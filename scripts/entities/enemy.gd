class_name Enemy
extends PathFollow2D

## Tín hiệu thông báo khi kết thúc vòng đời
signal died(gold: int)
signal reached_base(damage: int)

## Dữ liệu cấu hình quái (nạp từ file .tres)
@export var data: EnemyData

var current_hp: int = 0
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if data:
		current_hp = data.max_hp
		# Tự động nạp hình dạng quái từ EnemyData.tres
		if data.sprite_texture != null and sprite != null:
			sprite.texture = data.sprite_texture
			print("Đã nạp sprite cho enemy")
	else:
		current_hp = 100


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Di chuyển tịnh tiến dọc theo ray Path2D
	var move_speed: float = data.move_speed if data else 100.0
	progress += move_speed * delta
	
	# Kiểm tra khi quái đi hết đường dẫn (chạm tới Nhà chính)
	if progress_ratio >= 1.0:
		reach_base()


## Nhận sát thương khi trúng đạn
func take_damage(damage: float) -> void:
	if is_dead:
		return
		
	# Công thức trừ giáp: Damage thực = max(1, Sát thương cơ bản - Giáp quái)
	var armor: int = data.armor if data else 0
	var actual_damage: int = max(1.0, damage - armor)
	
	current_hp -= actual_damage
	
	if current_hp <= 0.0:
		die()


## Xử lý khi bị hạ gục
func die() -> void:
	if is_dead:
		return
	is_dead = true
	var reward: int = data.reward_gold if data else 10
	died.emit(reward)
	queue_free()


## Xử lý khi lọt vào Nhà chính
func reach_base() -> void:
	if is_dead:
		return
	is_dead = true
	var dmg: int = data.base_damage if data else 1
	reached_base.emit(dmg)
	queue_free()
