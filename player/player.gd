extends CharacterBody3D
class_name player

#Movment
var SPEED: int = 1
const WALK_SPEED: int = 1
const SPRINT_SPEED: int = 3

#Looking around
@onready var head: Node3D = $head_node
@onready var camera: Camera3D = $head_node/Camera3d
var SENS: float = 0.008

#HeadBooping
const BOB_FREQ: int = 10
const BOB_AMP: float = 0.015
var t_bob: float = 0.0
var mouse_mov

@export var armNode: Node3D
@onready var check_door_raycast_3d: RayCast3D = $head_node/Camera3d/CheckDoorRaycast3D

# Only for presentation purposes
@export var flashlight: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	%FlashLight.visible = flashlight

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENS)
		camera.rotate_x(-event.relative.y * SENS)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(70))
	
	# Sprint functionality

	if Input.get_vector("move_left", "move_right", "move_foreward", "move_backward"):
		if Input.is_action_pressed("shift"):
			SPEED = SPRINT_SPEED
		else:
			SPEED = WALK_SPEED
	else:
		SPEED = 0

	if flashlight:
		%FlashLight.rotation.x = lerp_angle(%FlashLight.rotation.x, camera.rotation.x, 0.1)
		%FlashLight.rotation.y = lerp_angle(%FlashLight.rotation.y, head.rotation.y, 0.1)

func _physics_process(delta):
	var input_dir := Input.get_vector("move_left", "move_right", "move_foreward", "move_backward")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply movement
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = lerp(velocity.x, direction.x * SPEED, 0.4)
		velocity.z = lerp(velocity.z, direction.z * SPEED, 0.4)

	move_and_slide()

	# Camera tilt logic
	var tilt_angle = 0.0
	if input_dir.x > 0:  # Moving right
		tilt_angle = -2.0
	elif input_dir.x < 0:  # Moving left
		tilt_angle = 2.0

	# Smoothly interpolate the camera tilt
	camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(tilt_angle), 0.3)

func isLookingAt(group: StringName):
	if check_door_raycast_3d.is_colliding():
		var collider = check_door_raycast_3d.get_collider()
		if collider.is_in_group(group):
			return true
		else:
			return false
	else:
		return false

func getArmNode():
	if armNode != null:
		return armNode
	else:
		printerr("ERROR: RealisticDoor/Arm - variable 'armNode' is empty. Make sure You added 'LeftArm' premade node to the scene and linked it in desired player node.")
		breakpoint

func getPlayerSpeed():
	return SPEED * Input.get_action_strength("move_foreward")
