class_name SkillManager
extends Node2D

signal cooldown_updated(meteor_cd: float, freeze_cd: float)

const EXPLOSION_FX_PATH: String = "res://scenes/effects/explosion_fx.tscn"

@export var max_meteor_cooldown: float = 15.0
@export var max_freeze_cooldown: float = 20.0
@export var meteor_radius: float = 120.0
@export var meteor_damage: float = 80.0
@export var freeze_duration: float = 4.0
@export var freeze_slow_ratio: float = 0.2 # Làm chậm còn 20% tốc độ (đặt 0.0 nếu muốn đứng im hoàn toàn)

var meteor_cooldown: float = 0.0
var freeze_cooldown: float = 0.0
var is_meteor_ready: bool = true
var is_freeze_ready: bool = true


func _process(delta: float) -> void:
	_update_cooldowns(delta)


func _update_cooldowns(delta: float) -> void:
	var changed: bool = false
	
	if not is_meteor_ready:
		meteor_cooldown = maxf(0.0, meteor_cooldown - delta)
		changed = true
		if meteor_cooldown <= 0.0:
			is_meteor_ready = true
			
	if not is_freeze_ready:
		freeze_cooldown = maxf(0.0, freeze_cooldown - delta)
		changed = true
		if freeze_cooldown <= 0.0:
			is_freeze_ready = true
			
	if changed:
		cooldown_updated.emit(meteor_cooldown, freeze_cooldown)


# ==========================================
# KỸ NĂNG 1: MƯA THIÊN THẠCH - AOE (SCRUM-74)
# ==========================================

func cast_meteor_strike(target_pos: Vector2) -> void:
	if not is_meteor_ready:
		return
		
	is_meteor_ready = false
	meteor_cooldown = max_meteor_cooldown
	cooldown_updated.emit(meteor_cooldown, freeze_cooldown)
	
	# 1. Phát âm thanh và hiệu ứng nổ diện rộng tại target_pos
	AudioManager.play_sfx("projectile_hit")
	_spawn_meteor_vfx(target_pos)
	
	# 2. Quét toàn bộ quái trong bán kính nổ (meteor_radius) và gây sát thương
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for node in enemies:
		var enemy := node as Enemy
		if is_instance_valid(enemy) and not enemy.is_dead:
			if enemy.global_position.distance_to(target_pos) <= meteor_radius:
				enemy.take_damage(meteor_damage)


func _spawn_meteor_vfx(target_pos: Vector2) -> void:
	# Sinh hiệu ứng hạt nổ lớn từ explosion_fx.tscn
	if ResourceLoader.exists(EXPLOSION_FX_PATH):
		var fx_scene: PackedScene = load(EXPLOSION_FX_PATH) as PackedScene
		if fx_scene:
			var fx: CPUParticles2D = fx_scene.instantiate() as CPUParticles2D
			fx.global_position = target_pos
			fx.scale = Vector2(3.5, 3.5)
			fx.color = Color(1.0, 0.35, 0.1, 1.0)
			get_tree().current_scene.add_child(fx)
			
	# Vẽ vòng sóng xung kích lửa bung ra rồi mờ dần
	var shockwave := Node2D.new()
	shockwave.global_position = target_pos
	shockwave.draw.connect(func():
		shockwave.draw_circle(Vector2.ZERO, meteor_radius, Color(1.0, 0.4, 0.1, 0.35))
		shockwave.draw_arc(Vector2.ZERO, meteor_radius, 0.0, TAU, 48, Color(1.0, 0.2, 0.0, 0.9), 4.0)
	)
	get_tree().current_scene.add_child(shockwave)
	
	var tween: Tween = create_tween()
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.45)
	tween.tween_callback(shockwave.queue_free)


# ==========================================
# KỸ NĂNG 2: ĐÓNG BĂNG TOÀN BẢN ĐỒ (SCRUM-75)
# ==========================================

func cast_freeze_all() -> void:
	if not is_freeze_ready:
		return
		
	is_freeze_ready = false
	freeze_cooldown = max_freeze_cooldown
	cooldown_updated.emit(meteor_cooldown, freeze_cooldown)
	
	# 1. Phát âm thanh và hiệu ứng sương băng phủ màn hình
	AudioManager.play_sfx("wave_start")
	_spawn_freeze_screen_vfx()
	
	# 2. Duyệt toàn bộ Enemy đang có trên bản đồ để làm chậm
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for node in enemies:
		var enemy := node as Enemy
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.apply_freeze(freeze_slow_ratio, freeze_duration)


func _spawn_freeze_screen_vfx() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	
	var frost_rect := ColorRect.new()
	frost_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	frost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frost_rect.color = Color(0.4, 0.85, 1.0, 0.28) # Lớp phủ xanh băng bán trong suốt
	canvas.add_child(frost_rect)
	get_tree().current_scene.add_child(canvas)
	
	var tween: Tween = create_tween()
	tween.tween_property(frost_rect, "color:a", 0.0, freeze_duration)
	tween.tween_callback(canvas.queue_free)
