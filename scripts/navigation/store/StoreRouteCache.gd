class_name StoreRouteCache
extends RefCounted

const MAX_ENTRIES: int = 128

var _entries: Dictionary = {}
var _clock: int = 0
var _obstacles: StoreDynamicObstacleTracker = null


func setup(obstacles: StoreDynamicObstacleTracker) -> void:
	_obstacles = obstacles


func get_route(
	cache_key: String,
	start_position: Vector2,
	current_revision: int
) -> Array[Vector2]:
	if not _entries.has(cache_key):
		return []
	var entry: Dictionary = _entries[cache_key]
	var route_variant: Variant = entry.get("route", [])
	if not (route_variant is Array):
		_entries.erase(cache_key)
		return []
	var route := _to_vector2_array(route_variant)
	var entry_revision := int(entry.get("revision", -1))
	if entry_revision == current_revision:
		_touch(cache_key, entry)
		return route
	if _obstacles == null:
		_entries.erase(cache_key)
		return []

	var dirty_regions := _obstacles.get_dirty_regions_since(entry_revision)
	if _obstacles.route_intersects_regions(
		start_position,
		route,
		dirty_regions
	):
		_entries.erase(cache_key)
		return []

	entry["revision"] = current_revision
	_touch(cache_key, entry)
	return route


func put_route(
	cache_key: String,
	start_position: Vector2,
	route: Array[Vector2],
	revision: int
) -> void:
	if route.is_empty():
		return
	_clock += 1
	_entries[cache_key] = {
		"start": start_position,
		"route": route.duplicate(),
		"revision": revision,
		"access": _clock
	}
	_trim()


func invalidate_all() -> void:
	_entries.clear()


func invalidate_for_regions(regions: Array[Rect2]) -> void:
	if _obstacles == null or regions.is_empty():
		return
	for cache_key_variant in _entries.keys():
		var cache_key := str(cache_key_variant)
		var entry: Dictionary = _entries[cache_key]
		var start_position: Vector2 = entry.get("start", Vector2.INF)
		var route := _to_vector2_array(entry.get("route", []))
		if _obstacles.route_intersects_regions(
			start_position,
			route,
			regions
		):
			_entries.erase(cache_key)


func _touch(cache_key: String, entry: Dictionary) -> void:
	_clock += 1
	entry["access"] = _clock
	_entries[cache_key] = entry


func _trim() -> void:
	while _entries.size() > MAX_ENTRIES:
		var oldest_key := ""
		var oldest_access := 2147483647
		for cache_key_variant in _entries.keys():
			var cache_key := str(cache_key_variant)
			var entry: Dictionary = _entries[cache_key]
			var access := int(entry.get("access", 0))
			if access < oldest_access:
				oldest_access = access
				oldest_key = cache_key
		if oldest_key == "":
			return
		_entries.erase(oldest_key)


func _to_vector2_array(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not (value is Array):
		return result
	for point_variant in value:
		if point_variant is Vector2:
			result.append(point_variant as Vector2)
	return result
