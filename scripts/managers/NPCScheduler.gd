extends Node


@warning_ignore("unused_signal")
signal npc_spawn_requested(npc_data)

const SCHEDULE_BLUEPRINT_PATHS: Array[String] = [
	"res://data/npc/schedules/day_1_human.tres"
]
const SPAWN_INTERVAL: float = 60.0
const DAY_ONE_NIGHT_SPAWN_INTERVAL: float = 8.0
const DAY_ONE_SLIME_GOLD: int = 10
const HUMAN_CUSTOMER_START_MINUTES: int = TimeManager.MORNING_START_MINUTES
const HUMAN_CUSTOMER_END_MINUTES: int = 16 * 60
const NIGHT_CUSTOMER_START_MINUTES: int = TimeManager.NIGHT_START_MINUTES
const NIGHT_CUSTOMER_END_MINUTES: int = TimeManager.END_START_MINUTES
const DEFAULT_FIRST_DELAY_MINUTES: int = 30
const DEFAULT_END_BUFFER_MINUTES: int = 30
const DEFAULT_MIN_INTERVAL_MINUTES: int = 20
const DEFAULT_MAX_INTERVAL_MINUTES: int = 180
const SESSION_NONE: StringName = &"none"
const SESSION_HUMAN: StringName = &"human"
const SESSION_NIGHT: StringName = &"night"
const DAY_ONE_CUSTOMER_COUNT: int = 14

const BASE_HUMAN_CUSTOMER_COUNT: int = 14
const DAILY_CUSTOMER_COUNT_INCREASE: int = 1
const MAX_HUMAN_CUSTOMER_COUNT: int = 19

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

@warning_ignore("unused_private_class_variable")
var _npc_database: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _day_schedule: Array = []
@warning_ignore("unused_private_class_variable")
var _spawn_queue: Array = []
@warning_ignore("unused_private_class_variable")
var _spawn_timer: float = 0.0
@warning_ignore("unused_private_class_variable")
var _spawn_interval: float = SPAWN_INTERVAL
@warning_ignore("unused_private_class_variable")
var _is_spawning: bool = false
@warning_ignore("unused_private_class_variable")
var _day_one_night_monster_spawned: bool = false
@warning_ignore("unused_private_class_variable")
var _day_one_night_monster_follow_up_requested: bool = false
@warning_ignore("unused_private_class_variable")
var _spawning_unlocked: bool = false
@warning_ignore("unused_private_class_variable")
var _normal_spawning_unlocked: bool = false
@warning_ignore("unused_private_class_variable")
var _store_open: bool = false
@warning_ignore("unused_private_class_variable")
var _customer_sessions: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _active_customer_session: StringName = SESSION_NONE
@warning_ignore("unused_private_class_variable")
var _schedule_blueprints: Array[Resource] = []

@warning_ignore("unused_private_class_variable")
var _database: NPCSchedulerDatabase = NPCSchedulerDatabase.new()
@warning_ignore("unused_private_class_variable")
var _day_flow: NPCSchedulerDayFlow = NPCSchedulerDayFlow.new()
@warning_ignore("unused_private_class_variable")
var _session_builder: NPCSchedulerSessionBuilder = NPCSchedulerSessionBuilder.new()
@warning_ignore("unused_private_class_variable")
var _session_runtime: NPCSchedulerSessionRuntime = NPCSchedulerSessionRuntime.new()
@warning_ignore("unused_private_class_variable")
var _spawn_runtime: NPCSchedulerSpawnRuntime = NPCSchedulerSpawnRuntime.new()
@warning_ignore("unused_private_class_variable")
var _day_one_factory: NPCSchedulerDayOneFactory = NPCSchedulerDayOneFactory.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_setup_scheduler_controllers()
	_load_npc_data()
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.phase_changed.connect(_on_phase_changed)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process(delta: float) -> void:
	_process_active_customer_session()
	_spawn_runtime.process(delta)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _load_npc_database() -> void:
	_database.load_npc_database()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _load_npc_data() -> void:
	_database.load_npc_data()
	_session_builder.load_schedule_blueprints()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_day_started(day: int) -> void:
	_day_flow.on_day_started(day)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_phase_changed(phase) -> void:
	_day_flow.on_phase_changed(phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func lock_spawning_until_ready() -> void:
	_day_flow.lock_spawning_until_ready()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_spawning_now(start_day_one_customers_now: bool = false) -> void:
	_day_flow.unlock_spawning_now(start_day_one_customers_now)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_normal_day_spawning_now() -> void:
	_day_flow.unlock_normal_day_spawning_now()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_store_open(is_open: bool) -> void:
	_day_flow.set_store_open(is_open)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func are_customer_sessions_complete_for_day() -> bool:
	return _session_runtime.are_customer_sessions_complete_for_day()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func close_customer_sessions_for_day() -> void:
	_session_runtime.close_customer_sessions_for_day()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_night_customer_session() -> void:
	_session_runtime.start_night_customer_session()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func stop_normal_customer_spawning() -> void:
	_spawn_runtime.stop_normal_customer_spawning()

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_human_customer_count_for_day(day: int) -> int:
	return mini(
		BASE_HUMAN_CUSTOMER_COUNT
		+ maxi(0, day - 1)
		* DAILY_CUSTOMER_COUNT_INCREASE,
		MAX_HUMAN_CUSTOMER_COUNT
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _reset_customer_sessions() -> void:
	_session_runtime.reset_customer_sessions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _generate_schedule(day: int) -> void:
	_session_builder.generate_schedule(day)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _generate_customer_sessions_for_day(day: int) -> void:
	_session_builder.generate_customer_sessions_for_day(day)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_customer_session_blueprint(day: int, session_name: StringName) -> Dictionary:
	return _session_builder.get_customer_session_blueprint(day, session_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _build_customer_session_pool(day: int, blueprint: Dictionary) -> Array[NPCData]:
	return _session_builder.build_customer_session_pool(day, blueprint)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _align_night_customer_items(pool: Array[NPCData]) -> Array[NPCData]:
	return _day_one_factory.align_night_customer_items(pool)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_ghost_or_monster_customer(npc: NPCData) -> bool:
	return _day_one_factory.is_ghost_or_monster_customer(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _make_day_one_customer_from_data(npc_data: NPCData, shopping_item: String) -> NPCData:
	return _day_one_factory.make_day_one_customer_from_data(npc_data, shopping_item)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_customer_npc_data(
	day: int,
	asset_path_prefix: String = "",
	visit_phase: NPCData.VisitPhase = NPCData.VisitPhase.DAY
) -> Array[NPCData]:
	return _session_builder.get_customer_npc_data(day, asset_path_prefix, visit_phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _make_customer_session(blueprint: Dictionary, pool: Array[NPCData]) -> Dictionary:
	return _session_builder.make_customer_session(blueprint, pool)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _build_customer_session_slots(blueprint: Dictionary, customer_count: int) -> Array[int]:
	return _session_builder.build_customer_session_slots(blueprint, customer_count)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_active_interaction_blueprints() -> Array:
	return _session_runtime.get_active_interaction_blueprints()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func notify_npc_shelf_route_ready(_npc: NPC, travel_seconds: float) -> void:
	_session_runtime.notify_npc_shelf_route_ready(travel_seconds)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process_active_customer_session() -> void:
	_session_runtime.process_active_customer_session()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _start_customer_session(session_name: StringName) -> void:
	_session_runtime.start_customer_session(session_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _finish_active_customer_session() -> void:
	_session_runtime.finish_active_customer_session()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _start_spawning(phase) -> void:
	_spawn_runtime.start_spawning(phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _start_day_one_spawning(phase) -> void:
	_spawn_runtime.start_day_one_spawning(phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func spawn_day_one_night_monster_customer() -> void:
	_day_one_factory.spawn_day_one_night_monster_customer()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process_day_one_night_monster_follow_up(delta: float) -> void:
	_spawn_runtime.process_day_one_night_monster_follow_up(delta)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _stop_spawning() -> void:
	_spawn_runtime.stop_spawning()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _spawn_next_npc() -> void:
	_spawn_runtime.spawn_next_npc()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _can_spawn_phase_now(visit_phase: NPCData.VisitPhase) -> bool:
	return _spawn_runtime.can_spawn_phase_now(visit_phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _can_spawn_npc_now(visit_phase: NPCData.VisitPhase) -> bool:
	return _spawn_runtime.can_spawn_npc_now(visit_phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_normal_day_customer(npc_data: NPCData) -> bool:
	return _spawn_runtime.is_normal_day_customer(npc_data)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_day_one_follow_up_story_npc(day: int, npc_data: NPCData) -> bool:
	return _day_one_factory.is_day_one_follow_up_story_npc(day, npc_data)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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
