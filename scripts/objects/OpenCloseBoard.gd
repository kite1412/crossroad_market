class_name OpenCloseBoard
extends StaticBody2D

const CLOSED_COLOR := Color(0.36, 0.10, 0.06, 1.0)
const OPEN_COLOR := Color(0.42, 0.78, 0.28, 1.0)
const STATUS_ANIM_DURATION: float = 0.25
const STATUS_PULSE_SCALE := Vector2(1.08, 1.08)

@onready var visual_root: Node2D = get_node_or_null("VisualRoot") as Node2D
@onready var status_panel: Polygon2D = get_node_or_null("VisualRoot/StatusPanel") as Polygon2D
@onready var status_label: Label = get_node_or_null("VisualRoot/StatusLabel") as Label
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D

var _status_tween: Tween = null
var _is_open: bool = false


func _ready() -> void:
	add_to_group("open_close_board")

	if interaction_area != null:
		interaction_area.input_pickable = true

	set_open_state(false, false)


func get_hover_display_name() -> String:
	return "Open/Close Board"


func set_open_state(is_open: bool, animated: bool = true) -> void:
	_is_open = is_open

	if status_label != null:
		status_label.text = "OPEN" if _is_open else "CLOSED"

	var target_color := OPEN_COLOR if _is_open else CLOSED_COLOR

	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = null

	if not animated:
		if status_panel != null:
			status_panel.color = target_color

		if visual_root != null:
			visual_root.scale = Vector2.ONE

		return

	_status_tween = create_tween()
	_status_tween.set_parallel(true)

	if status_panel != null:
		_status_tween.tween_property(status_panel, "color", target_color, STATUS_ANIM_DURATION)

	if visual_root != null:
		_status_tween.tween_property(visual_root, "scale", STATUS_PULSE_SCALE, 0.12)
		_status_tween.chain().tween_property(visual_root, "scale", Vector2.ONE, 0.12)


func request_interaction() -> void:
	var store := get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("request_toggle_store_open"):
		store.call("request_toggle_store_open")
