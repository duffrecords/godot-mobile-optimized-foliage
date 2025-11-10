extends Node3D

@export var radiate_from_center: float = 0.0 # factor influencing whether instances radiate outward from the mesh origin vs. from its center
@export var height_scale_effect: float = 0.0 # factor governing whether instances should be scaled smaller toward the top of the target mesh
@export var min_instance_scale: float = 0.5 # scaling factor for smallest instances at the top
@export var max_instance_scale: float = 1.0 # scaling factor for largest instances at the bottom
@export var multimesh_instance_path: NodePath = "MultiMeshInstance3D" # default: direct child
@export var shader_material: ShaderMaterial
@export var light_node: NodePath # assign your DirectionalLight3D here
@export var shadow_min: = 0.3 # albedo multiplier for the lightest instances
@export var shadow_max: = 1.0 # albedo multiplier for the darkest instances
@export var sun_boost: = 1.5 # maximum brightness multiplier for most-lit instances
@export var outward_bias_min: = 0.35 # how much each instance aligns with the branch direction (lower limit)
@export var outward_bias_max: = 0.7 # how much each instance aligns with the branch direction (upper limit)
@export var twist_degrees: = 15.0 # how much to randomly rotate instances in either direction

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# "depth shadow" based on Y coordinate
func calculate_depth_shadow(pos: Vector3) -> float:
	var min_y = -2.0
	var max_y = 2.0
	return clamp((pos.y - min_y) / (max_y - min_y), 0.0, 1.0)


func _ready():
	var mm_instance = get_node(multimesh_instance_path) as MultiMeshInstance3D
	var mm = mm_instance.multimesh

	# Save original transforms if they exist (e.g. from editor "Populate Surface")
	var transforms = []
	for i in mm.instance_count:
		transforms.append(mm.get_instance_transform(i))

	# Recreate MultiMesh for custom data support
	mm.instance_count = 0
	mm.use_custom_data = true
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])

	# Assign material and texture
	if shader_material:
		mm_instance.material_override = shader_material

	# Collect all instance global positions
	var global_positions = []
	for i in mm.instance_count:
		var local_xform = mm.get_instance_transform(i)
		var global_xform = mm_instance.global_transform * local_xform
		global_positions.append(global_xform.origin)

	# Calculate "center" for outward orientation
	var mesh_center = mm_instance.global_transform.origin
	var outward_center = mm_instance.global_transform.origin
	if global_positions.size() > 0:
		mesh_center = Vector3.ZERO
		for p in global_positions:
			mesh_center += p
		mesh_center /= global_positions.size()
		outward_center = mm_instance.global_transform.origin.lerp(outward_center, radiate_from_center)

	# Calculate vertical range for scaling (in world Y)
	var min_y = INF
	var max_y = -INF
	for p in global_positions:
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	var vertical_span = max_y - min_y if max_y > min_y else 1.0

	# Prepare for randomization
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(mm_instance.get_instance_id())

	for i in mm.instance_count:
		var local_xform = mm.get_instance_transform(i)
		var global_xform = mm_instance.global_transform * local_xform

		# --- Orientation ---
		var current_up = global_xform.basis.y.normalized()
		var outward = (global_xform.origin - outward_center).normalized()
		var outward_bias = rng.randf_range(outward_bias_min, outward_bias_max)
		var new_up = current_up.slerp(outward, outward_bias).normalized()

		var current_forward = global_xform.basis.z.normalized()
		var new_right = new_up.cross(current_forward).normalized()
		var new_forward = new_right.cross(new_up).normalized()
		var new_basis = Basis(new_right, new_up, new_forward)
		var twist_rad = deg_to_rad(rng.randf_range(-twist_degrees, twist_degrees))
		var twist_basis = Basis(new_up, twist_rad)
		new_basis = twist_basis * new_basis

		# --- Scaling ---
		# Vertical fraction: 0 at base, 1 at top
		var y_frac = clamp((global_xform.origin.y - min_y) / vertical_span, 0.0, 1.0)
		var instance_scale = lerp(max_instance_scale, min_instance_scale, height_scale_effect * y_frac)

		# Apply scale to basis (applies uniform scaling)
		new_basis = new_basis.scaled(Vector3(instance_scale, instance_scale, instance_scale))
		# Rebuild local transform relative to MultiMeshInstance3D
		var new_global_xform = Transform3D(new_basis, global_xform.origin)
		var new_local_xform = mm_instance.global_transform.affine_inverse() * new_global_xform

		mm.set_instance_transform(i, new_local_xform)

	# Get directional light direction (in global space)
	var light = get_node_or_null(light_node)
	var light_direction = Vector3(-1, -1, -1).normalized() # default if none found
	if light and light is DirectionalLight3D:
		light_direction = -light.global_transform.basis.z.normalized()

	# Set per-instance custom data for shadowing
	for i in mm.instance_count:
		var pos = global_positions[i]
		var instance_normal = (pos - mesh_center).normalized()
		var n_dot_l = -instance_normal.dot(light_direction)

		# var edge0 = 0.0
		# var edge1 = 1.0
		# var brightness = lerp(shadow_min, shadow_max, smoothstep(edge0, edge1, clamp(n_dot_l, 0.0, 1.0)))

		# var gamma = 2.2 # try between 1.5 and 3.0
		# var brightness = lerp(shadow_min, shadow_max, pow(clamp(n_dot_l, 0.0, 1.0), 1.0 / gamma))

		var depth_occlusion = calculate_depth_shadow(pos)

		var wrap = 0.5 # between 0.0 (sharp) and 1.0 (very soft)
		var wrapped = ((1.0 - wrap) * n_dot_l + wrap) / (1.0 + wrap)
		var wrap_brightness = clamp(wrapped, 0.0, 1.0)
		var highlight_factor = pow(wrap_brightness, 0.7)  # So 1.0 stays 1.0, but 0.5->0.66, 0.25->0.44
		var brightness = lerp(shadow_min, shadow_max + sun_boost, highlight_factor) * depth_occlusion

		# var brightness = lerp(shadow_min, shadow_max, clamp(n_dot_l, 0.0, 1.0))
		mm.set_instance_custom_data(i, Color(brightness, 0, 0, 1))

	var min_brightness = 1.0
	var max_brightness = 0.0
	for i in mm.instance_count:
		var brightness = mm.get_instance_custom_data(i).r
		if brightness < min_brightness:
			min_brightness = brightness
		if brightness > max_brightness:
			max_brightness = brightness
	# print("Setup complete! Range of brightness: " + str(min_brightness) + " " + str(max_brightness))
