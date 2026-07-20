class_name ActivityBoard
extends StaticBody2D


const DEFAULT_TITLE: String = "Today's Work"
const DEFAULT_LINES: Array[String] = [
	"Check storage for shelves and stock.",
	"Stock shelves, then serve customers."
]
const PANEL_SIZE := Vector2(292, 164)
const BOARD_GLOW_CYCLES: int = 3
const BOARD_GLOW_CYCLE_DURATION: float = 0.45

@warning_ignore("unused_private_class_variable")
var _board_layer: CanvasLayer = null
@warning_ignore("unused_private_class_variable")
var _board_panel: ColorRect = null
@warning_ignore("unused_private_class_variable")
var _glow_line: Line2D = null
@warning_ignore("unused_private_class_variable")
var _glow_tween: Tween = null
@warning_ignore("unused_private_class_variable")
var _board_lock_active: bool = false

@warning_ignore("unused_private_class_variable")
var _panel_flow: ActivityBoardPanelFlow = ActivityBoardPanelFlow.new()
@warning_ignore("unused_private_class_variable")
var _hud_bridge: ActivityBoardHudBridge = ActivityBoardHudBridge.new()
@warning_ignore("unused_private_class_variable")
var _glow_controller: ActivityBoardGlowController = ActivityBoardGlowController.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_setup_activity_board_controllers()
	_setup_cursor_hover()
	_setup_completion_glow()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _exit_tree() -> void:
	_unlock_player_actions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_activity_board_controllers() -> void:
	_panel_flow.setup(self)
	_hud_bridge.setup(self)
	_glow_controller.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func open_board() -> void:
	_panel_flow.open_board()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_interaction() -> void:
	_panel_flow.request_interaction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func play_completion_glow() -> void:
	_glow_controller.play_completion_glow()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _unhandled_input(event: InputEvent) -> void:
	_panel_flow.handle_unhandled_input(event)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_guidance() -> Dictionary:
	return _panel_flow.get_guidance()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_board_panel(title: String, lines_variant: Variant) -> void:
	_panel_flow.show_board_panel(title, lines_variant)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ensure_board_panel() -> void:
	_panel_flow.ensure_board_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _hide_board_panel() -> void:
	_panel_flow.hide_board_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _lock_player_actions() -> void:
	_hud_bridge.lock_player_actions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _unlock_player_actions() -> void:
	_hud_bridge.unlock_player_actions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _clear_container(container: Container) -> void:
	_panel_flow.clear_container(container)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_visible_overlay_named(node_name: String) -> bool:
	return _hud_bridge.has_visible_overlay_named(node_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_visible_overlay_named(node: Node, node_name: String) -> bool:
	return _hud_bridge.find_visible_overlay_named(node, node_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_cursor_hover() -> void:
	_hud_bridge.setup_cursor_hover()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_mouse_entered() -> void:
	_hud_bridge.on_cursor_mouse_entered()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_mouse_exited() -> void:
	_hud_bridge.on_cursor_mouse_exited()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_completion_glow() -> void:
	_glow_controller.setup_completion_glow()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_board_glow_points() -> PackedVector2Array:
	return _glow_controller.get_board_glow_points()
