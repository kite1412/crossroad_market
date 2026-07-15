class_name Store
extends Node2D

const StoreNotificationBridge = preload("res://scripts/locations/store/StoreNotificationBridge.gd")
const StoreNpcSpawner = preload("res://scripts/locations/store/StoreNpcSpawner.gd")
const StoreProgressionController = preload("res://scripts/locations/store/StoreProgressionController.gd")
const StoreShelfController = preload("res://scripts/locations/store/StoreShelfController.gd")
const StoreTransitionController = preload("res://scripts/locations/store/StoreTransitionController.gd")
const StoreNPCPathGraph = preload("res://scripts/locations/store/StoreNPCPathGraph.gd")

const NORMAL_STOCK_REQUIRED: int = 4
const PUT_ACTION: StringName = &"put"
const STORE_DROP_OFFSET := Vector2(0, 24)
const CASHIER_DEPTH_HALF_WIDTH: float = 48.0
const CASHIER_DEPTH_BACK_OFFSET: float = 64.0
const CASHIER_DEPTH_FRONT_OFFSET: float = 8.0
const SHELF_DEPTH_HALF_WIDTH: float = 48.0
const SHELF_DEPTH_BACK_OFFSET: float = 56.0
const SHELF_DEPTH_FRONT_OFFSET: float = 8.0
const CARRY_SHELF_CASHIER_BLOCKER_SIZE := Vector2(96, 36)
const CARRY_SHELF_CASHIER_BLOCKER_OFFSET := Vector2(0, -70)
const STORE_SHELF_PICKUP_DISTANCE: float = 76.0
const DOOR_NO_DROP_MARGIN: float = 8.0
const CASHIER_FLOW_RESTRICTED_SIZE := Vector2(180, 110)
const CASHIER_FLOW_RESTRICTED_OFFSET := Vector2(0, -40)
const CUSTOMER_PATH_ALERT_COOLDOWN_MS: int = 1000
const HUMAN_CUSTOMER_END_MINUTES: int = TimeManager.NIGHT_START_MINUTES
const SHELF_INTERACTION_STAND_DISTANCE: float = 54.0
const RESTRICTED_DROP_MESSAGE_COUNT: int = 3
const RESTRICTED_DROP_MESSAGE_DURATION: float = 0.55
const RESTRICTED_DANGER_LINE_CYCLES: int = 3
const RESTRICTED_DANGER_LINE_CYCLE_DURATION: float = 1.5
const RESTRICTED_DANGER_LINE_WIDTH: float = 3.0
const RESTRICTED_DANGER_LINE_COLOR := Color(1.0, 0.16, 0.08, 1.0)
const LOCATION_TITLE_DURATION: float = 1.25
const DROP_REJECTION_NONE: StringName = &"none"
const DROP_REJECTION_STORAGE_DOOR: StringName = &"storage_door"
const DROP_REJECTION_YARD_DOOR: StringName = &"yard_door"
const DROP_REJECTION_CUSTOMER_PATH: StringName = &"customer_path"
const DROP_REJECTION_CASHIER_FLOW: StringName = &"cashier_flow"
const DROP_REJECTION_COLLISION: StringName = &"collision"
const DROP_REJECTION_REACHABILITY: StringName = &"reachability"
const SHELF_DROP_FALLBACKS: Array[Vector2] = [
	Vector2(0, 56),
	Vector2(56, 0),
	Vector2(-56, 0),
	Vector2(0, -36),
	Vector2(56, 36),
	Vector2(-56, 36),
	Vector2(56, -36),
	Vector2(-56, -36)
]

var npc_scene: PackedScene = preload("res://scenes/npc/NPC.tscn")
var storage_scene: PackedScene = preload("res://scenes/locations/Storage.tscn")
var yard_scene: PackedScene = preload("res://scenes/locations/Yard.tscn")

@onready var counter_pos: Marker2D = get_node_or_null("CounterPos") as Marker2D
@onready var entrance_pos: Marker2D = get_node_or_null("EntrancePos") as Marker2D
@onready var npc_path_markers: Node2D = get_node_or_null("NPCPathMarkers") as Node2D
@onready var npc_entry_marker: Marker2D = _get_marker2d(NodePath("NPCPathMarkers/NPCPathEntry"), NodePath("NPCEntryMarker"))
@onready var npc_exit_marker: Marker2D = _get_marker2d(NodePath("NPCPathMarkers/NPCPathExit"), NodePath("NPCExitMarker"))
@onready var npc_store_path_marker: Marker2D = _get_marker2d(NodePath("NPCPathMarkers/NPCPathAisleRight"), NodePath("NPCStorePathMarker"))
@onready var npc_path_cashier_marker: Marker2D = _get_marker2d(NodePath("NPCPathMarkers/NPCPathCashier"), NodePath("NPCPathCashier"))
@onready var npc_queue_marker: Marker2D = _get_marker2d(NodePath("NPCPathMarkers/NPCQueueFront"), NodePath("NPCQueueMarker"))
@onready var customer_path_zones: Node2D = get_node_or_null("CustomerPathZones") as Node2D
@onready var storage_door: Area2D = get_node_or_null("StorageDoor") as Area2D
@onready var storage_return_pos: Marker2D = get_node_or_null("StorageReturnPos") as Marker2D
@onready var yard_door: Area2D = get_node_or_null("YardDoor") as Area2D
@onready var yard_return_pos: Marker2D = get_node_or_null("YardReturnPos") as Marker2D
@onready var player: Node2D = get_node_or_null("Player") as Node2D
@onready var cashier: Node2D = get_node_or_null("Cashier") as Node2D
@onready var open_close_board: Node = get_node_or_null("OpenCloseBoard")

var _current_storage: Node2D = null
var _current_yard: Node2D = null
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _location_title_layer: CanvasLayer = null
var _location_title_label: Label = null
var _location_title_tween: Tween = null
var _carry_shelf_blocker: StaticBody2D = null
var _carry_shelf_blocker_shape: CollisionShape2D = null
var _restricted_placement_warning: Node2D = null
var _restricted_placement_warning_line: Line2D = null
var _restricted_placement_warning_tween: Tween = null
var _npc_path_graph: StoreNPCPathGraph = null
var _is_transitioning: bool = false
var _shown_location_titles: Dictionary = {}
var _completed_task_notices: Dictionary = {}

var _normal_items_taken: int = 0
var _human_items_placed: int = 0
var _normal_supply_depleted: bool = false
var _mystery_phase_unlocked: bool = false
var _mystery_discovered: bool = false
var _mystery_supply_depleted: bool = false
var _human_shelf_installed: bool = false
var _ghost_shelf_installed: bool = false
var _customer_spawning_unlocked: bool = false
var _store_open: bool = false
var _store_opened_today: bool = false
var _store_closed_for_day: bool = false
var _customer_open_notification_shown: bool = false
var _suppress_next_day_open_notification: bool = false
var _intro_shown: bool = false
var _yard_intro_shown: bool = false
var _pending_store_intro_after_yard: bool = true
var _first_activity_board_shown: bool = false
var _ghost_shelf_lesson_shown: bool = false
var _gooby_resolved: bool = false
var _last_objective_text: String = ""
var _restricted_drop_feedback_token: int = 0
var _last_customer_path_alert_msec: int = 0

var human_shelf: Shelf = null
var ghost_shelf: Shelf = null


func _ready() -> void:
	add_to_group("store")
	_npc_path_graph = StoreNPCPathGraph.new(self, npc_path_markers)

	_connect_manager_signals()
	_connect_scene_signals()
	_set_customer_path_visual_visible(false)
	_update_store_status_board(false)
	_create_fade_layer()
	_create_location_title_layer()
	_create_carry_shelf_blocker()
	_create_restricted_placement_warning()
	_setup_npc_static_data()
	NPC.current_queue.clear()
	NPCScheduler.lock_spawning_until_ready()

	TimeManager.start_game()
	call_deferred("_start_game_in_yard")


func _process(_delta: float) -> void:
	if _current_storage != null or _current_yard != null or _is_transitioning:
		_set_carry_shelf_blocker_enabled(false)
		_set_customer_path_visual_visible(false)
		_hide_restricted_placement_warning()
		return

	_update_carry_shelf_blocker()
	_update_customer_path_visual()
	_update_player_depth_override()

	if _is_action_locked():
		return

	if _is_put_pressed():
		var carried_object := _get_carried_object_from_player()

		if carried_object != null:
			_drop_carried_shelf_in_store(carried_object)


func request_enter_storage(_door_type: String = "storage") -> void:
	if _is_transitioning or _current_storage != null:
		return

	await _enter_storage()


func request_enter_yard(_door_type: String = "yard") -> void:
	if _is_transitioning or _current_yard != null:
		return

	await _enter_yard()


func on_normal_item_taken() -> void:
	_normal_items_taken = min(_normal_items_taken + 1, NORMAL_STOCK_REQUIRED)
	_update_objective()

	if _normal_items_taken >= NORMAL_STOCK_REQUIRED:
		_normal_supply_depleted = true
		_show_notification("Bring the human shelf to the store and stock it.", 3.0)
		_update_objective()
		return


func on_human_item_placed() -> void:
	_register_human_stock_progress()
	_update_objective()


func is_shelf_type_installed(shelf_type: ItemData.ShelfType) -> bool:
	match shelf_type:
		ItemData.ShelfType.HUMAN:
			return _human_shelf_installed
		ItemData.ShelfType.GHOST:
			return _ghost_shelf_installed

	return false


func request_toggle_store_open() -> void:
	if _store_open:
		_manual_close_store()
		return

	if _store_closed_for_day:
		_show_notification("Store is closed for the day.", 1.2)
		_update_store_status_board()
		return

	if not _is_day_setup_complete():
		_show_notification("Set up the shelf and stock items before opening.", 1.5)
		_update_store_status_board()
		return

	var current_minutes := TimeManager.get_current_clock_minutes()

	if current_minutes >= HUMAN_CUSTOMER_END_MINUTES:
		_show_notification("Not enough time left for customers today.", 1.4)
		_store_closed_for_day = true
		_update_store_status_board()
		return

	_open_store_at(current_minutes)


func _is_day_setup_complete() -> bool:
	return _human_shelf_installed and _human_items_placed >= NORMAL_STOCK_REQUIRED


func _open_store_at(_open_minutes: int) -> void:
	_store_open = true
	_store_opened_today = true
	_store_closed_for_day = false

	NPCScheduler.set_store_open(true)
	_update_store_status_board()
	_show_status_notification("Store is OPEN.", 1.0)
	_show_task_complete_notice("store_opened", "Open sign flipped.")
	_update_objective()


func _manual_close_store() -> void:
	_store_open = false
	NPCScheduler.set_store_open(false)
	_update_store_status_board()
	_show_status_notification("Store is CLOSED.", 1.0)
	_update_objective()


func _close_store_for_day() -> void:
	if _store_closed_for_day:
		return

	_store_open = false
	_store_closed_for_day = true
	NPCScheduler.set_store_open(false)
	NPCScheduler.close_human_customer_schedule_for_day()
	_update_store_status_board()
	_update_objective()


func _update_store_status_board(animated: bool = true) -> void:
	open_close_board = _get_open_close_board()

	if open_close_board != null and open_close_board.has_method("set_open_state"):
		open_close_board.call("set_open_state", _store_open, animated)


func _get_open_close_board() -> Node:
	if open_close_board != null and is_instance_valid(open_close_board):
		return open_close_board

	var yard_board: Node = null

	if _current_yard != null and is_instance_valid(_current_yard):
		yard_board = _current_yard.get_node_or_null("OpenCloseBoard")

	if yard_board != null:
		return yard_board

	var group_board := get_tree().get_first_node_in_group("open_close_board")

	if group_board != null:
		return group_board

	return get_node_or_null("OpenCloseBoard")


func get_npc_entry_route_to_shelf(shelf_position: Vector2, from_position: Vector2 = Vector2.INF) -> Array[Vector2]:
	return _get_npc_path_graph().get_entry_route_to_shelf(shelf_position, from_position)


func get_npc_shelf_access_position(shelf: Shelf) -> Vector2:
	return _get_npc_path_graph().get_shelf_access_position(shelf)


func get_npc_shelf_visit_position(shelf: Shelf, _npc: Node = null) -> Vector2:
	return get_npc_shelf_access_position(shelf)


func get_npc_route_to_shelf_access(shelf: Shelf) -> Array[Vector2]:
	return _get_npc_path_graph().get_route_to_shelf_access(shelf)


func get_npc_route_to_cashier_from(from_position: Vector2) -> Array[Vector2]:
	return _get_npc_path_graph().get_route_to_cashier_from(from_position)


func get_npc_route_from_shelf_to_cashier(shelf: Shelf) -> Array[Vector2]:
	return _get_npc_path_graph().get_route_from_shelf_to_cashier(shelf)


func get_npc_exit_route_from(from_position: Vector2) -> Array[Vector2]:
	var exit_position := _get_marker_position_or(npc_exit_marker, Vector2(392, 248))
	return _get_npc_path_graph().get_exit_route_from(from_position, exit_position)


func get_npc_exit_route_from_cashier() -> Array[Vector2]:
	var from_position := _get_marker_position_or(npc_queue_marker, _get_marker_position_or(counter_pos, Vector2(96, 160)))
	return get_npc_exit_route_from(from_position)


func get_activity_board_guidance() -> Dictionary:
	var activities := [
		{"text": "Pick the Human Shelf at the Storage, and bring it to the Store", "done": _human_shelf_installed},
		{"text": "Take stock from the Storage and bring it to the Human Shelf", "done": _completed_task_notices.has("human_shelf_stocked")},
		{"text": "Check the dark corner inside the Storage", "done": _mystery_discovered},
		{"text": "Pick the Ghost Shelf at the Storage, and bring it to the Store", "done": _completed_task_notices.has("ghost_shelf_placed")},
		{"text": "Stock the Ghost Shelf", "done": _completed_task_notices.has("ghost_shelf_stocked")},
		{"text": "Flip the Open Sign outside the Store", "done": _store_opened_today},
		{"text": "Serve customers at the Store cashier", "done": _completed_task_notices.has("normal_customer_served")}
	]

	var lines: Array[String] = []
	var next_todo_index: int = -1

	for i in activities.size():
		if bool(activities[i]["done"]):
			lines.append("[x] %s" % [str(activities[i]["text"])])
		elif next_todo_index == -1:
			next_todo_index = i

	if next_todo_index != -1:
		lines.append("[ ] %s" % [str(activities[next_todo_index]["text"])])
	elif lines.is_empty():
		lines.append("[ ] Pick the Human Shelf at the Storage, and bring it to the Store")
	else:
		lines.append("All listed activities are complete.")

	return {
		"title": "Today's Work",
		"lines": lines
	}


func on_gooby_resolved() -> void:
	_gooby_resolved = true
	_show_task_complete_notice("gooby_resolved", "Gooby branch resolved.")
	_update_objective()


func _connect_manager_signals() -> void:
	if not NPCScheduler.npc_spawn_requested.is_connected(_on_npc_spawn_requested):
		NPCScheduler.npc_spawn_requested.connect(_on_npc_spawn_requested)

	if not TimeManager.phase_changed.is_connected(_on_phase_changed):
		TimeManager.phase_changed.connect(_on_phase_changed)

	if not TimeManager.day_ended.is_connected(_on_day_ended):
		TimeManager.day_ended.connect(_on_day_ended)

	if not TimeManager.day_started.is_connected(_on_day_started):
		TimeManager.day_started.connect(_on_day_started)

	if not EconomyManager.daily_target_reached.is_connected(_on_target_reached):
		EconomyManager.daily_target_reached.connect(_on_target_reached)

	if not EconomyManager.daily_report_ready.is_connected(_on_daily_report):
		EconomyManager.daily_report_ready.connect(_on_daily_report)


func _connect_scene_signals() -> void:
	if storage_door == null:
		push_error("Store: StorageDoor is missing.")
	else:
		storage_door.set_meta("door_type", "storage")
		_connect_cursor_tooltip(storage_door, "Storage Door")

	if yard_door == null:
		push_error("Store: YardDoor is missing.")
	else:
		yard_door.set_meta("door_type", "yard")
		_connect_cursor_tooltip(yard_door, "Yard Door")


func _show_morning_intro() -> void:
	if _intro_shown:
		return

	_intro_shown = true
	await _show_notification_sequence([
		"Finally made it... Grandma's old shop.",
		"It's dusty, but it still feels like home.",
		"Go to the backroom and bring out the human shelf."
	])
	_show_first_activity_board()


func _show_first_activity_board() -> void:
	if _first_activity_board_shown:
		return

	_first_activity_board_shown = true

	var activity_board := get_node_or_null("ActivityBoard")

	if activity_board != null and activity_board.has_method("open_board"):
		activity_board.call("open_board")


func _start_game_in_yard() -> void:
	if _yard_intro_shown:
		return

	if yard_scene == null:
		_show_location_title_once("store", "Store")
		call_deferred("_show_morning_intro")
		return

	if player == null:
		player = get_node_or_null("Player") as Node2D

	if player == null:
		push_error("Store: Player is missing.")
		return

	_current_yard = yard_scene.instantiate() as Node2D
	add_child(_current_yard)
	_current_yard.position = Vector2.ZERO
	_current_yard.z_index = 100
	_connect_yard_return_signal()
	open_close_board = null
	_update_store_status_board(false)

	var spawn_marker := _current_yard.get_node_or_null("PlayerSpawn") as Node2D
	var spawn_position := spawn_marker.global_position if spawn_marker != null else Vector2(240, 136)

	_set_store_world_active(false)
	StoreTransitionController.prepare_player_for_location(player, _current_yard, spawn_position)
	_show_location_title_once("yard", "Yard")
	_show_yard_intro()


func _show_yard_intro() -> void:
	if _yard_intro_shown:
		return

	_yard_intro_shown = true
	await _show_notification_sequence([
		"Grandma's old shop is just ahead.",
		"Take a breath, then head inside.",
		"Press E at the shop door to enter."
	])


func _connect_yard_return_signal() -> void:
	if _current_yard == null:
		return

	if _current_yard.has_signal("return_to_store"):
		var return_callable := Callable(self, "_on_yard_return")

		if not _current_yard.is_connected("return_to_store", return_callable):
			_current_yard.connect("return_to_store", return_callable)
	else:
		push_error("Store: Yard scene must emit return_to_store.")


func _enter_storage() -> void:
	if storage_scene == null:
		push_error("Store: Storage scene is missing.")
		return

	if player == null:
		player = get_node_or_null("Player") as Node2D

	if player == null:
		push_error("Store: Player is missing.")
		return

	_is_transitioning = true
	_cancel_restricted_drop_feedback()
	await _fade_to_black()

	_current_storage = storage_scene.instantiate() as Node2D
	add_child(_current_storage)
	_current_storage.position = Vector2.ZERO
	_current_storage.z_index = 100

	if _current_storage.has_method("set_entry_door"):
		_current_storage.set_entry_door("storage")

	if _current_storage.has_method("set_shelf_install_state"):
		_current_storage.set_shelf_install_state(
			_human_shelf_installed or _is_player_carrying_shelf_named("ShelfHuman"),
			_ghost_shelf_installed or _is_player_carrying_shelf_named("ShelfGhost")
		)

	if _current_storage.has_method("set_normal_supply_depleted"):
		_current_storage.set_normal_supply_depleted(_normal_supply_depleted)

	if _current_storage.has_method("set_mystery_discovered"):
		_current_storage.set_mystery_discovered(_mystery_discovered)

	if _current_storage.has_method("set_mystery_supply_depleted"):
		_current_storage.set_mystery_supply_depleted(_mystery_supply_depleted)

	if _current_storage.has_method("set_mystery_phase_unlocked"):
		_current_storage.set_mystery_phase_unlocked(_mystery_phase_unlocked)

	if _current_storage.has_signal("return_to_store"):
		var return_callable := Callable(self, "_on_storage_return")

		if not _current_storage.is_connected("return_to_store", return_callable):
			_current_storage.connect("return_to_store", return_callable)
	else:
		push_error("Store: Storage scene must emit return_to_store.")

	if _current_storage.has_signal("mystery_discovered"):
		var mystery_callable := Callable(self, "_on_storage_mystery_discovered")

		if not _current_storage.is_connected("mystery_discovered", mystery_callable):
			_current_storage.connect("mystery_discovered", mystery_callable)

	if _current_storage.has_signal("mystery_item_taken"):
		var mystery_item_callable := Callable(self, "_on_storage_mystery_item_taken")

		if not _current_storage.is_connected("mystery_item_taken", mystery_item_callable):
			_current_storage.connect("mystery_item_taken", mystery_item_callable)

	if _current_storage.has_signal("ghost_shelf_item_placed"):
		var ghost_shelf_callable := Callable(self, "_on_ghost_shelf_item_placed")

		if not _current_storage.is_connected("ghost_shelf_item_placed", ghost_shelf_callable):
			_current_storage.connect("ghost_shelf_item_placed", ghost_shelf_callable)

	var spawn_marker := _current_storage.get_node_or_null("PlayerSpawn") as Node2D
	var spawn_position := spawn_marker.global_position if spawn_marker != null else Vector2(42, 68)

	_set_store_world_active(false)
	StoreTransitionController.prepare_player_for_location(player, _current_storage, spawn_position)

	await _fade_from_black()
	_show_location_title_once("storage", "Storage")
	_is_transitioning = false


func _on_storage_return(_door_type: String) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	_close_cashier_runtime_ui()
	await _fade_to_black()

	if player == null and _current_storage != null:
		player = _current_storage.get_node_or_null("Player") as Node2D

	if player != null:
		StoreTransitionController.prepare_player_for_location(player, self, _get_storage_return_position())
	else:
		push_error("Store: Player not found while returning from Storage.")

	var storage_to_remove := _current_storage

	if storage_to_remove != null:
		storage_to_remove.queue_free()

	_set_store_world_active(true)
	_current_storage = null
	_setup_npc_static_data()
	_update_objective()

	await _fade_from_black()
	_is_transitioning = false


func _enter_yard() -> void:
	if yard_scene == null:
		push_error("Store: Yard scene is missing.")
		return

	if player == null:
		player = get_node_or_null("Player") as Node2D

	if player == null:
		push_error("Store: Player is missing.")
		return

	_is_transitioning = true
	_cancel_restricted_drop_feedback()
	_close_cashier_runtime_ui()
	await _fade_to_black()

	_current_yard = yard_scene.instantiate() as Node2D
	add_child(_current_yard)
	_current_yard.position = Vector2.ZERO
	_current_yard.z_index = 100
	_connect_yard_return_signal()
	open_close_board = null
	_update_store_status_board(false)

	var spawn_marker := _current_yard.get_node_or_null("PlayerSpawn") as Node2D
	var spawn_position := spawn_marker.global_position if spawn_marker != null else Vector2(240, 136)

	_set_store_world_active(false)
	StoreTransitionController.prepare_player_for_location(player, _current_yard, spawn_position)

	await _fade_from_black()
	_show_location_title_once("yard", "Yard")
	_is_transitioning = false


func _on_yard_return(_door_type: String) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	await _fade_to_black()

	if player == null and _current_yard != null:
		player = _current_yard.get_node_or_null("Player") as Node2D

	if player != null:
		StoreTransitionController.prepare_player_for_location(player, self, _get_yard_return_position())
	else:
		push_error("Store: Player not found while returning from Yard.")

	var yard_to_remove := _current_yard

	if yard_to_remove != null:
		yard_to_remove.queue_free()

	_set_store_world_active(true)
	_current_yard = null
	open_close_board = null
	_setup_npc_static_data()
	_update_objective()

	await _fade_from_black()
	_is_transitioning = false

	if _pending_store_intro_after_yard:
		_pending_store_intro_after_yard = false
		_show_location_title_once("store", "Store")
		call_deferred("_show_morning_intro")


func _on_storage_mystery_discovered() -> void:
	_mystery_discovered = true
	_show_task_complete_notice("mystery_discovered", "Mystery corner discovered.")
	_update_objective()


func _on_storage_mystery_item_taken() -> void:
	_mystery_supply_depleted = true
	_update_objective()


func _get_storage_return_position() -> Vector2:
	if storage_return_pos != null:
		return storage_return_pos.global_position

	if storage_door != null:
		return storage_door.global_position + Vector2(0, 44)

	return Vector2(120, 96)


func _get_yard_return_position() -> Vector2:
	if yard_return_pos != null:
		return yard_return_pos.global_position

	if yard_door != null:
		return yard_door.global_position + Vector2(0, -32)

	return Vector2(432, 210)


func _is_put_pressed() -> bool:
	return InputMap.has_action(PUT_ACTION) and Input.is_action_just_pressed(PUT_ACTION)


func _is_action_locked() -> bool:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))


func _get_carried_object_from_player() -> Node2D:
	return StoreShelfController.get_carried_object_from_player(player)


func request_drop_carried_shelf() -> bool:
	var carried_object := _get_carried_object_from_player()

	if carried_object == null:
		return false

	_drop_carried_shelf_in_store(carried_object)
	return true


func request_pickup_shelf(shelf: Shelf) -> bool:
	if shelf == null or player == null:
		return false

	if not _is_descendant_of(shelf, self):
		return false

	if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
		return false

	if player.global_position.distance_to(shelf.global_position) > STORE_SHELF_PICKUP_DISTANCE:
		return false

	_pickup_installed_shelf(shelf)
	return true


func _is_player_carrying_shelf_named(shelf_name: String) -> bool:
	return StoreShelfController.is_player_carrying_shelf_named(player, shelf_name)


func _drop_carried_shelf_in_store(object: Node2D) -> void:
	if player == null:
		return

	var primary_drop_position := _get_primary_shelf_drop_position()
	var primary_restriction := _evaluate_shelf_drop_restriction(object, primary_drop_position)
	var drop_position := _find_safe_drop_position(object)

	if drop_position == Vector2.INF:
		if not bool(primary_restriction.get("blocked", false)):
			primary_restriction = _get_drop_failure_context(object)

		if not bool(primary_restriction.get("blocked", false)):
			var primary_object_rect := _get_object_body_rect_at(object, primary_drop_position)
			primary_restriction = _make_drop_restriction(
				true,
				DROP_REJECTION_COLLISION,
				"I can't place the shelf here.",
				primary_object_rect,
				false
			)

		_show_drop_restriction_feedback(primary_restriction)
		return

	object.reparent(self, true)
	object.global_position = drop_position
	object.z_index = 0
	_set_shelf_carried_state(object, false)
	_store_shelf_access_metadata(object, drop_position)
	_register_installed_shelf(object)
	_set_customer_path_visual_visible(false)

	_show_notification("Shelf placed in the store.")


func _create_carry_shelf_blocker() -> void:
	_carry_shelf_blocker = StaticBody2D.new()
	_carry_shelf_blocker.name = "CarryShelfCashierBlocker"
	_carry_shelf_blocker.visible = false
	add_child(_carry_shelf_blocker)

	var shape := RectangleShape2D.new()
	shape.size = CARRY_SHELF_CASHIER_BLOCKER_SIZE

	_carry_shelf_blocker_shape = CollisionShape2D.new()
	_carry_shelf_blocker_shape.name = "CollisionShape2D"
	_carry_shelf_blocker_shape.shape = shape
	_carry_shelf_blocker.add_child(_carry_shelf_blocker_shape)

	_set_carry_shelf_blocker_enabled(false)


func _create_restricted_placement_warning() -> void:
	_restricted_placement_warning = Node2D.new()
	_restricted_placement_warning.name = "RestrictedPlacementWarning"
	_restricted_placement_warning.z_index = 90
	_restricted_placement_warning.visible = false
	_restricted_placement_warning.modulate.a = 0.0
	add_child(_restricted_placement_warning)

	_restricted_placement_warning_line = Line2D.new()
	_restricted_placement_warning_line.name = "RestrictedPlacementWarningLine"
	_restricted_placement_warning_line.width = RESTRICTED_DANGER_LINE_WIDTH
	_restricted_placement_warning_line.default_color = RESTRICTED_DANGER_LINE_COLOR
	_restricted_placement_warning_line.closed = true
	_restricted_placement_warning_line.visible = false
	_restricted_placement_warning.add_child(_restricted_placement_warning_line)


func _update_carry_shelf_blocker() -> void:
	if _carry_shelf_blocker != null:
		_carry_shelf_blocker.global_position = _get_carry_shelf_blocker_position()

	_set_carry_shelf_blocker_enabled(false)


func _update_customer_path_visual() -> void:
	_set_customer_path_visual_visible(_get_carried_object_from_player() != null)


func _set_customer_path_visual_visible(is_visible: bool) -> void:
	if customer_path_zones == null:
		return

	customer_path_zones.visible = is_visible


func _set_carry_shelf_blocker_enabled(_enabled: bool) -> void:
	if _carry_shelf_blocker_shape == null:
		return

	_carry_shelf_blocker_shape.disabled = true


func _find_safe_drop_position(object: Node2D) -> Vector2:
	for candidate in _get_drop_candidates():
		if not bool(_evaluate_shelf_drop_restriction(object, candidate).get("blocked", false)):
			return candidate

	return Vector2.INF


func _get_drop_failure_context(object: Node2D) -> Dictionary:
	for candidate in _get_drop_candidates():
		var rejection := _evaluate_shelf_drop_restriction(object, candidate)

		if bool(rejection.get("blocked", false)):
			return rejection

	return _make_drop_restriction()


func _get_drop_candidates() -> Array[Vector2]:
	var candidates: Array[Vector2] = []

	candidates.append(_get_primary_shelf_drop_position())

	return candidates


func _get_primary_shelf_drop_position() -> Vector2:
	return player.global_position + _get_player_facing_direction() * 56.0


func _get_player_facing_direction() -> Vector2:
	var facing: Variant = player.get("facing_direction") if player != null else Vector2.DOWN

	if facing is Vector2 and not facing.is_zero_approx():
		return (facing as Vector2).normalized()

	return Vector2.DOWN


func _is_drop_position_clear(object: Node2D, candidate: Vector2) -> bool:
	var collision_shape := _get_object_collision_shape(object)

	if collision_shape == null or collision_shape.shape == null:
		return true

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = Transform2D(0.0, candidate + collision_shape.position)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hits := get_world_2d().direct_space_state.intersect_shape(query, 16)

	for hit in hits:
		var collider: Node = hit.get("collider", null)

		if collider == null:
			continue

		if collider == object or _is_descendant_of(collider, object):
			continue

		return false

	return true


func _evaluate_shelf_drop_restriction(object: Node2D, candidate: Vector2) -> Dictionary:
	var object_rect := _get_object_body_rect_at(object, candidate)

	var storage_door_rect := _get_door_no_drop_rect(storage_door, DOOR_NO_DROP_MARGIN)

	if _rect_has_area(storage_door_rect) and object_rect.intersects(storage_door_rect):
		return _make_drop_restriction(
			true,
			DROP_REJECTION_STORAGE_DOOR,
			"This blocks the storage door.",
			storage_door_rect,
			false
		)

	var yard_door_rect := _get_door_no_drop_rect(yard_door, DOOR_NO_DROP_MARGIN)

	if _rect_has_area(yard_door_rect) and object_rect.intersects(yard_door_rect):
		return _make_drop_restriction(
			true,
			DROP_REJECTION_YARD_DOOR,
			"This blocks the yard door.",
			yard_door_rect,
			false
		)

	if _object_rect_intersects_customer_path(object_rect):
		return _make_drop_restriction(
			true,
			DROP_REJECTION_CUSTOMER_PATH,
			"Keep the customer path clear.",
			object_rect,
			false
		)

	var cashier_flow_rect := _get_cashier_flow_restricted_rect()

	if _rect_has_area(cashier_flow_rect) and object_rect.intersects(cashier_flow_rect):
		return _make_drop_restriction(
			true,
			DROP_REJECTION_CASHIER_FLOW,
			"Keep this area clear for customers.",
			cashier_flow_rect,
			true
		)

	if not _is_drop_position_clear(object, candidate):
		return _make_drop_restriction(
			true,
			DROP_REJECTION_COLLISION,
			"I can't place the shelf here.",
			object_rect,
			false
		)

	if not _has_reachable_npc_shelf_visit_position(object, candidate):
		return _make_drop_restriction(
			true,
			DROP_REJECTION_REACHABILITY,
			"Customers can't reach the shelf there.",
			object_rect,
			false
		)

	return _make_drop_restriction()


func _make_drop_restriction(
	blocked: bool = false,
	rejection_type: StringName = DROP_REJECTION_NONE,
	message: String = "",
	warning_rect: Rect2 = Rect2(),
	show_warning: bool = false
) -> Dictionary:
	return {
		"blocked": blocked,
		"type": rejection_type,
		"message": message,
		"warning_rect": warning_rect,
		"show_warning": show_warning
	}


func _rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0


func _get_object_body_rect_at(object: Node2D, candidate: Vector2) -> Rect2:
	var collision_shape := _get_object_collision_shape(object)

	if collision_shape == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var center := candidate + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


func _get_door_no_drop_rect(area: Area2D, margin: float) -> Rect2:
	if area == null:
		return Rect2()

	var area_rect := _get_area_rect(area)

	if area_rect.size == Vector2.ZERO:
		return Rect2()

	return area_rect.grow(margin)


func _get_area_rect(area: Area2D) -> Rect2:
	if area == null:
		return Rect2()

	var collision_shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision_shape == null:
		return Rect2(area.global_position - Vector2(20, 20), Vector2(40, 40))

	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2(area.global_position - Vector2(20, 20), Vector2(40, 40))

	var center := area.global_position + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


func _get_cashier_flow_restricted_rect() -> Rect2:
	var center := Vector2(96, 132)

	if counter_pos != null:
		center = counter_pos.global_position
	elif cashier != null:
		center = cashier.global_position + Vector2(0, 38)

	center += CASHIER_FLOW_RESTRICTED_OFFSET
	return Rect2(center - CASHIER_FLOW_RESTRICTED_SIZE * 0.5, CASHIER_FLOW_RESTRICTED_SIZE)


func _object_rect_intersects_customer_path(object_rect: Rect2) -> bool:
	if not _rect_has_area(object_rect):
		return false

	for zone_rect in _get_customer_path_zone_rects():
		if object_rect.intersects(zone_rect):
			return true

	return false


func _get_customer_path_zone_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []

	if customer_path_zones == null:
		return rects

	for child in customer_path_zones.get_children():
		var zone := child as Area2D

		if zone == null:
			continue

		var zone_rect := _get_area_rect(zone)

		if _rect_has_area(zone_rect):
			rects.append(zone_rect)

	return rects


func _get_marker_position_or(marker: Marker2D, fallback: Vector2) -> Vector2:
	if marker == null:
		return fallback

	return marker.global_position


func _get_marker2d(primary_path: NodePath, fallback_path: NodePath = NodePath("")) -> Marker2D:
	var marker := get_node_or_null(primary_path) as Marker2D

	if marker != null:
		return marker

	if not fallback_path.is_empty():
		return get_node_or_null(fallback_path) as Marker2D

	return null


func _get_npc_path_graph() -> StoreNPCPathGraph:
	if _npc_path_graph == null:
		_npc_path_graph = StoreNPCPathGraph.new(self, npc_path_markers)
	else:
		_npc_path_graph.setup(self, npc_path_markers)

	return _npc_path_graph


func _has_reachable_npc_shelf_visit_position(object: Node2D, candidate: Vector2) -> bool:
	return _get_npc_path_graph().has_reachable_shelf_access(object, candidate)


func _get_object_collision_shape(object: Node2D) -> CollisionShape2D:
	if object == null:
		return null

	return object.get_node_or_null("PhysicsBody/CollisionShape2D") as CollisionShape2D


func _get_nearest_installed_shelf() -> Node2D:
	if player == null:
		return null

	var nearest_shelf: Node2D = null
	var nearest_distance := STORE_SHELF_PICKUP_DISTANCE

	for node in get_tree().get_nodes_in_group("shelves"):
		if not node is Shelf:
			continue

		var shelf := node as Shelf

		if not _is_descendant_of(shelf, self):
			continue

		if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
			continue

		var distance := player.global_position.distance_to(shelf.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_shelf = shelf

	return nearest_shelf


func _pickup_installed_shelf(object: Node2D) -> void:
	if player == null:
		return

	if object == human_shelf:
		_human_shelf_installed = false
	elif object == ghost_shelf:
		_ghost_shelf_installed = false

	object.reparent(player, true)
	object.position = Vector2(0, -34)
	object.z_index = 80
	_set_shelf_carried_state(object, true)
	_clear_shelf_access_metadata(object)
	_set_customer_path_visual_visible(true)
	_update_objective()
	_show_notification("Shelf picked up. Press Q to place it.")


func _set_shelf_carried_state(object: Node2D, is_carried: bool) -> void:
	if object == null:
		return

	object.set_meta("is_carried_storage_object", is_carried)
	object.set_meta("is_installed_in_store", not is_carried)

	if is_carried:
		object.remove_from_group("shelves")
		_set_node_enabled_recursive(object, false)
	else:
		_set_node_enabled_recursive(object, true)


func _store_shelf_access_metadata(object: Node2D, drop_position: Vector2) -> void:
	_get_npc_path_graph().store_shelf_access_metadata(object, drop_position)


func _clear_shelf_access_metadata(object: Node2D) -> void:
	_get_npc_path_graph().clear_shelf_access_metadata(object)


func _show_drop_restriction_feedback(restriction: Dictionary) -> void:
	var message := str(restriction.get("message", "I can't place the shelf here."))
	var rejection_type := restriction.get("type", DROP_REJECTION_NONE) as StringName

	if rejection_type == DROP_REJECTION_CUSTOMER_PATH:
		_show_customer_path_rejection_alert(message)
		return

	if bool(restriction.get("show_warning", false)):
		_show_restricted_drop_feedback(restriction)
		return

	_show_notification(message, 0.9)


func _show_customer_path_rejection_alert(message: String) -> void:
	var now := int(Time.get_ticks_msec())

	if now - _last_customer_path_alert_msec < CUSTOMER_PATH_ALERT_COOLDOWN_MS:
		return

	_last_customer_path_alert_msec = now
	_show_notification(message, 0.9)


func _show_restricted_drop_feedback(restriction: Dictionary) -> void:
	_restricted_drop_feedback_token += 1
	var feedback_token := _restricted_drop_feedback_token
	var message := str(restriction.get("message", "Keep this area clear for customers."))
	var warning_rect := _get_warning_rect_from_restriction(restriction)

	_play_restricted_placement_warning(warning_rect)

	for i in RESTRICTED_DROP_MESSAGE_COUNT:
		if feedback_token != _restricted_drop_feedback_token:
			return

		_show_notification(message, RESTRICTED_DROP_MESSAGE_DURATION)
		await get_tree().create_timer(2.0 / float(RESTRICTED_DROP_MESSAGE_COUNT)).timeout


func _get_warning_rect_from_restriction(restriction: Dictionary) -> Rect2:
	var rect_variant: Variant = restriction.get("warning_rect", Rect2())

	if rect_variant is Rect2:
		return rect_variant as Rect2

	return Rect2()


func _play_restricted_placement_warning(rect: Rect2) -> void:
	if _current_storage != null or _current_yard != null or _is_transitioning:
		_hide_restricted_placement_warning()
		return

	if _restricted_placement_warning == null:
		return

	if _restricted_placement_warning_tween != null and _restricted_placement_warning_tween.is_valid():
		_restricted_placement_warning_tween.kill()
	_restricted_placement_warning_tween = null

	if not _rect_has_area(rect):
		_hide_restricted_placement_warning()
		return

	_sync_restricted_placement_warning(rect)
	_restricted_placement_warning.visible = true
	_restricted_placement_warning.modulate.a = 0.0

	_restricted_placement_warning_tween = create_tween()

	for i in RESTRICTED_DANGER_LINE_CYCLES:
		_restricted_placement_warning_tween.tween_property(
			_restricted_placement_warning,
			"modulate:a",
			1.0,
			RESTRICTED_DANGER_LINE_CYCLE_DURATION * 0.5
		)
		_restricted_placement_warning_tween.tween_property(
			_restricted_placement_warning,
			"modulate:a",
			0.0,
			RESTRICTED_DANGER_LINE_CYCLE_DURATION * 0.5
		)

	_restricted_placement_warning_tween.tween_callback(func() -> void:
		_restricted_placement_warning_tween = null
		_hide_restricted_placement_warning()
	)


func _sync_restricted_placement_warning(rect: Rect2) -> void:
	if _restricted_placement_warning_line == null:
		return

	_sync_restricted_warning_line_to_rect(_restricted_placement_warning_line, rect)


func _hide_restricted_placement_warning() -> void:
	if _restricted_placement_warning_tween != null and _restricted_placement_warning_tween.is_valid():
		_restricted_placement_warning_tween.kill()
	_restricted_placement_warning_tween = null

	if _restricted_placement_warning == null:
		return

	_restricted_placement_warning.visible = false
	_restricted_placement_warning.modulate.a = 0.0

	if _restricted_placement_warning_line != null:
		_restricted_placement_warning_line.visible = false


func _cancel_restricted_drop_feedback() -> void:
	_restricted_drop_feedback_token += 1
	_hide_restricted_placement_warning()


func _sync_restricted_warning_line_to_rect(line: Line2D, rect: Rect2) -> void:
	if line == null:
		return

	line.visible = true

	var points := PackedVector2Array([
		to_local(rect.position),
		to_local(rect.position + Vector2(rect.size.x, 0.0)),
		to_local(rect.position + rect.size),
		to_local(rect.position + Vector2(0.0, rect.size.y))
	])
	line.points = points


func _get_carry_shelf_blocker_position() -> Vector2:
	if counter_pos != null:
		return counter_pos.global_position + CARRY_SHELF_CASHIER_BLOCKER_OFFSET

	if cashier != null:
		return cashier.global_position + Vector2(0, 20)

	return Vector2(96, 142)


func _update_player_depth_override() -> void:
	if player == null:
		player = get_node_or_null("Player") as Node2D

	if cashier == null:
		cashier = get_node_or_null("Cashier") as Node2D

	if player == null or cashier == null:
		return

	var is_behind_depth_object: bool = _is_player_behind_depth_object(
		cashier,
		CASHIER_DEPTH_HALF_WIDTH,
		CASHIER_DEPTH_BACK_OFFSET,
		CASHIER_DEPTH_FRONT_OFFSET
	)

	if not is_behind_depth_object:
		for shelf in get_tree().get_nodes_in_group("shelves"):
			if shelf is Node2D and _is_descendant_of(shelf, self):
				is_behind_depth_object = _is_player_behind_depth_object(
					shelf as Node2D,
					SHELF_DEPTH_HALF_WIDTH,
					SHELF_DEPTH_BACK_OFFSET,
					SHELF_DEPTH_FRONT_OFFSET
				)

				if is_behind_depth_object:
					break

	player.z_index = -1 if is_behind_depth_object else 0


func _is_player_behind_depth_object(
	object: Node2D,
	half_width: float,
	back_offset: float,
	front_offset: float
) -> bool:
	return StoreShelfController.is_player_behind_depth_object(
		player,
		object,
		half_width,
		back_offset,
		front_offset
	)


func _register_installed_shelf(object: Node2D) -> void:
	if object == null:
		return

	if not object.is_in_group("shelves"):
		object.add_to_group("shelves")

	if object.name == "ShelfHuman" and object is Shelf:
		_human_shelf_installed = true
		human_shelf = object as Shelf

		_connect_human_shelf_signals(human_shelf)
		_set_human_stock_count(_get_shelf_stock_count(human_shelf))
		_update_objective()
		_show_task_complete_notice("human_shelf_placed", "Human Shelf placed.")

		if _human_items_placed < NORMAL_STOCK_REQUIRED:
			_show_notification("Now stock the human shelf with normal items.", 3.0)

	if object.name == "ShelfGhost" and object is Shelf:
		_ghost_shelf_installed = true
		ghost_shelf = object as Shelf

		if not ghost_shelf.item_placed.is_connected(_on_ghost_shelf_item_placed):
			ghost_shelf.item_placed.connect(_on_ghost_shelf_item_placed)

		ghost_shelf.apply_ghost_glow(true)
		_check_customer_spawning_ready()
		_update_objective()
		_show_task_complete_notice("ghost_shelf_placed", "Ghost Shelf placed.")

	_setup_npc_static_data()


func _register_human_stock_progress() -> void:
	_set_human_stock_count(_human_items_placed + 1)


func _connect_human_shelf_signals(shelf: Shelf) -> void:
	if shelf == null:
		return

	if not shelf.item_placed.is_connected(_on_human_shelf_item_placed):
		shelf.item_placed.connect(_on_human_shelf_item_placed)

	if not shelf.item_removed.is_connected(_on_human_shelf_item_removed):
		shelf.item_removed.connect(_on_human_shelf_item_removed)


func _set_human_stock_count(stock_count: int) -> void:
	_human_items_placed = clampi(stock_count, 0, NORMAL_STOCK_REQUIRED)

	if _human_items_placed >= NORMAL_STOCK_REQUIRED:
		_show_task_complete_notice("human_shelf_stocked", "Human Shelf stocked.")

	if not StoreProgressionController.can_unlock_mystery_phase(
		_human_items_placed,
		NORMAL_STOCK_REQUIRED,
		_human_shelf_installed,
		_mystery_phase_unlocked
	):
		return

	_mystery_phase_unlocked = true
	_show_notification("The dark corner in storage just opened.", 3.0)
	_update_objective()

	if _current_storage != null and _current_storage.has_method("set_mystery_phase_unlocked"):
		_current_storage.set_mystery_phase_unlocked(true)


func _set_store_world_active(is_active: bool) -> void:
	if not is_active:
		_cancel_restricted_drop_feedback()
		_close_cashier_runtime_ui()

	for child in get_children():
		if (
			child == _current_storage
			or child == _current_yard
			or child == _fade_layer
			or child == _location_title_layer
			or child == _carry_shelf_blocker
			or child == player
		):
			continue

		if child.name == "HUD":
			continue

		_set_node_active_recursive(child, is_active)


func _set_node_active_recursive(node: Node, is_active: bool) -> void:
	StoreTransitionController.set_node_active_recursive(node, is_active)


func _set_node_enabled_recursive(node: Node, enabled: bool) -> void:
	StoreTransitionController.set_node_enabled_recursive(node, enabled)


func _create_fade_layer() -> void:
	var fade_nodes := StoreTransitionController.create_fade_layer(self)
	_fade_layer = fade_nodes["layer"] as CanvasLayer
	_fade_rect = fade_nodes["rect"] as ColorRect


func _create_location_title_layer() -> void:
	_location_title_layer = CanvasLayer.new()
	_location_title_layer.name = "LocationTitleLayer"
	_location_title_layer.layer = 24
	add_child(_location_title_layer)

	var panel := ColorRect.new()
	panel.name = "LocationTitlePanel"
	panel.color = Color(0.06, 0.05, 0.05, 0.72)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -88.0
	panel.offset_top = -18.0
	panel.offset_right = 88.0
	panel.offset_bottom = 18.0
	panel.modulate.a = 0.0
	_location_title_layer.add_child(panel)

	_location_title_label = Label.new()
	_location_title_label.name = "LocationTitleLabel"
	_location_title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_location_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_location_title_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(_location_title_label)


func _show_location_title_once(location_key: String, title: String) -> void:
	if _shown_location_titles.has(location_key):
		return

	_shown_location_titles[location_key] = true
	_show_location_title(title)


func _show_location_title(title: String) -> void:
	if _location_title_layer == null or _location_title_label == null:
		return

	var panel := _location_title_label.get_parent() as Control

	if panel == null:
		return

	if _location_title_tween != null and _location_title_tween.is_valid():
		_location_title_tween.kill()

	_location_title_label.text = title
	panel.visible = true
	panel.modulate.a = 0.0
	panel.position.y = 8.0

	_location_title_tween = create_tween()
	_location_title_tween.set_parallel(true)
	_location_title_tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	_location_title_tween.tween_property(panel, "position:y", 0.0, 0.18)
	_location_title_tween.set_parallel(false)
	_location_title_tween.tween_interval(LOCATION_TITLE_DURATION)
	_location_title_tween.tween_property(panel, "modulate:a", 0.0, 0.28)


func _fade_to_black() -> void:
	await StoreTransitionController.fade_to(self, _fade_rect, 1.0)


func _fade_from_black() -> void:
	await StoreTransitionController.fade_to(self, _fade_rect, 0.0)


func _setup_npc_static_data() -> void:
	if npc_queue_marker != null:
		NPC.counter_position = npc_queue_marker.global_position
	elif counter_pos != null:
		NPC.counter_position = counter_pos.global_position

	if entrance_pos != null:
		NPC.entrance_position = entrance_pos.global_position

	if npc_exit_marker != null:
		NPC.exit_position = npc_exit_marker.global_position
	elif entrance_pos != null:
		NPC.exit_position = entrance_pos.global_position

	if npc_store_path_marker != null:
		NPC.store_path_position = npc_store_path_marker.global_position
	else:
		NPC.store_path_position = Vector2.INF


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	return StoreShelfController.is_descendant_of(node, ancestor)


func _close_cashier_runtime_ui() -> void:
	if cashier == null:
		cashier = get_node_or_null("Cashier") as Node2D

	if cashier != null and cashier.has_method("reset_runtime_ui"):
		cashier.call("reset_runtime_ui")


func _connect_cursor_tooltip(area: Area2D, tooltip_text: String) -> void:
	if area == null:
		return

	area.input_pickable = true
	var entered := Callable(self, "_on_cursor_tooltip_entered").bind(tooltip_text)
	var exited := Callable(self, "_on_cursor_tooltip_exited")

	if not area.mouse_entered.is_connected(entered):
		area.mouse_entered.connect(entered)

	if not area.mouse_exited.is_connected(exited):
		area.mouse_exited.connect(exited)


func _on_cursor_tooltip_entered(tooltip_text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", tooltip_text)


func _on_cursor_tooltip_exited() -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")


func _on_npc_spawn_requested(npc_data: NPCData) -> void:
	StoreNpcSpawner.spawn_npc(
		self,
		npc_scene,
		npc_entry_marker if npc_entry_marker != null else entrance_pos,
		npc_data,
		_on_npc_purchase,
		_on_npc_exited
	)


func _on_npc_purchase(_npc: NPC, _item_id: String, price: int) -> void:
	EconomyManager.add_gold(price)

	if price > 0:
		_show_task_complete_notice("normal_customer_served", "First customer served.")


func _on_npc_exited(_npc: NPC) -> void:
	pass


func _on_phase_changed(phase) -> void:
	match phase:
		TimeManager.Phase.DAY:
			if _is_day_setup_complete():
				if _suppress_next_day_open_notification:
					_suppress_next_day_open_notification = false
				else:
					_show_customer_open_notification()
			else:
				_show_notification("Finish setting up before customers arrive.", 3.0)
		TimeManager.Phase.NIGHT:
			_close_store_for_day()
			if _customer_spawning_unlocked:
				_show_notification("Night falls. Strange customers may arrive.", 3.0)
			else:
				_show_notification("Night falls, but the ghost shelf is not ready.", 3.0)
	_update_objective()


func _on_target_reached() -> void:
	_show_notification("Daily target achieved.", 2.5)


func _on_daily_report(report: Dictionary) -> void:
	print("=== DAY %d REPORT ===" % report.day)
	print("Revenue: %dG" % report.revenue)
	print("Tax: %dG" % report.tax)
	print("Net Profit: %dG" % report.net_profit)
	print("Total Gold: %dG" % report.total_gold)
	print("Target: %s" % ("REACHED" if report.target_reached else "MISSED"))

	EconomyManager.pay_tax()
	TimeManager.end_day_sequence()


func _on_day_ended(_day: int) -> void:
	_show_notification("Close the store and rest for the night.", 3.0)


func _on_day_started(_day: int) -> void:
	_store_open = false
	_store_opened_today = false
	_store_closed_for_day = false
	_customer_open_notification_shown = false
	NPCScheduler.set_store_open(false)
	NPCScheduler.stop_normal_customer_spawning()
	_update_store_status_board(false)

	if not _pending_store_intro_after_yard:
		_update_objective()


func _on_human_shelf_item_placed(_slot_index: int, item_id: String) -> void:
	var item := ItemDatabase.get_item(item_id)

	if item != null and item.shelf_type == ItemData.ShelfType.HUMAN:
		_set_human_stock_count(_get_shelf_stock_count(human_shelf))
		_update_objective()


func _on_human_shelf_item_removed(_slot_index: int, item_id: String) -> void:
	var item := ItemDatabase.get_item(item_id)

	if item != null and item.shelf_type == ItemData.ShelfType.HUMAN:
		_set_human_stock_count(_get_shelf_stock_count(human_shelf))
		_update_objective()


func _on_ghost_shelf_item_placed(_slot_index: int, item_id: String) -> void:
	var item := ItemDatabase.get_item(item_id)

	if item == null or item.shelf_type != ItemData.ShelfType.GHOST:
		return

	var became_ready := _check_customer_spawning_ready(false)
	_update_objective()
	_show_task_complete_notice("ghost_shelf_stocked", "Ghost Shelf stocked.")

	if _ghost_shelf_lesson_shown:
		if became_ready:
			_show_customer_open_notification()
			_update_objective()
		return

	_ghost_shelf_lesson_shown = true
	await _show_notification_sequence([
		"Huh... so it only stays on this shelf?",
		"This shelf looks different too...",
		"What was Grandma keeping here?"
	])

	if became_ready:
		_show_customer_open_notification()


func _check_customer_spawning_ready(show_notice: bool = true) -> bool:
	if not StoreProgressionController.can_unlock_customer_spawning(
		_customer_spawning_unlocked,
		_ghost_shelf_installed,
		ghost_shelf
	):
		return false

	if _customer_spawning_unlocked:
		return true

	_customer_spawning_unlocked = true
	_gooby_resolved = false

	var should_start_day_one_customers_now := StoreProgressionController.should_start_day_one_customers_now()

	if show_notice:
		_show_customer_open_notification()
	else:
		_suppress_next_day_open_notification = should_start_day_one_customers_now

	NPCScheduler.unlock_spawning_now(false)
	_update_objective()
	return true


func _show_customer_open_notification() -> void:
	if _customer_open_notification_shown:
		return

	_customer_open_notification_shown = true
	_show_notification("Store setup is ready. Flip the OPEN board when you want customers.", 2.5)
	_update_objective()


func _update_objective() -> void:
	var objective_text := _get_current_objective_text()

	if objective_text == _last_objective_text:
		return

	_last_objective_text = objective_text

	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", objective_text)


func _get_current_objective_text() -> String:
	if _gooby_resolved:
		return "Wait for the next strange customer."

	if TimeManager.current_phase == TimeManager.Phase.NIGHT and _customer_spawning_unlocked:
		return "Serve Gooby at the cashier."

	if not _human_shelf_installed:
		return "Bring the human shelf from storage."

	if _human_items_placed < NORMAL_STOCK_REQUIRED:
		return "Stock the human shelf with normal items."

	if not _store_open and not _store_closed_for_day:
		return "Flip the OPEN board when ready."

	if not _mystery_phase_unlocked or not _mystery_discovered:
		return "Check the dark storage corner."

	if not _ghost_shelf_installed:
		return "Place the ghost shelf in the store."

	if ghost_shelf == null or not ghost_shelf.has_stock():
		return "Stock Phantom Ice Cream on ghost shelf."

	if not _is_day_setup_complete():
		return "Prepare the store for customers."

	if _store_closed_for_day:
		return "Store closed. Prepare for night."

	return "Serve customers at the cashier."


func _show_notification(text: String, duration: float = 2.0) -> void:
	StoreNotificationBridge.show(get_tree(), text, duration)


func _show_status_notification(text: String, duration: float = 1.0) -> void:
	StoreNotificationBridge.show(get_tree(), text, duration, false)


func _show_task_complete_notice(key: String, message: String) -> void:
	if _completed_task_notices.has(key):
		return

	_completed_task_notices[key] = true

	var hud := get_tree().get_first_node_in_group("hud")
	var text := "Task Complete! %s Check the Activity Board." % message

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, 2.2, false)

	ActivityCompletionManager.notify(message)

	var activity_board := get_node_or_null("ActivityBoard")

	if activity_board != null and activity_board.has_method("play_completion_glow"):
		activity_board.call("play_completion_glow")


func _show_notification_sequence(messages: Array[String]) -> void:
	await StoreNotificationBridge.show_sequence(self, messages)


func _get_shelf_stock_count(shelf: Shelf) -> int:
	return StoreShelfController.get_shelf_stock_count(shelf)
