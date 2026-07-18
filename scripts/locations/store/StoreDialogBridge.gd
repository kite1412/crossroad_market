class_name StoreDialogBridge
extends RefCounted

const PLAYER_PORTRAIT: Texture2D = preload("res://assets/characters/player/portrait.png")


static func show_player_sequence(owner: Node, messages: Array[String]) -> void:
	if owner == null:
		return

	var hud := owner.get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("show_dialog_sequence"):
		return

	var dialogues: Array[Dictionary] = []
	for message in messages:
		dialogues.append({
			"name": "Player",
			"content": message,
			"portrait": PLAYER_PORTRAIT,
			"frame": 0
		})

	await hud.call("show_dialog_sequence", dialogues)
