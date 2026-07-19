extends "res://scripts/npc/runtime/NPCLiveQueueStateFlow.gd"

const GoobyDebugTraceScript = preload(
	"res://scripts/npc/runtime/GoobyDebugTrace.gd"
)

var _enter_snapshot_logged: bool = false


func process_enter() -> void:
	if not _enter_snapshot_logged:
		_enter_snapshot_logged = true
		GoobyDebugTraceScript.emit_npc(
			npc,
			"enter_evaluation_before",
			{
				"npc": GoobyDebugTraceScript.npc_snapshot(npc),
				"shelves": GoobyDebugTraceScript.shelf_snapshot(npc)
			}
		)

	super.process_enter()


func set_state(new_state: int) -> void:
	var previous_state: int = int(npc.current_state)
	var before := GoobyDebugTraceScript.npc_snapshot(npc)

	super.set_state(new_state)

	if previous_state == new_state:
		return

	GoobyDebugTraceScript.emit_npc(
		npc,
		"state_transition",
		{
			"from": GoobyDebugTraceScript.state_name(previous_state),
			"to": GoobyDebugTraceScript.state_name(new_state),
			"before": before,
			"after": GoobyDebugTraceScript.npc_snapshot(npc)
		}
	)


func _begin_wait_for_shelf(reason: String) -> void:
	GoobyDebugTraceScript.emit_npc(
		npc,
		"begin_wait_for_shelf",
		{
			"reason": reason,
			"npc": GoobyDebugTraceScript.npc_snapshot(npc),
			"shelves": GoobyDebugTraceScript.shelf_snapshot(npc)
		}
	)
	
	super._begin_wait_for_shelf(reason)


func complete_exit() -> void:
	GoobyDebugTraceScript.emit_npc(
		npc,
		"complete_exit_requested",
		{
			"npc": GoobyDebugTraceScript.npc_snapshot(npc),
			"distance_to_exit_target": npc.global_position.distance_to(
				npc.target_position
			)
		}
	)

	super.complete_exit()
