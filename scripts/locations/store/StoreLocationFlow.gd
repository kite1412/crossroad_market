class_name StoreLocationFlow
extends Node


const STORE_ENTRY_FALLBACK_POSITION := Vector2(240, 204)
const STORE_STORAGE_RETURN_FALLBACK_POSITION := Vector2(383, 76)
const YARD_HOME_RETURN_FALLBACK_POSITION := Vector2(35, 525)

var store: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_game_in_yard() -> void:
	if store._yard_intro_shown:
		return

	if store.yard_scene == null:
		store._show_location_title_once("store", "Store")
		store.call_deferred("_show_morning_intro")
		return

	if store.player == null:
		store.player = store.get_node_or_null("Player") as Node2D

	if store.player == null:
		pass
		return

	store._current_yard = store.yard_scene.instantiate() as Node2D
	store.add_child(store._current_yard)
	store._current_yard.position = Vector2.ZERO
	store._current_yard.z_index = 100
	configure_yard_scene()
	store.open_close_board = null
	store._update_store_status_board(false)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spawn_marker := store._current_yard.get_node_or_null("PlayerSpawn") as Node2D
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spawn_position: Vector2 = spawn_marker.global_position if spawn_marker != null else Vector2(240, 136)

	store._set_store_world_active(false)
	StoreTransitionController.prepare_player_for_location(store.player, store._current_yard, spawn_position)
	store._show_location_title_once("yard", "Yard")
	store._show_yard_intro()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func connect_yard_return_signal() -> void:
	if store._current_yard == null:
		return

	if store._current_yard.has_signal("return_to_store"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var return_callable := Callable(store, "_on_yard_return")

		if not store._current_yard.is_connected("return_to_store", return_callable):
			store._current_yard.connect("return_to_store", return_callable)
	else:
		pass

	if store._current_yard.has_signal("enter_home"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var home_callable := Callable(store, "_on_yard_enter_home")

		if not store._current_yard.is_connected("enter_home", home_callable):
			store._current_yard.connect("enter_home", home_callable)
	else:
		pass


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func configure_yard_scene() -> void:
	connect_yard_return_signal()

	if store._current_yard != null and store._current_yard.has_signal("restock_delivery_collected"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var restock_collected_callable := Callable(store, "_on_yard_restock_delivery_collected")

		if not store._current_yard.is_connected("restock_delivery_collected", restock_collected_callable):
			store._current_yard.connect("restock_delivery_collected", restock_collected_callable)

	store._sync_restock_deliveries_to_yard()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func enter_storage() -> void:
	if store.storage_scene == null:
		pass
		return

	if store.player == null:
		store.player = store.get_node_or_null("Player") as Node2D

	if store.player == null:
		pass
		return

	store._is_transitioning = true
	store._cancel_restricted_drop_feedback()
	await store._fade_to_black()

	store._current_storage = store.storage_scene.instantiate() as Node2D
	store.add_child(store._current_storage)
	store._current_storage.position = Vector2.ZERO
	store._current_storage.z_index = 100

	if store._current_storage.has_method("set_entry_door"):
		store._current_storage.set_entry_door("storage")

	if store._current_storage.has_method("set_shelf_install_state"):
		store._current_storage.set_shelf_install_state(
			store._human_shelf_installed or store._is_player_carrying_shelf_named("ShelfHuman"),
			store._ghost_shelf_installed or store._is_player_carrying_shelf_named("ShelfGhost")
		)

	if store._current_storage.has_method("set_normal_supply_depleted"):
		store._current_storage.set_normal_supply_depleted(store._normal_supply_depleted)

	if store._current_storage.has_method("set_mystery_discovered"):
		store._current_storage.set_mystery_discovered(store._mystery_discovered)

	if store._current_storage.has_method("set_mystery_items_taken"):
		store._current_storage.set_mystery_items_taken(store._mystery_items_taken)

	if store._current_storage.has_method("set_mystery_supply_depleted"):
		store._current_storage.set_mystery_supply_depleted(store._mystery_supply_depleted)

	if store._current_storage.has_method("set_phantom_human_shelf_attempted"):
		store._current_storage.set_phantom_human_shelf_attempted(
			store._phantom_human_shelf_attempted
		)

	if store._current_storage.has_method("set_mystery_phase_unlocked"):
		store._current_storage.set_mystery_phase_unlocked(store._mystery_phase_unlocked)

	connect_storage_signals()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spawn_position := Vector2(42, 68)

	if store._current_storage.has_method("get_player_spawn_position"):
		spawn_position = store._current_storage.get_player_spawn_position()
	else:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var spawn_marker := store._current_storage.get_node_or_null("StorageMarkers/PlayerSpawn") as Node2D
		spawn_position = spawn_marker.global_position if spawn_marker != null else spawn_position

	store._set_store_world_active(false)
	StoreTransitionController.prepare_player_for_location(store.player, store._current_storage, spawn_position)

	await store._fade_from_black()
	store._show_location_title_once("storage", "Storage")
	store._is_transitioning = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func connect_storage_signals() -> void:
	if store._current_storage.has_signal("return_to_store"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var return_callable := Callable(store, "_on_storage_return")

		if not store._current_storage.is_connected("return_to_store", return_callable):
			store._current_storage.connect("return_to_store", return_callable)
	else:
		pass

	if store._current_storage.has_signal("mystery_discovered"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var mystery_callable := Callable(store, "_on_storage_mystery_discovered")

		if not store._current_storage.is_connected("mystery_discovered", mystery_callable):
			store._current_storage.connect("mystery_discovered", mystery_callable)

	if store._current_storage.has_signal("mystery_item_taken"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var mystery_item_callable := Callable(store, "_on_storage_mystery_item_taken")

		if not store._current_storage.is_connected("mystery_item_taken", mystery_item_callable):
			store._current_storage.connect("mystery_item_taken", mystery_item_callable)

	if store._current_storage.has_signal("mystery_supply_depleted"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var mystery_depleted_callable := Callable(store, "_on_storage_mystery_supply_depleted")

		if not store._current_storage.is_connected("mystery_supply_depleted", mystery_depleted_callable):
			store._current_storage.connect("mystery_supply_depleted", mystery_depleted_callable)

	if store._current_storage.has_signal("ghost_shelf_item_placed"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var ghost_shelf_callable := Callable(store, "_on_ghost_shelf_item_placed")

		if not store._current_storage.is_connected("ghost_shelf_item_placed", ghost_shelf_callable):
			store._current_storage.connect("ghost_shelf_item_placed", ghost_shelf_callable)

	if store._current_storage.has_signal("restock_order_purchased"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var restock_order_callable := Callable(store, "_on_storage_restock_order_purchased")

		if not store._current_storage.is_connected("restock_order_purchased", restock_order_callable):
			store._current_storage.connect("restock_order_purchased", restock_order_callable)

	if store._current_storage.has_signal("restock_panel_opened"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var restock_panel_opened_callable := Callable(store, "_on_storage_restock_panel_opened")

		if not store._current_storage.is_connected("restock_panel_opened", restock_panel_opened_callable):
			store._current_storage.connect("restock_panel_opened", restock_panel_opened_callable)

	if store._current_storage.has_signal("restock_panel_closed"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var restock_panel_closed_callable := Callable(store, "_on_storage_restock_panel_closed")

		if not store._current_storage.is_connected("restock_panel_closed", restock_panel_closed_callable):
			store._current_storage.connect("restock_panel_closed", restock_panel_closed_callable)

	if store._current_storage.has_signal("restock_item_purchased"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var restock_callable := Callable(store, "_on_storage_restock_item_purchased")

		if not store._current_storage.is_connected("restock_item_purchased", restock_callable):
			store._current_storage.connect("restock_item_purchased", restock_callable)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_storage_return(_door_type: String) -> void:
	if store._is_transitioning:
		return

	store._is_transitioning = true
	store._close_cashier_runtime_ui()
	await store._fade_to_black()

	if store.player == null and store._current_storage != null:
		store.player = store._current_storage.get_node_or_null("Player") as Node2D

	if store.player != null:
		StoreTransitionController.prepare_player_for_location(store.player, store, get_storage_return_position())
	else:
		pass

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var storage_to_remove: Node2D = store._current_storage

	if storage_to_remove != null:
		storage_to_remove.queue_free()

	store._set_store_world_active(true)
	store._current_storage = null
	store._setup_npc_static_data()
	store._update_objective()

	await store._fade_from_black()
	store._is_transitioning = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func enter_yard() -> void:
	if store.yard_scene == null:
		pass
		return

	if store.player == null:
		store.player = store.get_node_or_null("Player") as Node2D

	if store.player == null:
		pass
		return

	store._is_transitioning = true
	store._cancel_restricted_drop_feedback()
	store._close_cashier_runtime_ui()
	await store._fade_to_black()

	store._current_yard = store.yard_scene.instantiate() as Node2D
	store.add_child(store._current_yard)
	store._current_yard.position = Vector2.ZERO
	store._current_yard.z_index = 100
	configure_yard_scene()
	store.open_close_board = null
	store._update_store_status_board(false)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spawn_marker := store._current_yard.get_node_or_null("PlayerSpawn") as Node2D
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spawn_position: Vector2 = spawn_marker.global_position if spawn_marker != null else Vector2(240, 136)

	store._set_store_world_active(false)
	StoreTransitionController.prepare_player_for_location(store.player, store._current_yard, spawn_position)

	await store._fade_from_black()
	store._show_location_title_once("yard", "Yard")
	store._is_transitioning = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_yard_return(_door_type: String) -> void:
	if store._is_transitioning:
		return

	store._is_transitioning = true
	await store._fade_to_black()

	if store.player == null and store._current_yard != null:
		store.player = store._current_yard.get_node_or_null("Player") as Node2D

	if store.player != null:
		StoreTransitionController.prepare_player_for_location(store.player, store, get_yard_return_position())
	else:
		pass

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var yard_to_remove: Node2D = store._current_yard

	if yard_to_remove != null:
		yard_to_remove.queue_free()

	store._set_store_world_active(true)
	store._current_yard = null
	store.open_close_board = null
	store._setup_npc_static_data()
	store._update_objective()

	await store._fade_from_black()
	store._is_transitioning = false

	if store._pending_store_intro_after_yard:
		store._pending_store_intro_after_yard = false
		store._show_location_title_once("store", "Store")
		store.call_deferred("_show_morning_intro")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_yard_enter_home() -> void:
	if store._is_transitioning:
		return
	
	if store.tax_flow != null:
		store.tax_flow.on_player_entered_home()

	enter_home()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func enter_home() -> void:
	if store.home_scene == null:
		pass
		return

	if store.player == null and store._current_yard != null:
		store.player = store._current_yard.get_node_or_null("Player") as Node2D

	if store.player == null:
		pass
		return

	store._is_transitioning = true
	store._cancel_restricted_drop_feedback()
	await store._fade_to_black()

	store._current_home = store.home_scene.instantiate() as Node2D
	store.add_child(store._current_home)
	store._current_home.position = Vector2.ZERO
	store._current_home.z_index = 100

	if store._current_home.has_signal("return_to_yard"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var return_callable := Callable(store, "_on_home_return_to_yard")

		if not store._current_home.is_connected("return_to_yard", return_callable):
			store._current_home.connect("return_to_yard", return_callable)
	else:
		pass

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spawn_marker := store._current_home.get_node_or_null("PlayerSpawn") as Node2D
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spawn_position: Vector2 = spawn_marker.global_position if spawn_marker != null else Vector2(240, 210)

	store._set_store_world_active(false)
	StoreTransitionController.prepare_player_for_location(store.player, store._current_home, spawn_position)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var yard_to_remove: Node2D = store._current_yard

	if yard_to_remove != null:
		yard_to_remove.queue_free()

	store._current_yard = null
	store.open_close_board = null

	await store._fade_from_black()
	store._show_location_title_once("home", "Home")
	store._is_transitioning = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_home_return_to_yard(_door_type: String) -> void:
	if store._is_transitioning:
		return

	if store.yard_scene == null:
		pass
		return

	store._is_transitioning = true
	await store._fade_to_black()

	if store.player == null and store._current_home != null:
		store.player = store._current_home.get_node_or_null("Player") as Node2D

	store._current_yard = store.yard_scene.instantiate() as Node2D
	store.add_child(store._current_yard)
	store._current_yard.position = Vector2.ZERO
	store._current_yard.z_index = 100
	configure_yard_scene()
	store.open_close_board = null
	store._update_store_status_board(false)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spawn_marker := store._current_yard.get_node_or_null("YardObjects/PlayerHouse/HomeReturnSpawn") as Node2D
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spawn_position: Vector2 = spawn_marker.global_position if spawn_marker != null else YARD_HOME_RETURN_FALLBACK_POSITION

	if store.player != null:
		StoreTransitionController.prepare_player_for_location(store.player, store._current_yard, spawn_position)
	else:
		pass

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var home_to_remove: Node2D = store._current_home

	if home_to_remove != null:
		home_to_remove.queue_free()

	store._current_home = null
	store._set_store_world_active(false)

	await store._fade_from_black()
	store._show_location_title_once("yard", "Yard")
	store._is_transitioning = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_storage_return_position() -> Vector2:
	if store == null:
		return STORE_STORAGE_RETURN_FALLBACK_POSITION

	if store.storage_return_pos != null:
		return store.storage_return_pos.global_position

	if store.storage_door != null:
		return store.storage_door.global_position + Vector2(0, 44)

	return STORE_STORAGE_RETURN_FALLBACK_POSITION


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_yard_return_position() -> Vector2:
	if store == null:
		return STORE_ENTRY_FALLBACK_POSITION

	if store.store_entry_pos != null:
		return store.store_entry_pos.global_position

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var structure_bottom := store.get_node_or_null("StoreStructure/Boundaries/Bottom/CollisionShape2D") as CollisionShape2D
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var bottom_shape: RectangleShape2D = null

	if structure_bottom != null:
		bottom_shape = structure_bottom.shape as RectangleShape2D

	if structure_bottom != null and bottom_shape != null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var player_bottom_offset := 30.0
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var player_collision: CollisionShape2D = null
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var player_shape: RectangleShape2D = null

		if store.player != null:
			player_collision = store.player.get_node_or_null("CollisionShape2D") as CollisionShape2D

		if player_collision != null:
			player_shape = player_collision.shape as RectangleShape2D

		if player_collision != null and player_shape != null:
			player_bottom_offset = player_collision.position.y + player_shape.size.y * 0.5

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var structure_center_x := 240.0
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var base_floor := store.get_node_or_null("StoreStructure/BaseFloor") as Node2D

		if base_floor != null:
			structure_center_x = base_floor.global_position.x

		return Vector2(
			structure_center_x,
			structure_bottom.global_position.y - bottom_shape.size.y * 0.5 - player_bottom_offset - 1.0
		)

	if store.yard_door != null:
		return store.yard_door.global_position + Vector2(0, -47)

	return STORE_ENTRY_FALLBACK_POSITION
