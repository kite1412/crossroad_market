@tool
class_name CharacterSprite
extends AnimatedSprite2D

enum Direction {
	DOWN,
	LEFT,
	RIGHT,
	UP
}

var _animation_fps: float = 5.0
var _default_direction: Direction = Direction.DOWN

var _down_texture: Texture2D
var _down_rows: int = 1
var _down_columns: int = 1
var _down_frames_per_row: int = 1
var _down_start_row: int = 0
var _down_start_column: int = 0
var _down_end_row: int = -1
var _down_end_column: int = -1
var _down_spacing: Vector2i = Vector2i.ZERO
var _down_margin: Vector2i = Vector2i.ZERO

var _left_texture: Texture2D
var _left_rows: int = 1
var _left_columns: int = 1
var _left_frames_per_row: int = 1
var _left_start_row: int = 0
var _left_start_column: int = 0
var _left_end_row: int = -1
var _left_end_column: int = -1
var _left_spacing: Vector2i = Vector2i.ZERO
var _left_margin: Vector2i = Vector2i.ZERO

var _right_texture: Texture2D
var _right_rows: int = 1
var _right_columns: int = 1
var _right_frames_per_row: int = 1
var _right_start_row: int = 0
var _right_start_column: int = 0
var _right_end_row: int = -1
var _right_end_column: int = -1
var _right_spacing: Vector2i = Vector2i.ZERO
var _right_margin: Vector2i = Vector2i.ZERO

var _up_texture: Texture2D
var _up_rows: int = 1
var _up_columns: int = 1
var _up_frames_per_row: int = 1
var _up_start_row: int = 0
var _up_start_column: int = 0
var _up_end_row: int = -1
var _up_end_column: int = -1
var _up_spacing: Vector2i = Vector2i.ZERO
var _up_margin: Vector2i = Vector2i.ZERO

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

@export var down_texture: Texture2D:
	get:
		return _down_texture
	set(value):
		_down_texture = value
		_queue_refresh()
@export var down_rows: int:
	get:
		return _down_rows
	set(value):
		_down_rows = maxi(value, 1)
		_queue_refresh()
@export var down_columns: int:
	get:
		return _down_columns
	set(value):
		_down_columns = maxi(value, 1)
		_queue_refresh()
@export var down_frames_per_row: int:
	get:
		return _down_frames_per_row
	set(value):
		_down_frames_per_row = maxi(value, 1)
		_queue_refresh()
@export var down_start_row: int:
	get:
		return _down_start_row
	set(value):
		_down_start_row = maxi(value, 0)
		if _down_end_row >= 0 and _down_end_row < _down_start_row:
			_down_end_row = _down_start_row
		_queue_refresh()
@export var down_start_column: int:
	get:
		return _down_start_column
	set(value):
		_down_start_column = maxi(value, 0)
		if _down_end_column >= 0 and _down_end_column < _down_start_column:
			_down_end_column = _down_start_column
		_queue_refresh()
@export var down_end_row: int:
	get:
		return _down_end_row
	set(value):
		_down_end_row = -1 if value < 0 else maxi(value, _down_start_row)
		_queue_refresh()
@export var down_end_column: int:
	get:
		return _down_end_column
	set(value):
		_down_end_column = -1 if value < 0 else maxi(value, _down_start_column)
		_queue_refresh()
@export var down_spacing: Vector2i:
	get:
		return _down_spacing
	set(value):
		_down_spacing = value
		_queue_refresh()
@export var down_margin: Vector2i:
	get:
		return _down_margin
	set(value):
		_down_margin = value
		_queue_refresh()

@export var left_texture: Texture2D:
	get:
		return _left_texture
	set(value):
		_left_texture = value
		_queue_refresh()
@export var left_rows: int:
	get:
		return _left_rows
	set(value):
		_left_rows = maxi(value, 1)
		_queue_refresh()
@export var left_columns: int:
	get:
		return _left_columns
	set(value):
		_left_columns = maxi(value, 1)
		_queue_refresh()
@export var left_frames_per_row: int:
	get:
		return _left_frames_per_row
	set(value):
		_left_frames_per_row = maxi(value, 1)
		_queue_refresh()
@export var left_start_row: int:
	get:
		return _left_start_row
	set(value):
		_left_start_row = maxi(value, 0)
		if _left_end_row >= 0 and _left_end_row < _left_start_row:
			_left_end_row = _left_start_row
		_queue_refresh()
@export var left_start_column: int:
	get:
		return _left_start_column
	set(value):
		_left_start_column = maxi(value, 0)
		if _left_end_column >= 0 and _left_end_column < _left_start_column:
			_left_end_column = _left_start_column
		_queue_refresh()
@export var left_end_row: int:
	get:
		return _left_end_row
	set(value):
		_left_end_row = -1 if value < 0 else maxi(value, _left_start_row)
		_queue_refresh()
@export var left_end_column: int:
	get:
		return _left_end_column
	set(value):
		_left_end_column = -1 if value < 0 else maxi(value, _left_start_column)
		_queue_refresh()
@export var left_spacing: Vector2i:
	get:
		return _left_spacing
	set(value):
		_left_spacing = value
		_queue_refresh()
@export var left_margin: Vector2i:
	get:
		return _left_margin
	set(value):
		_left_margin = value
		_queue_refresh()

@export var right_texture: Texture2D:
	get:
		return _right_texture
	set(value):
		_right_texture = value
		_queue_refresh()
@export var right_rows: int:
	get:
		return _right_rows
	set(value):
		_right_rows = maxi(value, 1)
		_queue_refresh()
@export var right_columns: int:
	get:
		return _right_columns
	set(value):
		_right_columns = maxi(value, 1)
		_queue_refresh()
@export var right_frames_per_row: int:
	get:
		return _right_frames_per_row
	set(value):
		_right_frames_per_row = maxi(value, 1)
		_queue_refresh()
@export var right_start_row: int:
	get:
		return _right_start_row
	set(value):
		_right_start_row = maxi(value, 0)
		if _right_end_row >= 0 and _right_end_row < _right_start_row:
			_right_end_row = _right_start_row
		_queue_refresh()
@export var right_start_column: int:
	get:
		return _right_start_column
	set(value):
		_right_start_column = maxi(value, 0)
		if _right_end_column >= 0 and _right_end_column < _right_start_column:
			_right_end_column = _right_start_column
		_queue_refresh()
@export var right_end_row: int:
	get:
		return _right_end_row
	set(value):
		_right_end_row = -1 if value < 0 else maxi(value, _right_start_row)
		_queue_refresh()
@export var right_end_column: int:
	get:
		return _right_end_column
	set(value):
		_right_end_column = -1 if value < 0 else maxi(value, _right_start_column)
		_queue_refresh()
@export var right_spacing: Vector2i:
	get:
		return _right_spacing
	set(value):
		_right_spacing = value
		_queue_refresh()
@export var right_margin: Vector2i:
	get:
		return _right_margin
	set(value):
		_right_margin = value
		_queue_refresh()

@export var up_texture: Texture2D:
	get:
		return _up_texture
	set(value):
		_up_texture = value
		_queue_refresh()
@export var up_rows: int:
	get:
		return _up_rows
	set(value):
		_up_rows = maxi(value, 1)
		_queue_refresh()
@export var up_columns: int:
	get:
		return _up_columns
	set(value):
		_up_columns = maxi(value, 1)
		_queue_refresh()
@export var up_frames_per_row: int:
	get:
		return _up_frames_per_row
	set(value):
		_up_frames_per_row = maxi(value, 1)
		_queue_refresh()
@export var up_start_row: int:
	get:
		return _up_start_row
	set(value):
		_up_start_row = maxi(value, 0)
		if _up_end_row >= 0 and _up_end_row < _up_start_row:
			_up_end_row = _up_start_row
		_queue_refresh()
@export var up_start_column: int:
	get:
		return _up_start_column
	set(value):
		_up_start_column = maxi(value, 0)
		if _up_end_column >= 0 and _up_end_column < _up_start_column:
			_up_end_column = _up_start_column
		_queue_refresh()
@export var up_end_row: int:
	get:
		return _up_end_row
	set(value):
		_up_end_row = -1 if value < 0 else maxi(value, _up_start_row)
		_queue_refresh()
@export var up_end_column: int:
	get:
		return _up_end_column
	set(value):
		_up_end_column = -1 if value < 0 else maxi(value, _up_start_column)
		_queue_refresh()
@export var up_spacing: Vector2i:
	get:
		return _up_spacing
	set(value):
		_up_spacing = value
		_queue_refresh()
@export var up_margin: Vector2i:
	get:
		return _up_margin
	set(value):
		_up_margin = value
		_queue_refresh()

var _current_direction: Direction = Direction.DOWN
var _is_moving: bool = false
var _is_ready: bool = false
var _needs_refresh: bool = true


func _ready() -> void:
	_is_ready = true
	_refresh_sprite_frames()
	_apply_motion_state()


func apply_motion_vector(motion: Vector2) -> void:
	if motion == Vector2.ZERO:
		set_moving(false)
		return

	set_direction_from_vector(motion)
	set_moving(true)


func set_direction_from_vector(motion: Vector2) -> void:
	if motion == Vector2.ZERO:
		return

	set_direction(_direction_from_vector(motion))


func set_direction(direction: Direction) -> void:
	_current_direction = direction
	_apply_motion_state()


func set_moving(moving: bool) -> void:
	_is_moving = moving
	_apply_motion_state()


func _queue_refresh() -> void:
	_needs_refresh = true

	if _is_ready:
		call_deferred("_refresh_sprite_frames")


func _refresh_sprite_frames() -> void:
	if not _needs_refresh and sprite_frames != null:
		return

	_needs_refresh = false

	var frames := SpriteFrames.new()
	var has_any_animation := false

	for direction in [Direction.DOWN, Direction.LEFT, Direction.RIGHT, Direction.UP]:
		var texture := _get_texture_for_direction(direction)

		if texture == null:
			continue

		var animation_name := _get_animation_name(direction)
		var rows := _get_rows_for_direction(direction)
		var columns := _get_columns_for_direction(direction)
		var frames_per_row := _get_frames_per_row_for_direction(direction)
		var start_row := _get_start_row_for_direction(direction)
		var start_column := _get_start_column_for_direction(direction)
		var end_row := _get_end_row_for_direction(direction)
		var end_column := _get_end_column_for_direction(direction)
		var spacing := _get_spacing_for_direction(direction)
		var margin := _get_margin_for_direction(direction)

		var created_frames := _add_frames_for_texture(
			frames,
			animation_name,
			texture,
			rows,
			columns,
			frames_per_row,
			start_row,
			start_column,
			end_row,
			end_column,
			spacing,
			margin
		)

		if created_frames > 0:
			has_any_animation = true

	sprite_frames = frames
	speed_scale = 1.0

	if not has_any_animation:
		stop()
		return

	_apply_motion_state()


func _apply_motion_state() -> void:
	if sprite_frames == null:
		return

	var animation_name := _get_animation_name(_current_direction)

	if not sprite_frames.has_animation(animation_name):
		return

	if _is_moving:
		if animation != animation_name:
			play(animation_name)
			frame = 0
		elif not is_playing():
			play(animation_name)
	else:
		animation = animation_name
		frame = 0
		stop()


func _direction_from_vector(motion: Vector2) -> Direction:
	if abs(motion.x) > abs(motion.y):
		return Direction.RIGHT if motion.x > 0.0 else Direction.LEFT

	return Direction.DOWN if motion.y > 0.0 else Direction.UP


func _add_frames_for_texture(
	frames: SpriteFrames,
	animation_name: String,
	texture: Texture2D,
	rows: int,
	columns: int,
	frames_per_row: int,
	start_row: int,
	start_column: int,
	end_row: int,
	end_column: int,
	spacing: Vector2i,
	margin: Vector2i
) -> int:
	if rows <= 0 or columns <= 0 or frames_per_row <= 0:
		return 0

	var texture_size := texture.get_size()
	var available_width := texture_size.x - float(margin.x * 2) - float(max(columns - 1, 0) * spacing.x)
	var available_height := texture_size.y - float(margin.y * 2) - float(max(rows - 1, 0) * spacing.y)

	if available_width <= 0.0 or available_height <= 0.0:
		return 0

	var cell_size := Vector2(available_width / float(columns), available_height / float(rows))
	var total_frames := 0
	var clamped_end_row := rows - 1 if end_row < 0 else mini(end_row, rows - 1)
	var clamped_end_column := columns - 1 if end_column < 0 else mini(end_column, columns - 1)
	var clamped_start_row := clampi(start_row, 0, clamped_end_row)
	var clamped_start_column := clampi(start_column, 0, clamped_end_column)
	var frames_in_row := mini(frames_per_row, clamped_end_column - clamped_start_column + 1)
	var rows_to_use := clamped_end_row - clamped_start_row + 1

	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, animation_fps)

	for row in range(rows_to_use):
		for column in range(frames_in_row):
			var region_position := Vector2(
				float(margin.x) + float(clamped_start_column + column) * (cell_size.x + float(spacing.x)),
				float(margin.y) + float(clamped_start_row + row) * (cell_size.y + float(spacing.y))
			)
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(region_position, cell_size)
			frames.add_frame(animation_name, atlas)
			total_frames += 1

	return total_frames


func _get_texture_for_direction(direction: Direction) -> Texture2D:
	match direction:
		Direction.DOWN:
			return _down_texture
		Direction.LEFT:
			return _left_texture
		Direction.RIGHT:
			return _right_texture
		Direction.UP:
			return _up_texture

	return null


func _get_rows_for_direction(direction: Direction) -> int:
	match direction:
		Direction.DOWN:
			return _down_rows
		Direction.LEFT:
			return _left_rows
		Direction.RIGHT:
			return _right_rows
		Direction.UP:
			return _up_rows

	return 1


func _get_columns_for_direction(direction: Direction) -> int:
	match direction:
		Direction.DOWN:
			return _down_columns
		Direction.LEFT:
			return _left_columns
		Direction.RIGHT:
			return _right_columns
		Direction.UP:
			return _up_columns

	return 1


func _get_frames_per_row_for_direction(direction: Direction) -> int:
	match direction:
		Direction.DOWN:
			return _down_frames_per_row
		Direction.LEFT:
			return _left_frames_per_row
		Direction.RIGHT:
			return _right_frames_per_row
		Direction.UP:
			return _up_frames_per_row

	return 1


func _get_start_row_for_direction(direction: Direction) -> int:
	match direction:
		Direction.DOWN:
			return _down_start_row
		Direction.LEFT:
			return _left_start_row
		Direction.RIGHT:
			return _right_start_row
		Direction.UP:
			return _up_start_row

	return 0


func _get_start_column_for_direction(direction: Direction) -> int:
	match direction:
		Direction.DOWN:
			return _down_start_column
		Direction.LEFT:
			return _left_start_column
		Direction.RIGHT:
			return _right_start_column
		Direction.UP:
			return _up_start_column

	return 0


func _get_end_row_for_direction(direction: Direction) -> int:
	match direction:
		Direction.DOWN:
			return _down_end_row
		Direction.LEFT:
			return _left_end_row
		Direction.RIGHT:
			return _right_end_row
		Direction.UP:
			return _up_end_row

	return 0


func _get_end_column_for_direction(direction: Direction) -> int:
	match direction:
		Direction.DOWN:
			return _down_end_column
		Direction.LEFT:
			return _left_end_column
		Direction.RIGHT:
			return _right_end_column
		Direction.UP:
			return _up_end_column

	return 0


func _get_spacing_for_direction(direction: Direction) -> Vector2i:
	match direction:
		Direction.DOWN:
			return _down_spacing
		Direction.LEFT:
			return _left_spacing
		Direction.RIGHT:
			return _right_spacing
		Direction.UP:
			return _up_spacing

	return Vector2i.ZERO


func _get_margin_for_direction(direction: Direction) -> Vector2i:
	match direction:
		Direction.DOWN:
			return _down_margin
		Direction.LEFT:
			return _left_margin
		Direction.RIGHT:
			return _right_margin
		Direction.UP:
			return _up_margin

	return Vector2i.ZERO


func _get_animation_name(direction: Direction) -> StringName:
	match direction:
		Direction.DOWN:
			return &"down"
		Direction.LEFT:
			return &"left"
		Direction.RIGHT:
			return &"right"
		Direction.UP:
			return &"up"

	return &"down"
