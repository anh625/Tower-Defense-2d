class_name Enemy
extends PathFollow2D

## Tín hiệu thông báo khi kết thúc vòng đời
signal died(gold: int)
signal reached_base(damage: int)

## Dữ liệu cấu hình quái (nạp từ file .tres)
@export var data: EnemyData

var current_hp: int = 0
var is_dead: bool = false
var speed_multiplier: float = 1.0
var freeze_timer: float = 0.0
# Thêm hằng số đường dẫn VFX ở đầu file enemy.gd:
const EXPLOSION_FX_PATH: String = "res://scenes/effects/explosion_fx.tscn"

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("enemies")
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
		
	if freeze_timer > 0.0:
		freeze_timer -= delta
		if freeze_timer <= 0.0:
			reset_default_speed()
	
	# Di chuyển tịnh tiến dọc theo ray Path2D
	var move_speed: float = data.move_speed if data else 100.0
	progress += move_speed * delta * speed_multiplier
	
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
	AudioManager.play_sfx("enemy_die")
	_spawn_death_vfx()
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
	
func _spawn_death_vfx() -> void:
	if not ResourceLoader.exists(EXPLOSION_FX_PATH):
		return
	var fx_scene: PackedScene = load(EXPLOSION_FX_PATH) as PackedScene
	if fx_scene:
		var fx: CPUParticles2D = fx_scene.instantiate() as CPUParticles2D
		fx.global_position = global_position
		fx.scale = Vector2(1.5, 1.5) # Nổ to hơn khi quái bị tiêu diệt
		fx.color = Color(1.0, 0.3, 0.2, 1.0) # Đổi sang tông đỏ cam bắt mắt
		get_tree().current_scene.add_child(fx)

## Áp dụng hiệu ứng làm chậm / đóng băng và phủ màu xanh băng giá
func apply_freeze(slow_ratio: float, duration: float) -> void:
	if is_dead:
		return
	speed_multiplier = clampf(slow_ratio, 0.0, 1.0)
	freeze_timer = maxf(freeze_timer, duration)
	if sprite:
		sprite.modulate = Color(0.4, 0.85, 1.0, 1.0) # Phủ màu xanh băng


## Khôi phục tốc độ di chuyển và màu sắc ban đầu khi hết thời gian đóng băng
func reset_default_speed() -> void:
	speed_multiplier = 1.0
	freeze_timer = 0.0
	if sprite:
		sprite.modulate = Color.WHITE
