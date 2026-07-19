class_name StoreNpcRuntime
extends Node

const StoreNpcSpawner = preload("res://scripts/locations/store/StoreNpcSpawner.gd")
const NPCResolvedExitRouteController = preload("res://scripts/npc/runtime/NPCResolvedExitRouteController.gd")
const NPCLiveQueueStateFlow = preload("res://scripts/npc/runtime/NPCLiveQueueStateFlow.gd")
const NPCCheckoutLaneQueueFlow = preload("res://scripts/npc/runtime/NPCCheckoutLaneQueueFlow.gd")
const GoobyDebugTraceScript = preload("res://scripts/npc/runtime/GoobyDebugTrace.gd")
const GoobyDebugStateFlow = preload("res://scripts/npc/runtime/GoobyDebugStateFlow.gd")
const GoobyDebugRouteController = preload("res://scripts/npc/runtime/GoobyDebugRouteController.gd")
const CUSTOMER_INTAKE_CLOSED_META: StringName = &"customer_intake_closed_today"

var store: Node = null


func setup(store_node: Node) -> void:
	store = store_node


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


func on_npc_spawn_requested(npc_data: NPCData) -> void:
	var is_gooby_request := GoobyDebugTraceScript.is_gooby_data(npc_data)

	if store == null:
		if is_gooby_request:
			GoobyDebugTraceScript.emit_data(
				"spawn_request_blocked",
				{
					"reason": "store_null",
					"npc_data": GoobyDebugTraceScript.data_snapshot(
						npc_data
					)
				}
			)
		return

	var intake_closed := bool(
		store.get_meta(CUSTOMER_INTAKE_CLOSED_META, false)
	)

	if is_gooby_request:
		GoobyDebugTraceScript.emit_data(
			"spawn_request_received",
			{
				"npc_data": GoobyDebugTraceScript.data_snapshot(npc_data),
				"store_open": store._store_open,
				"customer_intake_closed": intake_closed,
				"current_home_present": store._current_home != null,
				"spawn_marker": (
					GoobyDebugTraceScript.vector(
						get_npc_spawn_marker().global_position
					)
					if get_npc_spawn_marker() != null
					else "<none>"
				)
			}
		)

	# Protect against scheduler requests emitted on the same frame the board
	# is closed, and against reopening the board after the day's customer
	# intake has already been finalized.
	if not store._store_open or intake_closed:
		if is_gooby_request:
			GoobyDebugTraceScript.emit_data(
				"spawn_request_blocked",
				{
					"reason": (
						"store_closed"
						if not store._store_open
						else "customer_intake_closed"
					)
				}
			)
		return

	if store._current_home != null:
		if is_gooby_request:
			GoobyDebugTraceScript.emit_data(
				"spawn_request_blocked",
				{"reason": "player_in_home"}
			)
		return

	var npc := StoreNpcSpawner.spawn_npc(
		store,
		store.npc_scene,
		get_npc_spawn_marker(),
		npc_data,
		Callable(self, "on_npc_purchase"),
		Callable(self, "on_npc_exited")
	)

	if npc == null:
		if is_gooby_request:
			GoobyDebugTraceScript.emit_data(
				"spawn_failed",
				{"npc_data": GoobyDebugTraceScript.data_snapshot(npc_data)}
			)
		return

	install_shelf_arrival_controllers(npc)

	var route_ready_callable := Callable(
		self,
		"on_npc_shelf_route_ready"
	)

	if not npc.shelf_route_ready.is_connected(route_ready_callable):
		npc.shelf_route_ready.connect(route_ready_callable)


func install_shelf_arrival_controllers(npc: NPC) -> void:
	if npc == null or not is_instance_valid(npc):
		return

	var is_gooby := GoobyDebugTraceScript.is_gooby(npc)

	# Install the store-specific movement, shelf-exit, and live queue behavior.
	if is_gooby:
		npc._route_controller = GoobyDebugRouteController.new()
		npc._state_flow = GoobyDebugStateFlow.new()
	else:
		npc._route_controller = NPCResolvedExitRouteController.new()
		npc._state_flow = NPCLiveQueueStateFlow.new()

	npc._route_controller.setup(npc)
	npc._state_flow.setup(npc)
	npc._queue_flow = NPCCheckoutLaneQueueFlow.new()
	npc._queue_flow.setup(npc)

	if not is_gooby:
		return

	var tree_exiting_callable := Callable(
		self,
		"_on_gooby_tree_exiting"
	).bind(npc)
	if not npc.tree_exiting.is_connected(tree_exiting_callable):
		npc.tree_exiting.connect(
			tree_exiting_callable,
			CONNECT_ONE_SHOT
		)

	GoobyDebugTraceScript.emit_npc(
		npc,
		"spawn_setup_complete",
		{
			"npc_data": GoobyDebugTraceScript.data_snapshot(npc.npc_data),
			"npc": GoobyDebugTraceScript.npc_snapshot(npc),
			"shelves": GoobyDebugTraceScript.shelf_snapshot(npc),
			"state_controller": "GoobyDebugStateFlow",
			"route_controller": "GoobyDebugRouteController"
		}
	)


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


func on_npc_purchase(
	npc: NPC,
	item_id: String,
	price: int
) -> void:
	if GoobyDebugTraceScript.is_gooby(npc):
		GoobyDebugTraceScript.emit_npc(
			npc,
			"purchase_completed_signal",
			{
				"item_id": item_id,
				"price": price,
				"npc": GoobyDebugTraceScript.npc_snapshot(npc)
			}
		)

	if store == null:
		return

	EconomyManager.add_gold(price)

	if price > 0:
		store._show_task_complete_notice(
			"normal_customer_served",
			"First customer served."
		)


func on_npc_exited(npc: NPC) -> void:
	if GoobyDebugTraceScript.is_gooby(npc):
		GoobyDebugTraceScript.emit_npc(
			npc,
			"npc_exited_signal",
			{"npc": GoobyDebugTraceScript.npc_snapshot(npc)}
		)

	if store != null:
		store._update_end_day_tax_flow()


func on_npc_shelf_route_ready(
	npc: NPC,
	travel_seconds: float
) -> void:
	if GoobyDebugTraceScript.is_gooby(npc):
		GoobyDebugTraceScript.emit_npc(
			npc,
			"shelf_route_ready_signal",
			{
				"travel_seconds": travel_seconds,
				"npc": GoobyDebugTraceScript.npc_snapshot(npc)
			}
		)

	NPCScheduler.notify_npc_shelf_route_ready(
		npc,
		travel_seconds
	)


func _on_gooby_tree_exiting(npc: NPC) -> void:
	GoobyDebugTraceScript.emit_npc(
		npc,
		"tree_exiting",
		{"npc": GoobyDebugTraceScript.npc_snapshot(npc)}
	)
