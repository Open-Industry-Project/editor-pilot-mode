@tool
extends EditorPlugin

signal pilot_mode_entered
signal pilot_mode_exited

const SPAWN_Y_OFFSET: float = 1.5
const FOCUS_RETURN_DELAY: float = 0.05
const SHORTCUT_PATH: String = "Pilot Mode/Toggle Pilot Mode"
const SETTING_PATH: String = "addons/pilot_mode/scene/path"
const DEFAULT_SCENE: String = "res://addons/editor-pilot-mode/default_character.tscn"

var pilot_active: bool = false
var pilot_node: Node3D
var was_in_pilot_mode: bool = false
var overlay: Control
var _editor_camera: Camera3D
var _canvas_viewport: Viewport
var _node3d_viewport: Viewport

var _active_viewport_ui: Dictionary = {}


func _enter_tree() -> void:
	var editor_settings := EditorInterface.get_editor_settings()

	var toggle_shortcut := Shortcut.new()
	var key_stroke := InputEventKey.new()
	key_stroke.keycode = KEY_R
	key_stroke.shift_pressed = true
	toggle_shortcut.events.append(key_stroke)
	editor_settings.add_shortcut(SHORTCUT_PATH, toggle_shortcut)

	if not ProjectSettings.has_setting(SETTING_PATH):
		ProjectSettings.set_setting(SETTING_PATH, DEFAULT_SCENE)

	ProjectSettings.set_initial_value(SETTING_PATH, DEFAULT_SCENE)
	ProjectSettings.set_as_basic(SETTING_PATH, true)
	ProjectSettings.add_property_info({
		"name": SETTING_PATH,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tscn",
	})
	set_input_event_forwarding_always_enabled()

	overlay = Control.new()
	overlay.name = "FullscreenOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.draw.connect(_on_overlay_draw)


func _exit_tree() -> void:
	if pilot_active:
		exit_pilot_mode(_editor_camera, _canvas_viewport, _node3d_viewport)

	if is_instance_valid(overlay):
		overlay.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		handle_focus_lost()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		handle_focus_gained()


func _input(event: InputEvent) -> void:
	if not pilot_active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouse:
		if _canvas_viewport and not _canvas_viewport.gui_disable_input:
			_canvas_viewport.push_input(event)
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return

	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		return

	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.is_shortcut(SHORTCUT_PATH, event):
		return

	get_viewport().set_input_as_handled()


func _forward_3d_gui_input(_camera: Camera3D, event: InputEvent) -> int:
	var root := EditorInterface.get_edited_scene_root() as Node3D
	if not root:
		return AfterGUIInput.AFTER_GUI_INPUT_PASS

	var canvas_viewport := root.get_viewport()
	var node3d_viewport := _camera.get_viewport()

	var key := event as InputEventKey
	var editor_settings := EditorInterface.get_editor_settings()

	if event.is_pressed() and (editor_settings.is_shortcut(SHORTCUT_PATH, event) or (key != null and key.keycode == KEY_ESCAPE)):
		cache_editor_ui(node3d_viewport)

		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			exit_pilot_mode(_camera, canvas_viewport, node3d_viewport)
		elif key != null and key.keycode != KEY_ESCAPE:
			enter_pilot_mode(_camera, canvas_viewport, node3d_viewport)

	if canvas_viewport.gui_disable_input:
		return AfterGUIInput.AFTER_GUI_INPUT_PASS

	canvas_viewport.push_input(event)
	return AfterGUIInput.AFTER_GUI_INPUT_STOP


func enter_pilot_mode(_camera: Camera3D, canvas_viewport: Viewport, node3d_viewport: Viewport) -> void:
	var scene_path: String = ProjectSettings.get_setting(SETTING_PATH, DEFAULT_SCENE)

	if not ResourceLoader.exists(scene_path):
		push_warning("Pilot Mode: Scene not found at '%s'." % scene_path)
		return

	var packed_scene := load(scene_path) as PackedScene
	if not packed_scene:
		push_warning("Pilot Mode: Failed to load scene at '%s'." % scene_path)
		return

	var instance := packed_scene.instantiate()
	pilot_node = instance as Node3D
	if not pilot_node:
		push_warning("Pilot Mode: Scene root must be a Node3D (or derived type). Got '%s'." % instance.get_class())
		instance.free()
		return

	var cam := get_pilot_camera()
	if not cam:
		push_warning("Pilot Mode: No Camera3D found in the scene.")
		pilot_node.free()
		pilot_node = null
		return

	canvas_viewport.gui_disable_input = false
	InputMap.load_from_project_settings()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var spawn_transform := _camera.global_transform
	spawn_transform.origin -= spawn_transform.basis.y * SPAWN_Y_OFFSET
	pilot_node.global_transform = spawn_transform

	get_tree().edited_scene_root.add_child(pilot_node)
	pilot_active = true
	_editor_camera = _camera
	_canvas_viewport = canvas_viewport
	_node3d_viewport = node3d_viewport

	RenderingServer.viewport_attach_camera(node3d_viewport.get_viewport_rid(), cam.get_camera_rid())
	set_editor_ui_visible(false)
	pilot_mode_entered.emit()


func exit_pilot_mode(_camera: Camera3D, canvas_viewport: Viewport, node3d_viewport: Viewport) -> void:
	if not pilot_active:
		return

	var cam := get_pilot_camera()
	if cam:
		_camera.global_transform = cam.global_transform

	canvas_viewport.gui_disable_input = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().edited_scene_root.remove_child(pilot_node)
	pilot_node.queue_free()
	pilot_node = null
	pilot_active = false
	was_in_pilot_mode = false
	_editor_camera = null
	_canvas_viewport = null
	_node3d_viewport = null

	RenderingServer.viewport_attach_camera(node3d_viewport.get_viewport_rid(), _camera.get_camera_rid())
	set_editor_ui_visible(true)
	pilot_mode_exited.emit()


func handle_focus_lost() -> void:
	if not pilot_active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	was_in_pilot_mode = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var main_window := EditorInterface.get_base_control()
	if is_instance_valid(main_window):
		main_window.add_child(overlay)
		overlay.visible = true
		overlay.queue_redraw()


func handle_focus_gained() -> void:
	if not was_in_pilot_mode or not pilot_active:
		return

	await get_tree().process_frame
	if not pilot_active:
		return

	var center := Vector2.ZERO
	var viewport := get_viewport()
	if viewport:
		center = viewport.get_visible_rect().size / 2
		viewport.warp_mouse(center)

	simulate_click(center)

	await get_tree().create_timer(FOCUS_RETURN_DELAY).timeout
	if not pilot_active:
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	reset_camera_input()
	was_in_pilot_mode = false

	var main_window := EditorInterface.get_base_control()
	if is_instance_valid(overlay):
		main_window.remove_child(overlay)
		overlay.visible = false


func get_pilot_camera() -> Camera3D:
	if not pilot_node:
		return null
	var cameras := pilot_node.find_children("*", "Camera3D", true)
	return cameras[0] as Camera3D if cameras.size() > 0 else null


func cache_editor_ui(node3d_viewport: Viewport) -> void:
	var ui := node3d_viewport.get_parent().get_parent().get_child(1) as Control
	_active_viewport_ui = {
		"rotation_gizmo": ui.get_child(8).get_child(0),
		"menu": ui.get_child(0).get_child(0).get_child(0),
		"right_nav": ui.get_child(6),
		"left_nav": ui.get_child(7),
	}


func set_editor_ui_visible(visible: bool) -> void:
	if _active_viewport_ui.is_empty():
		return

	var show_nav := false
	if visible:
		show_nav = EditorInterface.get_editor_settings().get_setting(
			"editors/3d/navigation/show_viewport_navigation_gizmo"
		)

	_active_viewport_ui["rotation_gizmo"].visible = visible
	_active_viewport_ui["menu"].visible = visible
	_active_viewport_ui["right_nav"].visible = show_nav if visible else false
	_active_viewport_ui["left_nav"].visible = show_nav if visible else false


func simulate_click(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	Input.parse_input_event(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	Input.parse_input_event(release)


func reset_camera_input() -> void:
	if not pilot_node:
		return
	var event := InputEventMouseMotion.new()
	event.relative = Vector2.ZERO
	Input.parse_input_event(event)


func _on_overlay_draw() -> void:
	var window_size := get_window().get_size()
	overlay.draw_rect(Rect2(0, 0, window_size.x, window_size.y), Color(0, 0, 0, 0.1))
