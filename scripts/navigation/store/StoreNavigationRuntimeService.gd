class_name StoreNavigationRuntimeService
extends "res://scripts/navigation/store/StoreNavigationService.gd"

const RuntimeThetaScript = preload(
	"res://scripts/navigation/store/StoreThetaStarRuntimePlanner.gd"
)
const RuntimeSemanticScript = preload(
	"res://scripts/navigation/store/StoreRuntimeSemanticGraph.gd"
)
const DefaultCostPolicy = preload(
	"res://data/navigation/store_navigation_cost_policy.tres"
)
const MACRO_REPLAN_LIMIT: int = 5


func _init() -> void:
	_theta = RuntimeThetaScript.new()
	_semantic = RuntimeSemanticScript.new()
	var policy_copy := DefaultCostPolicy.duplicate(true)
	if policy_copy is StoreNavigationCostPolicy:
		_policy = policy_copy as StoreNavigationCostPolicy


func setup(
	store: Node2D,
	marker_root: Node2D,
	legacy_graph,
	anchors: Array[Vector2]
) -> void:
	var first_setup := not _initialized
	var store_changed := _store != store or _marker_root != marker_root
	_store = store
	_marker_root = marker_root
	_legacy_graph = legacy_graph

	var next_anchor_signature := _make_anchor_signature(anchors)
	var anchors_changed := next_anchor_signature != _anchor_signature
	if anchors_changed:
		_anchor_signature = next_anchor_signature
		_anchors = anchors.duplicate()

	if first_setup or store_changed or anchors_changed:
		_last_dirty_regions = _obstacles.refresh(_store)
		_theta.setup(_store, _anchors, _obstacles)
		_semantic.setup(_marker_root, _anchors, _obstacles, _policy)
		_reverse.setup(_semantic)
		_avoidance.setup(_store, _theta)
		_route_cache.setup(_obstacles)
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
	var dirty_regions := _obstacles.refresh(_store)
	if _obstacles.get_revision() == previous_revision:
		return

	_last_dirty_regions = dirty_regions
	_last_changed_nodes = _semantic.get_nodes_touching_regions(
		_last_dirty_regions
	)
	_theta.clear_dynamic_cache()
	_reverse.clear()
	_route_cache.invalidate_for_regions(_last_dirty_regions)


func plan(request: StoreNavigationRequest) -> Array[Vector2]:
	var route := super.plan(request)
	# All macro planners participating in this request have now seen the latest
	# dirty-node set. Later requests in the same revision can use the shared
	# reverse-Dijkstra field instead of repeatedly performing incremental repair.
	_last_changed_nodes.clear()
	return route


func get_revision() -> int:
	refresh_dynamic_state()
	return _obstacles.get_revision()


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
	request.ignore_goal_collision = true
	return plan(request)


func set_cost_policy(policy: StoreNavigationCostPolicy) -> void:
	if policy == null or _policy == policy:
		return
	_policy = policy
	if _initialized:
		_semantic.setup(
			_marker_root,
			_anchors,
			_obstacles,
			_policy
		)
		_reverse.clear()
		_dstar_by_goal.clear()
		_route_cache.invalidate_all()
		_theta.clear_dynamic_cache()


func should_repair_route(
	start_position: Vector2,
	route: Array[Vector2],
	built_revision: int
) -> bool:
	refresh_dynamic_state()
	if built_revision < 0:
		return true
	var current_revision := _obstacles.get_revision()
	if built_revision == current_revision:
		return false
	var dirty_regions := _obstacles.get_dirty_regions_since(built_revision)
	return _obstacles.route_intersects_regions(
		start_position,
		route,
		dirty_regions
	)


func get_dirty_regions_since(revision: int) -> Array[Rect2]:
	refresh_dynamic_state()
	return _obstacles.get_dirty_regions_since(revision)


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
		context["source_shelf"] = request.source_shelf
	if request.target_shelf != null and is_instance_valid(request.target_shelf):
		context["target_shelf"] = request.target_shelf
	return context


func _get_reachable_connectors(
	position: Vector2,
	request: StoreNavigationRequest,
	is_goal: bool
) -> Array[StringName]:
	var result: Array[StringName] = []
	var candidates := _semantic.find_nearest_node_ids(
		position,
		CONNECTOR_LIMIT * 4,
		false
	)
	var context := _make_planner_context(request)
	# Connector discovery always travels from the supplied position toward a
	# semantic node. When that position is a shelf goal, the target shelf is the
	# source obstacle for this reversed probe.
	context["ignore_start_collision"] = true
	context["ignore_goal_collision"] = false
	if is_goal and context.has("target_shelf"):
		context["source_shelf"] = context["target_shelf"]
		context.erase("target_shelf")

	for node_id in candidates:
		var node_position := _semantic.get_position(node_id)
		if position.distance_to(node_position) <= ROUTE_POINT_EPSILON:
			result.append(node_id)
		else:
			var connector_route := _theta.find_path(
				position,
				node_position,
				context
			)
			if not connector_route.is_empty():
				result.append(node_id)
		if result.size() >= CONNECTOR_LIMIT:
			break
	return result


func _plan_leg(request: StoreNavigationRequest) -> Array[Vector2]:
	var base_context := _make_planner_context(request)
	if request.allow_direct and not request.force_semantic:
		var direct_route := _theta.find_path(
			request.start_position,
			request.goal_position,
			base_context
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
			base_context
		)

	var best_route: Array[Vector2] = []
	var best_cost := INF
	for start_node in start_connectors:
		for goal_node in goal_connectors:
			var blocked_edges: Dictionary = {}
			for _attempt in range(MACRO_REPLAN_LIMIT):
				var attempt_context := base_context.duplicate(true)
				attempt_context["blocked_edges"] = blocked_edges
				var macro_path := _get_macro_path(
					start_node,
					goal_node,
					request,
					attempt_context
				)
				if macro_path.is_empty():
					break

				var materialized := _materialize_with_feedback(
					request.start_position,
					request.goal_position,
					macro_path,
					request,
					attempt_context
				)
				if bool(materialized.get("valid", false)):
					var candidate := _to_vector2_route(
						materialized.get("route", [])
					)
					var candidate_cost := _policy.calculate_route_cost(
						request.start_position,
						candidate
					)
					if candidate_cost < best_cost:
						best_cost = candidate_cost
						best_route = candidate
					break

				var failed_from := materialized.get(
					"failed_from",
					StringName()
				) as StringName
				var failed_to := materialized.get(
					"failed_to",
					StringName()
				) as StringName
				if failed_from == StringName() or failed_to == StringName():
					break
				blocked_edges[
					(_semantic as StoreRuntimeSemanticGraph).make_edge_key(
						failed_from,
						failed_to
					)
				] = true
	return best_route


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
	var blocked_signature := _get_blocked_edge_signature(planner_context)

	if (
		request.use_shared_goal_cache
		and _last_changed_nodes.is_empty()
		and blocked_signature == ""
	):
		var shared_path := _reverse.get_path(
			start_node,
			goal_node,
			revision,
			planner_context
		)
		if not shared_path.is_empty():
			return shared_path

	if request.allow_incremental_repair:
		var source_shelf_id := 0
		if request.source_shelf != null and is_instance_valid(request.source_shelf):
			source_shelf_id = request.source_shelf.get_instance_id()
		var planner_key := "%s|aq%d|q%d|s%d|r%d|b%s" % [
			String(goal_node),
			int(request.avoid_queue_front),
			request.queue_index,
			source_shelf_id,
			roundi(request.agent_radius * 10.0),
			blocked_signature
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

	if request.use_shared_goal_cache and blocked_signature == "":
		return _reverse.get_path(
			start_node,
			goal_node,
			revision,
			planner_context
		)
	return []


func _materialize_with_feedback(
	start_position: Vector2,
	goal_position: Vector2,
	macro_path: Array[StringName],
	request: StoreNavigationRequest,
	context: Dictionary
) -> Dictionary:
	var result: Array[Vector2] = []
	var current_position := start_position
	var previous_node := StringName()

	for node_index in range(macro_path.size()):
		var current_node := macro_path[node_index]
		var node_position := _semantic.get_position(current_node)
		var segment_context := context.duplicate(true)
		segment_context["ignore_start_collision"] = node_index == 0
		segment_context["ignore_goal_collision"] = false
		var segment := _theta.find_path(
			current_position,
			node_position,
			segment_context
		)
		if (
			segment.is_empty()
			and current_position.distance_to(node_position) > ROUTE_POINT_EPSILON
		):
			return {
				"valid": false,
				"failed_from": previous_node,
				"failed_to": current_node
			}
		_append_route(result, segment)
		current_position = node_position
		previous_node = current_node

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
			return {"valid": false}
		_append_route(result, final_segment)

	return {
		"valid": true,
		"route": _dedupe_route(result)
	}


func _get_blocked_edge_signature(context: Dictionary) -> String:
	var blocked_variant: Variant = context.get("blocked_edges", {})
	if not (blocked_variant is Dictionary):
		return ""
	var blocked_edges := blocked_variant as Dictionary
	var keys := PackedStringArray()
	for edge_key_variant in blocked_edges.keys():
		keys.append(str(edge_key_variant))
	keys.sort()
	return ",".join(keys)


func _to_vector2_route(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not (value is Array):
		return result
	for point_variant in value:
		if point_variant is Vector2:
			result.append(point_variant as Vector2)
	return result
