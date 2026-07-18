extends Node

const NPCSchedulerDatabase = preload("res://scripts/managers/npc_scheduler/NPCSchedulerDatabase.gd")
const NPCSchedulerDayFlow = preload("res://scripts/managers/npc_scheduler/NPCSchedulerDayFlow.gd")
const NPCSchedulerSessionBuilder = preload("res://scripts/managers/npc_scheduler/NPCSchedulerSessionBuilder.gd")
const NPCSchedulerSessionRuntime = preload("res://scripts/managers/npc_scheduler/NPCSchedulerSessionRuntime.gd")
const NPCSchedulerSpawnRuntime = preload("res://scripts/managers/npc_scheduler/NPCSchedulerSpawnRuntime.gd")
const NPCSchedulerDayOneFactory = preload("res://scripts/managers/npc_scheduler/NPCSchedulerDayOneFactory.gd")

signal npc_spawn_requested(npc_data)

const SPAWN_INTERVAL: float = 60.0
const DAY_ONE_NIGHT_SPAWN_INTERVAL: float = 8.0
const DAY_ONE_SLIME_GOLD: int = 10
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
var _spawning_unlocked: bool = false
var _normal_spawning_unlocked: bool = false
var _store_open: bool = false
var _customer_sessions: Dictionary = {}
var _active_customer_session: StringName = SESSION_NONE

var _database: NPCSchedulerDatabase = NPCSchedulerDatabase.new()
var _day_flow: NPCSchedulerDayFlow = NPCSchedulerDayFlow.new()
var _session_builder: NPCSchedulerSessionBuilder = NPCSchedulerSessionBuilder.new()
var _session_runtime: NPCSchedulerSessionRuntime = NPCSchedulerSessionRuntime.new()
var _spawn_runtime: NPCSchedulerSpawnRuntime = NPCSchedulerSpawnRuntime.new()
var _day_one_factory: NPCSchedulerDayOneFactory = NPCSchedulerDayOneFactory.new()


func _ready() -> void:
	_setup_scheduler_controllers()
	_load_npc_data()
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.phase_changed.connect(_on_phase_changed)


func _setup_scheduler_controllers() -> void:
	for controller in [
		_database,
		_day_flow,
		_session_builder,
		_session_runtime,
		_spawn_runtime,
		_day_one_factory
	]:
		controller.setup(self)


func _process(delta: float) -> void:
	_process_active_customer_session()
	_spawn_runtime.process(delta)


func _load_npc_database() -> void:
	_database.load_npc_database()


func _load_npc_data() -> void:
	_database.load_npc_data()


func _on_day_started(day: int) -> void:
	_day_flow.on_day_started(day)


func _on_phase_changed(phase) -> void:
	_day_flow.on_phase_changed(phase)


func lock_spawning_until_ready() -> void:
	_day_flow.lock_spawning_until_ready()


func unlock_spawning_now(start_day_one_customers_now: bool = false) -> void:
	_day_flow.unlock_spawning_now(start_day_one_customers_now)


func unlock_normal_day_spawning_now() -> void:
	_day_flow.unlock_normal_day_spawning_now()


func set_store_open(is_open: bool) -> void:
	_day_flow.set_store_open(is_open)


func are_customer_sessions_complete_for_day() -> bool:
	return _session_runtime.are_customer_sessions_complete_for_day()


func close_customer_sessions_for_day() -> void:
	_session_runtime.close_customer_sessions_for_day()


func start_night_customer_session() -> void:
	_session_runtime.start_night_customer_session()


func stop_normal_customer_spawning() -> void:
	_spawn_runtime.stop_normal_customer_spawning()


func _reset_customer_sessions() -> void:
	_session_runtime.reset_customer_sessions()


func _generate_schedule(day: int) -> void:
	_session_builder.generate_schedule(day)


func _generate_customer_sessions_for_day(day: int) -> void:
	_session_builder.generate_customer_sessions_for_day(day)


func _get_customer_session_blueprint(day: int, session_name: StringName) -> Dictionary:
	return _session_builder.get_customer_session_blueprint(day, session_name)


func _build_customer_session_pool(day: int, blueprint: Dictionary) -> Array[NPCData]:
	return _session_builder.build_customer_session_pool(day, blueprint)


func _align_night_customer_items(pool: Array[NPCData]) -> Array[NPCData]:
	return _day_one_factory.align_night_customer_items(pool)


func _is_ghost_or_monster_customer(npc: NPCData) -> bool:
	return _day_one_factory.is_ghost_or_monster_customer(npc)


func _make_day_one_customer_from_data(npc_data: NPCData, shopping_item: String) -> NPCData:
	return _day_one_factory.make_day_one_customer_from_data(npc_data, shopping_item)


func _get_customer_npc_data(
	day: int,
	asset_path_prefix: String = "",
	visit_phase: NPCData.VisitPhase = NPCData.VisitPhase.DAY
) -> Array[NPCData]:
	return _session_builder.get_customer_npc_data(day, asset_path_prefix, visit_phase)


func _make_customer_session(blueprint: Dictionary, pool: Array[NPCData]) -> Dictionary:
	return _session_builder.make_customer_session(blueprint, pool)


func _build_customer_session_slots(blueprint: Dictionary, customer_count: int) -> Array[int]:
	return _session_builder.build_customer_session_slots(blueprint, customer_count)


func _process_active_customer_session() -> void:
	_session_runtime.process_active_customer_session()


func _start_customer_session(session_name: StringName) -> void:
	_session_runtime.start_customer_session(session_name)


func _finish_active_customer_session() -> void:
	_session_runtime.finish_active_customer_session()


func _start_spawning(phase) -> void:
	_spawn_runtime.start_spawning(phase)


func _start_day_one_spawning(phase) -> void:
	_spawn_runtime.start_day_one_spawning(phase)


func spawn_day_one_night_monster_customer() -> void:
	_day_one_factory.spawn_day_one_night_monster_customer()


func _process_day_one_night_monster_follow_up(delta: float) -> void:
	_spawn_runtime.process_day_one_night_monster_follow_up(delta)


func _stop_spawning() -> void:
	_spawn_runtime.stop_spawning()


func _spawn_next_npc() -> void:
	_spawn_runtime.spawn_next_npc()


func _can_spawn_phase_now(visit_phase: NPCData.VisitPhase) -> bool:
	return _spawn_runtime.can_spawn_phase_now(visit_phase)


func _can_spawn_npc_now(visit_phase: NPCData.VisitPhase) -> bool:
	return _spawn_runtime.can_spawn_npc_now(visit_phase)


func _is_normal_day_customer(npc_data: NPCData) -> bool:
	return _spawn_runtime.is_normal_day_customer(npc_data)


func _is_day_one_follow_up_story_npc(day: int, npc_data: NPCData) -> bool:
	return _day_one_factory.is_day_one_follow_up_story_npc(day, npc_data)


func _make_day_one_customer(
	npc_id: String,
	display_name: String,
	shopping_items: Array,
	checkout_total: int,
	visit_phase: NPCData.VisitPhase,
	category: NPCData.NPCCategory = NPCData.NPCCategory.GENERIC,
	checkout_outcome: String = "paid",
	patience_type: NPCData.PatienceType = NPCData.PatienceType.PATIENT,
	assets_path: String = ""
) -> NPCData:
	return _day_one_factory.make_day_one_customer(
		npc_id,
		display_name,
		shopping_items,
		checkout_total,
		visit_phase,
		category,
		checkout_outcome,
		patience_type,
		assets_path
	)
