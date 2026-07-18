extends Node

const TimeRuntime = preload("res://scripts/managers/time/TimeRuntime.gd")
const TimePhaseFlow = preload("res://scripts/managers/time/TimePhaseFlow.gd")
const TimeClockFormatter = preload("res://scripts/managers/time/TimeClockFormatter.gd")

enum Phase { MORNING, DAY, NIGHT }

const PHASE_DURATION: float = 240.0
const TOTAL_DAYS: int = 6
const CLOCK_STEP_MINUTES: int = 10
const MORNING_START_MINUTES: int = 6 * 60
const DAY_START_MINUTES: int = 12 * 60
const NIGHT_START_MINUTES: int = 18 * 60
const END_START_MINUTES: int = 24 * 60

signal phase_changed(new_phase: Phase)
signal day_started(day: int)
signal day_ended(day: int)
signal time_updated(seconds_remaining: float)

var current_day: int = 1
var current_phase: Phase = Phase.MORNING
var time_remaining: float = PHASE_DURATION
var is_running: bool = false
var _day_finished: bool = false

var _runtime: TimeRuntime = TimeRuntime.new()
var _phase_flow: TimePhaseFlow = TimePhaseFlow.new()
var _clock_formatter: TimeClockFormatter = TimeClockFormatter.new()


func _ready() -> void:
	_setup_time_controllers()


func _setup_time_controllers() -> void:
	_runtime.setup(self)
	_phase_flow.setup(self)
	_clock_formatter.setup(self)


func _process(delta: float) -> void:
	_runtime.process(delta)


func start_game() -> void:
	_phase_flow.start_game()


func start_next_day() -> void:
	_phase_flow.start_next_day()


func start_day_phase() -> void:
	_phase_flow.start_day_phase()


func start_clock() -> void:
	_runtime.start_clock()


func end_day_sequence() -> void:
	_phase_flow.end_day_sequence()


func pause() -> void:
	_runtime.pause()


func resume() -> void:
	_runtime.resume()


func can_sleep() -> bool:
	return _phase_flow.can_sleep()


func sleep_until_next_day(force: bool = false) -> bool:
	return _phase_flow.sleep_until_next_day(force)


func get_phase_name() -> String:
	return _clock_formatter.get_phase_name()


func get_time_display() -> String:
	return _clock_formatter.get_time_display()


func get_clock_display() -> String:
	return _clock_formatter.get_clock_display()


func get_phase_time_range() -> String:
	return _clock_formatter.get_phase_time_range()


func get_world_minutes() -> int:
	return _clock_formatter.get_world_minutes()


func get_current_clock_minutes() -> int:
	return _clock_formatter.get_current_clock_minutes()


func _advance_phase() -> void:
	_phase_flow.advance_phase()


func _set_phase(new_phase: Phase) -> void:
	_phase_flow.set_phase(new_phase)


func _get_phase_start_minutes(phase: Phase) -> int:
	return _clock_formatter.get_phase_start_minutes(phase)


func _get_phase_world_duration_minutes(phase: Phase) -> int:
	return _clock_formatter.get_phase_world_duration_minutes(phase)
