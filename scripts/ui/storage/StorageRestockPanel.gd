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
	var purchase_button := _require_button(panel, "PurchaseButton")
	var close_button := _require_button(panel, "CloseButton")
	var scrollbar_sprite := _require_sprite(panel, "ScrollBar")
	var scrollbar_hitbox := _require_control(panel, "RestockScrollHitbox")
	var scrollbar_thumb := _require_color_rect(panel, "RestockScrollHitbox/Thumb")
	var missing_required := (
		list_area == null
		or detail_area == null
		or item_scroll == null
		or item_list == null
		or wallet_label == null
		or selected_label == null
		or guide_label == null
		or purchase_button == null
		or close_button == null
		or scrollbar_sprite == null
		or scrollbar_hitbox == null
		or scrollbar_thumb == null
	)
	if missing_required:
		layer.queue_free()
		return {}

	return {
		"layer": layer,
		"panel": panel,
		"list_area": list_area,
		"item_scroll": item_scroll,
		"item_list": item_list,
		"wallet_label": wallet_label,
		"selected_label": selected_label,
		"guide_label": guide_label,
		"purchase_button": purchase_button,
		"close_button": close_button,
		"add_button": null,
		"delete_button": null,
		"scrollbar_sprite": scrollbar_sprite,
		"scrollbar_hitbox": scrollbar_hitbox,
		"scrollbar_thumb": scrollbar_thumb
	}


static func clear_container(container: Container) -> void:
	if container == null:
		return

	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


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


static func _require_color_rect(panel: Control, node_path: NodePath) -> ColorRect:
	var node := panel.get_node_or_null(node_path) as ColorRect
	if node == null:
		push_error("StorageRestockPanel scene missing required ColorRect node: %s" % node_path)
	return node
