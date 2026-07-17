class_name StorePlacementGrid
extends RefCounted

var polygon: PackedVector2Array = PackedVector2Array()
var anchor_spacing: float = 18.0


func _init(surface_polygon: PackedVector2Array = PackedVector2Array(), spacing: float = 18.0) -> void:
	setup(surface_polygon, spacing)


func setup(surface_polygon: PackedVector2Array, spacing: float = 18.0) -> void:
	polygon = surface_polygon
	anchor_spacing = maxf(4.0, spacing)


func get_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if polygon.size() < 3:
		return positions

	var bounds := _get_polygon_bounds()
	var start_x := _snap_up(bounds.position.x, anchor_spacing)
	var start_y := _snap_up(bounds.position.y, anchor_spacing)
	var end_x := bounds.position.x + bounds.size.x
	var end_y := bounds.position.y + bounds.size.y

	var y := start_y
	while y <= end_y:
		var x := start_x

		while x <= end_x:
			var point := Vector2(x, y)

			if Geometry2D.is_point_in_polygon(point, polygon):
				positions.append(point)

			x += anchor_spacing

		y += anchor_spacing

	return positions


func _get_polygon_bounds() -> Rect2:
	var first := polygon[0]
	var min_position := first
	var max_position := first

	for point in polygon:
		min_position.x = minf(min_position.x, point.x)
		min_position.y = minf(min_position.y, point.y)
		max_position.x = maxf(max_position.x, point.x)
		max_position.y = maxf(max_position.y, point.y)

	return Rect2(min_position, max_position - min_position)


func _snap_up(value: float, spacing: float) -> float:
	return ceilf(value / spacing) * spacing
