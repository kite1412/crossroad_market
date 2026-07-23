class_name StorageRestockFlow
extends Node


const RESTOCK_SCROLL_STEP: int = 28
const RESTOCK_ITEM_HOVER_MODULATE := Color(1.12, 1.08, 0.92, 1.0)
const RESTOCK_ITEM_NORMAL_MODULATE := Color(1, 1, 1, 1)
const RESTOCK_ITEM_HOVER_DURATION: float = 0.12
const RESTOCK_BUTTON_HOVER_MODULATE := Color(1.18, 1.1, 0.96, 1.0)
const RESTOCK_BUTTON_NORMAL_MODULATE := Color(1, 1, 1, 1)
const RESTOCK_BUTTON_HOVER_DURATION: float = 0.12
const RESTOCK_SCROLLBAR_SCENE_POSITION_META: StringName = &"restock_scene_position"
const RESTOCK_ITEM_ROW_SCENE: PackedScene = preload(
	"res://scenes/locations/storage/restock/ListRestockPanel.tscn"
)

var storage: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(storage_node: Node) -> void:
	storage = storage_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func open_restock_panel() -> void:
	storage._restock_checkout_completed_this_session = false
	storage.restock_panel_opened.emit()
	ensure_restock_panel()
	render_restock_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func ensure_restock_panel() -> void:
	if storage._restock_layer != null and is_instance_valid(storage._restock_layer):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var panel_nodes := StorageRestockPanel.ensure(storage)
	if panel_nodes.is_empty():
		return
	storage._restock_layer = panel_nodes["layer"] as CanvasLayer
	storage._restock_panel = panel_nodes["panel"] as Control
	storage._restock_list_area = panel_nodes["list_area"] as Control
	storage._restock_item_scroll = panel_nodes["item_scroll"] as ScrollContainer
	storage._restock_item_list = panel_nodes["item_list"] as VBoxContainer
	storage._restock_wallet_label = panel_nodes["wallet_label"] as Label
	storage._restock_selected_label = panel_nodes["selected_label"] as Label
	storage._restock_guide_label = panel_nodes["guide_label"] as Label
	storage._restock_purchase_button = panel_nodes["purchase_button"] as Button
	storage._restock_close_button = panel_nodes["close_button"] as Button
	storage._restock_scrollbar_sprite = panel_nodes["scrollbar_sprite"] as Sprite2D
	_setup_scene_action_buttons()
	_setup_scene_scrollbar()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func render_restock_panel() -> void:
	if storage._restock_panel == null:
		return

	if storage._restock_layer != null:
		storage._restock_layer.visible = true

	storage._restock_panel.visible = true
	StorageRestockPanel.clear_container(storage._restock_item_list)
	update_restock_wallet()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var items := get_restock_items()

	for item in items:
		if item == null:
			continue

		var row := create_restock_item_row(item)
		if row != null:
			storage._restock_item_list.add_child(row)

	if storage._selected_restock_item_id == "" and not items.is_empty():
		storage._selected_restock_item_id = items[0].item_id

	render_restock_detail()
	_update_restock_scroll_metrics.call_deferred()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_restock_item_row(item: ItemData) -> Control:
	var row := RESTOCK_ITEM_ROW_SCENE.instantiate() as Control
	if row == null:
		push_error("ListRestockPanel scene failed to instantiate.")
		return null

	var select_button := row.get_node_or_null("SelectButton") as Button
	var icon_label := row.get_node_or_null("IconLabel") as Label
	var icon_sprite := row.get_node_or_null("IconSprite") as Sprite2D
	var name_label := row.get_node_or_null("NameLabel") as Label
	var price_label := row.get_node_or_null("PriceLabel") as Label
	var minus_button := row.get_node_or_null("MinusButton") as Button
	var qty_label := row.get_node_or_null("QuantityLabel") as Label
	var plus_button := row.get_node_or_null("PlusButton") as Button
	if not _validate_restock_item_row(
		row,
		select_button,
		icon_sprite,
		name_label,
		price_label,
		minus_button,
		qty_label,
		plus_button
	):
		row.queue_free()
		return null

	if icon_label != null:
		icon_label.visible = false
	_apply_item_icon(icon_sprite, item)
	name_label.text = item.display_name
	price_label.text = "%dG" % get_item_buy_cost(item)
	qty_label.text = str(get_restock_cart_quantity(item.item_id))

	select_button.pressed.connect(func() -> void:
		storage._selected_restock_item_id = item.item_id
		render_restock_panel()
	)
	connect_restock_scroll_forwarding(select_button)
	_connect_restock_row_hover(row, select_button)

	minus_button.pressed.connect(func() -> void:
		add_restock_cart_quantity(item.item_id, 1)
	)
	connect_restock_scroll_forwarding(minus_button)
	_connect_restock_row_hover(row, minus_button)

	plus_button.pressed.connect(func() -> void:
		add_restock_cart_quantity(item.item_id, -1)
	)
	connect_restock_scroll_forwarding(plus_button)
	_connect_restock_row_hover(row, plus_button)

	row.modulate = RESTOCK_ITEM_NORMAL_MODULATE

	return row


func _validate_restock_item_row(
	_row: Control,
	select_button: Button,
	icon_sprite: Sprite2D,
	name_label: Label,
	price_label: Label,
	minus_button: Button,
	qty_label: Label,
	plus_button: Button
) -> bool:
	var missing_nodes: Array[String] = []
	if select_button == null:
		missing_nodes.append("SelectButton")
	if icon_sprite == null:
		missing_nodes.append("IconSprite")
	if name_label == null:
		missing_nodes.append("NameLabel")
	if price_label == null:
		missing_nodes.append("PriceLabel")
	if minus_button == null:
		missing_nodes.append("MinusButton")
	if qty_label == null:
		missing_nodes.append("QuantityLabel")
	if plus_button == null:
		missing_nodes.append("PlusButton")
	if missing_nodes.is_empty():
		return true

	push_error(
		"ListRestockPanel scene missing required row node(s): %s" % ", ".join(missing_nodes)
	)
	return false


func _apply_item_icon(icon_sprite: Sprite2D, item: ItemData) -> void:
	if icon_sprite == null:
		push_error("ListRestockPanel scene missing required Sprite2D node: IconSprite")
		return

	icon_sprite.texture = item.get_icon()


func _connect_restock_row_hover(row: Control, control: Control) -> void:
	if row == null or control == null:
		return

	control.mouse_entered.connect(func() -> void:
		_tween_restock_row_modulate(row, RESTOCK_ITEM_HOVER_MODULATE)
	)
	control.mouse_exited.connect(func() -> void:
		_tween_restock_row_modulate(row, RESTOCK_ITEM_NORMAL_MODULATE)
	)


func _tween_restock_row_modulate(row: Control, target_modulate: Color) -> void:
	if row == null or not is_instance_valid(row):
		return

	if row.has_meta("hover_tween"):
		var active_tween := row.get_meta("hover_tween") as Tween
		if active_tween != null and active_tween.is_valid():
			active_tween.kill()

	var tween := row.create_tween()
	row.set_meta("hover_tween", tween)
	tween.tween_property(
		row,
		"modulate",
		target_modulate,
		RESTOCK_ITEM_HOVER_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _connect_restock_button_hover(button: Button) -> void:
	if button == null:
		return

	var target := button.get_node_or_null("Sprite2D") as CanvasItem
	if target == null:
		target = button
	target.modulate = RESTOCK_BUTTON_NORMAL_MODULATE

	button.mouse_entered.connect(func() -> void:
		_tween_restock_button_modulate(target, RESTOCK_BUTTON_HOVER_MODULATE)
	)
	button.mouse_exited.connect(func() -> void:
		_tween_restock_button_modulate(target, RESTOCK_BUTTON_NORMAL_MODULATE)
	)


func _tween_restock_button_modulate(target: CanvasItem, target_modulate: Color) -> void:
	if target == null or not is_instance_valid(target):
		return

	if target.has_meta("hover_tween"):
		var active_tween := target.get_meta("hover_tween") as Tween
		if active_tween != null and active_tween.is_valid():
			active_tween.kill()

	var tween := target.create_tween()
	target.set_meta("hover_tween", tween)
	tween.tween_property(
		target,
		"modulate",
		target_modulate,
		RESTOCK_BUTTON_HOVER_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _setup_scene_action_buttons() -> void:
	if storage._restock_purchase_button != null:
		_connect_restock_button_hover(storage._restock_purchase_button)
		var checkout_callable := Callable(self, "checkout_restock_cart")
		if not storage._restock_purchase_button.pressed.is_connected(checkout_callable):
			storage._restock_purchase_button.pressed.connect(checkout_callable)

	if storage._restock_close_button != null:
		_connect_restock_button_hover(storage._restock_close_button)
		var close_callable := Callable(self, "hide_restock_panel")
		if not storage._restock_close_button.pressed.is_connected(close_callable):
			storage._restock_close_button.pressed.connect(close_callable)


func _setup_scene_scrollbar() -> void:
	if storage._restock_panel == null or storage._restock_item_scroll == null:
		return

	var item_scroll_input := Callable(self, "_on_restock_item_scroll_gui_input")
	if not storage._restock_item_scroll.gui_input.is_connected(item_scroll_input):
		storage._restock_item_scroll.gui_input.connect(item_scroll_input)

	if storage._restock_scrollbar_hitbox == null:
		storage._restock_scrollbar_hitbox = (
			storage._restock_panel.find_child("RestockScrollHitbox", true, false)
			as Control
		)
	if storage._restock_scrollbar_hitbox == null:
		push_error("StorageRestockPanel scene missing required Control node: RestockScrollHitbox")
		return

	if storage._restock_scrollbar_sprite == null:
		push_error("StorageRestockPanel scene missing required Sprite2D node: ScrollBar")
		return

	if not storage._restock_scrollbar_sprite.has_meta(RESTOCK_SCROLLBAR_SCENE_POSITION_META):
		storage._restock_scrollbar_sprite.set_meta(
			RESTOCK_SCROLLBAR_SCENE_POSITION_META,
			storage._restock_scrollbar_sprite.position
		)

	var scrollbar_input := Callable(self, "_on_restock_scrollbar_gui_input")
	if not storage._restock_scrollbar_hitbox.gui_input.is_connected(scrollbar_input):
		storage._restock_scrollbar_hitbox.gui_input.connect(scrollbar_input)

	_update_restock_scroll_metrics.call_deferred()


func _update_scene_action_buttons() -> void:
	if storage._restock_purchase_button != null:
		storage._restock_purchase_button.disabled = not has_restock_cart_items()

	if storage._restock_close_button != null:
		storage._restock_close_button.disabled = false


func _update_restock_scroll_metrics() -> void:
	if (
		storage._restock_item_scroll == null
		or storage._restock_item_list == null
		or storage._restock_scrollbar_hitbox == null
		or storage._restock_scrollbar_sprite == null
	):
		return

	var content_height := maxf(
		storage._restock_item_list.get_combined_minimum_size().y,
		storage._restock_item_list.size.y
	)
	var view_height := maxf(storage._restock_item_scroll.size.y, 1.0)
	storage._restock_scroll_max = maxf(content_height - view_height, 0.0)

	var should_show: bool = storage._restock_scroll_max > 0.0
	storage._restock_scrollbar_hitbox.visible = should_show
	if storage._restock_scrollbar_sprite != null:
		storage._restock_scrollbar_sprite.visible = should_show
	if not should_show:
		storage._restock_item_scroll.scroll_vertical = 0
		return

	_set_restock_scroll(float(storage._restock_item_scroll.scroll_vertical))


func _get_restock_scrollbar_sprite_size() -> Vector2:
	if storage._restock_scrollbar_sprite == null:
		return Vector2.ONE

	var sprite_rect: Rect2 = storage._restock_scrollbar_sprite.get_rect()
	var sprite_scale: Vector2 = storage._restock_scrollbar_sprite.scale
	return Vector2(
		maxf(absf(sprite_rect.size.x * sprite_scale.x), 1.0),
		maxf(absf(sprite_rect.size.y * sprite_scale.y), 1.0)
	)


func _get_restock_scrollbar_sprite_hitbox_rect() -> Rect2:
	if storage._restock_scrollbar_sprite == null or storage._restock_scrollbar_hitbox == null:
		return Rect2()

	var parent_inverse: Transform2D = storage._restock_scrollbar_hitbox.get_global_transform_with_canvas().affine_inverse()
	var sprite_center: Vector2 = parent_inverse * storage._restock_scrollbar_sprite.global_position
	var sprite_size: Vector2 = _get_restock_scrollbar_sprite_size()
	return Rect2(sprite_center - sprite_size * 0.5, sprite_size)


func _set_restock_scroll(value: float) -> void:
	if storage._restock_item_scroll == null:
		return

	var scroll_value := clampf(value, 0.0, storage._restock_scroll_max)
	storage._restock_item_scroll.scroll_vertical = roundi(scroll_value)

	if storage._restock_scrollbar_hitbox == null or storage._restock_scrollbar_sprite == null:
		return

	var scroll_ratio := 0.0
	if storage._restock_scroll_max > 0.0:
		scroll_ratio = scroll_value / storage._restock_scroll_max

	var scene_position := _get_restock_scrollbar_scene_position()
	var bottom_position := _get_restock_scrollbar_scene_bottom_position(
		scene_position
	)
	storage._restock_scrollbar_sprite.position = scene_position.lerp(
		bottom_position,
		scroll_ratio
	)


func _get_restock_scrollbar_scene_position() -> Vector2:
	if storage._restock_scrollbar_sprite == null:
		return Vector2.ZERO
	var position_variant: Variant = storage._restock_scrollbar_sprite.get_meta(
		RESTOCK_SCROLLBAR_SCENE_POSITION_META,
		storage._restock_scrollbar_sprite.position
	)
	if position_variant is Vector2:
		return position_variant as Vector2
	return storage._restock_scrollbar_sprite.position


func _get_restock_scrollbar_scene_bottom_position(scene_position: Vector2) -> Vector2:
	if storage._restock_panel != null:
		var bottom_marker := (
			storage._restock_panel.find_child("ScrollBarBottom", true, false)
			as Node2D
		)
		if bottom_marker != null:
			return bottom_marker.position

	push_error("StorageRestockPanel scene missing required Marker2D node: ScrollBarBottom")
	return scene_position


func _on_restock_item_scroll_gui_input(event: InputEvent) -> void:
	var scroll_delta := _get_scroll_delta(event)
	if is_zero_approx(scroll_delta):
		return

	_set_restock_scroll(float(storage._restock_item_scroll.scroll_vertical) + scroll_delta)
	storage.get_viewport().set_input_as_handled()


func _on_restock_scrollbar_gui_input(event: InputEvent) -> void:
	if storage._restock_scrollbar_sprite == null or storage._restock_scrollbar_hitbox == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var thumb_rect := _get_restock_scrollbar_sprite_hitbox_rect()
			if thumb_rect.has_point(event.position):
				storage._restock_scrollbar_drag_offset = (
					event.position.y
					- thumb_rect.position.y
				)
			else:
				storage._restock_scrollbar_drag_offset = (
					thumb_rect.size.y
					* 0.5
				)
				_set_restock_scroll_from_thumb(event.position.y - storage._restock_scrollbar_drag_offset)
			storage._restock_scrollbar_dragging = true
		else:
			storage._restock_scrollbar_dragging = false
		storage._restock_scrollbar_hitbox.accept_event()
	elif event is InputEventMouseMotion and storage._restock_scrollbar_dragging:
		_set_restock_scroll_from_thumb(event.position.y - storage._restock_scrollbar_drag_offset)
		storage._restock_scrollbar_hitbox.accept_event()
	else:
		var scroll_delta := _get_scroll_delta(event)
		if is_zero_approx(scroll_delta):
			return
		_set_restock_scroll(float(storage._restock_item_scroll.scroll_vertical) + scroll_delta)
		storage._restock_scrollbar_hitbox.accept_event()


func _set_restock_scroll_from_thumb(thumb_y: float) -> void:
	if storage._restock_scrollbar_hitbox == null or storage._restock_scrollbar_sprite == null:
		return

	var thumb_size := _get_restock_scrollbar_sprite_size()
	var thumb_travel: float = (
		storage._restock_scrollbar_hitbox.size.y
		- thumb_size.y
	)
	if thumb_travel <= 0.0:
		_set_restock_scroll(0.0)
		return

	_set_restock_scroll(
		clampf(thumb_y, 0.0, thumb_travel)
		/ thumb_travel
		* storage._restock_scroll_max
	)


func _get_scroll_delta(event: InputEvent) -> float:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			return -RESTOCK_SCROLL_STEP * event.factor
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return RESTOCK_SCROLL_STEP * event.factor
	elif event is InputEventPanGesture:
		return event.delta.y * RESTOCK_SCROLL_STEP

	return 0.0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func render_restock_detail() -> void:
	if storage._restock_wallet_label != null:
		storage._restock_wallet_label.visible = false
	if storage._restock_guide_label != null:
		storage._restock_guide_label.visible = false
	if storage._restock_selected_label != null:
		storage._restock_selected_label.visible = true
		storage._restock_selected_label.text = "Cart Total: %dG" % get_restock_cart_total()

	_update_scene_action_buttons()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_restock_cart_quantity(item_id: String, delta: int) -> void:
	if item_id == "" or delta == 0:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var quantity := get_restock_cart_quantity(item_id) + delta

	if quantity <= 0:
		storage._restock_cart.erase(item_id)
	else:
		storage._restock_cart[item_id] = quantity

	storage._selected_restock_item_id = item_id
	render_restock_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func checkout_restock_cart() -> void:
	if not has_restock_cart_items():
		storage._show_notification("Add items to the cart first.", 0.9)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total := get_restock_cart_total()

	if total <= 0:
		storage._show_notification("Add items to the cart first.", 0.9)
		return

	if not EconomyManager.spend_gold(total):
		storage._show_notification("Not enough gold.", 0.9)
		render_restock_panel()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var order_items := get_restock_cart_order_items()
	storage._restock_cart.clear()
	storage.restock_order_purchased.emit(order_items)
	storage._restock_checkout_completed_this_session = true
	storage._show_notification("Restock ordered. Pick it up in the yard.", 1.2)
	render_restock_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_restock_cart_quantity(item_id: String) -> int:
	return int(storage._restock_cart.get(item_id, 0))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func connect_restock_scroll_forwarding(control: Control) -> void:
	control.gui_input.connect(func(event: InputEvent) -> void:
		forward_restock_scroll_input(event, control)
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func forward_restock_scroll_input(event: InputEvent, from_control: Control) -> void:
	var scroll_delta := _get_scroll_delta(event)
	if is_zero_approx(scroll_delta):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var scroll := find_parent_scroll_container(from_control)

	if scroll == null:
		return

	if scroll == storage._restock_item_scroll:
		_set_restock_scroll(float(scroll.scroll_vertical) + scroll_delta)
	else:
		scroll.scroll_vertical += roundi(scroll_delta)
	storage.get_viewport().set_input_as_handled()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_parent_scroll_container(from_control: Control) -> ScrollContainer:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var node: Node = from_control

	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer

		node = node.get_parent()

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_restock_cart_items() -> bool:
	for item_id in storage._restock_cart.keys():
		if int(storage._restock_cart[item_id]) > 0:
			return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func format_restock_cart_summary() -> String:
	if not has_restock_cart_items():
		return "Cart: empty"

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var parts: Array[String] = []

	for item_id in storage._restock_cart.keys():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var quantity := int(storage._restock_cart[item_id])

		if quantity <= 0:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item := ItemDatabase.get_item(str(item_id))
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item_name := str(item_id)

		if item != null:
			item_name = item.display_name

		parts.append("%s x%d" % [item_name, quantity])

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var packed_parts := PackedStringArray(parts)
	return "Cart: %s" % ", ".join(packed_parts)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_restock_cart_total() -> int:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total := 0

	for item_id in storage._restock_cart.keys():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item := ItemDatabase.get_item(str(item_id))

		if item == null:
			continue

		total += get_item_buy_cost(item) * int(storage._restock_cart[item_id])

	return total


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_restock_cart_order_items() -> Array[Dictionary]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var order_items: Array[Dictionary] = []

	for item_id in storage._restock_cart.keys():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var quantity := int(storage._restock_cart[item_id])

		if quantity <= 0:
			continue

		order_items.append({
			"item_id": str(item_id),
			"quantity": quantity
		})

	return order_items


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_restock_panel() -> void:
	if storage._restock_panel != null:
		storage._restock_panel.visible = false

	if storage._restock_layer != null:
		storage._restock_layer.visible = false

	storage.restock_panel_closed.emit(storage._restock_checkout_completed_this_session)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_restock_items() -> Array[ItemData]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var items: Array[ItemData] = []

	for item in ItemDatabase.get_all_items():
		if item == null:
			continue

		if item.shelf_type == ItemData.ShelfType.GHOST and not storage._mystery_phase_unlocked:
			continue

		items.append(item)

	items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.shelf_type != b.shelf_type:
			return int(a.shelf_type) < int(b.shelf_type)

		return a.display_name < b.display_name
	)
	return items


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_item_buy_cost(item: ItemData) -> int:
	if item.buy_cost > 0:
		return item.buy_cost

	return maxi(1, ceili(float(item.sell_price) * 0.5))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_restock_wallet() -> void:
	if storage._restock_wallet_label != null:
		storage._restock_wallet_label.text = ""
		storage._restock_wallet_label.visible = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_gold_changed(_amount: int) -> void:
	update_restock_wallet()
