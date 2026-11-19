class_name EnemyData
extends Resource

@export var enemy_id: String = ""
@export var enemy_name: String = ""
## Hình ảnh đại diện cho quái vật này
@export var sprite_texture: Texture2D
@export var max_hp: int = 100
@export var armor: int = 0
@export var move_speed: float = 50
@export var reward_gold: int = 10
@export var base_damage: int = 1

##Khả năng tự hồi phục tính theo %máu
@export var base_regen_percent: float = 0.01

##Thuộc tính miễn nhiễm trạng thái
@export var stun_immunity: bool = false
@export var slow_immunity: bool = false

##Skill khiên miễn thương theo đòn đánh
@export var has_hit_shield_skill: bool = false
@export var hit_shield: int = 10
@export var break_shield_duration: float = 5
@export var hit_shield_skill_cd: float = 20

##Skill bất tử
@export var has_immortal_skill: bool = false
@export var immortal_skill_duration: float = 2
@export var immortal_skill_cd: float = 10

##Skill nghỉ ngơi
@export var has_rest_skill: bool = false
@export var rest_skill_duration: float = 5.0
@export var rest_skill_cd: float = 30
