class_name StorageRestockPanel
extends RefCounted

const RESTOCK_PANEL_SCENE: PackedScene = preload(
	"res://scenes/locations/storage/restock/StorageRestockPanel.tscn"
)


static func ensure(owner: Node) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "StorageRestockLayer"
	layer.layer = 20
	layer.visible = false
	owner.add_child(layer)

	var panel := RESTOCK_PANEL_SCENE.instantiate() as Control
	layer.add_child(panel)

	var list_area := _require_control(panel, "RestockUiItemList")
	var detail_area := _require_control(panel, "DetailArea")
	var item_scroll := _require_scroll_container(panel, "ItemScroll")
	var item_list := _require_vbox_container(panel, "ItemScroll/ItemMargin/ItemList")
	var wallet_label := _require_label(panel, "DetailArea/DetailColumn/WalletLabel")
	var selected_label := _require_label(panel, "DetailArea/DetailColumn/SelectedLabel")
	var guide_label := _require_label(panel, "DetailArea/DetailColumn/GuideLabel")
	var action_row := _require_container(panel, "DetailArea/DetailColumn/ActionRow")
	var purchase_button := _require_button(panel, "PurchaseButton")
	var close_button := _require_button(panel, "CloseButton")
	var scrollbar_sprite := _require_sprite(panel, "ScrollBar")
	var missing_required := (
		list_area == null
		or detail_area == null
		or item_scroll == null
		or item_list == null
		or wallet_label == null
		or selected_label == null
		or guide_label == null
		or action_row == null
		or purchase_button == null
		or close_button == null
		or scrollbar_sprite == null
	)
	if missing_required:
		layer.queue_free()
		return {}

	_hide_list_layout_guides(list_area, panel)
	_configure_scene_runtime_behavior(item_scroll, selected_label, guide_label)

	return {
		"layer": layer,
		"panel": panel,
		"list_area": list_area,
		"item_scroll": item_scroll,
		"item_list": item_list,
		"wallet_label": wallet_label,
		"selected_label": selected_label,
		"guide_label": guide_label,
		"action_row": action_row,
		"purchase_button": purchase_button,
		"close_button": close_button,
		"add_button": null,
		"delete_button": null,
		"scrollbar_sprite": scrollbar_sprite
	}


static func clear_container(container: Container) -> void:
	if container == null:
		return

	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func _hide_list_layout_guides(list_area: Control, _panel: Control) -> void:
	if list_area != null and list_area.name == "RestockUiItemList":
		for child in list_area.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		return


static func _hide_builtin_scrollbar(scroll: ScrollContainer) -> void:
	var scrollbar := scroll.get_v_scroll_bar()
	if scrollbar == null:
		return

	scrollbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrollbar.modulate = Color(1, 1, 1, 0)


static func _configure_scene_runtime_behavior(
	item_scroll: ScrollContainer,
	selected_label: Label,
	guide_label: Label
) -> void:
	item_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	item_scroll.follow_focus = true
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hide_builtin_scrollbar(item_scroll)

	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_label.max_lines_visible = 2


static func _require_control(panel: Control, node_path: NodePath) -> Control:
	var node := panel.get_node_or_null(node_path) as Control
	if node == null:
		push_error("StorageRestockPanel scene missing required Control node: %s" % node_path)
	return node


static func _require_scroll_container(panel: Control, node_path: NodePath) -> ScrollContainer:
	var node := panel.get_node_or_null(node_path) as ScrollContainer
	if node == null:
		push_error("StorageRestockPanel scene missing required ScrollContainer node: %s" % node_path)
	return node


static func _require_vbox_container(panel: Control, node_path: NodePath) -> VBoxContainer:
	var node := panel.get_node_or_null(node_path) as VBoxContainer
	if node == null:
		push_error("StorageRestockPanel scene missing required VBoxContainer node: %s" % node_path)
	return node


static func _require_container(panel: Control, node_path: NodePath) -> Container:
	var node := panel.get_node_or_null(node_path) as Container
	if node == null:
		push_error("StorageRestockPanel scene missing required Container node: %s" % node_path)
	return node


static func _require_label(panel: Control, node_path: NodePath) -> Label:
	var node := panel.get_node_or_null(node_path) as Label
	if node == null:
		push_error("StorageRestockPanel scene missing required Label node: %s" % node_path)
	return node


static func _require_button(panel: Control, node_path: NodePath) -> Button:
	var node := panel.get_node_or_null(node_path) as Button
	if node == null:
		push_error("StorageRestockPanel scene missing required Button node: %s" % node_path)
	return node


static func _require_sprite(panel: Control, node_path: NodePath) -> Sprite2D:
	var node := panel.get_node_or_null(node_path) as Sprite2D
	if node == null:
		push_error("StorageRestockPanel scene missing required Sprite2D node: %s" % node_path)
	return node
