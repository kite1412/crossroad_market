extends Node

signal npc_spawn_requested(npc_data)

const SPAWN_INTERVAL: float = 60.0
const DAY_ONE_NIGHT_SPAWN_INTERVAL: float = 8.0
const DAY_ONE_SLIME_FOLLOW_UP_DELAY: float = 3.0
const HUMAN_CUSTOMER_START_MINUTES: int = TimeManager.MORNING_START_MINUTES
const HUMAN_CUSTOMER_END_MINUTES: int = TimeManager.NIGHT_START_MINUTES
const NIGHT_CUSTOMER_START_MINUTES: int = TimeManager.NIGHT_START_MINUTES
const NIGHT_CUSTOMER_END_MINUTES: int = TimeManager.END_START_MINUTES
const DEFAULT_FIRST_DELAY_MINUTES: int = 30
const DEFAULT_END_BUFFER_MINUTES: int = 30
const DEFAULT_MIN_INTERVAL_MINUTES: int = 20
const DEFAULT_MAX_INTERVAL_MINUTES: int = 180
const SESSION_NONE: StringName = &"none"
const SESSION_HUMAN: StringName = &"human"
const SESSION_NIGHT: StringName = &"night"
const DAY_ONE_CUSTOMER_COUNT: int = 4
const DAY_ONE_BREAD_CUSTOMER_GOLD: int = 10
const DAY_ONE_WATER_CUSTOMER_GOLD: int = 5
const DAY_ONE_BANDAGE_CUSTOMER_GOLD: int = 15
const DAY_ONE_IRENE_CUSTOMER_GOLD: int = 10
const NIGHT_STOCK_ITEM_IDS: Array[String] = [
	"phantom_ice_cream",
	"fresh_tombstone",
	"mandrake_root",
	"dewdrop_honey",
	"potion_bottle_empty"
]

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
var _customer_sessions: Dictionary = {}
var _active_customer_session: StringName = SESSION_NONE

func _ready() -> void:
	_load_npc_data()
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.phase_changed.connect(_on_phase_changed)

func _process(delta: float) -> void:
	_process_day_one_night_monster_follow_up(delta)
	_process_active_customer_session()

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
	_generate_customer_sessions_for_day(day)
	_start_customer_session(SESSION_HUMAN)

func _on_phase_changed(phase) -> void:
	if phase == TimeManager.Phase.MORNING:
		if TimeManager.current_day > 1 and _normal_spawning_unlocked:
			_start_spawning(NPCData.VisitPhase.MORNING)
		else:
			_stop_spawning()
	elif phase == TimeManager.Phase.DAY:
		_stop_spawning()
	elif phase == TimeManager.Phase.NIGHT:
		start_night_customer_session()

		if not _spawning_unlocked:
			_stop_spawning()
			return

		_stop_spawning()


func lock_spawning_until_ready() -> void:
	_spawning_unlocked = false
	_normal_spawning_unlocked = false
	_store_open = false
	_reset_customer_sessions()
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


func start_night_customer_session() -> void:
	if _active_customer_session == SESSION_NIGHT:
		return

	_finish_active_customer_session()
	_start_customer_session(SESSION_NIGHT)


func stop_normal_customer_spawning() -> void:
	if _is_spawning and _spawn_queue.size() > 0:
		var filtered_queue: Array = []

		for npc_data in _spawn_queue:
			if not _is_normal_day_customer(npc_data):
				filtered_queue.append(npc_data)

		_spawn_queue = filtered_queue
		_is_spawning = not _spawn_queue.is_empty()


func _reset_customer_sessions() -> void:
	_customer_sessions.clear()
	_active_customer_session = SESSION_NONE


func _generate_schedule(day: int) -> void:
	_day_schedule.clear()

	for npc in _npc_database.values():
		if npc.visit_days.is_empty() or day in npc.visit_days:
			_day_schedule.append(npc)

	_day_schedule.sort_custom(func(a, b): return a.spawn_order < b.spawn_order)


func _generate_customer_sessions_for_day(day: int) -> void:
	_reset_customer_sessions()

	var human_blueprint := _get_customer_session_blueprint(day, SESSION_HUMAN)
	var human_pool := _build_customer_session_pool(day, human_blueprint)
	_customer_sessions[SESSION_HUMAN] = _make_customer_session(human_blueprint, human_pool)

	var night_blueprint := _get_customer_session_blueprint(day, SESSION_NIGHT)
	var night_pool := _build_customer_session_pool(day, night_blueprint)
	_customer_sessions[SESSION_NIGHT] = _make_customer_session(night_blueprint, night_pool)


func _get_customer_session_blueprint(day: int, session_name: StringName) -> Dictionary:
	if session_name == SESSION_HUMAN and day == 1:
		return {
			"customer_count": DAY_ONE_CUSTOMER_COUNT,
			"window_start": HUMAN_CUSTOMER_START_MINUTES,
			"window_end": HUMAN_CUSTOMER_END_MINUTES,
			"min_interval": DEFAULT_MIN_INTERVAL_MINUTES,
			"max_interval": DEFAULT_MAX_INTERVAL_MINUTES,
			"customer_pool": "day_one_human"
		}

	var customer_count := 0
	var visit_phase := NPCData.VisitPhase.DAY if session_name == SESSION_HUMAN else NPCData.VisitPhase.NIGHT

	for npc in _day_schedule:
		if npc.visit_phase == visit_phase and not _is_day_one_follow_up_story_npc(day, npc):
			customer_count += 1

	if session_name == SESSION_NIGHT and day == 1 and _npc_database.has("gooby"):
		customer_count += 1

	return {
		"customer_count": customer_count,
		"window_start": HUMAN_CUSTOMER_START_MINUTES if session_name == SESSION_HUMAN else NIGHT_CUSTOMER_START_MINUTES,
		"window_end": HUMAN_CUSTOMER_END_MINUTES if session_name == SESSION_HUMAN else NIGHT_CUSTOMER_END_MINUTES,
		"min_interval": DEFAULT_MIN_INTERVAL_MINUTES,
		"max_interval": DEFAULT_MAX_INTERVAL_MINUTES,
		"customer_pool": String(session_name)
	}


func _build_customer_session_pool(day: int, blueprint: Dictionary) -> Array[NPCData]:
	var pool_name := str(blueprint.get("customer_pool", ""))

	if pool_name == "day_one_human":
		return [
			_make_day_one_customer("day1_bread_customer", "Customer", ["bread"], DAY_ONE_BREAD_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.GENERIC, "paid", NPCData.PatienceType.PATIENT, "npcs/humans/human1"),
			_make_day_one_customer("day1_water_customer", "Customer", ["water"], DAY_ONE_WATER_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.GENERIC, "paid", NPCData.PatienceType.PATIENT, "npcs/humans/human2"),
			_make_day_one_customer("day1_bandage_customer", "Customer", ["bandage"], DAY_ONE_BANDAGE_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.GENERIC, "paid", NPCData.PatienceType.PATIENT, "npcs/humans/human3"),
			_make_day_one_customer("irene", "Irene", ["painkiller"], DAY_ONE_IRENE_CUSTOMER_GOLD, NPCData.VisitPhase.DAY, NPCData.NPCCategory.STORY, "paid", NPCData.PatienceType.PATIENT, "irene")
		]

	var visit_phase := NPCData.VisitPhase.NIGHT if pool_name == String(SESSION_NIGHT) else NPCData.VisitPhase.DAY
	var pool := _get_customer_npc_data(day, "", visit_phase)
	if visit_phase == NPCData.VisitPhase.NIGHT:
		pool = _align_night_customer_items(pool)
	pool.shuffle()

	if visit_phase == NPCData.VisitPhase.NIGHT and day == 1:
		var gooby := _npc_database.get("gooby") as NPCData

		if gooby != null:
			pool.push_front(_make_day_one_customer_from_data(gooby, "phantom_ice_cream"))

	return pool


func _align_night_customer_items(pool: Array[NPCData]) -> Array[NPCData]:
	var aligned_pool: Array[NPCData] = []

	for npc in pool:
		if not _is_ghost_or_monster_customer(npc):
			aligned_pool.append(npc)
			continue

		var aligned_npc := npc.duplicate() as NPCData
		aligned_npc.favorite_items = NIGHT_STOCK_ITEM_IDS.duplicate()
		aligned_npc.favorite_items.shuffle()
		aligned_pool.append(aligned_npc)

	return aligned_pool


func _is_ghost_or_monster_customer(npc: NPCData) -> bool:
	if npc == null or npc.assets_path.is_empty():
		return false

	return (
		npc.assets_path.begins_with("npcs/ghosts/")
		or npc.assets_path.begins_with("npcs/monsters/")
	)


func _make_day_one_customer_from_data(npc_data: NPCData, shopping_item: String) -> NPCData:
	var customer := npc_data.duplicate() as NPCData
	customer.set_meta("shopping_list", [shopping_item])
	# Gooby cannot pay for the phantom ice cream. This drives the existing
	# cashier gift/refuse decision instead of treating the checkout as paid.
	customer.set_meta("checkout_total", 0)
	customer.set_meta("checkout_outcome", "reject_return")
	return customer


func _get_customer_npc_data(
	day: int,
	asset_path_prefix: String = "",
	visit_phase: NPCData.VisitPhase = NPCData.VisitPhase.DAY
) -> Array[NPCData]:
	var pool: Array[NPCData] = []

	for npc in _npc_database.values():
		if npc.visit_phase != visit_phase:
			continue
		if _is_day_one_follow_up_story_npc(day, npc):
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


func _make_customer_session(blueprint: Dictionary, pool: Array[NPCData]) -> Dictionary:
	return {
		"pool": pool,
		"slots": _build_customer_session_slots(blueprint, pool.size()),
		"index": 0,
		"missed": 0,
		"closed": false
	}


func _build_customer_session_slots(blueprint: Dictionary, customer_count: int) -> Array[int]:
	var slots: Array[int] = []

	if customer_count <= 0:
		return slots

	var window_start := int(blueprint.get("window_start", HUMAN_CUSTOMER_START_MINUTES))
	var window_end := int(blueprint.get("window_end", HUMAN_CUSTOMER_END_MINUTES))
	var average_interval := float(max(0, window_end - window_start)) / float(customer_count)

	for i in customer_count:
		slots.append(window_start + int(round(average_interval * (float(i) + 0.5))))

	return slots


func _process_active_customer_session() -> void:
	if _active_customer_session == SESSION_NONE or not _customer_sessions.has(_active_customer_session):
		return

	var session := _customer_sessions[_active_customer_session] as Dictionary

	if bool(session.get("closed", false)):
		return

	var pool := session.get("pool", []) as Array[NPCData]
	var slots := session.get("slots", []) as Array[int]
	var index := int(session.get("index", 0))

	if index >= pool.size():
		return

	var current_minutes := TimeManager.get_current_clock_minutes()

	if current_minutes >= TimeManager.END_START_MINUTES:
		_finish_active_customer_session()
		return

	while index < slots.size():
		var slot_minutes := slots[index]

		if current_minutes < slot_minutes:
			return

		var session_can_spawn := _active_customer_session != SESSION_NIGHT or _spawning_unlocked

		if _store_open and session_can_spawn:
			npc_spawn_requested.emit(pool[index])
		else:
			session["missed"] = int(session.get("missed", 0)) + 1

		index += 1
		session["index"] = index
		_customer_sessions[_active_customer_session] = session


func _start_customer_session(session_name: StringName) -> void:
	if not _customer_sessions.has(session_name):
		_active_customer_session = SESSION_NONE
		return

	_active_customer_session = session_name


func _finish_active_customer_session() -> void:
	if _active_customer_session == SESSION_NONE or not _customer_sessions.has(_active_customer_session):
		return

	var session := _customer_sessions[_active_customer_session] as Dictionary
	var pool := session.get("pool", []) as Array[NPCData]
	var index := int(session.get("index", 0))
	session["missed"] = int(session.get("missed", 0)) + maxi(0, pool.size() - index)
	session["index"] = pool.size()
	session["closed"] = true
	_customer_sessions[_active_customer_session] = session


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

	# Gooby is part of the day-one night customer session.
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
	# The monster is already scheduled in the night session. The old hook
	# emitted Gooby again here, which duplicated the first customer.

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


func _is_day_one_follow_up_story_npc(day: int, npc_data: NPCData) -> bool:
	return day == 1 and npc_data != null and npc_data.npc_id == "gooby"


func _make_day_one_customer(
	npc_id: String,
	display_name: String,
	shopping_items: Array[String],
	checkout_total: int,
	visit_phase: NPCData.VisitPhase,
	category: NPCData.NPCCategory = NPCData.NPCCategory.GENERIC,
	checkout_outcome: String = "paid",
	patience_type: NPCData.PatienceType = NPCData.PatienceType.PATIENT,
	assets_path: String = ""
) -> NPCData:
	var data := NPCData.new()
	data.npc_id = npc_id
	data.display_name = display_name
	data.npc_category = category
	data.visit_days = [1]
	data.visit_phase = visit_phase
	data.assets_path = assets_path
	data.patience_type = patience_type
	data.favorite_items = shopping_items.duplicate()
	data.set_meta("shopping_list", shopping_items.duplicate())
	data.set_meta("checkout_total", checkout_total)
	data.set_meta("checkout_outcome", checkout_outcome)
	return data
