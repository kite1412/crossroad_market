extends StaticBody2D

const CashierCheckoutHistory = preload("res://scripts/ui/cashier/CashierCheckoutHistory.gd")
const CashierCheckoutService = preload("res://scripts/ui/cashier/CashierCheckoutService.gd")
const CashierPanel = preload("res://scripts/ui/cashier/CashierPanel.gd")
const NPCQueueSystem = preload("res://scripts/npc/behavior/NPCQueueSystem.gd")

const GOOBY_ID: String = "gooby"
const GOOBY_GIFT_TRUST_GAIN: int = 10

@onready var interaction_area: Area2D = $InteractionArea

signal checkout_done(npc: NPC, item_id: String, price: int)

var _scanned_npc: NPC = null
var _scanned_item_id: String = ""
var _scanned_item_label: String = ""
var _scanned_total: int = 0
var _checkout_history: Array[Dictionary] = []
var _target_item_ids: Array[String] = []
var _selected_item_ids: Array[String] = []
var _ask_again_count: int = 0
var _cashier_layer: CanvasLayer = null
var _cashier_panel: ColorRect = null
var _panel_title: Label = null
var _customer_label: Label = null
var _selected_label: Label = null
var _item_list: VBoxContainer = null
var _action_row: HBoxContainer = null
var _cashier_lock_active: bool = false


func _exit_tree() -> void:
	_unlock_player_actions()


func reset_runtime_ui() -> void:
	_hide_cashier_panel()


func try_checkout() -> void:
	if not _is_player_nearby():
		return

	if _has_scanned_customer():
		if _cashier_panel != null and _cashier_panel.visible:
			_show_notification("Use the cashier panel.", 0.8)
		elif _scanned_total <= 0:
			_show_scan_panel()
		else:
			_show_paid_panel()
		return

	var first_npc: NPC = _get_first_checkout_npc()
	if first_npc == null:
		if _has_customer_approaching_counter():
			_show_notification("Customer is still walking to the counter.", 1.2)
		else:
			print("No customer waiting at counter.")
			_show_notification("No customer waiting at counter.", 1.2)
		return

	_process_scan(first_npc)


func _unhandled_input(event: InputEvent) -> void:
	if _cashier_panel == null or not _cashier_panel.visible:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_hide_cashier_panel()
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		_hide_cashier_panel()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if _scanned_total > 0:
			if _is_story_gift_checkout():
				_show_notification("Choose whether to give the item or refuse Gooby.", 1.0)
			else:
				_process_paid()
		else:
			_on_confirm_scan_pressed()
		get_viewport().set_input_as_handled()


func _is_player_nearby() -> bool:
	if interaction_area == null:
		return false

	for body in interaction_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true

	for area in interaction_area.get_overlapping_areas():
		if area.is_in_group("player"):
			return true

		var parent: Node = area.get_parent()

		if parent != null and parent.is_in_group("player"):
			return true

	return false

func _get_first_checkout_npc() -> NPC:
	NPCQueueSystem.prune_invalid(NPC.current_queue)

	for npc in NPC.current_queue:
		if npc.current_state == NPC.State.CHECKOUT:
			return npc
	return null

func _has_customer_approaching_counter() -> bool:
	for npc in NPC.current_queue:
		if not is_instance_valid(npc):
			continue

		if npc.current_state == NPC.State.WAIT_IN_QUEUE or npc.current_state == NPC.State.CHECKOUT:
			return true

	return false

func _process_scan(npc: NPC) -> void:
	if not is_instance_valid(npc):
		return

	var item_id: String = npc.item_to_buy
	var item_label: String = npc.get_checkout_item_label() if npc.has_method("get_checkout_item_label") else item_id
	var price: int = npc.get_checkout_total() if npc.has_method("get_checkout_total") else 0

	if price <= 0:
		var item_data: ItemData = ItemDatabase.get_item(item_id)

		if item_data != null:
			price = item_data.sell_price
			item_label = item_data.display_name

	if price <= 0:
		push_error("Cashier: item '%s' not found" % item_id)
		return
	_scanned_npc = npc
	_scanned_item_id = item_id
	_scanned_item_label = item_label
	_scanned_total = 0
	_target_item_ids = npc.get_cart_item_ids() if npc.has_method("get_cart_item_ids") else [item_id]
	_selected_item_ids.clear()
	_ask_again_count = 0

	print("SCAN: %s - %dG" % [item_label, price])
	_show_scan_panel()


func _process_paid() -> void:
	if not _has_scanned_customer():
		_clear_scan()
		return

	var npc: NPC = _scanned_npc
	var item_id: String = _scanned_item_id
	var item_label: String = _scanned_item_label
	var price: int = _scanned_total

	if price <= 0:
		_show_notification("Scan items first.", 0.8)
		_show_scan_panel()
		return

	npc.complete_checkout()

	if npc.checkout_outcome == "reject_return":
		_show_notification("Gooby has no human money. The item goes back.", 3.0)
		if NPCScheduler.has_method("spawn_day_one_night_monster_customer"):
			NPCScheduler.spawn_day_one_night_monster_customer()
		_add_history(npc, item_label, 0, "REJECTED")
		_clear_scan()
		return

	checkout_done.emit(npc, item_id, price)
	_add_history(npc, item_label, price, "PAID")
	print("PAID: %s for %dG" % [item_label, price])
	_show_notification("PAID | %s | +%dG" % [item_label, price], 1.4)
	_clear_scan()


func _process_gooby_gift() -> void:
	if not _has_scanned_customer():
		_clear_scan()
		return

	var npc := _scanned_npc
	var item_label := _scanned_item_label

	if npc.has_method("complete_story_gift"):
		npc.complete_story_gift("You'd really give this to me...? Thank you.")
	else:
		npc.complete_checkout()

	RelationshipManager.add_trust(GOOBY_ID, GOOBY_GIFT_TRUST_GAIN)
	_add_history(npc, item_label, 0, "GIFT")
	_show_notification("Gooby Trust +%d | No revenue gained." % GOOBY_GIFT_TRUST_GAIN, 2.0)
	_clear_scan()


func _process_gooby_refuse() -> void:
	if not _has_scanned_customer():
		_clear_scan()
		return

	var npc := _scanned_npc
	var item_label := _scanned_item_label

	if npc.has_method("reject_checkout_and_return_items"):
		npc.reject_checkout_and_return_items("Boo... I understand.")
	else:
		npc.complete_checkout()

	if NPCScheduler.has_method("spawn_day_one_night_monster_customer"):
		NPCScheduler.spawn_day_one_night_monster_customer()

	_add_history(npc, item_label, 0, "REFUSED")
	_show_notification("Refused Gooby. The item returns to the shelf... something else is coming.", 3.0)
	_clear_scan()


func _has_scanned_customer() -> bool:
	return _scanned_npc != null and is_instance_valid(_scanned_npc)


func _clear_scan() -> void:
	_scanned_npc = null
	_scanned_item_id = ""
	_scanned_item_label = ""
	_scanned_total = 0
	_target_item_ids.clear()
	_selected_item_ids.clear()
	_ask_again_count = 0
	_hide_cashier_panel()


func _add_history(npc: NPC, item_label: String, total: int, status: String) -> void:
	CashierCheckoutHistory.add_entry(_checkout_history, npc, item_label, total, status)


func get_checkout_history() -> Array[Dictionary]:
	return _checkout_history.duplicate(true)


func _show_scan_panel() -> void:
	_ensure_cashier_panel()
	_clear_container(_item_list)
	_clear_container(_action_row)
	_lock_player_actions()

	_cashier_panel.visible = true
	_panel_title.text = "SCAN"
	_customer_label.text = "Customer: %s" % _scanned_npc.get_checkout_item_label()

	var store_items: Array[ItemData] = ItemDatabase.get_all_items()

	for item in store_items:
		if item == null:
			continue

		var button := Button.new()
		button.text = "%s  %dG" % [item.display_name, item.sell_price]
		button.toggle_mode = true
		button.button_pressed = item.item_id in _selected_item_ids
		button.pressed.connect(Callable(self, "_on_scan_item_pressed").bind(item.item_id))
		_item_list.add_child(button)

	var confirm_button := Button.new()
	confirm_button.text = "Confirm Scan"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_on_confirm_scan_pressed)
	_action_row.add_child(confirm_button)

	var ask_button := Button.new()
	ask_button.text = "Ask Again %d/3" % _ask_again_count
	ask_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ask_button.pressed.connect(_on_ask_again_pressed)
	_action_row.add_child(ask_button)

	var cancel_button := Button.new()
	cancel_button.text = "Close"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(_hide_cashier_panel)
	_action_row.add_child(cancel_button)

	_update_selected_label()


func _show_paid_panel() -> void:
	if _is_story_gift_checkout():
		_show_gooby_choice_panel()
		return

	_ensure_cashier_panel()
	_clear_container(_item_list)
	_clear_container(_action_row)
	_lock_player_actions()

	_cashier_panel.visible = true
	_panel_title.text = "PAID"
	_customer_label.text = "Total due: %dG" % _scanned_total
	_selected_label.text = "Items: %s" % _scanned_item_label

	var paid_button := Button.new()
	paid_button.text = "Receive Payment"
	paid_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paid_button.pressed.connect(_process_paid)
	_action_row.add_child(paid_button)

	var back_button := Button.new()
	back_button.text = "Back to Scan"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.pressed.connect(_show_scan_panel)
	_action_row.add_child(back_button)


func _show_gooby_choice_panel() -> void:
	_ensure_cashier_panel()
	_clear_container(_item_list)
	_clear_container(_action_row)
	_lock_player_actions()

	_cashier_panel.visible = true
	_panel_title.text = "GOOBY REQUEST"
	_customer_label.text = "Gooby cannot pay with human money."
	_selected_label.text = "Item: %s | Revenue: 0G" % _scanned_item_label

	var gift_button := Button.new()
	gift_button.text = "Give Item (+Trust, +0G)"
	gift_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_button.pressed.connect(_process_gooby_gift)
	_action_row.add_child(gift_button)

	var refuse_button := Button.new()
	refuse_button.text = "Refuse Sale (Return Item)"
	refuse_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refuse_button.pressed.connect(_process_gooby_refuse)
	_action_row.add_child(refuse_button)

	var back_button := Button.new()
	back_button.text = "Back to Scan"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.pressed.connect(_show_scan_panel)
	_action_row.add_child(back_button)


func _on_scan_item_pressed(item_id: String) -> void:
	if item_id in _selected_item_ids:
		_selected_item_ids.erase(item_id)
	else:
		_selected_item_ids.append(item_id)

	_update_selected_label()


func _on_confirm_scan_pressed() -> void:
	if not _selection_matches_customer():
		_show_notification("Scan mismatch. Ask again or fix the list.", 1.2)
		return

	_scanned_total = _calculate_selected_total()
	_scanned_item_label = _get_selected_item_label()
	_show_paid_panel()


func _on_ask_again_pressed() -> void:
	_ask_again_count += 1

	if _ask_again_count > 3:
		if _has_scanned_customer() and _scanned_npc.has_method("cancel_checkout_and_leave"):
			_scanned_npc.cancel_checkout_and_leave()

		_add_history(_scanned_npc, _scanned_item_label, 0, "LEFT")
		_show_notification("Customer left.", 1.2)
		_clear_scan()
		return

	if _has_scanned_customer() and _scanned_npc.has_method("repeat_checkout_request"):
		_scanned_npc.repeat_checkout_request()

	_show_scan_panel()


func _selection_matches_customer() -> bool:
	return CashierCheckoutService.selection_matches_customer(_selected_item_ids, _target_item_ids)


func _calculate_selected_total() -> int:
	return CashierCheckoutService.calculate_total(_selected_item_ids)


func _get_selected_item_label() -> String:
	return CashierCheckoutService.get_item_label(_selected_item_ids)


func _update_selected_label() -> void:
	var total := _calculate_selected_total()
	var label := _get_selected_item_label()
	_selected_label.text = "Selected: %s | Total %dG" % [label if label != "" else "-", total]


func _is_story_gift_checkout() -> bool:
	if not _has_scanned_customer():
		return false

	if _scanned_npc.checkout_outcome != "reject_return":
		return false

	if _scanned_npc.npc_data == null:
		return false

	return _scanned_npc.npc_data.npc_id == GOOBY_ID


func _ensure_cashier_panel() -> void:
	if _cashier_layer != null and is_instance_valid(_cashier_layer):
		return

	var panel_nodes := CashierPanel.ensure(self)
	_cashier_layer = panel_nodes["layer"] as CanvasLayer
	_cashier_panel = panel_nodes["panel"] as ColorRect
	_panel_title = panel_nodes["title"] as Label
	_customer_label = panel_nodes["customer_label"] as Label
	_selected_label = panel_nodes["selected_label"] as Label
	_action_row = panel_nodes["action_row"] as HBoxContainer
	_item_list = panel_nodes["item_list"] as VBoxContainer


func _hide_cashier_panel() -> void:
	if _cashier_panel != null:
		_cashier_panel.visible = false
	_unlock_player_actions()


func _clear_container(container: Container) -> void:
	CashierPanel.clear_container(container)


func _lock_player_actions() -> void:
	if _cashier_lock_active:
		return

	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")
		_cashier_lock_active = true


func _unlock_player_actions() -> void:
	if not _cashier_lock_active:
		return

	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")

	_cashier_lock_active = false


func _show_notification(text: String, duration: float = 2.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration)
