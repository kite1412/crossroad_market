class_name YardRestockFlow
extends Node


var yard: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(yard_node: Node) -> void:
	yard = yard_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_restock_deliveries(deliveries: Array) -> void:
	yard._restock_deliveries.clear()

	for delivery in deliveries:
		if delivery is Dictionary:
			yard._restock_deliveries.append((delivery as Dictionary).duplicate())

	refresh_restock_packages()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func refresh_restock_packages() -> void:
	if yard.restock_drop_zone == null:
		return

	for child in yard.restock_drop_zone.get_children():
		if child is RestockPackage:
			child.queue_free()

	if yard._restock_deliveries.is_empty():
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var markers := get_restock_drop_markers()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var marker_count := markers.size()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var package := RestockPackage.new()
	package.name = "RestockSupplyBox"
	yard.restock_drop_zone.add_child(package)
	package.setup_deliveries(yard._restock_deliveries)

	if marker_count > 0:
		package.global_position = markers[0].global_position
	else:
		package.position = Vector2(80, 220)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var collected_callable := Callable(yard, "_on_restock_package_collected")

	if not package.collected.is_connected(collected_callable):
		package.collected.connect(collected_callable)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_restock_drop_markers() -> Array[Marker2D]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_restock_package_collected(delivery_id: int) -> void:
	if delivery_id < 0:
		yard._restock_deliveries.clear()
	else:
		for i in range(yard._restock_deliveries.size() - 1, -1, -1):
			if int(yard._restock_deliveries[i].get("id", -1)) == delivery_id:
				yard._restock_deliveries.remove_at(i)
				break

	yard.restock_delivery_collected.emit(delivery_id)
