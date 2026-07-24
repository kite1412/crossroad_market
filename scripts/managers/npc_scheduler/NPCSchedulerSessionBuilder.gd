class_name NPCSchedulerSessionBuilder
extends RefCounted

var scheduler: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(scheduler_node: Node) -> void:
	scheduler = scheduler_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func load_schedule_blueprints() -> void:
	scheduler._schedule_blueprints.clear()

	for path in scheduler.SCHEDULE_BLUEPRINT_PATHS:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var resource := load(path)

		if resource is Resource and resource.get("session_name") != null:
			scheduler._schedule_blueprints.append(resource)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func generate_schedule(day: int) -> void:
	scheduler._day_schedule.clear()

	for npc in scheduler._npc_database.values():
		if npc.visit_days.is_empty() or day in npc.visit_days:
			scheduler._day_schedule.append(npc)

	scheduler._day_schedule.sort_custom(func(a, b): return a.spawn_order < b.spawn_order)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func generate_customer_sessions_for_day(day: int) -> void:
	scheduler._reset_customer_sessions()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var human_blueprint := get_customer_session_blueprint(day, scheduler.SESSION_HUMAN)
	human_blueprint["customer_count"] = scheduler.get_human_customer_count_for_day(day)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var human_pool := build_customer_session_pool(day, human_blueprint)
	human_pool = expand_customer_pool(human_pool, int(human_blueprint.get("customer_count", 0)), day)
	if day == 1:
		human_pool = move_customer_to_end(human_pool, "irene")
	scheduler._customer_sessions[scheduler.SESSION_HUMAN] = make_customer_session(human_blueprint, human_pool)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var night_blueprint := get_customer_session_blueprint(day, scheduler.SESSION_NIGHT)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var night_pool := build_customer_session_pool(day, night_blueprint)
	# Day 1 night is owned by the Gooby story. Its only possible follow-up is
	# the Slime spawned directly by that story after the player rejects Gooby.
	# Do not let the normal night pool add unrelated ghosts or monsters.
	if day == 1:
		night_pool.clear()
	scheduler._customer_sessions[scheduler.SESSION_NIGHT] = make_customer_session(night_blueprint, night_pool)



@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_customer_session_blueprint(day: int, session_name: StringName) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var configured_blueprint := find_schedule_blueprint(day, session_name)

	if configured_blueprint != null:
		return schedule_blueprint_to_dictionary(configured_blueprint)

	if session_name == scheduler.SESSION_HUMAN and day == 1:
		return {
			"customer_count": scheduler.DAY_ONE_CUSTOMER_COUNT,
			"window_start": scheduler.HUMAN_CUSTOMER_START_MINUTES,
			"window_end": scheduler.HUMAN_CUSTOMER_END_MINUTES,
			"min_interval": scheduler.DEFAULT_MIN_INTERVAL_MINUTES,
			"max_interval": scheduler.DEFAULT_MAX_INTERVAL_MINUTES,
			"customer_pool": "day_one_human",
			"behavior_blueprints": []
		}

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var customer_count := 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var visit_phase := NPCData.VisitPhase.DAY if session_name == scheduler.SESSION_HUMAN else NPCData.VisitPhase.NIGHT

	for npc in scheduler._day_schedule:
		if npc.visit_phase == visit_phase and not scheduler._is_day_one_follow_up_story_npc(day, npc):
			customer_count += 1

	return {
		"customer_count": customer_count,
		"window_start": scheduler.HUMAN_CUSTOMER_START_MINUTES if session_name == scheduler.SESSION_HUMAN else scheduler.NIGHT_CUSTOMER_START_MINUTES,
		"window_end": scheduler.HUMAN_CUSTOMER_END_MINUTES if session_name == scheduler.SESSION_HUMAN else scheduler.NIGHT_CUSTOMER_END_MINUTES,
		"min_interval": scheduler.DEFAULT_MIN_INTERVAL_MINUTES,
		"max_interval": scheduler.DEFAULT_MAX_INTERVAL_MINUTES,
		"customer_pool": String(session_name),
		"behavior_blueprints": []
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_schedule_blueprint(day: int, session_name: StringName) -> Resource:
	for blueprint in scheduler._schedule_blueprints:
		if int(blueprint.get("day")) == day and StringName(blueprint.get("session_name")) == session_name:
			return blueprint

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func schedule_blueprint_to_dictionary(blueprint: Resource) -> Dictionary:
	return {
		"customer_count": int(blueprint.get("customer_count")),
		"window_start": int(blueprint.get("window_start")),
		"window_end": int(blueprint.get("window_end")),
		"min_interval": int(blueprint.get("min_interval")),
		"max_interval": int(blueprint.get("max_interval")),
		"customer_pool": str(blueprint.get("customer_pool")),
		"behavior_blueprints": blueprint.get("behavior_blueprints")
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func build_customer_session_pool(day: int, blueprint: Dictionary) -> Array[NPCData]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var pool_name := str(blueprint.get("customer_pool", ""))

	if pool_name == "day_one_human":
		return [
			scheduler._make_day_one_customer("day1_bread_customer", "Customer", ["hum_047"], scheduler.DAY_ONE_BREAD_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.GENERIC, "paid", NPCData.PatienceType.PATIENT, "npcs/humans/human1"),
			scheduler._make_day_one_customer("day1_water_customer", "Customer", ["hum_041"], scheduler.DAY_ONE_WATER_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.GENERIC, "paid", NPCData.PatienceType.PATIENT, "npcs/humans/human2"),
			scheduler._make_day_one_customer("day1_bandage_customer", "Customer", ["hum_098"], scheduler.DAY_ONE_BANDAGE_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.GENERIC, "paid", NPCData.PatienceType.PATIENT, "npcs/humans/human3"),
			scheduler._make_day_one_customer("irene", "Irene", ["hum_099"], scheduler.DAY_ONE_IRENE_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.STORY, "paid", NPCData.PatienceType.PATIENT, "irene")
		]

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var visit_phase := NPCData.VisitPhase.NIGHT if pool_name == String(scheduler.SESSION_NIGHT) else NPCData.VisitPhase.DAY
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var pool := get_customer_npc_data(day, "", visit_phase)
	if visit_phase == NPCData.VisitPhase.NIGHT:
		pool = scheduler._align_night_customer_items(pool)
	pool.shuffle()

	return pool


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_customer_npc_data(
	day: int,
	asset_path_prefix: String = "",
	visit_phase: NPCData.VisitPhase = NPCData.VisitPhase.DAY
) -> Array[NPCData]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var pool: Array[NPCData] = []

	for npc in scheduler._npc_database.values():
		if npc.visit_phase != visit_phase:
			continue
		if scheduler._is_day_one_follow_up_story_npc(day, npc):
			continue
		if not npc.visit_days.is_empty() and day not in npc.visit_days:
			continue
		if npc.assets_path.is_empty():
			continue
		if not asset_path_prefix.is_empty() and not npc.assets_path.begins_with(asset_path_prefix):
			continue
		if asset_path_prefix.is_empty() and not (
			npc.assets_path.begins_with("npcs/")
			or npc.assets_path == "irene"
			or npc.assets_path == "gooby"
		):
			continue
		pool.append(npc)

	return pool


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func make_customer_session(blueprint: Dictionary, pool: Array[NPCData]) -> Dictionary:
	return {
		"pool": pool,
		"slots": build_customer_session_slots(blueprint, pool.size()),
		"index": 0,
		"missed": 0,
		"closed": false,
		"window_start": int(blueprint.get("window_start", scheduler.HUMAN_CUSTOMER_START_MINUTES)),
		"window_end": int(blueprint.get("window_end", scheduler.HUMAN_CUSTOMER_END_MINUTES)),
		"behavior_blueprints": blueprint.get("behavior_blueprints", []),
		"behavior_counts": {},
		"last_behavior_minutes": {}
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func build_customer_session_slots(blueprint: Dictionary, customer_count: int) -> Array[int]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var slots: Array[int] = []

	if customer_count <= 0:
		return slots

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var window_start := int(blueprint.get("window_start", scheduler.HUMAN_CUSTOMER_START_MINUTES))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var window_end := int(blueprint.get("window_end", scheduler.HUMAN_CUSTOMER_END_MINUTES))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var average_interval := float(max(0, window_end - window_start)) / float(customer_count)

	for i in customer_count:
		slots.append(window_start + int(round(average_interval * (float(i) + 0.5))))

	return slots

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func expand_customer_pool(source_pool: Array[NPCData], desired_count: int, day: int) -> Array[NPCData]:
	if source_pool.is_empty() or desired_count <= 0:
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var repeatable: Array[NPCData] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var story_customers: Array[NPCData] = []

	for npc_data in source_pool:
		if npc_data == null:
			continue

		if npc_data.npc_category == NPCData.NPCCategory.STORY:
			story_customers.append(npc_data)
		else:
			repeatable.append(npc_data)

	if repeatable.is_empty():
		return source_pool.slice(0, mini(desired_count, source_pool.size()))

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result: Array[NPCData] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var generic_target := maxi(0, desired_count - story_customers.size())

	for index in generic_target:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var template := repeatable[index % repeatable.size()]
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var copy := template.duplicate(true) as NPCData
		copy.npc_id = "%s_day_%d_visit_%d" % [template.npc_id, day, index]
		copy.spawn_order = index
		result.append(copy)

	for story_npc in story_customers:
		if result.size() >= desired_count:
			break
		var story_visit := story_npc.duplicate(true) as NPCData
		story_visit.spawn_order = result.size()
		result.append(story_visit)

	return result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func move_customer_to_end(pool: Array[NPCData], npc_id: String) -> Array[NPCData]:
	var result: Array[NPCData] = pool.duplicate()
	for index in range(result.size() - 1, -1, -1):
		var npc_data: NPCData = result[index]
		if npc_data != null and npc_data.npc_id == npc_id:
			result.remove_at(index)
			result.append(npc_data)
			break

	return result
