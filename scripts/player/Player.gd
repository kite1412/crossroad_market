extends CharacterBody2D

@export var speed: float = 150.0
@export var interaction_distance: float = 20.0

@onready var interaction_area: Area2D = $InteractionArea

var facing_direction: Vector2 = Vector2.DOWN
var _supply_box_cursor: int = 0
var _wrong_shelf_attempts: Dictionary = {}

const MAX_WRONG_ATTEMPTS: int = 1


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
	if area == null:
		return ""

	if area.has_meta("door_type"):
		return str(area.get_meta("door_type"))

	match String(area.name):
		"StorageDoor", "StorageDoor_Normal":
			return "normal"
		"StorageDoor2", "StorageDoor_Mystery":
			return "mistery"
		_:
			return ""


func _get_interaction_priority(target: Node) -> int:
	if target is Cashier:
		return 0

	if target is NPC:
		return 1

	if target is SupplyBox:
		return 2

	if target is Shelf:
		return 3

	return 999


func _interact_with_npc(npc: NPC) -> void:
	if npc.current_state != NPC.State.CHECKOUT:
		return

	var item_id: String = npc.item_to_buy
	var item: ItemData = ItemDatabase.get_item(item_id)

	if item != null:
		_show_notification("Use the cashier to scan %s." % item.display_name)


func _interact_with_shelf(shelf: Shelf) -> void:
	if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
		_show_notification("Put the shelf down first.", 0.5)
		return

	if not _is_shelf_installed_in_store(shelf):
		return

	var inventory_items: Dictionary = Inventory.get_all()

	if inventory_items.is_empty():
		return

	var item_id: String = str(inventory_items.keys()[0])
	var item: ItemData = ItemDatabase.get_item(item_id)

	if item == null:
		return

	var result: int = shelf.place_item(item_id)

	if result >= 0:
		_wrong_shelf_attempts.erase(_get_wrong_shelf_key(item_id, shelf))

		if item.shelf_type != ItemData.ShelfType.GHOST:
			_show_notification("Placed %s" % item.display_name, 0.5)

		return

	if item.shelf_type != shelf.shelf_type:
		_handle_wrong_shelf_attempt(item_id, item, shelf)
	else:
		_show_notification("Could not place %s." % item.display_name, 0.5)


func _try_take_from_shelf() -> void:
	if _is_action_locked():
		return

	var shelf := _get_best_shelf_target()

	if shelf == null:
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
	_item: ItemData,
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
			"Huh? It keeps falling off from the shelf...",
			"Maybe I should try the other shelf..."
		])
	else:
		_show_notification(
			"The item fell off the shelf... (%d/%d)" %
			[attempts, MAX_WRONG_ATTEMPTS]
		)


func _get_wrong_shelf_key(item_id: String, shelf: Shelf) -> String:
	return "%s_%s" % [item_id, str(shelf.get_instance_id())]


func _is_shelf_installed_in_store(shelf: Shelf) -> bool:
	if shelf == null:
		return false

	if not shelf.has_meta("is_installed_in_store"):
		return true

	return bool(shelf.get_meta("is_installed_in_store"))


func _interact_with_supply_box(box: SupplyBox) -> void:
	var available: Array = box.get_available_items()

	if available.is_empty():
		_show_notification("This box is already empty.")
		return

	_supply_box_cursor = _supply_box_cursor % available.size()

	var item_id: String = str(available[_supply_box_cursor])

	if box.collect_one(item_id):
		var item: ItemData = ItemDatabase.get_item(item_id)

		if item != null:
			_show_pickup_notification(item.display_name)
		else:
			_show_pickup_notification(item_id)

		if not (box is MysterySupplyBox):
			_notify_mystery_taken()

	var updated_available: Array = box.get_available_items()

	if updated_available.size() > 0:
		_supply_box_cursor = (_supply_box_cursor + 1) % updated_available.size()
	else:
		_supply_box_cursor = 0


func _notify_mystery_taken() -> void:
	var world: Node = get_tree().get_first_node_in_group("store")

	if world == null:
		return

	if world.has_method("on_normal_item_taken"):
		world.on_normal_item_taken()


func _show_pickup_notification(item_name: String) -> void:
	_show_notification("Took %s" % item_name, 0.5)


func _show_notification(text: String, duration: float = 2.0) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud == null:
		return

	if hud.has_method("show_notification"):
		hud.call("show_notification", text, duration)


func _show_notification_sequence(messages: Array[String]) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")

	for message in messages:
		_show_notification(message, 2.5)

		if hud != null and hud.has_method("wait_for_notification_finished"):
			await hud.call("wait_for_notification_finished")
		else:
			await get_tree().create_timer(2.65).timeout

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")


func _interact_with_cashier(cashier: Cashier) -> void:
	cashier.try_checkout()


func _is_action_locked() -> bool:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))
