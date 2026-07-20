class_name StoreNpcInteractionRuntime
extends Node

var store: Node = null
@warning_ignore("unused_private_class_variable")
var _pair_cooldowns: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _interaction_counts: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _last_day: int = -1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node
	_last_day = TimeManager.current_day


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_npc_interactions(delta: float) -> void:
	if store == null:
		return

	_reset_session_counts_if_needed()
	_tick_cooldowns(delta)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var blueprints := NPCScheduler.get_active_interaction_blueprints()

	if blueprints.is_empty():
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var npcs := _get_interaction_candidates()

	if npcs.size() < 2:
		return

	for blueprint in blueprints:
		if _has_reached_session_limit(blueprint):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var pair := _find_interaction_pair(npcs, blueprint)

		if pair.is_empty():
			continue

		if randf() > float(blueprint.get("chance")):
			continue

		if _start_interaction(pair[0], pair[1], blueprint):
			_increment_interaction_count(blueprint)
			_pair_cooldowns[_get_pair_key(pair[0], pair[1])] = float(blueprint.get("cooldown"))
			return


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _reset_session_counts_if_needed() -> void:
	if _last_day == TimeManager.current_day:
		return

	_last_day = TimeManager.current_day
	_pair_cooldowns.clear()
	_interaction_counts.clear()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _tick_cooldowns(delta: float) -> void:
	for key in _pair_cooldowns.keys():
		_pair_cooldowns[key] = maxf(0.0, float(_pair_cooldowns[key]) - delta)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_interaction_candidates() -> Array[NPC]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var candidates: Array[NPC] = []

	for node in get_tree().get_nodes_in_group("npcs"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var npc := node as NPC

		if npc == null or not is_instance_valid(npc):
			continue

		if _can_candidate_interact(npc):
			candidates.append(npc)

	return candidates


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_interaction_pair(npcs: Array[NPC], blueprint: Resource) -> Array[NPC]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_pair: Array[NPC] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_distance := INF

	for i in npcs.size():
		for j in range(i + 1, npcs.size()):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var npc_a := npcs[i]
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var npc_b := npcs[j]
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var pair_key := _get_pair_key(npc_a, npc_b)

			if float(_pair_cooldowns.get(pair_key, 0.0)) > 0.0:
				continue

			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var distance := npc_a.global_position.distance_to(npc_b.global_position)

			if distance > float(blueprint.get("proximity_radius")) or distance >= best_distance:
				continue

			best_distance = distance
			best_pair = [npc_a, npc_b]

	return best_pair


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _start_interaction(npc_a: NPC, npc_b: NPC, blueprint: Resource) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var positions := _get_facing_positions(npc_a, npc_b, float(blueprint.get("face_distance")))

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var lines: Array = blueprint.get("dialog_lines")
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var line_a := str(lines[0]) if lines.size() > 0 else "Nice weather for shopping."
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var line_b := str(lines[1]) if lines.size() > 1 else line_a

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var pause_duration := float(blueprint.get("pause_duration"))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var started_a := npc_a.request_npc_interaction(npc_b, line_a, pause_duration, positions[0])
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var started_b := npc_b.request_npc_interaction(npc_a, line_b, pause_duration, positions[1])

	return started_a and started_b


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_facing_positions(npc_a: NPC, npc_b: NPC, face_distance: float) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var midpoint := (
		npc_a.global_position
		+ npc_b.global_position
	) * 0.5

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direction := (
		npc_b.global_position
		- npc_a.global_position
	).normalized()

	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var half_distance := maxf(
		4.0,
		face_distance * 0.5
	)

	return [
		midpoint - direction * half_distance,
		midpoint + direction * half_distance
	]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _are_face_positions_clear(positions: Array[Vector2]) -> bool:
	for position in positions:
		if not _is_position_clear(position):
			return false

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_position_clear(position: Vector2) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var space_state: PhysicsDirectSpaceState2D = store.get_world_2d().direct_space_state
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = position
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = true

	return space_state.intersect_point(query, 1).is_empty()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_reached_session_limit(blueprint: Resource) -> bool:
	return int(_interaction_counts.get(str(blueprint.get("id")), 0)) >= int(blueprint.get("max_per_session"))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _increment_interaction_count(blueprint: Resource) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var id := str(blueprint.get("id"))
	_interaction_counts[id] = int(_interaction_counts.get(id, 0)) + 1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_pair_key(npc_a: NPC, npc_b: NPC) -> String:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var ids := [str(npc_a.get_instance_id()), str(npc_b.get_instance_id())]
	ids.sort()
	return "%s:%s" % [ids[0], ids[1]]
