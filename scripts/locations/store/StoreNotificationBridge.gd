class_name StoreNotificationBridge
extends RefCounted


static func show(
	tree: SceneTree,
	text: String,
	duration: float = 2.0,
	blocks_actions: bool = true,
	instant_text: bool = false
) -> void:
	if tree == null:
		return

	var hud := tree.get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration, blocks_actions, instant_text)


static func show_sequence(owner: Node, messages: Array[String], duration: float = 2.5) -> void:
	if owner == null:
		return

	var hud := owner.get_tree().get_first_node_in_group("hud")

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
