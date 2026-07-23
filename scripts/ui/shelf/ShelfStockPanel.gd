class_name ShelfStockPanel
extends Control


const SHELF_STOCK_CARD_SCENE: PackedScene = preload("res://scenes/ui/shelf/ShelfStockCard.tscn")
const SCROLL_STEP: float = 36.0
const ANIM_DURATION: float = 0.14
const CLOSE_DISTANCE: float = 96.0
const NORMAL_MODULATE := Color(1, 1, 1, 1)
const HOVER_MODULATE := Color(1.15, 1.08, 0.96, 1)
const TEXT_DARK := Color("3c251b")
const TEXT_MUTED := Color("ad673c")

var _player: Node2D = null
var _shelf: Shelf = null
var _panel_root: Control
var _panel_art: Node2D
var _grid_viewport: Control
var _grid: GridContainer
var _empty_label: Label
var _scroll_value: float = 0.0
var _scroll_max: float = 0.0
var _panel_tween: Tween = null
var _panel_size := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_scene_nodes()
	_set_panel_visible(false, true)


func show_for_shelf(player: Node2D, shelf: Shelf) -> void:
	_disconnect_shelf_signals()
	_player = player
	_shelf = shelf
	if _shelf != null:
		if not _shelf.item_placed.is_connected(_on_shelf_stock_changed):
			_shelf.item_placed.connect(_on_shelf_stock_changed)
		if not _shelf.item_removed.is_connected(_on_shelf_stock_changed):
			_shelf.item_removed.connect(_on_shelf_stock_changed)
		if not _shelf.shelf_invalidated.is_connected(_on_shelf_invalidated):
			_shelf.shelf_invalidated.connect(_on_shelf_invalidated)

	if not _has_required_scene_nodes():
		return

	_position_panel()
	_refresh()
	_set_panel_visible(true)


func close_panel() -> void:
	_set_panel_visible(false)


func _process(_delta: float) -> void:
	if _panel_root == null or not _panel_root.visible:
		return
	if not is_instance_valid(_shelf):
		close_panel()
		return
	if _player != null and is_instance_valid(_player):
		if _player.global_position.distance_to(_shelf.global_position) > CLOSE_DISTANCE:
			close_panel()


func _unhandled_input(event: InputEvent) -> void:
	if _panel_root == null or not _panel_root.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_panel()
		accept_event()


func _bind_scene_nodes() -> void:
	_panel_root = _require_control("PanelRoot")
	_panel_art = _require_node2d("PanelRoot/PanelArtwork")
	_grid_viewport = _require_control("PanelRoot/GridViewport")
	_grid = get_node_or_null("PanelRoot/GridViewport/ShelfStockGrid") as GridContainer
	if _grid == null:
		push_error("ShelfStockPanel scene missing required GridContainer node: PanelRoot/GridViewport/ShelfStockGrid")
	_empty_label = get_node_or_null("PanelRoot/GridViewport/EmptyLabel") as Label
	if _empty_label == null:
		push_error("ShelfStockPanel scene missing required Label node: PanelRoot/GridViewport/EmptyLabel")

	if not _has_required_scene_nodes():
		return

	_panel_size = _get_control_size(_panel_root)
	if not _grid_viewport.gui_input.is_connected(_on_grid_gui_input):
		_grid_viewport.gui_input.connect(_on_grid_gui_input)

	_position_panel()


func _position_panel() -> void:
	if _panel_root == null:
		return

	var viewport_size := get_viewport_rect().size
	if _panel_size == Vector2.ZERO:
		_panel_size = _get_control_size(_panel_root)
	_panel_root.position = (viewport_size - _panel_size) * 0.5


func _get_control_size(control: Control) -> Vector2:
	var control_size := control.size
	if control_size.x <= 0.0 or control_size.y <= 0.0:
		control_size = control.custom_minimum_size
	return control_size


func _refresh() -> void:
	if _grid == null or _empty_label == null:
		return

	for child in _grid.get_children():
		child.queue_free()

	var entries := _get_shelf_entries()
	_empty_label.visible = entries.is_empty()
	for entry in entries:
		var card := _make_stock_card(entry["item_id"], entry["quantity"])
		if card != null:
			_grid.add_child(card)

	_update_scroll_metrics()


func _get_shelf_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not is_instance_valid(_shelf):
		return entries

	var counts: Dictionary = {}
	if _shelf.has_method("get_stock_counts"):
		counts = _shelf.get_stock_counts()
	for item in ItemDatabase.get_items_by_shelf(_shelf.shelf_type):
		if item == null:
			continue
		entries.append({
			"item_id": item.item_id,
			"name": item.display_name,
			"quantity": int(counts.get(item.item_id, 0))
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var quantity_a := int(a.get("quantity", 0))
		var quantity_b := int(b.get("quantity", 0))
		if quantity_a != quantity_b:
			return quantity_a > quantity_b
		return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
	)
	return entries


func _make_stock_card(item_id: String, quantity: int) -> Control:
	var card := SHELF_STOCK_CARD_SCENE.instantiate() as Button
	if card == null:
		push_error("ShelfStockCard scene failed to instantiate.")
		return null

	var icon := card.get_node_or_null("IconSprite") as Sprite2D
	var label := card.get_node_or_null("NameLabel") as Label
	if icon == null or label == null:
		push_error("ShelfStockCard scene missing required IconSprite or NameLabel node.")
		card.queue_free()
		return null

	if not card.gui_input.is_connected(_on_grid_gui_input):
		card.gui_input.connect(_on_grid_gui_input)

	var item := ItemDatabase.get_item(item_id)
	if item != null:
		icon.texture = item.get_icon()
	var icon_modulate := Color(1.0, 1.0, 1.0, 0.55)
	if quantity > 0:
		icon_modulate = NORMAL_MODULATE
	icon.modulate = icon_modulate

	label.text = _get_stock_label(item_id, quantity)
	var label_color := TEXT_MUTED
	if quantity > 0:
		label_color = TEXT_DARK
	label.add_theme_color_override("font_color", label_color)

	card.mouse_entered.connect(func() -> void:
		_tween_card(card, icon, Vector2(1.05, 1.05), HOVER_MODULATE)
	)
	card.mouse_exited.connect(func() -> void:
		_tween_card(card, icon, Vector2.ONE, icon_modulate)
	)

	return card


func _require_control(node_path: NodePath) -> Control:
	var node := get_node_or_null(node_path) as Control
	if node == null:
		push_error("ShelfStockPanel scene missing required Control node: %s" % node_path)
	return node


func _require_node2d(node_path: NodePath) -> Node2D:
	var node := get_node_or_null(node_path) as Node2D
	if node == null:
		push_error("ShelfStockPanel scene missing required Node2D node: %s" % node_path)
	return node


func _has_required_scene_nodes() -> bool:
	return (
		_panel_root != null
		and _panel_art != null
		and _grid_viewport != null
		and _grid != null
		and _empty_label != null
	)


func _get_stock_label(item_id: String, quantity: int) -> String:
	var item := ItemDatabase.get_item(item_id)
	var item_name := item_id.capitalize()
	if item != null:
		item_name = item.display_name
	return "%s\nx%d" % [item_name, quantity]


func _set_panel_visible(visible_state: bool, immediate: bool = false) -> void:
	if _panel_root == null:
		return

	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()

	if visible_state:
		_panel_root.visible = true

	if immediate:
		_panel_root.visible = visible_state
		_panel_root.modulate.a = 1.0 if visible_state else 0.0
		_panel_root.scale = Vector2.ONE if visible_state else Vector2(0.96, 0.96)
		return

	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(_panel_root, "modulate:a", 1.0 if visible_state else 0.0, ANIM_DURATION)
	_panel_tween.tween_property(
		_panel_root,
		"scale",
		Vector2.ONE if visible_state else Vector2(0.96, 0.96),
		ANIM_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if not visible_state:
		_panel_tween.finished.connect(func() -> void:
			if _panel_root != null:
				_panel_root.visible = false
		)


func _on_grid_gui_input(event: InputEvent) -> void:
	var delta := _get_scroll_delta(event)
	if is_zero_approx(delta):
		return

	_set_scroll(_scroll_value + delta)
	accept_event()


func _get_scroll_delta(event: InputEvent) -> float:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			return -SCROLL_STEP * event.factor
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return SCROLL_STEP * event.factor
	elif event is InputEventPanGesture:
		return event.delta.y * SCROLL_STEP

	return 0.0


func _update_scroll_metrics() -> void:
	await get_tree().process_frame
	if _grid == null or _grid_viewport == null:
		return

	var content_height := maxf(_grid.get_combined_minimum_size().y, _grid.size.y)
	_scroll_max = maxf(content_height - _grid_viewport.size.y, 0.0)
	_set_scroll(clampf(_scroll_value, 0.0, _scroll_max))


func _set_scroll(value: float) -> void:
	_scroll_value = clampf(value, 0.0, _scroll_max)
	if _grid != null:
		_grid.position.y = -roundf(_scroll_value)


func _tween_card(card: Control, icon: CanvasItem, target_scale: Vector2, target_modulate: Color) -> void:
	if card == null or not is_instance_valid(card):
		return

	if card.has_meta("hover_tween"):
		var active_tween := card.get_meta("hover_tween") as Tween
		if active_tween != null and active_tween.is_valid():
			active_tween.kill()

	var tween := card.create_tween()
	card.set_meta("hover_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(card, "scale", target_scale, ANIM_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if icon != null and is_instance_valid(icon):
		tween.tween_property(icon, "modulate", target_modulate, ANIM_DURATION)


func _on_shelf_stock_changed(_slot_index: int, _item_id: String) -> void:
	_refresh()


func _on_shelf_invalidated(_shelf_ref: Shelf, _old_revision: int, _new_revision: int) -> void:
	_refresh()


func _disconnect_shelf_signals() -> void:
	if not is_instance_valid(_shelf):
		return
	if _shelf.item_placed.is_connected(_on_shelf_stock_changed):
		_shelf.item_placed.disconnect(_on_shelf_stock_changed)
	if _shelf.item_removed.is_connected(_on_shelf_stock_changed):
		_shelf.item_removed.disconnect(_on_shelf_stock_changed)
	if _shelf.shelf_invalidated.is_connected(_on_shelf_invalidated):
		_shelf.shelf_invalidated.disconnect(_on_shelf_invalidated)


func _exit_tree() -> void:
	_disconnect_shelf_signals()
