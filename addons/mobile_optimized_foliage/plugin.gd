@tool
extends EditorPlugin

var _inspector_plugin: EditorInspectorPlugin
var _rebake_btn: Button
var _toolbar_separator: VSeparator


func _enter_tree() -> void:
	_inspector_plugin = FoliageInspectorPlugin.new()
	_inspector_plugin.editor_interface = get_editor_interface()
	add_inspector_plugin(_inspector_plugin)

	_toolbar_separator = VSeparator.new()
	add_control_to_container(CONTAINER_TOOLBAR, _toolbar_separator)

	_rebake_btn = Button.new()
	_rebake_btn.text = "Rebake All Foliage"
	_rebake_btn.tooltip_text = "Re-runs the lighting bake on every BakedFoliage node in the current scene."
	_rebake_btn.pressed.connect(_on_rebake_all_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _rebake_btn)


func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
	if _rebake_btn != null:
		remove_control_from_container(CONTAINER_TOOLBAR, _rebake_btn)
		_rebake_btn.queue_free()
		_rebake_btn = null
	if _toolbar_separator != null:
		remove_control_from_container(CONTAINER_TOOLBAR, _toolbar_separator)
		_toolbar_separator.queue_free()
		_toolbar_separator = null


func _on_rebake_all_pressed() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	var count := 0
	var candidates: Array[Node] = [root]
	candidates.append_array(root.find_children("*", "", true, false))
	for node in candidates:
		if node is BakedFoliage:
			node.rebake()
			count += 1
	if count > 0:
		print("[BakedFoliage] Rebaked %d node(s)." % count)
	else:
		print("[BakedFoliage] No BakedFoliage nodes found in the current scene.")


# ── Inspector plugin ─────────────────────────────────────────────────────────

class FoliageInspectorPlugin extends EditorInspectorPlugin:
	var editor_interface: EditorInterface

	func _can_handle(object: Object) -> bool:
		return object is BakedFoliage

	func _parse_end(object: Object) -> void:
		var foliage := object as BakedFoliage
		if foliage == null:
			return
		var rebake_btn := Button.new()
		rebake_btn.text = "Rebake"
		rebake_btn.tooltip_text = "Re-runs the lighting bake for this BakedFoliage node."
		rebake_btn.pressed.connect(foliage.rebake)
		add_custom_control(rebake_btn)
		var bake_btn := Button.new()
		bake_btn.text = "Bake Impostor Atlas"
		bake_btn.tooltip_text = "Captures 4 orthographic views, stitches a 1024×1024 PNG atlas, and assigns it."
		bake_btn.pressed.connect(_on_bake_pressed.bind(foliage, bake_btn))
		add_custom_control(bake_btn)

	func _on_bake_pressed(foliage: BakedFoliage, btn: Button) -> void:
		btn.text = "Baking…"
		btn.disabled = true
		var baker = load("res://addons/mobile_optimized_foliage/impostor_baker.gd").new()
		var err: String = await baker.bake(foliage, editor_interface)
		btn.disabled = false
		if err.is_empty():
			btn.text = "Bake Impostor Atlas ✓"
			print("[BakedFoliage] Impostor atlas baked: ", foliage.impostor_data.resource_path)
		else:
			btn.text = "Bake Impostor Atlas ✗"
			push_error("[BakedFoliage] Bake failed: " + err)
