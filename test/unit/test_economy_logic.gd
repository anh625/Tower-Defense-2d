extends GutTest

## SCRUM-82: Unit Test kiểm thử trực tiếp class Level (level.gd) và Tower (tower.gd)

var _level: Level
var _level_data: LevelData
var _tower: Tower
var _tower_data: TowerData


func before_each() -> void:
	# 1. Tạo dữ liệu màn chơi (LevelData) có 1 Wave mẫu
	_level_data = LevelData.new()
	_level_data.level_id = 1
	_level_data.level_name = "Màn 1 Test"
	_level_data.starting_gold = 250
	_level_data.starting_base_hp = 20

	var wave_1 := WaveData.new()
	wave_1.wave_index = 1
	wave_1.enemy_count = 2
	wave_1.spawn_interval = 1.0
	_level_data.wave_configuration = [wave_1]

	# 2. Khởi tạo Level thật và gắn sẵn các Node con bắt buộc trước khi vào _ready()
	_level = Level.new()

	var spawn_timer := Timer.new()
	spawn_timer.name = "SpawnTimer"
	_level.add_child(spawn_timer)

	var wave_countdown_timer := Timer.new()
	wave_countdown_timer.name = "WaveCountdownTimer"
	_level.add_child(wave_countdown_timer)

	var enemy_path := Path2D.new()
	enemy_path.name = "EnemyPath"
	_level.add_child(enemy_path)

	add_child_autofree(_level)
	_level.initialize_level(_level_data)
	# Dừng bộ đếm tự động gọi wave để kiểm thử độc lập từng hàm
	wave_countdown_timer.stop()

	# 3. Khởi tạo TowerData và thực thể Tower thật kèm các Node con bắt buộc
	_tower_data = TowerData.new()
	_tower_data.tower_id = "archer"
	_tower_data.cost = 100
	_tower_data.max_level = 3
	_tower_data.upgrade_cost = [50, 100]
	_tower_data.base_damage = [15.0, 25.0, 40.0]
	_tower_data.attack_range = [180.0, 200.0, 220.0]
	_tower_data.attack_speed = [1.0, 1.2, 1.5]

	_tower = Tower.new()
	_tower.data = _tower_data

	var range_area := Area2D.new()
	range_area.name = "RangeArea"
	var col_shape := CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	range_area.add_child(col_shape)
	_tower.add_child(range_area)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	_tower.add_child(sprite)

	var muzzle := Marker2D.new()
	muzzle.name = "MuzzleMarker"
	_tower.add_child(muzzle)

	add_child_autofree(_tower)


func after_each() -> void:
	# Đảm bảo mở khóa SceneTree nếu hàm kết thúc màn chơi trong level.gd bật paused = true
	get_tree().paused = false


## 1. Kiểm tra hàm initialize_level() trong level.gd nạp đúng Vàng và Máu khởi đầu
func test_level_initialize_resources() -> void:
	assert_eq(_level.current_golds, 250, "level.gd phải khởi tạo current_golds = 250 từ LevelData")
	assert_eq(_level.current_hp, 20, "level.gd phải khởi tạo current_hp = 20 từ LevelData")


## 2. Kiểm tra mua tháp (spend_gold) khi ĐỦ vàng
func test_level_spend_gold_when_enough() -> void:
	watch_signals(_level)
	
	var result: bool = _level.spend_gold(100)
	
	assert_true(result, "spend_gold(100) phải trả về true khi đang có 250 vàng")
	assert_eq(_level.current_golds, 150, "Số vàng trong level.gd phải giảm còn 150")
	assert_signal_emitted_with_parameters(_level, "gold_changed", [150])


## 3. Kiểm tra mua tháp (spend_gold) bị từ chối khi KHÔNG ĐỦ vàng
func test_level_spend_gold_rejected_when_not_enough() -> void:
	var result: bool = _level.spend_gold(300)
	
	assert_false(result, "spend_gold(300) phải trả về false khi chỉ có 250 vàng")
	assert_eq(_level.current_golds, 250, "Số vàng trong level.gd phải giữ nguyên 250")


## 4. Kiểm tra hàm _on_enemy_died() trong level.gd cộng vàng thưởng và giảm số quái sống
func test_level_on_enemy_died_adds_gold_and_decreases_count() -> void:
	_level.alive_enemies_count = 3
	_level.enemies_remaining_to_spawn = 1
	
	_level._on_enemy_died(35)
	
	assert_eq(_level.current_golds, 285, "Diệt quái thưởng 35 vàng -> tổng vàng phải tăng lên 285")
	assert_eq(_level.alive_enemies_count, 2, "Số quái đang sống phải giảm từ 3 xuống 2")


## 5. Kiểm tra nâng cấp tháp và tính tiền bán tháp (hoàn 70% tổng vốn đầu tư) trong tower.gd
func test_tower_upgrade_and_sell_refund_70_percent() -> void:
	# Hỗ trợ gọi cả 2 tên hàm get_sell_refund() hoặc get_sell_value() trong tower.gd
	var sell_lv1: int = _tower.get_sell_refund() if _tower.has_method("get_sell_refund") else _tower.get_sell_value()
	assert_eq(sell_lv1, 70, "Tháp cấp 1 (mua 100G) khi bán phải hoàn 70% = 70G")
	
	# Nâng cấp lên cấp 2 (tốn thêm 50G -> tổng đầu tư = 150G)
	_tower.upgrade()
	assert_eq(_tower.current_level, 2, "Sau khi gọi upgrade(), cấp độ tháp phải tăng lên 2")
	
	var sell_lv2: int = _tower.get_sell_refund() if _tower.has_method("get_sell_refund") else _tower.get_sell_value()
	assert_eq(sell_lv2, 105, "Tháp cấp 2 (tổng đầu tư 150G) khi bán phải hoàn 70% = 105G")


## 6. Kiểm tra hàm _on_enemy_reached_base() trừ máu Nhà chính và xử lý Thua cuộc khi HP <= 0
func test_level_defeat_when_base_hp_depleted() -> void:
	watch_signals(_level)
	_level.alive_enemies_count = 2
	_level.enemies_remaining_to_spawn = 1
	
	# Quái thứ nhất lọt vào gây 15 sát thương -> Nhà chính còn 5 HP
	_level._on_enemy_reached_base(15)
	assert_eq(_level.current_hp, 5, "Máu Nhà chính phải giảm từ 20 xuống 5")
	assert_signal_emitted_with_parameters(_level, "base_hp_changed", [5])
	
	# Quái thứ hai lọt vào gây 10 sát thương -> Nhà chính về 0 HP (Thua cuộc)
	_level._on_enemy_reached_base(10)
	assert_eq(_level.current_hp, 0, "Máu Nhà chính khi bị trừ quá số dư phải dừng ở 0")
	if "is_game_over" in _level:
		assert_true(_level.is_game_over, "Khi HP = 0, cờ is_game_over phải chuyển thành true")


## 7. Kiểm tra hoàn thành đợt quái cuối cùng khi tiêu diệt con quái cuối trên bản đồ
func test_level_victory_when_last_enemy_of_final_wave_killed() -> void:
	# Giả lập đang ở Wave cuối cùng (Wave 1/1), không còn quái chờ sinh và chỉ còn 1 quái trên sân
	_level.current_wave = 1
	_level.is_wave_in_progress = true
	_level.enemies_remaining_to_spawn = 0
	_level.alive_enemies_count = 1
	
	# Tiêu diệt con quái cuối cùng
	_level._on_enemy_died(20)
	
	assert_eq(_level.alive_enemies_count, 0, "Số lượng quái sống phải về 0")
	assert_false(_level.is_wave_in_progress, "Wave cuối phải kết thúc (is_wave_in_progress = false)")
	if "is_game_over" in _level:
		assert_true(_level.is_game_over, "Khi dọn sạch Wave cuối, trạng thái trận đấu phải kết thúc")
