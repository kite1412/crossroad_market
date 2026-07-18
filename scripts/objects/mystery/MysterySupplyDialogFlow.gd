class_name MysterySupplyDialogFlow
extends RefCounted

const PLAYER_PORTRAIT: Texture2D = preload("res://assets/characters/player/portrait.png")

var box: MysterySupplyBox = null


func setup(box_node: MysterySupplyBox) -> void:
	box = box_node


func show_discovery_dialog() -> void:
	var hud: Node = get_hud()

	if hud == null or not hud.has_method("show_dialog_sequence"):
		return

	await hud.call("show_dialog_sequence", _build_player_dialogues([
		"What is this...?",
		"This box wasn’t in Grandma’s inventory list.",
		"Why is it glowing... and why does it feel ice cold?"
	]))


func show_dialog_line(text: String, _duration: float = 0.0) -> void:
	var hud: Node = get_hud()

	if hud == null or not hud.has_method("show_dialog_sequence"):
		return

	await hud.call("show_dialog_sequence", _build_player_dialogues([text]))


func get_hud() -> Node:
	var hud: Node = box.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_dialog_sequence"):
		return hud

	return find_node_with_method(box.get_tree().root, "show_dialog_sequence")


func _build_player_dialogues(messages: Array[String]) -> Array[Dictionary]:
	var dialogues: Array[Dictionary] = []

	for message in messages:
		dialogues.append({
			"name": "Player",
			"content": message,
			"portrait": PLAYER_PORTRAIT,
			"frame": 0
		})

	return dialogues


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
