@tool
class_name CharacterSprite
extends AnimatedSprite2D

enum Direction {
	DOWN,
	LEFT,
	RIGHT,
	UP
}

@warning_ignore("unused_private_class_variable")
var _animation_fps: float = 5.0
@warning_ignore("unused_private_class_variable")
var _default_direction: Direction = Direction.DOWN
@warning_ignore("unused_private_class_variable")
var _animate_idle: bool = true
@warning_ignore("unused_private_class_variable")
var _direction_config: AnimatedCharacterSpriteConfig
@warning_ignore("unused_private_class_variable")
var _idle_direction_config: AnimatedCharacterSpriteConfig
@warning_ignore("unused_private_class_variable")
var _current_direction: Direction = Direction.DOWN
@warning_ignore("unused_private_class_variable")
var _is_moving: bool = false
@warning_ignore("unused_private_class_variable")
var _is_direction_loop_forced: bool = false
@warning_ignore("unused_private_class_variable")
var _is_ready: bool = false
@warning_ignore("unused_private_class_variable")
var _needs_refresh: bool = true

@export var animation_fps: float:
	get:
		return _animation_fps
	set(value):
		_animation_fps = maxf(value, 0.1)
		_queue_refresh()

@export var default_direction: Direction:
	get:
		return _default_direction
	set(value):
		_default_direction = value
		_current_direction = value
		_apply_motion_state()

@export var animate_idle: bool:
	get:
		return _animate_idle
	set(value):
		_animate_idle = value
		_apply_motion_state()

@export var direction_config: AnimatedCharacterSpriteConfig:
	get:
		return _direction_config
	set(value):
		if _direction_config == value:
			return
		if _direction_config != null and _direction_config.changed.is_connected(_queue_refresh):
			_direction_config.changed.disconnect(_queue_refresh)
		_direction_config = value
		if _direction_config != null:
			_direction_config.changed.connect(_queue_refresh)
		_queue_refresh()

@export var idle_direction_config: AnimatedCharacterSpriteConfig:
	get:
		return _idle_direction_config
	set(value):
		if _idle_direction_config == value:
			return
		if _idle_direction_config != null and _idle_direction_config.changed.is_connected(_queue_refresh):
			_idle_direction_config.changed.disconnect(_queue_refresh)
		_idle_direction_config = value
		if _idle_direction_config != null:
			_idle_direction_config.changed.connect(_queue_refresh)
		_queue_refresh()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_is_ready = true
	_refresh_sprite_frames()
	_apply_motion_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_motion_vector(motion: Vector2) -> void:
	if motion == Vector2.ZERO:
		set_moving(false)
		return

	set_direction_from_vector(motion)
	set_moving(true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func refresh_sprite_frames() -> void:
	_needs_refresh = true
	_refresh_sprite_frames()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_direction_from_vector(motion: Vector2) -> void:
	if motion != Vector2.ZERO:
		set_direction(_direction_from_vector(motion))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_direction(direction: Direction) -> void:
	_current_direction = direction
	_apply_motion_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_moving(moving: bool) -> void:
	_is_moving = moving
	_apply_motion_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func play_direction_loop(direction: Direction) -> void:
	_current_direction = direction
	_is_moving = false
	_is_direction_loop_forced = true
	_apply_motion_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func stop_direction_loop() -> void:
	_is_direction_loop_forced = false
	_apply_motion_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _queue_refresh() -> void:
	_needs_refresh = true
	if _is_ready:
		call_deferred("_refresh_sprite_frames")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _refresh_sprite_frames() -> void:
	if not _needs_refresh and sprite_frames != null:
		return
	_needs_refresh = false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var frames := SpriteFrames.new()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var has_any_animation := false
	if _direction_config == null and _idle_direction_config == null:
		sprite_frames = frames
		stop()
		return

	for direction in [Direction.DOWN, Direction.LEFT, Direction.RIGHT, Direction.UP]:
		if _direction_config != null:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var settings := _direction_config.get_direction_settings(direction)
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var texture: Texture2D = settings.get("texture")
			if texture != null:
				@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
				var created_frames := _add_frames_for_texture(frames, _get_animation_name(direction), texture, settings.get("rows"), settings.get("columns"), settings.get("frames_per_row"), settings.get("start_row"), settings.get("start_column"), settings.get("end_row"), settings.get("end_column"), settings.get("spacing"), settings.get("margin"))
				has_any_animation = has_any_animation or created_frames > 0

		if _idle_direction_config != null:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var idle_settings := _idle_direction_config.get_direction_settings(direction)
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var idle_texture: Texture2D = idle_settings.get("texture")
			if idle_texture != null:
				@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
				var created_idle_frames := _add_frames_for_texture(frames, _get_idle_animation_name(direction), idle_texture, idle_settings.get("rows"), idle_settings.get("columns"), idle_settings.get("frames_per_row"), idle_settings.get("start_row"), idle_settings.get("start_column"), idle_settings.get("end_row"), idle_settings.get("end_column"), idle_settings.get("spacing"), idle_settings.get("margin"))
				has_any_animation = has_any_animation or created_idle_frames > 0

	sprite_frames = frames
	speed_scale = 1.0
	if has_any_animation:
		_apply_motion_state()
	else:
		stop()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_motion_state() -> void:
	if sprite_frames == null:
		return
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var animation_name := _get_active_animation_name(_current_direction)
	if not sprite_frames.has_animation(animation_name):
		return

	if _is_direction_loop_forced or _is_moving or _animate_idle:
		if animation != animation_name:
			play(animation_name)
			frame = 0
		elif not is_playing():
			play(animation_name)
	else:
		animation = animation_name
		frame = 0
		stop()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _direction_from_vector(motion: Vector2) -> Direction:
	if abs(motion.x) > abs(motion.y):
		return Direction.RIGHT if motion.x > 0.0 else Direction.LEFT
	return Direction.DOWN if motion.y > 0.0 else Direction.UP


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _add_frames_for_texture(frames: SpriteFrames, animation_name: String, texture: Texture2D, rows: int, columns: int, frames_per_row: int, start_row: int, start_column: int, end_row: int, end_column: int, spacing: Vector2i, margin: Vector2i) -> int:
	if rows <= 0 or columns <= 0 or frames_per_row <= 0:
		return 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var texture_size := texture.get_size()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var available_width := texture_size.x - float(margin.x * 2) - float(max(columns - 1, 0) * spacing.x)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var available_height := texture_size.y - float(margin.y * 2) - float(max(rows - 1, 0) * spacing.y)
	if available_width <= 0.0 or available_height <= 0.0:
		return 0

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cell_size := Vector2(available_width / float(columns), available_height / float(rows))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total_frames := 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var clamped_start_column := clampi(start_column, 0, columns - 1)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var clamped_end_row := clampi(start_row, 0, rows - 1) if end_row < 0 else mini(end_row, rows - 1)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var clamped_end_column := mini(clamped_start_column + frames_per_row - 1, columns - 1) if end_column < 0 else mini(end_column, columns - 1)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var clamped_start_row := clampi(start_row, 0, clamped_end_row)
	if clamped_start_row == clamped_end_row:
		clamped_start_column = mini(clamped_start_column, clamped_end_column)

	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, animation_fps)
	for row in range(clamped_start_row, clamped_end_row + 1):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var row_start_column := clamped_start_column if row == clamped_start_row else 0
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var row_end_column := clamped_end_column if row == clamped_end_row else columns - 1
		if row_end_column < row_start_column:
			continue
		for column_offset in range(mini(frames_per_row, row_end_column - row_start_column + 1)):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var column := row_start_column + column_offset
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(float(margin.x) + float(column) * (cell_size.x + float(spacing.x)), float(margin.y) + float(row) * (cell_size.y + float(spacing.y))), cell_size)
			frames.add_frame(animation_name, atlas)
			total_frames += 1
	return total_frames


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_animation_name(direction: Direction) -> StringName:
	match direction:
		Direction.DOWN: return &"down"
		Direction.LEFT: return &"left"
		Direction.RIGHT: return &"right"
		Direction.UP: return &"up"
	return &"down"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_idle_animation_name(direction: Direction) -> StringName:
	match direction:
		Direction.DOWN: return &"idle_down"
		Direction.LEFT: return &"idle_left"
		Direction.RIGHT: return &"idle_right"
		Direction.UP: return &"idle_up"
	return &"idle_down"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_active_animation_name(direction: Direction) -> StringName:
	if not _is_moving and _idle_direction_config != null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var idle_animation := _get_idle_animation_name(direction)
		if sprite_frames != null and sprite_frames.has_animation(idle_animation):
			return idle_animation

	return _get_animation_name(direction)
