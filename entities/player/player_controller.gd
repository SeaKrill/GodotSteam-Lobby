extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var steam_id := 0

@export var sprint_multiplier : float = 1.5
@export var mouse_sensitivity : float = 0.002

@export var fov_base := 86.0
@export var fov_scale := 0.3

@export var bob_freq : float = 2.4
@export var bob_amp : float = 0.08
var _bob := 0.0

@onready var camera = $CameraController/Camera3D
@onready var camera_controller = $CameraController
@onready var body = $CollisionShape3D
@onready var arms = $CameraController/Arms

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	$SteamName.text = Steam.getFriendPersonaName(steam_id)
	camera.current = is_multiplayer_authority()
	set_process_unhandled_input(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if is_multiplayer_authority():
		$SteamName.hide()
		body.hide()
		arms.show()
	
	#Console.add_log("Authority: %s = %s" % [name.to_int(), Steam.getFriendPersonaName(Networking.players[name.to_int()])])
	
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		SceneManager.end_game.emit()
	
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		camera_controller.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
		body.rotation.y = camera_controller.rotation.y
		arms.rotation.x = camera.rotation.x

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (camera_controller.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var _speed = SPEED * sprint_multiplier if Input.is_action_pressed("sprint") else SPEED
	if is_on_floor():
		if direction:
			velocity.x = direction.x * _speed
			velocity.z = direction.z * _speed
		else:
			velocity.x = lerp(velocity.x, direction.x * _speed, delta * 15.0)
			velocity.z = lerp(velocity.z, direction.z * _speed, delta * 15.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * _speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * _speed, delta * 3.0)
		
	_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _head_bob(_bob)
	
	#FOV change on velocity
	#var velocity_clamped = clamp(velocity.length(), 0.5, SPEED * 3.0)
	#var target_fov = fov_base + fov_scale * velocity_clamped
	#camera.fov = lerp(camera.fov, target_fov, delta * 10.0)

	move_and_slide()

func _head_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp
	pos.x = cos(time * bob_freq / 2) * bob_amp
	return pos
