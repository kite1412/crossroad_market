class_name StoreRuntimeSemanticGraph
extends "res://scripts/navigation/store/StoreSemanticGraph.gd"


func get_edge_cost(
	from_node: StringName,
	to_node: StringName,
	context: Dictionary = {}
) -> float:
	var blocked_variant: Variant = context.get("blocked_edges", {})
	if blocked_variant is Dictionary:
		var blocked_edges := blocked_variant as Dictionary
		if blocked_edges.has(make_edge_key(from_node, to_node)):
			return INF
	return super.get_edge_cost(from_node, to_node, context)


func get_nodes_touching_regions(
	regions: Array[Rect2],
	margin: float = 18.0
) -> Array[StringName]:
	var result := super.get_nodes_touching_regions(regions, margin)
	if regions.is_empty():
		return result

	var visited_edges: Dictionary = {}
	for from_node in get_node_ids():
		for to_node in get_neighbors(from_node):
			var edge_key := make_edge_key(from_node, to_node)
			if visited_edges.has(edge_key):
				continue
			visited_edges[edge_key] = true

			var from_position := get_position(from_node)
			var to_position := get_position(to_node)
			for region in regions:
				if _segment_intersects_rect(
					from_position,
					to_position,
					region.grow(margin)
				):
					if from_node not in result:
						result.append(from_node)
					if to_node not in result:
						result.append(to_node)
					break
	return result


func make_edge_key(
	from_node: StringName,
	to_node: StringName
) -> String:
	var first := String(from_node)
	var second := String(to_node)
	if first > second:
		var swap := first
		first = second
		second = swap
	return "%s<->%s" % [first, second]


func _segment_intersects_rect(
	from_position: Vector2,
	to_position: Vector2,
	rect: Rect2
) -> bool:
	if rect.has_point(from_position) or rect.has_point(to_position):
		return true
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.end,
		rect.position + Vector2(0.0, rect.size.y)
	]
	for index in range(corners.size()):
		var next_index := (index + 1) % corners.size()
		if Geometry2D.segment_intersects_segment(
			from_position,
			to_position,
			corners[index] as Vector2,
			corners[next_index] as Vector2
		) != null:
			return true
	return false
