class_name StoreNavigationService
extends RefCounted

const RequestScript = preload(
	"res://scripts/navigation/store/StoreNavigationRequest.gd"
)
const CostPolicyScript = preload(
	"res://scripts/navigation/store/StoreNavigationCostPolicy.gd"
)
const ObstacleTrackerScript = preload(
	"res://scripts/navigation/store/StoreDynamicObstacleTracker.gd"
)
const SemanticGraphScript = preload(
	"res://scripts/navigation/store/StoreSemanticGraph.gd"
)
const ThetaStarScript = preload(
	"res://scripts/navigation/store/StoreThetaStarPlanner.gd"
)
const ReverseDijkstraScript = preload(
	"res://scripts/navigation/store/StoreReverseDijkstraCache.gd"
)
const DStarLiteScript = preload(
	"res://scripts/navigation/store/StoreDStarLitePlanner.gd"
)
const LocalAvoidanceScript = preload(
	"res://scripts/navigation/store/StoreLocalAvoidance.gd"
)
const RouteCacheScript = preload(
	"res://scripts/navigation/store/StoreRouteCache.gd"
)

const CONNECTOR_LIMIT: int = 3
const ROUTE_POINT_EPSILON: float = 2.0

var _store: Node2D = null
var _marker_root: Node2D = null
var _legacy_graph = null
var _anchors: Array[Vector2] = []
var _anchor_signature: String = ""

var _policy: StoreNavigationCostPolicy = CostPolicyScript.new()
var _obstacles: StoreDynamicObstacleTracker = ObstacleTrackerScript.new()
var _semantic: StoreSemanticGraph = SemanticGraphScript.new()
var _theta: StoreThetaStarPlanner = ThetaStarScript.new()
var _reverse: StoreReverseDijkstraCache = ReverseDijkstraScript.new()
var _avoidance: StoreLocalAvoidance = LocalAvoidanceScript.new()
var _route_cache: StoreRouteCache = RouteCacheScript.new()
var _dstar_by_goal: Dictionary = {}
var _last_changed_nodes: Array[StringName] = []
var _last_dirty_regions: Array[Rect2] = []
var _initialized: bool = false


func setup(
	store: Node2D,
	marker_root: Node2D,
	legacy_graph,
	anchors: Array[Vector2]
) -> void:
	var store_changed := _store != store or _marker_root != marker_root
	_store = store
	_marker_root = marker_root
	_legacy_graph = legacy_graph

	var next_anchor_signature := _make_anchor_signature(anchors)
	var anchors_changed := next_anchor_signature != _anchor_signature
	if anchors_changed:
		_anchor_signature = next_anchor_signature
		_anchors = anchors.duplicate()

	_last_dirty_regions = _obstacles.refresh(_store)
	_theta.setup(_store, _anchors, _obstacles)
	_semantic.setup(_marker_root, _anchors, _obstacles, _policy)
	_reverse.setup(_semantic)
	_avoidance.setup(_store, _theta)
	_route_cache.setup(_obstacles)

	if store_changed or anchors_changed:
		_route_cache.invalidate_all()
		_reverse.clear()
		_dstar_by_goal.clear()
		_theta.clear_dynamic_cache()

	_last_changed_nodes = _semantic.get_nodes_touching_regions(
		_last_dirty_regions
	)
	_initialized = true


func refresh_dynamic_state() -> void:
	if not _initialized:
		return
	var previous_revision := _obstacles.get_revision()
	_last_dirty_regions = _obstacles.refresh(_store)
	if _obstacles.get_revision() == previous_revision:
		_last_changed_nodes.clear()
		return

	_last_changed_nodes = _semantic.get_nodes_touching_regions(
		_last_dirty_regions
	)
	_theta.clear_dynamic_cache()
	_reverse.clear()
	_route_cache.invalidate_for_regions(_last_dirty_regions)


func plan(request: StoreNavigationRequest) -> Array[Vector2]:
	if not _initialized or request == null:
		return []
	refresh_dynamic_state()
	if not _resolve_request_goal(request):
		return []

	var revision := _obstacles.get_revision()
	var cache_key := "%s|top:%s|policy:%s" % [
		request.get_cache_key(_get_grid_spacing()),
		_semantic.get_topology_signature(),
		_policy.get_signature()
	]
	var cached := _route_cache.get_route(
		cache_key,
		request.start_position,
		revision
	)
	if not cached.is_empty():
		return cached

	var route := _plan_request_sequence(request)
	if not route.is_empty():
		_route_cache.put_route(
			cache_key,
			request.start_position,
			route,
			revision
		)
	return route


func plan_to_shelf(
	shelf: Shelf,
	start_position: Vector2,
	npc: Node = null
) -> Array[Vector2]:
	var request := RequestScript.new() as StoreNavigationRequest
	request.start_position = start_position
	request.goal_type = StoreNavigationRequest.GOAL_SHELF
	request.target_shelf = shelf
	request.npc = npc
	request.allow_direct = true
	request.force_semantic = false
	request.ignore_goal_collision = false
	return plan(request)


func plan_to_position(
	start_position: Vector2,
	goal_position: Vector2,
	npc: Node = null
) -> Array[Vector2]:
	var request := RequestScript.new() as StoreNavigationRequest
	request.start_position = start_position
	request.goal_position = goal_position
	request.goal_type = StoreNavigationRequest.GOAL_POSITION
	request.npc = npc
	request.allow_direct = true
	return plan(request)


func plan_to_queue(
	start_position: Vector2,
	queue_index: int,
	source_shelf: Shelf = null,
	npc: Node = null
) -> Array[Vector2]:
	var request := RequestScript.new() as StoreNavigationRequest
	request.start_position = start_position
	request.goal_type = StoreNavigationRequest.GOAL_QUEUE
	request.queue_index = maxi(0, queue_index)
	request.source_shelf = source_shelf
	request.npc = npc
	request.allow_direct = queue_index <= 0
	request.force_semantic = queue_index > 0
	request.avoid_queue_front = queue_index > 0
	request.ignore_goal_collision = true

	var approach_role := (
		&"queue_front_right"
		if queue_index <= 0
		else &"queue_back_right"
	)
	var approach_node := _semantic.get_node_for_role(
		approach_role,
		maxi(0, queue_index)
	)
	if approach_node != StringName():
		request.required_nodes.append(approach_node)
	return plan(request)


func plan_to_cashier(
	start_position: Vector2,
	npc: Node = null
) -> Array[Vector2]:
	return plan_to_queue(start_position, 0, null, npc)


func plan_to_exit(
	start_position: Vector2,
	npc: Node = null
) -> Array[Vector2]:
	var request := RequestScript.new() as StoreNavigationRequest
	request.start_position = start_position
	request.goal_type = StoreNavigationRequest.GOAL_EXIT
	request.npc = npc
	request.force_semantic = true
	request.allow_direct = false
	return plan(request)


func plan_checkout_exit(
	start_position: Vector2,
	npc: Node = null
) -> Array[Vector2]:
	var request := RequestScript.new() as StoreNavigationRequest
	request.start_position = start_position
	request.goal_type = StoreNavigationRequest.GOAL_EXIT
	request.npc = npc
	request.force_semantic = true
	request.allow_direct = false
	for role_and_index in [
		[&"queue_front_right", 0],
		[&"queue_back_right", 1],
		[&"queue_back_right", 2],
		[&"queue_exit_right", -1],
		[&"aisle_right", -1]
	]:
		var role := role_and_index[0] as StringName
		var queue_index := int(role_and_index[1])
		var node_id := _semantic.get_node_for_role(role, queue_index)
		if node_id != StringName():
			request.required_nodes.append(node_id)
	return plan(request)


func get_local_avoidance_adjustment(
	npc: NPC,
	desired_target: Vector2
) -> Dictionary:
	return _avoidance.get_adjustment(npc, desired_target)


func get_revision() -> int:
	return _obstacles.get_revision()


func invalidate_all() -> void:
	_route_cache.invalidate_all()
	_reverse.clear()
	_dstar_by_goal.clear()
	_theta.clear_dynamic_cache()


func _resolve_request_goal(request: StoreNavigationRequest) -> bool:
	match request.goal_type:
		StoreNavigationRequest.GOAL_SHELF:
			if (
				request.target_shelf == null
				or not is_instance_valid(request.target_shelf)
			):
				return false
			if _legacy_graph != null and not _legacy_graph.has_cached_shelf_access_metadata(
				request.target_shelf
			):
				_legacy_graph.store_shelf_access_metadata(
					request.target_shelf,
					request.target_shelf.global_position
				)
			request.goal_position = _legacy_graph.get_shelf_access_position(
				request.target_shelf
			)
			request.goal_id = StringName()
			return request.goal_position.is_finite()

		StoreNavigationRequest.GOAL_QUEUE:
			var role := &"queue_front" if request.queue_index <= 0 else &"queue_back"
			request.goal_id = _semantic.get_node_for_role(
				role,
				maxi(0, request.queue_index)
			)
			request.goal_position = _semantic.get_position(request.goal_id)
			return request.goal_id != StringName() and request.goal_position.is_finite()

		StoreNavigationRequest.GOAL_CASHIER:
			request.goal_id = _semantic.get_node_for_role(&"queue_front", 0)
			request.goal_position = _semantic.get_position(request.goal_id)
			return request.goal_id != StringName() and request.goal_position.is_finite()

		StoreNavigationRequest.GOAL_EXIT:
			request.goal_id = _semantic.get_node_for_role(&"exit")
			request.goal_position = _semantic.get_position(request.goal_id)
			return request.goal_id != StringName() and request.goal_position.is_finite()

		_:
			return request.goal_position.is_finite()


func _plan_request_sequence(
	request: StoreNavigationRequest
) -> Array[Vector2]:
	var route: Array[Vector2] = []
	var current_position := request.start_position
	var sequence := request.required_nodes.duplicate()
	if request.goal_id != StringName():
		if sequence.is_empty() or sequence.back() != request.goal_id:
			sequence.append(request.goal_id)

	for target_node in sequence:
		var target_position := _semantic.get_position(target_node)
		if not target_position.is_finite():
			return []
		var leg_request := request.duplicate_request()
		leg_request.start_position = current_position
		leg_request.goal_position = target_position
		leg_request.goal_id = target_node
		leg_request.required_nodes.clear()
		leg_request.force_semantic = true
		var leg := _plan_leg(leg_request)
		if leg.is_empty() and current_position.distance_to(target_position) > ROUTE_POINT_EPSILON:
			return []
		_append_route(route, leg)
		current_position = target_position

	if request.goal_id == StringName():
		var final_request := request.duplicate_request()
		final_request.start_position = current_position
		final_request.required_nodes.clear()
		var final_leg := _plan_leg(final_request)
		if final_leg.is_empty() and current_position.distance_to(request.goal_position) > ROUTE_POINT_EPSILON:
			return []
		_append_route(route, final_leg)

	return _dedupe_route(route)


func _plan_leg(request: StoreNavigationRequest) -> Array[Vector2]:
	var context := _make_planner_context(request)
	if request.allow_direct and not request.force_semantic:
		var direct_route := _theta.find_path(
			request.start_position,
			request.goal_position,
			context
		)
		if not direct_route.is_empty():
			return direct_route

	var start_connectors := _get_reachable_connectors(
		request.start_position,
		request,
		false
	)
	var goal_connectors: Array[StringName] = []
	if request.goal_id != StringName() and _semantic.has_node(request.goal_id):
		goal_connectors.append(request.goal_id)
	else:
		goal_connectors = _get_reachable_connectors(
			request.goal_position,
			request,
			true
		)
	if start_connectors.is_empty() or goal_connectors.is_empty():
		return _theta.find_path(
			request.start_position,
			request.goal_position,
			context
		)

	var best_route: Array[Vector2] = []
	var best_cost := INF
	for start_node in start_connectors:
		for goal_node in goal_connectors:
			var macro_path := _get_macro_path(
				start_node,
				goal_node,
				request,
				context
			)
			if macro_path.is_empty():
				continue
			var candidate := _materialize_macro_path(
				request.start_position,
				request.goal_position,
				macro_path,
				request,
				context
			)
			if candidate.is_empty():
				continue
			var candidate_cost := _policy.calculate_route_cost(
				request.start_position,
				candidate
			)
			if candidate_cost < best_cost:
				best_cost = candidate_cost
				best_route = candidate
	return best_route


func _get_reachable_connectors(
	position: Vector2,
	request: StoreNavigationRequest,
	is_goal: bool
) -> Array[StringName]:
	var result: Array[StringName] = []
	var candidates := _semantic.find_nearest_node_ids(
		position,
		CONNECTOR_LIMIT * 3,
		false
	)
	var context := _make_planner_context(request)
	for node_id in candidates:
		var node_position := _semantic.get_position(node_id)
		var connector_context := context.duplicate(true)
		connector_context["ignore_start_collision"] = not is_goal
		connector_context["ignore_goal_collision"] = is_goal
		if _theta.is_direct_path_clear(
			position,
			node_position,
			connector_context
		):
			result.append(node_id)
		if result.size() >= CONNECTOR_LIMIT:
			break
	return result


func _get_macro_path(
	start_node: StringName,
	goal_node: StringName,
	request: StoreNavigationRequest,
	context: Dictionary
) -> Array[StringName]:
	var revision := _obstacles.get_revision()
	var planner_context := context.duplicate(true)
	planner_context["goal_node"] = goal_node
	planner_context["policy_signature"] = _policy.get_signature()

	if request.allow_incremental_repair:
		var planner_key := "%s|aq%d|q%d" % [
			String(goal_node),
			int(request.avoid_queue_front),
			request.queue_index
		]
		if not _dstar_by_goal.has(planner_key):
			var planner := DStarLiteScript.new() as StoreDStarLitePlanner
			planner.setup(_semantic, _policy)
			_dstar_by_goal[planner_key] = planner
		var dstar := _dstar_by_goal[planner_key] as StoreDStarLitePlanner
		var repaired_path := dstar.get_path(
			start_node,
			goal_node,
			revision,
			planner_context,
			_last_changed_nodes
		)
		if not repaired_path.is_empty():
			return repaired_path

	if request.use_shared_goal_cache:
		return _reverse.get_path(
			start_node,
			goal_node,
			revision,
			planner_context
		)
	return []


func _materialize_macro_path(
	start_position: Vector2,
	goal_position: Vector2,
	macro_path: Array[StringName],
	request: StoreNavigationRequest,
	context: Dictionary
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var current_position := start_position
	for node_index in range(macro_path.size()):
		var node_position := _semantic.get_position(macro_path[node_index])
		var segment_context := context.duplicate(true)
		segment_context["ignore_start_collision"] = node_index == 0
		segment_context["ignore_goal_collision"] = false
		var segment := _theta.find_path(
			current_position,
			node_position,
			segment_context
		)
		if segment.is_empty() and current_position.distance_to(node_position) > ROUTE_POINT_EPSILON:
			return []
		_append_route(result, segment)
		current_position = node_position

	if current_position.distance_to(goal_position) > ROUTE_POINT_EPSILON:
		var final_context := context.duplicate(true)
		final_context["ignore_start_collision"] = false
		final_context["ignore_goal_collision"] = request.ignore_goal_collision
		var final_segment := _theta.find_path(
			current_position,
			goal_position,
			final_context
		)
		if final_segment.is_empty():
			return []
		_append_route(result, final_segment)
	return _dedupe_route(result)


func _make_planner_context(
	request: StoreNavigationRequest
) -> Dictionary:
	var context := request.get_policy_context()
	context["npc"] = request.npc
	context["agent_radius"] = request.agent_radius
	context["ignore_start_collision"] = request.ignore_start_collision
	context["ignore_goal_collision"] = request.ignore_goal_collision
	context["policy_signature"] = _policy.get_signature()
	if request.source_shelf != null and is_instance_valid(request.source_shelf):
		context["ignored_shelf"] = request.source_shelf
	return context


func _append_route(
	target: Array[Vector2],
	points: Array[Vector2]
) -> void:
	for point in points:
		if not point.is_finite():
			continue
		if not target.is_empty() and target.back().distance_to(point) <= ROUTE_POINT_EPSILON:
			continue
		target.append(point)


func _dedupe_route(route: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	_append_route(result, route)
	return result


func _get_grid_spacing() -> float:
	if _anchors.size() < 2:
		return 12.0
	var best := INF
	var sample_count := mini(_anchors.size(), 40)
	for a_index in range(sample_count):
		for b_index in range(a_index + 1, sample_count):
			var delta := _anchors[a_index] - _anchors[b_index]
			if absf(delta.x) > 0.1:
				best = minf(best, absf(delta.x))
			if absf(delta.y) > 0.1:
				best = minf(best, absf(delta.y))
	return 12.0 if best == INF else maxf(4.0, best)


func _make_anchor_signature(points: Array[Vector2]) -> String:
	if points.is_empty():
		return "empty"
	return "%d:%d:%d:%d:%d" % [
		points.size(),
		roundi(points.front().x),
		roundi(points.front().y),
		roundi(points.back().x),
		roundi(points.back().y)
	]
