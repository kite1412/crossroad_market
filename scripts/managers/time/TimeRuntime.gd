class_name TimeRuntime
extends RefCounted

var manager: Node = null


func setup(manager_node: Node) -> void:
	manager = manager_node


func process(delta: float) -> void:
	if not manager.is_running:
		return

	manager.time_remaining -= delta
	manager.time_updated.emit(manager.time_remaining)

	if manager.time_remaining <= 0.0:
		manager._advance_phase()


func start_clock() -> void:
	if manager._day_finished:
		return

	manager.is_running = true


func pause() -> void:
	manager.is_running = false


func resume() -> void:
	start_clock()
