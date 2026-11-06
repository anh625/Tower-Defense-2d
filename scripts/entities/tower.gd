class_name Tower
extends Node2D

## Cấu hình dữ liệu của tháp (Nạp từ TowerData.tres)
@export var data: TowerData

## Các chế độ ưu tiên mục tiêu của tháp
enum TargetMode {
	FIRST,  # Xa nhất (Đi đầu / gần Nhà chính nhất trên đường đi, hoặc xa tháp nhất)
	LAST,   # Gần cổng nhất
	STRONGEST, # Mạnh nhất (Nhiều máu hiện tại nhất)
	WEAKEST    # Yếu nhất (Ít máu hiện tại nhất)
}

## Chế độ bắn hiện tại của tháp (Mặc định ưu tiên con đi xa nhất/đầu hàng)
var target_mode: TargetMode = TargetMode.FIRST

## Trạng thái hoạt động
var current_level: int = 1
var cell_pos: Vector2i = Vector2i.ZERO
var total_invested_gold: int = 0

var current_target: Enemy = null
var targets_in_range: Array[Enemy] = []

## Bộ đếm hồi chiêu giữa các đòn đánh
var attack_cooldown: float = 0.0

## Tham chiếu các Node con bên trong Scene
@onready var range_area: Area2D = $RangeArea
@onready var range_collision: CollisionShape2D = $RangeArea/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle_marker: Marker2D = $MuzzleMarker
## Các Node Sprite2D hiển thị lính Hiệp sĩ đứng canh gác dưới chân Tháp Kiếm
var knight_guards: Array[Sprite2D] = []
var knight_home_positions: Array[Vector2] = [Vector2(-28, 18), Vector2(28, 18)]
var is_knight_dashing: bool = false
var next_knight_idx: int = 0
var idle_bob_time: float = 0.0

@onready var upgrade_container: HBoxContainer = find_child("UpgradeContainer", true, false) as HBoxContainer
@onready var upgrade_button: Button = find_child("UpgradeBtn", true, false) as Button
@onready var sell_button: Button = find_child("SellBtn", true, false) as Button

func _ready() -> void:
	if not range_area:
		push_error("Tower: Thiếu Node RangeArea (Area2D)!")
		return
	
	# Kết nối tín hiệu quét quái vật
	# Dùng area_entered nếu quái dùng Area2D (HurtBox), hoặc body_entered nếu quái là CharacterBody2D
	if not range_area.area_entered.is_connected(_on_range_area_entered):
		range_area.area_entered.connect(_on_range_area_entered)
	if not range_area.area_exited.is_connected(_on_range_area_exited):
		range_area.area_exited.connect(_on_range_area_exited)
	
	# Đồng bộ bán kính tầm bắn theo cấp độ hiện tại
	if data:
		total_invested_gold = data.cost
		# Tháp Pháp Sư mặc định ưu tiên nhắm vào quái Mạnh nhất (nhiều máu/giáp nhất)
		if data.tower_id == "tower_wizard":
			target_mode = TargetMode.STRONGEST
		_setup_knight_guards()
		_update_range_shape()
		_update_visual() # Cập nhật hình ảnh ban đầu cho Level 1

func _physics_process(delta: float) -> void:
	# Đếm ngược thời gian hồi đòn
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# Dọn dẹp các quái đã chết hoặc bị giải phóng khỏi bộ nhớ
	_clean_invalid_targets()
	
	# Khóa mục tiêu đi đầu tiên trên đường chạy
	current_target = acquire_target()
	
	# Xoay/lật Sprite hướng về mục tiêu (nếu có quái trong tầm)
	#if current_target != null:
		#var target_dir = (current_target.global_position - global_position).normalized()
		#if target_dir.x < 0:
			#sprite.flip_h = true
		#else:
			#sprite.flip_h = false
			
	# Hiệu ứng 2 Hiệp sĩ nhún nhảy canh gác dưới chân tháp khi đang nghỉ (Idle)
	if not knight_guards.is_empty() and not is_knight_dashing:
		idle_bob_time += delta * 5.0
		for i in range(knight_guards.size()):
			var k_sprite: Sprite2D = knight_guards[i]
			if is_instance_valid(k_sprite):
				var bob_offset: float = sin(idle_bob_time + i * PI) * 2.5
				k_sprite.position = knight_home_positions[i] + Vector2(0, bob_offset)
				
	# Kích hoạt bắn khi đủ điều kiện
	if current_target != null and attack_cooldown <= 0.0:
		shoot()

## Tạo 2 Hiệp sĩ đứng canh gác dưới chân Doanh Trại
func _setup_knight_guards() -> void:
	if not data or data.unit_sprites.is_empty():
		return
	if not knight_guards.is_empty():
		return
		
	for i in range(2):
		var k_sprite := Sprite2D.new()
		k_sprite.name = "KnightGuard_%d" % (i + 1)
		k_sprite.position = knight_home_positions[i]
		k_sprite.z_index = 2 # Hiển thị nổi phía trước chân tháp
		add_child(k_sprite)
		knight_guards.append(k_sprite)

## Tìm mục tiêu trong tầm bắn dựa theo chế độ người chơi đã chọn
func acquire_target() -> Enemy:
	# 1. Dọn dẹp các quái đã chết hoặc không còn hợp lệ khỏi danh sách
	var valid_enemies: Array[Enemy] = []
	for enemy in targets_in_range:
		if is_instance_valid(enemy) and not enemy.is_dead:
			valid_enemies.append(enemy)
	targets_in_range = valid_enemies
	
	if targets_in_range.is_empty():
		return null
		
	# 2. Chọn ra con quái phù hợp nhất với target_mode
	var best_enemy: Enemy = targets_in_range[0]
	
	for i in range(1, targets_in_range.size()):
		var candidate: Enemy = targets_in_range[i]
		
		match target_mode:
			TargetMode.WEAKEST:
				# Ưu tiên quái có máu hiện tại (current_hp) thấp nhất
				if candidate.current_hp < best_enemy.current_hp:
					best_enemy = candidate
					
			TargetMode.STRONGEST:
				# Ưu tiên quái có máu hiện tại (current_hp) cao nhất (nếu bằng máu thì chọn con giáp dày hơn)
				if candidate.current_hp > best_enemy.current_hp:
					best_enemy = candidate
				elif candidate.current_hp == best_enemy.current_hp and candidate.data and best_enemy.data:
					if candidate.data.armor > best_enemy.data.armor:
						best_enemy = candidate
						
			TargetMode.FIRST:
				# Con đi đầu là con chạy được quãng đường dài nhất trên Path2D (progress lớn nhất)
				if candidate.progress > best_enemy.progress:
					best_enemy = candidate
					
			TargetMode.LAST:
				# Con đi cuối là con chạy được quãng đường ngắn nhất trên Path2D (progress nhỏ nhất)
				if candidate.progress < best_enemy.progress:
					best_enemy = candidate
					
	return best_enemy


## Thực hiện đòn tấn công theo từng loại tháp
func shoot() -> void:
	if not data or not data.projectile_scene:
		push_warning("Tower: Chưa gán TowerData hoặc ProjectileScene!")
		return
	
	var speed_rate: float = get_current_attack_speed()
	attack_cooldown = 1.0 / max(0.01, speed_rate)
	
	# 1. NHÁNH THÁP CUNG THỦ (Archer Tower)
	if data.tower_id == "tower_archer":
		AudioManager.play_sfx("tower_shoot")
		_spawn_archer_arrow(current_target, Vector2.ZERO)
		
		if current_level >= 3:
			var second_target: Enemy = _get_secondary_target(current_target)
			get_tree().create_timer(0.08).timeout.connect(func():
				if not is_inside_tree():
					return
				var valid_target: Enemy = second_target
				if not is_instance_valid(valid_target) or valid_target.is_dead:
					valid_target = acquire_target()
				if is_instance_valid(valid_target) and not valid_target.is_dead:
					_spawn_archer_arrow(valid_target, Vector2(0, -6))
			)
			
	# 2. NHÁNH THÁP KIẾM / DOANH TRẠI (Barrack Tower - Hiệp sĩ xung kích)
	elif data.tower_id == "tower_barrack":
		_perform_barrack_strike(current_target)
		
	# 3. NHÁNH THÁP PHÁP SƯ (Wizard Tower - Xuyên giáp & Hủy Diệt Tinh Vân)
	elif data.tower_id == "tower_wizard":
		AudioManager.play_sfx("tower_shoot")
		_spawn_wizard_orb(current_target)
		
	else:
		AudioManager.play_sfx("tower_shoot")
		_spawn_default_projectile(current_target)

## Sinh cầu năng lượng phép thuật cho Tháp Pháp Sư theo 3 Level
func _spawn_wizard_orb(target_enemy: Enemy) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_dead:
		return
		
	var orb = data.projectile_scene.instantiate() as Projectile
	if not orb:
		return
		
	var spawn_pos: Vector2 = muzzle_marker.global_position if muzzle_marker else global_position
	orb.global_position = spawn_pos
	orb.damage = get_current_damage()
	orb.speed = 460.0 # Cầu phép bay đầm và uy lực
	orb.is_wizard_magic = true
	orb.wizard_level = current_level
	
	# Thiết lập tiến hóa theo 3 Level của Tháp Pháp Sư
	match current_level:
		1:
			# Level 1: Đơn mục tiêu, xuyên 50% giáp
			orb.armor_penetration = 0.5
			orb.magic_splash_radius = 0.0
			orb.applies_nebula_burn = false
		2:
			# Level 2: Sát thương chuẩn (Xuyên 100% giáp) + Nổ lan bán kính 75px (50% sát thương)
			orb.armor_penetration = 1.0
			orb.magic_splash_radius = 75.0
			orb.magic_splash_ratio = 0.5
			orb.applies_nebula_burn = false
		_:
			# Level 3: Hủy Diệt Tinh Vân - Xuyên 100% giáp + Nổ lan 95px (65% sát thương) + Đốt % Max HP & Giật sét 3 quái
			orb.armor_penetration = 1.0
			orb.magic_splash_radius = 95.0
			orb.magic_splash_ratio = 0.65
			orb.applies_nebula_burn = true
			
	orb.set_target(target_enemy)
	
	var level_node = get_tree().current_scene
	if level_node:
		level_node.add_child(orb)
	else:
		get_parent().add_child(orb)
		
				
## Hiệp sĩ lướt nhanh (Dash) ra chém Kiếm khí AoE rồi lướt lùi về chân tháp
func _perform_barrack_strike(target_enemy: Enemy) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_dead:
		return
		
	AudioManager.play_sfx("tower_shoot")
	
	# Nếu chưa gán ảnh Hiệp sĩ thì vẫn tung kiếm khí ngay tại chỗ quái
	if knight_guards.is_empty():
		_spawn_sword_slash_at(target_enemy)
		return
		
	# Luân phiên cho Hiệp sĩ số 1 và Hiệp sĩ số 2 lao ra chém
	var attacker_idx: int = next_knight_idx % knight_guards.size()
	next_knight_idx += 1
	
	var attacker: Sprite2D = knight_guards[attacker_idx]
	var home_pos: Vector2 = knight_home_positions[attacker_idx]
	
	# Quy đổi vị trí của quái sang tọa độ local của Tháp (vì Tháp đang scale 0.4)
	var target_local_pos: Vector2 = to_local(target_enemy.global_position)
	# Dừng cách tâm con quái một khoảng ngắn để vung kiếm đẹp mắt
	var dir_to_enemy: Vector2 = (target_local_pos - home_pos).normalized()
	var strike_pos: Vector2 = target_local_pos - dir_to_enemy * 20.0
	
	# Lật mặt Hiệp sĩ hướng về phía quái
	attacker.flip_h = (dir_to_enemy.x < 0)
	is_knight_dashing = true
	
	# Bước 1 (Xung kích 0.1s) -> Bước 2 (Tung Kiếm Khí) -> Bước 3 (Thu về 0.14s)
	var tween: Tween = create_tween()
	tween.tween_property(attacker, "position", strike_pos, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_spawn_sword_slash_at(target_enemy)
	)
	tween.tween_property(attacker, "position", home_pos, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		is_knight_dashing = false
	)
	
## Sinh thực thể Kiếm Khí (sword_slash.tscn) quét qua đám quái tại vị trí mục tiêu
func _spawn_sword_slash_at(target_enemy: Enemy) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_dead:
		target_enemy = acquire_target()
		if not is_instance_valid(target_enemy) or target_enemy.is_dead:
			return
			
	var slash = data.projectile_scene.instantiate() as Projectile
	if not slash:
		return
		
	slash.is_sword_slash = true
	slash.slash_level = current_level
	slash.damage = get_current_damage()
	slash.target = target_enemy
	slash.global_position = target_enemy.global_position
	
	# Xoay vệt chém hướng từ tháp về phía quái
	slash.rotation = (target_enemy.global_position - global_position).angle()
	
	# Cấu hình số lượng mục tiêu và bán kính chém lan theo từng Level
	match current_level:
		1:
			slash.max_slash_targets = 3
			slash.slash_radius = 65.0*320.0/180.0
		2:
			slash.max_slash_targets = 4
			slash.slash_radius = 80.0*320.0/180.0
		_:
			slash.max_slash_targets = 6
			slash.slash_radius = 100.0*320.0/180.0
			
	var level_node = get_tree().current_scene
	if level_node:
		level_node.add_child(slash)
	else:
		get_parent().add_child(slash)


## Hàm sinh mũi tên riêng cho Tháp Cung Thủ (Xử lý Crit Lv2+ và Diệt quái nhanh Lv3)
func _spawn_archer_arrow(target_enemy: Enemy, pos_offset: Vector2) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_dead:
		return
		
	var proj = data.projectile_scene.instantiate() as Projectile
	if not proj:
		return
		
	var spawn_pos: Vector2 = muzzle_marker.global_position if muzzle_marker else global_position
	proj.global_position = spawn_pos + pos_offset
	proj.damage = get_current_damage()
	proj.speed = 700.0 # Đạn cung bay cực nhanh để bắt kịp Scout/Speeder
	
	# LEVEL 2 & 3: Tính xác suất Chí mạng (Lv2: 25%, Lv3: 35%)
	if current_level >= 2:
		var crit_chance: float = 0.25 if current_level == 2 else 0.35
		if randf() < crit_chance:
			proj.is_crit = true
			
	# LEVEL 3: Tăng 50% sát thương lên quái chạy nhanh (move_speed >= 150)
	if current_level >= 3:
		proj.bonus_vs_fast = true
		
	proj.set_target(target_enemy)
	
	var level_node = get_tree().current_scene
	if level_node:
		level_node.add_child(proj)
	else:
		get_parent().add_child(proj)

## Tìm mục tiêu phụ gần mục tiêu chính cho phát bắn thứ 2 ở Level 3
func _get_secondary_target(primary_target: Enemy) -> Enemy:
	if targets_in_range.size() <= 1:
		return primary_target # Nếu chỉ có 1 quái trong tầm, bắn bồi mũi tên thứ 2 vào chính nó
		
	var second_best: Enemy = null
	var min_dist: float = INF
	
	for enemy in targets_in_range:
		if is_instance_valid(enemy) and not enemy.is_dead and enemy != primary_target:
			var d = primary_target.global_position.distance_squared_to(enemy.global_position)
			if d < min_dist:
				min_dist = d
				second_best = enemy
				
	return second_best if second_best != null else primary_target



## Hàm bắn mặc định cho các tháp khác
func _spawn_default_projectile(target_enemy: Enemy) -> void:
	var proj = data.projectile_scene.instantiate() as Projectile
	if not proj:
		return
	var spawn_pos: Vector2 = muzzle_marker.global_position if muzzle_marker else global_position
	proj.global_position = spawn_pos
	proj.damage = get_current_damage()
	proj.set_target(target_enemy)
	
	var level_node = get_tree().current_scene
	if level_node:
		level_node.add_child(proj)
	else:
		get_parent().add_child(proj)

## Đổi hình ảnh Tháp và Giáp trụ của Hiệp sĩ theo cấp độ hiện tại (Level 1 -> 2 -> 3)
func _update_visual() -> void:
	if not data:
		return
		
	var sprite_index: int = current_level - 1
	
	# 1. Cập nhật hình ảnh tòa nhà
	if not data.sprites.is_empty() and sprite_index < data.sprites.size() and data.sprites[sprite_index] != null:
		sprite.texture = data.sprites[sprite_index]
		
	# 2. Cập nhật hình ảnh lính Hiệp sĩ canh gác (nếu là Tháp Kiếm)
	if not data.unit_sprites.is_empty():
		if knight_guards.is_empty():
			_setup_knight_guards()
		var unit_idx: int = clampi(sprite_index, 0, data.unit_sprites.size() - 1)
		var knight_tex: Texture2D = data.unit_sprites[unit_idx]
		for k_sprite in knight_guards:
			if is_instance_valid(k_sprite) and knight_tex:
				k_sprite.texture = knight_tex

## Loại bỏ các quái đã chết hoặc null khỏi danh sách mục tiêu
func _clean_invalid_targets() -> void:
	for i in range(targets_in_range.size() - 1, -1, -1):
		var enemy = targets_in_range[i]
		if not is_instance_valid(enemy) or enemy.is_dead:
			targets_in_range.remove_at(i)


## Bắt tín hiệu khi Quái bước vào vùng quét
func _on_range_area_entered(area: Area2D) -> void:
	# Tìm thực thể quái vật (cha của HurtBox)
	var enemy = area.get_parent() as Enemy
	if enemy and not enemy.is_dead:
		if not targets_in_range.has(enemy):
			targets_in_range.append(enemy)



## Bắt tín hiệu khi Quái rời khỏi vùng quét
func _on_range_area_exited(area: Area2D) -> void:
	var enemy = area.get_parent() as Enemy
	if enemy:
		targets_in_range.erase(enemy)
		if current_target == enemy:
			current_target = null

## Giá bán hoàn lại (70% tổng giá trị đã đầu tư)
func get_sell_value() -> int:
	if not data:
		return 0
	var total_spent: int = data.cost
	for i in range(current_level - 1):
		if i < data.upgrade_cost.size():
			total_spent += data.upgrade_cost[i]
	return int(total_spent * 0.7)

## Kiểm tra tháp đã đạt cấp tối đa chưa
func is_max_level() -> bool:
	if not data:
		return true
	return current_level >= data.max_level
	
## Lấy chi phí nâng cấp lên cấp tiếp theo
func get_upgrade_cost() -> int:
	if not data or is_max_level():
		return 0
	var cost_index: int = current_level - 1
	if cost_index < data.upgrade_cost.size():
		return data.upgrade_cost[cost_index]
	return 0
	
## Tính lượng vàng hoàn trả khi bán tháp (70% tổng vàng đã đầu tư)
func get_sell_refund() -> int:
	return int(round(total_invested_gold * 0.7))
	
## Lấy bán kính tầm bắn ở cấp độ hiện tại
func get_current_range() -> float:
	if not data or data.attack_range.is_empty():
		return 150.0
	var idx: int = clampi(current_level - 1, 0, data.attack_range.size() - 1)
	return data.attack_range[idx]
	
## Lấy sát thương ở cấp độ hiện tại
func get_current_damage() -> float:
	if not data or data.base_damage.is_empty():
		return 10.0
	var idx: int = clampi(current_level - 1, 0, data.base_damage.size() - 1)
	return data.base_damage[idx]
	
## Lấy tốc độ đánh ở cấp độ hiện tại
func get_current_attack_speed() -> float:
	if not data or data.attack_speed.is_empty():
		return 1.0
	var idx: int = clampi(current_level - 1, 0, data.attack_speed.size() - 1)
	return data.attack_speed[idx]
	
## Thực hiện nâng cấp tháp
func upgrade() -> void:
	if not data or is_max_level():
		return
	total_invested_gold += get_upgrade_cost()
	current_level += 1
	_update_range_shape()
	_update_visual()
	
## Cập nhật bán kính vùng va chạm quét quái
func _update_range_shape() -> void:
	if range_collision and range_collision.shape is CircleShape2D:
		(range_collision.shape as CircleShape2D).radius = get_current_range()
		
## Đổi xoay vòng chế độ bắn khi người chơi bấm nút trên Popup
func cycle_target_mode() -> void:
	target_mode = ((target_mode + 1) % 4) as TargetMode
	# Cập nhật lại mục tiêu ngay lập tức khi đổi chế độ
	current_target = acquire_target()


## Trả về tên tiếng Việt của chế độ bắn để hiển thị lên nút UI
func get_target_mode_name() -> String:
	match target_mode:
		TargetMode.FIRST:
			return "Đi đầu"
		TargetMode.LAST:
			return "Đi cuối"
		TargetMode.STRONGEST:
			return "Mạnh nhất"
		TargetMode.WEAKEST:
			return "Yếu nhất"
	return "Đi đầu"
	
## Mô tả kỹ năng đặc trưng theo cấp độ của cả 3 tháp
func get_skill_description() -> String:
	if not data:
		return ""
	match data.tower_id:
		"tower_archer":
			match current_level:
				1:
					return "Đặc tính: Bắn đơn tốc độ cao"
				2:
					return "Kỹ năng: 25% Chí mạng (x2 sát thương)"
				3:
					return "Kỹ năng: Bắn Kép (2 tên) | 35% Chí mạng\n+50% sát thương lên quái chạy nhanh"
		"tower_barrack":
			match current_level:
				1:
					return "Kỹ năng: Hiệp sĩ xung kích (Chém lan 3 quái)"
				2:
					return "Kỹ năng: Chém chấn động (Lan 4 quái)\nLàm chậm 35% tốc độ trong 2 giây"
				3:
					return "Kỹ năng: Trọng Kiếm Phá Giáp (Lan 6 quái)\nChoáng 0.35s, Chậm 35% & Trừ 6 Giáp (3s)"
		"tower_wizard":
			match current_level:
				1:
					return "Kỹ năng: Đạn phép xuyên 50% Giáp"
				2:
					return "Kỹ năng: Xuyên 100% Giáp (Sát thương chuẩn)\nNổ lan vùng phụ (50% sát thương)"
				3:
					return "Kỹ năng: Hủy Diệt Tinh Vân (Xuyên 100% Giáp)\nĐốt 3% Máu tối đa/giây & Giật lan 3 mục tiêu"
	return ""
