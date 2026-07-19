class_name Cashier
extends StaticBody2D

const CashierCustomerDetector = preload("res://scripts/ui/cashier/runtime/CashierCustomerDetector.gd")
const CashierCheckoutFlow = preload("res://scripts/ui/cashier/runtime/CashierCheckoutFlow.gd")
const CashierStoreOSRenderer = preload("res://scripts/ui/cashier/runtime/CashierStoreOSRenderer.gd")
const CashierCartController = preload("res://scripts/ui/cashier/runtime/CashierCartController.gd")
const CashierStoryFlow = preload("res://scripts/ui/cashier/runtime/CashierStoryFlow.gd")
const CashierHudBridge = preload("res://scripts/ui/cashier/runtime/CashierHudBridge.gd")

const GOOBY_ID: String = "gooby"
const STORY_INTERACTION_TRUST_GAIN: int = 20
const CASHIER_BUTTON_FONT_SIZE: int = 8
const CASHIER_BUTTON_MIN_HEIGHT: float = 20.0
const CASHIER_PRIMARY_BUTTON_WIDTH: float = 118.0
const CASHIER_SECONDARY_BUTTON_WIDTH: float = 96.0
const CASHIER_CLOSE_BUTTON_WIDTH: float = 64.0
const ITEM_SWATCH_SIZE := Vector2(10, 16)
const STORE_OS_APP_POS: StringName = &"pos"

@onready var interaction_area: Area2D = $InteractionArea

signal checkout_done(npc: NPC, item_id: String, price: int)

var _scanned_npc: NPC = null
var _scanned_item_id: String = ""
var _scanned_item_label: String = ""
var _scanned_total: int = 0
var _checkout_history: Array[Dictionary] = []
var _target_item_ids: Array[String] = []
var _cart_quantities: Dictionary = {}
var _pending_item_id: String = ""
var _ask_again_count: int = 0
var _cashier_layer: CanvasLayer = null
var _cashier_panel: ColorRect = null
var _panel_title: Label = null
var _customer_label: Label = null
var _request_label: Label = null
var _selected_label: Label = null
var _guide_label: Label = null
var _item_title: Label = null
var _item_list: VBoxContainer = null
var _item_scroll: ScrollContainer = null
var _action_row: Container = null
var _cashier_lock_active: bool = false
var _seen_panel_guidance: Dictionary = {}
var _active_store_os_app: StringName = STORE_OS_APP_POS

var _customer_detector: CashierCustomerDetector = CashierCustomerDetector.new()
var _checkout_flow: CashierCheckoutFlow = CashierCheckoutFlow.new()
var _store_os_renderer: CashierStoreOSRenderer = CashierStoreOSRenderer.new()
var _cart_controller: CashierCartController = CashierCartController.new()
var _story_flow: CashierStoryFlow = CashierStoryFlow.new()
var _hud_bridge: CashierHudBridge = CashierHudBridge.new()


func _ready() -> void:
	_setup_cashier_controllers()
	_setup_cursor_hover()


func _exit_tree() -> void:
	_unlock_player_actions()


func _setup_cashier_controllers() -> void:
	for controller in [
		_customer_detector,
		_checkout_flow,
		_store_os_renderer,
		_cart_controller,
		_story_flow,
		_hud_bridge
	]:
		controller.setup(self)


func reset_runtime_ui() -> void:
	_hide_cashier_panel()


func try_checkout() -> void:
	if not _is_player_nearby():
		pass
		return

	if _has_scanned_customer():
		pass
		if _cashier_panel != null and _cashier_panel.visible:
			_show_notification("Use the cashier panel.", 0.8)
		elif _scanned_total <= 0:
			_show_scan_panel()
		else:
			_show_paid_panel()
		return

	var first_npc: NPC = _get_first_checkout_npc()
	if first_npc == null:
		pass
		if _has_customer_approaching_counter():
			_show_notification("Customer is still walking to the counter.", 1.2)
		else:
			_show_notification("No customer at checkout.", 0.9)

		_render_empty_pos_app()
		return

	pass
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
		if _active_store_os_app != STORE_OS_APP_POS:
			get_viewport().set_input_as_handled()
			return

		if _scanned_total > 0:
			if _is_story_gift_checkout():
				_show_notification("Choose whether to give the item or refuse Gooby.", 1.0)
			else:
				_process_paid()
		else:
			_on_confirm_scan_pressed()
		get_viewport().set_input_as_handled()


func _is_player_nearby() -> bool:
	return _customer_detector.is_player_nearby()


func _get_first_checkout_npc() -> NPC:
	return _customer_detector.get_first_checkout_npc()


func _has_customer_approaching_counter() -> bool:
	return _customer_detector.has_customer_approaching_counter()


func _process_scan(npc: NPC) -> void:
	_checkout_flow.process_scan(npc)


func _process_paid() -> void:
	_checkout_flow.process_paid()


func _process_gooby_gift() -> void:
	_checkout_flow.process_gooby_gift()


func _process_gooby_refuse() -> void:
	_checkout_flow.process_gooby_refuse()


func _has_scanned_customer() -> bool:
	return _checkout_flow.has_scanned_customer()


func _clear_scan() -> void:
	_checkout_flow.clear_scan()


func _add_history(npc: NPC, item_label: String, total: int, status: String) -> void:
	_checkout_flow.add_history(npc, item_label, total, status)


func get_checkout_history() -> Array[Dictionary]:
	return _checkout_flow.get_checkout_history()


func _render_store_os_home(
	status_text: String = "No customer at checkout.",
	guide_text: String = "Use POS when a customer arrives."
) -> void:
	_store_os_renderer.render_store_os_home(status_text, guide_text)


func _render_pos_app() -> void:
	_store_os_renderer.render_pos_app()


func _show_scan_panel() -> void:
	_store_os_renderer.show_scan_panel()


func _add_cart_rows_to_panel() -> void:
	_store_os_renderer.add_cart_rows_to_panel()


func _create_cart_row(item_id: String) -> Control:
	return _store_os_renderer.create_cart_row(item_id)


func _show_paid_panel() -> void:
	_store_os_renderer.show_paid_panel()


func _show_gooby_choice_panel() -> void:
	_store_os_renderer.show_gooby_choice_panel()


func _on_scan_item_pressed(item_id: String) -> void:
	_cart_controller.on_scan_item_pressed(item_id)


func _on_add_item_pressed() -> void:
	_cart_controller.on_add_item_pressed()


func _on_increment_cart_item_pressed(item_id: String) -> void:
	_cart_controller.on_increment_cart_item_pressed(item_id)


func _on_decrement_cart_item_pressed(item_id: String) -> void:
	_cart_controller.on_decrement_cart_item_pressed(item_id)


func _on_delete_cart_item_pressed(item_id: String) -> void:
	_cart_controller.on_delete_cart_item_pressed(item_id)


func _on_confirm_scan_pressed() -> void:
	_cart_controller.on_confirm_scan_pressed()


func _on_ask_again_pressed() -> void:
	_checkout_flow.on_ask_again_pressed()


func _get_scanned_customer_name() -> String:
	return _checkout_flow.get_scanned_customer_name()


func _get_customer_request_line() -> String:
	return _checkout_flow.get_customer_request_line()


func _get_ask_again_panel_text() -> String:
	return _checkout_flow.get_ask_again_panel_text()


func _show_customer_request_bubble() -> void:
	_checkout_flow.show_customer_request_bubble()


func _set_store_os_app(app_id: StringName) -> void:
	_store_os_renderer.set_store_os_app(app_id)


func _set_item_title(text: String) -> void:
	_store_os_renderer.set_item_title(text)


func _refresh_cashier_item_scroll() -> void:
	_store_os_renderer.refresh_cashier_item_scroll()


func _render_empty_pos_app() -> void:
	_store_os_renderer.render_empty_pos_app()


func _create_scan_item_row(item: ItemData) -> Control:
	return _store_os_renderer.create_scan_item_row(item)


func _create_catalog_item_row(item: ItemData) -> Control:
	return _store_os_renderer.create_catalog_item_row(item)


func _add_app_navigation_buttons() -> void:
	_store_os_renderer.add_app_navigation_buttons()


func _close_store_os() -> void:
	_store_os_renderer.close_store_os()


func _selection_matches_customer() -> bool:
	return _cart_controller.selection_matches_customer()


func _calculate_selected_total() -> int:
	return _cart_controller.calculate_selected_total()


func _get_selected_item_label() -> String:
	return _cart_controller.get_selected_item_label()


func _get_pending_item_label() -> String:
	return _cart_controller.get_pending_item_label()


func _get_item_display_label(item_id: String) -> String:
	return _cart_controller.get_item_display_label(item_id)


func _get_store_items() -> Array[ItemData]:
	return _cart_controller.get_store_items()


func _get_item_shelf_color(item: ItemData) -> Color:
	return _cart_controller.get_item_shelf_color(item)


func _get_item_name(item_id: String) -> String:
	return _cart_controller.get_item_name(item_id)


func _get_item_unit_price(item_id: String) -> int:
	return _cart_controller.get_item_unit_price(item_id)


func _get_cart_item_ids_ordered() -> Array[String]:
	return _cart_controller.get_cart_item_ids_ordered()


func _get_cart_item_ids_expanded() -> Array[String]:
	return _cart_controller.get_cart_item_ids_expanded()


func _get_cart_row_label(item_id: String) -> String:
	return _cart_controller.get_cart_row_label(item_id)


func _get_cart_summary_label() -> String:
	return _cart_controller.get_cart_summary_label()


func _increment_cart_item(item_id: String) -> void:
	_cart_controller.increment_cart_item(item_id)


func _update_selected_label() -> void:
	_cart_controller.update_selected_label()


func _is_story_gift_checkout() -> bool:
	return _story_flow.is_story_gift_checkout()


func _apply_story_interaction_trust(npc: NPC) -> int:
	return _story_flow.apply_story_interaction_trust(npc)


func _is_gooby_npc(npc: NPC) -> bool:
	return _story_flow.is_gooby_npc(npc)


func _request_gooby_slime_follow_up() -> void:
	_story_flow.request_gooby_slime_follow_up()


func _notify_store_gooby_resolved() -> void:
	_story_flow.notify_store_gooby_resolved()


func _ensure_cashier_panel() -> void:
	_store_os_renderer.ensure_cashier_panel()


func _set_panel_guidance_once(key: String, text: String) -> void:
	_store_os_renderer.set_panel_guidance_once(key, text)


func _configure_button_guidance(button: Button, tooltip: String) -> void:
	_store_os_renderer.configure_button_guidance(button, tooltip)


func _add_cashier_action_button(text: String, width: float, tooltip: String, pressed: Callable) -> Button:
	return _store_os_renderer.add_cashier_action_button(text, width, tooltip, pressed)


func _hide_cashier_panel() -> void:
	_store_os_renderer.hide_cashier_panel()


func _clear_container(container: Container) -> void:
	_store_os_renderer.clear_container(container)


func _lock_player_actions() -> void:
	_hud_bridge.lock_player_actions()


func _unlock_player_actions() -> void:
	_hud_bridge.unlock_player_actions()


func _show_notification(text: String, duration: float = 2.0) -> void:
	_hud_bridge.show_notification(text, duration)


func _setup_cursor_hover() -> void:
	_hud_bridge.setup_cursor_hover()


func _on_cursor_mouse_entered() -> void:
	_hud_bridge.on_cursor_mouse_entered()


func _on_cursor_mouse_exited() -> void:
	_hud_bridge.on_cursor_mouse_exited()
