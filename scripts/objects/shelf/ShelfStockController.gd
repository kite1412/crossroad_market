class_name ShelfStockController
extends RefCounted

const ShelfItemIndexScript = preload("res://scripts/objects/shelf/ShelfItemIndex.gd")

var shelf: Shelf = null
var _next_reservation_id: int = 0
var _item_reservations: Dictionary = {}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(shelf_node: Shelf) -> void:
	shelf = shelf_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func initialize_slots() -> void:
	shelf._slots.resize(shelf.max_slots)
	shelf._slots.fill(null)
	shelf._slot_quantities.resize(shelf.max_slots)
	shelf._slot_quantities.fill(0)
	shelf._slot_reserved_quantities.resize(shelf.max_slots)
	shelf._slot_reserved_quantities.fill(0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func place_item(item_id: String) -> int:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		pass
		return -1

	if item.shelf_type != shelf.shelf_type:
		return -1

	if not Inventory.remove_item(item_id):
		return -1

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var slot := find_item_slot(item_id)
	if slot == -1:
		slot = get_empty_slot()
		if slot == -1:
			Inventory.add_item(item_id)
			return -1

	shelf._slots[slot] = item_id
	shelf._slot_quantities[slot] += 1
	ShelfItemIndexScript.register_shelf_item(shelf, item_id)
	shelf._refresh_slot_visual(slot, item_id)
	shelf.item_placed.emit(slot, item_id)
	return slot


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func stock_item_direct(item_id: String) -> int:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		pass
		return -1

	if item.shelf_type != shelf.shelf_type:
		return -1

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var slot := find_item_slot(item_id)
	if slot == -1:
		slot = get_empty_slot()
		if slot == -1:
			return -1

	shelf._slots[slot] = item_id
	shelf._slot_quantities[slot] += 1
	ShelfItemIndexScript.register_shelf_item(shelf, item_id)
	shelf._refresh_slot_visual(slot, item_id)
	shelf.item_placed.emit(slot, item_id)
	return slot


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func remove_item(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= shelf._slots.size():
		return ""

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_id: String = shelf._slots[slot_index]
	if item_id == null:
		return ""
	if get_available_quantity(slot_index) <= 0:
		return ""

	shelf._slot_quantities[slot_index] -= 1
	if shelf._slot_quantities[slot_index] <= 0:
		shelf._slot_quantities[slot_index] = 0
		shelf._slots[slot_index] = null
		ShelfItemIndexScript.unregister_shelf_item(shelf, item_id)
	shelf._refresh_slot_visual(slot_index, "")
	Inventory.add_item(item_id)
	shelf.item_removed.emit(slot_index, item_id)
	return item_id


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func remove_first_item() -> String:
	for i in shelf._slots.size():
		if shelf._slots[i] != null:
			return remove_item(i)

	return ""


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func take_item_for_npc(item_id: String) -> bool:
	for i in shelf._slots.size():
		if shelf._slots[i] == item_id and get_available_quantity(i) > 0:
			shelf._slot_quantities[i] -= 1
			if shelf._slot_quantities[i] <= 0:
				shelf._slot_quantities[i] = 0
				shelf._slots[i] = null
				ShelfItemIndexScript.unregister_shelf_item(shelf, item_id)
			shelf._refresh_slot_visual(i, "")
			shelf.item_removed.emit(i, item_id)
			return true
	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_item(item_id: String) -> bool:
	for i in shelf._slots.size():
		if shelf._slots[i] == item_id and get_available_quantity(i) > 0:
			return true
	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_stock() -> bool:
	for item_id in shelf._slots:
		if item_id != null:
			return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_first_stocked_item_id() -> String:
	for i in shelf._slots.size():
		if shelf._slots[i] != null and get_available_quantity(i) > 0:
			return shelf._slots[i]

	return ""


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_stock_counts() -> Dictionary:
	var counts: Dictionary = {}
	for i in shelf._slots.size():
		var item_id = shelf._slots[i]
		if item_id == null:
			continue

		var quantity := shelf._slot_quantities[i]
		if quantity <= 0:
			continue

		var key := str(item_id)
		counts[key] = int(counts.get(key, 0)) + quantity

	return counts


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func reserve_item_for_npc(item_id: String, npc: Node) -> Dictionary:
	if shelf.get_lifecycle() != Shelf.LIFECYCLE_PLACED:
		return _reservation_result(false, &"shelf_unavailable")

	var slot_index: int = find_available_item_slot(item_id)
	if slot_index < 0:
		return _reservation_result(false, &"out_of_stock")

	_next_reservation_id += 1
	var token_id: StringName = StringName(
		"%s_item_%d" % [
			str(shelf.get_shelf_id()),
			_next_reservation_id
		]
	)
	var owner_id: int = npc.get_instance_id() if npc != null else 0
	var token: Dictionary = {
		"token_id": token_id,
		"owner_id": owner_id,
		"shelf_id": shelf.get_shelf_id(),
		"shelf_revision": shelf.get_revision(),
		"item_id": item_id,
		"slot_index": slot_index,
		"status": &"active"
	}

	shelf._slot_reserved_quantities[slot_index] += 1
	_item_reservations[token_id] = token.duplicate()
	return {
		"ok": true,
		"reason": &"reserved",
		"token": token
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func commit_npc_item_reservation(token: Dictionary, npc: Node) -> Dictionary:
	var token_id: StringName = StringName(str(token.get("token_id", StringName())))
	if token_id == StringName() or not _item_reservations.has(token_id):
		return _reservation_result(false, &"reservation_missing")

	var reservation: Dictionary = _item_reservations[token_id]
	if StringName(str(reservation.get("status", &"active"))) == &"committed":
		return {
			"ok": true,
			"reason": &"already_committed",
			"item_id": str(reservation.get("item_id", ""))
		}

	var owner_id: int = npc.get_instance_id() if npc != null else 0
	if owner_id != int(reservation.get("owner_id", 0)):
		return _reservation_result(false, &"owner_mismatch")

	if shelf.get_lifecycle() != Shelf.LIFECYCLE_PLACED:
		cancel_npc_item_reservation(reservation)
		return _reservation_result(false, &"shelf_unavailable")

	if shelf.get_revision() != int(reservation.get("shelf_revision", -1)):
		cancel_npc_item_reservation(reservation)
		return _reservation_result(false, &"shelf_changed")

	var slot_index: int = int(reservation.get("slot_index", -1))
	var item_id: String = str(reservation.get("item_id", ""))
	if slot_index < 0 or slot_index >= shelf._slots.size():
		cancel_npc_item_reservation(reservation)
		return _reservation_result(false, &"slot_missing")

	if shelf._slots[slot_index] != item_id or shelf._slot_quantities[slot_index] <= 0:
		cancel_npc_item_reservation(reservation)
		return _reservation_result(false, &"item_missing")

	shelf._slot_quantities[slot_index] -= 1
	shelf._slot_reserved_quantities[slot_index] = maxi(
		0,
		shelf._slot_reserved_quantities[slot_index] - 1
	)
	if shelf._slot_quantities[slot_index] <= 0:
		shelf._slot_quantities[slot_index] = 0
		shelf._slots[slot_index] = null
		ShelfItemIndexScript.unregister_shelf_item(shelf, item_id)
	shelf._refresh_slot_visual(slot_index, "")
	shelf.item_removed.emit(slot_index, item_id)

	reservation["status"] = &"committed"
	_item_reservations[token_id] = reservation
	return {
		"ok": true,
		"reason": &"committed",
		"item_id": item_id
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func cancel_npc_item_reservation(token: Dictionary) -> Dictionary:
	var token_id: StringName = StringName(str(token.get("token_id", StringName())))
	if token_id == StringName() or not _item_reservations.has(token_id):
		return _reservation_result(false, &"reservation_missing")

	var reservation: Dictionary = _item_reservations[token_id]
	if StringName(str(reservation.get("status", &"active"))) == &"committed":
		return {
			"ok": true,
			"reason": &"already_committed"
		}

	var slot_index: int = int(reservation.get("slot_index", -1))
	if slot_index >= 0 and slot_index < shelf._slot_reserved_quantities.size():
		shelf._slot_reserved_quantities[slot_index] = maxi(
			0,
			shelf._slot_reserved_quantities[slot_index] - 1
		)

	reservation["status"] = &"cancelled"
	_item_reservations.erase(token_id)
	return {
		"ok": true,
		"reason": &"cancelled"
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func cancel_all_npc_item_reservations() -> void:
	for token_id in _item_reservations.keys():
		var reservation: Dictionary = _item_reservations[token_id]
		if StringName(str(reservation.get("status", &"active"))) == &"committed":
			continue

		var slot_index: int = int(reservation.get("slot_index", -1))
		if slot_index >= 0 and slot_index < shelf._slot_reserved_quantities.size():
			shelf._slot_reserved_quantities[slot_index] = maxi(
				0,
				shelf._slot_reserved_quantities[slot_index] - 1
			)

	_item_reservations.clear()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_slot_content(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= shelf._slots.size():
		return ""

	return shelf._slots[slot_index] if shelf._slots[slot_index] != null else ""


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_empty_slot() -> int:
	for i in shelf._slots.size():
		if shelf._slots[i] == null:
			return i
	return -1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_item_slot(item_id: String) -> int:
	for i in shelf._slots.size():
		if shelf._slots[i] == item_id:
			return i

	return -1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_available_item_slot(item_id: String) -> int:
	for i in shelf._slots.size():
		if shelf._slots[i] == item_id and get_available_quantity(i) > 0:
			return i
	return -1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_available_quantity(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= shelf._slot_quantities.size():
		return 0
	var reserved_quantity: int = 0
	if slot_index < shelf._slot_reserved_quantities.size():
		reserved_quantity = shelf._slot_reserved_quantities[slot_index]
	return maxi(0, shelf._slot_quantities[slot_index] - reserved_quantity)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _reservation_result(ok: bool, reason: StringName) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"token": {}
	}
