class_name NPCMovement
extends RefCounted


const ORTHOGONAL_TARGET_META: StringName = &"npc_orthogonal_target"
const ORTHOGONAL_AXIS_META: StringName = &"npc_orthogonal_axis"


static func move_to(
	npc: CharacterBody2D,
	target: Vector2,
	speed: float,
	arrival_threshold: float
) -> bool:
	if npc == null:
		return true

	var delta: Vector2 = target - npc.global_position
	if (
		absf(delta.x) <= arrival_threshold
		and absf(delta.y) <= arrival_threshold
	):
		_clear_orthogonal_segment(npc)
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		return true

	var active_target_variant: Variant = npc.get_meta(
		ORTHOGONAL_TARGET_META,
		Vector2.INF
	)
	var active_axis_variant: Variant = npc.get_meta(
		ORTHOGONAL_AXIS_META,
		Vector2.ZERO
	)
	var active_axis: Vector2 = (
		active_axis_variant as Vector2
		if active_axis_variant is Vector2
		else Vector2.ZERO
	)
	var target_changed: bool = (
		not (active_target_variant is Vector2)
		or not (active_target_variant as Vector2).is_equal_approx(target)
	)

	if target_changed or active_axis == Vector2.ZERO:
		active_axis = _select_orthogonal_axis(delta, arrival_threshold)
		npc.set_meta(ORTHOGONAL_TARGET_META, target)
		npc.set_meta(ORTHOGONAL_AXIS_META, active_axis)

	if active_axis.x != 0.0 and absf(delta.x) <= arrival_threshold:
		active_axis = Vector2.DOWN if absf(delta.y) > arrival_threshold else Vector2.ZERO
	elif active_axis.y != 0.0 and absf(delta.y) <= arrival_threshold:
		active_axis = Vector2.RIGHT if absf(delta.x) > arrival_threshold else Vector2.ZERO

	if active_axis == Vector2.ZERO:
		_clear_orthogonal_segment(npc)
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		return true

	npc.set_meta(ORTHOGONAL_AXIS_META, active_axis)
	if active_axis.x != 0.0:
		npc.velocity = Vector2(signf(delta.x) * speed, 0.0)
	else:
		npc.velocity = Vector2(0.0, signf(delta.y) * speed)

	assert(is_zero_approx(npc.velocity.x) or is_zero_approx(npc.velocity.y))
	npc.move_and_slide()
	return false


static func _select_orthogonal_axis(
	delta: Vector2,
	arrival_threshold: float
) -> Vector2:
	var needs_horizontal: bool = absf(delta.x) > arrival_threshold
	var needs_vertical: bool = absf(delta.y) > arrival_threshold

	if needs_horizontal and needs_vertical:
		return Vector2.RIGHT if absf(delta.x) >= absf(delta.y) else Vector2.DOWN
	if needs_horizontal:
		return Vector2.RIGHT
	if needs_vertical:
		return Vector2.DOWN
	return Vector2.ZERO


static func _clear_orthogonal_segment(npc: CharacterBody2D) -> void:
	if npc.has_meta(ORTHOGONAL_TARGET_META):
		npc.remove_meta(ORTHOGONAL_TARGET_META)
	if npc.has_meta(ORTHOGONAL_AXIS_META):
		npc.remove_meta(ORTHOGONAL_AXIS_META)
