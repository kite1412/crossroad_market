class_name NPCSchedulerDatabase
extends RefCounted

var scheduler: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(scheduler_node: Node) -> void:
	scheduler = scheduler_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func load_npc_database() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var load_dir := func(dir_path: String) -> void:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var dir := DirAccess.open(dir_path)
		if dir == null:
			return
		dir.list_dir_begin()
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
				var npc = load(dir_path + file_name)
				if npc != null and npc.npc_id != "":
					scheduler._npc_database[npc.npc_id] = npc
			file_name = dir.get_next()
	load_dir.call("res://data/npc/story/")
	load_dir.call("res://data/npc/generic/")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func load_npc_data() -> void:
	scheduler._npc_database.clear()
	load_npc_database()
