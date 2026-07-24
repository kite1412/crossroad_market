class_name StoreNpcRuntime
extends Node

const NPCResolvedExitRouteController = preload("res://scripts/npc/runtime/NPCResolvedExitRouteController.gd")
const NPCLiveQueueStateFlow = preload("res://scripts/npc/runtime/NPCLiveQueueStateFlow.gd")
const NPCReachableShelfShoppingFlow = preload("res://scripts/npc/runtime/NPCReachableShelfShoppingFlow.gd")
const NPCCheckoutLaneQueueFlow = preload("res://scripts/npc/runtime/NPCCheckoutLaneQueueFlow.gd")
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")
const CUSTOMER_INTAKE_CLOSED_META: StringName = &"customer_intake_closed_today"
const MAX_NPC_ACTIVATIONS_PER_FRAME: int = 2
const NPC_ACTIVATION_STAGGER_MSEC: int = 16

var store: Node = null
var _pending_npc_activations: Array[Dictionary] = []


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

	_pending_npc_activations.append({
		"npc_data": npc_data,
		"ready_msec": Time.get_ticks_msec() + _get_activation_delay_msec(npc_data)
	})


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_npc_runtime(_delta: float) -> void:
	var activated_count: int = 0
	var now_msec: int = Time.get_ticks_msec()
	var index: int = 0

	while index < _pending_npc_activations.size():
		if activated_count >= MAX_NPC_ACTIVATIONS_PER_FRAME:
			return

		var request: Dictionary = _pending_npc_activations[index]
		if now_msec < int(request.get("ready_msec", 0)):
			index += 1
			continue
		if is_customer_spawn_blocked_by_shelf_layout():
			_record_customer_spawn_probe(&"customer_spawn_blocked_by_shelf_layout")
			index += 1
			continue

		_pending_npc_activations.remove_at(index)
		_spawn_admitted_npc(request.get("npc_data", null) as NPCData)
		activated_count += 1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _spawn_admitted_npc(npc_data: NPCData) -> void:
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

	_spawn_customer_instance(npc_data)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func spawn_story_customer(npc_data: NPCData) -> NPC:
	if store == null or npc_data == null:
		return null
	if not is_store_world_available_for_customer_spawn():
		return null
	return _spawn_customer_instance(npc_data)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _spawn_customer_instance(npc_data: NPCData) -> NPC:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var npc := StoreNpcSpawner.spawn_npc(
		store,
		store.npc_scene,
		get_npc_spawn_marker(),
		npc_data,
		Callable(self, "on_npc_purchase"),
		Callable(self, "on_npc_exited")
	)
	if npc != null:
		install_shelf_arrival_controllers(npc)
		# Re-enter through the freshly installed store-specific controllers.
		# This keeps forced story follow-ups on the exact same shopping flow as
		# scheduled customers and guarantees physics was not inherited disabled.
		npc.velocity = Vector2.ZERO
		npc.set_process(true)
		npc.set_physics_process(true)
		npc._set_state(NPC.State.ENTER)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var route_ready_callable := Callable(
			self,
			"on_npc_shelf_route_ready"
		)

		if not npc.shelf_route_ready.is_connected(route_ready_callable):
			npc.shelf_route_ready.connect(route_ready_callable)

	return npc


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_activation_delay_msec(npc_data: NPCData) -> int:
	if npc_data == null:
		return 0

	var stable_key: int = abs(hash(npc_data.resource_path))
	return (stable_key % 10) * NPC_ACTIVATION_STAGGER_MSEC


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
func is_customer_spawn_blocked_by_shelf_layout() -> bool:
	if store == null:
		return false
	if store.has_method("_get_carried_object_from_player"):
		if store.call("_get_carried_object_from_player") != null:
			return true

	for node in store.get_tree().get_nodes_in_group("shelves"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_meta("npc_path_pending") and bool(node.get_meta("npc_path_pending")):
			return true
		if node.has_meta("pending_shelf_access_update_token"):
			return true

	return false


func _record_customer_spawn_probe(label: StringName) -> void:
	var context: Dictionary = {
		"carried_object": "",
		"pending_shelves": 0
	}
	if store != null and store.has_method("_get_carried_object_from_player"):
		var carried_variant: Variant = store.call("_get_carried_object_from_player")
		if carried_variant is Node:
			context["carried_object"] = (carried_variant as Node).name

	if store != null:
		for node in store.get_tree().get_nodes_in_group("shelves"):
			if node == null or not is_instance_valid(node):
				continue
			if (
				(node.has_meta("npc_path_pending") and bool(node.get_meta("npc_path_pending")))
				or node.has_meta("pending_shelf_access_update_token")
			):
				context["pending_shelves"] = int(context["pending_shelves"]) + 1

	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func install_shelf_arrival_controllers(npc: NPC) -> void:
	if npc == null or not is_instance_valid(npc):
		return

	# Install the store-specific movement, shelf-exit, live queue, and lazy
	# shelf-access refresh behavior for every store customer.
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
