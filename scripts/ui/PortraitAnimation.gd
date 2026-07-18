class_name PortraitAnimation
extends Control

## Displays a horizontal portrait strip as a looping 6-frame animation.

const DEFAULT_FRAME_COUNT: int = 6
const DEFAULT_FPS: float = 5.0

@export var portrait: Texture2D
@export_range(1, 32, 1) var frame_count: int = DEFAULT_FRAME_COUNT
@export_range(0.1, 30.0, 0.1) var frames_per_second: float = DEFAULT_FPS
@export_range(0, 31, 1) var initial_frame: int = 0

@onready var frame_view: TextureRect = $Frame

var _current_frame: int = 0
var _frame_elapsed: float = 0.0
var _frame_width: float = 0.0


func _ready() -> void:
	set_portrait(portrait, initial_frame)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or portrait == null or frame_count <= 1:
		return

	var frame_duration = 1.0 / max(frames_per_second, 0.1)
	_frame_elapsed += delta

	if _frame_elapsed < frame_duration:
		return

	var frames_to_advance := floori(_frame_elapsed / frame_duration)
	_frame_elapsed -= float(frames_to_advance) * frame_duration
	_current_frame = posmod(_current_frame + frames_to_advance, frame_count)
	_update_frame()


func set_portrait(texture: Texture2D, start_frame: int = 0) -> void:
	portrait = texture
	_current_frame = posmod(start_frame, max(frame_count, 1))
	_frame_elapsed = 0.0
	_update_dimensions()
	_update_frame()


func get_frame_size() -> Vector2:
	if portrait == null:
		return Vector2.ZERO

	return Vector2(_get_frame_width(portrait), portrait.get_height())


func _update_dimensions() -> void:
	if portrait == null:
		_frame_width = 0
		size = Vector2.ZERO
		custom_minimum_size = Vector2.ZERO
		return

	_frame_width = _get_frame_width(portrait)
	var frame_size := Vector2(_frame_width, portrait.get_height())
	size = frame_size
	custom_minimum_size = frame_size


func _update_frame() -> void:
	if portrait == null or _frame_width <= 0.0:
		frame_view.texture = null
		return

	var frame_texture := AtlasTexture.new()
	frame_texture.atlas = portrait
	frame_texture.region = Rect2(
		_current_frame * _frame_width,
		0,
		_frame_width,
		portrait.get_height()
	)
	frame_view.texture = frame_texture


func _get_frame_width(texture: Texture2D) -> float:
	return float(texture.get_width()) / float(max(frame_count, 1))
