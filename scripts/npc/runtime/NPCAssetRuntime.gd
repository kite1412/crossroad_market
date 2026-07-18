class_name NPCAssetRuntime
extends RefCounted

var npc = null


func setup(npc_node) -> void:
	npc = npc_node


func load_character_assets() -> void:
	if npc.npc_data == null or npc.npc_data.assets_path.strip_edges() == "":
		return

	var idle_sprite: CharacterSprite = npc.sprite_idle
	var move_sprite: CharacterSprite = npc.sprite_move
	if idle_sprite == null:
		idle_sprite = npc.get_node_or_null("VisualRoot/SpriteIdle") as CharacterSprite
	if move_sprite == null:
		move_sprite = npc.get_node_or_null("VisualRoot/SpriteMove") as CharacterSprite
	if idle_sprite == null or move_sprite == null:
		push_error("NPC '%s' cannot load character assets because SpriteIdle or SpriteMove is missing." % npc.npc_data.npc_id)
		return

	var textures := load_directional_textures(npc.npc_data.assets_path)
	if textures.size() < 4:
		push_warning("NPC '%s' is missing one or more directional textures at '%s'." % [npc.npc_data.npc_id, npc.npc_data.assets_path])
		return

	idle_sprite.direction_config = create_character_sprite_config(textures, 0, 6, 5)
	move_sprite.direction_config = create_character_sprite_config(textures, 1, 4, 3)
	idle_sprite.refresh_sprite_frames()
	move_sprite.refresh_sprite_frames()
	idle_sprite.visible = true
	move_sprite.visible = false
	validate_character_sprite("idle", idle_sprite, 6)
	validate_character_sprite("move", move_sprite, 4)

	var placeholder := npc.get_node_or_null("VisualRoot/PlaceholderRect") as CanvasItem
	if placeholder != null:
		placeholder.visible = false


func load_directional_textures(assets_path: String) -> Dictionary:
	var directory_path := "res://assets/characters/%s" % assets_path.trim_prefix("/").trim_suffix("/")
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return {}

	var textures: Dictionary = {}
	var prefixes := {
		"down": "front-",
		"left": "side-left-",
		"right": "side-right-",
		"up": "back-"
	}

	for file_name in directory.get_files():
		if not file_name.to_lower().ends_with(".png"):
			continue

		for direction in prefixes:
			if textures.has(direction) or not file_name.begins_with(prefixes[direction]):
				continue

			var texture := load("%s/%s" % [directory_path, file_name]) as Texture2D
			if texture != null:
				textures[direction] = texture
			break

	return textures


func create_character_sprite_config(textures: Dictionary, row: int, frames: int, end_column: int) -> AnimatedCharacterSpriteConfig:
	var config := AnimatedCharacterSpriteConfig.new()
	configure_character_direction(config, "down", textures["down"] as Texture2D, row, frames, end_column)
	configure_character_direction(config, "left", textures["left"] as Texture2D, row, frames, end_column)
	configure_character_direction(config, "right", textures["right"] as Texture2D, row, frames, end_column)
	configure_character_direction(config, "up", textures["up"] as Texture2D, row, frames, end_column)
	return config


func configure_character_direction(config: AnimatedCharacterSpriteConfig, direction: String, texture: Texture2D, row: int, frames: int, end_column: int) -> void:
	match direction:
		"down":
			config.down_texture = texture
			config.down_rows = 2
			config.down_columns = 6
			config.down_frames_per_row = frames
			config.down_start_row = row
			config.down_start_column = 0
			config.down_end_row = row
			config.down_end_column = end_column
		"left":
			config.left_texture = texture
			config.left_rows = 2
			config.left_columns = 6
			config.left_frames_per_row = frames
			config.left_start_row = row
			config.left_start_column = 0
			config.left_end_row = row
			config.left_end_column = end_column
		"right":
			config.right_texture = texture
			config.right_rows = 2
			config.right_columns = 6
			config.right_frames_per_row = frames
			config.right_start_row = row
			config.right_start_column = 0
			config.right_end_row = row
			config.right_end_column = end_column
		"up":
			config.up_texture = texture
			config.up_rows = 2
			config.up_columns = 6
			config.up_frames_per_row = frames
			config.up_start_row = row
			config.up_start_column = 0
			config.up_end_row = row
			config.up_end_column = end_column


func validate_character_sprite(label: String, sprite: CharacterSprite, expected_frames: int) -> void:
	if sprite == null or sprite.direction_config == null:
		push_error("NPC '%s' %s sprite has no AnimatedCharacterSpriteConfig." % [npc.npc_data.npc_id, label])
		return

	for direction in [CharacterSprite.Direction.DOWN, CharacterSprite.Direction.LEFT, CharacterSprite.Direction.RIGHT, CharacterSprite.Direction.UP]:
		var settings := sprite.direction_config.get_direction_settings(direction)
		var texture := settings.get("texture") as Texture2D
		var animation_name := get_character_animation_name(direction)
		var frame_count := sprite.sprite_frames.get_frame_count(animation_name) if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name) else 0
		if texture == null or frame_count != expected_frames:
			push_error("NPC '%s' %s sprite failed for %s: texture=%s frames=%d expected=%d" % [npc.npc_data.npc_id, label, animation_name, texture != null, frame_count, expected_frames])


func get_character_animation_name(direction: CharacterSprite.Direction) -> StringName:
	match direction:
		CharacterSprite.Direction.DOWN: return &"down"
		CharacterSprite.Direction.LEFT: return &"left"
		CharacterSprite.Direction.RIGHT: return &"right"
		CharacterSprite.Direction.UP: return &"up"
	return &"down"
