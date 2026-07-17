class_name NPC
extends CharacterBody2D

const NPCDialogController = preload("res://scripts/npc/presentation/NPCDialogController.gd")
const NPCVisualController = preload("res://scripts/npc/presentation/NPCVisualController.gd")

enum State {
	ENTER,
	WALK_TO_SHELF,
	SEARCH_ITEM,
	BROWSE_ITEM,
	TAKE_ITEM,
	WAIT_IN_QUEUE,
	CHECKOUT,
	EXIT
}

const SPEED: float = 80.0
const ARRIVAL_THRESHOLD: float = 5.0
const ENTER_PAUSE: float = 1.5
const DIALOG_DURATION: float = 2.5
const CHECKOUT_PATIENCE: float = 20.0
const SEARCH_PATIENCE: float = 15.0
const SHELF_SEARCH_MIN_TIME: float = 1.0
const SHELF_TAKE_PAUSE_TIME: float = 1.25
const SHELF_VISIT_OFFSET: Vector2 = Vector2(0, 34)
const SHELF_ACTION_DISTANCE: float = 28.0
const SHELF_VISIT_ARRIVAL_DISTANCE: float = 8.0
const QUEUE_ACTION_DISTANCE: float = 14.0
const STUCK_WATCHDOG_SECONDS: float = 1.5
const STUCK_MIN_MOVE_DISTANCE: float = 1.0
const STUCK_WATCHDOG_MAX_REBUILDS: int = 2

static var current_queue: Array[NPC] = []
static var counter_position: Vector2 = Vector2.ZERO
static var entrance_position: Vector2 = Vector2.ZERO
static var exit_position: Vector2 = Vector2.ZERO
static var store_path_position: Vector2 = Vector2.INF

signal purchase_completed(npc: NPC, item_id: String, price: int)
signal npc_exited(npc: NPC)

var npc_data: NPCData
var current_state: State = State.ENTER
var target_position: Vector2 = Vector2.ZERO
var item_to_buy: String = ""
var item_to_buy_original: String = ""
var queue_position: int = 0
var shopping_list: Array[String] = []
var checkout_total_override: int = -1
var checkout_outcome: String = "paid"

var _browse_item: String = ""
var _cart_items: Array[String] = []
var _enter_pause_timer: float = 0.0
var _dialog_timer: float = 0.0
var _checkout_timer: float = 0.0
var _search_timer: float = 0.0
var _search_announced: bool = false
var _take_item_pause_timer: float = 0.0
var _has_taken_shelf_item: bool = false
var _trust_label: Label = null
var _movement_route: Array[Vector2] = []
var _movement_route_destination: Vector2 = Vector2.INF
var _target_shelf: Shelf = null
var _last_watchdog_position: Vector2 = Vector2.INF
var _stuck_watchdog_timer: float = 0.0
var _stuck_watchdog_rebuilds: int = 0
var _exit_completed: bool = false

@onready var sprite_move: CharacterSprite = $VisualRoot/SpriteMove
@onready var sprite_idle: CharacterSprite = $VisualRoot/SpriteIdle

var _move_direction: CharacterSprite.Direction = CharacterSprite.Direction.DOWN


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("dialog_skip_target")
	_trust_label = get_node_or_null("TrustLabel") as Label
	_update_trust_display()
	_set_dialog_mouse_filter()
	#if npc_data != null:
		#_load_character_assets()
	_update_character_sprite()


func _exit_tree() -> void:
	_disconnect_trust_signal()
	_leave_queue()


func setup(data: NPCData) -> void:
	npc_data = data
	_load_character_assets()
	_apply_scripted_metadata()
	_choose_item_to_buy()
	item_to_buy_original = item_to_buy
	_apply_name_label()
	_apply_visual()
	_setup_trust_display()
	_set_state(State.ENTER)


func _physics_process(delta: float) -> void:
	match current_state:
		State.ENTER:
			_process_enter()
		State.WALK_TO_SHELF:
			_process_walk_to_shelf()
		State.SEARCH_ITEM:
			_process_search_item(delta)
		State.BROWSE_ITEM:
			_process_browse_item(delta)
		State.TAKE_ITEM:
			_process_take_item()
		State.WAIT_IN_QUEUE:
			_process_wait_in_queue(delta)
		State.CHECKOUT:
			_process_checkout(delta)
		State.EXIT:
			_process_exit()

	if is_queued_for_deletion():
		return

	_update_stuck_watchdog(delta)
	_update_dialog(delta)
	_update_character_sprite()


func complete_checkout() -> void:
	if checkout_outcome == "reject_return":
		reject_checkout_and_return_items("Boo...")
		return

	var total := get_checkout_total()

	if total > 0:
		purchase_completed.emit(self, item_to_buy, total)
		_show_dialog(BlueprintManager.get_done_dialog(self))

	_finish_checkout_and_exit()


func complete_story_gift(dialog_text: String = "Thank you...") -> void:
	_cart_items.clear()
	_show_dialog(dialog_text)
	_finish_checkout_and_exit()


func reject_checkout_and_return_items(dialog_text: String = "Boo...") -> void:
	_return_cart_items_to_shelf()
	_show_dialog(dialog_text)
	_finish_checkout_and_exit()


func get_checkout_total() -> int:
	return NPCCheckoutBehavior.get_checkout_total(_cart_items, item_to_buy, checkout_total_override)


func get_checkout_item_label() -> String:
	return NPCCheckoutBehavior.get_checkout_item_label(_cart_items, item_to_buy)


func get_cart_item_ids() -> Array[String]:
	return NPCCheckoutBehavior.get_cart_item_ids(_cart_items, item_to_buy)


func repeat_checkout_request() -> void:
	_show_dialog("I'm buying %s." % get_checkout_item_label())


func skip_dialog() -> bool:
	if _dialog_timer <= 0.0:
		return false

	_dialog_timer = 0.0
	_hide_dialog()
	return true


func cancel_checkout_and_leave() -> void:
	_return_cart_items_to_shelf()
	_show_dialog("Never mind. I'll come back later.")
	_finish_checkout_and_exit()


func queue_done() -> void:
	queue_free()


func _apply_name_label() -> void:
	NPCVisualController.apply_name_label(self, npc_data)


func _apply_visual() -> void:
	NPCVisualController.apply_visual(self, npc_data)


func _setup_trust_display() -> void:
	_update_trust_display()

	var trust_callable := Callable(self, "_on_trust_changed")

	if _should_show_trust_display():
		if not RelationshipManager.trust_changed.is_connected(trust_callable):
			RelationshipManager.trust_changed.connect(trust_callable)
	else:
		_disconnect_trust_signal()


func _disconnect_trust_signal() -> void:
	var trust_callable := Callable(self, "_on_trust_changed")

	if RelationshipManager.trust_changed.is_connected(trust_callable):
		RelationshipManager.trust_changed.disconnect(trust_callable)


func _should_show_trust_display() -> bool:
	return (
		npc_data != null
		and npc_data.npc_category == NPCData.NPCCategory.STORY
		and npc_data.npc_id != ""
	)


func _update_trust_display() -> void:
	if _trust_label == null:
		return

	if not _should_show_trust_display():
		_trust_label.visible = false
		return

	var trust_value := RelationshipManager.get_trust(npc_data.npc_id)
	_trust_label.visible = true
	_trust_label.text = "Trust: %d/100" % trust_value


func _on_trust_changed(npc_id: String, _new_trust: int, _delta: int) -> void:
	if npc_data == null or npc_id != npc_data.npc_id:
		return

	_update_trust_display()


func _process_enter() -> void:
	_enter_pause_timer += get_process_delta_time()

	if _enter_pause_timer < ENTER_PAUSE:
		return

	_choose_available_item_to_buy()

	var target_shelf := _find_reachable_matching_shelf()

	if target_shelf == null:
		var fallback_shelf := _find_matching_shelf()
		_show_dialog("I can't reach that shelf." if fallback_shelf != null else "Nothing I need is on the shelves right now.")
		_dialog_timer = DIALOG_DURATION
		target_position = _get_exit_position()
		_set_state(State.EXIT)
		return

	var visit_position := _get_shelf_visit_position(target_shelf)

	if not visit_position.is_finite():
		_show_dialog("I can't reach that shelf.")
		_dialog_timer = DIALOG_DURATION
		target_position = _get_exit_position()
		_set_state(State.EXIT)
		return

	_target_shelf = target_shelf
	target_position = visit_position
	_set_state(State.WALK_TO_SHELF)


func _process_walk_to_shelf() -> void:
	if global_position.distance_to(target_position) <= SHELF_VISIT_ARRIVAL_DISTANCE:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_state(State.SEARCH_ITEM)
		return

	if _move_to(target_position):
		_set_state(State.SEARCH_ITEM)


func _process_search_item(delta: float) -> void:
	_search_timer += delta

	if _has_any_requested_item_available():
		if _search_timer < SHELF_SEARCH_MIN_TIME:
			return

		_set_state(State.TAKE_ITEM)
		return

	var action := BlueprintManager.evaluate_no_item_action(self)

	match action:
		BlueprintManager.Action.LEAVE:
			if not _search_announced:
				_show_dialog(BlueprintManager.get_item_not_found_dialog(self))
				_search_announced = true

			if _search_timer >= SEARCH_PATIENCE:
				target_position = _get_exit_position()
				_set_state(State.EXIT)

		BlueprintManager.Action.QUEUE:
			if not _search_announced:
				_show_dialog(BlueprintManager.get_item_not_found_dialog(self))
				_search_announced = true

			if _search_timer >= SEARCH_PATIENCE:
				_show_dialog("Is there any restock coming...? I'll wait here.")
				_search_timer = 0.0
				_search_announced = false
				_join_queue()
				target_position = _get_queue_target()
				_set_state(State.WAIT_IN_QUEUE)

		BlueprintManager.Action.BROWSE_BUY:
			if not _search_announced:
				_show_dialog(BlueprintManager.get_item_not_found_dialog(self))
				_search_announced = true

			if _search_timer >= 5.0:
				var alt_item := _find_alternative_item()

				if alt_item != "":
					_browse_item = alt_item
					item_to_buy = alt_item
					_search_timer = 0.0
					_search_announced = false
					_show_dialog("Oh? This looks good actually.")
					_set_state(State.TAKE_ITEM)
				else:
					target_position = _get_exit_position()
					_set_state(State.EXIT)


func _process_browse_item(delta: float) -> void:
	_search_timer += delta

	if _search_timer < 8.0:
		return

	var alt_item := _find_alternative_item()

	if alt_item != "":
		_browse_item = alt_item
		item_to_buy = alt_item
		_show_dialog("This one will do!")
		_set_state(State.TAKE_ITEM)
	else:
		_show_dialog("Nothing here for me...")
		target_position = _get_exit_position()
		_set_state(State.EXIT)


func _process_take_item() -> void:
	if _has_taken_shelf_item:
		velocity = Vector2.ZERO
		move_and_slide()
		_take_item_pause_timer += get_process_delta_time()

		if _take_item_pause_timer < SHELF_TAKE_PAUSE_TIME:
			return

		_join_queue()
		target_position = _get_queue_target()
		_set_state(State.WAIT_IN_QUEUE)
		return

	if global_position.distance_to(target_position) > SHELF_ACTION_DISTANCE and not _move_to(target_position):
		return

	if _take_requested_items_from_shelves():
		_has_taken_shelf_item = true
		_take_item_pause_timer = 0.0
		_show_dialog("I'll take this.")
		return

	_show_dialog("Someone must have taken it already.")
	target_position = _get_exit_position()
	_set_state(State.EXIT)


func _process_wait_in_queue(_delta: float) -> void:
	target_position = _get_queue_target()

	var arrived := global_position.distance_to(target_position) <= QUEUE_ACTION_DISTANCE

	if not arrived:
		arrived = _move_to(target_position)

	if arrived and current_queue.find(self) == 0:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_state(State.CHECKOUT)


func _process_checkout(delta: float) -> void:
	if _checkout_timer == 0.0:
		_show_dialog("I'd like to buy %s." % get_checkout_item_label())

	_checkout_timer += delta

	if npc_data.patience_type == NPCData.PatienceType.IMPATIENT and _checkout_timer >= CHECKOUT_PATIENCE:
		_show_dialog(BlueprintManager.get_checkout_wait_dialog(self))
		_leave_queue()
		_return_item_to_shelf()
		target_position = _get_exit_position()
		_set_state(State.EXIT)


func _process_exit() -> void:
	if global_position.distance_to(target_position) <= ARRIVAL_THRESHOLD:
		velocity = Vector2.ZERO
		_complete_exit()
		return

	if _dialog_timer > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _move_to(target_position):
		_complete_exit()


func _complete_exit() -> void:
	if _exit_completed or is_queued_for_deletion():
		return

	_exit_completed = true
	velocity = Vector2.ZERO
	_movement_route.clear()
	_movement_route_destination = Vector2.INF
	_reset_stuck_watchdog()
	npc_exited.emit(self)
	queue_done()


func _move_to(target: Vector2) -> bool:
	if _should_rebuild_movement_route(target):
		_movement_route = _build_movement_route(target)
		_movement_route_destination = target

	if _movement_route.is_empty():
		return NPCMovement.move_to(self, target, SPEED, ARRIVAL_THRESHOLD)

	var next_target := _movement_route[0]

	if not NPCMovement.move_to(self, next_target, SPEED, ARRIVAL_THRESHOLD):
		return false

	_movement_route.remove_at(0)
	return _movement_route.is_empty()


func _update_character_sprite() -> void:
	if sprite_idle == null or sprite_move == null:
		return

	if velocity == Vector2.ZERO:
		sprite_move.visible = false
		sprite_idle.visible = true
		sprite_idle.play_direction_loop(_move_direction)
		return

	sprite_idle.visible = false
	sprite_move.visible = true
	sprite_move.apply_motion_vector(velocity)
	_move_direction = _get_direction(velocity)


func _get_direction(motion: Vector2) -> CharacterSprite.Direction:
	if abs(motion.x) > abs(motion.y):
		return CharacterSprite.Direction.RIGHT if motion.x > 0.0 else CharacterSprite.Direction.LEFT
	return CharacterSprite.Direction.DOWN if motion.y > 0.0 else CharacterSprite.Direction.UP


func _load_character_assets() -> void:
	if npc_data == null or npc_data.assets_path.strip_edges() == "":
		return

	var idle_sprite := sprite_idle
	var move_sprite := sprite_move
	if idle_sprite == null:
		idle_sprite = get_node_or_null("VisualRoot/SpriteIdle") as CharacterSprite
	if move_sprite == null:
		move_sprite = get_node_or_null("VisualRoot/SpriteMove") as CharacterSprite
	if idle_sprite == null or move_sprite == null:
		push_error("NPC '%s' cannot load character assets because SpriteIdle or SpriteMove is missing." % npc_data.npc_id)
		return

	var textures := _load_directional_textures(npc_data.assets_path)
	if textures.size() < 4:
		push_warning("NPC '%s' is missing one or more directional textures at '%s'." % [npc_data.npc_id, npc_data.assets_path])
		return

	idle_sprite.direction_config = _create_character_sprite_config(textures, 0, 6, 5)
	move_sprite.direction_config = _create_character_sprite_config(textures, 1, 4, 3)
	idle_sprite.refresh_sprite_frames()
	move_sprite.refresh_sprite_frames()
	idle_sprite.visible = true
	move_sprite.visible = false
	_validate_character_sprite("idle", idle_sprite, 6)
	_validate_character_sprite("move", move_sprite, 4)

	var placeholder := get_node_or_null("VisualRoot/PlaceholderRect") as CanvasItem
	if placeholder != null:
		placeholder.visible = false


func _load_directional_textures(assets_path: String) -> Dictionary:
	var directory_path := "res://assets/characters/%s" % assets_path.trim_prefix("/").trim_suffix("/")
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return {}

	var textures: Dictionary = {}
	var prefixes := {
		"down": "front-",
		"left": "side-left-",
		"right": "side-right-",
		"up": "back-"
	}

	for file_name in directory.get_files():
		if not file_name.to_lower().ends_with(".png"):
			continue

		for direction in prefixes:
			if textures.has(direction) or not file_name.begins_with(prefixes[direction]):
				continue

			var texture := load("%s/%s" % [directory_path, file_name]) as Texture2D
			if texture != null:
				textures[direction] = texture
			break

	return textures


func _create_character_sprite_config(textures: Dictionary, row: int, frames: int, end_column: int) -> AnimatedCharacterSpriteConfig:
	var config := AnimatedCharacterSpriteConfig.new()
	_configure_character_direction(config, "down", textures["down"] as Texture2D, row, frames, end_column)
	_configure_character_direction(config, "left", textures["left"] as Texture2D, row, frames, end_column)
	_configure_character_direction(config, "right", textures["right"] as Texture2D, row, frames, end_column)
	_configure_character_direction(config, "up", textures["up"] as Texture2D, row, frames, end_column)
	return config


func _configure_character_direction(config: AnimatedCharacterSpriteConfig, direction: String, texture: Texture2D, row: int, frames: int, end_column: int) -> void:
	match direction:
		"down":
			config.down_texture = texture
			config.down_rows = 2
			config.down_columns = 6
			config.down_frames_per_row = frames
			config.down_start_row = row
			config.down_start_column = 0
			config.down_end_row = row
			config.down_end_column = end_column
		"left":
			config.left_texture = texture
			config.left_rows = 2
			config.left_columns = 6
			config.left_frames_per_row = frames
			config.left_start_row = row
			config.left_start_column = 0
			config.left_end_row = row
			config.left_end_column = end_column
		"right":
			config.right_texture = texture
			config.right_rows = 2
			config.right_columns = 6
			config.right_frames_per_row = frames
			config.right_start_row = row
			config.right_start_column = 0
			config.right_end_row = row
			config.right_end_column = end_column
		"up":
			config.up_texture = texture
			config.up_rows = 2
			config.up_columns = 6
			config.up_frames_per_row = frames
			config.up_start_row = row
			config.up_start_column = 0
			config.up_end_row = row
			config.up_end_column = end_column


func _validate_character_sprite(label: String, sprite: CharacterSprite, expected_frames: int) -> void:
	if sprite == null or sprite.direction_config == null:
		push_error("NPC '%s' %s sprite has no AnimatedCharacterSpriteConfig." % [npc_data.npc_id, label])
		return

	for direction in [CharacterSprite.Direction.DOWN, CharacterSprite.Direction.LEFT, CharacterSprite.Direction.RIGHT, CharacterSprite.Direction.UP]:
		var settings := sprite.direction_config.get_direction_settings(direction)
		var texture := settings.get("texture") as Texture2D
		var animation_name := _get_character_animation_name(direction)
		var frame_count := sprite.sprite_frames.get_frame_count(animation_name) if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name) else 0
		if texture == null or frame_count != expected_frames:
			push_error("NPC '%s' %s sprite failed for %s: texture=%s frames=%d expected=%d" % [npc_data.npc_id, label, animation_name, texture != null, frame_count, expected_frames])


func _get_character_animation_name(direction: CharacterSprite.Direction) -> StringName:
	match direction:
		CharacterSprite.Direction.DOWN: return &"down"
		CharacterSprite.Direction.LEFT: return &"left"
		CharacterSprite.Direction.RIGHT: return &"right"
		CharacterSprite.Direction.UP: return &"up"
	return &"down"


func _update_stuck_watchdog(delta: float) -> void:
	if not _is_movement_state():
		_reset_stuck_watchdog()
		return

	if _dialog_timer > 0.0 or _take_item_pause_timer > 0.0:
		_reset_stuck_watchdog()
		return

	if current_state == State.EXIT and global_position.distance_to(target_position) <= ARRIVAL_THRESHOLD:
		_reset_stuck_watchdog()
		return

	if not _last_watchdog_position.is_finite():
		_last_watchdog_position = global_position
		_stuck_watchdog_timer = 0.0
		return

	if global_position.distance_to(_last_watchdog_position) > STUCK_MIN_MOVE_DISTANCE:
		_last_watchdog_position = global_position
		_stuck_watchdog_timer = 0.0
		return

	_stuck_watchdog_timer += delta

	if _stuck_watchdog_timer < STUCK_WATCHDOG_SECONDS:
		return

	if current_state == State.WALK_TO_SHELF and _refresh_shelf_visit_target():
		_reset_stuck_watchdog()
		return

	if _stuck_watchdog_rebuilds >= STUCK_WATCHDOG_MAX_REBUILDS:
		print(
			"NPC route watchdog giving up: state=%s pos=%s target=%s route=%s" %
			[str(current_state), str(global_position), str(target_position), str(_movement_route)]
		)
		if current_state == State.EXIT:
			# Use direct orthogonal path as last resort for EXIT
			var fallback := _make_orthogonal_route(global_position, exit_position, true)
			fallback.append(exit_position)
			_movement_route = _dedupe_route_points(fallback)
			_movement_route_destination = exit_position
			_stuck_watchdog_rebuilds = 0
			return
		target_position = _get_exit_position()
		_set_state(State.EXIT)
		return

	print(
		"NPC route watchdog: state=%s pos=%s target=%s route=%s" %
		[str(current_state), str(global_position), str(target_position), str(_movement_route)]
	)
	_movement_route.clear()
	_movement_route_destination = Vector2.INF
	_last_watchdog_position = global_position
	_stuck_watchdog_timer = 0.0
	_stuck_watchdog_rebuilds += 1


func _is_movement_state() -> bool:
	return current_state in [
		State.WALK_TO_SHELF,
		State.TAKE_ITEM,
		State.WAIT_IN_QUEUE,
		State.EXIT
	]


func _reset_stuck_watchdog() -> void:
	_last_watchdog_position = Vector2.INF
	_stuck_watchdog_timer = 0.0
	_stuck_watchdog_rebuilds = 0


func _should_rebuild_movement_route(target: Vector2) -> bool:
	if _movement_route.is_empty():
		return true

	return not _movement_route_destination.is_equal_approx(target)


func _build_movement_route(destination: Vector2) -> Array[Vector2]:
	var route := _get_store_route_for_current_state(destination)

	if not route.is_empty():
		return _append_destination_to_route(route, destination)

	route = []
	var path_position := _get_store_path_position()

	if _should_use_store_path(destination, path_position):
		route.append_array(_make_orthogonal_route(global_position, path_position, true))
		route.append_array(_make_orthogonal_route(path_position, destination, true))
	else:
		route.append_array(_make_orthogonal_route(global_position, destination, true))

	return _dedupe_route_points(route)


func _get_store_route_for_current_state(destination: Vector2) -> Array[Vector2]:
	var store := _get_store_route_provider()

	if store == null:
		return []

	match current_state:
		State.WALK_TO_SHELF:
			if _target_shelf != null and is_instance_valid(_target_shelf):
				return _call_store_route(store, &"get_npc_route_to_shelf_access", [_target_shelf])

			return _call_store_route(store, &"get_npc_entry_route_to_shelf", [destination, global_position])
		State.WAIT_IN_QUEUE:
			if _target_shelf != null and is_instance_valid(_target_shelf):
				return _call_store_route(store, &"get_npc_route_from_shelf_to_cashier", [_target_shelf])

			return _call_store_route(store, &"get_npc_route_to_cashier_from", [global_position])
		State.EXIT:
			return _call_store_route(store, &"get_npc_exit_route_from", [global_position])

	return []


func _get_store_route_provider() -> Node:
	var tree := get_tree()

	if tree == null:
		return null

	var store := tree.get_first_node_in_group("store")

	if store == null:
		return null

	return store


func _call_store_route(store: Node, method_name: StringName, args: Array) -> Array[Vector2]:
	if store == null or not store.has_method(method_name):
		return []

	var result: Variant = store.callv(method_name, args)
	var route: Array[Vector2] = []

	if not (result is Array):
		return route

	for point_variant in result:
		if point_variant is Vector2:
			route.append(point_variant as Vector2)

	return _dedupe_route_points(route)


func _append_destination_to_route(route: Array[Vector2], destination: Vector2) -> Array[Vector2]:
	if route.is_empty():
		return _make_orthogonal_route(global_position, destination, true)

	var last_point := route[route.size() - 1]

	if last_point.distance_to(destination) > ARRIVAL_THRESHOLD:
		route.append_array(_make_orthogonal_route(last_point, destination, true))

	return _dedupe_route_points(route)


func _make_orthogonal_route(from_pos: Vector2, to_pos: Vector2, horizontal_first: bool = true) -> Array[Vector2]:
	var route: Array[Vector2] = []

	if from_pos.distance_to(to_pos) <= 2.0:
		return route

	var corner := Vector2(to_pos.x, from_pos.y) if horizontal_first else Vector2(from_pos.x, to_pos.y)

	if from_pos.distance_to(corner) > 2.0:
		route.append(corner)

	if corner.distance_to(to_pos) > 2.0:
		route.append(to_pos)

	return route


func _dedupe_route_points(route: Array[Vector2]) -> Array[Vector2]:
	var deduped: Array[Vector2] = []

	for point in route:
		if not point.is_finite():
			continue

		if not deduped.is_empty() and deduped[deduped.size() - 1].distance_to(point) <= 2.0:
			continue

		deduped.append(point)

	return deduped


func _should_use_store_path(destination: Vector2, path_position: Vector2) -> bool:
	if not _is_valid_route_point(path_position):
		return false

	if global_position.distance_to(path_position) <= ARRIVAL_THRESHOLD:
		return false

	if destination.distance_to(path_position) <= ARRIVAL_THRESHOLD:
		return false

	return true


func _is_valid_route_point(point: Vector2) -> bool:
	return point.is_finite()


func _is_near_cashier_area() -> bool:
	var cashier_threshold: float = 160.0
	return (
		counter_position != Vector2.ZERO
		and global_position.distance_to(counter_position) <= cashier_threshold
	)


func _get_store_path_position() -> Vector2:
	return store_path_position


func _get_exit_position() -> Vector2:
	if _is_valid_route_point(exit_position) and exit_position != Vector2.ZERO:
		return exit_position

	return entrance_position


func _choose_item_to_buy() -> void:
	if not shopping_list.is_empty():
		item_to_buy = shopping_list[0]
		return

	if npc_data == null or npc_data.favorite_items.is_empty():
		item_to_buy = ""
		return

	item_to_buy = npc_data.favorite_items[randi() % npc_data.favorite_items.size()]


func _choose_available_item_to_buy() -> void:
	if npc_data == null:
		return

	for shopping_item_id in shopping_list:
		if _find_shelf_with_item(shopping_item_id) != null:
			_set_requested_item(shopping_item_id)
			return

	for favorite_item_id in npc_data.favorite_items:
		var item_id := str(favorite_item_id)

		if _find_shelf_with_item(item_id) != null:
			_set_requested_item(item_id)
			return

	if _can_substitute_available_stock():
		var fallback_item_id := _find_available_stock_substitute()

		if fallback_item_id != "":
			_set_requested_item(fallback_item_id)
			return

	if item_to_buy == "":
		_choose_item_to_buy()


func _find_alternative_item() -> String:
	return NPCShoppingBehavior.find_alternative_item(get_tree(), item_to_buy, item_to_buy_original)


func _set_requested_item(item_id: String) -> void:
	item_to_buy = item_id
	item_to_buy_original = item_id
	shopping_list.clear()
	shopping_list.append(item_id)


func _can_substitute_available_stock() -> bool:
	return (
		npc_data != null
		and npc_data.npc_category == NPCData.NPCCategory.GENERIC
		and npc_data.visit_phase != NPCData.VisitPhase.NIGHT
	)


func _find_available_stock_substitute() -> String:
	var shelf_type := ItemData.ShelfType.HUMAN
	var requested_items := _get_requested_items()

	for requested_item_id in requested_items:
		var item := ItemDatabase.get_item(requested_item_id)

		if item != null:
			shelf_type = item.shelf_type
			break

	return NPCShoppingBehavior.find_first_stocked_item_for_shelf_type(get_tree(), shelf_type)


func _join_queue() -> void:
	NPCQueueSystem.join_queue(current_queue, self)


func _leave_queue() -> void:
	NPCQueueSystem.leave_queue(current_queue, self)


func _get_queue_target() -> Vector2:
	var position_in_queue := current_queue.find(self)

	if position_in_queue < 0:
		return counter_position

	var store := _get_store_route_provider()

	if store != null and store.has_method("get_npc_queue_target"):
		var result: Variant = store.call("get_npc_queue_target", position_in_queue, counter_position)

		if result is Vector2:
			return result as Vector2

	return NPCQueueSystem.get_queue_target(current_queue, self, counter_position)


func _return_item_to_shelf() -> void:
	if not _cart_items.is_empty():
		_return_cart_items_to_shelf()
		return

	var item: ItemData = ItemDatabase.get_item(item_to_buy)

	if item == null:
		return

	for shelf in get_tree().get_nodes_in_group("shelves"):
		if shelf is Shelf and shelf.shelf_type == item.shelf_type:
			Inventory.add_item(item_to_buy)
			shelf.place_item(item_to_buy)
			return


func _find_matching_shelf() -> Shelf:
	return NPCShoppingBehavior.find_matching_shelf(get_tree(), item_to_buy)


func _find_reachable_matching_shelf() -> Shelf:
	for shelf in _get_matching_shelf_candidates():
		var visit_position := _get_shelf_visit_position(shelf)

		if visit_position.is_finite():
			return shelf

	return null


func _get_matching_shelf_candidates() -> Array[Shelf]:
	var stocked_shelves: Array[Shelf] = []
	var fallback_shelves: Array[Shelf] = []
	var item: ItemData = ItemDatabase.get_item(item_to_buy)

	if item == null:
		return []

	for shelf_node in get_tree().get_nodes_in_group("shelves"):
		var shelf := shelf_node as Shelf

		if shelf == null:
			continue

		if shelf.shelf_type != item.shelf_type:
			continue

		if shelf.has_item(item_to_buy):
			stocked_shelves.append(shelf)
		else:
			fallback_shelves.append(shelf)

	stocked_shelves.append_array(fallback_shelves)
	return stocked_shelves


func _find_shelf_with_item(item_id: String) -> Shelf:
	return NPCShoppingBehavior.find_shelf_with_item(get_tree(), item_id)


func _get_shelf_visit_position(shelf: Shelf) -> Vector2:
	var store := _get_store_route_provider()

	if store != null and store.has_method("get_npc_shelf_visit_position"):
		var result: Variant = store.call("get_npc_shelf_visit_position", shelf, self)

		if result is Vector2:
			return result as Vector2

	return NPCShoppingBehavior.get_shelf_visit_position(shelf, SHELF_VISIT_OFFSET)


func _refresh_shelf_visit_target() -> bool:
	if _target_shelf == null or not is_instance_valid(_target_shelf):
		return false

	var refreshed_position := _get_shelf_visit_position(_target_shelf)

	if not refreshed_position.is_finite():
		return false

	if refreshed_position.distance_to(target_position) <= 2.0:
		return false

	target_position = refreshed_position
	_movement_route.clear()
	_movement_route_destination = Vector2.INF
	return true


func _apply_scripted_metadata() -> void:
	shopping_list.clear()
	_cart_items.clear()
	checkout_total_override = -1
	checkout_outcome = "paid"

	if npc_data == null:
		return

	if npc_data.has_meta("shopping_list"):
		for item_id in npc_data.get_meta("shopping_list"):
			shopping_list.append(str(item_id))

	if npc_data.has_meta("checkout_total"):
		checkout_total_override = int(npc_data.get_meta("checkout_total"))

	if npc_data.has_meta("checkout_outcome"):
		checkout_outcome = str(npc_data.get_meta("checkout_outcome"))


func _has_any_requested_item_available() -> bool:
	for requested_item_id in _get_requested_items():
		if _find_shelf_with_item(requested_item_id) != null:
			return true

	return false


func _take_requested_items_from_shelves() -> bool:
	_cart_items.clear()

	for requested_item_id in _get_requested_items():
		var shelf := _find_shelf_with_item(requested_item_id)

		if shelf != null and shelf.take_item_for_npc(requested_item_id):
			_cart_items.append(requested_item_id)

	if not _cart_items.is_empty():
		item_to_buy = _cart_items[0]
		return true

	return false


func _get_requested_items() -> Array[String]:
	return NPCShoppingBehavior.get_requested_items(shopping_list, item_to_buy)


func _return_cart_items_to_shelf() -> void:
	for cart_item_id in _cart_items:
		var item: ItemData = ItemDatabase.get_item(cart_item_id)

		if item == null:
			continue

		for shelf in get_tree().get_nodes_in_group("shelves"):
			if shelf is Shelf and shelf.shelf_type == item.shelf_type:
				shelf.stock_item_direct(cart_item_id)
				break

	_cart_items.clear()


func _finish_checkout_and_exit() -> void:
	_dialog_timer = DIALOG_DURATION
	_leave_queue()
	_target_shelf = null
	target_position = _get_exit_position()
	_set_state(State.EXIT)


func _set_state(new_state: State) -> void:
	if new_state == State.ENTER:
		_enter_pause_timer = 0.0

	if new_state == State.SEARCH_ITEM:
		_search_timer = 0.0
		_search_announced = false

	if new_state == State.TAKE_ITEM:
		_take_item_pause_timer = 0.0
		_has_taken_shelf_item = false

	if new_state == State.CHECKOUT:
		_checkout_timer = 0.0

	if new_state == State.EXIT:
		_leave_queue()
		_target_shelf = null

	_movement_route.clear()
	_movement_route_destination = Vector2.INF
	_reset_stuck_watchdog()
	current_state = new_state


func _show_dialog(text: String) -> void:
	NPCDialogController.show_dialog(self, npc_data, text)
	_dialog_timer = DIALOG_DURATION


func _update_dialog(delta: float) -> void:
	if _dialog_timer <= 0.0:
		return

	_dialog_timer -= delta

	if _dialog_timer > 0.0:
		return

	_hide_dialog()


func _hide_dialog() -> void:
	NPCDialogController.hide_dialog(self)


func _set_dialog_mouse_filter() -> void:
	NPCDialogController.set_mouse_filter(self)
