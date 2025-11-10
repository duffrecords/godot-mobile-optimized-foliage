extends CharacterBody3D

@export var walk_speed = 1.0
@export var turn_speed = 1.0

var direction = Vector3.FORWARD
var shift_pressed = false
var player_height = Vector3(0.0, 1.7, 0.0)
var angular_velocity = Vector3.ZERO
var camera_velocity = Vector3.ZERO

func _input(event):
	if event is InputEventKey:
		shift_pressed = event.shift_pressed


func get_input():
	var forward = Input.is_action_pressed("wasd_forward")
	var backward = Input.is_action_pressed("wasd_backward")
	var left = Input.is_action_pressed("wasd_left")
	var right = Input.is_action_pressed("wasd_right")
	var turn_left = Input.is_action_pressed("ui_left")
	var turn_right = Input.is_action_pressed("ui_right")
	var look_up = Input.is_action_pressed("ui_up")
	var look_down = Input.is_action_pressed("ui_down")
	
	if is_on_floor():
		if forward:
			velocity += walk_speed * -global_transform.basis.z
		elif backward:
			velocity += walk_speed * global_transform.basis.z
		if left:
			velocity += walk_speed * -global_transform.basis.x
		elif right:
			velocity += walk_speed * global_transform.basis.x
	if turn_left:
		angular_velocity.y += turn_speed
	elif turn_right:
		angular_velocity.y -= turn_speed
	else:
		angular_velocity.y *= 0.9
	if look_up:
		if shift_pressed:
			if $Camera3D.position.y < player_height:
				camera_velocity.y += walk_speed * 0.1
		else:
			if $Camera3D.global_transform.basis.z.dot(Vector3.UP) > -0.9:
				angular_velocity.x += turn_speed
	elif look_down:
		if shift_pressed:
			if $Camera3D.position.y > player_height / 2.0:
				camera_velocity.y -= walk_speed * 0.1
		else:
			if $Camera3D.global_transform.basis.z.dot(Vector3.UP) < 0.9:
				angular_velocity.x -= turn_speed
	else:
		velocity.y = 0.0
		angular_velocity.x *= 0.8
		camera_velocity.y *= 0.9
	if velocity.length() < 0.001:
		velocity = Vector3.ZERO
	if angular_velocity.length() < 0.001:
		angular_velocity = Vector3.ZERO
	velocity = velocity.normalized() * clamp(velocity.length(), 0.0, walk_speed * 2.0)
	angular_velocity.x = clamp(angular_velocity.x, -1.0, 1.0)
	angular_velocity.y = clamp(angular_velocity.y, -1.0, 1.0)

func _ready() -> void:
	player_height = $Camera3D.position.y


func _physics_process(delta: float) -> void:
	get_input()
	if angular_velocity.length() > 0.0:
		rotate_object_local(Vector3.UP, angular_velocity.y * delta)
		$Camera3D.rotate_object_local(Vector3.RIGHT, angular_velocity.x * delta)
	if camera_velocity.y != 0.0:
		$Camera3D.position.y += camera_velocity.y * delta
	move_and_slide()
	velocity *= 0.9
