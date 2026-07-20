class_name TimeRuntime
extends RefCounted

var manager: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(manager_node: Node) -> void:
	manager = manager_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process(delta: float) -> void:
	if not manager.is_running:
		return

	manager.time_remaining -= delta
	manager.time_updated.emit(manager.time_remaining)

	if manager.time_remaining <= 0.0:
		manager._advance_phase()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_clock() -> void:
	if manager._day_finished:
		return

	manager.is_running = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func pause() -> void:
	manager.is_running = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func resume() -> void:
	start_clock()
