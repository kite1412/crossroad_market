extends Node


enum Phase { MORNING, DAY, NIGHT }

const PHASE_DURATION: float = 240.0
const TOTAL_DAYS: int = 6
const CLOCK_STEP_MINUTES: int = 10
const MORNING_START_MINUTES: int = 6 * 60
const DAY_START_MINUTES: int = 12 * 60
const NIGHT_START_MINUTES: int = 18 * 60
const END_START_MINUTES: int = 24 * 60

@warning_ignore("unused_signal")
signal phase_changed(new_phase: Phase)
@warning_ignore("unused_signal")
signal day_started(day: int)
@warning_ignore("unused_signal")
signal day_ended(day: int)
@warning_ignore("unused_signal")
signal time_updated(seconds_remaining: float)

var current_day: int = 1
var current_phase: Phase = Phase.MORNING
var time_remaining: float = PHASE_DURATION
var is_running: bool = false
@warning_ignore("unused_private_class_variable")
var _day_finished: bool = false

@warning_ignore("unused_private_class_variable")
var _runtime: TimeRuntime = TimeRuntime.new()
@warning_ignore("unused_private_class_variable")
var _phase_flow: TimePhaseFlow = TimePhaseFlow.new()
@warning_ignore("unused_private_class_variable")
var _clock_formatter: TimeClockFormatter = TimeClockFormatter.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_setup_time_controllers()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_time_controllers() -> void:
	_runtime.setup(self)
	_phase_flow.setup(self)
	_clock_formatter.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process(delta: float) -> void:
	_runtime.process(delta)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_game() -> void:
	_phase_flow.start_game()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_next_day() -> void:
	_phase_flow.start_next_day()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_day_phase() -> void:
	_phase_flow.start_day_phase()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func transition_to_night() -> void:
	_phase_flow.set_phase(Phase.NIGHT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_clock() -> void:
	_runtime.start_clock()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func end_day_sequence() -> void:
	_phase_flow.end_day_sequence()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func pause() -> void:
	_runtime.pause()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func resume() -> void:
	_runtime.resume()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func can_sleep() -> bool:
	return _phase_flow.can_sleep()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func sleep_until_next_day(force: bool = false) -> bool:
	return _phase_flow.sleep_until_next_day(force)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_phase_name() -> String:
	return _clock_formatter.get_phase_name()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_time_display() -> String:
	return _clock_formatter.get_time_display()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_clock_display() -> String:
	return _clock_formatter.get_clock_display()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_phase_time_range() -> String:
	return _clock_formatter.get_phase_time_range()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_world_minutes() -> int:
	return _clock_formatter.get_world_minutes()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_current_clock_minutes() -> int:
	return _clock_formatter.get_current_clock_minutes()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_precise_clock_minutes() -> float:
	return _clock_formatter.get_precise_world_minutes()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_phase_world_duration_minutes(phase: Phase) -> int:
	return _clock_formatter.get_phase_world_duration_minutes(phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _advance_phase() -> void:
	_phase_flow.advance_phase()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_phase(new_phase: Phase) -> void:
	_phase_flow.set_phase(new_phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_phase_start_minutes(phase: Phase) -> int:
	return _clock_formatter.get_phase_start_minutes(phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_phase_world_duration_minutes(phase: Phase) -> int:
	return _clock_formatter.get_phase_world_duration_minutes(phase)
