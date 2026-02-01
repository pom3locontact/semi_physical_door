extends StaticBody3D # You can make it AnimatableBody3D if you want

@export var isLocked: bool = false
@export var isDoubleSided: bool = false
@export var openCloseRangeDegrees: float = 100.0
@export var reversedOpeningSide: bool = false
@export var doorKnobGrab: bool = false
@onready var doorKnobGrabOffset: float = 0.08
@export var playerGroupName: String = "player"
@export var doorHeavines: float = 3.0: # Minimum is 1.0
	set(weight):
		doorHeavines = max(weight, 1.0)
@export var doorOpeningSpeed: float = 40.0
@export var playerSpeedCollisionAdjustment: float = 1.0: # Minimum is 1.0
	set(size):
		playerSpeedCollisionAdjustment = max(size, 1.0)

var collisionSpeedBasedSize: bool = false
@onready var interactionAreaCollision: CollisionShape3D = $HandAnimationArea/CollisionShape3D
@onready var initialCollisionShapeSize: int


var restingAngle: float
var notRestingAngle: float 
var pushing: bool = false
var soundSystemEnabled: bool = false
var justSoundAction: bool = false
var justClosedSoundAction: bool = false
var alrPlaying: bool = false
var noiseDisplacmentAccumulation: float = 0.0

var player_instance: Node3D # do not set any value, it is setted automatic by playerGroupName
var isOnFront: int = 0
var isInArea: bool = false
@onready var openingVelocity: float

var minAngleHingeValue: float # DO NOT TOUCH
var maxAngleHingeValue: float # DO NOT TOUCH

# Hands Point Of Intrests Points
@onready var pointA: Marker3D = $HandPositionPointOfIntrest/PointA
@onready var pointB: Marker3D = $HandPositionPointOfIntrest/PointB
@onready var floating_point: Node3D = $HandPositionPointOfIntrest/FloatingPoint
@onready var doorKnobPoint: Marker3D = $HandPositionPointOfIntrest/DoorKnob


func _ready() -> void:
	optionsResolver()

func optionsResolver():
	if isDoubleSided == true:
		reversedOpeningSide = false
		minAngleHingeValue = -openCloseRangeDegrees + self.rotation_degrees.y
		maxAngleHingeValue = openCloseRangeDegrees + self.rotation_degrees.y
	else:
		if reversedOpeningSide == true:
			maxAngleHingeValue = 0.0 + self.rotation_degrees.y
			minAngleHingeValue = -openCloseRangeDegrees + self.rotation_degrees.y
			restingAngle = maxAngleHingeValue
			notRestingAngle = minAngleHingeValue
		else:
			minAngleHingeValue = 0.0 + self.rotation_degrees.y
			maxAngleHingeValue = openCloseRangeDegrees + self.rotation_degrees.y
			restingAngle = minAngleHingeValue
			notRestingAngle = maxAngleHingeValue

	if playerSpeedCollisionAdjustment != 1.0:
		player_instance = get_tree().get_first_node_in_group("player")
		collisionSpeedBasedSize = true
		initialCollisionShapeSize = interactionAreaCollision.shape.size.z

func _physics_process(delta: float) -> void:
	pushing = false
	if isInArea == true:
		if player_instance.isLookingAt("door"): 
			var playerAcceleration: float = player_instance.getPlayerSpeed()
			
			# I know its getting messy, 3 ifs? Jeez, but what can I do, id
			# need to lerp openingVelocity with desiredVeloctiy to prevent
			# this one playerAcceleration if, but the performance wouldnt be
			# better i suppose. Contribute if You have any ideas on ow to improve this!
			if playerAcceleration != 0:
				openingVelocity = playerAcceleration * doorOpeningSpeed * isOnFront
				pushing = true
	openingVelocity *= exp(-doorHeavines * delta)
	
	if soundSystemEnabled == true:
		move_and_sound(openingVelocity * delta)
		
	self.rotation_degrees.y += openingVelocity * delta
	self.rotation_degrees.y = clamp(self.rotation_degrees.y, minAngleHingeValue, maxAngleHingeValue)
	if collisionSpeedBasedSize == true:
		interactionAreaCollision.shape.size.z = initialCollisionShapeSize + ((playerSpeedCollisionAdjustment * player_instance.getPlayerSpeed()) / 10)

func getHandPOI(player_node: Node3D):
	if doorKnobGrab == false:
		# vector projection
		var AB: Vector3 = pointB.global_position - pointA.global_position
		var AP: Vector3 = player_node.global_position - pointA.global_position
		
		# making it squered of length for vector projection formula
		var ABLengthSqr: float = AB.length_squared()
		
		# caluclating the exact value from the line AB, clamping it to prevent hand going out of bounds
		var t: float = AP.dot(AB) / ABLengthSqr
		var t_clamped: float = clamp(t, 0.0, 1.0)
		
		# sets up floating point to utilize godots great node system insted of complex math :)
		setUpHandPOI(pointA.global_position + AB * t_clamped)
	else:
		setUpHandPOI(doorKnobPoint.global_position)
	
	return floating_point

func setUpHandPOI(pos: Vector3) -> void:
	# red blob manipulation
	if isOnFront == 1:
		floating_point.global_position = pos + floating_point.global_transform.basis.z * doorKnobGrabOffset
	else:
		floating_point.global_position = pos - floating_point.global_transform.basis.z * doorKnobGrabOffset

func _on_hand_animation_area_body_entered(body: Node3D) -> void:
	if body.is_in_group(playerGroupName):
		player_instance = body
		whichDoorSide()
		body.getArmNode().armPOI(getHandPOI(body))
		body.getArmNode().armVisibility(true)
		print("ENTERED")
		if isLocked == false:
			soundSystemEnabled = true
			isInArea = true

func _on_hand_animation_area_body_exited(body: Node3D) -> void:
	if body.is_in_group(playerGroupName):
		player_instance = body
		body.getArmNode().armVisibility(false)
		print("EXITED")
		isInArea = false

func whichDoorSide() -> void:
	if (player_instance.global_position - self.global_position).dot(-self.global_transform.basis.z) > 0:
		isOnFront = -1
	else:
		isOnFront = 1

func unlock() -> void:
	isLocked = false

func lock() -> void:
	isLocked = true

func isDoorLocked() :
	return isLocked

func move_and_sound(doorCurrentSpeed: float) -> void:
	var fixedDoorCurSpeed: float = clampf(abs(doorCurrentSpeed) / 10,0,1)

	# Close / Open Sound Logic, if double sided it will be ignored
	if isDoubleSided == false:
		if self.rotation_degrees.y == restingAngle:
			fixedDoorCurSpeed = 0.0
			# Making sure the front is on the correct opening side.
			var quickCheck: int = 1
			if reversedOpeningSide == true: quickCheck = -1
			if isOnFront == quickCheck:
				if justSoundAction == false || justClosedSoundAction == true:
					justClosedSoundAction = false
					justSoundAction = true
					%OpenDoorSound.play()
			else:
				if justSoundAction == false:
					justSoundAction = true
					justClosedSoundAction = true
					%MovingDoorSound.volume_db = -80.0
					%CloseDoorSound.play()
		elif self.rotation_degrees.y == notRestingAngle:
			fixedDoorCurSpeed = 0.0
		else:
			justSoundAction = false
	else:
		if self.rotation_degrees.y == maxAngleHingeValue || self.rotation_degrees.y == minAngleHingeValue:
			fixedDoorCurSpeed = 0.0

	var lerpedFinalValue: float = lerp(db_to_linear(%MovingDoorSound.volume_db), fixedDoorCurSpeed, 0.2)
	%MovingDoorSound.volume_db = linear_to_db(lerpedFinalValue)
	
	if pushing == false:
		%MovingDoorSound.pitch_scale = lerp(%MovingDoorSound.pitch_scale, 1.0 + fixedDoorCurSpeed, 0.8)
		if alrPlaying == false:
			%MetalScreechSound.pitch_scale = 0.5 + (%MovingDoorSound.pitch_scale / 2)
			doorScreechSound(1/(lerpedFinalValue*400))
	else:
		var fn: FastNoiseLite = FastNoiseLite.new()
		fn.TYPE_VALUE_CUBIC
		var noiseDisplacment = fn.get_noise_1d(noiseDisplacmentAccumulation)
		noiseDisplacmentAccumulation += 0.08
		
		%MovingDoorSound.pitch_scale = lerp(%MovingDoorSound.pitch_scale, 0.9 + fixedDoorCurSpeed + noiseDisplacment, 0.1)

	
func doorScreechSound(TimeBetween: float):
	print("SOUND PLAY")
	alrPlaying = true
	%MetalScreechSound.play()
	var waitTimer: SceneTreeTimer = get_tree().create_timer(TimeBetween)
	waitTimer.timeout.connect(MetalScreechDone)

func MetalScreechDone():
	alrPlaying = false
	print("SINGAL_RECIVED")
