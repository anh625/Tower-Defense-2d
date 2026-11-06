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

## Hiệu ứng Phá Giáp từ Tháp Kiếm Level 3
var armor_debuff: int = 0
var armor_debuff_timer: float = 0.0

## Hiệu ứng Đốt máu Tinh Vân (% Max HP) từ Tháp Pháp Sư Level 3
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0
var burn_percent_per_sec: float = 0.0

# Thêm hằng số đường dẫn VFX ở đầu file enemy.gd:
const EXPLOSION_FX_PATH: String = "res://scenes/effects/explosion_fx.tscn"

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

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
		
	# 1. Đếm ngược thời gian làm chậm / đóng băng
	if freeze_timer > 0.0:
		freeze_timer -= delta
		if freeze_timer <= 0.0:
			reset_default_speed()
			
	# 2. Đếm ngược thời gian bị Phá Giáp (Tháp Kiếm Lv3)
	if armor_debuff_timer > 0.0:
		armor_debuff_timer -= delta
		if armor_debuff_timer <= 0.0:
			armor_debuff = 0
			armor_debuff_timer = 0.0
			_update_status_color()
			
	# 3. Đếm ngược và gây sát thương Đốt máu % Max HP (Tháp Pháp Sư Lv3)
	if burn_timer > 0.0:
		burn_timer -= delta
		burn_tick_timer -= delta
		if burn_tick_timer <= 0.0:
			burn_tick_timer = 0.5
			_process_nebula_burn_tick()
		if burn_timer <= 0.0:
			burn_timer = 0.0
			burn_percent_per_sec = 0.0
			_update_status_color()
	
	# Di chuyển theo Path2D
	var move_speed: float = data.move_speed if data else 100.0
	progress += move_speed * speed_multiplier * delta
	
	if progress_ratio >= 1.0:
		reach_base()


## Nhận sát thương (Hỗ trợ cả Phá Giáp phẳng của Tháp Kiếm và % Xuyên Giáp của Pháp Sư)
func take_damage(damage: float, armor_penetration: float = 0.0) -> void:
	if is_dead:
		return
	var base_armor: int = data.armor if data else 0
	
	# 1. Trừ giáp phẳng từ Tháp Kiếm Level 3
	var reduced_armor: float = float(max(0, base_armor - armor_debuff))
	# 2. Nhân với tỷ lệ xuyên giáp của Tháp Pháp Sư (Lv1: xuyên 50% -> còn 0.5; Lv2-3: xuyên 100% -> còn 0.0)
	var effective_armor: float = reduced_armor * clampf(1.0 - armor_penetration, 0.0, 1.0)
	var actual_damage: int = int(max(1.0, damage - effective_armor))
	
	current_hp -= actual_damage
	if current_hp <= 0:
		die()
		
## Áp dụng hiệu ứng Đốt máu Tinh Vân theo % Máu tối đa (Tháp Pháp Sư Level 3)
func apply_nebula_burn(percent_per_sec: float, duration: float) -> void:
	if is_dead:
		return
	burn_percent_per_sec = maxf(burn_percent_per_sec, percent_per_sec)
	burn_timer = maxf(burn_timer, duration)
	if burn_tick_timer <= 0.0:
		burn_tick_timer = 0.5
	_update_status_color()
	
## Trừ máu theo % Max HP mỗi 0.5 giây (Bỏ qua hoàn toàn giáp)
func _process_nebula_burn_tick() -> void:
	if is_dead or not data:
		return
	# Ví dụ: 3% Max HP/giây -> mỗi 0.5s đốt 1.5% Max HP (Boss 3000 máu mất 45 máu/nhịp)
	var burn_dmg: int = int(max(2.0, data.max_hp * burn_percent_per_sec * 0.5))
	current_hp -= burn_dmg
	if current_hp <= 0:
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

## Nhận hiệu ứng Đóng băng / Làm chậm (Chỉ ghi đè nếu mức làm chậm mới mạnh hơn hoặc bằng)
func apply_freeze(slow_ratio: float, duration: float) -> void:
	if is_dead:
		return
	var clamped_ratio: float = clampf(slow_ratio, 0.0, 1.0)
	if freeze_timer <= 0.0 or clamped_ratio <= speed_multiplier:
		speed_multiplier = clamped_ratio
	freeze_timer = maxf(freeze_timer, duration)
	_update_status_color()
	
## Nhận hiệu ứng Phá Giáp từ Tháp Kiếm Level 3 (Trừ giáp tạm thời)
func apply_armor_break(reduction_amount: int, duration: float) -> void:
	if is_dead:
		return
	armor_debuff = max(armor_debuff, reduction_amount)
	armor_debuff_timer = maxf(armor_debuff_timer, duration)
	_update_status_color()

## Khôi phục tốc độ gốc khi hết thời gian làm chậm
func reset_default_speed() -> void:
	speed_multiplier = 1.0
	freeze_timer = 0.0
	_update_status_color()
	
## Đổi màu hiển thị trạng thái trên người quái (Xanh băng khi chậm, Cam tím khi vỡ giáp)
## Đổi màu hiển thị trạng thái trên người quái
func _update_status_color() -> void:
	if not sprite:
		sprite = find_child("Sprite2D", true, false) as Sprite2D
	if not sprite:
		return
		
	if burn_timer > 0.0:
		sprite.modulate = Color(0.85, 0.35, 1.0, 1.0) # Tím Tinh Vân (Đang bị đốt % máu tối đa)
	elif freeze_timer > 0.0 and armor_debuff_timer > 0.0:
		sprite.modulate = Color(0.75, 0.5, 1.0, 1.0)  # Tím sáng (Chậm + Vỡ giáp)
	elif freeze_timer > 0.0:
		sprite.modulate = Color(0.3, 0.8, 1.0, 1.0)   # Xanh băng (Đang bị làm chậm)
	elif armor_debuff_timer > 0.0:
		sprite.modulate = Color(1.0, 0.65, 0.3, 1.0)  # Cam rực (Đang bị Phá Giáp)
	else:
		sprite.modulate = Color.WHITE
