class_name GridSystem
extends Node2D

## Tham chiếu TileMapLayer nếu bạn vẽ map bằng TileMapLayer của Godot 4
@export var tilemap_layer: TileMapLayer

## Kích thước thực tế của 1 ô trên màn hình (250x235 nhân scale 0.4)
@export var cell_size: Vector2 = Vector2(100.0, 94.0)

## Dictionary lưu trữ các ô đã bị chiếm dụng: { Vector2i(x, y): Tower }
var occupied_cells: Dictionary = {}


## Chuyển tọa độ thế giới sang tọa độ ô lưới
func world_to_cell(world_pos: Vector2) -> Vector2i:
	if tilemap_layer:
		return tilemap_layer.local_to_map(tilemap_layer.to_local(world_pos))
	return Vector2i(floori(world_pos.x / cell_size.x), floori(world_pos.y / cell_size.y))

## Chuyển tọa độ ô lưới về tâm mặt sàn của ô Isometric
func cell_to_world(cell_pos: Vector2i) -> Vector2:
	if tilemap_layer:
		return tilemap_layer.to_global(tilemap_layer.map_to_local(cell_pos))
	return Vector2(cell_pos.x * cell_size.x + cell_size.x / 2.0, cell_pos.y * cell_size.y + cell_size.y / 2.0)


## Kiểm tra ô lưới có hợp lệ để đặt tháp không
func can_place_at(cell_pos: Vector2i) -> bool:
	# 1. Ô đã có tháp khác cắm chốt chưa?
	if occupied_cells.has(cell_pos) and occupied_cells[cell_pos] != null:
		return false
	
	# 2. Kiểm tra ô đất trên TileMapLayer (nếu có dùng TileMapLayer)
	if tilemap_layer:
		var tile_data = tilemap_layer.get_cell_tile_data(cell_pos)
		if not tile_data:
			return false # Ô rỗng ngoài viền bản đồ
		
		# Đọc Custom Data gán trên TileSet (ví dụ "buildable")
		var is_buildable = tile_data.get_custom_data("buildable")
		if is_buildable != null and not is_buildable:
			return false

	return true


## Đăng ký tháp vào ô lưới
func register_tower(cell_pos: Vector2i, tower: Tower) -> void:
	occupied_cells[cell_pos] = tower


## Hủy đăng ký ô đất khi bán tháp
func unregister_tower(cell_pos: Vector2i) -> void:
	if occupied_cells.has(cell_pos):
		occupied_cells.erase(cell_pos)
