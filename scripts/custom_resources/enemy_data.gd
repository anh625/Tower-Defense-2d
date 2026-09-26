class_name EnemyData
extends Resource

@export var enemy_id: String = ""
@export var enemy_name: String = ""
## Hình ảnh đại diện cho quái vật này
@export var sprite_texture: Texture2D
@export var max_hp: int = 100
@export var armor: int = 0
@export var move_speed: float = 150.0
@export var reward_gold: int = 10
@export var base_damage: int = 1
