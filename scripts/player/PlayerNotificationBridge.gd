class_name PlayerNotificationBridge
extends RefCounted


static func show(tree: SceneTree, text: String, duration: float = 2.0) -> void:
	if tree == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = tree.get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration)


static func show_sequence(owner: Node, messages: Array[String], duration: float = 2.5) -> void:
	if owner == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = owner.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")

	for message in messages:
		show(owner.get_tree(), message, duration)

		if hud != null and hud.has_method("wait_for_notification_finished"):
			await hud.call("wait_for_notification_finished")
		else:
			await owner.get_tree().create_timer(duration + 0.15).timeout

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")


static func is_action_locked(tree: SceneTree) -> bool:
	if tree == null:
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = tree.get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))
