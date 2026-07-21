class_name StoreSimulationScheduler
extends RefCounted

const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")

const PRIORITY_HIGH: StringName = &"high"
const PRIORITY_NORMAL: StringName = &"normal"
const PRIORITY_LOW: StringName = &"low"
const DEFAULT_BUDGET_MSEC: float = 2.0
const SPIKE_HISTORY_LIMIT: int = 24

var budget_msec: float = DEFAULT_BUDGET_MSEC
var _high_priority_jobs: Array[Dictionary] = []
var _normal_priority_jobs: Array[Dictionary] = []
var _low_priority_jobs: Array[Dictionary] = []
var _spike_history: Array[Dictionary] = []


func enqueue(
	execute_step: Callable,
	priority: StringName = PRIORITY_NORMAL,
	label: StringName = &"job"
) -> void:
	if not execute_step.is_valid():
		return

	var job := {
		"execute_step": execute_step,
		"priority": priority,
		"label": label,
		"created_msec": Time.get_ticks_msec()
	}

	match priority:
		PRIORITY_HIGH:
			_high_priority_jobs.append(job)
		PRIORITY_LOW:
			_low_priority_jobs.append(job)
		_:
			_normal_priority_jobs.append(job)


func tick() -> void:
	var start_usec: int = Time.get_ticks_usec()

	while _has_jobs():
		if _elapsed_msec(start_usec) >= budget_msec:
			break

		var job := _pop_next_job()
		if job.is_empty():
			break

		var job_start_usec: int = Time.get_ticks_usec()
		var completed: bool = bool(job.get("execute_step", Callable()).call())
		var job_elapsed_msec: float = _elapsed_msec(job_start_usec)
		if job_elapsed_msec > budget_msec:
			_record_spike(job, job_elapsed_msec)
			StoreRuntimeDebugProbeScript.record(
				StringName(str(job.get("label", &"job"))),
				job_elapsed_msec,
				{
					"priority": StringName(str(job.get("priority", PRIORITY_NORMAL))),
					"source": &"simulation_scheduler"
				},
				budget_msec
			)

		if not completed:
			_requeue(job)


func has_pending_jobs() -> bool:
	return _has_jobs()


func get_spike_history() -> Array[Dictionary]:
	return _spike_history.duplicate(true)


func _has_jobs() -> bool:
	return (
		not _high_priority_jobs.is_empty()
		or not _normal_priority_jobs.is_empty()
		or not _low_priority_jobs.is_empty()
	)


func _pop_next_job() -> Dictionary:
	if not _high_priority_jobs.is_empty():
		return _high_priority_jobs.pop_front()
	if not _normal_priority_jobs.is_empty():
		return _normal_priority_jobs.pop_front()
	if not _low_priority_jobs.is_empty():
		return _low_priority_jobs.pop_front()
	return {}


func _requeue(job: Dictionary) -> void:
	match StringName(str(job.get("priority", PRIORITY_NORMAL))):
		PRIORITY_HIGH:
			_high_priority_jobs.append(job)
		PRIORITY_LOW:
			_low_priority_jobs.append(job)
		_:
			_normal_priority_jobs.append(job)


func _record_spike(job: Dictionary, elapsed_msec: float) -> void:
	_spike_history.append({
		"label": StringName(str(job.get("label", &"job"))),
		"elapsed_msec": elapsed_msec,
		"time_msec": Time.get_ticks_msec()
	})
	while _spike_history.size() > SPIKE_HISTORY_LIMIT:
		_spike_history.pop_front()


func _elapsed_msec(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0
