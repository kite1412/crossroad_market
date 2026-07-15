extends Node

signal npc_spawn_requested(npc_data)

const SPAWN_INTERVAL: float = 60.0
const DAY_ONE_NIGHT_SPAWN_INTERVAL: float = 8.0
const DAY_ONE_SLIME_FOLLOW_UP_DELAY: float = 3.0
const HUMAN_CUSTOMER_START_MINUTES: int = TimeManager.MORNING_START_MINUTES
const HUMAN_CUSTOMER_END_MINUTES: int = TimeManager.NIGHT_START_MINUTES
const DEFAULT_FIRST_DELAY_MINUTES: int = 30
const DEFAULT_END_BUFFER_MINUTES: int = 30
const DEFAULT_MIN_INTERVAL_MINUTES: int = 20
const DEFAULT_MAX_INTERVAL_MINUTES: int = 180
const DAY_ONE_CUSTOMER_COUNT: int = 4

var _npc_database: Dictionary = {}
var _day_schedule: Array = []
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = SPAWN_INTERVAL
var _is_spawning: bool = false
var _day_one_night_monster_spawned: bool = false
var _day_one_night_monster_follow_up_requested: bool = false
var _day_one_night_monster_follow_up_timer: float = 0.0
var _spawning_unlocked: bool = false
var _normal_spawning_unlocked: bool = false
var _store_open: bool = false
var _daily_customer_pool: Array[NPCData] = []
var _daily_customer_slots: Array[int] = []
var _daily_customer_index: int = 0
var _missed_daily_customers: int = 0
var _daily_customer_schedule_closed: bool = false

func _ready() -> void:
	_load_npc_data()
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.phase_changed.connect(_on_phase_changed)

func _process(delta: float) -> void:
	_process_day_one_night_monster_follow_up(delta)
	_process_daily_customer_schedule()

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
	_normal_spawning_unlocked = false
	_store_open = false
	_generate_schedule(day)
	_generate_daily_customer_schedule(day)

func _on_phase_changed(phase) -> void:
	if phase == TimeManager.Phase.MORNING:
		if TimeManager.current_day > 1 and _normal_spawning_unlocked:
			_start_spawning(NPCData.VisitPhase.MORNING)
		else:
			_stop_spawning()
	elif phase == TimeManager.Phase.DAY:
		_stop_spawning()
	elif phase == TimeManager.Phase.NIGHT:
		close_human_customer_schedule_for_day()

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
	_reset_daily_customer_schedule()
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


func set_store_open(is_open: bool) -> void:
	_store_open = is_open


func close_human_customer_schedule_for_day() -> void:
	_store_open = false
	_daily_customer_schedule_closed = true

	while _daily_customer_index < _daily_customer_pool.size():
		_miss_daily_customer()


func close_normal_customer_schedule_for_day() -> void:
	close_human_customer_schedule_for_day()


func stop_normal_customer_spawning() -> void:
	if _is_spawning and _spawn_queue.size() > 0:
		var filtered_queue: Array = []

		for npc_data in _spawn_queue:
			if not _is_normal_day_customer(npc_data):
				filtered_queue.append(npc_data)

		_spawn_queue = filtered_queue
		_is_spawning = not _spawn_queue.is_empty()


func _reset_daily_customer_schedule() -> void:
	_daily_customer_pool.clear()
	_daily_customer_slots.clear()
	_daily_customer_index = 0
	_missed_daily_customers = 0
	_daily_customer_schedule_closed = false


func _generate_schedule(day: int) -> void:
	_day_schedule.clear()

	for npc in _npc_database.values():
		if npc.visit_days.is_empty() or day in npc.visit_days:
			_day_schedule.append(npc)

	_day_schedule.sort_custom(func(a, b): return a.spawn_order < b.spawn_order)


func _generate_daily_customer_schedule(day: int) -> void:
	_reset_daily_customer_schedule()

	var blueprint := _get_daily_customer_blueprint(day)
	_daily_customer_pool = _build_daily_customer_pool(day, blueprint)
	_daily_customer_slots = _build_daily_customer_slots(blueprint, _daily_customer_pool.size())


func _get_daily_customer_blueprint(day: int) -> Dictionary:
	if day == 1:
		return {
			"customer_count": DAY_ONE_CUSTOMER_COUNT,
			"window_start": HUMAN_CUSTOMER_START_MINUTES,
			"window_end": HUMAN_CUSTOMER_END_MINUTES,
			"first_delay": DEFAULT_FIRST_DELAY_MINUTES,
			"end_buffer": DEFAULT_END_BUFFER_MINUTES,
			"min_interval": DEFAULT_MIN_INTERVAL_MINUTES,
			"max_interval": DEFAULT_MAX_INTERVAL_MINUTES,
			"customer_pool": "day_one"
		}

	var day_customer_count := 0

	for npc in _day_schedule:
		if npc.visit_phase == NPCData.VisitPhase.DAY:
			day_customer_count += 1

	return {
		"customer_count": day_customer_count,
		"window_start": HUMAN_CUSTOMER_START_MINUTES,
		"window_end": HUMAN_CUSTOMER_END_MINUTES,
		"first_delay": DEFAULT_FIRST_DELAY_MINUTES,
		"end_buffer": DEFAULT_END_BUFFER_MINUTES,
		"min_interval": DEFAULT_MIN_INTERVAL_MINUTES,
		"max_interval": DEFAULT_MAX_INTERVAL_MINUTES,
		"customer_pool": "daily_schedule"
	}


func _build_daily_customer_pool(day: int, blueprint: Dictionary) -> Array[NPCData]:
	if str(blueprint.get("customer_pool", "")) == "day_one":
		var human_customers := _get_customer_npc_data(day, "npcs/humans/", false)
		var monster_customers := _get_customer_npc_data(day, "npcs/monsters/", false)
		human_customers.shuffle()

		var day_one_pool: Array[NPCData] = []
		if human_customers.size() > 0:
			day_one_pool.append(_make_day_one_customer_from_data(human_customers[0], "water"))
		if human_customers.size() > 1:
			day_one_pool.append(_make_day_one_customer_from_data(human_customers[1], "bandage"))
		if monster_customers.size() > 0:
			day_one_pool.append(_make_day_one_customer_from_data(human_customers[2], "water"))

		var irene := _npc_database.get("irene") as NPCData
		if irene != null:
			day_one_pool.append(_make_day_one_customer_from_data(irene, "painkiller"))

		#var gooby := _npc_database.get("gooby") as NPCData
		#if gooby != null:
			#day_one_pool.append(_make_day_one_customer_from_data(gooby, "phantom_ice_cream"))

		return day_one_pool

	var pool := _get_customer_npc_data(day)
	pool.shuffle()
	return pool


func _make_day_one_customer_from_data(npc_data: NPCData, shopping_item: String) -> NPCData:
	var customer := npc_data.duplicate() as NPCData
	customer.set_meta("shopping_list", [shopping_item])
	return customer


func _get_customer_npc_data(
	day: int,
	asset_path_prefix: String = "",
	require_day_phase: bool = true
) -> Array[NPCData]:
	var pool: Array[NPCData] = []

	for npc in _npc_database.values():
		if require_day_phase and npc.visit_phase != NPCData.VisitPhase.DAY:
			continue
		if not npc.visit_days.is_empty() and day not in npc.visit_days:
			continue
		if npc.assets_path.is_empty():
			continue
		if not asset_path_prefix.is_empty() and not npc.assets_path.begins_with(asset_path_prefix):
			continue
		if asset_path_prefix.is_empty() and not (
			npc.assets_path.begins_with("npcs/")
			or npc.assets_path == "irene"
			or npc.assets_path == "gooby"
		):
			continue
		pool.append(npc)

	return pool


func _build_daily_customer_slots(blueprint: Dictionary, customer_count: int) -> Array[int]:
	var slots: Array[int] = []

	if customer_count <= 0:
		return slots

	var window_start := int(blueprint.get("window_start", HUMAN_CUSTOMER_START_MINUTES))
	var window_end := int(blueprint.get("window_end", HUMAN_CUSTOMER_END_MINUTES))
	var first_delay := int(blueprint.get("first_delay", DEFAULT_FIRST_DELAY_MINUTES))
	var end_buffer := int(blueprint.get("end_buffer", DEFAULT_END_BUFFER_MINUTES))
	var min_interval := int(blueprint.get("min_interval", DEFAULT_MIN_INTERVAL_MINUTES))
	var max_interval := int(blueprint.get("max_interval", DEFAULT_MAX_INTERVAL_MINUTES))
	var usable_window: int = max(0, window_end - window_start - first_delay - end_buffer)
	var interval := 0.0

	if customer_count > 1:
		interval = float(usable_window) / float(customer_count - 1)
		interval = clampf(interval, float(min_interval), float(max_interval))

	for i in customer_count:
		slots.append(window_start + first_delay + int(floor(interval * float(i))))

	return slots


func _process_daily_customer_schedule() -> void:
	if _daily_customer_schedule_closed:
		return

	if (
		TimeManager.current_phase != TimeManager.Phase.MORNING
		and TimeManager.current_phase != TimeManager.Phase.DAY
	):
		return

	if _daily_customer_index >= _daily_customer_pool.size():
		return

	var current_minutes := TimeManager.get_current_clock_minutes()

	while _daily_customer_index < _daily_customer_slots.size():
		var slot_minutes := _daily_customer_slots[_daily_customer_index]

		if current_minutes < slot_minutes:
			return

		if _store_open:
			_spawn_daily_customer()
		else:
			_miss_daily_customer()


func _spawn_daily_customer() -> void:
	if _daily_customer_index >= _daily_customer_pool.size():
		return

	npc_spawn_requested.emit(_daily_customer_pool[_daily_customer_index])
	_daily_customer_index += 1


func _miss_daily_customer() -> void:
	_missed_daily_customers += 1
	_daily_customer_index += 1


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
		return
	elif phase == NPCData.VisitPhase.NIGHT:
		if not _can_spawn_phase_now(phase):
			_stop_spawning()
			return

		_spawn_queue.clear()
		_spawn_interval = DAY_ONE_NIGHT_SPAWN_INTERVAL

	# Gooby is already part of the day-one daily customer pool.
	_is_spawning = false
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
	var gooby := _npc_database.get("gooby") as NPCData
	if gooby == null:
		return
	npc_spawn_requested.emit(_make_day_one_customer_from_data(gooby, "phantom_ice_cream"))

func _stop_spawning() -> void:
	_is_spawning = false
	_spawn_queue.clear()

func _spawn_next_npc() -> void:
	if _spawn_queue.is_empty():
		_is_spawning = false
		return
	var npc_data = _spawn_queue[0]

	if not _can_spawn_npc_now(npc_data.visit_phase):
		_is_spawning = false
		_spawn_queue.clear()
		return

	_spawn_queue.pop_front()
	npc_spawn_requested.emit(npc_data)


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
	return _can_spawn_phase_now(visit_phase)


func _is_normal_day_customer(npc_data: NPCData) -> bool:
	return npc_data != null and npc_data.visit_phase == NPCData.VisitPhase.DAY


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
