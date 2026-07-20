class_name StoreNpcRuntime
extends Node

const NPCResolvedExitRouteController = preload("res://scripts/debug/NPCQueueDebugRouteController.gd")
const NPCLiveQueueStateFlow = preload("res://scripts/debug/NPCEntryDebugStateFlow.gd")
const NPCReachableShelfShoppingFlow = preload("res://scripts/debug/NPCEntryDebugShoppingFlow.gd")
const NPCCheckoutLaneQueueFlow = preload("res://scripts/npc/runtime/NPCCheckoutLaneQueueFlow.gd")
const CUSTOMER_INTAKE_CLOSED_META: StringName = &"customer_intake_closed_today"
const DEBUG_NPC_SPAWN_PROFILE: bool = true

var store: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup_static_data() -> void:
	if store == null:
		return

	if store.npc_queue_marker != null:
		NPC.counter_position = store.npc_queue_marker.global_position
	elif store.counter_pos != null:
		NPC.counter_position = store.counter_pos.global_position

	if store.entrance_pos != null:
		NPC.entrance_position = store.entrance_pos.global_position

	if store.npc_enter_store_marker != null:
		NPC.entrance_position = store.npc_enter_store_marker.global_position
	elif store.npc_exit_marker != null:
		NPC.entrance_position = store.npc_exit_marker.global_position

	if store.npc_exit_marker != null:
		NPC.exit_position = store.npc_exit_marker.global_position
	elif store.entrance_pos != null:
		NPC.exit_position = store.entrance_pos.global_position

	if store.npc_store_path_marker != null:
		NPC.store_path_position = store.npc_store_path_marker.global_position
	else:
		NPC.store_path_position = Vector2.INF


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_npc_spawn_requested(npc_data: NPCData) -> void:
	if store == null:
		return

	# Scheduler signals remain connected while the Store scene is suspended.
	# Never instantiate a customer behind Storage, Yard, Home, or a fade
	# transition because that NPC would not receive a valid visibility snapshot.
	if not is_store_world_available_for_customer_spawn():
		return

	# Protect against scheduler requests emitted on the same frame the board
	# is closed, and against reopening the board after the day's customer
	# intake has already been finalized.
	if (
		not store._store_open
		or bool(
			store.get_meta(
				CUSTOMER_INTAKE_CLOSED_META,
				false
			)
		)
	):
		return

	var total_started_usec := Time.get_ticks_usec()
	var spawn_started_usec := total_started_usec
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var npc := StoreNpcSpawner.spawn_npc(
		store,
		store.npc_scene,
		get_npc_spawn_marker(),
		npc_data,
		Callable(self, "on_npc_purchase"),
		Callable(self, "on_npc_exited")
	)
	var spawn_elapsed_msec := float(
		Time.get_ticks_usec() - spawn_started_usec
	) / 1000.0
	var install_elapsed_msec := 0.0

	if npc != null:
		var install_started_usec := Time.get_ticks_usec()
		install_shelf_arrival_controllers(npc)
		install_elapsed_msec = float(
			Time.get_ticks_usec() - install_started_usec
		) / 1000.0

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var route_ready_callable := Callable(
			self,
			"on_npc_shelf_route_ready"
		)

		if not npc.shelf_route_ready.is_connected(route_ready_callable):
			npc.shelf_route_ready.connect(route_ready_callable)

	if DEBUG_NPC_SPAWN_PROFILE:
		var total_elapsed_msec := float(
			Time.get_ticks_usec() - total_started_usec
		) / 1000.0
		print(
			"[NPC_SPAWN_PROFILE] npc=%s spawn_ms=%.3f install_ms=%.3f total_ms=%.3f"
			% [
				_get_npc_data_label(npc_data),
				spawn_elapsed_msec,
				install_elapsed_msec,
				total_elapsed_msec
			]
		)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_store_world_available_for_customer_spawn() -> bool:
	return (
		bool(store._is_store_world_active)
		and not bool(store._is_transitioning)
		and store._current_storage == null
		and store._current_yard == null
		and store._current_home == null
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func install_shelf_arrival_controllers(npc: NPC) -> void:
	if npc == null or not is_instance_valid(npc):
		return

	# Install debug wrappers around the same production implementations. The
	# wrappers only measure and print; state and route results come from super.
	npc._route_controller = NPCResolvedExitRouteController.new()
	npc._route_controller.setup(npc)
	npc._state_flow = NPCLiveQueueStateFlow.new()
	npc._state_flow.setup(npc)
	npc._shopping_flow = NPCReachableShelfShoppingFlow.new()
	npc._shopping_flow.setup(npc)
	npc._queue_flow = NPCCheckoutLaneQueueFlow.new()
	npc._queue_flow.setup(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_npc_spawn_marker() -> Marker2D:
	if store == null:
		return null

	if store.npc_enter_store_marker != null:
		return store.npc_enter_store_marker

	if store.npc_entry_marker != null:
		return store.npc_entry_marker

	if store.npc_exit_marker != null:
		return store.npc_exit_marker

	return store.entrance_pos


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_npc_purchase(
	_npc: NPC,
	_item_id: String,
	price: int
) -> void:
	if store == null:
		return

	EconomyManager.add_gold(price)

	if price > 0:
		store._show_task_complete_notice(
			"normal_customer_served",
			"First customer served."
		)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_npc_exited(_npc: NPC) -> void:
	if store != null:
		store._update_end_day_tax_flow()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_npc_shelf_route_ready(
	npc: NPC,
	travel_seconds: float
) -> void:
	NPCScheduler.notify_npc_shelf_route_ready(
		npc,
		travel_seconds
	)


func _get_npc_data_label(npc_data: NPCData) -> String:
	if npc_data == null:
		return "<null>"
	if npc_data.npc_id != "":
		return npc_data.npc_id
	return str(npc_data.resource_path)
