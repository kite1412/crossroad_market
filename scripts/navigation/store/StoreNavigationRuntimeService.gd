class_name StoreNavigationRuntimeService
extends "res://scripts/navigation/store/StoreNavigationService.gd"


func should_repair_route(
	start_position: Vector2,
	route: Array[Vector2],
	built_revision: int
) -> bool:
	refresh_dynamic_state()
	if built_revision < 0:
		return true
	if built_revision == get_revision():
		return false
	var dirty_regions := _obstacles.get_dirty_regions_since(built_revision)
	return _obstacles.route_intersects_regions(
		start_position,
		route,
		dirty_regions
	)


func get_dirty_regions_since(revision: int) -> Array[Rect2]:
	refresh_dynamic_state()
	return _obstacles.get_dirty_regions_since(revision)
