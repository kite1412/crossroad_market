class_name ActivityCompletionNotifier
extends RefCounted

var manager: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(manager_node: Node) -> void:
	manager = manager_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func notify(message: String) -> void:
	manager.activity_completion.emit(message)
