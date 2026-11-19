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

## Hiệu ứng Phá Giáp từ Tháp Cung Level 3
var armor_debuff: int = 0
var armor_debuff_timer: float = 0.0
var armor_break_vuln: float = 0.0
var armor_break_timer: float = 0.0
var is_armor_break_immunity: bool = false
var armor_break_immunity_timer: float = 0.0

## Hiệu ứng Đốt máu Tinh Vân (% Max HP) từ Tháp Pháp Sư Level 3
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0
var burn_percent_per_sec: float = 0.0

## Hiệu ứng bất tử
var is_immortal: bool = false
var hit_armor: int = 0
var hit_armor_timer: float = 0.0

##Hiệu ứng tự hồi phục
var regen_tick_timer: float = 1.0
var regen_bonus: float = 0.0
var ultra_regeneration_timer: float = 0.0
var heal_reduction: float = 0.0
var heal_reduction_timer: float = 0.0

## Hiệu ứng miễn choáng
var is_stun_immunity: bool = false
var stun_immunity_timer: float = 0.0

## Hiệu ứng miễn chậm
var is_slow_immunity: bool = false
var slow_immunity_timer: float = 0.0

##Skill bất tử:
var immortal_timer: float = 0.0
var immortal_cd: float = 0.0
var is_immortal_ready: bool = false

##Skill nghỉ ngơi:
var rest_cd: float = 0.0
var is_rest_ready: bool = false

##Skill khiên miễn thương
var hit_shield: int = 0
var hit_shield_cd: float = 0.0
var is_hit_shield_ready: bool = false

##Hiệu ứng phá khiên
var shield_break_vuln: float = 0.0
var shield_break_timer: float = 0.0

var total_dmg_taken: float = 0

# Thêm hằng số đường dẫn VFX ở đầu file enemy.gd:
const EXPLOSION_FX_PATH: String = "res://scenes/effects/explosion_fx.tscn"

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var hp_label: Label = find_child("HpEnemy", true, false) as Label
@onready var hit_armor_label: Label = find_child("HitArmorLabel", true, false) as Label
@onready var hit_shield_label: Label = find_child("HitShieldLabel", true, false) as Label

var min_hp: int

func _ready() -> void:
	add_to_group("enemies")
	if data:
		current_hp = data.max_hp
		#current_hp = 100
		# Tự động nạp hình dạng quái từ EnemyData.tres
		if data.sprite_texture != null and sprite != null:
			sprite.texture = data.sprite_texture
			#print("Đã nạp sprite cho enemy")
	else:
		current_hp = 100
	min_hp = current_hp
	hp_label.text = str(current_hp)
	hit_armor_label.visible = false
	hit_shield_label.visible = false
	#hp_label.modulate = Color()
	
	#Kiểm tra xem có skill miễn thương không?
	if data.has_hit_shield_skill:
		is_hit_shield_ready = true
		
	#Kiểm tra xem có skill bất tử không?
	if data.has_immortal_skill:
		immortal_cd = data.immortal_skill_cd
		
	#Kiểm tra xem có skill nghỉ ngơi không?
	if data.has_rest_skill:
		rest_cd = data.rest_skill_cd
	

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	#========================================
	#Debuff quái
	#========================================
	#Đếm ngược thời gian làm chậm / đóng băng
	if freeze_timer > 0.0:
		freeze_timer -= delta
		if freeze_timer <= 0.0:
			reset_default_speed()
			
	#Đếm ngược thời gian bị Trừ giáp
	if armor_debuff_timer > 0.0:
		armor_debuff_timer -= delta
		if armor_debuff_timer <= 0.0:
			armor_debuff = 0
			armor_debuff_timer = 0.0
			#print("armor_debuff_timer end")
			_update_status_color()
			
	#Đếm ngược và gây sát thương Đốt máu % Max HP
	if burn_timer > 0.0:
		burn_timer -= delta
		burn_tick_timer -= delta
		if burn_tick_timer <= 0.0:
			burn_tick_timer = 0.5
			_process_nebula_burn_tick()
		if burn_timer <= 0.0:
			burn_timer = 0.0
			burn_percent_per_sec = 0.0
			#print("burn_timer end")
			_update_status_color()
	
	if hit_armor_timer > 0:
		hit_armor_timer -= delta
		if hit_armor_timer <= 0:
			hit_armor_timer = 0
			cancel_hit_armor()
 	
	if armor_break_timer > 0:
		armor_break_timer -= delta
		if armor_break_timer <= 0:
			armor_break_timer = 0
			armor_break_vuln = 0
			
	if heal_reduction_timer > 0:
		heal_reduction_timer -= delta
		if heal_reduction_timer <= 0:
			heal_reduction_timer = 0
			heal_reduction = 0
			
	#========================================
	#Trạng thái miễn nhiễm
	#========================================
	#Đếm ngược thời gian miễn choáng
	if stun_immunity_timer > 0.0:
		stun_immunity_timer -= delta
		if stun_immunity_timer <= 0.0:
			is_stun_immunity = data.stun_immunity
			stun_immunity_timer = 0
			#print("stun_immunity_timer end")
			_update_status_color()
	
	if slow_immunity_timer > 0.0:
		slow_immunity_timer -= delta
		if slow_immunity_timer <= 0.0:
			is_slow_immunity = data.slow_immunity
			slow_immunity_timer = 0
			#print("slow_immunity_timer end")
			_update_status_color()
	
	if armor_break_immunity_timer > 0:
		armor_break_immunity_timer -= delta
		if armor_break_immunity_timer <= 0:
			armor_break_immunity_timer = 0
			is_armor_break_immunity = false
			#print("armor_break_immunity_timer end")
			_update_status_color()
			
	#========================================
	#Skill quái
	#========================================
	#Tự hồi phục:
	if regen_tick_timer > 0:
		regen_tick_timer -= delta
		if regen_tick_timer <= 0:
			self_recovery()
			regen_tick_timer = 1
	
	#Tự thi triển skill immortal
	if is_immortal_ready:
		activate_immortal()
	
	if immortal_timer > 0:
		immortal_timer -= delta
		if immortal_timer <= 0:
			cancel_immortal()
			immortal_timer = 0
	
	if immortal_cd > 0:
		immortal_cd -= delta
		if immortal_cd <= 0:
			immortal_cd = 0
			is_immortal_ready = true
			
	#Tự thi triển skill hit shield
	if is_hit_shield_ready:
		activate_shield()
	
	if shield_break_timer > 0:
		shield_break_timer -= 0
		if shield_break_timer <= 0:
			shield_break_timer = 0
			#print("shield_break_timer end")
	
	if hit_shield_cd > 0:
		hit_shield_cd -= delta
		if hit_shield_cd <= 0:
			is_hit_shield_ready = true
			hit_shield_cd = 0
			#print("hit_shield_cd end")
	
	#Tự thi triển skill rest
	if is_rest_ready:
		activate_rest()
	
	#Skill siêu hồi phục:
	if ultra_regeneration_timer > 0:
		ultra_regeneration_timer -= delta
		if ultra_regeneration_timer <= 0:
			ultra_regeneration_timer = 0
			regen_bonus = 0
	
	if rest_cd > 0:
		rest_cd -= delta
		if rest_cd <= 0:
			is_rest_ready = true
			rest_cd = 0
			
	# Di chuyển theo Path2D
	var move_speed: float = data.move_speed if data else 100.0
	progress += move_speed * speed_multiplier * delta
	hp_label.text = str(current_hp)
	
	if progress_ratio >= 1.0:
		reach_base()

## Nhận sát thương (Hỗ trợ cả Phá Giáp phẳng của Tháp Kiếm và % Xuyên Giáp của Pháp Sư)
func take_damage(damage: float, armor_penetration: float = 0.0) -> void:
	if hit_shield > 0:
		hit_shield -= 1
		hit_shield_label.text = str(hit_shield)
		if hit_shield <= 0:
			break_shield()
		return
	
	if not is_armor_break_immunity:
		if hit_armor > 0:
			hit_armor -= 1
			hit_armor_label.text = str(hit_armor)
			if hit_armor <= 0:
				apply_armor_break_debuff()
			
	if is_dead or is_immortal:
		return
	var base_armor: int = data.armor if data else 0
	
	# 1. Trừ giáp phẳng từ Tháp Kiếm Level 3
	var reduced_armor: float = float(max(0, base_armor - armor_debuff))
	# 2. Nhân với tỷ lệ xuyên giáp của Tháp Pháp Sư (Lv1: xuyên 50% -> còn 0.5; Lv2-3: xuyên 100% -> còn 0.0)
	var effective_armor: float = reduced_armor * clampf(1.0 - armor_penetration, 0.0, 1.0)
	var final_dmg = (damage - effective_armor)*(1+shield_break_vuln)*(1+armor_break_vuln)
	var actual_damage: int = int(max(1.0, final_dmg))
	
	current_hp -= actual_damage
	#if current_hp < min_hp:
		#min_hp = current_hp
		#print("min_hp: ", min_hp)
	#total_dmg_taken += actual_damage
	#print("total_dmg_taken: ", total_dmg_taken)
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
	#print("apply_nebula_burn")
	_update_status_color()
	
## Trừ máu theo % Max HP mỗi 0.5 giây (Bỏ qua hoàn toàn giáp)
func _process_nebula_burn_tick() -> void:
	if is_dead or not data or is_immortal:
		return
	# Ví dụ: 3% Max HP/giây -> mỗi 0.5s đốt 1.5% Max HP (Boss 3000 máu mất 45 máu/nhịp)
	var burn_dmg: int = int(clampf(data.max_hp * burn_percent_per_sec * 0.5, 2.0, 25))
	current_hp -= burn_dmg
	#if current_hp < min_hp:
		#min_hp = current_hp
		#print("min_hp: ", min_hp)
	#total_dmg_taken += burn_dmg
	#print("total_dmg_taken: ", total_dmg_taken)
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
	
	#Chỉ giữ lại hiệu ứng làm chậm hơn ở trên quái
	if slow_ratio > speed_multiplier:
		return
	
	#Miễn choáng nếu trong trạng thái miễn choáng
	if slow_ratio <= 0.05 and is_stun_immunity:
		return
	
	#Miễn chậm nếu trong trạng thái miễn chậm
	if slow_ratio > 0.05 and is_slow_immunity:
		return
			
	var clamped_ratio: float = clampf(slow_ratio, 0.0, 1.0)
	
	#Quái máu càng dày thì thời gian choáng càng giảm nhiều
	if clamped_ratio <= 0.05:
		var max_hp = maxf(1,data.max_hp)
		duration = 0.4 + 0.4/(1+(max_hp/3100)*(max_hp/3100))
		
		#thời gian miễn choáng
		stun_immunity_timer = maxf(stun_immunity_timer, \
							1 + 2/(1 + 3100*3100/(0.01+max_hp*max_hp)))
		is_stun_immunity = true
			
	if clamped_ratio == speed_multiplier:
		freeze_timer = maxf(freeze_timer, duration)
	else:
		speed_multiplier = clamped_ratio
		freeze_timer = duration
	#print("apply_freeze")
	_update_status_color()
	
## Nhận hiệu ứng Trừ giáp tạm thời
func apply_armor_debuff(reduction_amount: int, duration: float) -> void:
	if is_dead:
		return
	armor_debuff = max(armor_debuff, reduction_amount)
	armor_debuff_timer = maxf(armor_debuff_timer, duration)
	#print("apply_armor_debuff")
	_update_status_color()

##Nhận hiệu ứng tạo khiên ảo để phá
func apply_hit_armor(duration: float = 1) -> void:
	if is_armor_break_immunity:
		return
	
	if data.armor <= 0:
		return
		
	if hit_armor <= 0:
		hit_armor = data.armor
		hit_armor_label.visible = true
		hit_armor_label.text = str(hit_armor)
	hit_armor_timer = duration
	#print("apply_hit_armor")
	_update_status_color()

func cancel_hit_armor() -> void:
	hit_armor = 0
	hit_armor_timer = 0
	hit_armor_label.visible = false
	#print("cancel_hit_armor")
	_update_status_color()

## Nhận hiệu ứng Phá giáp Cung Lv3
func apply_armor_break_debuff(duration: float = 5) -> void:
	if is_dead:
		return
	#print("apply_armor_break_debuff")
	hit_armor_label.visible = false
	var multipliar: float = float(data.armor)/100
	armor_break_vuln = multipliar
	armor_break_timer = duration
	is_armor_break_immunity = true
	armor_break_immunity_timer = duration
	apply_armor_debuff(data.armor, duration)
	apply_freeze(1 - multipliar, duration)
	_update_status_color()

func apply_heal_reduction(multipliar_reduction: float, duration: float) -> void:
	if is_dead:
		return
		
	heal_reduction = multipliar_reduction
	heal_reduction_timer = duration
	#print("apply_heal_reduction")

	_update_status_color()

## Khôi phục tốc độ gốc khi hết thời gian làm chậm
func reset_default_speed() -> void:
	speed_multiplier = 1.0
	freeze_timer = 0.0
	#print("reset_default_speed")
	
	_update_status_color()
	
## Đổi màu hiển thị trạng thái trên người quái (Xanh băng khi chậm, Cam tím khi vỡ giáp)
## Đổi màu hiển thị trạng thái trên người quái
func _update_status_color() -> void:
	if not sprite:
		sprite = find_child("Sprite2D", true, false) as Sprite2D
	if not sprite:
		return
	
	#print("_update_status_color")
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

# ==========================================
# Skill
# ==========================================
##Skill tạo khiên
func activate_shield() -> void:
	if is_hit_shield_ready:
		is_hit_shield_ready = false
		hit_shield = max(0, data.hit_shield)
		hit_shield_label.visible = true
		hit_shield_label.text = str(hit_shield)
		is_immortal = true
		is_slow_immunity = data.slow_immunity
		#print("activate_shield")
		_update_status_color()
		
#Phá khiên
func break_shield(duration: float = data.break_shield_duration) -> void:
	#print("break_shield: ", duration, "s")
	hit_shield_label.visible = false
	is_immortal = false
	hit_shield_cd = maxf(data.hit_shield_skill_cd, duration*2)
	shield_break_vuln = 0.5
	shield_break_timer = duration
	if data.slow_immunity:
		is_slow_immunity = false
	apply_freeze(0.5, duration)
	apply_armor_debuff(data.armor, duration)
	_update_status_color()

func cancel_break_shield() -> void:
	shield_break_vuln = 0.0
	shield_break_timer = 0.0
	#print("cancel_break_shield")
	_update_status_color()
	
##Skill bất tử
func activate_immortal() -> void:
	if is_immortal_ready:
		is_immortal_ready = false
		is_immortal = true
		immortal_cd = maxf(immortal_cd, data.immortal_skill_cd)
		immortal_timer = clampf(data.immortal_skill_duration, 0, immortal_cd/1.25)
		#print("activate_immortal ")
		#print("immortal_cd: ", immortal_cd)
		#print("immortal_timer: ", immortal_timer)
		
		_update_status_color()
		
##Huỷ skill bất tử
func cancel_immortal() -> void:
	is_immortal = false
	#print("cancel_immortal")
	_update_status_color()

##Skill nghỉ ngơi
func activate_rest(duration: float = data.rest_skill_duration) -> void:
	if is_rest_ready:
		#print("activate_rest")
		is_rest_ready = false
		dispel_all_debuff()
		apply_freeze(0.01, 0.4)
		immune_cc(duration)
		activate_ultra_regeneration(0.3, duration)
		rest_cd = maxf(data.rest_skill_cd, duration*2)
		_update_status_color()

##Xoá tất cả hiệu ứng xấu
func dispel_all_debuff() -> void:
	armor_break_vuln = 0.0
	armor_break_timer = 0.0
	
	shield_break_vuln = 0.0
	shield_break_timer = 0.0
	
	armor_debuff = 0
	armor_debuff_timer = 0.0
	reset_default_speed()

#Miễn nhiễm hiệu ứng khống chế
func immune_cc(duration: float) -> void:
	stun_immunity_timer = maxf(stun_immunity_timer, duration)
	slow_immunity_timer = maxf(slow_immunity_timer, duration)
	is_stun_immunity = true
	is_slow_immunity = true
	#print("immune_cc")
	_update_status_color()

#Hồi máu
func self_recovery() -> void:
	var hp_bonus: int = int(data.base_regen_percent*data.max_hp*(1.0+regen_bonus)*(1.0-heal_reduction))
	#if regen_bonus > 0
	current_hp = clampi(current_hp+hp_bonus, 0, data.max_hp)
	#print("hp_bonus: ", hp_bonus)

##Skill siêu hồi phục
func activate_ultra_regeneration(multiplier: float, duration: float) -> void:
	#print("active_ultra_heal")
	regen_bonus =  maxf(multiplier, 0)
	ultra_regeneration_timer = maxf(duration, 0)
	
