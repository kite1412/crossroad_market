class_name ActivityBoard
extends StaticBody2D

const ActivityBoardPanelFlow = preload("res://scripts/objects/activity/ActivityBoardPanelFlow.gd")
const ActivityBoardHudBridge = preload("res://scripts/objects/activity/ActivityBoardHudBridge.gd")
const ActivityBoardGlowController = preload("res://scripts/objects/activity/ActivityBoardGlowController.gd")

const DEFAULT_TITLE: String = "Today's Work"
const DEFAULT_LINES: Array[String] = [
	"Check storage for shelves and stock.",
	"Stock shelves, then serve customers."
]
const PANEL_SIZE := Vector2(292, 164)
const BOARD_GLOW_CYCLES: int = 3
const BOARD_GLOW_CYCLE_DURATION: float = 0.45

var _board_layer: CanvasLayer = null
var _board_panel: ColorRect = null
var _glow_line: Line2D = null
var _glow_tween: Tween = null
var _board_lock_active: bool = false

var _panel_flow: ActivityBoardPanelFlow = ActivityBoardPanelFlow.new()
var _hud_bridge: ActivityBoardHudBridge = ActivityBoardHudBridge.new()
var _glow_controller: ActivityBoardGlowController = ActivityBoardGlowController.new()


func _ready() -> void:
	_setup_activity_board_controllers()
	_setup_cursor_hover()
	_setup_completion_glow()


func _exit_tree() -> void:
	_unlock_player_actions()


func _setup_activity_board_controllers() -> void:
	_panel_flow.setup(self)
	_hud_bridge.setup(self)
	_glow_controller.setup(self)


func open_board() -> void:
	_panel_flow.open_board()


func request_interaction() -> void:
	_panel_flow.request_interaction()


func play_completion_glow() -> void:
	_glow_controller.play_completion_glow()


func _unhandled_input(event: InputEvent) -> void:
	_panel_flow.handle_unhandled_input(event)


func _get_guidance() -> Dictionary:
	return _panel_flow.get_guidance()


func _show_board_panel(title: String, lines_variant: Variant) -> void:
	_panel_flow.show_board_panel(title, lines_variant)


func _ensure_board_panel() -> void:
	_panel_flow.ensure_board_panel()


func _hide_board_panel() -> void:
	_panel_flow.hide_board_panel()


func _lock_player_actions() -> void:
	_hud_bridge.lock_player_actions()


func _unlock_player_actions() -> void:
	_hud_bridge.unlock_player_actions()


func _clear_container(container: Container) -> void:
	_panel_flow.clear_container(container)


func _has_visible_overlay_named(node_name: String) -> bool:
	return _hud_bridge.has_visible_overlay_named(node_name)


func _find_visible_overlay_named(node: Node, node_name: String) -> bool:
	return _hud_bridge.find_visible_overlay_named(node, node_name)


func _setup_cursor_hover() -> void:
	_hud_bridge.setup_cursor_hover()


func _on_cursor_mouse_entered() -> void:
	_hud_bridge.on_cursor_mouse_entered()


func _on_cursor_mouse_exited() -> void:
	_hud_bridge.on_cursor_mouse_exited()


func _setup_completion_glow() -> void:
	_glow_controller.setup_completion_glow()


func _get_board_glow_points() -> PackedVector2Array:
	return _glow_controller.get_board_glow_points()
