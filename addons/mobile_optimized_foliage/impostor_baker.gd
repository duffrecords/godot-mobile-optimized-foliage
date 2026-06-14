@tool
class_name ImpostorBaker
extends RefCounted

const _TREE_MIRROR_PREFIX := "_foliage_tree_"
const CELL_SIZE := 512


## Bakes a 4-view impostor atlas for foliage, saves a PNG adjacent to the scene
## file, then writes impostor_width / impostor_height / impostor_texture back onto
## the node. Returns "" on success or an error message on failure.
func bake(foliage: BakedFoliage, ei: EditorInterface) -> String:
	if foliage == null:
		return "BakedFoliage node is null."

	# ── 1. Geometry AABB → impostor dimensions ───────────────────────────────
	var aabb: AABB = foliage.compute_capture_aabb()
	if aabb.size == Vector3.ZERO:
		return "No geometry found — assign tree_scene, target_mesh, and leaf_mesh first."

	const PAD := 1.05
	var cap_width: float  = maxf(aabb.size.x, aabb.size.z) * PAD
	var cap_height: float = aabb.end.y * PAD
	if cap_height <= 0.0:
		return "Computed impostor height ≤ 0 — BakedFoliage origin must sit at or below the tree base."

	# ── 2. Output paths ──────────────────────────────────────────────────────────
	# BakedFoliage nodes are typically inline in the scene rather than sub-scene
	# roots, so scene_file_path walks up to the edited scene root (e.g. main.tscn).
	# Append the node name so each BakedFoliage in the scene gets its own atlas.
	var scene_path: String = foliage.get_tree().edited_scene_root.scene_file_path
	if scene_path.is_empty():
		return "Save the scene before baking."
	var base: String = scene_path.get_basename() + "_" + foliage.name
	var atlas_path: String = base + "_impostor_atlas.png"
	var tres_path: String  = base + "_impostor.tres"

	# ── 3. Capture material — same uniforms as the leaf shader, no LOD discard ──
	var src_mat := foliage.shader_material
	if src_mat == null:
		return "BakedFoliage '%s' has no shader_material assigned." % foliage.name
	var cap_shader: Shader = load("res://addons/mobile_optimized_foliage/foliage_capture.gdshader")
	if cap_shader == null:
		return "Could not load foliage_capture.gdshader — try reimporting the plugin files."
	var cap_mat := ShaderMaterial.new()
	cap_mat.shader = cap_shader
	for param in ["albedo_texture", "alpha_scissor_threshold", "alpha_antialiasing_edge",
				  "stem_base_y", "stem_tip_y", "ao_affect"]:
		cap_mat.set_shader_parameter(param, src_mat.get_shader_parameter(param))

	# ── 3.5. Rebake leaf instances with the impostor-specific directional shadow strength ──
	# directional_shadow_strength controls real-time N·L contrast baked into INSTANCE_CUSTOM.r.
	# The impostor atlas captures that data, so we temporarily swap in the impostor value,
	# let the setter trigger _bake(), then restore after teardown.
	var saved_directional_strength: float = foliage.directional_shadow_strength
	foliage.directional_shadow_strength = foliage.impostor_directional_shadow_strength

	# ── 4. SubViewport — attach to editor UI tree so the 3D scene is untouched ──
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL_SIZE, CELL_SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# MSAA_4X gives the hard-cutout leaf silhouettes sub-pixel soft edges through
	# the resolve step, replacing the fwidth trick that required blend_mix.
	vp.msaa_3d = Viewport.MSAA_4X
	# own_world_3d isolates this viewport from the editor's World3D so only the
	# mirrored geometry is visible, not every other object in the open scene.
	vp.own_world_3d = true
	ei.get_base_control().add_child(vp)

	# ── 5. Mirror foliage geometry into the SubViewport ──────────────────────
	var root := Node3D.new()
	vp.add_child(root)

	for child in foliage.get_children():
		if child is MultiMeshInstance3D:
			# Share the MultiMesh resource — INSTANCE_CUSTOM data is already baked.
			var src := child as MultiMeshInstance3D
			var dst := MultiMeshInstance3D.new()
			dst.transform = src.transform
			dst.multimesh = src.multimesh
			dst.material_override = cap_mat
			root.add_child(dst)
		elif child is MeshInstance3D and child.name.begins_with(_TREE_MIRROR_PREFIX):
			# Trunk / branch baked meshes.
			var src := child as MeshInstance3D
			var dst := MeshInstance3D.new()
			dst.transform = src.transform
			dst.mesh = src.mesh
			dst.material_override = src.material_override
			for s in src.get_surface_override_material_count():
				dst.set_surface_override_material(s, src.get_surface_override_material(s))
			root.add_child(dst)

	# ── 6. Orthographic camera ────────────────────────────────────────────────
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Use the larger dimension so neither axis is cropped; the image is then
	# translated downward in post so the lowest pixel lands at the cell bottom.
	cam.size = maxf(cap_width, cap_height)
	cam.near = 0.01
	cam.far = cam.size * 10.0
	root.add_child(cam)

	var cy: float = cap_height / 2.0
	var standoff: float = cam.size * 3.0

	# Cell layout matches cell_origin() in foliage_impostor.gdshader:
	#   0 (+Z) → top-left,  1 (+X) → top-right
	#   2 (−Z) → bot-left,  3 (−X) → bot-right
	var views: Array = [
		{ "pos": Vector3(0.0,      cy,  standoff), "cell": Vector2i(0,         0) },
		{ "pos": Vector3( standoff, cy, 0.0),      "cell": Vector2i(CELL_SIZE, 0) },
		{ "pos": Vector3(0.0,      cy, -standoff), "cell": Vector2i(0,         CELL_SIZE) },
		{ "pos": Vector3(-standoff, cy, 0.0),      "cell": Vector2i(CELL_SIZE, CELL_SIZE) },
	]

	# ── 7. Capture loop ───────────────────────────────────────────────────────
	var atlas := Image.create(CELL_SIZE * 2, CELL_SIZE * 2, false, Image.FORMAT_RGBA8)
	var capture_err := ""

	for view in views:
		cam.position = view["pos"]
		cam.look_at(Vector3(0.0, cy, 0.0), Vector3.UP)
		# Two frames: first flushes the transform change, second captures the result.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

		var img: Image = vp.get_texture().get_image()
		if img == null or img.is_empty():
			capture_err = "SubViewport returned an empty image."
			break
		if img.get_size() != Vector2i(CELL_SIZE, CELL_SIZE):
			img.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_LANCZOS)
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)

		# Scan rows bottom-to-top via raw bytes (alpha byte = offset +3 in RGBA8).
		# Find the lowest row with any non-transparent pixel, then shift the image
		# down so that row lands at the cell bottom — fixes floating when the camera
		# frustum is wider than the subject is tall.
		var raw := img.get_data()
		var lowest_row := CELL_SIZE - 1  # fallback: no shift
		var found_content := false
		for row in range(CELL_SIZE - 1, -1, -1):
			if found_content:
				break
			var row_base := row * CELL_SIZE * 4
			for col in range(CELL_SIZE):
				if raw[row_base + col * 4 + 3] > 2:
					lowest_row = row
					found_content = true
					break

		var shift_y: int = (CELL_SIZE - 1) - lowest_row
		# Copy only the rows that fit after shifting; the vacated top rows stay transparent.
		atlas.blit_rect(img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE - shift_y),
				view["cell"] + Vector2i(0, shift_y))

	# ── 8. Tear down SubViewport (always, even on error) ─────────────────────
	ei.get_base_control().remove_child(vp)
	vp.queue_free()

	# Restore real-time directional shadow strength (always, even on error).
	foliage.directional_shadow_strength = saved_directional_strength

	if not capture_err.is_empty():
		return capture_err

	# ── 9. Save PNG ───────────────────────────────────────────────────────────
	var save_err: int = atlas.save_png(atlas_path)
	if save_err != OK:
		return "Failed to save '%s' (error %d)." % [atlas_path, save_err]

	# ── 10. Build FoliageImpostorData with an ImageTexture for immediate use ─
	# The camera frustum is a square (maxf of width and height), so the quad must
	# be square too — otherwise the texture is stretched on the shorter axis.
	var impostor_size: float = snappedf(maxf(cap_width, cap_height), 0.01)
	var data := FoliageImpostorData.new()
	data.texture = ImageTexture.create_from_image(atlas)
	data.width   = impostor_size
	data.height  = impostor_size

	# Assign now so the impostor renders during the reimport wait below.
	foliage.impostor_data = data

	# Save an initial .tres so the resource is file-backed immediately; the
	# embedded ImageTexture is replaced in step 11 once the PNG is imported.
	var res_err: int = ResourceSaver.save(data, tres_path)
	if res_err != OK:
		push_warning("[BakedFoliage] Could not save '%s' (error %d) — impostor data will be embedded in scene." % [tres_path, res_err])

	# ── 11. Register + import the PNG, then swap in the CompressedTexture2D ──
	# scan() registers new files that aren't yet in the filesystem database.
	# filesystem_changed fires after the scan AND all triggered reimports finish,
	# so it is safe to load the imported texture immediately after it.
	# resources_reimported is not used here: it only fires when Godot detects a
	# content change, so a same-content rebake skips reimport and causes a hang.
	ei.get_resource_filesystem().scan()
	await ei.get_resource_filesystem().filesystem_changed

	# CACHE_MODE_REPLACE bypasses any stale entry from a previous bake.
	var imported_tex := ResourceLoader.load(atlas_path, "", ResourceLoader.CACHE_MODE_REPLACE) as Texture2D
	if imported_tex != null:
		data.texture = imported_tex
		foliage.impostor_data = data  # re-triggers _update_impostor() with the imported texture
		ResourceSaver.save(data, tres_path)  # overwrite: now a path reference, no embedded bytes

	return ""
