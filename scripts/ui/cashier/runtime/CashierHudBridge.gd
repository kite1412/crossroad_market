class_name CashierHudBridge
extends RefCounted

var cashier: Cashier = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func lock_player_actions() -> void:
	if cashier._cashier_lock_active:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")
		cashier._cashier_lock_active = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_player_actions() -> void:
	if not cashier._cashier_lock_active:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")

	cashier._cashier_lock_active = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_notification(text: String, duration: float = 2.0) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup_cursor_hover() -> void:
	if cashier.interaction_area == null:
		return

	cashier.interaction_area.input_pickable = true
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var entered := Callable(cashier, "_on_cursor_mouse_entered")
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var exited := Callable(cashier, "_on_cursor_mouse_exited")

	if not cashier.interaction_area.mouse_entered.is_connected(entered):
		cashier.interaction_area.mouse_entered.connect(entered)

	if not cashier.interaction_area.mouse_exited.is_connected(exited):
		cashier.interaction_area.mouse_exited.connect(exited)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_cursor_mouse_entered() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", "Cashier")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_cursor_mouse_exited() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")
