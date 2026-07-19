class_name StoreNpcInteractionRuntime
extends Node

var store: Node = null
var _pair_cooldowns: Dictionary = {}
var _interaction_counts: Dictionary = {}
var _last_day: int = -1


func setup(store_node: Node) -> void:
	store = store_node
	_last_day = TimeManager.current_day


func process_npc_interactions(delta: float) -> void:
	if store == null:
		return

	_reset_session_counts_if_needed()
	_tick_cooldowns(delta)

	var blueprints := NPCScheduler.get_active_interaction_blueprints()

	if blueprints.is_empty():
		return

	var npcs := _get_interaction_candidates()

	if npcs.size() < 2:
		return

	for blueprint in blueprints:
		if _has_reached_session_limit(blueprint):
			continue

		var pair := _find_interaction_pair(npcs, blueprint)

		if pair.is_empty():
			continue

		if randf() > float(blueprint.get("chance")):
			continue

		if _start_interaction(pair[0], pair[1], blueprint):
			_increment_interaction_count(blueprint)
			_pair_cooldowns[_get_pair_key(pair[0], pair[1])] = float(blueprint.get("cooldown"))
			return


func _reset_session_counts_if_needed() -> void:
	if _last_day == TimeManager.current_day:
		return

	_last_day = TimeManager.current_day
	_pair_cooldowns.clear()
	_interaction_counts.clear()


func _tick_cooldowns(delta: float) -> void:
	for key in _pair_cooldowns.keys():
		_pair_cooldowns[key] = maxf(0.0, float(_pair_cooldowns[key]) - delta)


func _get_interaction_candidates() -> Array[NPC]:
	var candidates: Array[NPC] = []

	for node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as NPC

		if npc == null or not is_instance_valid(npc):
			continue

		if _can_candidate_interact(npc):
			candidates.append(npc)

	return candidates


func _can_candidate_interact(npc: NPC) -> bool:
	if npc.npc_data == null:
		return false

	if npc.npc_data.npc_category != NPCData.NPCCategory.GENERIC:
		return false

	if npc._dialog_timer > 0.0 or npc._interaction_pause_timer > 0.0:
		return false

	return npc.current_state in [
		NPC.State.ENTER,
		NPC.State.WALK_TO_SHELF,
		NPC.State.SEARCH_ITEM,
		NPC.State.BROWSE_ITEM,
		NPC.State.TAKE_ITEM
	]


func _find_interaction_pair(npcs: Array[NPC], blueprint: Resource) -> Array[NPC]:
	var best_pair: Array[NPC] = []
	var best_distance := INF

	for i in npcs.size():
		for j in range(i + 1, npcs.size()):
			var npc_a := npcs[i]
			var npc_b := npcs[j]
			var pair_key := _get_pair_key(npc_a, npc_b)

			if float(_pair_cooldowns.get(pair_key, 0.0)) > 0.0:
				continue

			var distance := npc_a.global_position.distance_to(npc_b.global_position)

			if distance > float(blueprint.get("proximity_radius")) or distance >= best_distance:
				continue

			best_distance = distance
			best_pair = [npc_a, npc_b]

	return best_pair


func _start_interaction(npc_a: NPC, npc_b: NPC, blueprint: Resource) -> bool:
	var positions := _get_facing_positions(npc_a, npc_b, float(blueprint.get("face_distance")))

	if _are_face_positions_clear(positions):
		npc_a.global_position = positions[0]
		npc_b.global_position = positions[1]
		npc_a._movement_route.clear()
		npc_b._movement_route.clear()

	var lines: Array = blueprint.get("dialog_lines")
	var line_a := str(lines[0]) if lines.size() > 0 else "Nice weather for shopping."
	var line_b := str(lines[1]) if lines.size() > 1 else line_a

	var pause_duration := float(blueprint.get("pause_duration"))
	var started_a := npc_a.request_npc_interaction(npc_b, line_a, pause_duration, npc_b.global_position)
	var started_b := npc_b.request_npc_interaction(npc_a, line_b, pause_duration, npc_a.global_position)

	return started_a and started_b


func _get_facing_positions(npc_a: NPC, npc_b: NPC, face_distance: float) -> Array[Vector2]:
	var midpoint := (npc_a.global_position + npc_b.global_position) * 0.5
	var delta := npc_b.global_position - npc_a.global_position
	var half_distance := maxf(4.0, face_distance * 0.5)

	if absf(delta.x) >= absf(delta.y):
		return [
			midpoint + Vector2(-half_distance, 0.0),
			midpoint + Vector2(half_distance, 0.0)
		]

	return [
		midpoint + Vector2(0.0, -half_distance),
		midpoint + Vector2(0.0, half_distance)
	]


func _are_face_positions_clear(positions: Array[Vector2]) -> bool:
	for position in positions:
		if not _is_position_clear(position):
			return false

	return true


func _is_position_clear(position: Vector2) -> bool:
	var space_state: PhysicsDirectSpaceState2D = store.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = position
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = true

	return space_state.intersect_point(query, 1).is_empty()


func _has_reached_session_limit(blueprint: Resource) -> bool:
	return int(_interaction_counts.get(str(blueprint.get("id")), 0)) >= int(blueprint.get("max_per_session"))


func _increment_interaction_count(blueprint: Resource) -> void:
	var id := str(blueprint.get("id"))
	_interaction_counts[id] = int(_interaction_counts.get(id, 0)) + 1


func _get_pair_key(npc_a: NPC, npc_b: NPC) -> String:
	var ids := [str(npc_a.get_instance_id()), str(npc_b.get_instance_id())]
	ids.sort()
	return "%s:%s" % [ids[0], ids[1]]
