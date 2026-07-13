class_name NPC
extends CharacterBody2D

const NPCMovement = preload("res://scripts/npc/NPCMovement.gd")
const NPCCheckoutBehavior = preload("res://scripts/npc/behavior/NPCCheckoutBehavior.gd")
const NPCQueueSystem = preload("res://scripts/npc/behavior/NPCQueueSystem.gd")
const NPCShoppingBehavior = preload("res://scripts/npc/behavior/NPCShoppingBehavior.gd")
const NPCDialogController = preload("res://scripts/npc/presentation/NPCDialogController.gd")
const NPCVisualController = preload("res://scripts/npc/presentation/NPCVisualController.gd")

enum State {
	ENTER,
	WALK_TO_SHELF,
	SEARCH_ITEM,
	BROWSE_ITEM,
	TAKE_ITEM,
	WAIT_IN_QUEUE,
	CHECKOUT,
	EXIT
}

const SPEED: float = 80.0
const ARRIVAL_THRESHOLD: float = 5.0
const ENTER_PAUSE: float = 1.5
const DIALOG_DURATION: float = 2.5
const CHECKOUT_PATIENCE: float = 20.0
const SEARCH_PATIENCE: float = 15.0
const SHELF_SEARCH_MIN_TIME: float = 0.7
const SHELF_VISIT_OFFSET: Vector2 = Vector2(0, 34)
const SHELF_ACTION_DISTANCE: float = 28.0
const QUEUE_ACTION_DISTANCE: float = 14.0

static var current_queue: Array[NPC] = []
static var counter_position: Vector2 = Vector2.ZERO
static var entrance_position: Vector2 = Vector2.ZERO

signal purchase_completed(npc: NPC, item_id: String, price: int)
signal npc_exited(npc: NPC)

var npc_data: NPCData
var current_state: State = State.ENTER
var target_position: Vector2 = Vector2.ZERO
var item_to_buy: String = ""
var item_to_buy_original: String = ""
var queue_position: int = 0
var shopping_list: Array[String] = []
var checkout_total_override: int = -1
var checkout_outcome: String = "paid"

var _browse_item: String = ""
var _cart_items: Array[String] = []
var _enter_pause_timer: float = 0.0
var _dialog_timer: float = 0.0
var _checkout_timer: float = 0.0
var _search_timer: float = 0.0
var _search_announced: bool = false
var _trust_label: Label = null


func _ready() -> void:
	add_to_group("dialog_skip_target")
	_trust_label = get_node_or_null("TrustLabel") as Label
	_update_trust_display()
	_set_dialog_mouse_filter()


func _exit_tree() -> void:
	_disconnect_trust_signal()
	_leave_queue()


func setup(data: NPCData) -> void:
	npc_data = data
	_apply_scripted_metadata()
	_choose_item_to_buy()
	item_to_buy_original = item_to_buy
	_apply_visual()
	_apply_name_label()
	_setup_trust_display()
	_set_state(State.ENTER)


func _physics_process(delta: float) -> void:
	match current_state:
		State.ENTER:
			_process_enter()
		State.WALK_TO_SHELF:
			_process_walk_to_shelf()
		State.SEARCH_ITEM:
			_process_search_item(delta)
		State.BROWSE_ITEM:
			_process_browse_item(delta)
		State.TAKE_ITEM:
			_process_take_item()
		State.WAIT_IN_QUEUE:
			_process_wait_in_queue(delta)
		State.CHECKOUT:
			_process_checkout(delta)
		State.EXIT:
			_process_exit()

	_update_dialog(delta)


func complete_checkout() -> void:
	if checkout_outcome == "reject_return":
		reject_checkout_and_return_items("Boo...")
		return

	var total := get_checkout_total()

	if total > 0:
		purchase_completed.emit(self, item_to_buy, total)
		_show_dialog(BlueprintManager.get_done_dialog(self))

	_finish_checkout_and_exit()


func complete_story_gift(dialog_text: String = "Thank you...") -> void:
	_cart_items.clear()
	_show_dialog(dialog_text)
	_finish_checkout_and_exit()


func reject_checkout_and_return_items(dialog_text: String = "Boo...") -> void:
	_return_cart_items_to_shelf()
	_show_dialog(dialog_text)
	_finish_checkout_and_exit()


func get_checkout_total() -> int:
	return NPCCheckoutBehavior.get_checkout_total(_cart_items, item_to_buy, checkout_total_override)


func get_checkout_item_label() -> String:
	return NPCCheckoutBehavior.get_checkout_item_label(_cart_items, item_to_buy)


func get_cart_item_ids() -> Array[String]:
	return NPCCheckoutBehavior.get_cart_item_ids(_cart_items, item_to_buy)


func repeat_checkout_request() -> void:
	_show_dialog("I'm buying %s." % get_checkout_item_label())


func skip_dialog() -> bool:
	if _dialog_timer <= 0.0:
		return false

	_dialog_timer = 0.0
	_hide_dialog()
	return true


func cancel_checkout_and_leave() -> void:
	_return_cart_items_to_shelf()
	_show_dialog("Never mind. I'll come back later.")
	_finish_checkout_and_exit()


func queue_done() -> void:
	queue_free()


func _apply_name_label() -> void:
	NPCVisualController.apply_name_label(self, npc_data)


func _apply_visual() -> void:
	NPCVisualController.apply_visual(self, npc_data)


func _setup_trust_display() -> void:
	_update_trust_display()

	var trust_callable := Callable(self, "_on_trust_changed")

	if _should_show_trust_display():
		if not RelationshipManager.trust_changed.is_connected(trust_callable):
			RelationshipManager.trust_changed.connect(trust_callable)
	else:
		_disconnect_trust_signal()


func _disconnect_trust_signal() -> void:
	var trust_callable := Callable(self, "_on_trust_changed")

	if RelationshipManager.trust_changed.is_connected(trust_callable):
		RelationshipManager.trust_changed.disconnect(trust_callable)


func _should_show_trust_display() -> bool:
	return (
		npc_data != null
		and npc_data.npc_category == NPCData.NPCCategory.STORY
		and npc_data.npc_id != ""
	)


func _update_trust_display() -> void:
	if _trust_label == null:
		return

	if not _should_show_trust_display():
		_trust_label.visible = false
		return

	var trust_value := RelationshipManager.get_trust(npc_data.npc_id)
	_trust_label.visible = true
	_trust_label.text = "Trust: %d/100" % trust_value


func _on_trust_changed(npc_id: String, _new_trust: int, _delta: int) -> void:
	if npc_data == null or npc_id != npc_data.npc_id:
		return

	_update_trust_display()


func _process_enter() -> void:
	_enter_pause_timer += get_process_delta_time()

	if _enter_pause_timer < ENTER_PAUSE:
		return

	_choose_available_item_to_buy()

	var target_shelf := _find_matching_shelf()

	if target_shelf == null:
		_show_dialog("Nothing I need is on the shelves right now.")
		_dialog_timer = DIALOG_DURATION
		target_position = entrance_position
		_set_state(State.EXIT)
		return

	target_position = _get_shelf_visit_position(target_shelf)
	_set_state(State.WALK_TO_SHELF)


func _process_walk_to_shelf() -> void:
	if global_position.distance_to(target_position) <= SHELF_ACTION_DISTANCE:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_state(State.SEARCH_ITEM)
		return

	if _move_to(target_position):
		_set_state(State.SEARCH_ITEM)


func _process_search_item(delta: float) -> void:
	_search_timer += delta

	if _has_any_requested_item_available():
		if not _search_announced:
			_show_dialog(BlueprintManager.get_item_found_dialog(self))
			_search_announced = true

		if _search_timer < SHELF_SEARCH_MIN_TIME:
			return

		_set_state(State.TAKE_ITEM)
		return

	var action := BlueprintManager.evaluate_no_item_action(self)

	match action:
		BlueprintManager.Action.LEAVE:
			if not _search_announced:
				_show_dialog(BlueprintManager.get_item_not_found_dialog(self))
				_search_announced = true

			if _search_timer >= SEARCH_PATIENCE:
				target_position = entrance_position
				_set_state(State.EXIT)

		BlueprintManager.Action.QUEUE:
			if not _search_announced:
				_show_dialog(BlueprintManager.get_item_not_found_dialog(self))
				_search_announced = true

			if _search_timer >= SEARCH_PATIENCE:
				_show_dialog("Is there any restock coming...? I'll wait here.")
				_search_timer = 0.0
				_search_announced = false
				_join_queue()
				target_position = _get_queue_target()
				_set_state(State.WAIT_IN_QUEUE)

		BlueprintManager.Action.BROWSE_BUY:
			if not _search_announced:
				_show_dialog(BlueprintManager.get_item_not_found_dialog(self))
				_search_announced = true

			if _search_timer >= 5.0:
				var alt_item := _find_alternative_item()

				if alt_item != "":
					_browse_item = alt_item
					item_to_buy = alt_item
					_search_timer = 0.0
					_search_announced = false
					_show_dialog("Oh? This looks good actually.")
					_set_state(State.TAKE_ITEM)
				else:
					target_position = entrance_position
					_set_state(State.EXIT)


func _process_browse_item(delta: float) -> void:
	_search_timer += delta

	if _search_timer < 8.0:
		return

	var alt_item := _find_alternative_item()

	if alt_item != "":
		_browse_item = alt_item
		item_to_buy = alt_item
		_show_dialog("This one will do!")
		_set_state(State.TAKE_ITEM)
	else:
		_show_dialog("Nothing here for me...")
		target_position = entrance_position
		_set_state(State.EXIT)


func _process_take_item() -> void:
	if global_position.distance_to(target_position) > SHELF_ACTION_DISTANCE and not _move_to(target_position):
		return

	if _take_requested_items_from_shelves():
		_join_queue()
		target_position = _get_queue_target()
		_show_dialog("I'll take this.")
		_set_state(State.WAIT_IN_QUEUE)
		return

	_show_dialog("Someone must have taken it already.")
	target_position = entrance_position
	_set_state(State.EXIT)


func _process_wait_in_queue(_delta: float) -> void:
	target_position = _get_queue_target()

	var arrived := global_position.distance_to(target_position) <= QUEUE_ACTION_DISTANCE

	if not arrived:
		arrived = _move_to(target_position)

	if arrived and current_queue.find(self) == 0:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_state(State.CHECKOUT)


func _process_checkout(delta: float) -> void:
	if _checkout_timer == 0.0:
		_show_dialog("I'd like to buy %s." % get_checkout_item_label())

	_checkout_timer += delta

	if npc_data.patience_type == NPCData.PatienceType.IMPATIENT and _checkout_timer >= CHECKOUT_PATIENCE:
		_show_dialog(BlueprintManager.get_checkout_wait_dialog(self))
		_leave_queue()
		_return_item_to_shelf()
		target_position = entrance_position
		_set_state(State.EXIT)


func _process_exit() -> void:
	if _dialog_timer > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _move_to(target_position):
		npc_exited.emit(self)
		queue_done()


func _move_to(target: Vector2) -> bool:
	return NPCMovement.move_to(self, target, SPEED, ARRIVAL_THRESHOLD)


func _choose_item_to_buy() -> void:
	if not shopping_list.is_empty():
		item_to_buy = shopping_list[0]
		return

	if npc_data == null or npc_data.favorite_items.is_empty():
		item_to_buy = ""
		return

	item_to_buy = npc_data.favorite_items[randi() % npc_data.favorite_items.size()]


func _choose_available_item_to_buy() -> void:
	if npc_data == null:
		return

	for shopping_item_id in shopping_list:
		if _find_shelf_with_item(shopping_item_id) != null:
			item_to_buy = shopping_item_id
			item_to_buy_original = item_to_buy
			return

	for favorite_item_id in npc_data.favorite_items:
		var item_id := str(favorite_item_id)

		if _find_shelf_with_item(item_id) != null:
			item_to_buy = item_id
			item_to_buy_original = item_to_buy
			return

	if item_to_buy == "":
		_choose_item_to_buy()


func _find_alternative_item() -> String:
	return NPCShoppingBehavior.find_alternative_item(get_tree(), item_to_buy, item_to_buy_original)


func _join_queue() -> void:
	NPCQueueSystem.join_queue(current_queue, self)


func _leave_queue() -> void:
	NPCQueueSystem.leave_queue(current_queue, self)


func _get_queue_target() -> Vector2:
	return NPCQueueSystem.get_queue_target(current_queue, self, counter_position)


func _return_item_to_shelf() -> void:
	if not _cart_items.is_empty():
		_return_cart_items_to_shelf()
		return

	var item: ItemData = ItemDatabase.get_item(item_to_buy)

	if item == null:
		return

	for shelf in get_tree().get_nodes_in_group("shelves"):
		if shelf is Shelf and shelf.shelf_type == item.shelf_type:
			Inventory.add_item(item_to_buy)
			shelf.place_item(item_to_buy)
			return


func _find_matching_shelf() -> Shelf:
	return NPCShoppingBehavior.find_matching_shelf(get_tree(), item_to_buy)


func _find_shelf_with_item(item_id: String) -> Shelf:
	return NPCShoppingBehavior.find_shelf_with_item(get_tree(), item_id)


func _get_shelf_visit_position(shelf: Shelf) -> Vector2:
	return NPCShoppingBehavior.get_shelf_visit_position(shelf, SHELF_VISIT_OFFSET)


func _apply_scripted_metadata() -> void:
	shopping_list.clear()
	_cart_items.clear()
	checkout_total_override = -1
	checkout_outcome = "paid"

	if npc_data == null:
		return

	if npc_data.has_meta("shopping_list"):
		for item_id in npc_data.get_meta("shopping_list"):
			shopping_list.append(str(item_id))

	if npc_data.has_meta("checkout_total"):
		checkout_total_override = int(npc_data.get_meta("checkout_total"))

	if npc_data.has_meta("checkout_outcome"):
		checkout_outcome = str(npc_data.get_meta("checkout_outcome"))


func _has_any_requested_item_available() -> bool:
	for requested_item_id in _get_requested_items():
		if _find_shelf_with_item(requested_item_id) != null:
			return true

	return false


func _take_requested_items_from_shelves() -> bool:
	_cart_items.clear()

	for requested_item_id in _get_requested_items():
		var shelf := _find_shelf_with_item(requested_item_id)

		if shelf != null and shelf.take_item_for_npc(requested_item_id):
			_cart_items.append(requested_item_id)

	if not _cart_items.is_empty():
		item_to_buy = _cart_items[0]
		return true

	return false


func _get_requested_items() -> Array[String]:
	return NPCShoppingBehavior.get_requested_items(shopping_list, item_to_buy)


func _return_cart_items_to_shelf() -> void:
	for cart_item_id in _cart_items:
		var item: ItemData = ItemDatabase.get_item(cart_item_id)

		if item == null:
			continue

		for shelf in get_tree().get_nodes_in_group("shelves"):
			if shelf is Shelf and shelf.shelf_type == item.shelf_type:
				shelf.stock_item_direct(cart_item_id)
				break

	_cart_items.clear()


func _finish_checkout_and_exit() -> void:
	_dialog_timer = DIALOG_DURATION
	_leave_queue()
	target_position = entrance_position
	_set_state(State.EXIT)


func _set_state(new_state: State) -> void:
	if new_state == State.ENTER:
		_enter_pause_timer = 0.0

	if new_state == State.SEARCH_ITEM:
		_search_timer = 0.0
		_search_announced = false

	if new_state == State.CHECKOUT:
		_checkout_timer = 0.0

	if new_state == State.EXIT:
		_leave_queue()

	current_state = new_state


func _show_dialog(text: String) -> void:
	NPCDialogController.show_dialog(self, npc_data, text)
	_dialog_timer = DIALOG_DURATION


func _update_dialog(delta: float) -> void:
	if _dialog_timer <= 0.0:
		return

	_dialog_timer -= delta

	if _dialog_timer > 0.0:
		return

	_hide_dialog()


func _hide_dialog() -> void:
	NPCDialogController.hide_dialog(self)


func _set_dialog_mouse_filter() -> void:
	NPCDialogController.set_mouse_filter(self)
