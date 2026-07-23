class_name PurpleSparkleBlink
extends Node2D

const BLINK_COUNT: int = 3
const FADE_DURATION: float = 0.2
const HOLD_DURATION: float = 0.3
const BETWEEN_BLINKS_DURATION: float = 0.2
const CLUSTER_OFFSETS: Array[Vector2] = [
	Vector2(-16, -9),
	Vector2(0, -17),
	Vector2(17, -7),
	Vector2(-21, 8),
	Vector2(4, 4),
	Vector2(20, 13),
]
# Screen-space positions taken from the three panels in the supplied timing
# reference. The final beat intentionally shows two clusters together.
const BLINK_POSITION_RATIOS: Array = [
	[Vector2(0.23, 0.73)],
	[Vector2(0.81, 0.35)],
	[Vector2(0.45, 0.54), Vector2(0.575, 0.35)],
]

var _cluster_roots: Array[Node2D] = []


func _ready() -> void:
	z_index = 120
	modulate.a = 0.0


func play(viewport_size: Vector2) -> void:
	for blink_index in BLINK_COUNT:
		_build_blink_layout(blink_index, viewport_size)
		modulate.a = 0.0
		var appear := create_tween()
		appear.set_parallel(true)
		appear.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
		for cluster_root in _cluster_roots:
			cluster_root.scale = Vector2(0.72, 0.72)
			appear.tween_property(cluster_root, "scale", Vector2.ONE, FADE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await appear.finished
		await get_tree().create_timer(HOLD_DURATION).timeout

		var disappear := create_tween()
		disappear.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
		await disappear.finished
		if blink_index < BLINK_COUNT - 1:
			await get_tree().create_timer(BETWEEN_BLINKS_DURATION).timeout

	queue_free()


func _build_blink_layout(blink_index: int, viewport_size: Vector2) -> void:
	_clear_clusters()
	var position_ratios: Array = BLINK_POSITION_RATIOS[blink_index]
	for position_ratio: Vector2 in position_ratios:
		var cluster_root := Node2D.new()
		cluster_root.position = Vector2(
			roundf(viewport_size.x * position_ratio.x),
			roundf(viewport_size.y * position_ratio.y)
		)
		add_child(cluster_root)
		_cluster_roots.append(cluster_root)
		_build_sparkle_cluster(cluster_root)


func _clear_clusters() -> void:
	for cluster_root in _cluster_roots:
		if is_instance_valid(cluster_root):
			remove_child(cluster_root)
			cluster_root.queue_free()
	_cluster_roots.clear()


func _build_sparkle_cluster(cluster_root: Node2D) -> void:
	for index in CLUSTER_OFFSETS.size():
		var sparkle := Polygon2D.new()
		sparkle.position = CLUSTER_OFFSETS[index]
		var radius := 4.5 if index % 2 == 0 else 3.0
		sparkle.polygon = _make_sparkle_polygon(radius)
		sparkle.color = (
			Color(0.83, 0.54, 1.0, 1.0)
			if index % 2 == 0
			else Color(0.56, 0.25, 0.95, 1.0)
		)
		cluster_root.add_child(sparkle)


func _make_sparkle_polygon(radius: float) -> PackedVector2Array:
	var inner := radius * 0.22
	return PackedVector2Array([
		Vector2(0, -radius),
		Vector2(inner, -inner),
		Vector2(radius, 0),
		Vector2(inner, inner),
		Vector2(0, radius),
		Vector2(-inner, inner),
		Vector2(-radius, 0),
		Vector2(-inner, -inner),
	])
