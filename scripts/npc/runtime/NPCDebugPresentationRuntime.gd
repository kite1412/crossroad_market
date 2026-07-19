extends "res://scripts/npc/runtime/NPCPresentationRuntime.gd"

const NPCStoreDebugTraceScript = preload(
	"res://scripts/npc/runtime/NPCStoreDebugTrace.gd"
)


func show_dialog(text: String) -> void:
	var started_usec := Time.get_ticks_usec()
	super.show_dialog(text)
	var elapsed_msec := float(
		Time.get_ticks_usec() - started_usec
	) / 1000.0

	NPCStoreDebugTraceScript.emit(
		npc,
		"dialog_show",
		{
			"text": text,
			"elapsed_msec": elapsed_msec,
			"state": NPCStoreDebugTraceScript.state_name(
				int(npc.current_state)
			),
			"search_timer": npc._search_timer,
			"position": NPCStoreDebugTraceScript.vector(
				npc.global_position
			)
		}
	)
