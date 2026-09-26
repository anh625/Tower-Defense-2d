class_name Projectile
extends Area2D

@export var speed: float = 400.0
var damage: float = 10.0
var target: Enemy = null

func _ready() -> void:
	# Kết nối tín hiệu va chạm bằng code nếu chưa nối qua giao diện Editor
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	# Nếu mục tiêu bị hủy hoặc đã chết giữa đường -> Tự hủy đạn
	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return
	
	# Hướng bay bám đuổi (Homing) theo vị trí hiện tại của quái
	var target_pos: Vector2 = target.global_position
	var direction: Vector2 = (target_pos - global_position).normalized()
	
	# Cập nhật vị trí và góc xoay của đầu đạn theo hướng bay
	global_position += direction * speed * delta
	rotation = direction.angle()


## Gán mục tiêu cần theo dõi
func set_target(enemy: Enemy) -> void:
	target = enemy


## Xử lý khi đạn chạm vào HurtBox của quái
func _on_area_entered(area: Area2D) -> void:
	# Tìm node Enemy cha của HurtBox
	var enemy: Enemy = area.get_parent() as Enemy
	if enemy and enemy == target and not enemy.is_dead:
		hit_target(enemy)


## Gây sát thương và giải phóng Node đạn
func hit_target(enemy: Enemy) -> void:
	enemy.take_damage(damage)
	queue_free()
