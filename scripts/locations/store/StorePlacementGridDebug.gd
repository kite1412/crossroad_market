@tool
class_name StorePlacementSurface
extends Node2D


@export var surface_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(0, 0),
	Vector2(450, 0),
	Vector2(450, 180),
	Vector2(0, 180)
]):
	set(value):
		surface_polygon = value
		queue_redraw()
@export_range(4.0, 48.0, 1.0) var anchor_spacing: float = 18.0:
	set(value):
		anchor_spacing = maxf(4.0, value)
		queue_redraw()
@export var visible_in_game: bool = false
@export var point_radius: float = 2.0:
	set(value):
		point_radius = maxf(0.5, value)
		queue_redraw()
@export var surface_color: Color = Color(0.2, 0.85, 1.0, 0.16):
	set(value):
		surface_color = value
		queue_redraw()
@export var border_color: Color = Color(0.3, 1.0, 0.7, 0.65):
	set(value):
		border_color = value
		queue_redraw()
@export var point_color: Color = Color(0.3, 1.0, 0.7, 0.9):
	set(value):
		point_color = value
		queue_redraw()

@warning_ignore("unused_private_class_variable")
var _sampler := StorePlacementGrid.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	if not Engine.is_editor_hint() and not visible_in_game:
		visible = false
	set_process(Engine.is_editor_hint())
	queue_redraw()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process(_delta: float) -> void:
	queue_redraw()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_anchor_positions() -> Array[Vector2]:
	_sampler.setup(_get_global_polygon(), anchor_spacing)
	return _sampler.get_positions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_surface_polygon_global() -> PackedVector2Array:
	return _get_global_polygon()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _draw() -> void:
	if surface_polygon.size() < 3:
		return

	draw_colored_polygon(surface_polygon, surface_color)
	draw_polyline(_get_closed_local_polygon(), border_color, 1.0)

	for anchor in _get_local_anchor_positions():
		draw_circle(anchor, point_radius, point_color)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_global_polygon() -> PackedVector2Array:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var global_polygon := PackedVector2Array()

	for point in surface_polygon:
		global_polygon.append(to_global(point))

	return global_polygon


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_closed_local_polygon() -> PackedVector2Array:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var closed_polygon := surface_polygon.duplicate()

	if closed_polygon.size() > 0:
		closed_polygon.append(closed_polygon[0])

	return closed_polygon


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_local_anchor_positions() -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var anchors: Array[Vector2] = []

	for global_anchor in get_anchor_positions():
		anchors.append(to_local(global_anchor))

	return anchors
