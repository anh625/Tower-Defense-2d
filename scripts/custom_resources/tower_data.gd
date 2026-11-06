# res://scripts/custom_resources/tower_data.gd
class_name TowerData
extends Resource

@export var tower_id: String = ""
@export var tower_name: String = ""
@export var max_level: int = 3
@export var cost: int = 100

## Mảng chứa texture hiển thị tòa tháp theo từng cấp [Lv1, Lv2, Lv3]
@export var sprites: Array[Texture2D] = []

## Mảng chứa texture lính Hiệp sĩ đi kèm theo từng cấp [Lv1, Lv2, Lv3] (Dùng cho Tháp Kiếm)
@export var unit_sprites: Array[Texture2D] = []

@export var base_damage: Array[float] = [20.0, 35.0, 55.0]
@export var attack_range: Array[float] = [150.0, 175.0, 200.0]
@export var attack_speed: Array[float] = [1.2, 1.4, 1.6]
@export var upgrade_cost: Array[int] = [75, 120]
@export var projectile_scene: PackedScene
