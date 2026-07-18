class_name YardRestockFlow
extends Node

const RestockPackage = preload("res://scripts/objects/RestockPackage.gd")

var yard: Node = null


func setup(yard_node: Node) -> void:
	yard = yard_node


func set_restock_deliveries(deliveries: Array) -> void:
	yard._restock_deliveries.clear()

	for delivery in deliveries:
		if delivery is Dictionary:
			yard._restock_deliveries.append((delivery as Dictionary).duplicate())

	refresh_restock_packages()


func refresh_restock_packages() -> void:
	if yard.restock_drop_zone == null:
		return

	for child in yard.restock_drop_zone.get_children():
		if child is RestockPackage:
			child.queue_free()

	if yard._restock_deliveries.is_empty():
		return

	var markers := get_restock_drop_markers()
	var marker_count := markers.size()
	var package := RestockPackage.new()
	package.name = "RestockSupplyBox"
	yard.restock_drop_zone.add_child(package)
	package.setup_deliveries(yard._restock_deliveries)

	if marker_count > 0:
		package.global_position = markers[0].global_position
	else:
		package.position = Vector2(80, 220)

	var collected_callable := Callable(yard, "_on_restock_package_collected")

	if not package.collected.is_connected(collected_callable):
		package.collected.connect(collected_callable)


func get_restock_drop_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []

	if yard.restock_drop_zone == null:
		return markers

	for child in yard.restock_drop_zone.get_children():
		if child is Marker2D:
			markers.append(child as Marker2D)

	markers.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return a.name < b.name
	)
	return markers


func on_restock_package_collected(delivery_id: int) -> void:
	if delivery_id < 0:
		yard._restock_deliveries.clear()
	else:
		for i in range(yard._restock_deliveries.size() - 1, -1, -1):
			if int(yard._restock_deliveries[i].get("id", -1)) == delivery_id:
				yard._restock_deliveries.remove_at(i)
				break

	yard.restock_delivery_collected.emit(delivery_id)
