class_name PlayerGuidanceFlow
extends RefCounted

var player = null


func setup(player_node) -> void:
	player = player_node


func update_interaction_hint() -> void:
	if player._is_action_locked():
		return

	var areas: Array[Area2D] = player.interaction_area.get_overlapping_areas()
	trigger_interaction_guidance(areas)


func trigger_interaction_guidance(areas: Array[Area2D]) -> void:
	for area in areas:
		var door_type: String = player._get_storage_door_type(area)

		if door_type == "yard":
			show_guided_hint_once(
				"door_transition",
				"Doors move you between locations. Stand near the door and press E."
			)
			return

		if door_type == "yard_return":
			show_guided_hint_once(
				"door_transition",
				"Doors move you between locations. Stand near the door and press E."
			)
			return

		if door_type.ends_with("_return") or door_type == "return":
			show_guided_hint_once(
				"door_transition",
				"Doors move you between locations. Stand near the door and press E."
			)
			return

		if door_type != "":
			show_guided_hint_once(
				"door_transition",
				"Doors move you between locations. Stand near the door and press E."
			)
			return

	var carried_object: Shelf = player._get_carried_shelf()

	if carried_object != null:
		show_guided_hint_once(
			"shelf_place",
			"Carrying %s. Press Q to place it on a clear floor tile." %
			get_object_prompt_name(carried_object)
		)
		return

	var best_target: Node = player._get_best_interaction_target(areas)

	if best_target == null:
		return

	if best_target is NPC:
		show_guided_hint_once(
			"npc_interaction",
			"%s. Press E to talk or check what they need." %
			get_object_prompt_name(best_target)
		)
		return

	if best_target is Cashier:
		show_guided_hint_once(
			"cashier_interaction",
			"Cashier. Press E to scan and serve the front customer."
		)
		return

	if best_target is SupplyBox:
		show_guided_hint_once(
			"supply_box_take_stock",
			"%s. Press E to take one stock item." %
			get_object_prompt_name(best_target)
		)
		return

	if best_target is Shelf:
		trigger_shelf_guidance(best_target as Shelf)
		return

	if best_target is ActivityBoard:
		show_guided_hint_once(
			"activity_board",
			"Activity Board. Press E to read current work guidance."
		)
		return

	if best_target is OpenCloseBoard:
		show_guided_hint_once(
			"open_close_board",
			"Open/Close Board. Press E to flip the store sign."
		)
		return

	if best_target is SleepBed:
		show_guided_hint_once(
			"sleep_bed",
			"Bed. Press E to sleep when the night is over."
		)
		return

	if best_target is StorageRestockTerminal:
		show_guided_hint_once(
			"storage_restock",
			"Storage Restock Terminal. Press E to order stock."
		)
		return

	if best_target is RestockPackage:
		show_guided_hint_once(
			"restock_package",
			"Restock Supply Box. Press E to pick it up."
		)
		return


func trigger_shelf_guidance(shelf: Shelf) -> void:
	var shelf_name := get_object_prompt_name(shelf)

	if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
		show_guided_hint_once(
			"shelf_place",
			"Carrying %s. Press Q to place it on a clear floor tile." % shelf_name
		)
		return

	if not player._is_shelf_installed_in_store(shelf):
		show_guided_hint_once(
			"shelf_pickup",
			"%s. Press E to pick it up, then press Q to place it." % shelf_name
		)
		return

	var inventory_items := Inventory.get_all()
	var has_inventory_item := not inventory_items.is_empty()
	var has_shelf_stock := shelf.has_stock()

	if has_inventory_item and has_shelf_stock:
		show_guided_hint_once(
			"shelf_dual",
			"%s. Press E to move the shelf, or Q to stock your carried item." %
			shelf_name
		)
		return

	if has_inventory_item:
		show_guided_hint_once(
			"shelf_stock",
			"%s. Press Q to put your carried item on this shelf." %
			shelf_name
		)
		return

	if has_shelf_stock:
		show_guided_hint_once(
			"shelf_reposition_stocked",
			"%s. Press E to move the stocked shelf." % shelf_name
		)
		return

	show_guided_hint_once(
		"shelf_pickup",
		"%s. Press E to pick it up, then press Q to place it." % shelf_name
	)


func show_guided_hint_once(key: String, first_time_text: String) -> void:
	if player._seen_guidance_keys.has(key):
		return

	player._seen_guidance_keys[key] = true

	var hud: Node = player.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_hint_dialog"):
		hud.call("show_hint_dialog", key, first_time_text)


func get_object_prompt_name(target: Node) -> String:
	if target is NPC:
		var npc := target as NPC

		if npc.npc_data != null and npc.npc_data.display_name != "":
			return npc.npc_data.display_name

	if target is SupplyBox:
		if target is MysterySupplyBox:
			return "Mystery Box"

		return "Supply Box"

	if target is Shelf:
		var shelf := target as Shelf

		match shelf.shelf_type:
			ItemData.ShelfType.HUMAN:
				return "Human Shelf"
			ItemData.ShelfType.GHOST:
				return "Ghost Shelf"

	var node_name := String(target.name)
	return node_name.capitalize()
