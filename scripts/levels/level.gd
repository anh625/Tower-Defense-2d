class_name Level
extends Node2D

## Tín hiệu thông báo tiến trình cho UI/HUD (nếu có sau này)
signal wave_changed(current_wave: int, total_waves: int)
signal alive_enemies_changed(count: int)
signal gold_changed(current_gold: int)
signal base_hp_changed(current_hp: int)
signal game_won
signal game_lost

## Dữ liệu cấu hình của màn chơi (.tres)
@export var level_data: LevelData
## Scene quái vật cơ bản dùng để instantiate (enemy_base.tscn đã làm ở Bước 1)
@export var enemy_base_scene: PackedScene

## Các biến trạng thái của màn chơi theo Class Diagram
var current_wave: int = 0
var alive_enemies_count: int = 0
var current_hp: int = 20
var current_golds: int = 250

## Quản lý quá trình spawn nội bộ
var current_wave_data: WaveData = null
var enemies_remaining_to_spawn: int = 0
var is_wave_in_progress: bool = false

## Tham chiếu Node con
@onready var enemy_path: Path2D = $EnemyPath
@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_countdown_timer: Timer = $WaveCountdownTimer


func _ready() -> void:
	# Kết nối sự kiện của các Timer
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	wave_countdown_timer.timeout.connect(_on_wave_countdown_timeout)
	
	if level_data:
		initialize_level(level_data)


## Khởi tạo trạng thái ban đầu của màn chơi
func initialize_level(data: LevelData) -> void:
	level_data = data
	
	current_hp = data.starting_base_hp
	#$HpLabel.text = "HP: " + str(current_hp)
	
	current_golds = data.starting_gold
	#$GoldLabel.text = "Gold: " + str(current_golds)
	
	current_wave = 0
	#$WaveLabel.text = "Wave: " + str(current_wave + 1)
	
	gold_changed.emit(current_golds)
	base_hp_changed.emit(current_hp)
	
	# Bắt đầu đếm ngược 3 giây trước đợt quái đầu tiên
	start_wave_countdown(3.0)


## Bắt đầu đếm ngược giữa các Wave
func start_wave_countdown(delay: float = 5.0) -> void:
	wave_countdown_timer.start(delay)
	print("Đang đếm ngược vào Wave tiếp theo: ", delay, "s")


## Hết giờ đếm ngược -> Tự động kích hoạt Wave
func _on_wave_countdown_timeout() -> void:
	start_wave(current_wave + 1)


## Người chơi chủ động gọi đợt quái sớm (Call Wave Early)
func call_wave_early() -> void:
	if is_wave_in_progress:
		return
	
	# Tính thưởng vàng gọi sớm dựa vào thời gian còn lại của Timer
	var time_left: float = wave_countdown_timer.time_left
	var early_bonus: int = int(time_left * 2) # Ví dụ: mỗi giây dư được +2 vàng
	current_golds += early_bonus
	#$GoldLabel.text = "Gold: " + str(current_golds)
	gold_changed.emit(current_golds)
	
	wave_countdown_timer.stop()
	start_wave(current_wave + 1)


## Bắt đầu một Wave cụ thể
func start_wave(index: int) -> void:
	if not level_data or level_data.wave_configuration.is_empty():
		push_error("Level: Thiếu wave_configuration trong LevelData!")
		return
		
	if index > level_data.wave_configuration.size():
		return
		
	current_wave = index
	is_wave_in_progress = true
	current_wave_data = level_data.wave_configuration[current_wave - 1]
	
	wave_changed.emit(current_wave, level_data.wave_configuration.size())
	print("=== BẮT ĐẦU WAVE ", current_wave, " ===")
	
	# Kích hoạt chu trình sinh quái
	spawn_wave_routine(current_wave_data)


## Chuẩn bị vòng lặp sinh quái
func spawn_wave_routine(wave: WaveData) -> void:
	enemies_remaining_to_spawn = wave.enemy_count
	# Bắn quái đầu tiên ngay lập tức, sau đó Timer sẽ lo các con tiếp theo
	_spawn_next_enemy_in_wave()


func _spawn_next_enemy_in_wave() -> void:
	if enemies_remaining_to_spawn > 0:
		spawn_single_enemy(current_wave_data)
		enemies_remaining_to_spawn -= 1
		
		if enemies_remaining_to_spawn > 0:
			spawn_timer.start(current_wave_data.spawn_interval)
	else:
		spawn_timer.stop()


func _on_spawn_timer_timeout() -> void:
	_spawn_next_enemy_in_wave()


## Khởi tạo 1 thực thể quái vật và đưa vào đường chạy Path2D
func spawn_single_enemy(wave: WaveData) -> void:
	if not enemy_base_scene:
		push_error("Level: Chưa gán enemy_base_scene!")
		return
		
	var enemy_instance = enemy_base_scene.instantiate() as Enemy
	if not enemy_instance:
		return
		
	# Gán dữ liệu EnemyData từ WaveData vào quái
	enemy_instance.data = wave.enemy_data
	
	# Kết nối tín hiệu của quái để theo dõi vòng đời
	enemy_instance.died.connect(_on_enemy_died)
	enemy_instance.reached_base.connect(_on_enemy_reached_base)
	
	# Đưa quái vào làm con của Path2D để nó tự trượt trên đường ray
	enemy_path.add_child(enemy_instance)
	
	alive_enemies_count += 1
	alive_enemies_changed.emit(alive_enemies_count)


## Xử lý khi quái bị Tháp/Đạn tiêu diệt
func _on_enemy_died(gold: int) -> void:
	current_golds += gold
	gold_changed.emit(current_golds)
	
	_check_enemy_cleared()


## Xử lý khi quái đi hết đường lọt vào Nhà chính
func _on_enemy_reached_base(damage: int) -> void:
	current_hp -= damage
	base_hp_changed.emit(current_hp)
	print("Nhà chính bị tấn công! HP còn lại: ", current_hp)
	
	if current_hp <= 0:
		_on_base_hp_depleted()
	else:
		_check_enemy_cleared()


## Giảm biến đếm quái sống và kiểm tra hoàn thành đợt
func _check_enemy_cleared() -> void:
	alive_enemies_count -= 1
	alive_enemies_changed.emit(alive_enemies_count)
	
	# Điều kiện dọn sạch wave: Không còn quái nào để sinh VÀ không còn quái nào sống sót
	if enemies_remaining_to_spawn == 0 and alive_enemies_count <= 0:
		alive_enemies_count = 0
		_completed_wave(current_wave)


## Hoàn thành một đợt quái
func _completed_wave(wave_index: int) -> void:
	is_wave_in_progress = false
	print("--- ĐÃ DỌN SẠCH WAVE ", wave_index, " ---")
	
	if current_wave < level_data.wave_configuration.size():
		# Chưa phải wave cuối -> Đếm ngược sang wave kế
		start_wave_countdown(5.0)
	else:
		# Đã vượt qua Wave cuối cùng
		_on_level_victory()


## Xử lý khi Thắng màn
func _on_level_victory() -> void:
	print(">>> CHIẾN THẮNG MÀN CHƠI! <<<")
	game_won.emit()


## Xử lý khi Thua cuộc
func _on_base_hp_depleted() -> void:
	print(">>> THẤT BẠI - NHÀ CHÍNH SỤP ĐỔ! <<<")
	# Dừng sinh quái
	spawn_timer.stop()
	wave_countdown_timer.stop()
	game_lost.emit()
