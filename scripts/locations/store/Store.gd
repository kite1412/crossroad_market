class_name Store
extends Node2D


const StoreSimulationSchedulerScript = preload("res://scripts/locations/store/StoreSimulationScheduler.gd")
const NPCPathRequestServiceScript = preload("res://scripts/npc/runtime/NPCPathRequestService.gd")
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")

const SHELF_ACCESS_WARMUP_DELAY: float = 1.0
const STORE_ENTRY_FALLBACK_POSITION := Vector2(240, 204)
const STORE_STORAGE_RETURN_FALLBACK_POSITION := Vector2(383, 76)
const RUNTIME_DEBUG_OVERLAY_TOGGLE_KEY: Key = KEY_F9
const RUNTIME_DEBUG_CLEAR_KEY: Key = KEY_F8
const RUNTIME_DEBUG_DUMP_KEY: Key = KEY_F10

var npc_scene: PackedScene = preload("res://scenes/npc/NPC.tscn")
var storage_scene: PackedScene = preload("res://scenes/locations/Storage.tscn")
var yard_scene: PackedScene = preload("res://scenes/locations/Yard.tscn")
var home_scene: PackedScene = preload("res://scenes/locations/Home.tscn")

@export var shelf_placement_fallback_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(48, 86),
	Vector2(458, 86),
	Vector2(458, 236),
	Vector2(48, 236)
])
@export_range(4.0, 48.0, 1.0) var shelf_placement_fallback_spacing: float = 18.0

@onready var counter_pos: Marker2D = get_node_or_null("CounterPos") as Marker2D
@onready var entrance_pos: Marker2D = get_node_or_null("EntrancePos") as Marker2D
@onready var store_path_markers: Node2D = get_node_or_null("StorePathMarkers") as Node2D
@onready var npc_entry_marker: Marker2D = _get_store_path_marker_by_role(&"entry", NodePath("StorePathMarkers/StorePathEntry"), NodePath("NPCEntryMarker"))
@onready var npc_enter_store_marker: Marker2D = _get_store_path_marker_by_role(&"enter_store", NodePath("StorePathMarkers/StorePathEnterStore"), NodePath("NPCEnterStoreMarker"))
@onready var npc_exit_marker: Marker2D = _get_store_path_marker_by_role(&"exit", NodePath("StorePathMarkers/StorePathExit"), NodePath("NPCExitMarker"))
@onready var npc_store_path_marker: Marker2D = _get_store_path_marker_by_role(&"aisle_right", NodePath("StorePathMarkers/StorePathAisleRight"), NodePath("NPCStorePathMarker"))
@onready var npc_path_cashier_marker: Marker2D = _get_store_path_marker_by_role(&"cashier", NodePath("StorePathMarkers/StorePathCashier"), NodePath("StorePathCashier"))
@onready var npc_queue_marker: Marker2D = _get_store_path_marker_by_role(&"queue_front", NodePath("StorePathMarkers/StorePathQueueFront"), NodePath("StorePathQueueMarker"))
@onready var customer_path_zones: Node2D = get_node_or_null("CustomerPathZones") as Node2D
@onready var storage_door: Area2D = get_node_or_null("StorageDoor") as Area2D
@onready var storage_return_pos: Marker2D = _get_store_path_marker_by_role(&"storage_return", NodePath("StorePathMarkers/StorePathStorageReturn"), NodePath("StorageReturnPos"))
@onready var yard_door: Area2D = get_node_or_null("YardDoor") as Area2D
@onready var store_entry_pos: Marker2D = get_node_or_null("StoreEntryPos") as Marker2D
@onready var player: Node2D = get_node_or_null("Player") as Node2D
@onready var cashier: Node2D = get_node_or_null("Cashier") as Node2D
@onready var open_close_board: Node = get_node_or_null("OpenCloseBoard")
@onready var location_flow: Node = get_node_or_null("LocationFlow")
@onready var tax_flow: Node = get_node_or_null("TaxFlow")
@onready var shelf_placement_controller: Node = get_node_or_null("ShelfPlacementController")
@onready var progression_flow: Node = get_node_or_null("ProgressionFlow")
@onready var npc_runtime: Node = get_node_or_null("NpcRuntime")
@onready var presentation: Node = get_node_or_null("Presentation")
@onready var open_close_controller: Node = get_node_or_null("OpenCloseController")
@onready var day_runtime: Node = get_node_or_null("DayRuntime")
@onready var task_completion: Node = get_node_or_null("TaskCompletion")
@onready var npc_routes: Node = get_node_or_null("NpcRoutes")
@onready var world_state_controller: Node = get_node_or_null("WorldStateController")
@onready var npc_interaction_runtime: Node = get_node_or_null("NpcInteractionRuntime")
@onready var story_runtime: Node = get_node_or_null("StoryRuntime")

@warning_ignore("unused_private_class_variable")
var _current_storage: Node2D = null
@warning_ignore("unused_private_class_variable")
var _current_yard: Node2D = null
@warning_ignore("unused_private_class_variable")
var _current_home: Node2D = null
@warning_ignore("unused_private_class_variable")
var _fade_layer: CanvasLayer = null
@warning_ignore("unused_private_class_variable")
var _fade_rect: ColorRect = null
var _runtime_debug_overlay_layer: CanvasLayer = null
var _runtime_debug_overlay_background: ColorRect = null
var _runtime_debug_overlay_label: Label = null
var _runtime_debug_overlay_visible: bool = false
var _runtime_debug_overlay_key_was_pressed: bool = false
var _runtime_debug_clear_key_was_pressed: bool = false
var _runtime_debug_dump_key_was_pressed: bool = false
var _runtime_debug_last_dump_path: String = ""
var _runtime_debug_last_dump_count: int = 0
@warning_ignore("unused_private_class_variable")
var _location_title_layer: CanvasLayer = null
@warning_ignore("unused_private_class_variable")
var _location_title_label: Label = null
@warning_ignore("unused_private_class_variable")
var _location_title_tween: Tween = null
@warning_ignore("unused_private_class_variable")
var _carry_shelf_blocker: StaticBody2D = null
@warning_ignore("unused_private_class_variable")
var _carry_shelf_blocker_shape: CollisionShape2D = null
@warning_ignore("unused_private_class_variable")
var _restricted_placement_warning: Node2D = null
@warning_ignore("unused_private_class_variable")
var _restricted_placement_warning_line: Line2D = null
@warning_ignore("unused_private_class_variable")
var _restricted_placement_warning_tween: Tween = null
@warning_ignore("unused_private_class_variable")
var _store_path_graph: StorePathGraph = null
@warning_ignore("unused_private_class_variable")
var _simulation_scheduler: RefCounted = null
@warning_ignore("unused_private_class_variable")
var _placement_grid: StorePlacementGrid = null
@warning_ignore("unused_private_class_variable")
var _placement_surface: Node = null
@warning_ignore("unused_private_class_variable")
var _placement_surface_anchor_cache: Array[Vector2] = []
@warning_ignore("unused_private_class_variable")
var _shelf_access_metadata_update_token: int = 0
@warning_ignore("unused_private_class_variable")
var _shelf_access_warmup_token: int = 0
var _has_navigation_dirty_bounds: bool = false
var _navigation_dirty_bounds: Rect2 = Rect2()
@warning_ignore("unused_private_class_variable")
var _is_transitioning: bool = false
@warning_ignore("unused_private_class_variable")
var _is_store_world_active: bool = true
@warning_ignore("unused_private_class_variable")
var _shown_location_titles: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _completed_task_notices: Dictionary = {}

@warning_ignore("unused_private_class_variable")
var _normal_items_taken: int = 0
@warning_ignore("unused_private_class_variable")
var _human_items_placed: int = 0
@warning_ignore("unused_private_class_variable")
var _normal_supply_depleted: bool = false
@warning_ignore("unused_private_class_variable")
var _mystery_phase_unlocked: bool = false
@warning_ignore("unused_private_class_variable")
var _mystery_discovered: bool = false
@warning_ignore("unused_private_class_variable")
var _mystery_supply_depleted: bool = false
@warning_ignore("unused_private_class_variable")
var _mystery_items_taken: Array[String] = []
@warning_ignore("unused_private_class_variable")
var _phantom_human_shelf_attempted: bool = false
@warning_ignore("unused_private_class_variable")
var _human_shelf_installed: bool = false
@warning_ignore("unused_private_class_variable")
var _ghost_shelf_installed: bool = false
@warning_ignore("unused_private_class_variable")
var _customer_spawning_unlocked: bool = false
@warning_ignore("unused_private_class_variable")
var _store_open: bool = false
@warning_ignore("unused_private_class_variable")
var _store_opened_today: bool = false
@warning_ignore("unused_private_class_variable")
var _customer_open_notification_shown: bool = false
@warning_ignore("unused_private_class_variable")
var _suppress_next_day_open_notification: bool = false
@warning_ignore("unused_private_class_variable")
var _intro_shown: bool = false
@warning_ignore("unused_private_class_variable")
var _yard_intro_shown: bool = false
@warning_ignore("unused_private_class_variable")
var _pending_store_intro_after_yard: bool = true
@warning_ignore("unused_private_class_variable")
var _first_activity_board_shown: bool = false
@warning_ignore("unused_private_class_variable")
var _ghost_shelf_lesson_shown: bool = false
@warning_ignore("unused_private_class_variable")
var _gooby_resolved: bool = false
@warning_ignore("unused_private_class_variable")
var _last_objective_text: String = ""
@warning_ignore("unused_private_class_variable")
var _restricted_drop_feedback_token: int = 0
@warning_ignore("unused_private_class_variable")
var _pending_restock_deliveries: Array[Dictionary] = []
@warning_ignore("unused_private_class_variable")
var _restock_delivery_counter: int = 0
@warning_ignore("unused_private_class_variable")
var _restock_ordered_today: bool = false
@warning_ignore("unused_private_class_variable")
var _restock_panel_open: bool = false
@warning_ignore("unused_private_class_variable")
var _tax_waiting_for_restock_close: bool = false
@warning_ignore("unused_private_class_variable")
var _tax_ready_after_restock_close: bool = false
@warning_ignore("unused_private_class_variable")
var _tax_restock_close_ready_at_msec: int = 0
@warning_ignore("unused_private_class_variable")
var _tax_restock_retry_token: int = 0
@warning_ignore("unused_private_class_variable")
var _tax_pending: bool = false
@warning_ignore("unused_private_class_variable")
var _tax_paid_today: bool = false
@warning_ignore("unused_private_class_variable")
var _tax_ignored_today: bool = false
@warning_ignore("unused_private_class_variable")
var _tax_notice_active: bool = false
@warning_ignore("unused_private_class_variable")
var _tax_home_warning_shown: bool = false
@warning_ignore("unused_private_class_variable")
var _tax_panel_showing: bool = false
@warning_ignore("unused_private_class_variable")
var _end_day_transition_started: bool = false
@warning_ignore("unused_private_class_variable")
var _latest_daily_report: Dictionary = {}

var human_shelf: Shelf = null
var ghost_shelf: Shelf = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	add_to_group("store")
	_placement_grid = StorePlacementGrid.new(
		shelf_placement_fallback_polygon,
		shelf_placement_fallback_spacing
	)
	_simulation_scheduler = StoreSimulationSchedulerScript.new()
	_placement_surface = get_node_or_null("StorePlacementSurface")
	_store_path_graph = StorePathGraph.new(self, store_path_markers)

	_setup_store_controllers()
	_connect_manager_signals()
	_connect_scene_signals()
	_set_customer_path_visual_visible(false)
	_update_store_status_board(false)
	_create_fade_layer()
	_create_location_title_layer()
	_create_carry_shelf_blocker()
	_create_restricted_placement_warning()
	_setup_npc_static_data()
	_schedule_shelf_access_warmup(0.8)
	NPC.current_queue.clear()
	NPCScheduler.lock_spawning_until_ready()

	TimeManager.start_game()
	call_deferred("_start_game_in_yard")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_store_controllers() -> void:
	for controller in [
		location_flow,
		tax_flow,
		shelf_placement_controller,
		progression_flow,
		npc_runtime,
		presentation,
		open_close_controller,
		day_runtime,
		task_completion,
		npc_routes,
		world_state_controller,
		npc_interaction_runtime,
		story_runtime
	]:
		if controller != null and controller.has_method("setup"):
			controller.call("setup", self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process(_delta: float) -> void:
	_update_end_day_tax_flow()
	_flush_navigation_dirty_bounds()
	_process_simulation_scheduler()
	NPCPathRequestServiceScript.tick()
	_update_runtime_debug_overlay()

	if world_state_controller != null:
		world_state_controller.process_store_world(_delta)

	if npc_runtime != null and npc_runtime.has_method("process_npc_runtime"):
		npc_runtime.process_npc_runtime(_delta)

	if npc_interaction_runtime != null:
		npc_interaction_runtime.process_npc_interactions(_delta)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func enqueue_simulation_job(
	execute_step: Callable,
	priority: StringName = &"normal",
	label: StringName = &"job"
) -> void:
	if _simulation_scheduler == null:
		_simulation_scheduler = StoreSimulationSchedulerScript.new()
	_simulation_scheduler.enqueue(execute_step, priority, label)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process_simulation_scheduler() -> void:
	if _simulation_scheduler == null:
		return
	_simulation_scheduler.tick()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_runtime_debug_events() -> Array[Dictionary]:
	return StoreRuntimeDebugProbeScript.get_events()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_runtime_debug_summary() -> Dictionary:
	return StoreRuntimeDebugProbeScript.get_summary()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_runtime_debug_overlay() -> void:
	var key_pressed := Input.is_key_pressed(RUNTIME_DEBUG_OVERLAY_TOGGLE_KEY)
	if key_pressed and not _runtime_debug_overlay_key_was_pressed:
		_runtime_debug_overlay_visible = not _runtime_debug_overlay_visible
		_ensure_runtime_debug_overlay()
		_runtime_debug_overlay_layer.visible = _runtime_debug_overlay_visible

	_runtime_debug_overlay_key_was_pressed = key_pressed
	var clear_key_pressed := Input.is_key_pressed(RUNTIME_DEBUG_CLEAR_KEY)
	if clear_key_pressed and not _runtime_debug_clear_key_was_pressed:
		StoreRuntimeDebugProbeScript.clear()

	_runtime_debug_clear_key_was_pressed = clear_key_pressed
	var dump_key_pressed := Input.is_key_pressed(RUNTIME_DEBUG_DUMP_KEY)
	if dump_key_pressed and not _runtime_debug_dump_key_was_pressed:
		_dump_runtime_debug_events_to_file()

	_runtime_debug_dump_key_was_pressed = dump_key_pressed

	if not _runtime_debug_overlay_visible:
		return

	_ensure_runtime_debug_overlay()
	_runtime_debug_overlay_label.text = _format_runtime_debug_overlay_text()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ensure_runtime_debug_overlay() -> void:
	if _runtime_debug_overlay_layer != null:
		return

	_runtime_debug_overlay_layer = CanvasLayer.new()
	_runtime_debug_overlay_layer.name = "RuntimeDebugOverlay"
	_runtime_debug_overlay_layer.layer = 120
	_runtime_debug_overlay_layer.visible = _runtime_debug_overlay_visible
	add_child(_runtime_debug_overlay_layer)

	_runtime_debug_overlay_background = ColorRect.new()
	_runtime_debug_overlay_background.name = "Background"
	_runtime_debug_overlay_background.color = Color(0.0, 0.0, 0.0, 0.72)
	_runtime_debug_overlay_background.position = Vector2(8, 8)
	_runtime_debug_overlay_background.size = Vector2(420, 180)
	_runtime_debug_overlay_layer.add_child(_runtime_debug_overlay_background)

	_runtime_debug_overlay_label = Label.new()
	_runtime_debug_overlay_label.name = "Summary"
	_runtime_debug_overlay_label.position = Vector2(16, 14)
	_runtime_debug_overlay_label.size = Vector2(404, 168)
	_runtime_debug_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_runtime_debug_overlay_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.98, 1.0, 1.0)
	)
	_runtime_debug_overlay_label.add_theme_font_size_override("font_size", 12)
	_runtime_debug_overlay_layer.add_child(_runtime_debug_overlay_label)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _format_runtime_debug_overlay_text() -> String:
	var summary: Dictionary = StoreRuntimeDebugProbeScript.get_summary()
	var events: Array[Dictionary] = StoreRuntimeDebugProbeScript.get_events()
	var lines: Array[String] = [
		"Runtime Debug Probe (F9 show, F8 clear, F10 dump)",
		"events: %d enabled: %s" % [
			int(summary.get("event_count", 0)),
			str(summary.get("enabled", false))
		]
	]
	if _runtime_debug_last_dump_path != "":
		lines.append("dumped %d: %s" % [
			_runtime_debug_last_dump_count,
			_runtime_debug_last_dump_path
		])

	var max_elapsed: Dictionary = summary.get("max_elapsed_msec", {})
	for label in max_elapsed.keys():
		lines.append("%s max %.2f ms" % [
			str(label),
			float(max_elapsed[label])
		])

	if events.is_empty():
		lines.append("No spike above threshold yet.")
		return "\n".join(lines)

	lines.append("Recent:")
	var start_index: int = maxi(0, events.size() - 4)
	for i in range(start_index, events.size()):
		var event: Dictionary = events[i]
		lines.append("%s %.2f ms %s" % [
			str(event.get("label", &"unknown")),
			float(event.get("elapsed_msec", 0.0)),
			str(event.get("context", {}))
		])

	return "\n".join(lines)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _dump_runtime_debug_events_to_file() -> void:
	var events: Array[Dictionary] = StoreRuntimeDebugProbeScript.get_events()
	var timestamp := Time.get_datetime_string_from_system(false, true)
	timestamp = timestamp.replace(":", "-").replace(" ", "_")
	var user_path := "user://store_runtime_debug_%s.jsonl" % timestamp
	var file := FileAccess.open(user_path, FileAccess.WRITE)
	if file == null:
		_runtime_debug_last_dump_path = "failed error=%d" % FileAccess.get_open_error()
		_runtime_debug_last_dump_count = 0
		return

	for event in events:
		file.store_line(JSON.stringify(_normalize_runtime_debug_value(event)))

	_runtime_debug_last_dump_count = events.size()
	_runtime_debug_last_dump_path = ProjectSettings.globalize_path(user_path)


func _normalize_runtime_debug_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var normalized: Dictionary = {}
			var value_dictionary: Dictionary = value
			for key in value_dictionary.keys():
				normalized[str(key)] = _normalize_runtime_debug_value(
					value_dictionary[key]
				)
			return normalized
		TYPE_ARRAY:
			var normalized_array: Array = []
			var value_array: Array = value
			for item in value_array:
				normalized_array.append(_normalize_runtime_debug_value(item))
			return normalized_array
		TYPE_VECTOR2:
			var vector_value: Vector2 = value
			return {
				"x": snappedf(vector_value.x, 0.01),
				"y": snappedf(vector_value.y, 0.01)
			}
		TYPE_STRING_NAME:
			return str(value)
		_:
			return value


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_navigation_dirty(bounds: Rect2) -> void:
	if not bounds.has_area():
		return

	if _has_navigation_dirty_bounds:
		_navigation_dirty_bounds = _navigation_dirty_bounds.merge(bounds)
	else:
		_navigation_dirty_bounds = bounds
		_has_navigation_dirty_bounds = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _flush_navigation_dirty_bounds() -> void:
	if not _has_navigation_dirty_bounds:
		return

	var dirty_bounds := _navigation_dirty_bounds
	_navigation_dirty_bounds = Rect2()
	_has_navigation_dirty_bounds = false

	for npc_node in get_tree().get_nodes_in_group("npcs"):
		if npc_node == null or not is_instance_valid(npc_node):
			continue

		if _is_npc_route_affected_by_bounds(npc_node, dirty_bounds):
			npc_node.set_meta(&"path_possibly_invalid", true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_npc_route_affected_by_bounds(npc_node: Node, bounds: Rect2) -> bool:
	if not (npc_node is Node2D):
		return false

	var route_variant: Variant = npc_node.get("_movement_route")
	if not route_variant is Array:
		return false

	var route := route_variant as Array
	if route.is_empty():
		return false

	var route_bounds := Rect2((npc_node as Node2D).global_position, Vector2.ONE)
	for point_variant in route:
		if point_variant is Vector2:
			route_bounds = route_bounds.expand(point_variant as Vector2)

	return route_bounds.grow(16.0).intersects(bounds)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_enter_storage(_door_type: String = "storage") -> void:
	if _is_transitioning or _current_storage != null:
		return

	await _enter_storage()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_enter_yard(_door_type: String = "yard") -> void:
	if _is_transitioning or _current_yard != null:
		return

	await _enter_yard()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_normal_item_taken() -> void:
	if day_runtime != null:
		day_runtime.on_normal_item_taken()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_human_item_placed() -> void:
	if day_runtime != null:
		day_runtime.on_human_item_placed()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_shelf_type_installed(shelf_type: ItemData.ShelfType) -> bool:
	match shelf_type:
		ItemData.ShelfType.HUMAN:
			return _human_shelf_installed
		ItemData.ShelfType.GHOST:
			return _ghost_shelf_installed

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_toggle_store_open() -> void:
	if open_close_controller != null:
		open_close_controller.request_toggle_store_open()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func can_player_sleep() -> Dictionary:
	if day_runtime != null:
		return day_runtime.can_player_sleep()

	return {"allowed": false, "message": ""}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_day_setup_complete() -> bool:
	return open_close_controller != null and open_close_controller.is_day_setup_complete()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _open_store() -> void:
	if open_close_controller != null:
		open_close_controller.open_store()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _close_store() -> void:
	if open_close_controller != null:
		open_close_controller.close_store()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_store_status_board(animated: bool = true) -> void:
	if open_close_controller != null:
		open_close_controller.update_store_status_board(animated)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_open_close_board() -> Node:
	if open_close_controller != null:
		return open_close_controller.get_open_close_board()

	return open_close_board


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_entry_route_to_shelf(shelf_position: Vector2, from_position: Vector2 = Vector2.INF) -> Array[Vector2]:
	if npc_routes != null:
		return npc_routes.get_npc_entry_route_to_shelf(shelf_position, from_position)

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_shelf_access_position(shelf: Shelf) -> Vector2:
	if npc_routes != null:
		return npc_routes.get_npc_shelf_access_position(shelf)

	return Vector2.INF


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_shelf_visit_position(shelf: Shelf, _npc: Node = null) -> Vector2:
	if npc_routes != null:
		return npc_routes.get_npc_shelf_visit_position(shelf, _npc)

	return shelf.global_position + Vector2(0, 34) if shelf != null else Vector2.INF


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_npc_shelf_access_metadata(shelf: Shelf) -> bool:
	return npc_routes != null and npc_routes.has_npc_shelf_access_metadata(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_route_to_shelf_access(shelf: Shelf, from_position: Vector2 = Vector2.INF, npc_node: Node = null) -> Array[Vector2]:
	if npc_routes != null:
		return npc_routes.get_npc_route_to_shelf_access(shelf, from_position, npc_node)

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_route_to_cashier_from(from_position: Vector2) -> Array[Vector2]:
	if npc_routes != null:
		return npc_routes.get_npc_route_to_cashier_from(from_position)

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_route_to_queue_target_from(from_position: Vector2, queue_index: int) -> Array[Vector2]:
	if npc_routes != null:
		return npc_routes.get_npc_route_to_queue_target_from(from_position, queue_index)

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_shelf_egress_route_to_queue_from(
	shelf: Shelf,
	from_position: Vector2,
	queue_index: int,
	destination: Vector2,
	npc_node: Node = null
) -> Array[Vector2]:
	if npc_routes != null:
		return npc_routes.get_npc_shelf_egress_route_to_queue_from(
			shelf,
			from_position,
			queue_index,
			destination,
			npc_node
		)

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_queue_egress_target(
	queue_index: int,
	fallback_position: Vector2
) -> Vector2:
	if npc_routes != null:
		return npc_routes.get_npc_queue_egress_target(
			queue_index,
			fallback_position
		)

	return fallback_position


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_queue_target(queue_index: int, fallback_position: Vector2) -> Vector2:
	if npc_routes != null:
		return npc_routes.get_npc_queue_target(queue_index, fallback_position)

	return fallback_position


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_cashier_target(fallback_position: Vector2) -> Vector2:
	if npc_routes != null:
		return npc_routes.get_npc_cashier_target(fallback_position)

	return fallback_position


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_route_from_shelf_to_cashier(shelf: Shelf) -> Array[Vector2]:
	if npc_routes != null:
		return npc_routes.get_npc_route_from_shelf_to_cashier(shelf)

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_exit_route_from(from_position: Vector2) -> Array[Vector2]:
	if npc_routes != null:
		return npc_routes.get_npc_exit_route_from(from_position)

	return []

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_shelf_wait_position(index: int = 0) -> Vector2:
	if npc_routes != null:
		return npc_routes.get_npc_shelf_wait_position(index)

	return Vector2.INF



@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_exit_route_from_cashier(from_position: Vector2) -> Array[Vector2]:
	if npc_routes != null:
		return npc_routes.get_npc_exit_route_from_cashier(from_position)

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_checkout_exit_blocking_context(
	waiting_npc: Node,
	queue_index: int
) -> Dictionary:
	if npc_routes != null and npc_routes.has_method(
		"get_npc_checkout_exit_blocking_context"
	):
		return npc_routes.get_npc_checkout_exit_blocking_context(
			waiting_npc,
			queue_index
		)

	return {"blocked": false, "reason": "unavailable"}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_activity_board_guidance() -> Dictionary:
	if progression_flow != null:
		return progression_flow.get_activity_board_guidance()

	return {
		"title": "Today's Work",
		"lines": ["[ ] Pick the Human Shelf at the Storage, and bring it to the Store"]
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_gooby_resolved() -> void:
	if day_runtime != null:
		day_runtime.on_gooby_resolved()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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

	call_deferred("_connect_hud_signals")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _connect_hud_signals() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud := get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_signal("tax_payment_requested"):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var pay_callable := Callable(self, "_on_tax_payment_requested")
	if hud.has_signal("tax_payment_requested") and not hud.is_connected("tax_payment_requested", pay_callable):
		hud.connect("tax_payment_requested", pay_callable)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var ignore_callable := Callable(self, "_on_tax_ignore_requested")
	if hud.has_signal("tax_ignore_requested") and not hud.is_connected("tax_ignore_requested", ignore_callable):
		hud.connect("tax_ignore_requested", ignore_callable)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _connect_scene_signals() -> void:
	if cashier != null and cashier.has_signal("player_exit_dialog_finished"):
		var exit_dialog_callable := Callable(self, "_on_cashier_player_exit_dialog_finished")
		if not cashier.is_connected("player_exit_dialog_finished", exit_dialog_callable):
			cashier.connect("player_exit_dialog_finished", exit_dialog_callable)

	if storage_door == null:
		pass
	else:
		storage_door.set_meta("door_type", "storage")
		_connect_cursor_tooltip(storage_door, "Storage Door")

	if yard_door == null:
		pass
	else:
		yard_door.set_meta("door_type", "yard")
		_connect_cursor_tooltip(yard_door, "Yard Door")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_morning_intro() -> void:
	if progression_flow != null:
		await progression_flow.show_morning_intro()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_first_activity_board() -> void:
	if progression_flow != null:
		progression_flow.show_first_activity_board()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _start_game_in_yard() -> void:
	if location_flow != null:
		location_flow.start_game_in_yard()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_yard_intro() -> void:
	if progression_flow != null:
		await progression_flow.show_yard_intro()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _connect_yard_return_signal() -> void:
	if location_flow != null:
		location_flow.connect_yard_return_signal()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _configure_yard_scene() -> void:
	if location_flow != null:
		location_flow.configure_yard_scene()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _enter_storage() -> void:
	if location_flow != null:
		await location_flow.enter_storage()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_storage_return(_door_type: String) -> void:
	if location_flow != null:
		await location_flow.on_storage_return(_door_type)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _enter_yard() -> void:
	if location_flow != null:
		await location_flow.enter_yard()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_yard_return(_door_type: String) -> void:
	if location_flow != null:
		await location_flow.on_yard_return(_door_type)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_yard_enter_home() -> void:
	if location_flow != null:
		location_flow.on_yard_enter_home()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _enter_home() -> void:
	if location_flow != null:
		await location_flow.enter_home()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_home_return_to_yard(_door_type: String) -> void:
	if location_flow != null:
		location_flow.on_home_return_to_yard(_door_type)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_storage_mystery_discovered() -> void:
	if progression_flow != null:
		progression_flow.on_storage_mystery_discovered()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_storage_mystery_item_taken(item_id: String) -> void:
	if progression_flow != null:
		progression_flow.on_storage_mystery_item_taken(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_storage_mystery_supply_depleted() -> void:
	if progression_flow != null:
		progression_flow.on_storage_mystery_supply_depleted()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _should_prioritize_phantom_for_human_shelf() -> bool:
	return (
		progression_flow != null
		and progression_flow.should_prioritize_phantom_for_human_shelf()
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_phantom_human_shelf_attempted() -> void:
	if progression_flow != null:
		await progression_flow.on_phantom_human_shelf_attempted()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_storage_restock_order_purchased(order_items: Array) -> void:
	if tax_flow != null:
		tax_flow.on_storage_restock_order_purchased(order_items)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_storage_restock_panel_opened() -> void:
	if tax_flow != null:
		tax_flow.on_storage_restock_panel_opened()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_storage_restock_panel_closed(had_checkout: bool = false) -> void:
	if tax_flow != null:
		tax_flow.on_storage_restock_panel_closed(had_checkout)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _schedule_restock_tax_retry() -> void:
	if tax_flow != null:
		tax_flow.schedule_restock_tax_retry()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _defer_restock_tax_retry(retry_token: int) -> void:
	if tax_flow != null:
		await tax_flow.defer_restock_tax_retry(retry_token)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _should_continue_restock_tax_retry() -> bool:
	return tax_flow != null and tax_flow.should_continue_restock_tax_retry()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_storage_restock_item_purchased(item_id: String, quantity: int) -> void:
	if tax_flow != null:
		tax_flow.on_storage_restock_item_purchased(item_id, quantity)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _duplicate_restock_items(order_items: Array) -> Array[Dictionary]:
	if tax_flow == null:
		return []

	return tax_flow.duplicate_restock_items(order_items)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_yard_restock_delivery_collected(delivery_id: int) -> void:
	if tax_flow != null:
		tax_flow.on_yard_restock_delivery_collected(delivery_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _sync_restock_deliveries_to_yard() -> void:
	if tax_flow != null:
		tax_flow.sync_restock_deliveries_to_yard()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_end_day_tax_flow() -> void:
	if tax_flow != null:
		tax_flow.update_end_day_tax_flow()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _try_show_tax_panel() -> bool:
	return tax_flow != null and tax_flow.try_show_tax_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _can_show_tax_panel() -> bool:
	return tax_flow != null and tax_flow.can_show_tax_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_active_customer_npcs() -> bool:
	NPCQueueSystem.prune_invalid(NPC.current_queue)

	if not NPC.current_queue.is_empty():
		return true

	for node in get_tree().get_nodes_in_group("npcs"):
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_blocking_overlay_for_tax() -> bool:
	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_tax_panel(warning: String = "") -> bool:
	return tax_flow != null and tax_flow.show_tax_panel(warning)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_tax_payment_requested() -> void:
	if tax_flow != null:
		tax_flow.on_tax_payment_requested()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_tax_ignore_requested() -> void:
	if tax_flow != null:
		tax_flow.on_tax_ignore_requested()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _start_midnight_to_morning_transition() -> void:
	if tax_flow != null:
		tax_flow.start_midnight_to_morning_transition()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _run_midnight_to_morning_transition() -> void:
	if tax_flow != null:
		await tax_flow.run_midnight_to_morning_transition()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_storage_return_position() -> Vector2:
	if location_flow != null:
		return location_flow.get_storage_return_position()

	return STORE_STORAGE_RETURN_FALLBACK_POSITION


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_yard_return_position() -> Vector2:
	if location_flow != null:
		return location_flow.get_yard_return_position()

	return STORE_ENTRY_FALLBACK_POSITION


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_put_pressed() -> bool:
	return world_state_controller != null and world_state_controller.is_put_pressed()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_action_locked() -> bool:
	return world_state_controller != null and world_state_controller.is_action_locked()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_carried_object_from_player() -> Node2D:
	if shelf_placement_controller != null:
		return shelf_placement_controller.get_carried_object_from_player()

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_drop_carried_shelf() -> bool:
	return shelf_placement_controller != null and shelf_placement_controller.request_drop_carried_shelf()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_pickup_shelf(shelf: Shelf) -> bool:
	return shelf_placement_controller != null and shelf_placement_controller.request_pickup_shelf(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_player_carrying_shelf_named(shelf_name: String) -> bool:
	return shelf_placement_controller != null and shelf_placement_controller.is_player_carrying_shelf_named(shelf_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _drop_carried_shelf_in_store(object: Node2D) -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.drop_carried_shelf_in_store(object)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _create_carry_shelf_blocker() -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.create_carry_shelf_blocker()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _create_restricted_placement_warning() -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.create_restricted_placement_warning()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_carry_shelf_blocker() -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.update_carry_shelf_blocker()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_customer_path_visual() -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.update_customer_path_visual()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_customer_path_visual_visible(should_show: bool) -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.set_customer_path_visual_visible(should_show)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_carry_shelf_blocker_enabled(_enabled: bool) -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.set_carry_shelf_blocker_enabled(_enabled)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_shelf_placement_grid_positions() -> Array[Vector2]:
	if shelf_placement_controller != null:
		return shelf_placement_controller.get_shelf_placement_grid_positions()

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_marker2d(primary_path: NodePath, fallback_path: NodePath = NodePath("")) -> Marker2D:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
	var marker := get_node_or_null(primary_path) as Marker2D

	if marker != null:
		return marker

	if not fallback_path.is_empty():
		return get_node_or_null(fallback_path) as Marker2D

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_store_path_marker_by_role(
	role: StringName,
	fallback_path: NodePath = NodePath(""),
	legacy_fallback_path: NodePath = NodePath("")
) -> Marker2D:
	if store_path_markers != null:
		for child in store_path_markers.get_children():
			if not child is Marker2D:
				continue

			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
			var marker := child as Marker2D
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var marker_role: Variant = marker.get_meta(&"store_path_role", StringName())

			if marker_role is String and StringName(marker_role) == role:
				return marker

			if marker_role is StringName and marker_role == role:
				return marker

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
	var marker := _get_marker2d(fallback_path, legacy_fallback_path)

	if marker != null:
		return marker

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_store_path_graph() -> StorePathGraph:
	if npc_routes != null:
		return npc_routes.get_store_path_graph()

	if _store_path_graph == null:
		_store_path_graph = StorePathGraph.new(self, store_path_markers)

	return _store_path_graph


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _schedule_shelf_access_warmup(delay: float = SHELF_ACCESS_WARMUP_DELAY) -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.schedule_shelf_access_warmup(delay)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _hide_restricted_placement_warning() -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.hide_restricted_placement_warning()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _cancel_restricted_drop_feedback() -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.cancel_restricted_drop_feedback()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_player_depth_override() -> void:
	if shelf_placement_controller != null:
		shelf_placement_controller.update_player_depth_override()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _register_installed_shelf(object: Node2D) -> void:
	if progression_flow != null:
		progression_flow.register_installed_shelf(object)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _register_human_stock_progress() -> void:
	if progression_flow != null:
		progression_flow.register_human_stock_progress()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _connect_human_shelf_signals(shelf: Shelf) -> void:
	if progression_flow != null:
		progression_flow.connect_human_shelf_signals(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_human_stock_count(stock_count: int) -> void:
	if progression_flow != null:
		progression_flow.set_human_stock_count(stock_count)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_store_world_active(is_active: bool) -> void:
	if world_state_controller != null:
		world_state_controller.set_store_world_active(is_active)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_node_enabled_recursive(node: Node, enabled: bool) -> void:
	if world_state_controller != null:
		world_state_controller.set_node_enabled_recursive(node, enabled)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _create_fade_layer() -> void:
	if presentation != null:
		presentation.create_fade_layer()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _create_location_title_layer() -> void:
	if presentation != null:
		presentation.create_location_title_layer()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_location_title_once(location_key: String, title: String) -> void:
	if presentation != null:
		presentation.show_location_title_once(location_key, title)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_location_title(title: String) -> void:
	if presentation != null:
		presentation.show_location_title(title)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _fade_to_black() -> void:
	if presentation != null:
		await presentation.fade_to_black()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _fade_from_black() -> void:
	if presentation != null:
		await presentation.fade_from_black()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_npc_static_data() -> void:
	if npc_runtime != null:
		npc_runtime.setup_static_data()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _close_cashier_runtime_ui() -> void:
	if world_state_controller != null:
		world_state_controller.close_cashier_runtime_ui()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _connect_cursor_tooltip(area: Area2D, tooltip_text: String) -> void:
	if presentation != null:
		presentation.connect_cursor_tooltip(area, tooltip_text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_tooltip_entered(tooltip_text: String) -> void:
	if presentation != null:
		presentation._on_cursor_tooltip_entered(tooltip_text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_tooltip_exited() -> void:
	if presentation != null:
		presentation._on_cursor_tooltip_exited()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_npc_spawn_requested(npc_data: NPCData) -> void:
	if npc_runtime != null:
		npc_runtime.on_npc_spawn_requested(npc_data)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_npc_spawn_marker() -> Marker2D:
	if npc_runtime != null:
		return npc_runtime.get_npc_spawn_marker()

	return entrance_pos


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_npc_purchase(_npc: NPC, _item_id: String, price: int) -> void:
	if npc_runtime != null:
		npc_runtime.on_npc_purchase(_npc, _item_id, price)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_npc_exited(_npc: NPC) -> void:
	if npc_runtime != null:
		npc_runtime.on_npc_exited(_npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cashier_player_exit_dialog_finished(customer_id: String) -> void:
	if story_runtime != null and story_runtime.has_method("on_player_exit_dialog_finished"):
		story_runtime.call("on_player_exit_dialog_finished", customer_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_phase_changed(phase) -> void:
	if day_runtime != null:
		day_runtime.on_phase_changed(phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_target_reached() -> void:
	if day_runtime != null:
		day_runtime.on_target_reached()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_daily_report(report: Dictionary) -> void:
	if day_runtime != null:
		day_runtime.on_daily_report(report)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_day_ended(_day: int) -> void:
	if day_runtime != null:
		day_runtime.on_day_ended(_day)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_day_started(_day: int) -> void:
	if day_runtime != null:
		day_runtime.on_day_started(_day)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_human_shelf_item_placed(_slot_index: int, item_id: String) -> void:
	if progression_flow != null:
		progression_flow.on_human_shelf_item_placed(_slot_index, item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_human_shelf_item_removed(_slot_index: int, item_id: String) -> void:
	if progression_flow != null:
		progression_flow.on_human_shelf_item_removed(_slot_index, item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_ghost_shelf_item_placed(_slot_index: int, item_id: String) -> void:
	if progression_flow != null:
		await progression_flow.on_ghost_shelf_item_placed(_slot_index, item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _check_customer_spawning_ready(show_notice: bool = true) -> bool:
	return progression_flow != null and progression_flow.check_customer_spawning_ready(show_notice)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_customer_open_notification() -> void:
	if progression_flow != null:
		progression_flow.show_customer_open_notification()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_objective() -> void:
	if progression_flow != null:
		progression_flow.update_objective()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_current_objective_text() -> String:
	if progression_flow != null:
		return progression_flow.get_current_objective_text()

	return ""


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_notification(text: String, duration: float = 2.0) -> void:
	if presentation != null:
		presentation.show_notification(text, duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_passive_notification(text: String, duration: float = 2.0, instant_text: bool = false) -> void:
	if presentation != null:
		presentation.show_passive_notification(text, duration, instant_text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_status_notification(text: String, duration: float = 1.0) -> void:
	if presentation != null:
		presentation.show_status_notification(text, duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_task_complete_notice(key: String, message: String) -> void:
	if task_completion != null:
		task_completion.show_task_complete_notice(key, message)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_notification_sequence(messages: Array[String]) -> void:
	if presentation != null:
		await presentation.show_notification_sequence(messages)
