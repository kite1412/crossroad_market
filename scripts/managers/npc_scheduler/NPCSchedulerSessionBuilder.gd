class_name NPCSchedulerSessionBuilder
extends RefCounted

var scheduler: Node = null


func setup(scheduler_node: Node) -> void:
	scheduler = scheduler_node


func generate_schedule(day: int) -> void:
	scheduler._day_schedule.clear()

	for npc in scheduler._npc_database.values():
		if npc.visit_days.is_empty() or day in npc.visit_days:
			scheduler._day_schedule.append(npc)

	scheduler._day_schedule.sort_custom(func(a, b): return a.spawn_order < b.spawn_order)


func generate_customer_sessions_for_day(day: int) -> void:
	scheduler._reset_customer_sessions()

	var human_blueprint := get_customer_session_blueprint(day, scheduler.SESSION_HUMAN)
	var human_pool := build_customer_session_pool(day, human_blueprint)
	scheduler._customer_sessions[scheduler.SESSION_HUMAN] = make_customer_session(human_blueprint, human_pool)

	var night_blueprint := get_customer_session_blueprint(day, scheduler.SESSION_NIGHT)
	var night_pool := build_customer_session_pool(day, night_blueprint)
	scheduler._customer_sessions[scheduler.SESSION_NIGHT] = make_customer_session(night_blueprint, night_pool)


func get_customer_session_blueprint(day: int, session_name: StringName) -> Dictionary:
	if session_name == scheduler.SESSION_HUMAN and day == 1:
		return {
			"customer_count": scheduler.DAY_ONE_CUSTOMER_COUNT,
			"window_start": scheduler.HUMAN_CUSTOMER_START_MINUTES,
			"window_end": scheduler.HUMAN_CUSTOMER_END_MINUTES,
			"min_interval": scheduler.DEFAULT_MIN_INTERVAL_MINUTES,
			"max_interval": scheduler.DEFAULT_MAX_INTERVAL_MINUTES,
			"customer_pool": "day_one_human"
		}

	var customer_count := 0
	var visit_phase := NPCData.VisitPhase.DAY if session_name == scheduler.SESSION_HUMAN else NPCData.VisitPhase.NIGHT

	for npc in scheduler._day_schedule:
		if npc.visit_phase == visit_phase and not scheduler._is_day_one_follow_up_story_npc(day, npc):
			customer_count += 1

	if session_name == scheduler.SESSION_NIGHT and day == 1 and scheduler._npc_database.has("gooby"):
		customer_count += 1

	return {
		"customer_count": customer_count,
		"window_start": scheduler.HUMAN_CUSTOMER_START_MINUTES if session_name == scheduler.SESSION_HUMAN else scheduler.NIGHT_CUSTOMER_START_MINUTES,
		"window_end": scheduler.HUMAN_CUSTOMER_END_MINUTES if session_name == scheduler.SESSION_HUMAN else scheduler.NIGHT_CUSTOMER_END_MINUTES,
		"min_interval": scheduler.DEFAULT_MIN_INTERVAL_MINUTES,
		"max_interval": scheduler.DEFAULT_MAX_INTERVAL_MINUTES,
		"customer_pool": String(session_name)
	}


func build_customer_session_pool(day: int, blueprint: Dictionary) -> Array[NPCData]:
	var pool_name := str(blueprint.get("customer_pool", ""))

	if pool_name == "day_one_human":
		return [
			scheduler._make_day_one_customer("day1_bread_customer", "Customer", ["bread"], scheduler.DAY_ONE_BREAD_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.GENERIC, "paid", NPCData.PatienceType.PATIENT, "npcs/humans/human1"),
			scheduler._make_day_one_customer("day1_water_customer", "Customer", ["water"], scheduler.DAY_ONE_WATER_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.GENERIC, "paid", NPCData.PatienceType.PATIENT, "npcs/humans/human2"),
			scheduler._make_day_one_customer("day1_bandage_customer", "Customer", ["bandage"], scheduler.DAY_ONE_BANDAGE_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.GENERIC, "paid", NPCData.PatienceType.PATIENT, "npcs/humans/human3"),
			scheduler._make_day_one_customer("irene", "Irene", ["painkiller"], scheduler.DAY_ONE_IRENE_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.STORY, "paid", NPCData.PatienceType.PATIENT, "irene")
		]

	var visit_phase := NPCData.VisitPhase.NIGHT if pool_name == String(scheduler.SESSION_NIGHT) else NPCData.VisitPhase.DAY
	var pool := get_customer_npc_data(day, "", visit_phase)
	if visit_phase == NPCData.VisitPhase.NIGHT:
		pool = scheduler._align_night_customer_items(pool)
	pool.shuffle()

	if visit_phase == NPCData.VisitPhase.NIGHT and day == 1:
		var gooby := scheduler._npc_database.get("gooby") as NPCData

		if gooby != null:
			pool.push_front(scheduler._make_day_one_customer_from_data(gooby, "phantom_ice_cream"))

	return pool


func get_customer_npc_data(
	day: int,
	asset_path_prefix: String = "",
	visit_phase: NPCData.VisitPhase = NPCData.VisitPhase.DAY
) -> Array[NPCData]:
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


func make_customer_session(blueprint: Dictionary, pool: Array[NPCData]) -> Dictionary:
	return {
		"pool": pool,
		"slots": build_customer_session_slots(blueprint, pool.size()),
		"index": 0,
		"missed": 0,
		"closed": false
	}


func build_customer_session_slots(blueprint: Dictionary, customer_count: int) -> Array[int]:
	var slots: Array[int] = []

	if customer_count <= 0:
		return slots

	var window_start := int(blueprint.get("window_start", scheduler.HUMAN_CUSTOMER_START_MINUTES))
	var window_end := int(blueprint.get("window_end", scheduler.HUMAN_CUSTOMER_END_MINUTES))
	var average_interval := float(max(0, window_end - window_start)) / float(customer_count)

	for i in customer_count:
		slots.append(window_start + int(round(average_interval * (float(i) + 0.5))))

	return slots
