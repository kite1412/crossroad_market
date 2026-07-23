class_name PlayerInteractionFlow
extends RefCounted

const STORY_INTERACTION_TRUST_GAIN: int = 20
const GOOBY_ID: String = "gooby"
const IRENE_ID: String = "irene"

var player = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(player_node) -> void:
	player = player_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func try_interact() -> void:
	if player._is_action_locked():
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var areas: Array[Area2D] = player.interaction_area.get_overlapping_areas()

	if areas.is_empty():
		return

	# Fallback untuk door Storage.
	# Jadi kalau body_entered door gagal, player tetap bisa masuk Storage dengan tombol interact.
	for area in areas:
		if player._try_storage_door_interaction(area):
			return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_target := get_best_interaction_target(areas)

	if best_target == null:
		return

	if best_target is NPC:
		interact_with_npc(best_target as NPC)
		return

	if best_target is Cashier:
		interact_with_cashier(best_target as Cashier)
		return

	if best_target is SupplyBox:
		player._interact_with_supply_box(best_target as SupplyBox)
		return

	if best_target is Shelf:
		player._interact_with_shelf(best_target as Shelf)
		return

	if best_target is ActivityBoard:
		interact_with_activity_board(best_target as ActivityBoard)
		return

	if best_target is OpenCloseBoard:
		interact_with_open_close_board(best_target as OpenCloseBoard)
		return

	if best_target is SleepBed:
		interact_with_sleep_bed(best_target as SleepBed)
		return

	if best_target is StorageRestockTerminal:
		interact_with_storage_restock_terminal(best_target as StorageRestockTerminal)
		return

	if best_target is RestockPackage:
		interact_with_restock_package(best_target as RestockPackage)
		return

		if is_npc_feedback_board(best_target):
			interact_with_npc_feedback_board(best_target)
			return


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_storage_door_type(area: Area2D) -> String:
	return PlayerInteraction.get_storage_door_type(area)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_interaction_priority(target: Node) -> int:
	return PlayerInteraction.get_interaction_priority(target)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_best_interaction_target(areas: Array[Area2D]) -> Node:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_target: Node = null
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_priority: int = 999
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_distance: float = INF

	for area in areas:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var target: Node = area
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var priority: int = get_interaction_priority(target)

		if priority == 999:
			target = area.get_parent()

			if target == null:
				continue

			priority = get_interaction_priority(target)

		if priority == 999:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var distance: float = player.global_position.distance_squared_to(area.global_position)

		if priority < best_priority:
			best_target = target
			best_priority = priority
			best_distance = distance
		elif priority == best_priority and distance < best_distance:
			best_target = target
			best_distance = distance

	return best_target


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func interact_with_npc(npc: NPC) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var trust_text := apply_story_npc_interaction_trust(npc)

	if npc.current_state != NPC.State.CHECKOUT:
		if trust_text != "":
			player._show_notification("%s They are busy right now." % trust_text, 1.2)
		else:
			player._show_notification("They are busy right now.", 0.7)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_id: String = npc.item_to_buy
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(item_id)

	if item != null:
		if trust_text != "":
			player._show_notification("%s Use the cashier to scan %s." % [trust_text, item.display_name], 1.6)
		else:
			player._show_notification("Use the cashier to scan %s." % item.display_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_story_npc_interaction_trust(npc: NPC) -> String:
	if npc == null or npc.npc_data == null:
		return ""

	if npc.npc_data.npc_category != NPCData.NPCCategory.STORY:
		return ""

	if npc.npc_data.npc_id == GOOBY_ID:
		return ""
	if TimeManager.current_day == 1 and npc.npc_data.npc_id == IRENE_ID:
		return ""

	RelationshipManager.add_trust(npc.npc_data.npc_id, STORY_INTERACTION_TRUST_GAIN)
	return "%s Trust +%d." % [npc.npc_data.display_name, STORY_INTERACTION_TRUST_GAIN]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func interact_with_open_close_board(board: OpenCloseBoard) -> void:
	if board != null and board.has_method("request_interaction"):
		board.call("request_interaction")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func interact_with_cashier(cashier: Cashier) -> void:
	if player._get_carried_shelf() != null:
		player._show_notification("Put down the shelf first.", 0.8)
		return

	cashier.try_checkout()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func interact_with_activity_board(activity_board: ActivityBoard) -> void:
	if player._get_carried_shelf() != null:
		player._show_notification("Put down the shelf first.", 0.8)
		return

	if activity_board.has_method("request_interaction"):
		activity_board.call("request_interaction")
	else:
		activity_board.open_board()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func interact_with_sleep_bed(sleep_bed: SleepBed) -> void:
	if player._get_carried_shelf() != null:
		player._show_notification("Put down the shelf first.", 0.8)
		return

	sleep_bed.request_interaction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func interact_with_storage_restock_terminal(terminal: StorageRestockTerminal) -> void:
	terminal.request_interaction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func interact_with_restock_package(restock_package: RestockPackage) -> void:
	restock_package.request_interaction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func interact_with_npc_feedback_board(feedback_board: Node) -> void:
	if player._get_carried_shelf() != null:
		player._show_notification("Put down the shelf first.", 0.8)
		return

	if feedback_board.has_method("request_interaction"):
		feedback_board.call("request_interaction")


func is_npc_feedback_board(target: Node) -> bool:
	return (
		target != null
		and target.name == "NpcFeedbackBoard"
		and target.has_method("request_interaction")
	)
