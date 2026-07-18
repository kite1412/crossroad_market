class_name NPCSchedulerDayOneFactory
extends RefCounted

var scheduler: Node = null


func setup(scheduler_node: Node) -> void:
	scheduler = scheduler_node


func align_night_customer_items(pool: Array[NPCData]) -> Array[NPCData]:
	var aligned_pool: Array[NPCData] = []

	for npc in pool:
		if not is_ghost_or_monster_customer(npc):
			aligned_pool.append(npc)
			continue

		var aligned_npc := npc.duplicate() as NPCData
		aligned_npc.favorite_items = scheduler.NIGHT_STOCK_ITEM_IDS.duplicate()
		aligned_npc.favorite_items.shuffle()
		aligned_pool.append(aligned_npc)

	return aligned_pool


func is_ghost_or_monster_customer(npc: NPCData) -> bool:
	if npc == null or npc.assets_path.is_empty():
		return false

	return (
		npc.assets_path.begins_with("npcs/ghosts/")
		or npc.assets_path.begins_with("npcs/monsters/")
	)


func make_day_one_customer_from_data(npc_data: NPCData, shopping_item: String) -> NPCData:
	var customer := npc_data.duplicate() as NPCData
	customer.set_meta("shopping_list", [shopping_item])
	customer.set_meta("checkout_total", 0)
	customer.set_meta("checkout_outcome", "reject_return")
	return customer


func spawn_day_one_night_monster_customer() -> void:
	if scheduler._day_one_night_monster_spawned or scheduler._day_one_night_monster_follow_up_requested:
		return

	if TimeManager.current_day != 1 or TimeManager.current_phase != TimeManager.Phase.NIGHT:
		return

	scheduler._day_one_night_monster_follow_up_requested = true
	scheduler._day_one_night_monster_spawned = true

	var monster_data := scheduler._npc_database.get("monster_1") as NPCData

	if monster_data == null:
		push_warning("NPCScheduler: monster_1 not found in database")
		return

	var slime := monster_data.duplicate() as NPCData
	slime.set_meta("shopping_list", ["phantom_ice_cream"])
	slime.set_meta("checkout_total", scheduler.DAY_ONE_SLIME_GOLD)
	slime.set_meta("checkout_outcome", "paid")
	scheduler.npc_spawn_requested.emit(slime)


func is_day_one_follow_up_story_npc(day: int, npc_data: NPCData) -> bool:
	return day == 1 and npc_data != null and npc_data.npc_id == "gooby"


func make_day_one_customer(
	npc_id: String,
	display_name: String,
	shopping_items: Array,
	checkout_total: int,
	visit_phase: NPCData.VisitPhase,
	category: NPCData.NPCCategory = NPCData.NPCCategory.GENERIC,
	checkout_outcome: String = "paid",
	patience_type: NPCData.PatienceType = NPCData.PatienceType.PATIENT,
	assets_path: String = ""
) -> NPCData:
	var data := NPCData.new()
	data.npc_id = npc_id
	data.display_name = display_name
	data.npc_category = category
	data.visit_days = [1]
	data.visit_phase = visit_phase
	data.assets_path = assets_path
	data.patience_type = patience_type
	var typed_items: Array[String] = []
	for item in shopping_items:
		typed_items.append(str(item))
	data.favorite_items = typed_items.duplicate()
	data.set_meta("shopping_list", typed_items.duplicate())
	data.set_meta("checkout_total", checkout_total)
	data.set_meta("checkout_outcome", checkout_outcome)
	return data
