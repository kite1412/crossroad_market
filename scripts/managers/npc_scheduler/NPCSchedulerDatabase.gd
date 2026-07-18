class_name NPCSchedulerDatabase
extends RefCounted

var scheduler: Node = null


func setup(scheduler_node: Node) -> void:
	scheduler = scheduler_node


func load_npc_database() -> void:
	var load_dir := func(dir_path: String) -> void:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			return
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var npc = load(dir_path + file_name)
				if npc != null and npc.npc_id != "":
					scheduler._npc_database[npc.npc_id] = npc
			file_name = dir.get_next()
	load_dir.call("res://data/npc/story/")
	load_dir.call("res://data/npc/generic/")


func load_npc_data() -> void:
	scheduler._npc_database.clear()
	load_npc_database()
