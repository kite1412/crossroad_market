class_name Shelf
extends Node2D

@export var shelf_type: ItemData.ShelfType = ItemData.ShelfType.HUMAN
@export var max_slots: int = 6

signal item_placed(slot_index: int, item_id: String)
signal item_removed(slot_index: int, item_id: String)

var _slots: Array = []

func _ready() -> void:
	_slots.resize(max_slots)
	_slots.fill(null)
	_apply_shelf_color()

func _apply_shelf_color() -> void:
	var color_rect = $ColorRect
	if color_rect == null:
		return
	if shelf_type == ItemData.ShelfType.HUMAN:
		color_rect.color = Color(0.7, 0.5, 0.3, 1.0)
	else:
		# ghost shelf starts dim, revealed after mystery box discovery
		color_rect.color = Color(0.15, 0.1, 0.25, 0.7)

func apply_ghost_glow(enabled: bool) -> void:
	var color_rect = $ColorRect
	if color_rect == null:
		return
	if enabled:
		color_rect.color = Color(0.5, 0.35, 0.9, 1.0)  # glowing purple
	else:
		color_rect.color = Color(0.15, 0.1, 0.25, 0.7)

func place_item(item_id: String) -> int:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		push_warning("Shelf: item '%s' not found in database" % item_id)
		return -1

	if item.shelf_type != shelf_type:
		return -1

	var slot := _get_empty_slot()
	if slot == -1:
		return -1

	if not Inventory.remove_item(item_id):
		return -1

	_slots[slot] = item_id
	item_placed.emit(slot, item_id)
	return slot

func stock_item_direct(item_id: String) -> int:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		push_warning("Shelf: item '%s' not found in database" % item_id)
		return -1

	if item.shelf_type != shelf_type:
		return -1

	var slot := _get_empty_slot()
	if slot == -1:
		return -1

	_slots[slot] = item_id
	item_placed.emit(slot, item_id)
	return slot

func remove_item(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= max_slots:
		return ""

	var item_id: String = _slots[slot_index]
	if item_id == null:
		return ""

	_slots[slot_index] = null
	Inventory.add_item(item_id)
	item_removed.emit(slot_index, item_id)
	return item_id

func remove_first_item() -> String:
	for i in max_slots:
		if _slots[i] != null:
			return remove_item(i)

	return ""

func take_item_for_npc(item_id: String) -> bool:
	for i in max_slots:
		if _slots[i] == item_id:
			_slots[i] = null
			item_removed.emit(i, item_id)
			return true
	return false

func has_item(item_id: String) -> bool:
	return _slots.has(item_id)

func has_stock() -> bool:
	for item_id in _slots:
		if item_id != null:
			return true

	return false

func get_slot_content(slot_index: int) -> String:
	return _slots[slot_index] if _slots[slot_index] != null else ""


func get_slot_contents() -> Array[String]:
	var contents: Array[String] = []

	for slot_index in max_slots:
		contents.append(get_slot_content(slot_index))

	return contents


func restore_slot_contents(contents: Array[String]) -> void:
	_slots.resize(max_slots)
	_slots.fill(null)

	var limit: int = mini(contents.size(), max_slots)

	for slot_index in limit:
		var item_id := str(contents[slot_index])

		if item_id == "":
			continue

		var item: ItemData = ItemDatabase.get_item(item_id)

		if item != null and item.shelf_type == shelf_type:
			_slots[slot_index] = item_id


func _get_empty_slot() -> int:
	for i in max_slots:
		if _slots[i] == null:
			return i
	return -1
