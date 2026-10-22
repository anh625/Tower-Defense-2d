extends GutTest

## SCRUM-81: Unit Test kiểm thử logic tính toán sát thương, giáp và vòng đời Quái vật

var _enemy: Enemy
var _enemy_data: EnemyData


func before_each() -> void:
	# Khởi tạo dữ liệu cấu hình mẫu (Goblin Chiến Binh)
	_enemy_data = EnemyData.new()
	_enemy_data.enemy_id = "goblin_warrior"
	_enemy_data.enemy_name = "Goblin Chiến Binh"
	_enemy_data.max_hp = 100
	_enemy_data.armor = 5
	_enemy_data.move_speed = 120.0
	_enemy_data.reward_gold = 35
	_enemy_data.base_damage = 2

	# Khởi tạo thực thể Enemy và gắn dữ liệu
	_enemy = Enemy.new()
	_enemy.data = _enemy_data
	add_child_autofree(_enemy)


## 1. Kiểm tra khởi tạo máu ban đầu từ EnemyData
func test_enemy_initial_hp_from_data() -> void:
	assert_eq(_enemy.current_hp, 100, "Máu khởi tạo phải bằng max_hp trong EnemyData (100)")
	assert_false(_enemy.is_dead, "Trạng thái ban đầu của quái phải là còn sống (is_dead = false)")


## 2. Kiểm tra khởi tạo mặc định khi không gắn file .tres (data == null)
func test_enemy_default_hp_without_data() -> void:
	var default_enemy := Enemy.new()
	add_child_autofree(default_enemy)
	assert_eq(default_enemy.current_hp, 100, "Khi không có EnemyData, máu mặc định phải là 100")


## 3. Kiểm tra công thức trừ giáp: Damage thực = max(1, Sát thương cơ bản - Giáp)
func test_take_damage_with_armor_reduction() -> void:
	# Sát thương đạn = 25, Giáp quái = 5 -> Sát thương thực = 20 -> Máu còn 80
	_enemy.take_damage(25.0)
	assert_eq(_enemy.current_hp, 80, "Máu phải giảm đúng 20 HP sau khi trừ 5 giáp")


## 4. Kiểm tra sát thương tối thiểu bằng 1 khi Giáp >= Sát thương đạn
func test_minimum_damage_when_armor_exceeds_attack() -> void:
	_enemy_data.armor = 50
	# Sát thương đạn = 10, Giáp = 50 -> max(1.0, 10 - 50) = 1
	_enemy.take_damage(10.0)
	assert_eq(_enemy.current_hp, 99, "Quái vẫn phải mất tối thiểu 1 HP dù giáp cao hơn sát thương")


## 5. Kiểm tra quái chết khi HP <= 0 và phát tín hiệu died(reward_gold)
func test_enemy_dies_and_emits_reward_gold_signal() -> void:
	watch_signals(_enemy)
	
	# Gây sát thương kết liễu (110 - 5 giáp = 105 damage >= 100 HP)
	_enemy.take_damage(110.0)
	
	assert_true(_enemy.is_dead, "Cờ is_dead phải bật thành true khi HP <= 0")
	assert_signal_emitted_with_parameters(
		_enemy, 
		"died", 
		[35]
	)


## 6. Kiểm tra quái đã chết không nhận thêm sát thương hoặc phát tín hiệu trùng lặp
func test_dead_enemy_ignores_further_damage() -> void:
	watch_signals(_enemy)
	
	_enemy.take_damage(110.0) # Chết lần 1
	_enemy.take_damage(50.0)  # Bắn bồi thêm khi đã chết
	
	assert_signal_emit_count(_enemy, "died", 1, "Tín hiệu died chỉ được phát đúng 1 lần duy nhất")


## 7. Kiểm tra quái chạm Nhà chính phát tín hiệu reached_base(base_damage)
func test_enemy_reaches_base_emits_damage_signal() -> void:
	watch_signals(_enemy)
	
	_enemy.reach_base()
	
	assert_true(_enemy.is_dead, "Khi lọt vào Nhà chính, quái phải chuyển trạng thái kết thúc vòng đời")
	assert_signal_emitted_with_parameters(
		_enemy, 
		"reached_base", 
		[2]
	)
