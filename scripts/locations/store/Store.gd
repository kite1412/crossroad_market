extends Node2D

const StoreNotificationBridge = preload("res://scripts/locations/store/StoreNotificationBridge.gd")
const StoreNpcSpawner = preload("res://scripts/locations/store/StoreNpcSpawner.gd")
const StoreProgressionController = preload("res://scripts/locations/store/StoreProgressionController.gd")
const StoreShelfController = preload("res://scripts/locations/store/StoreShelfController.gd")
const StoreTransitionController = preload("res://scripts/locations/store/StoreTransitionController.gd")

const NORMAL_STOCK_REQUIRED: int = 4
const CARRY_ACTION: StringName = &"carry"
const STORE_DROP_OFFSET := Vector2(0, 24)
const CASHIER_DEPTH_HALF_WIDTH: float = 48.0
const CASHIER_DEPTH_BACK_OFFSET: float = 64.0
const CASHIER_DEPTH_FRONT_OFFSET: float = 8.0
const SHELF_DEPTH_HALF_WIDTH: float = 48.0
const SHELF_DEPTH_BACK_OFFSET: float = 56.0
const SHELF_DEPTH_FRONT_OFFSET: float = 8.0
const CARRY_SHELF_CASHIER_BLOCKER_SIZE := Vector2(112, 80)
const CARRY_SHELF_CASHIER_BLOCKER_OFFSET := Vector2(0, -10)
const STORE_SHELF_PICKUP_DISTANCE: float = 76.0
const DOOR_NO_DROP_MARGIN: float = 34.0
const CASHIER_NO_DROP_MARGIN: float = 10.0
const SHELF_INTERACTION_STAND_DISTANCE: float = 54.0
const RESTRICTED_DROP_MESSAGE_COUNT: int = 3
const RESTRICTED_DROP_MESSAGE_DURATION: float = 0.55
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
@onready var storage_door: Area2D = get_node_or_null("StorageDoor") as Area2D
@onready var storage_return_pos: Marker2D = get_node_or_null("StorageReturnPos") as Marker2D
@onready var yard_door: Area2D = get_node_or_null("YardDoor") as Area2D
@onready var yard_return_pos: Marker2D = get_node_or_null("YardReturnPos") as Marker2D
@onready var player: Node2D = get_node_or_null("Player") as Node2D
@onready var cashier: Node2D = get_node_or_null("Cashier") as Node2D

var _current_storage: Node2D = null
var _current_yard: Node2D = null
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _carry_shelf_blocker: StaticBody2D = null
var _carry_shelf_blocker_shape: CollisionShape2D = null
var _is_transitioning: bool = false

var _normal_items_taken: int = 0
var _human_items_placed: int = 0
var _normal_supply_depleted: bool = false
var _mystery_phase_unlocked: bool = false
var _mystery_discovered: bool = false
var _mystery_supply_depleted: bool = false
var _human_shelf_installed: bool = false
var _ghost_shelf_installed: bool = false
var _customer_spawning_unlocked: bool = false
var _customer_open_notification_shown: bool = false
var _suppress_next_day_open_notification: bool = false
var _intro_shown: bool = false
var _ghost_shelf_lesson_shown: bool = false
var _gooby_refused: bool = false
var _last_objective_text: String = ""
var _restricted_drop_feedback_running: bool = false

var human_shelf: Shelf = null
var ghost_shelf: Shelf = null


func _ready() -> void:
	add_to_group("store")

	_connect_manager_signals()
	_connect_scene_signals()
	_create_fade_layer()
	_create_carry_shelf_blocker()
	_setup_npc_static_data()
	NPC.current_queue.clear()
	NPCScheduler.lock_spawning_until_ready()

	TimeManager.start_game()
	_update_objective()
	call_deferred("_show_morning_intro")


func _process(_delta: float) -> void:
	if _current_storage != null or _current_yard != null or _is_transitioning:
		_set_carry_shelf_blocker_enabled(false)
		return

	_update_carry_shelf_blocker()
	_update_player_depth_override()

	if _is_action_locked():
		return

	if _is_carry_pressed():
		var carried_object := _get_carried_object_from_player()

		if carried_object != null:
			_drop_carried_shelf_in_store(carried_object)
			return

		var installed_shelf := _get_nearest_installed_shelf()

		if installed_shelf != null:
			_pickup_installed_shelf(installed_shelf)


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


func get_activity_board_guidance() -> Dictionary:
	if TimeManager.current_phase == TimeManager.Phase.NIGHT and _customer_spawning_unlocked:
		return {
			"title": "Night Choice",
			"lines": [
				"Watch the store at night.",
				"Gooby may ask for Phantom Ice Cream.",
				"Give item: Trust +, Revenue 0G.",
				"Refuse sale: item returns, another customer may come."
			]
		}

	if not _human_shelf_installed:
		return {
			"title": "Today's Work",
			"lines": [
				"Go to storage.",
				"Carry the human shelf with F.",
				"Return and place it in the store."
			]
		}

	if _human_items_placed < NORMAL_STOCK_REQUIRED:
		return {
			"title": "Today's Work",
			"lines": [
				"Take stock from the normal box.",
				"Place human items on the human shelf.",
				"%d/%d human stock ready." % [_human_items_placed, NORMAL_STOCK_REQUIRED]
			]
		}

	if not _mystery_phase_unlocked or not _mystery_discovered:
		return {
			"title": "Strange Notes",
			"lines": [
				"Check the dark storage corner.",
				"Look for the glowing box.",
				"Bring anything strange back to the store."
			]
		}

	if not _ghost_shelf_installed:
		return {
			"title": "Strange Notes",
			"lines": [
				"Carry the ghost shelf to the store.",
				"Place it on the shop floor.",
				"Keep normal and ghost items separate."
			]
		}

	if ghost_shelf == null or not ghost_shelf.has_stock():
		return {
			"title": "Strange Notes",
			"lines": [
				"Take Phantom Ice Cream from storage.",
				"Stock it on the ghost shelf.",
				"Watch the store at night."
			]
		}

	return {
		"title": "Today's Work",
		"lines": [
			"Serve customers at the cashier.",
			"Scan the item they are buying.",
			"Reach the daily revenue target."
		]
	}


func on_gooby_refused() -> void:
	_gooby_refused = true
	_update_objective()


func _connect_manager_signals() -> void:
	if not NPCScheduler.npc_spawn_requested.is_connected(_on_npc_spawn_requested):
		NPCScheduler.npc_spawn_requested.connect(_on_npc_spawn_requested)

	if not TimeManager.phase_changed.is_connected(_on_phase_changed):
		TimeManager.phase_changed.connect(_on_phase_changed)

	if not TimeManager.day_ended.is_connected(_on_day_ended):
		TimeManager.day_ended.connect(_on_day_ended)

	if not EconomyManager.daily_target_reached.is_connected(_on_target_reached):
		EconomyManager.daily_target_reached.connect(_on_target_reached)

	if not EconomyManager.daily_report_ready.is_connected(_on_daily_report):
		EconomyManager.daily_report_ready.connect(_on_daily_report)


func _connect_scene_signals() -> void:
	if storage_door == null:
		push_error("Store: StorageDoor is missing.")
	else:
		storage_door.set_meta("door_type", "storage")

		if not storage_door.body_entered.is_connected(_on_storage_door_entered):
			storage_door.body_entered.connect(_on_storage_door_entered)

	if yard_door == null:
		push_error("Store: YardDoor is missing.")
	else:
		yard_door.set_meta("door_type", "yard")

		if not yard_door.body_entered.is_connected(_on_yard_door_entered):
			yard_door.body_entered.connect(_on_yard_door_entered)


func _show_morning_intro() -> void:
	if _intro_shown:
		return

	_intro_shown = true
	await _show_notification_sequence([
		"Finally made it... Grandma's old shop.",
		"It's dusty, but it still feels like home.",
		"Go to the backroom and bring out the human shelf."
	])


func _on_storage_door_entered(body: Node) -> void:
	if _is_action_locked():
		return

	if body.is_in_group("player"):
		await request_enter_storage("storage")


func _on_yard_door_entered(body: Node) -> void:
	if _is_action_locked():
		return

	if body.is_in_group("player"):
		await request_enter_yard("yard")


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
	_close_cashier_runtime_ui()
	await _fade_to_black()

	_current_yard = yard_scene.instantiate() as Node2D
	add_child(_current_yard)
	_current_yard.position = Vector2.ZERO
	_current_yard.z_index = 100

	if _current_yard.has_signal("return_to_store"):
		var return_callable := Callable(self, "_on_yard_return")

		if not _current_yard.is_connected("return_to_store", return_callable):
			_current_yard.connect("return_to_store", return_callable)
	else:
		push_error("Store: Yard scene must emit return_to_store.")

	var spawn_marker := _current_yard.get_node_or_null("PlayerSpawn") as Node2D
	var spawn_position := spawn_marker.global_position if spawn_marker != null else Vector2(240, 136)

	_set_store_world_active(false)
	StoreTransitionController.prepare_player_for_location(player, _current_yard, spawn_position)

	await _fade_from_black()
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
	_setup_npc_static_data()
	_update_objective()

	await _fade_from_black()
	_is_transitioning = false


func _on_storage_mystery_discovered() -> void:
	_mystery_discovered = true
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
		return yard_door.global_position + Vector2(0, -44)

	return Vector2(420, 210)


func _is_carry_pressed() -> bool:
	return InputMap.has_action(CARRY_ACTION) and Input.is_action_just_pressed(CARRY_ACTION)


func _is_action_locked() -> bool:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))


func _get_carried_object_from_player() -> Node2D:
	return StoreShelfController.get_carried_object_from_player(player)


func _is_player_carrying_shelf_named(shelf_name: String) -> bool:
	return StoreShelfController.is_player_carrying_shelf_named(player, shelf_name)


func _drop_carried_shelf_in_store(object: Node2D) -> void:
	if player == null:
		return

	var primary_drop_position := _get_primary_shelf_drop_position()
	var primary_rejection := _get_drop_rejection_reason(object, primary_drop_position)

	if primary_rejection != "":
		_show_drop_rejection_feedback(primary_rejection)

	var drop_position := _find_safe_drop_position(object)

	if drop_position == Vector2.INF:
		if primary_rejection == "":
			_show_notification("I can't place the shelf here.", 0.9)
		return

	object.reparent(self, true)
	object.global_position = drop_position
	object.z_index = 0
	object.set_meta("is_carried_storage_object", false)
	object.set_meta("is_installed_in_store", true)

	_set_node_enabled_recursive(object, true)
	_register_installed_shelf(object)

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


func _update_carry_shelf_blocker() -> void:
	if _carry_shelf_blocker != null:
		_carry_shelf_blocker.global_position = _get_carry_shelf_blocker_position()

	_set_carry_shelf_blocker_enabled(false)


func _set_carry_shelf_blocker_enabled(_enabled: bool) -> void:
	if _carry_shelf_blocker_shape == null:
		return

	_carry_shelf_blocker_shape.disabled = true


func _find_safe_drop_position(object: Node2D) -> Vector2:
	for candidate in _get_drop_candidates():
		if _get_drop_rejection_reason(object, candidate) == "":
			return candidate

	return Vector2.INF


func _get_drop_candidates() -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	var base_position := player.global_position

	candidates.append(_get_primary_shelf_drop_position())

	for offset in SHELF_DROP_FALLBACKS:
		var candidate := base_position + offset

		if candidate not in candidates:
			candidates.append(candidate)

	var legacy_candidate := base_position + STORE_DROP_OFFSET

	if legacy_candidate not in candidates:
		candidates.append(legacy_candidate)

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


func _get_drop_rejection_reason(object: Node2D, candidate: Vector2) -> String:
	var object_rect := _get_object_body_rect_at(object, candidate)

	if _intersects_area_no_drop_zone(object_rect, storage_door, DOOR_NO_DROP_MARGIN):
		return "This blocks the storage door."

	if _intersects_area_no_drop_zone(object_rect, yard_door, DOOR_NO_DROP_MARGIN):
		return "This blocks the yard door."

	if object_rect.intersects(_get_cashier_no_drop_rect()):
		return "This area is reserved for the cashier."

	if not _is_drop_position_clear(object, candidate):
		return "I can't place the shelf here."

	if not _has_clear_standing_spot_near_shelf(object, candidate):
		return "I can't reach the shelf there."

	return ""


func _get_object_body_rect_at(object: Node2D, candidate: Vector2) -> Rect2:
	var collision_shape := _get_object_collision_shape(object)

	if collision_shape == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var center := candidate + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


func _intersects_area_no_drop_zone(object_rect: Rect2, area: Area2D, margin: float) -> bool:
	if area == null:
		return false

	var area_rect := _get_area_rect(area)

	if area_rect.size == Vector2.ZERO:
		return false

	return object_rect.intersects(area_rect.grow(margin))


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


func _get_cashier_no_drop_rect() -> Rect2:
	var rect := Rect2(
		_get_carry_shelf_blocker_position() - CARRY_SHELF_CASHIER_BLOCKER_SIZE * 0.5,
		CARRY_SHELF_CASHIER_BLOCKER_SIZE
	)

	return rect.grow(CASHIER_NO_DROP_MARGIN)


func _has_clear_standing_spot_near_shelf(object: Node2D, candidate: Vector2) -> bool:
	var interaction_center := _get_shelf_interaction_center_at(object, candidate)
	var standing_offsets: Array[Vector2] = [
		Vector2(0, SHELF_INTERACTION_STAND_DISTANCE),
		Vector2(-SHELF_INTERACTION_STAND_DISTANCE, 0),
		Vector2(SHELF_INTERACTION_STAND_DISTANCE, 0),
		Vector2(0, -SHELF_INTERACTION_STAND_DISTANCE)
	]

	for offset in standing_offsets:
		if _is_player_standing_position_clear(interaction_center + offset, object):
			return true

	return false


func _get_shelf_interaction_center_at(object: Node2D, candidate: Vector2) -> Vector2:
	var interaction_area := object.get_node_or_null("InteractionArea") as Area2D

	if interaction_area == null:
		return candidate

	return candidate + interaction_area.position


func _is_player_standing_position_clear(position: Vector2, shelf_object: Node2D) -> bool:
	if player == null:
		return true

	var player_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if player_shape == null or player_shape.shape == null:
		return true

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player_shape.shape
	query.transform = Transform2D(0.0, position + player_shape.position)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hits := get_world_2d().direct_space_state.intersect_shape(query, 16)

	for hit in hits:
		var collider: Node = hit.get("collider", null)

		if collider == null:
			continue

		if collider == player or _is_descendant_of(collider, player):
			continue

		if collider == shelf_object or _is_descendant_of(collider, shelf_object):
			continue

		return false

	return true


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

	object.remove_from_group("shelves")
	object.reparent(player, true)
	object.position = Vector2(0, -34)
	object.z_index = 80
	object.set_meta("is_carried_storage_object", true)
	object.set_meta("is_installed_in_store", false)
	_set_node_enabled_recursive(object, false)
	_update_objective()
	_show_notification("Shelf picked up. Press F to place it.")


func _show_drop_rejection_feedback(message: String) -> void:
	if message == "This area is reserved for the cashier.":
		_show_restricted_drop_feedback(message)
		return

	_show_notification(message, 0.9)


func _show_restricted_drop_feedback(message: String) -> void:
	if _restricted_drop_feedback_running:
		return

	_restricted_drop_feedback_running = true

	for i in RESTRICTED_DROP_MESSAGE_COUNT:
		_show_notification(message, RESTRICTED_DROP_MESSAGE_DURATION)
		await get_tree().create_timer(2.0 / float(RESTRICTED_DROP_MESSAGE_COUNT)).timeout

	_restricted_drop_feedback_running = false


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
		_close_cashier_runtime_ui()

	for child in get_children():
		if child == _current_storage or child == _current_yard or child == _fade_layer or child == _carry_shelf_blocker or child == player:
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


func _fade_to_black() -> void:
	await StoreTransitionController.fade_to(self, _fade_rect, 1.0)


func _fade_from_black() -> void:
	await StoreTransitionController.fade_to(self, _fade_rect, 0.0)


func _setup_npc_static_data() -> void:
	if counter_pos != null:
		NPC.counter_position = counter_pos.global_position

	if entrance_pos != null:
		NPC.entrance_position = entrance_pos.global_position


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	return StoreShelfController.is_descendant_of(node, ancestor)


func _close_cashier_runtime_ui() -> void:
	if cashier == null:
		cashier = get_node_or_null("Cashier") as Node2D

	if cashier != null and cashier.has_method("reset_runtime_ui"):
		cashier.call("reset_runtime_ui")


func _on_npc_spawn_requested(npc_data: NPCData) -> void:
	StoreNpcSpawner.spawn_npc(
		self,
		npc_scene,
		entrance_pos,
		npc_data,
		_on_npc_purchase,
		_on_npc_exited
	)


func _on_npc_purchase(_npc: NPC, _item_id: String, price: int) -> void:
	EconomyManager.add_gold(price)


func _on_npc_exited(_npc: NPC) -> void:
	pass


func _on_phase_changed(phase) -> void:
	match phase:
		TimeManager.Phase.DAY:
			if _customer_spawning_unlocked:
				if _suppress_next_day_open_notification:
					_suppress_next_day_open_notification = false
				else:
					_show_customer_open_notification()
			else:
				_show_notification("Finish setting up before customers arrive.", 3.0)
		TimeManager.Phase.NIGHT:
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
	_gooby_refused = false

	var should_start_day_one_customers_now := StoreProgressionController.should_start_day_one_customers_now()

	if show_notice:
		_show_customer_open_notification()
	else:
		_suppress_next_day_open_notification = should_start_day_one_customers_now

	NPCScheduler.unlock_spawning_now(should_start_day_one_customers_now)
	_update_objective()
	return true


func _show_customer_open_notification() -> void:
	if _customer_open_notification_shown:
		return

	_customer_open_notification_shown = true
	_show_notification("Store is ready. Human customers can come in. Ghost customers wait for night.", 2.5)
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
	if _gooby_refused:
		return "Wait for the next strange customer."

	if TimeManager.current_phase == TimeManager.Phase.NIGHT and _customer_spawning_unlocked:
		return "Serve Gooby at the cashier."

	if not _human_shelf_installed:
		return "Bring the human shelf from storage."

	if _human_items_placed < NORMAL_STOCK_REQUIRED:
		return "Stock the human shelf with normal items."

	if not _mystery_phase_unlocked or not _mystery_discovered:
		return "Check the dark storage corner."

	if not _ghost_shelf_installed:
		return "Place the ghost shelf in the store."

	if ghost_shelf == null or not ghost_shelf.has_stock():
		return "Stock Phantom Ice Cream on ghost shelf."

	if not _customer_spawning_unlocked:
		return "Prepare the store for customers."

	return "Serve customers at the cashier."


func _show_notification(text: String, duration: float = 2.0) -> void:
	StoreNotificationBridge.show(get_tree(), text, duration)


func _show_notification_sequence(messages: Array[String]) -> void:
	await StoreNotificationBridge.show_sequence(self, messages)


func _get_shelf_stock_count(shelf: Shelf) -> int:
	return StoreShelfController.get_shelf_stock_count(shelf)
