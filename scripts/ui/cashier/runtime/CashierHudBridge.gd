class_name CashierHudBridge
extends RefCounted

var cashier: Cashier = null


func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


func lock_player_actions() -> void:
	if cashier._cashier_lock_active:
		return

	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")
		cashier._cashier_lock_active = true


func unlock_player_actions() -> void:
	if not cashier._cashier_lock_active:
		return

	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")

	cashier._cashier_lock_active = false


func show_notification(text: String, duration: float = 2.0) -> void:
	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration)


func setup_cursor_hover() -> void:
	if cashier.interaction_area == null:
		return

	cashier.interaction_area.input_pickable = true
	var entered := Callable(cashier, "_on_cursor_mouse_entered")
	var exited := Callable(cashier, "_on_cursor_mouse_exited")

	if not cashier.interaction_area.mouse_entered.is_connected(entered):
		cashier.interaction_area.mouse_entered.connect(entered)

	if not cashier.interaction_area.mouse_exited.is_connected(exited):
		cashier.interaction_area.mouse_exited.connect(exited)


func on_cursor_mouse_entered() -> void:
	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", "Cashier")


func on_cursor_mouse_exited() -> void:
	var hud := cashier.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")
