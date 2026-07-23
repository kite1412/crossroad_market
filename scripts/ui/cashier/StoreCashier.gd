class_name StoreCashierUI
extends Node2D

## The replacement cashier UI.  It is intentionally independent of Cashier.gd
## so the old checkout can remain active until this scene is swapped in.

signal payment_requested(
	total: int,
	item_label: String,
	quantities: Dictionary,
	show_customer_completion_dialog: bool
)
signal free_requested(total: int, item_label: String, quantities: Dictionary)
signal checkout_cancelled()
signal checkout_conversation_started()
signal player_exit_dialog_requested(
	messages: Array[String],
	customer: NPC,
	wait_for_customer_exit: bool
)

const UI_LAYER: int = 12
const ITEM_CARD_SIZE := Vector2(48, 15)
const ITEM_GRID_GAP: int = 1
const CATALOG_VIEW_RECT := Rect2(2, 211, 97, 55)
const CATALOG_SCROLL_RECT := Rect2(100.5, 211.5, 5, 55)
const CATALOG_SCROLL_STEP: float = 16.0
const CATALOG_CARD_FONT_SIZE: int = 4
const CATALOG_ICON_SCALE := Vector2(0.45, 0.45)
const CATALOG_TEXT_RECT := Rect2(12, 1, 32, 6)
const SMALL_FONT_SIZE: int = 7
const BODY_FONT_SIZE: int = 8
const ITEM_CARD_TEXTURE: Texture2D = preload("res://assets/cashier/item-card.png")
const PLAYER_PORTRAIT: Texture2D = preload("res://assets/characters/player/portrait.png")
const POST_PAYMENT_EXCHANGE_NODE_NAMES := [
	&"MainFrame",
	&"Dialog",
	&"DialogNextButton",
	&"PortraitAnimation",
]

@onready var _scan_tab: Node2D = $StoreCashier
@onready var _exchange_tab: Node2D = $CashierExchangeTab
@onready var _scan_patience_bar: ProgressBar = $StoreCashier/PatienceBar
@onready var _exchange_patience_bar: ProgressBar = $CashierExchangeTab/PatienceBar

var _ui_layer: CanvasLayer
var _scan_list: Control
var _scan_rows: GridContainer
var _scan_scrollbar: Control
var _scan_scroll_thumb: ColorRect
var _catalog_scroll_value: float = 0.0
var _catalog_scroll_max: float = 0.0
var _catalog_thumb_dragging: bool = false
var _catalog_thumb_drag_offset: float = 0.0
var _scan_cart: ScrollContainer
var _scan_cart_rows: VBoxContainer
var _scan_total: Label
var _customer_cash_label: Label
var _scan_continue: Button
var _exchange_cart_rows: VBoxContainer
var _exchange_total: Label
var _exchange_hint: Label
var _exchange_input: Label
var _scan_dialog: Label
var _exchange_dialog: Label
var _exchange_dialog_next: Button
var _scan_portrait: PortraitAnimation
var _exchange_portrait: PortraitAnimation

var _customer: NPC
var _target_item_ids: Array[String] = []
var _cart_quantities: Dictionary[String, int] = {}
var _customer_cash: int = 0
var _total: int = 0
var _change_due: int = 0
var _entered_change: String = ""
var _portrait_texture: Texture2D
var _action_lock_active: bool = false
var _inventory_panel: CanvasItem
var _inventory_was_visible: bool = true
var _inventory_hidden_by_cashier: bool = false
var _cashier_conversation: CashierConversationData
var _checkout_conversation_active: bool = false
var _checkout_conversation_index: int = -1
var _checkout_conversation_lines: Array[CashierDialogueLine] = []
var _exchange_default_visibility: Dictionary = {}
var _active_conditional_conversation_id: String = ""
var _shown_conditional_conversations_by_day: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "CashierUILayer"
	_ui_layer.layer = UI_LAYER
	add_child(_ui_layer)
	_scan_tab.reparent(_ui_layer, false)
	_exchange_tab.reparent(_ui_layer, false)

	_build_scan_tab()
	_build_exchange_tab()
	_ui_layer.visible = false
	_hide_inventory_panel()


func _process(_delta: float) -> void:
	# Cashier.gd owns the timer and updates the Scan bar. Mirror that state so
	# changing tabs preserves the exact remaining time and green/yellow/red tint.
	if _scan_patience_bar == null or _exchange_patience_bar == null:
		return
	_exchange_patience_bar.value = _scan_patience_bar.value
	_exchange_patience_bar.visible = (
		false if _checkout_conversation_active else _scan_patience_bar.visible
	)
	_exchange_patience_bar.modulate = _scan_patience_bar.modulate


func get_patience_bar() -> ProgressBar:
	return _scan_patience_bar


## Starts a checkout for an NPC.  This is the hand-off point when replacing
## Cashier.gd's runtime flow.
func begin_checkout(npc: NPC) -> bool:
	if npc == null or not is_instance_valid(npc):
		return false
	if _is_hud_dialog_visible():
		return false

	_customer = npc
	_target_item_ids = npc.get_cart_item_ids() if npc.has_method("get_cart_item_ids") else [npc.item_to_buy]
	var valid_target_item_ids: Array[String] = []
	for item_id in _target_item_ids:
		if not item_id.is_empty():
			valid_target_item_ids.append(item_id)
	_target_item_ids = valid_target_item_ids
	if _target_item_ids.is_empty():
		_show_notification("This customer has no items to scan.")
		return false

	_cart_quantities.clear()
	_total = 0
	_change_due = 0
	_entered_change = ""
	_reset_checkout_conversation()
	_cashier_conversation = _resolve_cashier_conversation(npc)
	# Checkout totals may be overridden for scripted customers. Always fund the
	# customer against the actual prices of every item they are buying as well.
	var minimum_cash: int = maxi(
		_get_target_total(),
		CashierCheckoutService.calculate_total(_target_item_ids)
	)
	_customer_cash = _get_customer_cash(npc, minimum_cash)
	_portrait_texture = _get_customer_portrait(npc)
	_apply_customer_presentation()
	_refresh_scan_tab()
	_show_scan_tab()
	_hide_inventory_panel()
	_set_action_lock(true)
	return true


func reset_runtime_ui() -> void:
	_ui_layer.visible = false
	_customer = null
	_target_item_ids.clear()
	_cart_quantities.clear()
	_entered_change = ""
	_reset_checkout_conversation()
	_restore_inventory_panel()
	_set_action_lock(false)


func _exit_tree() -> void:
	_restore_inventory_panel()


func has_active_checkout() -> bool:
	return _customer != null and is_instance_valid(_customer) and _ui_layer.visible


func _unhandled_input(event: InputEvent) -> void:
	if not has_active_checkout():
		return
	if _is_hud_dialog_visible():
		return

	if _checkout_conversation_active:
		if (
			event is InputEventKey
			and event.pressed
			and not event.echo
			and (
				event.is_action_pressed("interact")
				or event.is_action_pressed("ui_accept")
				or event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
			)
		):
			_advance_checkout_conversation()
			get_viewport().set_input_as_handled()
		elif (
			event is InputEventKey
			and event.pressed
			and not event.echo
			and event.keycode == KEY_ESCAPE
		):
			# Once payment is confirmed, keep the transaction pending until the
			# authored conversation reaches its final line.
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		reset_runtime_ui()
		checkout_cancelled.emit()
		get_viewport().set_input_as_handled()


func _build_scan_tab() -> void:
	var cards_root := _scan_tab.get_node("Cards") as Node2D
	_scan_list = Control.new()
	_scan_list.name = "CardViewport"
	_scan_list.position = CATALOG_VIEW_RECT.position
	_scan_list.size = CATALOG_VIEW_RECT.size
	_scan_list.clip_contents = true
	_scan_list.mouse_filter = Control.MOUSE_FILTER_STOP
	_scan_list.gui_input.connect(_on_catalog_gui_input)
	cards_root.add_child(_scan_list)

	_scan_rows = GridContainer.new()
	_scan_rows.name = "ItemGrid"
	_scan_rows.columns = 2
	_scan_rows.size = Vector2(CATALOG_VIEW_RECT.size.x, 0)
	_scan_rows.add_theme_constant_override("h_separation", ITEM_GRID_GAP)
	_scan_rows.add_theme_constant_override("v_separation", ITEM_GRID_GAP)
	_scan_list.add_child(_scan_rows)

	# A small custom scrollbar keeps the visible thumb exactly aligned to the
	# five-pixel artwork; the built-in VScrollBar enforces a wider theme minimum.
	_scan_scrollbar = Control.new()
	_scan_scrollbar.name = "ScrollThumb"
	_scan_scrollbar.position = CATALOG_SCROLL_RECT.position
	_scan_scrollbar.size = CATALOG_SCROLL_RECT.size
	_scan_scrollbar.mouse_filter = Control.MOUSE_FILTER_STOP
	_scan_scrollbar.z_index = 5
	_scan_scrollbar.gui_input.connect(_on_catalog_scrollbar_gui_input)
	_scan_tab.add_child(_scan_scrollbar)

	_scan_scroll_thumb = ColorRect.new()
	_scan_scroll_thumb.name = "Thumb"
	_scan_scroll_thumb.size = Vector2(CATALOG_SCROLL_RECT.size.x, CATALOG_SCROLL_RECT.size.y)
	_scan_scroll_thumb.color = Color("ad673c")
	_scan_scroll_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scan_scrollbar.add_child(_scan_scroll_thumb)

	_scan_cart = ScrollContainer.new()
	_scan_cart.name = "SelectedItems"
	_scan_cart.position = Vector2(113, 214)
	_scan_cart.size = Vector2(72, 34)
	_scan_cart.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scan_cart.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scan_cart.mouse_filter = Control.MOUSE_FILTER_STOP
	_scan_tab.add_child(_scan_cart)

	_scan_cart_rows = VBoxContainer.new()
	_scan_cart_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scan_cart_rows.add_theme_constant_override("separation", 0)
	_scan_cart.add_child(_scan_cart_rows)

	_scan_total = _make_label("TOTAL 0G", BODY_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	_scan_total.position = Vector2(109, 188)
	_scan_total.size = Vector2(80, 16)
	_scan_total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scan_total.add_theme_color_override("font_color", Color.WHITE)
	_scan_tab.add_child(_scan_total)

	_scan_continue = _make_button("", Rect2(169, 250, 16, 11), BODY_FONT_SIZE)
	_scan_continue.tooltip_text = "Check the scanned items and enter the customer's change."
	_scan_continue.pressed.connect(_on_scan_continue_pressed)
	_add_exchange_arrow_icon(_scan_continue)
	_scan_tab.add_child(_scan_continue)

	var customer_money := _scan_tab.get_node("CustomerMoney") as Sprite2D
	_customer_cash_label = _make_label("0G", BODY_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	_customer_cash_label.position = Vector2(-24, -12)
	_customer_cash_label.size = Vector2(48, 14)
	_customer_cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_customer_cash_label.add_theme_color_override("font_color", Color("ad673c"))
	customer_money.add_child(_customer_cash_label)

	_scan_dialog = _scan_tab.get_node("Dialog") as Label
	_scan_portrait = _scan_tab.get_node("PortraitAnimation") as PortraitAnimation


func _build_exchange_tab() -> void:
	_exchange_total = _exchange_tab.get_node("Total") as Label
	_exchange_cart_rows = _exchange_tab.get_node("Screen/CartItems") as VBoxContainer
	_exchange_input = _exchange_tab.get_node("Screen/InputAmount") as Label
	_exchange_hint = _exchange_tab.get_node("TotalExchange/Label") as Label
	_exchange_dialog = _exchange_tab.get_node("Dialog") as Label
	_exchange_portrait = _exchange_tab.get_node("PortraitAnimation") as PortraitAnimation
	_exchange_dialog_next = _exchange_tab.get_node("DialogNextButton") as Button
	_exchange_dialog_next.tooltip_text = "Continue the conversation."
	_exchange_dialog_next.pressed.connect(_advance_checkout_conversation)

	var digit_nodes := {
		"One": "1",
		"Two": "2",
		"Three": "3",
		"Four": "4",
		"Five": "5",
		"Six": "6",
		"Seven": "7",
		"Eight": "8",
		"Nine": "9",
		"Zero": "0",
	}
	for node_name in digit_nodes:
		var digit_control := _exchange_tab.get_node("Calc/Numbers/%s" % node_name) as Control
		_bind_exchange_control(
			digit_control,
			_on_digit_pressed.bind(digit_nodes[node_name]),
			"Add %s to the change amount." % digit_nodes[node_name]
		)

	_bind_exchange_control(
		_exchange_tab.get_node("Calc/FreeButton") as Control,
		_on_free_pressed,
		"Give the selected items to the customer for free."
	)
	_bind_exchange_control(
		_exchange_tab.get_node("Calc/Actions/Nine") as Control,
		_on_delete_or_back_pressed,
		"Delete the last digit, or return to Scan when the field is empty."
	)
	_bind_exchange_control(
		_exchange_tab.get_node("Calc/Actions/Nine2") as Control,
		_on_confirm_exchange_pressed,
		"Return the exact change to complete the checkout."
	)
	_capture_exchange_default_visibility()


func _bind_exchange_control(control: Control, action: Callable, tooltip: String) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.tooltip_text = tooltip
	control.gui_input.connect(_on_exchange_control_input.bind(action))


func _on_exchange_control_input(event: InputEvent, action: Callable) -> void:
	if _is_hud_dialog_visible():
		return
	if _checkout_conversation_active:
		get_viewport().set_input_as_handled()
		return
	var activated: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	) or (
		event is InputEventScreenTouch
		and event.pressed
	)
	if not activated:
		return
	action.call()
	get_viewport().set_input_as_handled()


func _refresh_scan_tab() -> void:
	_clear_children(_scan_rows)
	var store_items := _get_store_items()
	for item in store_items:
		_scan_rows.add_child(_make_catalog_item(item))
	_update_catalog_scroll_metrics(store_items.size())

	_refresh_cart_displays()
	_customer_cash_label.text = "%dG" % _customer_cash
	_apply_dialogue_line(
		_scan_dialog,
		_scan_portrait,
		CashierDialogueLine.Speaker.CUSTOMER,
		_get_customer_request_text()
	)
	_scan_continue.disabled = _cart_quantities.is_empty()


func _refresh_cart_displays() -> void:
	_total = _calculate_cart_total()
	_scan_total.text = "TOTAL %dG" % _total
	_exchange_total.text = "TOTAL %dG" % _total

	_clear_children(_scan_cart_rows)
	_clear_children(_exchange_cart_rows)
	if _cart_quantities.is_empty():
		_scan_cart_rows.add_child(_make_label("Select items", SMALL_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER))
		_exchange_cart_rows.add_child(_make_label("No items", SMALL_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER))
		return

	for item_id in _cart_quantities:
		var quantity := _cart_quantities[item_id]
		_scan_cart_rows.add_child(_make_cart_row(item_id, quantity, true))
		_exchange_cart_rows.add_child(_make_cart_row(item_id, quantity, false))


func _make_catalog_item(item: ItemData) -> Button:
	var button := _make_button("", Rect2(Vector2.ZERO, ITEM_CARD_SIZE), SMALL_FONT_SIZE)
	button.custom_minimum_size = ITEM_CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.tooltip_text = "Scan %s for %dG." % [item.display_name, item.sell_price]
	button.pressed.connect(_on_item_scanned.bind(item.item_id))
	# Card buttons receive the pointer event before CardViewport does, so route
	# wheel/trackpad gestures through the same catalog scroll handler.
	button.gui_input.connect(_on_catalog_gui_input)

	var card := TextureRect.new()
	card.texture = ITEM_CARD_TEXTURE
	card.position = Vector2.ZERO
	card.size = ITEM_CARD_SIZE
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(card)

	# Match shelf rendering: item art is a Sprite2D whose source texture is
	# explicitly scaled, rather than a TextureRect that may preserve its bounds.
	var icon := Sprite2D.new()
	icon.texture = item.get_icon()
	icon.position = Vector2(7, 7.5)
	icon.scale = CATALOG_ICON_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(icon)

	var item_name := _make_label("", CATALOG_CARD_FONT_SIZE)
	item_name.clip_text = true
	item_name.position = CATALOG_TEXT_RECT.position
	item_name.size = CATALOG_TEXT_RECT.size
	item_name.text = _ellipsize_to_width(
		item.display_name,
		item_name.get_theme_font("font"),
		CATALOG_CARD_FONT_SIZE,
		CATALOG_TEXT_RECT.size.x
	)
	item_name.add_theme_color_override("font_color", Color("ad673c"))
	item_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(item_name)

	var price := _make_label("%dG" % item.sell_price, CATALOG_CARD_FONT_SIZE)
	price.position = Vector2(CATALOG_TEXT_RECT.position.x, 5)
	price.size = CATALOG_TEXT_RECT.size
	price.add_theme_color_override("font_color", Color("ead2a2"))
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(price)
	return button


func _make_cart_row(item_id: String, quantity: int, allow_decrement: bool) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(72, 10)
	row.add_theme_constant_override("separation", 1)
	var item: ItemData = ItemDatabase.get_item(item_id)
	var name := item.display_name if item != null else item_id
	var price := item.sell_price if item != null else 0
	var text := _make_label("%s x%d" % [name, quantity], SMALL_FONT_SIZE)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(text)

	var subtotal := _make_label("%d" % (price * quantity), SMALL_FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
	subtotal.custom_minimum_size = Vector2(15, 0)
	row.add_child(subtotal)

	if allow_decrement:
		var minus := _make_button("", Rect2(Vector2.ZERO, Vector2(9, 9)), SMALL_FONT_SIZE)
		minus.custom_minimum_size = Vector2(9, 9)
		minus.tooltip_text = "Remove one %s." % name
		minus.pressed.connect(_on_item_decremented.bind(item_id))
		var minus_icon := ColorRect.new()
		minus_icon.position = Vector2(2, 4)
		minus_icon.size = Vector2(5, 1)
		minus_icon.color = Color.BLACK
		minus_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minus.add_child(minus_icon)
		row.add_child(minus)
	return row


func _show_scan_tab() -> void:
	if _checkout_conversation_active:
		return
	if _exchange_portrait != null and _scan_portrait != null and _portrait_texture != null:
		_scan_portrait.set_portrait(_portrait_texture, _exchange_portrait.get_current_frame())
	_scan_tab.visible = true
	_exchange_tab.visible = false
	_ui_layer.visible = true
	_hide_inventory_panel()


func show_scan_tab() -> void:
	if has_active_checkout():
		_show_scan_tab()


func _show_exchange_tab() -> void:
	if _scan_portrait != null and _exchange_portrait != null and _portrait_texture != null:
		_exchange_portrait.set_portrait(_portrait_texture, _scan_portrait.get_current_frame())
	_scan_tab.visible = false
	_exchange_tab.visible = true
	_ui_layer.visible = true
	_hide_inventory_panel()
	_refresh_exchange_tab()


func show_exchange_tab() -> void:
	if has_active_checkout():
		_show_exchange_tab()


func _refresh_exchange_tab() -> void:
	_change_due = max(_customer_cash - _total, 0)
	_exchange_hint.text = "%dG" % _change_due
	_exchange_input.text = ("[%sG]" % _entered_change) if not _entered_change.is_empty() else "[--G]"
	if not _checkout_conversation_active:
		_apply_dialogue_line(
			_exchange_dialog,
			_exchange_portrait,
			CashierDialogueLine.Speaker.CUSTOMER,
			_get_customer_request_text()
		)
	_refresh_cart_displays()


func _update_catalog_scroll_metrics(item_count: int) -> void:
	var row_count := ceili(float(item_count) / 2.0)
	var content_height := maxf(
		CATALOG_VIEW_RECT.size.y,
		row_count * ITEM_CARD_SIZE.y + maxi(row_count - 1, 0) * ITEM_GRID_GAP
	)
	_scan_rows.custom_minimum_size = Vector2(CATALOG_VIEW_RECT.size.x, content_height)
	_scan_rows.size = Vector2(CATALOG_VIEW_RECT.size.x, content_height)
	_catalog_scroll_max = maxf(content_height - CATALOG_VIEW_RECT.size.y, 0.0)
	_scan_scrollbar.visible = _catalog_scroll_max > 0.0
	var visible_ratio := CATALOG_VIEW_RECT.size.y / content_height
	_scan_scroll_thumb.size = Vector2(
		CATALOG_SCROLL_RECT.size.x,
		maxf(roundf(CATALOG_SCROLL_RECT.size.y * visible_ratio), 6.0)
	)
	_set_catalog_scroll(_catalog_scroll_value)


func _set_catalog_scroll(value: float) -> void:
	_catalog_scroll_value = clampf(value, 0.0, _catalog_scroll_max)
	_scan_rows.position.y = -roundf(_catalog_scroll_value)
	var thumb_travel := CATALOG_SCROLL_RECT.size.y - _scan_scroll_thumb.size.y
	var scroll_ratio := _catalog_scroll_value / _catalog_scroll_max if _catalog_scroll_max > 0.0 else 0.0
	_scan_scroll_thumb.position.y = roundf(thumb_travel * scroll_ratio)


func _on_catalog_gui_input(event: InputEvent) -> void:
	var scroll_delta: float = 0.0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_delta = -CATALOG_SCROLL_STEP * event.factor
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_delta = CATALOG_SCROLL_STEP * event.factor
	elif event is InputEventPanGesture:
		scroll_delta = event.delta.y * CATALOG_SCROLL_STEP

	if is_zero_approx(scroll_delta):
		return
	_set_catalog_scroll(_catalog_scroll_value + scroll_delta)
	get_viewport().set_input_as_handled()


func _on_catalog_scrollbar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var thumb_rect := Rect2(_scan_scroll_thumb.position, _scan_scroll_thumb.size)
			if thumb_rect.has_point(event.position):
				_catalog_thumb_drag_offset = event.position.y - _scan_scroll_thumb.position.y
			else:
				_catalog_thumb_drag_offset = _scan_scroll_thumb.size.y * 0.5
				_set_catalog_scroll_from_thumb(event.position.y - _catalog_thumb_drag_offset)
			_catalog_thumb_dragging = true
		else:
			_catalog_thumb_dragging = false
		_scan_scrollbar.accept_event()
	elif event is InputEventMouseMotion and _catalog_thumb_dragging:
		_set_catalog_scroll_from_thumb(event.position.y - _catalog_thumb_drag_offset)
		_scan_scrollbar.accept_event()


func _set_catalog_scroll_from_thumb(thumb_y: float) -> void:
	var thumb_travel := CATALOG_SCROLL_RECT.size.y - _scan_scroll_thumb.size.y
	if thumb_travel <= 0.0:
		_set_catalog_scroll(0.0)
		return
	_set_catalog_scroll(clampf(thumb_y, 0.0, thumb_travel) / thumb_travel * _catalog_scroll_max)


func _on_item_scanned(item_id: String) -> void:
	if _is_hud_dialog_visible():
		return
	_cart_quantities[item_id] = _cart_quantities.get(item_id, 0) + 1
	_refresh_scan_tab()


func _on_item_decremented(item_id: String) -> void:
	if _is_hud_dialog_visible():
		return
	if not _cart_quantities.has(item_id):
		return
	_cart_quantities[item_id] -= 1
	if _cart_quantities[item_id] <= 0:
		_cart_quantities.erase(item_id)
	_refresh_scan_tab()


func _on_scan_continue_pressed() -> void:
	if _is_hud_dialog_visible():
		return
	if _cart_quantities.is_empty():
		_show_notification("Scan at least one item first.")
		return
	if not _cart_matches_customer():
		_show_notification("Scan exactly the items this customer requested.")
		return
	_entered_change = ""
	_show_exchange_tab()


func _on_digit_pressed(digit: String) -> void:
	if _is_hud_dialog_visible():
		return
	if _checkout_conversation_active:
		return
	if _entered_change.length() >= 6:
		return
	_entered_change += digit
	_refresh_exchange_tab()


func _on_delete_or_back_pressed() -> void:
	if _is_hud_dialog_visible():
		return
	if _checkout_conversation_active:
		return
	if _entered_change.is_empty():
		_show_scan_tab()
		return
	_entered_change = _entered_change.left(-1)
	_refresh_exchange_tab()


func _on_confirm_exchange_pressed() -> void:
	if _is_hud_dialog_visible():
		return
	if _checkout_conversation_active:
		return
	if _customer_cash < _total:
		_show_notification(
			"Customer needs %dG more to pay for these items." % (_total - _customer_cash)
		)
		_flash_exchange_input()
		return
	if _entered_change.is_empty() or int(_entered_change) != _change_due:
		_show_notification("Return exactly %dG in change." % _change_due)
		_flash_exchange_input()
		return
	_complete_checkout(false)


func _on_free_pressed() -> void:
	if _is_hud_dialog_visible():
		return
	if _checkout_conversation_active:
		return
	if not _cart_matches_customer():
		_show_notification("Scan the customer's requested items before giving them away.")
		return
	_complete_checkout(true)


func _complete_checkout(is_free: bool) -> void:
	if _is_hud_dialog_visible():
		return
	if _customer == null or not is_instance_valid(_customer):
		reset_runtime_ui()
		return
	if not is_free and _begin_post_payment_conversation():
		return

	_emit_checkout_request(is_free, true)


func _emit_checkout_request(
	is_free: bool,
	show_customer_completion_dialog: bool
) -> void:
	if _customer == null or not is_instance_valid(_customer):
		reset_runtime_ui()
		return

	var item_label := _get_selected_item_label()
	var quantities := _cart_quantities.duplicate(true)
	if is_free:
		free_requested.emit(_total, item_label, quantities)
	else:
		payment_requested.emit(
			_total,
			item_label,
			quantities,
			show_customer_completion_dialog
		)


func _begin_post_payment_conversation() -> bool:
	if _cashier_conversation == null:
		return false

	_checkout_conversation_lines.clear()
	for line in _cashier_conversation.post_payment_dialogue:
		if line != null and not line.text.strip_edges().is_empty():
			_checkout_conversation_lines.append(line)

	if _checkout_conversation_lines.is_empty():
		return false

	if not _active_conditional_conversation_id.is_empty():
		_mark_conditional_conversation_shown(
			TimeManager.current_day,
			_active_conditional_conversation_id
		)

	_checkout_conversation_active = true
	_checkout_conversation_index = -1
	_set_exchange_post_payment_mode(true)
	checkout_conversation_started.emit()
	_advance_checkout_conversation()
	return true


func _advance_checkout_conversation() -> void:
	if _is_hud_dialog_visible():
		return
	if not _checkout_conversation_active:
		return

	_checkout_conversation_index += 1
	if _checkout_conversation_index >= _checkout_conversation_lines.size():
		var player_exit_dialogue: Array[String] = []
		var wait_for_customer_exit := false
		if _cashier_conversation != null:
			for message in _cashier_conversation.player_exit_dialogue:
				if not message.strip_edges().is_empty():
					player_exit_dialogue.append(message)
			wait_for_customer_exit = _cashier_conversation.wait_for_customer_exit
		var departing_customer := _customer
		_reset_checkout_conversation()
		_emit_checkout_request(false, false)
		if not player_exit_dialogue.is_empty():
			player_exit_dialog_requested.emit(
				player_exit_dialogue,
				departing_customer,
				wait_for_customer_exit
			)
		return

	var line := _checkout_conversation_lines[_checkout_conversation_index]
	_apply_dialogue_line(
		_exchange_dialog,
		_exchange_portrait,
		line.speaker,
		line.text,
		line.portrait_frame
	)
	_exchange_dialog_next.text = (
		"Close" if _checkout_conversation_index == _checkout_conversation_lines.size() - 1
		else "Next..."
	)


func _reset_checkout_conversation() -> void:
	_set_exchange_post_payment_mode(false)
	_checkout_conversation_active = false
	_checkout_conversation_index = -1
	_checkout_conversation_lines.clear()
	_cashier_conversation = null
	_active_conditional_conversation_id = ""
	if _exchange_dialog_next != null:
		_exchange_dialog_next.visible = false
		_exchange_dialog_next.text = "Next..."


func _capture_exchange_default_visibility() -> void:
	_exchange_default_visibility.clear()
	for child in _exchange_tab.get_children():
		if child is CanvasItem:
			_exchange_default_visibility[child] = child.visible


func _set_exchange_post_payment_mode(active: bool) -> void:
	if _exchange_default_visibility.is_empty():
		return
	for item in _exchange_default_visibility:
		var canvas_item := item as CanvasItem
		if canvas_item == null or not is_instance_valid(canvas_item):
			continue
		canvas_item.visible = (
			canvas_item.name in POST_PAYMENT_EXCHANGE_NODE_NAMES
			if active
			else bool(_exchange_default_visibility[item])
		)


func _cart_matches_customer() -> bool:
	var selected: Array[String] = []
	for item_id in _cart_quantities:
		for count in _cart_quantities[item_id]:
			selected.append(item_id)
	return CashierCheckoutService.selection_matches_customer(selected, _target_item_ids)


func _calculate_cart_total() -> int:
	var total := 0
	for item_id in _cart_quantities:
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item != null:
			total += item.sell_price * _cart_quantities[item_id]
	return total


func _get_selected_item_label() -> String:
	var labels: Array[String] = []
	for item_id in _cart_quantities:
		var item: ItemData = ItemDatabase.get_item(item_id)
		var item_name := item.display_name if item != null else item_id
		var quantity := _cart_quantities[item_id]
		labels.append("%s x%d" % [item_name, quantity] if quantity > 1 else item_name)
	return ", ".join(labels)


func _get_target_total() -> int:
	if _customer != null and _customer.has_method("get_checkout_total"):
		return _customer.get_checkout_total()
	return CashierCheckoutService.calculate_total(_target_item_ids)


func _get_customer_cash(npc: NPC, target_total: int) -> int:
	if npc.npc_data != null and npc.npc_data.checkout_cash > 0:
		return maxi(npc.npc_data.checkout_cash, target_total)

	# Give regular customers varied amounts instead of always selecting the next
	# fixed denomination. The possible overpayment grows with the purchase, while
	# remaining bounded so the required change stays reasonable.
	var extra_cash_limit: int = clampi(roundi(float(target_total) * 0.5), 20, 200)
	return target_total + randi_range(0, extra_cash_limit)


func _get_customer_portrait(npc: NPC) -> Texture2D:
	if npc.npc_data == null:
		return null
	if npc.npc_data.portrait != null:
		return npc.npc_data.portrait
	if npc.npc_data.assets_path.is_empty():
		return null
	return NPCAssetRuntime.load_portrait_texture(npc.npc_data.assets_path)


func _apply_customer_presentation() -> void:
	var request_text := _get_customer_request_text()
	_apply_dialogue_line(
		_scan_dialog,
		_scan_portrait,
		CashierDialogueLine.Speaker.CUSTOMER,
		request_text
	)
	_apply_dialogue_line(
		_exchange_dialog,
		_exchange_portrait,
		CashierDialogueLine.Speaker.CUSTOMER,
		request_text
	)


func _apply_dialogue_line(
	dialog_label: Label,
	portrait_view: PortraitAnimation,
	speaker: CashierDialogueLine.Speaker,
	text: String,
	portrait_frame: int = 0
) -> void:
	var speaker_name := _get_customer_name()
	var speaker_portrait := _portrait_texture
	if speaker == CashierDialogueLine.Speaker.PLAYER:
		speaker_name = "Player"
		speaker_portrait = PLAYER_PORTRAIT

	dialog_label.text = "%s\n%s" % [speaker_name, text]
	if speaker_portrait == null:
		portrait_view.visible = false
		return
	portrait_view.visible = true
	portrait_view.set_portrait(speaker_portrait, portrait_frame)


func _get_customer_name() -> String:
	if _customer == null or not is_instance_valid(_customer):
		return "Customer"
	var customer_name := "Customer"
	if _customer.npc_data != null and not _customer.npc_data.display_name.is_empty():
		customer_name = _customer.npc_data.display_name
	return customer_name


func _get_customer_request_text() -> String:
	if _customer == null or not is_instance_valid(_customer):
		return "Waiting..."
	if (
		_cashier_conversation != null
		and not _cashier_conversation.opening_line.strip_edges().is_empty()
	):
		return _cashier_conversation.opening_line
	var request := _customer.get_checkout_item_label() if _customer.has_method("get_checkout_item_label") else "these items"
	return "Just %s, please." % request


func _get_store_items() -> Array[ItemData]:
	var stocked_item_ids: Dictionary[String, bool] = {}
	var store := get_tree().get_first_node_in_group("store") as Store
	if store != null:
		_collect_shelf_item_ids(store.human_shelf, stocked_item_ids)
		_collect_shelf_item_ids(store.ghost_shelf, stocked_item_ids)

	# Shopping removes units from shelf stock before checkout. Keep the active
	# cart scannable when the customer took the final unit of an item.
	for item_id in _target_item_ids:
		if not item_id.is_empty():
			stocked_item_ids[item_id] = true

	var items: Array[ItemData] = []
	for item_id in stocked_item_ids:
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item != null:
			items.append(item)
	items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return items


func _collect_shelf_item_ids(shelf: Shelf, item_ids: Dictionary[String, bool]) -> void:
	if shelf == null or not is_instance_valid(shelf):
		return
	for slot_index in shelf.max_slots:
		var item_id := shelf.get_slot_content(slot_index)
		if not item_id.is_empty():
			item_ids[item_id] = true


func _add_exchange_arrow_icon(button: Button) -> void:
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(2, 3),
		Vector2(9, 3),
		Vector2(9, 1),
		Vector2(14, 5.5),
		Vector2(9, 10),
		Vector2(9, 8),
		Vector2(2, 8),
	])
	arrow.color = Color.WHITE
	button.add_child(arrow)


func _make_label(text: String, font_size: int, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("3c251b"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _ellipsize_to_width(text: String, font: Font, font_size: int, max_width: float) -> String:
	if font == null or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
		return text

	const ELLIPSIS := "…"
	var shortened := text
	while not shortened.is_empty():
		shortened = shortened.left(-1).strip_edges()
		if font.get_string_size(shortened + ELLIPSIS, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			return shortened + ELLIPSIS
	return ELLIPSIS


func _make_button(text: String, rect: Rect2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("f5dfc6"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("fff0a0"))
	button.add_theme_stylebox_override("normal", _panel_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("hover", _panel_style(Color("4e3025"), Color("d98c58"), 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("2b1714"), Color("fff0a0"), 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	return button


func _panel_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.content_margin_left = 1
	style.content_margin_right = 1
	return style


func _flash_exchange_input() -> void:
	_exchange_input.modulate = Color("ff6b6b")
	var tween := create_tween()
	tween.tween_property(_exchange_input, "modulate", Color.WHITE, 0.25)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _hide_inventory_panel() -> void:
	if _inventory_hidden_by_cashier:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	_inventory_panel = hud.get_node_or_null("InventoryUI") as CanvasItem
	if _inventory_panel == null:
		return
	_inventory_was_visible = _inventory_panel.visible
	_inventory_panel.visible = false
	_inventory_hidden_by_cashier = true


func _restore_inventory_panel() -> void:
	if not _inventory_hidden_by_cashier:
		return
	if _inventory_panel != null and is_instance_valid(_inventory_panel):
		_inventory_panel.visible = _inventory_was_visible
	_inventory_panel = null
	_inventory_hidden_by_cashier = false


func _set_action_lock(locked: bool) -> void:
	if locked == _action_lock_active:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if locked and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")
		_action_lock_active = true
	elif not locked and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")
		_action_lock_active = false


func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, 1.2)


func _resolve_cashier_conversation(npc: NPC) -> CashierConversationData:
	var day := TimeManager.current_day
	var shown_conversations: Dictionary = _shown_conditional_conversations_by_day.get(
		day,
		{}
	)
	var conditional_conversation := CashierConversationResolver.get_conditional_conversation(
		day,
		_get_customer_number(npc),
		shown_conversations
	)
	if conditional_conversation != null:
		_active_conditional_conversation_id = conditional_conversation.conversation_id
		return conditional_conversation

	return CashierConversationResolver.get_conversation(
		day,
		npc.npc_data.npc_id if npc.npc_data != null else ""
	)


func _get_customer_number(npc: NPC) -> int:
	if npc == null or npc.npc_data == null:
		return 1
	return maxi(1, npc.npc_data.spawn_order + 1)


func _mark_conditional_conversation_shown(day: int, conversation_id: String) -> void:
	if not _shown_conditional_conversations_by_day.has(day):
		_shown_conditional_conversations_by_day[day] = {}
	var shown_conversations: Dictionary = _shown_conditional_conversations_by_day[day]
	shown_conversations[conversation_id] = true
	_shown_conditional_conversations_by_day[day] = shown_conversations


func _is_hud_dialog_visible() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return false
	if hud.has_method("is_dialog_visible"):
		return bool(hud.call("is_dialog_visible"))
	var dialog := hud.get_node_or_null("Dialog") as CanvasItem
	return dialog != null and dialog.visible
