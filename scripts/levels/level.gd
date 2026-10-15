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

# Thêm biến cờ để tránh kích hoạt Thắng/Thua 2 lần cùng lúc
var is_game_over: bool = false

## Tham chiếu Node con
@onready var enemy_path: Path2D = find_child("EnemyPath", true, false) as Path2D
@onready var spawn_timer: Timer = find_child("SpawnTimer", true, false) as Timer
@onready var wave_countdown_timer: Timer = find_child("WaveCountdownTimer", true, false) as Timer
@onready var hp_label: Label = find_child("HpLabel", true, false) as Label
@onready var gold_label: Label = find_child("GoldLabel", true, false) as Label
@onready var wave_label: Label = find_child("WaveLabel", true, false) as Label
@onready var enemy_label: Label = find_child("EnemyLabel", true, false) as Label
@onready var early_wave_btn: Button = find_child("EarlyWaveBtn", true, false) as Button

@onready var result_popup: Control = find_child("ResultPopup", true, false) as Control
@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var stars_label: Label = find_child("StarsLabel", true, false) as Label
@onready var restart_btn: Button = find_child("RestartBtn", true, false) as Button
@onready var next_level_btn: Button = find_child("NextLevelBtn", true, false) as Button
@onready var menu_btn: Button = find_child("MenuBtn", true, false) as Button

# Nút icon trên màn hình
@onready var pause_btn: BaseButton = find_child("Pause", true, false) as BaseButton
@onready var setting_btn: BaseButton = find_child("Setting", true, false) as BaseButton

# Các node thuộc PausePopup (SCRUM-67)
@onready var pause_popup: Control = find_child("PausePopup", true, false) as Control
@onready var resume_btn: Button = find_child("ResumeBtn", true, false) as Button
@onready var pause_restart_btn: Button = find_child("PauseRestartBtn", true, false) as Button
@onready var pause_menu_btn: Button = find_child("PauseMenuBtn", true, false) as Button

# Các node thuộc SettingsPopup (SCRUM-68)
@onready var settings_popup: Control = find_child("SettingsPopup", true, false) as Control
@onready var master_slider: HSlider = find_child("MasterSlider", true, false) as HSlider
@onready var bgm_slider: HSlider = find_child("BgmSlider", true, false) as HSlider
@onready var sfx_slider: HSlider = find_child("SfxSlider", true, false) as HSlider
@onready var close_settings_btn: Button = find_child("CloseSettingsBtn", true, false) as Button
func _ready() -> void:
	# Kết nối sự kiện của các Timer
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	wave_countdown_timer.timeout.connect(_on_wave_countdown_timeout)
	
	# Kết nối nút Gọi Wave Sớm (nếu có)
	if early_wave_btn:
		early_wave_btn.pressed.connect(call_wave_early)
	# Tự động cập nhật chữ trên HUD mỗi khi phát tín hiệu
	gold_changed.connect(_on_gold_changed_ui)
	base_hp_changed.connect(_on_base_hp_changed_ui)
	wave_changed.connect(_on_wave_changed_ui)
	alive_enemies_changed.connect(_on_enemy_changed_ui)
	
	if level_data:
		initialize_level(level_data)
	
	if result_popup:
		result_popup.visible = false
		restart_btn.pressed.connect(_on_restart_pressed)
		next_level_btn.pressed.connect(_on_next_level_pressed)
		menu_btn.pressed.connect(_on_menu_pressed)
		
	# Kết nối nút mở bảng Pause và Settings
	if pause_btn:
		pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_btn.pressed.connect(_on_pause_btn_pressed)
	if setting_btn:
		setting_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		setting_btn.pressed.connect(_on_setting_btn_pressed)
		
	# Thiết lập PausePopup
	if pause_popup:
		pause_popup.visible = false
		if resume_btn:
			resume_btn.pressed.connect(_on_resume_pressed)
		if pause_restart_btn:
			pause_restart_btn.pressed.connect(_on_restart_pressed)
		if pause_menu_btn:
			pause_menu_btn.pressed.connect(_on_menu_pressed)
			
	# Thiết lập SettingsPopup và đồng bộ thanh trượt âm lượng
	if settings_popup:
		settings_popup.visible = false
		_init_audio_sliders()
		if close_settings_btn:
			close_settings_btn.pressed.connect(_on_close_settings_pressed)


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
	wave_changed.emit(0, data.wave_configuration.size())
	alive_enemies_changed.emit(0)
	
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
	add_gold(gold)
	_check_enemy_cleared()


## Xử lý khi quái đi hết đường lọt vào Nhà chính
func _on_enemy_reached_base(damage: int) -> void:
	current_hp = max(0, current_hp - damage)
	base_hp_changed.emit(current_hp)
	print("Nhà chính bị tấn công! HP còn lại: ", current_hp)
	
	if current_hp <= 0:
		_on_base_hp_depleted()
	else:
		_check_enemy_cleared()


## Giảm biến đếm quái sống và kiểm tra hoàn thành đợt
func _check_enemy_cleared() -> void:
	if is_game_over:
		return

	alive_enemies_count = max(0, alive_enemies_count - 1)
	alive_enemies_changed.emit(alive_enemies_count)
	
	# Nếu đã sinh hết quái của đợt hiện tại VÀ không còn quái nào sống trên bản đồ
	if enemies_remaining_to_spawn <= 0 and alive_enemies_count == 0 and is_wave_in_progress:
		is_wave_in_progress = false
		_completed_wave()


## Hoàn thành một đợt quái
func _completed_wave() -> void:
	print("Đã dọn sạch Wave ", current_wave)
	
	if current_wave < level_data.wave_configuration.size():
		# Chưa phải wave cuối -> Đếm ngược sang wave kế
		start_wave_countdown(5.0)
	else:
		# Đã vượt qua Wave cuối cùng
		_on_level_victory()


## Xử lý khi Thắng màn
func _on_level_victory() -> void:
	if is_game_over:
		return
	is_game_over = true
	
	spawn_timer.stop()
	wave_countdown_timer.stop()
	
	var stars: int = calculate_stars()
	print(">>> CHIẾN THẮNG! Số sao đạt được: ", stars, " <<<")
	
	game_won.emit()
	show_result_popup(true, stars)


## Xử lý khi Thua cuộc
func _on_base_hp_depleted() -> void:
	if is_game_over:
		return
	is_game_over = true
	
	print(">>> THẤT BẠI - NHÀ CHÍNH SỤP ĐỔ! <<<")
	spawn_timer.stop()
	wave_countdown_timer.stop()
	
	game_lost.emit()
	show_result_popup(false, 0)
	
## Kiểm tra người chơi có đủ vàng không
func can_afford(cost: int) -> bool:
	return current_golds >= cost
	
## Trừ vàng khi mua hoặc nâng cấp tháp (trả về true nếu giao dịch thành công)
func spend_gold(cost: int) -> bool:
	if not can_afford(cost):
		return false
	current_golds -= cost
	gold_changed.emit(current_golds)
	return true
	
## Cộng vàng khi diệt quái, gọi wave sớm hoặc bán tháp
func add_gold(amount: int) -> void:
	current_golds += amount
	gold_changed.emit(current_golds)
	
func _on_gold_changed_ui(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "Gold: " + str(new_gold)

func _on_base_hp_changed_ui(new_hp: int) -> void:
	if hp_label:
		hp_label.text = "HP: " + str(new_hp)

func _on_wave_changed_ui(wave_idx: int, total_waves: int) -> void:
	if wave_label:
		wave_label.text = "Wave: %d/%d" % [wave_idx, total_waves]

func _on_enemy_changed_ui(count: int) -> void:
	if enemy_label:
		enemy_label.text = "Enemy alive: %d" %(count)
		
## Tính số sao dựa trên % máu Nhà chính còn lại
func calculate_stars() -> int:
	if not level_data or level_data.starting_base_hp <= 0:
		return 1
	var hp_ratio: float = float(current_hp) / float(level_data.starting_base_hp)
	if hp_ratio >= 1.0:
		return 3
	elif hp_ratio >= 0.5:
		return 2
	else:
		return 1
		
## Hiển thị bảng kết quả Thắng / Thua và tạm dừng trận đấu
func show_result_popup(is_victory: bool, stars: int) -> void:
	if not result_popup:
		return
		
	result_popup.visible = true
	get_tree().paused = true # Đóng băng mọi hoạt động dưới bản đồ
	
	if is_victory:
		title_label.text = "CHIẾN THẮNG!"
		stars_label.visible = true
		stars_label.text = "Đánh giá: " + "★ ".repeat(stars) + "☆ ".repeat(3 - stars)
		next_level_btn.visible = true
	else:
		title_label.text = "THẤT BẠI!"
		stars_label.visible = false
		next_level_btn.visible = false


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_next_level_pressed() -> void:
	get_tree().paused = false
	# Tạm thời nếu chưa có Level 2 thì chuyển về màn chọn Level hoặc reload
	var next_level_path: String = "res://scenes/levels/level_%d.tscn" % (level_data.level_id + 1)
	if ResourceLoader.exists(next_level_path):
		get_tree().change_scene_to_file(next_level_path)
	elif ResourceLoader.exists("res://scenes/ui/level_select.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")
	else:
		print("Chưa có scene màn tiếp theo, tải lại màn hiện tại!")
		get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	if ResourceLoader.exists("res://scenes/ui/main_menu.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	else:
		print("Chưa tạo scene main_menu.tscn (sẽ làm ở Bước 4)!")

# ==========================================
# XỬ LÝ TẠM DỪNG TRẬN ĐẤU (SCRUM-67)
# ==========================================

func _on_pause_btn_pressed() -> void:
	if is_game_over:
		return
	if settings_popup and settings_popup.visible:
		settings_popup.visible = false
	if pause_popup:
		pause_popup.visible = not pause_popup.visible
		get_tree().paused = pause_popup.visible


func _on_resume_pressed() -> void:
	if pause_popup:
		pause_popup.visible = false
	get_tree().paused = false


# ==========================================
# XỬ LÝ CÀI ĐẶT ÂM THANH (SCRUM-68)
# ==========================================

func _on_setting_btn_pressed() -> void:
	if is_game_over:
		return
	if pause_popup and pause_popup.visible:
		pause_popup.visible = false
	if settings_popup:
		settings_popup.visible = not settings_popup.visible
		get_tree().paused = settings_popup.visible


func _on_close_settings_pressed() -> void:
	if settings_popup:
		settings_popup.visible = false
	get_tree().paused = false


func _init_audio_sliders() -> void:
	if master_slider:
		master_slider.value = _get_bus_volume_linear("Master")
		master_slider.value_changed.connect(func(val: float): _set_bus_volume_linear("Master", val))
	if bgm_slider:
		bgm_slider.value = _get_bus_volume_linear("BGM")
		bgm_slider.value_changed.connect(func(val: float): _set_bus_volume_linear("BGM", val))
	if sfx_slider:
		sfx_slider.value = _get_bus_volume_linear("SFX")
		sfx_slider.value_changed.connect(func(val: float): _set_bus_volume_linear("SFX", val))


func _get_bus_volume_linear(bus_name: String) -> float:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return 1.0
	if AudioServer.is_bus_mute(bus_idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


func _set_bus_volume_linear(bus_name: String, linear_val: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	# Nếu kéo về 0 thì Mute kênh âm thanh, ngược lại đổi sang Decibel (dB)
	if linear_val <= 0.001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))
