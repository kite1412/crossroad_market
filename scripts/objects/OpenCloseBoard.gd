class_name OpenCloseBoard
extends StaticBody2D

const OpenCloseBoardVisualController = preload("res://scripts/objects/board/OpenCloseBoardVisualController.gd")

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

var _visual_controller: OpenCloseBoardVisualController = OpenCloseBoardVisualController.new()


func _ready() -> void:
	_visual_controller.setup(self)
	_visual_controller.ready()


func get_hover_display_name() -> String:
	return "Open/Close Board"


func set_open_state(is_open: bool, animated: bool = true) -> void:
	_visual_controller.set_open_state(is_open, animated)


func request_interaction() -> void:
	_visual_controller.request_interaction()
