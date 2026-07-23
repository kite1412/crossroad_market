class_name Cashier
extends StaticBody2D


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

@warning_ignore("unused_signal")
signal checkout_done(npc: NPC, item_id: String, price: int)
@warning_ignore("unused_signal")
signal player_exit_dialog_finished(customer_id: String)

@warning_ignore("unused_private_class_variable")
var _scanned_npc: NPC = null
@warning_ignore("unused_private_class_variable")
var _scanned_item_id: String = ""
@warning_ignore("unused_private_class_variable")
var _scanned_item_label: String = ""
@warning_ignore("unused_private_class_variable")
var _scanned_total: int = 0
@warning_ignore("unused_private_class_variable")
var _checkout_history: Array[Dictionary] = []
@warning_ignore("unused_private_class_variable")
var _target_item_ids: Array[String] = []
@warning_ignore("unused_private_class_variable")
var _cart_quantities: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _pending_item_id: String = ""
@warning_ignore("unused_private_class_variable")
var _ask_again_count: int = 0
@warning_ignore("unused_private_class_variable")
var _cashier_layer: CanvasLayer = null
@warning_ignore("unused_private_class_variable")
var _cashier_panel: ColorRect = null
@warning_ignore("unused_private_class_variable")
var _panel_title: Label = null
@warning_ignore("unused_private_class_variable")
var _customer_label: Label = null
@warning_ignore("unused_private_class_variable")
var _request_label: Label = null
@warning_ignore("unused_private_class_variable")
var _selected_label: Label = null
@warning_ignore("unused_private_class_variable")
var _guide_label: Label = null
@warning_ignore("unused_private_class_variable")
var _item_title: Label = null
@warning_ignore("unused_private_class_variable")
var _item_list: VBoxContainer = null
@warning_ignore("unused_private_class_variable")
var _item_scroll: ScrollContainer = null
@warning_ignore("unused_private_class_variable")
var _action_row: Container = null
@warning_ignore("unused_private_class_variable")
var _cashier_lock_active: bool = false
@warning_ignore("unused_private_class_variable")
var _seen_panel_guidance: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _active_store_os_app: StringName = STORE_OS_APP_POS
@warning_ignore("unused_private_class_variable")
var _patience_bar: ProgressBar = null
@warning_ignore("unused_private_class_variable")
var _patience_timer: float = 0.0
@warning_ignore("unused_private_class_variable")
var _patience_duration: float = 0.0
@warning_ignore("unused_private_class_variable")
var _patience_active: bool = false

@warning_ignore("unused_private_class_variable")
var _customer_detector: CashierCustomerDetector = CashierCustomerDetector.new()
@warning_ignore("unused_private_class_variable")
var _checkout_flow: CashierCheckoutFlow = CashierCheckoutFlow.new()
@warning_ignore("unused_private_class_variable")
var _store_os_renderer: CashierStoreOSRenderer = CashierStoreOSRenderer.new()
@warning_ignore("unused_private_class_variable")
var _cart_controller: CashierCartController = CashierCartController.new()
@warning_ignore("unused_private_class_variable")
var _story_flow: CashierStoryFlow = CashierStoryFlow.new()
@warning_ignore("unused_private_class_variable")
var _hud_bridge: CashierHudBridge = CashierHudBridge.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_setup_cashier_controllers()
	_setup_cursor_hover()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process(delta: float) -> void:
	_update_patience_timer(delta)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_patience_timer(delta: float) -> void:
	if not _patience_active:
		return
	if _patience_timer <= 0.0:
		return

	_patience_timer -= delta

	if _patience_bar != null:
		_patience_bar.value = clampf(_patience_timer / _patience_duration, 0.0, 1.0)
		# Color shift: green -> yellow -> red
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var ratio: float = _patience_bar.value
		if ratio > 0.5:
			_patience_bar.modulate = Color(1.0 - (ratio - 0.5) * 2.0, 1.0, 0.3)
		else:
			_patience_bar.modulate = Color(1.0, ratio * 2.0, 0.3)

	if _patience_timer <= 0.0:
		_on_patience_expired()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _start_patience_timer() -> void:
	_patience_duration = SettingsManager.get_patience_duration()
	_patience_timer = _patience_duration
	_patience_active = true
	if _patience_bar != null:
		_patience_bar.visible = true
		_patience_bar.value = 1.0
		_patience_bar.modulate = Color(0.3, 1.0, 0.3)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _stop_patience_timer() -> void:
	_patience_active = false
	_patience_timer = 0.0
	if _patience_bar != null:
		_patience_bar.visible = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_patience_expired() -> void:
	_stop_patience_timer()
	if _has_scanned_customer() and _scanned_npc.has_method("cancel_checkout_and_leave"):
		_scanned_npc.cancel_checkout_and_leave()
	_add_history(_scanned_npc, _scanned_item_label, 0, "LEFT")
	_show_notification("Customer left — waited too long.", 1.6)
	_clear_scan()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _exit_tree() -> void:
	_unlock_player_actions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func reset_runtime_ui() -> void:
	_hide_cashier_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func try_checkout() -> void:
	if (
		_hud_bridge.is_dialog_visible()
		or _store_os_renderer.is_player_exit_dialog_pending()
	):
		return
	if not _is_player_nearby():
		pass
		return

	if _has_scanned_customer():
		pass
		if _store_os_renderer.is_cashier_visible():
			_show_notification("Use the cashier panel.", 0.8)
		elif _scanned_total <= 0:
			_show_scan_panel()
		else:
			_show_paid_panel()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _unhandled_input(event: InputEvent) -> void:
	if _cashier_panel == null or not _cashier_panel.visible:
		return
	if (
		_hud_bridge.is_dialog_visible()
		or _store_os_renderer.is_player_exit_dialog_pending()
	):
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_player_nearby() -> bool:
	return _customer_detector.is_player_nearby()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_first_checkout_npc() -> NPC:
	return _customer_detector.get_first_checkout_npc()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_customer_approaching_counter() -> bool:
	return _customer_detector.has_customer_approaching_counter()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process_scan(npc: NPC) -> void:
	_checkout_flow.process_scan(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process_paid(show_customer_completion_dialog: bool = true) -> void:
	_checkout_flow.process_paid(show_customer_completion_dialog)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process_free() -> void:
	_checkout_flow.process_free()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process_gooby_gift() -> void:
	_checkout_flow.process_gooby_gift()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process_gooby_refuse() -> void:
	_checkout_flow.process_gooby_refuse()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_scanned_customer() -> bool:
	return _checkout_flow.has_scanned_customer()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _clear_scan() -> void:
	_checkout_flow.clear_scan()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _add_history(npc: NPC, item_label: String, total: int, status: String) -> void:
	_checkout_flow.add_history(npc, item_label, total, status)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_checkout_history() -> Array[Dictionary]:
	return _checkout_flow.get_checkout_history()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _render_store_os_home(
	status_text: String = "No customer at checkout.",
	guide_text: String = "Use POS when a customer arrives."
) -> void:
	_store_os_renderer.render_store_os_home(status_text, guide_text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _render_pos_app() -> void:
	_store_os_renderer.render_pos_app()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_scan_panel() -> void:
	_store_os_renderer.show_scan_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _add_cart_rows_to_panel() -> void:
	_store_os_renderer.add_cart_rows_to_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _create_cart_row(item_id: String) -> Control:
	return _store_os_renderer.create_cart_row(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_paid_panel() -> void:
	_store_os_renderer.show_paid_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_gooby_choice_panel() -> void:
	_store_os_renderer.show_gooby_choice_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_scan_item_pressed(item_id: String) -> void:
	_cart_controller.on_scan_item_pressed(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_add_item_pressed() -> void:
	_cart_controller.on_add_item_pressed()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_increment_cart_item_pressed(item_id: String) -> void:
	_cart_controller.on_increment_cart_item_pressed(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_decrement_cart_item_pressed(item_id: String) -> void:
	_cart_controller.on_decrement_cart_item_pressed(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_delete_cart_item_pressed(item_id: String) -> void:
	_cart_controller.on_delete_cart_item_pressed(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_confirm_scan_pressed() -> void:
	_cart_controller.on_confirm_scan_pressed()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_ask_again_pressed() -> void:
	_checkout_flow.on_ask_again_pressed()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_scanned_customer_name() -> String:
	return _checkout_flow.get_scanned_customer_name()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_customer_request_line() -> String:
	return _checkout_flow.get_customer_request_line()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_ask_again_panel_text() -> String:
	return _checkout_flow.get_ask_again_panel_text()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_customer_request_bubble() -> void:
	_checkout_flow.show_customer_request_bubble()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_store_os_app(app_id: StringName) -> void:
	_store_os_renderer.set_store_os_app(app_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_item_title(text: String) -> void:
	_store_os_renderer.set_item_title(text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _refresh_cashier_item_scroll() -> void:
	_store_os_renderer.refresh_cashier_item_scroll()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _render_empty_pos_app() -> void:
	_store_os_renderer.render_empty_pos_app()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _create_scan_item_row(item: ItemData) -> Control:
	return _store_os_renderer.create_scan_item_row(item)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _create_catalog_item_row(item: ItemData) -> Control:
	return _store_os_renderer.create_catalog_item_row(item)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _add_app_navigation_buttons() -> void:
	_store_os_renderer.add_app_navigation_buttons()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _close_store_os() -> void:
	_store_os_renderer.close_store_os()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _selection_matches_customer() -> bool:
	return _cart_controller.selection_matches_customer()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _calculate_selected_total() -> int:
	return _cart_controller.calculate_selected_total()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_selected_item_label() -> String:
	return _cart_controller.get_selected_item_label()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_pending_item_label() -> String:
	return _cart_controller.get_pending_item_label()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_item_display_label(item_id: String) -> String:
	return _cart_controller.get_item_display_label(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_store_items() -> Array[ItemData]:
	return _cart_controller.get_store_items()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_item_shelf_color(item: ItemData) -> Color:
	return _cart_controller.get_item_shelf_color(item)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_item_name(item_id: String) -> String:
	return _cart_controller.get_item_name(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_item_unit_price(item_id: String) -> int:
	return _cart_controller.get_item_unit_price(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_cart_item_ids_ordered() -> Array[String]:
	return _cart_controller.get_cart_item_ids_ordered()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_cart_item_ids_expanded() -> Array[String]:
	return _cart_controller.get_cart_item_ids_expanded()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_cart_row_label(item_id: String) -> String:
	return _cart_controller.get_cart_row_label(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_cart_summary_label() -> String:
	return _cart_controller.get_cart_summary_label()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _increment_cart_item(item_id: String) -> void:
	_cart_controller.increment_cart_item(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_selected_label() -> void:
	_cart_controller.update_selected_label()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_story_gift_checkout() -> bool:
	return _story_flow.is_story_gift_checkout()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_story_interaction_trust(npc: NPC) -> int:
	return _story_flow.apply_story_interaction_trust(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_gooby_npc(npc: NPC) -> bool:
	return _story_flow.is_gooby_npc(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _request_gooby_slime_follow_up() -> void:
	_story_flow.request_gooby_slime_follow_up()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _notify_store_gooby_resolved() -> void:
	_story_flow.notify_store_gooby_resolved()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ensure_cashier_panel() -> void:
	_store_os_renderer.ensure_cashier_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_panel_guidance_once(key: String, text: String) -> void:
	_store_os_renderer.set_panel_guidance_once(key, text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _configure_button_guidance(button: Button, tooltip: String) -> void:
	_store_os_renderer.configure_button_guidance(button, tooltip)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _add_cashier_action_button(text: String, width: float, tooltip: String, pressed: Callable) -> Button:
	return _store_os_renderer.add_cashier_action_button(text, width, tooltip, pressed)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _hide_cashier_panel() -> void:
	_store_os_renderer.hide_cashier_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _clear_container(container: Container) -> void:
	_store_os_renderer.clear_container(container)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _lock_player_actions() -> void:
	_hud_bridge.lock_player_actions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _unlock_player_actions() -> void:
	_hud_bridge.unlock_player_actions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_notification(text: String, duration: float = 2.0) -> void:
	_hud_bridge.show_notification(text, duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_cursor_hover() -> void:
	_hud_bridge.setup_cursor_hover()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_mouse_entered() -> void:
	_hud_bridge.on_cursor_mouse_entered()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_mouse_exited() -> void:
	_hud_bridge.on_cursor_mouse_exited()
