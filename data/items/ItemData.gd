class_name ItemData
extends Resource

const TilesetIconLoader = preload("res://scripts/items/TilesetIconLoader.gd")

enum ShelfType {
	HUMAN, GHOST
}

@export var item_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var buy_cost: int = 0
@export var sell_price: int = 0
@export var shelf_type: ShelfType = ShelfType.HUMAN
@export var icon: Texture2D = null
@export_file("*.png") var icon_tileset_path: String = ""
@export var icon_tile: Vector2i = Vector2i(-1, -1)
@export var icon_tile_size: Vector2i = Vector2i(16, 16)


func get_icon() -> Texture2D:
	if icon != null:
		return icon

	return TilesetIconLoader.get_icon(icon_tileset_path, icon_tile, icon_tile_size)
