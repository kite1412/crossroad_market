class_name ActivityCompletionNotifier
extends RefCounted

var manager: Node = null


func setup(manager_node: Node) -> void:
	manager = manager_node


func notify(message: String) -> void:
	manager.activity_completion.emit(message)
