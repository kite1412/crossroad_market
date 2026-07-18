class_name MysterySupplyDialogFlow
extends RefCounted

var box: MysterySupplyBox = null


func setup(box_node: MysterySupplyBox) -> void:
	box = box_node


func show_discovery_dialog() -> void:
	var hud: Node = get_hud()

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")

	await show_dialog_line("What is this...?", 2.3)
	await show_dialog_line("This box wasn’t in Grandma’s inventory list.", 2.9)
	await show_dialog_line("Why is it glowing... and why does it feel ice cold?", 3.3)

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")


func show_dialog_line(text: String, duration: float) -> void:
	var hud: Node = get_hud()

	if hud == null:
		return

	if not hud.has_method("show_notification"):
		return

	hud.call("show_notification", text, duration)

	if hud.has_method("wait_for_notification_finished"):
		await hud.call("wait_for_notification_finished")
	else:
		await box.get_tree().create_timer(duration + 0.15).timeout


func get_hud() -> Node:
	var hud: Node = box.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		return hud

	return find_node_with_method(box.get_tree().root, "show_notification")


func find_node_with_method(node: Node, method_name: String) -> Node:
	if node == null:
		return null

	if node.has_method(method_name):
		return node

	for child in node.get_children():
		var found: Node = find_node_with_method(child, method_name)

		if found != null:
			return found

	return null
