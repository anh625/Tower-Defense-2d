class_name Tower
extends Node2D

## Cấu hình dữ liệu của tháp (Nạp từ TowerData.tres)
@export var data: TowerData

## Trạng thái hoạt động
var current_level: int = 1
var current_target: Enemy = null
var targets_in_range: Array[Enemy] = []

## Bộ đếm hồi chiêu giữa các đòn đánh
var attack_cooldown: float = 0.0

## Tham chiếu các Node con bên trong Scene
@onready var range_area: Area2D = $RangeArea
@onready var collision_shape: CollisionShape2D = $RangeArea/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle_marker: Marker2D = $MuzzleMarker

func _ready() -> void:
	if not range_area:
		push_error("Tower: Thiếu Node RangeArea (Area2D)!")
		return
	
	# Kết nối tín hiệu quét quái vật
	# Dùng area_entered nếu quái dùng Area2D (HurtBox), hoặc body_entered nếu quái là CharacterBody2D
	range_area.area_entered.connect(_on_range_area_entered)
	range_area.area_exited.connect(_on_range_area_exited)
	
	# Đồng bộ bán kính tầm bắn theo cấp độ hiện tại
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

	# Kích hoạt bắn khi đủ điều kiện
	if current_target != null and attack_cooldown <= 0.0:
		shoot()


## Lựa chọn quái đi xa nhất trên ray Path2D (First Target Strategy)
func acquire_target() -> Enemy:
	if targets_in_range.is_empty():
		return null
	
	var best_target: Enemy = null
	var max_progress: float = -1.0
	
	for enemy in targets_in_range:
		if is_instance_valid(enemy) and not enemy.is_dead:
			# Quái vật kế thừa PathFollow2D có thuộc tính progress đo khoảng cách đã đi
			if enemy.progress > max_progress:
				max_progress = enemy.progress
				best_target = enemy
				
	return best_target


## Thực hiện đòn tấn công và phóng đạn
func shoot() -> void:
	if not data or not data.projectile_scene:
		push_warning("Tower: Chưa gán TowerData hoặc ProjectileScene!")
		return
	
	# Tính Cooldown dựa theo attack_speed (số phát bắn mỗi giây)
	var speed_rate: float = data.attack_speed[current_level - 1]
	attack_cooldown = 1.0 / max(0.01, speed_rate)
	
	# Sinh thực thể đạn
	var proj_instance = data.projectile_scene.instantiate() as Projectile
	if not proj_instance:
		return
	
	# Đặt vị trí xuất phát tại nòng tháp
	var spawn_pos: Vector2 = muzzle_marker.global_position if muzzle_marker else global_position
	proj_instance.global_position = spawn_pos
	
	# Thiết lập chỉ số và mục tiêu cho đạn
	var current_dmg: float = data.base_damage[current_level - 1]
	proj_instance.damage = current_dmg
	proj_instance.set_target(current_target)
	
	# Thêm đạn vào Level gốc để đạn bay độc lập không bị dính vào vị trí của Tháp
	var level_node = get_tree().current_scene
	if level_node:
		level_node.add_child(proj_instance)
	else:
		get_parent().add_child(proj_instance)


## Cập nhật lại bán kính CollisionShape2D tương ứng attack_range trong TowerData
func _update_range_shape() -> void:
	if not data or not collision_shape:
		return
		
	var radius: float = data.attack_range[current_level - 1]
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius
	else:
		var circle = CircleShape2D.new()
		circle.radius = radius
		collision_shape.shape = circle
		
## Hàm gán Texture tương ứng với level hiện tại
func _update_visual() -> void:
	if not data or data.sprites.is_empty():
		return
		
	var sprite_index: int = current_level - 1
	if sprite_index < data.sprites.size() and data.sprites[sprite_index] != null:
		sprite.texture = data.sprites[sprite_index]

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


## Nâng cấp tháp lên cấp độ tiếp theo
func upgrade() -> void:
	if not data:
		return
	if current_level < data.max_level:
		current_level += 1
		_update_range_shape()
		_update_visual() # Đổi sang ảnh của Level mới


## Giá bán hoàn lại (70% tổng giá trị đã đầu tư)
func get_sell_value() -> int:
	if not data:
		return 0
	var total_spent: int = data.cost
	for i in range(current_level - 1):
		if i < data.upgrade_cost.size():
			total_spent += data.upgrade_cost[i]
	return int(total_spent * 0.7)
