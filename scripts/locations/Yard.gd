extends Node2D

signal return_to_store(door_type: String)
signal enter_home()
signal restock_delivery_collected(delivery_id: int)

const RestockPackage = preload("res://scripts/objects/RestockPackage.gd")

@onready var return_door: Area2D = get_node_or_null("ReturnDoor") as Area2D
@onready var home_door: Area2D = get_node_or_null("PlayerHomeArea/HomeDoor") as Area2D
@onready var restock_drop_zone: Node2D = get_node_or_null("RestockDropZone") as Node2D

var _restock_deliveries: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("location")
	add_to_group("yard")

	if return_door == null:
		push_error("Yard: ReturnDoor is missing.")
		return

	return_door.set_meta("door_type", "yard_return")

	if home_door == null:
		push_error("Yard: HomeDoor is missing.")
	else:
		home_door.set_meta("door_type", "home")


func request_return_to_store() -> bool:
	if _is_action_locked():
		return false

	return_to_store.emit("yard")
	return true


func request_enter_home() -> bool:
	if _is_action_locked():
		return false

	enter_home.emit()
	return true


func set_restock_deliveries(deliveries: Array) -> void:
	_restock_deliveries.clear()

	for delivery in deliveries:
		if delivery is Dictionary:
			_restock_deliveries.append((delivery as Dictionary).duplicate())

	_refresh_restock_packages()


func _is_action_locked() -> bool:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))


func _refresh_restock_packages() -> void:
	if restock_drop_zone == null:
		return

	for child in restock_drop_zone.get_children():
		if child is RestockPackage:
			child.queue_free()

	var markers := _get_restock_drop_markers()
	var marker_count := markers.size()

	for i in range(_restock_deliveries.size()):
		var delivery := _restock_deliveries[i]
		var package := RestockPackage.new()
		package.name = "RestockPackage%d" % int(delivery.get("id", i))
		restock_drop_zone.add_child(package)
		package.setup(
			int(delivery.get("id", i)),
			str(delivery.get("item_id", "")),
			int(delivery.get("quantity", 1))
		)

		if marker_count > 0:
			package.global_position = markers[i % marker_count].global_position
		else:
			package.position = Vector2(80 + 36 * i, 220)

		var collected_callable := Callable(self, "_on_restock_package_collected")

		if not package.collected.is_connected(collected_callable):
			package.collected.connect(collected_callable)


func _get_restock_drop_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []

	if restock_drop_zone == null:
		return markers

	for child in restock_drop_zone.get_children():
		if child is Marker2D:
			markers.append(child as Marker2D)

	markers.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return a.name < b.name
	)
	return markers


func _on_restock_package_collected(delivery_id: int) -> void:
	for i in range(_restock_deliveries.size() - 1, -1, -1):
		if int(_restock_deliveries[i].get("id", -1)) == delivery_id:
			_restock_deliveries.remove_at(i)
			break

	restock_delivery_collected.emit(delivery_id)
