extends Node

enum Phase { MORNING, DAY, NIGHT }

const PHASE_DURATION: float = 240.0
const TOTAL_DAYS: int = 6
const CLOCK_STEP_MINUTES: int = 10
const MORNING_START_MINUTES: int = 8 * 60
const DAY_START_MINUTES: int = 10 * 60
const NIGHT_START_MINUTES: int = 18 * 60
const END_START_MINUTES: int = 22 * 60

signal phase_changed(new_phase: Phase)
signal day_started(day: int)
signal day_ended(day: int)
signal time_updated(seconds_remaining: float)

var current_day: int = 1
var current_phase: Phase = Phase.MORNING
var time_remaining: float = PHASE_DURATION
var is_running: bool = false


func _process(delta: float) -> void:
	if not is_running:
		return

	time_remaining -= delta
	time_updated.emit(time_remaining)

	if time_remaining <= 0.0:
		_advance_phase()


func start_game() -> void:
	current_day = 1
	is_running = true
	_set_phase(Phase.MORNING)
	day_started.emit(current_day)


func start_next_day() -> void:
	if current_day >= TOTAL_DAYS:
		is_running = false
		return

	current_day += 1
	is_running = true
	_set_phase(Phase.MORNING)
	day_started.emit(current_day)


func start_day_phase() -> void:
	is_running = true
	_set_phase(Phase.DAY)


func end_day_sequence() -> void:
	start_next_day()


func pause() -> void:
	is_running = false


func resume() -> void:
	is_running = true


func get_phase_name() -> String:
	match current_phase:
		Phase.MORNING:
			return "Morning"
		Phase.DAY:
			return "Day"
		Phase.NIGHT:
			return "Night"

	return "Unknown"


func get_time_display() -> String:
	return get_clock_display()


func get_clock_display() -> String:
	var minutes: int = get_world_minutes()
	var hour: int = int(minutes / 60) % 24
	var minute: int = minutes % 60

	return "%02d:%02d" % [hour, minute]


func get_phase_time_range() -> String:
	match current_phase:
		Phase.MORNING:
			return "08:00-10:00"
		Phase.DAY:
			return "10:00-18:00"
		Phase.NIGHT:
			return "18:00-22:00"

	return ""


func get_world_minutes() -> int:
	var phase_start: int = _get_phase_start_minutes(current_phase)
	var elapsed_ratio: float = clamp((PHASE_DURATION - time_remaining) / PHASE_DURATION, 0.0, 0.999)
	var phase_minutes: int = int(floor(elapsed_ratio * float(_get_phase_world_duration_minutes(current_phase))))
	phase_minutes = int(floor(float(phase_minutes) / float(CLOCK_STEP_MINUTES))) * CLOCK_STEP_MINUTES

	return (phase_start + phase_minutes) % (24 * 60)


func get_current_clock_minutes() -> int:
	return get_world_minutes()


func _advance_phase() -> void:
	match current_phase:
		Phase.MORNING:
			_set_phase(Phase.DAY)
		Phase.DAY:
			_set_phase(Phase.NIGHT)
		Phase.NIGHT:
			is_running = false
			day_ended.emit(current_day)


func _set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	time_remaining = PHASE_DURATION
	phase_changed.emit(current_phase)
	time_updated.emit(time_remaining)


func _get_phase_start_minutes(phase: Phase) -> int:
	match phase:
		Phase.MORNING:
			return MORNING_START_MINUTES
		Phase.DAY:
			return DAY_START_MINUTES
		Phase.NIGHT:
			return NIGHT_START_MINUTES

	return MORNING_START_MINUTES


func _get_phase_world_duration_minutes(phase: Phase) -> int:
	match phase:
		Phase.MORNING:
			return DAY_START_MINUTES - MORNING_START_MINUTES
		Phase.DAY:
			return NIGHT_START_MINUTES - DAY_START_MINUTES
		Phase.NIGHT:
			return END_START_MINUTES - NIGHT_START_MINUTES

	return DAY_START_MINUTES - MORNING_START_MINUTES
