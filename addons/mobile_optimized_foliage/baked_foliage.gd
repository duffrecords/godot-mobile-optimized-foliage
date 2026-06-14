@tool
class_name BakedFoliage
extends Node3D

@export_group("Setup")

## Root Node3D of the imported tree glTF (e.g. an inherited scene with overridden materials).
## Drag it here; target_mesh must be a MeshInstance3D descendant of this node.
## The node can be hidden once all BakedFoliage slots are wired up.
@export var tree_scene: Node3D:
	set(value):
		tree_scene = value
		if is_node_ready():
			_sync_tree_meshes()
			_bake()

## The mesh surface to scatter leaf instances on. Pick a MeshInstance3D child of tree_scene.
@export var target_mesh: MeshInstance3D:
	set(value):
		target_mesh = value
		if is_node_ready(): _bake()

## Number of leaf instances scattered on the target mesh surface.
@export_range(1, 10000, 1) var instance_count: int = 100:
	set(value):
		instance_count = value
		if is_node_ready(): _bake()

## The leaf-card mesh placed at each instance position.
@export var leaf_mesh: Mesh:
	set(value):
		leaf_mesh = value
		if is_node_ready(): _bake()

## ShaderMaterial using foliage_shadow.gdshader; assigned as material_override on the MultiMeshInstance3D.
@export var shader_material: ShaderMaterial:
	set(value):
		shader_material = value
		if is_node_ready(): _bake()

## Seed for the per-instance RNG. Set a unique value per foliage node for a
## stable, reproducible arrangement across editor sessions and devices.
@export var random_seed: int = 0:
	set(value):
		random_seed = value
		if is_node_ready(): _bake()

@export_group("Orientation")

## Factor influencing whether instances radiate outward from the mesh origin vs. from its center.
@export_range(0.0, 1.0, 0.01) var radiate_from_center: float = 0.0:
	set(value):
		radiate_from_center = value
		if is_node_ready(): _bake()

## Lower bound for how much each instance aligns its up-axis with the branch direction.
@export_range(0.0, 1.0, 0.01) var outward_bias_min: float = 0.35:
	set(value):
		outward_bias_min = min(value, outward_bias_max)
		if is_node_ready(): _bake()

## Upper bound for how much each instance aligns its up-axis with the branch direction.
@export_range(0.0, 1.0, 0.01) var outward_bias_max: float = 0.7:
	set(value):
		outward_bias_max = max(value, outward_bias_min)
		if is_node_ready(): _bake()

## Maximum random rotation applied around each instance's up-axis, in degrees.
@export_range(0.0, 180.0, 1.0) var twist_degrees: float = 15.0:
	set(value):
		twist_degrees = value
		if is_node_ready(): _bake()

@export_group("Scaling")

## Factor governing whether instances should be scaled smaller toward the top of the target mesh.
@export_range(0.0, 1.0, 0.01) var height_scale_effect: float = 0.0:
	set(value):
		height_scale_effect = value
		if is_node_ready(): _bake()

## Scaling factor for largest instances at the bottom.
@export_range(0.0, 2.0, 0.01) var max_instance_scale: float = 1.0:
	set(value):
		max_instance_scale = value
		if is_node_ready(): _bake()

## Scaling factor for smallest instances at the top.
@export_range(0.0, 2.0, 0.01) var min_instance_scale: float = 0.5:
	set(value):
		min_instance_scale = value
		if is_node_ready(): _bake()

@export_group("Lighting")

## DirectionalLight3D used to compute per-instance brightness.
@export var light: DirectionalLight3D:
	set(value):
		light = value
		if is_node_ready(): _bake()

## Albedo multiplier for the darkest (most occluded) instances.
@export_range(0.0, 1.0, 0.01) var shadow_min: float = 0.3:
	set(value):
		shadow_min = value
		if is_node_ready(): _bake()

## Albedo multiplier for fully lit instances.
@export_range(0.0, 1.0, 0.01) var shadow_max: float = 1.0:
	set(value):
		shadow_max = value
		if is_node_ready(): _bake()

## Maximum brightness multiplier applied on top of shadow_max for the most-lit instances.[br]
## Effective peak brightness = shadow_max + sun_boost, so keep their sum ≤ ~2.0 to avoid blown-out highlights.
@export_range(0.0, 3.0, 0.01) var sun_boost: float = 1.5:
	set(value):
		sun_boost = value
		if is_node_ready(): _bake()

## Controls how much light wraps around occluded and backlit foliage.
## 0.0 = hard N·L (dark backs); 1.0 = fully wrapped (backs glow as bright as fronts).
@export_range(0.0, 1.0, 0.01) var light_wrap: float = 0.5:
	set(value):
		light_wrap = value
		if is_node_ready(): _bake()

## How strongly the sun-side vs. shadow-side N·L contrast is applied to real-time leaf cards.
## 1.0 = full contrast; 0.5 = half; 0.0 = flat. Default 1.0 leaves real-time appearance unchanged.
## For impostor-only softening see impostor_directional_shadow_strength in the LOD group.
@export_range(0.0, 1.0, 0.01) var directional_shadow_strength: float = 1.0:
	set(value):
		directional_shadow_strength = value
		if is_node_ready(): _bake()

@export_group("Shader Parameters")

## Alpha clip threshold; fragments below this alpha are discarded.
@export_range(0.0, 1.0, 0.01) var alpha_scissor_threshold: float = 0.25:
	set(value):
		alpha_scissor_threshold = value
		_push_shader_params()

## Anti-aliasing transition band width around the clip threshold.
@export_range(0.0, 1.0, 0.01) var alpha_antialiasing_edge: float = 0.15:
	set(value):
		alpha_antialiasing_edge = value
		_push_shader_params()

## Local Y coordinate of the base of the leaf stem (matches shader uniform).
@export_range(-1.0, 1.0, 0.01) var stem_base_y: float = 0.0:
	set(value):
		stem_base_y = value
		_push_shader_params()

## Local Y coordinate of the tip of the leaf stem (matches shader uniform).
@export_range(-1.0, 1.0, 0.01) var stem_tip_y: float = 0.2:
	set(value):
		stem_tip_y = value
		_push_shader_params()

## Strength of the AO darkening applied toward the stem base.
@export_range(0.0, 1.0, 0.01) var ao_affect: float = 0.9:
	set(value):
		ao_affect = value
		_push_shader_params()

@export_group("Blob Shadow")

## When enabled, a Decal child is automatically created and positioned to project a radial
## blob shadow onto terrain below. Opacity is derived from shadow_min; offset follows light.
@export var blob_shadow_enabled: bool = true:
	set(value):
		blob_shadow_enabled = value
		if is_node_ready(): _bake()

## Render-layer mask controlling which geometry the blob-shadow Decal can project onto.
## Default is layer 1 (Godot's default render layer). Adjust to match your terrain layer.
@export_flags_3d_render var blob_shadow_cull_mask: int = 1:
	set(value):
		blob_shadow_cull_mask = value
		if is_node_ready():
			if _blob_shadow != null and is_instance_valid(_blob_shadow):
				_blob_shadow.cull_mask = blob_shadow_cull_mask
			else:
				_bake()

@export_group("LOD / Impostor")

## Baked atlas texture and quad dimensions produced by "Bake Impostor Atlas".
## Leave empty to disable the impostor LOD. Assign the same resource to multiple
## BakedFoliage nodes to share one baked atlas across identical shrubs.
@export var impostor_data: FoliageImpostorData:
	set(value):
		impostor_data = value
		if is_node_ready(): _update_impostor()

## Distance at which the leaf-card MultiMesh begins fading out (metres).
@export_range(0.0, 200.0, 1.0, "suffix:m") var lod_switch_distance: float = 30.0:
	set(value):
		lod_switch_distance = value
		if is_node_ready():
			_update_impostor()
			_push_shader_params()

## Width of the dither transition zone (metres). MultiMesh fades out and impostor
## fades in over this range.
@export_range(0.5, 20.0, 0.5, "suffix:m") var lod_fade_range: float = 5.0:
	set(value):
		lod_fade_range = value
		if is_node_ready():
			_update_impostor()
			_push_shader_params()

## Distance at which the impostor is fully culled (metres).
@export_range(0.0, 500.0, 1.0, "suffix:m") var lod_cull_distance: float = 150.0:
	set(value):
		lod_cull_distance = value
		if is_node_ready(): _update_impostor()

## Alpha clip threshold for the impostor. Higher than the leaf-card threshold because
## mix() blends adjacent-view alphas — a pixel opaque in one view and transparent in
## the next blends to ~0.5 at the midpoint, so 0.5 clips it cleanly.
@export_range(0.0, 1.0, 0.01) var impostor_alpha_scissor: float = 0.5:
	set(value):
		impostor_alpha_scissor = value
		if is_node_ready(): _update_impostor()

## Directional (N·L) shadow contrast used when baking the impostor atlas, independently
## of the real-time leaf-card appearance. 1.0 = full contrast; 0.5 = half contrast
## (shadow-side leaves bake 50% brighter); 0.0 = flat. Reducing this avoids the baked
## impostor looking too dark on the shadow side, where PBR would normally recover detail.
## Only read by ImpostorBaker — changing this has no effect until you rebake the atlas.
@export_range(0.0, 1.0, 0.01) var impostor_directional_shadow_strength: float = 0.5


const _MMI_NAME := "FoliageInstances"
const _TREE_MIRROR_PREFIX := "_foliage_tree_"
const _DECAL_NAME := "FoliageBlobShadow"
const _IMPOSTOR_NAME := "FoliageImpostor"
const _IMPOSTOR_SHADER: Shader = preload("res://addons/mobile_optimized_foliage/foliage_impostor.gdshader")

var _multimesh_instance: MultiMeshInstance3D
var _blob_shadow: Decal
var _blob_shadow_gradient: Gradient
var _blob_shadow_texture: GradientTexture2D
var _impostor_instance: MeshInstance3D
var _impostor_mesh: QuadMesh
var _impostor_material: ShaderMaterial
var _baked_light_direction: Vector3 = Vector3.ZERO
var _light_stale: bool = false
var _last_msaa: int = -1


func _ready() -> void:
	set_notify_transform(true)
	_sync_tree_meshes()
	_bake()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			if is_node_ready():
				_bake()
		NOTIFICATION_EDITOR_PRE_SAVE:
			# Zero the instance count so the buffer is not serialised into the
			# scene file — _bake() regenerates it deterministically at runtime.
			if is_instance_valid(_multimesh_instance) and _multimesh_instance.multimesh != null:
				_multimesh_instance.multimesh.instance_count = 0
		NOTIFICATION_EDITOR_POST_SAVE:
			_bake()


func _bake() -> void:
	if target_mesh == null:
		push_warning("BakedFoliage (%s): target_mesh is not assigned — drag a MeshInstance3D here to scatter leaf instances on." % name)
		return
	if leaf_mesh == null:
		push_warning("BakedFoliage (%s): leaf_mesh is not assigned — assign the leaf card Mesh resource." % name)
		return
	if instance_count <= 0:
		push_warning("BakedFoliage (%s): instance_count must be greater than zero." % name)
		return

	_ensure_multimesh_instance()
	_setup_multimesh()

	var mm := _multimesh_instance.multimesh
	var global_positions := _scatter_on_surface(mm)
	if global_positions.is_empty():
		push_warning("BakedFoliage (%s): no surface positions generated — check that target_mesh '%s' has geometry." % [name, target_mesh.name])
		return

	var mesh_center := Vector3.ZERO
	for p in global_positions:
		mesh_center += p
	mesh_center /= global_positions.size()
	var outward_center := _multimesh_instance.global_transform.origin.lerp(mesh_center, radiate_from_center)

	var min_y := INF
	var max_y := -INF
	for p in global_positions:
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	var vertical_span := max_y - min_y if max_y > min_y else 1.0

	# Separate RNG so orientation choices are independent from scatter positions.
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	for i in mm.instance_count:
		var local_xform := mm.get_instance_transform(i)
		var global_xform := _multimesh_instance.global_transform * local_xform

		# Slerp surface normal toward the outward direction, then add twist.
		var current_up := global_xform.basis.y.normalized()
		var outward := (global_xform.origin - outward_center).normalized()
		var outward_bias := rng.randf_range(outward_bias_min, outward_bias_max)
		var new_up := current_up.slerp(outward, outward_bias).normalized()

		var current_forward := global_xform.basis.z.normalized()
		var new_right := new_up.cross(current_forward).normalized()
		var new_forward := new_right.cross(new_up).normalized()
		var new_basis := Basis(new_right, new_up, new_forward)
		var twist_rad := deg_to_rad(rng.randf_range(-twist_degrees, twist_degrees))
		new_basis = Basis(new_up, twist_rad) * new_basis

		var y_frac := clamp((global_xform.origin.y - min_y) / vertical_span, 0.0, 1.0)
		var instance_scale: float = lerp(max_instance_scale, min_instance_scale, height_scale_effect * y_frac)
		new_basis = new_basis.scaled(Vector3.ONE * instance_scale)

		var new_global_xform := Transform3D(new_basis, global_xform.origin)
		mm.set_instance_transform(i, _multimesh_instance.global_transform.affine_inverse() * new_global_xform)

	var light_direction := Vector3(-1.0, -1.0, -1.0).normalized()
	if light:
		light_direction = -light.global_transform.basis.z.normalized()
	_baked_light_direction = light_direction
	_light_stale = false

	for i in mm.instance_count:
		var pos := global_positions[i]
		var instance_normal := (pos - mesh_center).normalized()
		var n_dot_l := -instance_normal.dot(light_direction)
		var depth_occlusion := _depth_shadow(pos, min_y, max_y)
		var wrapped := ((1.0 - light_wrap) * n_dot_l + light_wrap) / (1.0 + light_wrap)
		var highlight_factor: float = pow(clamp(wrapped, 0.0, 1.0), 0.7)
		highlight_factor = lerp(0.5, highlight_factor, directional_shadow_strength)
		# depth_occlusion lerps between shadow_min (fully occluded) and the lit value,
		# rather than multiplying down to zero. Leaves can never be darker than shadow_min,
		# matching the shader's intended ambient floor and preventing the impostor's
		# orthographic capture from picking up near-black leaves at the tree base.
		var lit: float = lerp(shadow_min, shadow_max + sun_boost, highlight_factor)
		var brightness: float = lerp(shadow_min, lit, depth_occlusion)
		mm.set_instance_custom_data(i, Color(brightness, 0.0, 0.0, 1.0))

	if shader_material:
		_multimesh_instance.material_override = shader_material
		_push_shader_params()
	else:
		push_warning("BakedFoliage (%s): shader_material is not assigned — assign a ShaderMaterial using foliage_shadow.gdshader; the MultiMesh will render without the foliage shader." % name)

	_update_decal(global_positions, light_direction, min_y, max_y)
	_update_impostor()
	if Engine.is_editor_hint():
		update_configuration_warnings()


func _sync_tree_meshes() -> void:
	# Build a name→node map of mirrors we already manage.
	var existing: Dictionary = {}
	for child in get_children():
		if child.name.begins_with(_TREE_MIRROR_PREFIX):
			existing[child.name] = child

	var seen: Dictionary = {}
	if tree_scene != null:
		var tree_inv := tree_scene.global_transform.affine_inverse()
		for node in tree_scene.find_children("*", "MeshInstance3D", true, false):
			var mnode := node as MeshInstance3D
			if mnode == null:
				continue
			var mirror_name := _TREE_MIRROR_PREFIX + mnode.name
			seen[mirror_name] = true
			var mirror: MeshInstance3D
			if existing.has(mirror_name):
				mirror = existing[mirror_name] as MeshInstance3D
			else:
				mirror = MeshInstance3D.new()
				mirror.name = mirror_name
				add_child(mirror)
				if Engine.is_editor_hint():
					mirror.owner = get_tree().edited_scene_root
			mirror.mesh = mnode.mesh
			mirror.material_override = mnode.material_override
			for surf in mnode.get_surface_override_material_count():
				mirror.set_surface_override_material(surf, mnode.get_surface_override_material(surf))
			# Place at the same offset from BakedFoliage as the mesh sits within tree_scene.
			mirror.transform = tree_inv * mnode.global_transform

	# Remove mirrors whose source nodes no longer exist.
	for mirror_name in existing:
		if not seen.has(mirror_name):
			existing[mirror_name].free()


func _ensure_multimesh_instance() -> void:
	if _multimesh_instance != null and is_instance_valid(_multimesh_instance):
		return
	_multimesh_instance = get_node_or_null(_MMI_NAME) as MultiMeshInstance3D
	if _multimesh_instance != null:
		return
	var mmi := MultiMeshInstance3D.new()
	mmi.name = _MMI_NAME
	add_child(mmi)
	if Engine.is_editor_hint():
		mmi.owner = get_tree().edited_scene_root
	_multimesh_instance = mmi


func _ensure_decal() -> void:
	if _blob_shadow != null and is_instance_valid(_blob_shadow):
		return
	_blob_shadow = get_node_or_null(_DECAL_NAME) as Decal
	if _blob_shadow != null:
		return
	var decal := Decal.new()
	decal.name = _DECAL_NAME
	add_child(decal)
	if Engine.is_editor_hint():
		decal.owner = get_tree().edited_scene_root
	_blob_shadow = decal


func _setup_multimesh() -> void:
	var mm := _multimesh_instance.multimesh
	if mm != null and mm.mesh == leaf_mesh and mm.use_custom_data:
		if mm.instance_count == instance_count:
			return
		if mm.instance_count == 0:
			# Cleared by NOTIFICATION_EDITOR_PRE_SAVE; restore in-place so the
			# resource identity (and any external path) is preserved.
			mm.instance_count = instance_count
			return
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = leaf_mesh
	mm.instance_count = instance_count
	_multimesh_instance.multimesh = mm


# Scatters instance_count transforms onto the surface of target_mesh using
# triangle-area-weighted sampling. Initial basis Y = interpolated surface normal.
# Returns global positions for the lighting pass.
func _scatter_on_surface(mm: MultiMesh) -> Array[Vector3]:
	var mesh_res := target_mesh.mesh
	if mesh_res == null:
		push_warning("BakedFoliage (%s): target_mesh '%s' has no Mesh resource assigned." % [name, target_mesh.name])
		return []

	var tri_a := PackedVector3Array()
	var tri_b := PackedVector3Array()
	var tri_c := PackedVector3Array()
	var tri_na := PackedVector3Array()
	var tri_nb := PackedVector3Array()
	var tri_nc := PackedVector3Array()
	var cumulative := PackedFloat32Array()
	var total_area := 0.0

	for surf_idx in mesh_res.get_surface_count():
		var arrays := mesh_res.surface_get_arrays(surf_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms_raw: Variant = arrays[Mesh.ARRAY_NORMAL]
		var has_norms := norms_raw != null
		var norms: PackedVector3Array = norms_raw if has_norms else PackedVector3Array()
		var indices_raw: Variant = arrays[Mesh.ARRAY_INDEX]
		var has_indices := indices_raw != null
		var indices: PackedInt32Array = indices_raw if has_indices else PackedInt32Array()

		var step := indices.size() if has_indices else verts.size()
		for i in range(0, step, 3):
			var ia := indices[i] if has_indices else i
			var ib := indices[i + 1] if has_indices else i + 1
			var ic := indices[i + 2] if has_indices else i + 2
			var a := verts[ia]
			var b := verts[ib]
			var c := verts[ic]
			var face_n := (b - a).cross(c - a).normalized()
			tri_a.append(a)
			tri_b.append(b)
			tri_c.append(c)
			tri_na.append(norms[ia] if has_norms else face_n)
			tri_nb.append(norms[ib] if has_norms else face_n)
			tri_nc.append(norms[ic] if has_norms else face_n)
			total_area += 0.5 * (b - a).cross(c - a).length()
			cumulative.append(total_area)

	if tri_a.is_empty() or total_area <= 0.0:
		push_warning("BakedFoliage (%s): target_mesh '%s' has no valid triangles (surface_count=%d, total_area=%.4f)." % [name, target_mesh.name, mesh_res.get_surface_count(), total_area])
		return []

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	# When tree_scene is set, strip its world position and re-root the geometry at
	# BakedFoliage's own transform. Without tree_scene, scatter at target_mesh's
	# actual world position (legacy behaviour).
	var to_global := target_mesh.global_transform
	if tree_scene != null:
		to_global = global_transform * (tree_scene.global_transform.affine_inverse() * target_mesh.global_transform)
	var to_mmi_local := _multimesh_instance.global_transform.affine_inverse()
	var global_positions: Array[Vector3] = []

	for i in instance_count:
		var t := _bisect(cumulative, rng.randf() * total_area)

		# Uniform point on triangle via square-root method.
		var r1 := sqrt(rng.randf())
		var r2 := rng.randf()
		var u := 1.0 - r1
		var v := r1 * (1.0 - r2)
		var w := r1 * r2
		var local_pos: Vector3 = u * tri_a[t] + v * tri_b[t] + w * tri_c[t]
		var local_normal: Vector3 = (u * tri_na[t] + v * tri_nb[t] + w * tri_nc[t]).normalized()

		var global_pos := to_global * local_pos
		var up := (to_global.basis * local_normal).normalized()
		var ref := Vector3.FORWARD if abs(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
		var right := up.cross(ref).normalized()
		var forward := right.cross(up).normalized()

		mm.set_instance_transform(i, to_mmi_local * Transform3D(Basis(right, up, forward), global_pos))
		global_positions.append(global_pos)

	return global_positions


func _bisect(arr: PackedFloat32Array, value: float) -> int:
	var lo := 0
	var hi := arr.size() - 1
	while lo < hi:
		var mid := (lo + hi) / 2
		if arr[mid] < value:
			lo = mid + 1
		else:
			hi = mid
	return lo


func _push_shader_params() -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter("alpha_scissor_threshold", alpha_scissor_threshold)
	shader_material.set_shader_parameter("alpha_antialiasing_edge", alpha_antialiasing_edge)
	shader_material.set_shader_parameter("stem_base_y", stem_base_y)
	shader_material.set_shader_parameter("stem_tip_y", stem_tip_y)
	shader_material.set_shader_parameter("ao_affect", ao_affect)
	# When there is no impostor, push a very large distance so the shader never fades.
	var effective_switch: float = lod_switch_distance if (impostor_data != null and impostor_data.texture != null) else 1.0e9
	shader_material.set_shader_parameter("lod_switch_distance", effective_switch)
	shader_material.set_shader_parameter("lod_fade_range", lod_fade_range)


func _depth_shadow(pos: Vector3, y_min: float, y_max: float) -> float:
	var span := y_max - y_min if y_max > y_min else 1.0
	return clamp((pos.y - y_min) / span, 0.0, 1.0)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var stale := is_instance_valid(light) \
		and _baked_light_direction != Vector3.ZERO \
		and (-light.global_transform.basis.z.normalized()).dot(_baked_light_direction) < 0.9998
	if stale != _light_stale:
		_light_stale = stale
		update_configuration_warnings()
	var msaa := int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0))
	if msaa != _last_msaa:
		_last_msaa = msaa
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _light_stale:
		warnings.append("Light direction has changed since the last bake. Use \"Rebake All Foliage\" in the toolbar.")
	var msaa := int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0))
	if msaa == 0:
		warnings.append("MSAA is disabled. This foliage shader uses alpha_to_coverage_and_one, which requires MSAA to work correctly — enable at least 2× MSAA under Project Settings > Rendering > Anti Aliasing > Quality > MSAA 3D.")
	return warnings


## Re-runs the lighting bake. Called by the editor toolbar button to refresh all nodes at once.
func rebake() -> void:
	_bake()


func _update_decal(global_positions: Array[Vector3], light_direction: Vector3, min_y: float, max_y: float) -> void:
	if not blob_shadow_enabled:
		if _blob_shadow != null and is_instance_valid(_blob_shadow):
			_blob_shadow.queue_free()
			_blob_shadow = null
		return

	if global_positions.is_empty():
		return

	_ensure_decal()

	# XZ centroid of scatter positions.
	var cx := 0.0
	var cz := 0.0
	for p in global_positions:
		cx += p.x
		cz += p.z
	cx /= global_positions.size()
	cz /= global_positions.size()

	# Max XZ radius from centroid — this is the shadow footprint size.
	var mesh_radius := 0.0
	for p in global_positions:
		var dx := p.x - cx
		var dz := p.z - cz
		mesh_radius = max(mesh_radius, sqrt(dx * dx + dz * dz))

	# Project the mesh midpoint height down to the ground via the light direction
	# to get the XZ offset where the shadow centre lands.
	var origin_y := global_transform.origin.y
	var mesh_mid_y := (min_y + max_y) * 0.5 - origin_y
	var offset_x := 0.0
	var offset_z := 0.0
	if abs(light_direction.y) > 0.001:
		var t: float = -mesh_mid_y / light_direction.y
		offset_x = light_direction.x * t
		offset_z = light_direction.z * t

	# Convert the global shadow centre to BakedFoliage-local space.
	var global_shadow_pos := Vector3(cx + offset_x, origin_y, cz + offset_z)
	var local_shadow_pos := global_transform.affine_inverse() * global_shadow_pos
	local_shadow_pos.y = 0.0

	# Decal Y depth spans the mesh height plus clearance so it always hits terrain.
	var decal_depth: float = max_y - min_y + 1.0

	_blob_shadow.position = local_shadow_pos
	_blob_shadow.size = Vector3(mesh_radius * 2.0, decal_depth, mesh_radius * 2.0)
	_blob_shadow.cull_mask = blob_shadow_cull_mask
	_blob_shadow.emission_energy = 0.0

	# Build (or reuse) the radial gradient texture. Inner alpha mirrors shadow depth:
	# when shadow_min is low (dark leaves), the blob shadow is more opaque.
	if _blob_shadow_gradient == null:
		_blob_shadow_gradient = Gradient.new()
		_blob_shadow_gradient.offsets = PackedFloat32Array([0.22, 0.72])
	if _blob_shadow_texture == null:
		_blob_shadow_texture = GradientTexture2D.new()
		_blob_shadow_texture.gradient = _blob_shadow_gradient
		_blob_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
		_blob_shadow_texture.fill_from = Vector2(0.5, 0.5)
		_blob_shadow_texture.fill_to = Vector2(1.0, 1.0)
		_blob_shadow.texture_albedo = _blob_shadow_texture

	var inner_alpha: float = clamp(1.0 - shadow_min, 0.0, 1.0)
	_blob_shadow_gradient.colors = PackedColorArray([Color(0.0, 0.0, 0.0, inner_alpha), Color(0.0, 0.0, 0.0, 0.0)])


func _ensure_impostor() -> void:
	if _impostor_instance != null and is_instance_valid(_impostor_instance):
		return
	_impostor_instance = get_node_or_null(_IMPOSTOR_NAME) as MeshInstance3D
	if _impostor_instance != null:
		return
	var mi := MeshInstance3D.new()
	mi.name = _IMPOSTOR_NAME
	add_child(mi)
	if Engine.is_editor_hint():
		mi.owner = get_tree().edited_scene_root
	_impostor_instance = mi


func _update_impostor() -> void:
	if impostor_data == null or impostor_data.texture == null:
		if _impostor_instance != null and is_instance_valid(_impostor_instance):
			_impostor_instance.queue_free()
			_impostor_instance = null
		# Restore the MMI to always-visible when there is no impostor to take over.
		if _multimesh_instance != null and is_instance_valid(_multimesh_instance):
			_multimesh_instance.visibility_range_end = 0.0
			_multimesh_instance.visibility_range_end_margin = 0.0
			_multimesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		_push_shader_params()
		_update_tree_mirror_visibility()
		return

	_ensure_impostor()

	# Size the quad; bottom edge sits at the node origin, top edge at impostor_data.height.
	if _impostor_mesh == null:
		_impostor_mesh = QuadMesh.new()
	_impostor_mesh.size = Vector2(impostor_data.width, impostor_data.height)
	_impostor_instance.mesh = _impostor_mesh
	_impostor_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impostor_instance.position = Vector3(0.0, impostor_data.height * 0.5, 0.0)

	# Build or update the impostor ShaderMaterial.
	if _impostor_material == null:
		_impostor_material = ShaderMaterial.new()
		_impostor_material.shader = _IMPOSTOR_SHADER
	_impostor_material.set_shader_parameter("albedo_texture", impostor_data.texture)
	_impostor_material.set_shader_parameter("alpha_scissor_threshold", impostor_alpha_scissor)
	_impostor_material.set_shader_parameter("lod_switch_distance", lod_switch_distance)
	_impostor_material.set_shader_parameter("lod_fade_range", lod_fade_range)
	_impostor_material.set_shader_parameter("lod_cull_distance", lod_cull_distance)
	_impostor_instance.material_override = _impostor_material

	# Shader handles all fading; visibility range provides zero-cost hard culls only.
	# VISIBILITY_RANGE_FADE_SELF is Forward+ only — use FADE_DISABLED on Mobile renderer.
	if _multimesh_instance != null and is_instance_valid(_multimesh_instance):
		_multimesh_instance.visibility_range_end = lod_switch_distance
		_multimesh_instance.visibility_range_end_margin = 0.0
		_multimesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	_impostor_instance.visibility_range_begin = max(0.0, lod_switch_distance - lod_fade_range)
	_impostor_instance.visibility_range_begin_margin = 0.0
	_impostor_instance.visibility_range_end = lod_cull_distance
	_impostor_instance.visibility_range_end_margin = 0.0
	_impostor_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	_update_tree_mirror_visibility()


func _update_tree_mirror_visibility() -> void:
	# When an impostor is active, hard-cull the trunk/branch mirrors at the distance
	# where the impostor begins fading in. The leaf cards are still present during the
	# fade zone and cover the trunk area, so the cut is invisible. Without this, the
	# flat impostor quad clips through the 3D trunk geometry during the transition.
	var range_end: float = 0.0  # 0 = always visible (Godot's disabled sentinel)
	if impostor_data != null and impostor_data.texture != null:
		range_end = max(0.0, lod_switch_distance - lod_fade_range)
	for child in get_children():
		if child.name.begins_with(_TREE_MIRROR_PREFIX):
			var gi := child as GeometryInstance3D
			if gi != null:
				gi.visibility_range_end = range_end
				gi.visibility_range_end_margin = 0.0
				gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Returns the AABB of all geometry children (leaf MultiMesh + tree mirrors) in this
## node's local space. Used by the impostor baker to size the orthographic camera and
## the billboard quad without requiring manual measurement.
func compute_capture_aabb() -> AABB:
	var result := AABB()
	var first := true
	for child in get_children():
		# Exclude the flat impostor quad — it's a proxy, not real geometry.
		if child.name == _IMPOSTOR_NAME:
			continue
		var gi := child as GeometryInstance3D
		if gi == null:
			continue
		# get_aabb() is local to the child; apply the child's local transform to bring
		# it into BakedFoliage's coordinate space before merging.
		var child_aabb: AABB = child.transform * gi.get_aabb()
		if first:
			result = child_aabb
			first = false
		else:
			result = result.merge(child_aabb)
	return result
