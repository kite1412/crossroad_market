@tool
class_name AnimatedCharacterSpriteConfig
extends Resource

## Sprite-sheet settings for each facing direction of a CharacterSprite.
##
## Keeping these together makes a CharacterSprite's inspector compact and lets
## one config resource be reused by character sprites that share an animation
## layout.

@export_group("Down")
@export var down_texture: Texture2D
@export_range(1, 100, 1) var down_rows: int = 1
@export_range(1, 100, 1) var down_columns: int = 1
@export_range(1, 100, 1) var down_frames_per_row: int = 1
@export_range(0, 100, 1) var down_start_row: int = 0
@export_range(0, 100, 1) var down_start_column: int = 0
@export var down_end_row: int = -1
@export var down_end_column: int = -1
@export var down_spacing: Vector2i = Vector2i.ZERO
@export var down_margin: Vector2i = Vector2i.ZERO

@export_group("Left")
@export var left_texture: Texture2D
@export_range(1, 100, 1) var left_rows: int = 1
@export_range(1, 100, 1) var left_columns: int = 1
@export_range(1, 100, 1) var left_frames_per_row: int = 1
@export_range(0, 100, 1) var left_start_row: int = 0
@export_range(0, 100, 1) var left_start_column: int = 0
@export var left_end_row: int = -1
@export var left_end_column: int = -1
@export var left_spacing: Vector2i = Vector2i.ZERO
@export var left_margin: Vector2i = Vector2i.ZERO

@export_group("Right")
@export var right_texture: Texture2D
@export_range(1, 100, 1) var right_rows: int = 1
@export_range(1, 100, 1) var right_columns: int = 1
@export_range(1, 100, 1) var right_frames_per_row: int = 1
@export_range(0, 100, 1) var right_start_row: int = 0
@export_range(0, 100, 1) var right_start_column: int = 0
@export var right_end_row: int = -1
@export var right_end_column: int = -1
@export var right_spacing: Vector2i = Vector2i.ZERO
@export var right_margin: Vector2i = Vector2i.ZERO

@export_group("Up")
@export var up_texture: Texture2D
@export_range(1, 100, 1) var up_rows: int = 1
@export_range(1, 100, 1) var up_columns: int = 1
@export_range(1, 100, 1) var up_frames_per_row: int = 1
@export_range(0, 100, 1) var up_start_row: int = 0
@export_range(0, 100, 1) var up_start_column: int = 0
@export var up_end_row: int = -1
@export var up_end_column: int = -1
@export var up_spacing: Vector2i = Vector2i.ZERO
@export var up_margin: Vector2i = Vector2i.ZERO


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_direction_settings(direction: int) -> Dictionary:
	match direction:
		0:
			return _settings(down_texture, down_rows, down_columns, down_frames_per_row, down_start_row, down_start_column, down_end_row, down_end_column, down_spacing, down_margin)
		1:
			return _settings(left_texture, left_rows, left_columns, left_frames_per_row, left_start_row, left_start_column, left_end_row, left_end_column, left_spacing, left_margin)
		2:
			return _settings(right_texture, right_rows, right_columns, right_frames_per_row, right_start_row, right_start_column, right_end_row, right_end_column, right_spacing, right_margin)
		3:
			return _settings(up_texture, up_rows, up_columns, up_frames_per_row, up_start_row, up_start_column, up_end_row, up_end_column, up_spacing, up_margin)

	return {}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _settings(texture: Texture2D, rows: int, columns: int, frames_per_row: int, start_row: int, start_column: int, end_row: int, end_column: int, spacing: Vector2i, margin: Vector2i) -> Dictionary:
	return {
		"texture": texture,
		"rows": rows,
		"columns": columns,
		"frames_per_row": frames_per_row,
		"start_row": start_row,
		"start_column": start_column,
		"end_row": end_row,
		"end_column": end_column,
		"spacing": spacing,
		"margin": margin,
	}
