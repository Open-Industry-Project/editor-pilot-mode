@tool
extends CharacterBody3D

@export_category("Default Character")
@export var move_speed: float = 5.0
@export var mouse_sensitivity: float = 0.1
@export var jump_velocity: float = 4.5

var _head: Node3D
var _mouse_input: Vector2 = Vector2.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	if get_tree().edited_scene_root == self:
		return

	_head = $Head
	_head.rotation.y = rotation.y
	_head.rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(90))
	rotation = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if get_tree().edited_scene_root == self:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	var forward := -_head.global_transform.basis.z
	var right := _head.global_transform.basis.x
	var direction := (right * input_dir.x + forward * input_dir.y)
	direction.y = 0
	direction = direction.normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	move_and_slide()

	_head.rotation_degrees.y -= _mouse_input.x * mouse_sensitivity
	_head.rotation_degrees.x -= _mouse_input.y * mouse_sensitivity
	_head.rotation_degrees.x = clamp(_head.rotation_degrees.x, -90.0, 90.0)
	_mouse_input = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_input += event.relative
