extends CharacterBody2D

const ActivityBoard = preload("res://scripts/objects/ActivityBoard.gd")
const PlayerInteraction = preload("res://scripts/player/PlayerInteraction.gd")
const PlayerNotificationBridge = preload("res://scripts/player/PlayerNotificationBridge.gd")
const PlayerShelfInteraction = preload("res://scripts/player/PlayerShelfInteraction.gd")

@export var speed: float = 150.0
@export var interaction_distance: float = 20.0

@onready var interaction_area: Area2D = $InteractionArea

var facing_direction: Vector2 = Vector2.DOWN
var _supply_box_cursor: int = 0
var _wrong_shelf_attempts: Dictionary = {}
var _seen_item_ids: Dictionary = {}

const MAX_WRONG_ATTEMPTS: int = 1
const STORY_INTERACTION_TRUST_GAIN: int = 20


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	_update_interaction_area_position()


func _physics_process(_delta: float) -> void:
	if _is_action_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_dir: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if input_dir != Vector2.ZERO:
		facing_direction = input_dir.normalized()
		_update_interaction_area_position()

	velocity = input_dir * speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if _is_action_locked():
		return

	if event.is_action_pressed("take_shelf_item"):
		_try_take_from_shelf()
		return

	if event.is_action_pressed("interact"):
		_try_interact()


func _update_interaction_area_position() -> void:
	if interaction_area == null:
		return

	interaction_area.position = facing_direction * interaction_distance


func _try_interact() -> void:
	if _is_action_locked():
		return

	var areas: Array[Area2D] = interaction_area.get_overlapping_areas()

	if areas.is_empty():
		_show_notification("Nothing to interact with.", 0.5)
		return

	# Fallback untuk door Storage.
	# Jadi kalau body_entered door gagal, player tetap bisa masuk Storage dengan tombol interact.
	for area in areas:
		if _try_storage_door_interaction(area):
			return

	var best_target: Node = null
	var best_priority: int = 999
	var best_distance: float = INF

	for area in areas:
		var parent: Node = area.get_parent()

		if parent == null:
			continue

		var priority: int = _get_interaction_priority(parent)

		if priority == 999:
			continue

		var distance: float = global_position.distance_squared_to(area.global_position)

		if priority < best_priority:
			best_target = parent
			best_priority = priority
			best_distance = distance
		elif priority == best_priority and distance < best_distance:
			best_target = parent
			best_distance = distance

	if best_target == null:
		_show_notification("Nothing useful here.", 0.5)
		return

	if best_target is NPC:
		_interact_with_npc(best_target as NPC)
		return

	if best_target is Cashier:
		_interact_with_cashier(best_target as Cashier)
		return

	if best_target is SupplyBox:
		_interact_with_supply_box(best_target as SupplyBox)
		return

	if best_target is Shelf:
		_interact_with_shelf(best_target as Shelf)
		return

	if best_target is ActivityBoard:
		_interact_with_activity_board(best_target as ActivityBoard)
		return


func _try_storage_door_interaction(area: Area2D) -> bool:
	var door_type: String = _get_storage_door_type(area)

	if door_type == "":
		return false

	var store: Node = get_tree().get_first_node_in_group("store")

	if store == null:
		return false

	if not store.has_method("request_enter_storage"):
		if door_type != "yard" or not store.has_method("request_enter_yard"):
			return false

	if door_type == "yard" and store.has_method("request_enter_yard"):
		store.call("request_enter_yard", door_type)
		return true

	store.call("request_enter_storage", door_type)
	return true


func _get_storage_door_type(area: Area2D) -> String:
	return PlayerInteraction.get_storage_door_type(area)


func _get_interaction_priority(target: Node) -> int:
	return PlayerInteraction.get_interaction_priority(target)


func _interact_with_npc(npc: NPC) -> void:
	var trust_text := _apply_story_npc_interaction_trust(npc)

	if npc.current_state != NPC.State.CHECKOUT:
		if trust_text != "":
			_show_notification("%s They are busy right now." % trust_text, 1.2)
		else:
			_show_notification("They are busy right now.", 0.7)
		return

	var item_id: String = npc.item_to_buy
	var item: ItemData = ItemDatabase.get_item(item_id)

	if item != null:
		if trust_text != "":
			_show_notification("%s Use the cashier to scan %s." % [trust_text, item.display_name], 1.6)
		else:
			_show_notification("Use the cashier to scan %s." % item.display_name)


func _apply_story_npc_interaction_trust(npc: NPC) -> String:
	if npc == null or npc.npc_data == null:
		return ""

	if npc.npc_data.npc_category != NPCData.NPCCategory.STORY:
		return ""

	RelationshipManager.add_trust(npc.npc_data.npc_id, STORY_INTERACTION_TRUST_GAIN)
	return "%s Trust +%d." % [npc.npc_data.display_name, STORY_INTERACTION_TRUST_GAIN]


func _interact_with_shelf(shelf: Shelf) -> void:
	if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
		_show_notification("Put the shelf down first.", 0.5)
		return

	if not _is_shelf_installed_in_store(shelf):
		_show_notification("Place this shelf in the store first.", 0.8)
		return

	var inventory_items: Dictionary = Inventory.get_all()

	if inventory_items.is_empty():
		_show_notification("No item to place.", 0.6)
		return

	var item_id: String = str(inventory_items.keys()[0])
	var item: ItemData = ItemDatabase.get_item(item_id)

	if item == null:
		_show_notification("That item cannot be stocked yet.", 0.8)
		return

	var result: int = shelf.place_item(item_id)

	if result >= 0:
		_wrong_shelf_attempts.erase(_get_wrong_shelf_key(item_id, shelf))
		_show_notification("Placed %s" % item.display_name, 0.5)
		return

	if item.shelf_type != shelf.shelf_type:
		_handle_wrong_shelf_attempt(item_id, item, shelf)
	elif _is_shelf_full(shelf):
		_show_notification("Shelf is full.", 0.6)
	else:
		_show_notification("Could not place %s." % item.display_name, 0.5)


func _try_take_from_shelf() -> void:
	if _is_action_locked():
		return

	var shelf := _get_best_shelf_target()

	if shelf == null:
		_show_notification("No shelf in reach.", 0.5)
		return

	if not _is_shelf_installed_in_store(shelf):
		_show_notification("Place this shelf in the store first.", 0.8)
		return

	_take_item_from_shelf(shelf)


func _get_best_shelf_target() -> Shelf:
	var areas: Array[Area2D] = interaction_area.get_overlapping_areas()
	var best_shelf: Shelf = null
	var best_distance: float = INF

	for area in areas:
		var parent := area.get_parent()

		if not parent is Shelf:
			continue

		var distance: float = global_position.distance_squared_to(area.global_position)

		if distance < best_distance:
			best_shelf = parent as Shelf
			best_distance = distance

	return best_shelf


func _take_item_from_shelf(shelf: Shelf) -> void:
	var item_id: String = shelf.remove_first_item()

	if item_id == "":
		_show_notification("Shelf is empty.", 0.5)
		return

	var item: ItemData = ItemDatabase.get_item(item_id)

	if item != null:
		_show_notification("Took %s" % item.display_name, 0.5)
	else:
		_show_notification("Took %s" % item_id, 0.5)


func _handle_wrong_shelf_attempt(
	item_id: String,
	item: ItemData,
	shelf: Shelf
) -> void:
	var attempt_key: String = _get_wrong_shelf_key(item_id, shelf)
	var attempts: int = int(_wrong_shelf_attempts.get(attempt_key, 0))

	if attempts >= MAX_WRONG_ATTEMPTS:
		return

	attempts += 1
	_wrong_shelf_attempts[attempt_key] = attempts

	if attempts >= MAX_WRONG_ATTEMPTS:
		await _show_notification_sequence([
			"%s does not fit on this shelf." % item.display_name,
			"Try the %s shelf." % _get_shelf_type_label(item.shelf_type)
		])
	else:
		_show_notification(
			"The item fell off the shelf... (%d/%d)" %
			[attempts, MAX_WRONG_ATTEMPTS]
		)


func _is_shelf_full(shelf: Shelf) -> bool:
	for slot_index in shelf.max_slots:
		if shelf.get_slot_content(slot_index) == "":
			return false

	return true


func _get_shelf_type_label(shelf_type: ItemData.ShelfType) -> String:
	match shelf_type:
		ItemData.ShelfType.HUMAN:
			return "human"
		ItemData.ShelfType.GHOST:
			return "ghost"

	return "matching"


func _get_wrong_shelf_key(item_id: String, shelf: Shelf) -> String:
	return PlayerShelfInteraction.get_wrong_shelf_key(item_id, shelf)


func _is_shelf_installed_in_store(shelf: Shelf) -> bool:
	return PlayerShelfInteraction.is_shelf_installed_in_store(shelf)


func _interact_with_supply_box(box: SupplyBox) -> void:
	var available: Array = box.get_available_items()

	if available.is_empty():
		_show_notification("This box is already empty.")
		return

	if not _is_supply_box_shelf_ready(available):
		_show_notification("maybe I should move the shelf out first")
		return

	_supply_box_cursor = _supply_box_cursor % available.size()

	var item_id: String = str(available[_supply_box_cursor])

	if box.collect_one(item_id):
		var item: ItemData = ItemDatabase.get_item(item_id)

		_show_pickup_notification(item_id, item)

		if not (box is MysterySupplyBox):
			_notify_mystery_taken()

	var updated_available: Array = box.get_available_items()

	if updated_available.size() > 0:
		_supply_box_cursor = (_supply_box_cursor + 1) % updated_available.size()
	else:
		_supply_box_cursor = 0


func _is_supply_box_shelf_ready(available_items: Array) -> bool:
	return PlayerShelfInteraction.is_supply_box_shelf_ready(get_tree(), available_items)


func _has_installed_shelf_type(shelf_type: int) -> bool:
	return PlayerShelfInteraction.has_installed_shelf_type(get_tree(), shelf_type)


func _notify_mystery_taken() -> void:
	var world: Node = get_tree().get_first_node_in_group("store")

	if world == null:
		return

	if world.has_method("on_normal_item_taken"):
		world.on_normal_item_taken()


func _show_pickup_notification(item_id: String, item: ItemData) -> void:
	var item_name := item.display_name if item != null else item_id

	if _seen_item_ids.has(item_id):
		_show_notification("Took %s" % item_name, 0.5)
		return

	_seen_item_ids[item_id] = true

	if item == null:
		_show_notification("Took %s. Press E near a shelf to try stocking it." % item_name, 2.2)
		return

	_show_notification(
		"Took %s. Press E near the %s shelf to stock it. Press Q near a shelf to take stock." %
		[item.display_name, _get_shelf_type_label(item.shelf_type)],
		3.0
	)


func _show_notification(text: String, duration: float = 2.0) -> void:
	PlayerNotificationBridge.show(get_tree(), text, duration)


func _show_notification_sequence(messages: Array[String]) -> void:
	await PlayerNotificationBridge.show_sequence(self, messages)


func _interact_with_cashier(cashier: Cashier) -> void:
	cashier.try_checkout()


func _interact_with_activity_board(activity_board: ActivityBoard) -> void:
	activity_board.open_board()


func _is_action_locked() -> bool:
	return PlayerNotificationBridge.is_action_locked(get_tree())
