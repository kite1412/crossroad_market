extends "res://scripts/npc/runtime/NPCResolvedExitRouteController.gd"

const GoobyDebugTraceScript = preload(
	"res://scripts/npc/runtime/GoobyDebugTrace.gd"
)

var _last_route_key: String = ""


func build_movement_route(destination: Vector2) -> Array[Vector2]:
	var route := super.build_movement_route(destination)
	var route_key := "%s|%s|%s" % [
		GoobyDebugTraceScript.state_name(int(npc.current_state)),
		GoobyDebugTraceScript.vector(destination),
		str(GoobyDebugTraceScript.route_points(route))
	]

	if route_key != _last_route_key:
		_last_route_key = route_key
		GoobyDebugTraceScript.emit_npc(
			npc,
			"route_build",
			{
				"destination": GoobyDebugTraceScript.vector(destination),
				"distance_to_destination": npc.global_position.distance_to(
					destination
				),
				"route_size": route.size(),
				"route": GoobyDebugTraceScript.route_points(route),
				"npc": GoobyDebugTraceScript.npc_snapshot(npc)
			}
		)

	return route


func update_stuck_watchdog(delta: float) -> void:
	var previous_state: int = int(npc.current_state)
	var previous_rebuilds: int = npc._stuck_watchdog_rebuilds
	var previous_target: Vector2 = npc.target_position

	super.update_stuck_watchdog(delta)

	if (
		previous_state == int(npc.current_state)
		and previous_rebuilds == npc._stuck_watchdog_rebuilds
		and previous_target.is_equal_approx(npc.target_position)
	):
		return

	GoobyDebugTraceScript.emit_npc(
		npc,
		"stuck_watchdog_action",
		{
			"previous_state": GoobyDebugTraceScript.state_name(
				previous_state
			),
			"current_state": GoobyDebugTraceScript.state_name(
				int(npc.current_state)
			),
			"previous_rebuilds": previous_rebuilds,
			"current_rebuilds": npc._stuck_watchdog_rebuilds,
			"previous_target": GoobyDebugTraceScript.vector(
				previous_target
			),
			"current_target": GoobyDebugTraceScript.vector(
				npc.target_position
			)
		}
	)
