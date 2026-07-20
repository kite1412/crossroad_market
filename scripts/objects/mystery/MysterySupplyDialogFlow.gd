class_name MysterySupplyDialogFlow
extends RefCounted

const PLAYER_PORTRAIT: Texture2D = preload("res://assets/characters/player/portrait.png")

var box: MysterySupplyBox = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(box_node: MysterySupplyBox) -> void:
	box = box_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_discovery_dialog() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = get_hud()

	if hud == null or not hud.has_method("show_dialog_sequence"):
		return

	await hud.call("show_dialog_sequence", _build_player_dialogues([
		"What is this...?",
		"This box wasn’t in Grandma’s inventory list.",
		"Why is it glowing... and why does it feel ice cold?"
	]))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_dialog_line(text: String, _duration: float = 0.0) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = get_hud()

	if hud == null or not hud.has_method("show_dialog_sequence"):
		return

	await hud.call("show_dialog_sequence", _build_player_dialogues([text]))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_hud() -> Node:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = box.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_dialog_sequence"):
		return hud

	return find_node_with_method(box.get_tree().root, "show_dialog_sequence")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _build_player_dialogues(messages: Array[String]) -> Array[Dictionary]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var dialogues: Array[Dictionary] = []

	for message in messages:
		dialogues.append({
			"name": "Player",
			"content": message,
			"portrait": PLAYER_PORTRAIT,
			"frame": 0
		})

	return dialogues


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_node_with_method(node: Node, method_name: String) -> Node:
	if node == null:
		return null

	if node.has_method(method_name):
		return node

	for child in node.get_children():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var found: Node = find_node_with_method(child, method_name)

		if found != null:
			return found

	return null
