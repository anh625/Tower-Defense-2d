class_name LevelData
extends Resource

@export var level_id: int = 1
@export var level_name: String = "Rừng Khởi Nguyên"
@export var starting_gold: int = 250
@export var starting_base_hp: int = 20
@export var tilemap_scene: PackedScene # Scene chứa bản đồ TileMapLayer của màn này
@export var wave_configuration: Array[WaveData] = [] # Danh sách các đợt quái
