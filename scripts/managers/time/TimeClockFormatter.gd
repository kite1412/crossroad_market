class_name TimeClockFormatter
extends RefCounted

var manager: Node = null


func setup(manager_node: Node) -> void:
	manager = manager_node


func get_phase_name() -> String:
	match manager.current_phase:
		TimeManager.Phase.MORNING:
			return "Morning"
		TimeManager.Phase.DAY:
			return "Day"
		TimeManager.Phase.NIGHT:
			return "Night"

	return "Unknown"


func get_time_display() -> String:
	return get_clock_display()


func get_clock_display() -> String:
	var minutes: int = get_world_minutes()
	var hour: int = 24 if minutes >= manager.END_START_MINUTES else floori(minutes / 60.0) % 24
	var minute: int = minutes % 60

	return "%02d:%02d" % [hour, minute]


func get_phase_time_range() -> String:
	match manager.current_phase:
		TimeManager.Phase.MORNING:
			return "06:00-12:00"
		TimeManager.Phase.DAY:
			return "12:00-18:00"
		TimeManager.Phase.NIGHT:
			return "18:00-24:00"

	return ""


func get_world_minutes() -> int:
	if manager._day_finished:
		return manager.END_START_MINUTES

	var phase_start: int = get_phase_start_minutes(manager.current_phase)
	var elapsed_ratio: float = clamp((manager.PHASE_DURATION - manager.time_remaining) / manager.PHASE_DURATION, 0.0, 0.999)
	var phase_minutes: int = int(floor(elapsed_ratio * float(get_phase_world_duration_minutes(manager.current_phase))))
	phase_minutes = int(floor(float(phase_minutes) / float(manager.CLOCK_STEP_MINUTES))) * manager.CLOCK_STEP_MINUTES

	return phase_start + phase_minutes


func get_current_clock_minutes() -> int:
	return get_world_minutes()


func get_phase_start_minutes(phase: TimeManager.Phase) -> int:
	match phase:
		TimeManager.Phase.MORNING:
			return manager.MORNING_START_MINUTES
		TimeManager.Phase.DAY:
			return manager.DAY_START_MINUTES
		TimeManager.Phase.NIGHT:
			return manager.NIGHT_START_MINUTES

	return manager.MORNING_START_MINUTES


func get_phase_world_duration_minutes(phase: TimeManager.Phase) -> int:
	match phase:
		TimeManager.Phase.MORNING:
			return manager.DAY_START_MINUTES - manager.MORNING_START_MINUTES
		TimeManager.Phase.DAY:
			return manager.NIGHT_START_MINUTES - manager.DAY_START_MINUTES
		TimeManager.Phase.NIGHT:
			return manager.END_START_MINUTES - manager.NIGHT_START_MINUTES

	return manager.DAY_START_MINUTES - manager.MORNING_START_MINUTES
