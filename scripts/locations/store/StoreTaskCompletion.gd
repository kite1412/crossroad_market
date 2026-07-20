class_name StoreTaskCompletion
extends Node

var store: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_task_complete_notice(key: String, message: String) -> void:
	if store._completed_task_notices.has(key):
		return

	store._completed_task_notices[key] = true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := store.get_tree().get_first_node_in_group("hud")
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var text := "Task Complete! %s Check the Activity Board." % message

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, 2.2, false)

	ActivityCompletionManager.notify(message)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var activity_board := store.get_node_or_null("ActivityBoard")

	if activity_board != null and activity_board.has_method("play_completion_glow"):
		activity_board.call("play_completion_glow")
