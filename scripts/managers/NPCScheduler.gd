extends Node

signal npc_spawn_requested(npc_data)

const SPAWN_INTERVAL: float = 60.0
const DAY_ONE_NIGHT_SPAWN_INTERVAL: float = 8.0
const DAY_ONE_DAY_SPAWN_END_BUFFER: float = 8.0
const DAY_ONE_MIN_SPAWN_INTERVAL: float = 8.0
const DAY_ONE_RUSH_SPAWN_INTERVAL: float = 0.5
const DAY_ONE_SLIME_FOLLOW_UP_DELAY: float = 3.0
const DEFAULT_DYNAMIC_CLOSE_MINUTES: int = 18 * 60

var _npc_database: Dictionary = {}
var _day_schedule: Array = []
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = SPAWN_INTERVAL
var _is_spawning: bool = false
var _day_one_night_monster_spawned: bool = false
var _day_one_night_monster_follow_up_requested: bool = false
var _day_one_night_monster_follow_up_timer: float = 0.0
var _day_one_day_spawning_started: bool = false
var _spawning_unlocked: bool = false
var _normal_spawning_unlocked: bool = false
var _store_open: bool = false
var _dynamic_customer_target: int = 0
var _dynamic_spawned_customers: int = 0
var _dynamic_interval_minutes: float = 0.0
var _dynamic_close_minutes: int = DEFAULT_DYNAMIC_CLOSE_MINUTES
var _next_customer_spawn_minutes: float = 0.0

func _ready() -> void:
	_load_npc_data()
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.phase_changed.connect(_on_phase_changed)

func _process(delta: float) -> void:
	_process_day_one_night_monster_follow_up(delta)

	if not _is_spawning or _spawn_queue.is_empty():
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_next_npc()
		_spawn_timer = _spawn_interval

func _load_npc_database() -> void:
	var _load_dir := func(dir_path: String) -> void:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			return
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var npc = load(dir_path + file_name)
				if npc != null and npc.npc_id != "":
					_npc_database[npc.npc_id] = npc
			file_name = dir.get_next()
	_load_dir.call("res://data/npc/story/")
	_load_dir.call("res://data/npc/generic/")

func _load_npc_data() -> void:
	_npc_database.clear()
	_load_npc_database()

func _on_day_started(day: int) -> void:
	_day_one_night_monster_spawned = false
	_day_one_night_monster_follow_up_requested = false
	_day_one_night_monster_follow_up_timer = 0.0
	_day_one_day_spawning_started = false
	_normal_spawning_unlocked = false
	_store_open = false
	_reset_dynamic_day_pacing()
	_generate_schedule(day)

func _on_phase_changed(phase) -> void:
	if phase == TimeManager.Phase.MORNING:
		if TimeManager.current_day == 1 and _normal_spawning_unlocked:
			_start_day_one_spawning(NPCData.VisitPhase.DAY)
		elif TimeManager.current_day > 1 and _normal_spawning_unlocked:
			_start_spawning(NPCData.VisitPhase.MORNING)
		else:
			_stop_spawning()
	elif phase == TimeManager.Phase.DAY:
		if TimeManager.current_day == 1 and _normal_spawning_unlocked:
			_start_day_one_spawning(NPCData.VisitPhase.DAY)
		elif _normal_spawning_unlocked:
			_start_spawning(NPCData.VisitPhase.DAY)
		else:
			_stop_spawning()
	elif phase == TimeManager.Phase.NIGHT:
		if not _spawning_unlocked:
			_stop_spawning()
			return

		if TimeManager.current_day == 1:
			_start_day_one_spawning(NPCData.VisitPhase.NIGHT)
		else:
			_start_spawning(NPCData.VisitPhase.NIGHT)


func lock_spawning_until_ready() -> void:
	_spawning_unlocked = false
	_normal_spawning_unlocked = false
	_store_open = false
	_reset_dynamic_day_pacing()
	_stop_spawning()


func unlock_spawning_now(start_day_one_customers_now: bool = false) -> void:
	var was_unlocked := _spawning_unlocked
	if not _spawning_unlocked:
		_spawning_unlocked = true

	if was_unlocked and not start_day_one_customers_now:
		return

	if start_day_one_customers_now:
		_start_day_one_spawning(NPCData.VisitPhase.DAY)
	else:
		_on_phase_changed(TimeManager.current_phase)


func unlock_normal_day_spawning_now() -> void:
	_normal_spawning_unlocked = true
	_start_day_one_spawning(NPCData.VisitPhase.DAY)


func set_store_open(is_open: bool) -> void:
	_store_open = is_open

	if not _store_open:
		stop_normal_customer_spawning()


func configure_dynamic_day_pacing(customer_target: int, interval_minutes: float, close_minutes: int) -> void:
	_dynamic_customer_target = max(0, customer_target)
	_dynamic_spawned_customers = 0
	_dynamic_interval_minutes = max(0.0, interval_minutes)
	_dynamic_close_minutes = close_minutes
	_next_customer_spawn_minutes = float(TimeManager.get_current_clock_minutes())
	_store_open = _dynamic_customer_target > 0
	_day_one_day_spawning_started = false


func stop_normal_customer_spawning() -> void:
	_store_open = false

	if _is_spawning and _spawn_queue.size() > 0:
		var filtered_queue: Array = []

		for npc_data in _spawn_queue:
			if not _is_normal_day_customer(npc_data):
				filtered_queue.append(npc_data)

		_spawn_queue = filtered_queue
		_is_spawning = not _spawn_queue.is_empty()


func _reset_dynamic_day_pacing() -> void:
	_dynamic_customer_target = 0
	_dynamic_spawned_customers = 0
	_dynamic_interval_minutes = 0.0
	_dynamic_close_minutes = DEFAULT_DYNAMIC_CLOSE_MINUTES
	_next_customer_spawn_minutes = 0.0


func _generate_schedule(day: int) -> void:
	_day_schedule.clear()

	for npc in _npc_database.values():
		if npc.visit_days.is_empty() or day in npc.visit_days:
			_day_schedule.append(npc)

	_day_schedule.sort_custom(func(a, b): return a.spawn_order < b.spawn_order)

func _start_spawning(phase) -> void:
	if not _can_spawn_phase_now(phase):
		_stop_spawning()
		return

	_spawn_queue.clear()
	for npc in _day_schedule:
		if npc.visit_phase == phase:
			_spawn_queue.append(npc)
	_is_spawning = true
	_spawn_interval = SPAWN_INTERVAL
	_spawn_timer = 5.0

func _start_day_one_spawning(phase) -> void:
	if phase == NPCData.VisitPhase.DAY:
		if _day_one_day_spawning_started:
			return

		if not _can_spawn_day_one_day_customers_now():
			_stop_spawning()
			return

		_spawn_queue.clear()
		_day_one_day_spawning_started = true
		var day_customers: Array[NPCData] = [
			_make_day_one_customer("day1_bread_customer", "Customer", ["bread"], 10, phase),
			_make_day_one_customer("day1_water_customer", "Customer", ["water"], 5, phase),
			_make_day_one_customer("day1_bandage_customer", "Customer", ["bandage"], 15, phase),
			_make_day_one_customer("irene", "Irene", ["painkiller"], 10, phase, NPCData.NPCCategory.STORY),
			_make_day_one_customer("day1_bread_customer_2", "Customer", ["bread"], 10, phase),
			_make_day_one_customer("day1_water_customer_2", "Customer", ["water"], 5, phase)
		]
		var customer_limit := mini(_dynamic_customer_target, day_customers.size())

		for i in customer_limit:
			_spawn_queue.append(day_customers[i])

		_spawn_interval = maxf(0.1, _get_real_seconds_for_world_minutes(_dynamic_interval_minutes))
	elif phase == NPCData.VisitPhase.NIGHT:
		if not _can_spawn_phase_now(phase):
			_stop_spawning()
			return

		_spawn_queue.clear()
		_spawn_interval = DAY_ONE_NIGHT_SPAWN_INTERVAL
		_spawn_queue.append(_make_day_one_customer("gooby", "Gooby The Phantom", ["phantom_ice_cream"], 10, phase, NPCData.NPCCategory.STORY, "reject_return"))

	_is_spawning = not _spawn_queue.is_empty()
	_spawn_timer = minf(2.0, _spawn_interval) if phase == NPCData.VisitPhase.NIGHT else _spawn_interval

func spawn_day_one_night_monster_customer() -> void:
	if _day_one_night_monster_spawned or _day_one_night_monster_follow_up_requested:
		return

	if TimeManager.current_day != 1 or TimeManager.current_phase != TimeManager.Phase.NIGHT:
		return

	_day_one_night_monster_follow_up_requested = true
	_day_one_night_monster_follow_up_timer = DAY_ONE_SLIME_FOLLOW_UP_DELAY

func _process_day_one_night_monster_follow_up(delta: float) -> void:
	if not _day_one_night_monster_follow_up_requested:
		return

	if TimeManager.current_day != 1 or TimeManager.current_phase != TimeManager.Phase.NIGHT:
		_day_one_night_monster_follow_up_requested = false
		_day_one_night_monster_follow_up_timer = 0.0
		return

	_day_one_night_monster_follow_up_timer -= delta

	if _day_one_night_monster_follow_up_timer > 0.0:
		return

	_day_one_night_monster_follow_up_requested = false
	_day_one_night_monster_spawned = true
	npc_spawn_requested.emit(_make_day_one_customer(
		"day1_slime",
		"Slime Customer",
		["phantom_ice_cream"],
		10,
		NPCData.VisitPhase.NIGHT,
		NPCData.NPCCategory.GENERIC,
		"paid",
		NPCData.PatienceType.IMPATIENT
	))

func _stop_spawning() -> void:
	_is_spawning = false
	_spawn_queue.clear()

func _spawn_next_npc() -> void:
	if _spawn_queue.is_empty():
		_is_spawning = false
		return
	var npc_data = _spawn_queue[0]

	if not _can_spawn_npc_now(npc_data.visit_phase):
		if _should_wait_for_normal_customer_window(npc_data):
			return

		_is_spawning = false
		_spawn_queue.clear()
		return

	_spawn_queue.pop_front()
	npc_spawn_requested.emit(npc_data)

	if _is_normal_day_customer(npc_data):
		_on_normal_customer_spawned()


func _can_spawn_phase_now(visit_phase: NPCData.VisitPhase) -> bool:
	match visit_phase:
		NPCData.VisitPhase.MORNING:
			return TimeManager.current_phase == TimeManager.Phase.MORNING
		NPCData.VisitPhase.DAY:
			return TimeManager.current_phase == TimeManager.Phase.DAY
		NPCData.VisitPhase.NIGHT:
			return TimeManager.current_phase == TimeManager.Phase.NIGHT

	return false

func _can_spawn_npc_now(visit_phase: NPCData.VisitPhase) -> bool:
	if (
		TimeManager.current_day == 1
		and visit_phase == NPCData.VisitPhase.DAY
		and _day_one_day_spawning_started
	):
		return _can_spawn_day_one_day_customers_now()

	return _can_spawn_phase_now(visit_phase)

func _can_spawn_day_one_day_customers_now() -> bool:
	return (
		TimeManager.current_day == 1
		and TimeManager.current_phase != TimeManager.Phase.NIGHT
		and _can_spawn_normal_customer()
	)

func _can_spawn_normal_customer() -> bool:
	if not _store_open:
		return false

	if TimeManager.get_current_clock_minutes() >= _dynamic_close_minutes:
		return false

	if _dynamic_spawned_customers >= _dynamic_customer_target:
		return false

	if float(TimeManager.get_current_clock_minutes()) < _next_customer_spawn_minutes:
		return false

	return true

func _on_normal_customer_spawned() -> void:
	_dynamic_spawned_customers += 1

	if _dynamic_spawned_customers >= _dynamic_customer_target:
		return

	var variation := randf_range(0.85, 1.15)
	var next_interval := _dynamic_interval_minutes * variation
	_next_customer_spawn_minutes = minf(
		float(_dynamic_close_minutes),
		float(TimeManager.get_current_clock_minutes()) + next_interval
	)


func _is_normal_day_customer(npc_data: NPCData) -> bool:
	return npc_data != null and npc_data.visit_phase == NPCData.VisitPhase.DAY


func _should_wait_for_normal_customer_window(npc_data: NPCData) -> bool:
	return (
		_is_normal_day_customer(npc_data)
		and _store_open
		and TimeManager.get_current_clock_minutes() < _dynamic_close_minutes
		and _dynamic_spawned_customers < _dynamic_customer_target
	)

func _configure_day_one_day_pacing() -> void:
	var customer_count := _spawn_queue.size()
	if customer_count <= 0:
		_spawn_interval = SPAWN_INTERVAL
		return

	var remaining_day_seconds := _get_real_seconds_until_night()
	var pacing_window_seconds: float = maxf(
		remaining_day_seconds - DAY_ONE_DAY_SPAWN_END_BUFFER,
		0.0
	)
	var raw_interval: float = pacing_window_seconds / float(customer_count)

	if raw_interval >= DAY_ONE_MIN_SPAWN_INTERVAL:
		_spawn_interval = raw_interval
	else:
		_spawn_interval = maxf(DAY_ONE_RUSH_SPAWN_INTERVAL, raw_interval)

func _get_real_seconds_until_night() -> float:
	match TimeManager.current_phase:
		TimeManager.Phase.MORNING:
			return TimeManager.time_remaining + TimeManager.PHASE_DURATION
		TimeManager.Phase.DAY:
			return TimeManager.time_remaining
		TimeManager.Phase.NIGHT:
			return 0.0

	return 0.0

func _get_real_seconds_for_world_minutes(world_minutes: float) -> float:
	var day_world_minutes := float(TimeManager.NIGHT_START_MINUTES - TimeManager.DAY_START_MINUTES)

	if day_world_minutes <= 0.0:
		return world_minutes

	return maxf(0.1, world_minutes * (TimeManager.PHASE_DURATION / day_world_minutes))

func _make_day_one_customer(
	npc_id: String,
	display_name: String,
	shopping_items: Array[String],
	checkout_total: int,
	visit_phase: NPCData.VisitPhase,
	category: NPCData.NPCCategory = NPCData.NPCCategory.GENERIC,
	checkout_outcome: String = "paid",
	patience_type: NPCData.PatienceType = NPCData.PatienceType.PATIENT
) -> NPCData:
	var data := NPCData.new()
	data.npc_id = npc_id
	data.display_name = display_name
	data.npc_category = category
	data.visit_days = [1]
	data.visit_phase = visit_phase
	data.patience_type = patience_type
	data.favorite_items = shopping_items.duplicate()
	data.set_meta("shopping_list", shopping_items.duplicate())
	data.set_meta("checkout_total", checkout_total)
	data.set_meta("checkout_outcome", checkout_outcome)
	return data
