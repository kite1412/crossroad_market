extends Node2D

const DEPTH_POINTS_META: StringName = &"depth_points"
const DEPTH_BASELINES_META: StringName = &"depth_y_values"
const ACTIVE_RECT_META: StringName = &"depth_active_rect"
const DEFAULT_INDEX_META: StringName = &"depth_default_index"
const VISUAL_TOP_META: StringName = &"visual_top_y"


class TreeCluster:
	var anchor: Node2D
	var visual: Sprite2D
	var depth_points: PackedVector2Array
	var baselines: PackedFloat32Array
	var active_rect: Rect2
	var default_depth_index: int
	var visual_top_y: float
	var active_depth_index: int = -1


var _clusters: Array[TreeCluster] = []
var _player: Node2D


func _ready() -> void:
	_collect_tree_clusters()
	set_process(not _clusters.is_empty())


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	var player_local_position: Vector2 = to_local(_player.global_position)
	for cluster: TreeCluster in _clusters:
		_apply_nearest_trunk_depth(cluster, player_local_position)


func _collect_tree_clusters() -> void:
	for child: Node in get_children():
		var anchor: Node2D = child as Node2D
		if anchor == null or not anchor.has_meta(DEPTH_BASELINES_META):
			continue

		var visual: Sprite2D = anchor.get_node_or_null("Visual") as Sprite2D
		var points_value: Variant = anchor.get_meta(DEPTH_POINTS_META, PackedVector2Array())
		var baselines_value: Variant = anchor.get_meta(DEPTH_BASELINES_META, PackedFloat32Array())
		var active_rect_value: Variant = anchor.get_meta(ACTIVE_RECT_META, Rect2())
		if (
			visual == null
			or not points_value is PackedVector2Array
			or not baselines_value is PackedFloat32Array
			or not active_rect_value is Rect2
		):
			continue

		var depth_points: PackedVector2Array = points_value as PackedVector2Array
		var baselines: PackedFloat32Array = baselines_value as PackedFloat32Array
		if baselines.size() != depth_points.size() or baselines.is_empty():
			push_warning("Tree cluster '%s' needs one baseline for every depth point." % anchor.name)
			continue

		var cluster: TreeCluster = TreeCluster.new()
		cluster.anchor = anchor
		cluster.visual = visual
		cluster.depth_points = depth_points
		cluster.baselines = baselines
		cluster.active_rect = active_rect_value as Rect2
		cluster.default_depth_index = clampi(int(anchor.get_meta(DEFAULT_INDEX_META, 0)), 0, baselines.size() - 1)
		cluster.visual_top_y = float(anchor.get_meta(VISUAL_TOP_META, visual.global_position.y))
		_clusters.append(cluster)


func _apply_nearest_trunk_depth(cluster: TreeCluster, player_local_position: Vector2) -> void:
	var depth_index: int = cluster.default_depth_index
	if cluster.active_rect.has_point(player_local_position):
		var nearest_distance_squared: float = INF
		for index: int in cluster.depth_points.size():
			var distance_squared: float = player_local_position.distance_squared_to(cluster.depth_points[index])
			if distance_squared < nearest_distance_squared:
				nearest_distance_squared = distance_squared
				depth_index = index

	if cluster.active_depth_index == depth_index:
		return

	var baseline_y: float = cluster.baselines[depth_index]
	cluster.anchor.position.y = baseline_y
	cluster.visual.position.y = cluster.visual_top_y - baseline_y
	cluster.active_depth_index = depth_index
