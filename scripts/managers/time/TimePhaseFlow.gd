class_name TimePhaseFlow
extends RefCounted

var manager: Node = null


func setup(manager_node: Node) -> void:
	manager = manager_node


func start_game() -> void:
	manager.current_day = 1
	manager.is_running = false
	manager._day_finished = false
	set_phase(TimeManager.Phase.MORNING)
	manager.day_started.emit(manager.current_day)


func start_next_day() -> void:
	if manager.current_day >= manager.TOTAL_DAYS:
		manager.is_running = false
		return

	manager.current_day += 1
	manager.is_running = false
	manager._day_finished = false
	set_phase(TimeManager.Phase.MORNING)
	manager.day_started.emit(manager.current_day)


func start_day_phase() -> void:
	manager.is_running = true
	set_phase(TimeManager.Phase.DAY)


func end_day_sequence() -> void:
	start_next_day()


func can_sleep() -> bool:
	return manager._day_finished


func sleep_until_next_day(force: bool = false) -> bool:
	if not force and not can_sleep():
		return false

	start_next_day()
	return true


func advance_phase() -> void:
	match manager.current_phase:
		TimeManager.Phase.MORNING:
			set_phase(TimeManager.Phase.DAY)
		TimeManager.Phase.DAY:
			set_phase(TimeManager.Phase.NIGHT)
		TimeManager.Phase.NIGHT:
			manager.time_remaining = 0.0
			manager.is_running = false
			manager._day_finished = true
			manager.time_updated.emit(manager.time_remaining)
			manager.day_ended.emit(manager.current_day)


func set_phase(new_phase: TimeManager.Phase) -> void:
	manager.current_phase = new_phase
	manager.time_remaining = manager.PHASE_DURATION
	manager._day_finished = false
	manager.phase_changed.emit(manager.current_phase)
	manager.time_updated.emit(manager.time_remaining)
