class_name CashierStoreOSRenderer
extends RefCounted

## Adapter between the existing cashier gameplay controllers and the authored
## StoreCashier scene. The old generated CashierPanel payment UI is no longer
## created by this renderer.

const STORE_CASHIER_SCENE: PackedScene = preload(
	"res://scenes/locations/store/cashier/StoreCashier.tscn"
)
const PLAYER_EXIT_DIALOG_DELAY: float = 0.35

var cashier: Cashier = null
var cashier_ui: StoreCashierUI = null
var _player_exit_dialog_serial: int = 0
var _player_exit_dialog_pending: bool = false


func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


func render_store_os_home(
	status_text: String = "No customer at checkout.",
	_guide_text: String = "Use POS when a customer arrives."
) -> void:
	hide_cashier_panel()
	if not status_text.is_empty():
		cashier._show_notification(status_text, 0.9)


func render_pos_app() -> void:
	if not cashier._has_scanned_customer():
		render_empty_pos_app()
	elif cashier._scanned_total > 0:
		show_paid_panel()
	else:
		show_scan_panel()


func show_scan_panel() -> void:
	if _player_exit_dialog_pending:
		return
	ensure_cashier_panel()
	if cashier_ui == null or not cashier._has_scanned_customer():
		return

	cashier._set_store_os_app(cashier.STORE_OS_APP_POS)
	if cashier_ui.has_active_checkout():
		cashier_ui.show_scan_tab()
	else:
		cashier_ui.begin_checkout(cashier._scanned_npc)


func show_paid_panel() -> void:
	if _player_exit_dialog_pending:
		return
	ensure_cashier_panel()
	if cashier_ui == null or not cashier._has_scanned_customer():
		return

	if not cashier_ui.has_active_checkout():
		cashier_ui.begin_checkout(cashier._scanned_npc)
	cashier_ui.show_exchange_tab()


func show_gooby_choice_panel() -> void:
	show_paid_panel()


func render_empty_pos_app() -> void:
	hide_cashier_panel()


func ensure_cashier_panel() -> void:
	if cashier_ui != null and is_instance_valid(cashier_ui):
		cashier._patience_bar = cashier_ui.get_patience_bar()
		return

	var instance := STORE_CASHIER_SCENE.instantiate() as StoreCashierUI
	if instance == null:
		cashier._show_notification("Cashier interface could not be loaded.", 1.4)
		return

	cashier_ui = instance
	cashier_ui.name = "StoreCashierUI"
	cashier.add_child(cashier_ui)
	cashier._patience_bar = cashier_ui.get_patience_bar()
	cashier_ui.payment_requested.connect(_on_payment_requested)
	cashier_ui.free_requested.connect(_on_free_requested)
	cashier_ui.checkout_cancelled.connect(_on_checkout_cancelled)
	cashier_ui.checkout_conversation_started.connect(_on_checkout_conversation_started)
	cashier_ui.player_exit_dialog_requested.connect(_on_player_exit_dialog_requested)


func is_cashier_visible() -> bool:
	return (
		cashier_ui != null
		and is_instance_valid(cashier_ui)
		and cashier_ui.has_active_checkout()
	)


func is_player_exit_dialog_pending() -> bool:
	return _player_exit_dialog_pending


func hide_cashier_panel() -> void:
	if cashier_ui != null and is_instance_valid(cashier_ui):
		cashier_ui.reset_runtime_ui()
	cashier._unlock_player_actions()


func close_store_os() -> void:
	hide_cashier_panel()


func set_store_os_app(app_id: StringName) -> void:
	cashier._active_store_os_app = app_id


func _on_payment_requested(
	total: int,
	item_label: String,
	quantities: Dictionary,
	show_customer_completion_dialog: bool
) -> void:
	_apply_ui_selection(total, item_label, quantities)
	cashier._process_paid(show_customer_completion_dialog)


func _on_free_requested(total: int, item_label: String, quantities: Dictionary) -> void:
	_apply_ui_selection(total, item_label, quantities)
	if cashier._is_story_gift_checkout():
		cashier._process_gooby_gift()
	else:
		cashier._process_free()


func _on_checkout_cancelled() -> void:
	# Closing the UI does not dismiss the queued customer. Interacting with the
	# counter again resumes their checkout from the Scan tab.
	cashier._unlock_player_actions()


func _on_checkout_conversation_started() -> void:
	# The transaction is correct at this point; story dialogue should not consume
	# the remaining customer patience while the player reads it.
	cashier._stop_patience_timer()


func _on_player_exit_dialog_requested(
	messages: Array[String],
	customer: NPC,
	wait_for_customer_exit: bool
) -> void:
	_player_exit_dialog_serial += 1
	_player_exit_dialog_pending = true
	_show_player_exit_dialog(
		messages,
		customer,
		wait_for_customer_exit,
		_player_exit_dialog_serial
	)


func _show_player_exit_dialog(
	messages: Array[String],
	customer: NPC,
	wait_for_customer_exit: bool,
	dialog_serial: int
) -> void:
	var tree := cashier.get_tree()
	if tree == null:
		_player_exit_dialog_pending = false
		return
	var customer_id := ""
	if customer != null and is_instance_valid(customer) and customer.npc_data != null:
		customer_id = customer.npc_data.npc_id

	if (
		wait_for_customer_exit
		and customer != null
		and is_instance_valid(customer)
		and not customer.is_queued_for_deletion()
	):
		await customer.npc_exited
	else:
		# Irene's line intentionally begins while she is walking away.
		await tree.create_timer(PLAYER_EXIT_DIALOG_DELAY).timeout
	if dialog_serial != _player_exit_dialog_serial:
		return

	if cashier == null or not is_instance_valid(cashier):
		_player_exit_dialog_pending = false
		return
	await StoreDialogBridge.show_player_sequence(cashier, messages)
	if dialog_serial == _player_exit_dialog_serial:
		_player_exit_dialog_pending = false
		if not customer_id.is_empty():
			cashier.player_exit_dialog_finished.emit(customer_id)


func _apply_ui_selection(total: int, item_label: String, quantities: Dictionary) -> void:
	cashier._scanned_total = total
	cashier._scanned_item_label = item_label
	cashier._cart_quantities = quantities.duplicate(true)


# Compatibility shims for the old Cashier.gd façade. These can be removed when
# the legacy generated-panel methods are pruned from Cashier.gd.
func add_cart_rows_to_panel() -> void:
	pass


func create_cart_row(_item_id: String) -> Control:
	return Control.new()


func set_item_title(_text: String) -> void:
	pass


func refresh_cashier_item_scroll() -> void:
	pass


func create_scan_item_row(_item: ItemData) -> Control:
	return Control.new()


func create_catalog_item_row(_item: ItemData) -> Control:
	return Control.new()


func add_app_navigation_buttons() -> void:
	pass


func set_panel_guidance_once(_key: String, _text: String) -> void:
	pass


func configure_button_guidance(button: Button, tooltip: String) -> void:
	if button != null:
		button.tooltip_text = tooltip


func add_cashier_action_button(
	text: String,
	width: float,
	tooltip: String,
	pressed: Callable
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = width
	button.tooltip_text = tooltip
	if pressed.is_valid():
		button.pressed.connect(pressed)
	return button


func clear_container(container: Container) -> void:
	if container != null:
		CashierPanel.clear_container(container)
