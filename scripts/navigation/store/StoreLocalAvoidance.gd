class_name StoreLocalAvoidance
extends RefCounted

const NEIGHBOR_RADIUS: float = 30.0
const AHEAD_DOT_THRESHOLD: float = 0.15
const STOP_DISTANCE: float = 12.0
const SIDE_STEP_DISTANCE: float = 14.0
const FORWARD_PROBE_DISTANCE: float = 18.0

var _store: Node = null
var _theta: StoreThetaStarPlanner = null


func setup(store: Node, theta: StoreThetaStarPlanner) -> void:
	_store = store
	_theta = theta


func get_adjustment(
	npc: NPC,
	desired_target: Vector2
) -> Dictionary:
	if npc == null or not is_instance_valid(npc):
		return {"target": desired_target, "wait": false}
	if not desired_target.is_finite():
		return {"target": desired_target, "wait": false}
	if not _should_use_avoidance(npc):
		return {"target": desired_target, "wait": false}
	if _store == null or _store.get_tree() == null:
		return {"target": desired_target, "wait": false}

	var desired_direction: Vector2 = npc.global_position.direction_to(desired_target)
	if desired_direction.is_zero_approx():
		return {"target": desired_target, "wait": false}

	var nearest_blocker: NPC = null
	var nearest_distance: float = INF
	for other_variant in _store.get_tree().get_nodes_in_group("npcs"):
		if not (other_variant is NPC):
			continue
		var other: NPC = other_variant as NPC
		if other == npc or not is_instance_valid(other):
			continue
		if other.is_queued_for_deletion():
			continue
		var offset: Vector2 = other.global_position - npc.global_position
		var distance: float = offset.length()
		if distance <= 0.001 or distance > NEIGHBOR_RADIUS:
			continue
		if desired_direction.dot(offset.normalized()) < AHEAD_DOT_THRESHOLD:
			continue
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_blocker = other

	if nearest_blocker == null:
		return {"target": desired_target, "wait": false}

	var relative: Vector2 = nearest_blocker.global_position - npc.global_position
	var perpendicular: Vector2 = Vector2(-desired_direction.y, desired_direction.x)
	var cross_sign: float = signf(desired_direction.cross(relative))
	if is_zero_approx(cross_sign):
		cross_sign = 1.0 if npc.get_instance_id() < nearest_blocker.get_instance_id() else -1.0

	var side_signs: Array[float] = [cross_sign, -cross_sign]
	for side_sign: float in side_signs:
		var sidestep_target: Vector2 = (
			npc.global_position
			+ desired_direction * FORWARD_PROBE_DISTANCE
			- perpendicular * side_sign * SIDE_STEP_DISTANCE
		)
		var context: Dictionary = {
			"npc": npc,
			"agent_radius": 10.5,
			"ignore_start_collision": true,
			"ignore_goal_collision": false
		}
		if _theta != null and _theta.is_direct_path_clear(
			npc.global_position,
			sidestep_target,
			context
		):
			return {
				"target": sidestep_target,
				"wait": false,
				"avoiding": nearest_blocker
			}

	return {
		"target": desired_target,
		"wait": nearest_distance <= STOP_DISTANCE,
		"avoiding": nearest_blocker
	}


func _should_use_avoidance(npc: NPC) -> bool:
	return npc.current_state in [
		NPC.State.WALK_TO_SHELF,
		NPC.State.EXIT
	]
