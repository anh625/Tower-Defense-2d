class_name Projectile
extends Area2D

const EXPLOSION_FX_PATH: String = "res://scenes/effects/explosion_fx.tscn"

@export var speed: float = 650.0
var damage: float = 10.0
var target: Enemy = null

## 1. Thuộc tính của Tháp Cung Thủ (Archer)
var is_crit: bool = false
var bonus_vs_fast: bool = false

## 2. Thuộc tính của Tháp Kiếm / Doanh Trại (Barrack Sword Slash)
var is_sword_slash: bool = false
var slash_level: int = 1
var slash_radius: float = 65.0
var max_slash_targets: int = 3

## 3. Thuộc tính của Tháp Pháp Sư (Wizard Orb)
var is_wizard_magic: bool = false
var wizard_level: int = 1
var armor_penetration: float = 0.0      # Lv1: 0.5 (50%), Lv2 & Lv3: 1.0 (100% True Damage)
var magic_splash_radius: float = 0.0    # Lv2: 75px, Lv3: 95px
var magic_splash_ratio: float = 0.5     # Tỷ lệ sát thương nổ lan vùng phụ
var applies_nebula_burn: bool = false   # Lv3: Đốt 3% Max HP/s trong 3 giây & giật sét 3 mục tiêu

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	if is_sword_slash:
		_execute_sword_slash_aoe()
		return

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
		
	if is_crit and sprite:
		sprite.scale *= 1.35
		sprite.modulate = Color(1.0, 0.85, 0.2, 1.0)
	elif is_wizard_magic and sprite:
		if wizard_level == 2:
			sprite.scale *= 1.2
			sprite.modulate = Color(0.5, 0.85, 1.0, 1.0) # Cầu phép xanh lam sáng ở Lv2
		elif wizard_level >= 3:
			sprite.scale *= 1.4
			sprite.modulate = Color(0.9, 0.35, 1.0, 1.0) # Cầu Tinh Vân tím rực ở Lv3


func _physics_process(delta: float) -> void:
	if is_sword_slash:
		return
		
	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return
	
	var target_pos: Vector2 = target.global_position
	var direction: Vector2 = (target_pos - global_position).normalized()
	
	global_position += direction * speed * delta
	rotation = direction.angle()


func set_target(enemy: Enemy) -> void:
	target = enemy


func _on_area_entered(area: Area2D) -> void:
	if is_sword_slash:
		return
	var enemy: Enemy = area.get_owner() as Enemy
	if not enemy:
		enemy = area.get_parent() as Enemy
		
	if enemy and enemy == target and not enemy.is_dead:
		hit_target(enemy)


## Xử lý khi đạn chạm mục tiêu chính (Cung Thủ & Pháp Sư)
func hit_target(enemy: Enemy) -> void:
	AudioManager.play_sfx("projectile_hit")
	
	var final_damage: float = damage
	if bonus_vs_fast and enemy.data and enemy.data.move_speed >= 150.0:
		final_damage *= 1.5
	if is_crit:
		final_damage *= 2.0
		
	# Gây sát thương lên mục tiêu chính (có tính % xuyên giáp nếu là Pháp Sư)
	enemy.take_damage(final_damage, armor_penetration)
	
	# Nếu là đạn của Tháp Pháp Sư -> Kích hoạt hiệu ứng phép thuật theo Level
	if is_wizard_magic:
		_handle_wizard_magic_impact(enemy, final_damage)
	else:
		_spawn_hit_vfx(global_position, Vector2(0.7, 0.7), Color(1.0, 0.6, 0.1, 1.0))
		
	queue_free()


## Xử lý Nổ lan (Lv2) và Hủy Diệt Tinh Vân + Giật năng lượng (Lv3) của Tháp Pháp Sư
func _handle_wizard_magic_impact(main_enemy: Enemy, main_damage: float) -> void:
	var impact_pos: Vector2 = main_enemy.global_position
	var vfx_color := Color(0.6, 0.4, 1.0, 1.0) if wizard_level < 3 else Color(0.95, 0.25, 1.0, 1.0)
	var vfx_scale := Vector2(0.85, 0.85) if wizard_level == 1 else Vector2(1.25, 1.25)
	_spawn_hit_vfx(impact_pos, vfx_scale, vfx_color)
	
	# Level 3: Đốt máu mục tiêu chính theo % Max HP (3% mỗi giây trong 3.5 giây)
	if applies_nebula_burn and is_instance_valid(main_enemy) and not main_enemy.is_dead:
		main_enemy.apply_nebula_burn(0.03, 3.5)
		
	# Level 2 & Level 3: Nổ lan sát thương chuẩn ra xung quanh
	if magic_splash_radius > 0.0:
		var all_enemies = get_tree().get_nodes_in_group("enemies")
		var radius_sq: float = magic_splash_radius * magic_splash_radius
		var chain_count: int = 0
		var max_chains: int = 3 # Level 3 giật tia năng lượng Tinh Vân sang tối đa 3 mục tiêu phụ
		
		for node in all_enemies:
			var other: Enemy = node as Enemy
			if is_instance_valid(other) and not other.is_dead and other != main_enemy:
				if impact_pos.distance_squared_to(other.global_position) <= radius_sq:
					# Gây sát thương nổ lan xuyên 100% giáp
					other.take_damage(main_damage * magic_splash_ratio, armor_penetration)
					
					# Nếu là Level 3: Giật sét Tinh Vân và đốt máu luôn các mục tiêu phụ
					if applies_nebula_burn and chain_count < max_chains:
						chain_count += 1
						other.apply_nebula_burn(0.02, 2.5)
						_spawn_nebula_lightning_line(impact_pos, other.global_position)
						_spawn_hit_vfx(other.global_position, Vector2(0.75, 0.75), vfx_color)


## Vẽ tia sét năng lượng Tinh Vân nối từ mục tiêu chính sang mục tiêu phụ ở Level 3
func _spawn_nebula_lightning_line(from_pos: Vector2, to_pos: Vector2) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.95, 0.4, 1.0, 0.95)
	var mid_pos: Vector2 = (from_pos + to_pos) * 0.5 + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
	line.add_point(from_pos)
	line.add_point(mid_pos)
	line.add_point(to_pos)
	
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(line)
		var tween: Tween = line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.22)
		tween.tween_callback(line.queue_free)


## Xử lý nhát chém Kiếm Khí AoE của Hiệp sĩ theo 3 Level
func _execute_sword_slash_aoe() -> void:
	AudioManager.play_sfx("projectile_hit")
	
	if sprite:
		var start_scale: Vector2 = sprite.scale
		if slash_level == 2:
			sprite.modulate = Color(0.4, 0.9, 1.0, 1.0)
			start_scale *= 1.25
		elif slash_level >= 3:
			sprite.modulate = Color(1.0, 0.55, 0.15, 1.0)
			start_scale *= 1.5
			
		sprite.scale = start_scale * 0.5
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", start_scale * 1.35, 0.2)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.22)
		tween.chain().tween_callback(queue_free)
	else:
		get_tree().create_timer(0.1).timeout.connect(queue_free)

	var hit_enemies: Array[Enemy] = []
	if is_instance_valid(target) and not target.is_dead:
		hit_enemies.append(target)
		
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var radius_sq: float = slash_radius * slash_radius
	
	for node in all_enemies:
		if hit_enemies.size() >= max_slash_targets:
			break
		var e: Enemy = node as Enemy
		if is_instance_valid(e) and not e.is_dead and e != target:
			if global_position.distance_squared_to(e.global_position) <= radius_sq:
				hit_enemies.append(e)

	for e in hit_enemies:
		if not is_instance_valid(e) or e.is_dead:
			continue
			
		if slash_level >= 3:
			e.apply_armor_break(6, 3.0)
			e.apply_freeze(0.05, 0.35)
			get_tree().create_timer(0.35).timeout.connect(func():
				if is_instance_valid(e) and not e.is_dead:
					e.apply_freeze(0.65, 2.0)
			)
		elif slash_level == 2:
			e.apply_freeze(0.65, 2.0)
			
		e.take_damage(damage)
		_spawn_hit_vfx(e.global_position, Vector2(0.85, 0.85), Color(1.0, 0.85, 0.4, 1.0))


func _spawn_hit_vfx(pos: Vector2, fx_scale: Vector2, fx_color: Color) -> void:
	if not ResourceLoader.exists(EXPLOSION_FX_PATH):
		return
	var fx_scene: PackedScene = load(EXPLOSION_FX_PATH) as PackedScene
	if fx_scene:
		var fx: CPUParticles2D = fx_scene.instantiate() as CPUParticles2D
		fx.global_position = pos
		if is_crit:
			fx.scale = Vector2(1.1, 1.1)
			fx.color = Color(1.0, 0.8, 0.1, 1.0)
		else:
			fx.scale = fx_scale
			fx.color = fx_color
		get_tree().current_scene.add_child(fx)
