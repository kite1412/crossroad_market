class_name TilesetIconLoader
extends RefCounted

const DEFAULT_TILE_SIZE := Vector2i(16, 16)

static var _icon_cache: Dictionary = {}


static func get_icon(
	tileset_path: String,
	tile_position: Vector2i,
	tile_size: Vector2i = DEFAULT_TILE_SIZE
) -> Texture2D:
	if tileset_path == "":
		return null

	if tile_size.x <= 0 or tile_size.y <= 0:
		return null

	if tile_position.x < 0 or tile_position.y < 0:
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cache_key := "%s:%d:%d:%d:%d" % [
		tileset_path,
		tile_position.x,
		tile_position.y,
		tile_size.x,
		tile_size.y
	]

	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key] as Texture2D

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tileset := load(tileset_path) as Texture2D
	if tileset == null:
		push_warning("Tileset icon source could not be loaded: %s" % tileset_path)
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var region := Rect2(tile_position * tile_size, tile_size)
	if region.end.x > tileset.get_width() or region.end.y > tileset.get_height():
		push_warning("Tileset icon coordinates are outside the source image: %s" % tileset_path)
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = tileset
	atlas_texture.region = region
	_icon_cache[cache_key] = atlas_texture
	return atlas_texture
