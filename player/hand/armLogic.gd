extends Node3D
@onready var skeleton_ik_3d: SkeletonIK3D = $hand_001/Skeleton3D/SkeletonIK3D
@onready var visibilityPOI: Marker3D = $visibilityPOI

func armPOI(point3d):
	# not asigned target_node directly to prevent an issue
	skeleton_ik_3d.target_node = point3d.get_path()
	skeleton_ik_3d.start()

func armVisibility(condition: bool):
	armChangedStateAnimation(condition)

func armChangedStateAnimation(condition: bool):
	var animationTween: Tween = get_tree().create_tween()
	if condition == true:
		animationTween.tween_property(skeleton_ik_3d, "influence", 1.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		animationTween.tween_property(skeleton_ik_3d, "influence", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
