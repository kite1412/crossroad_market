class_name CashierHudBridge
extends RefCounted

var cashier: Cashier = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func lock_player_actions() -> void:
	# Prevent double-locking - the flag is cleared on unlock
	if cashier._cashier_lock_active:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud_node := cashier.get_tree().get_first_node_in_group("hud")

	if hud_node != null and hud_node.has_method("begin_action_lock"):
		hud_node.call("begin_action_lock")

	cashier._cashier_lock_active = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_player_actions() -> void:
	# Prevent double-unlocking - the flag is set on lock
	if not cashier._cashier_lock_active:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud_node := cashier.get_tree().get_first_node_in_group("hud")

	if hud_node != null and hud_node.has_method("end_action_lock"):
		hud_node.call("end_action_lock")

	cashier._cashier_lock_active = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_notification(text: String, duration: float = 2.0) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud_node := cashier.get_tree().get_first_node_in_group("hud")

	if hud_node != null and hud_node.has_method("show_notification"):
		hud_node.call("show_notification", text, duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_dialog_visible() -> bool:
	var hud_node := cashier.get_tree().get_first_node_in_group("hud")
	if hud_node == null:
		return false
	if hud_node.has_method("is_dialog_visible"):
		return bool(hud_node.call("is_dialog_visible"))
	var dialog := hud_node.get_node_or_null("Dialog") as CanvasItem
	return dialog != null and dialog.visible


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
	@warning_ignore("shadowed_variable")
	var hud_node := cashier.get_tree().get_first_node_in_group("hud")

	if hud_node != null and hud_node.has_method("show_cursor_tooltip"):
		hud_node.call("show_cursor_tooltip", "Cashier")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_cursor_mouse_exited() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud_node := cashier.get_tree().get_first_node_in_group("hud")

	if hud_node != null and hud_node.has_method("hide_cursor_tooltip"):
		hud_node.call("hide_cursor_tooltip")
