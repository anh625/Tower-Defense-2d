extends Node

## Đường dẫn các bản nhạc nền (BGM) - Bạn đổi đuôi .ogg hoặc .mp3 tùy file thực tế
const BGM_TRACKS: Dictionary = {
	"menu": "res://assets/audio/bgm/menu_bgm.mp3",
	"battle": "res://assets/audio/bgm/battle_bgm.mp3"
}

## Đường dẫn các hiệu ứng âm thanh (SFX) - Chuẩn bị sẵn cho Bước 2 (SCRUM-71)
const SFX_SOUNDS: Dictionary = {
	"ui_click": "res://assets/audio/sfx/ui_click.mp3",
	"tower_place": "res://assets/audio/sfx/tower_place.mp3",
	"tower_shoot": "res://assets/audio/sfx/tower_shoot.mp3",
	"projectile_hit": "res://assets/audio/sfx/projectile_hit.mp3",
	"enemy_die": "res://assets/audio/sfx/enemy_die.mp3",
	"wave_start": "res://assets/audio/sfx/wave_start.mp3",
	"victory": "res://assets/audio/sfx/victory.mp3",
	"defeat": "res://assets/audio/sfx/defeat.mp3"
}

const SFX_POOL_SIZE: int = 8

var bgm_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var current_bgm_name: String = ""


func _ready() -> void:
	# Luôn hoạt động kể cả khi get_tree().paused = true (mở bảng Pause / Settings)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Khởi tạo trình phát nhạc nền (BGM) gắn vào kênh "BGM"
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = &"BGM" if AudioServer.get_bus_index("BGM") != -1 else &"Master"
	add_child(bgm_player)
	
	# Khởi tạo Pool trình phát hiệu ứng âm thanh (SFX) gắn vào kênh "SFX"
	var sfx_bus: StringName = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = sfx_bus
		add_child(player)
		sfx_pool.append(player)
		
	# Tự động gắn âm thanh click cho tất cả các nút hiện có và sinh ra sau này
	get_tree().node_added.connect(_on_tree_node_added)
	_connect_buttons_recursive(get_tree().root)


# ==========================================
# QUẢN LÝ NHẠC NỀN - BGM (SCRUM-72)
# ==========================================

## Phát nhạc nền theo tên track ("menu" hoặc "battle") theo Class Diagram
func play_bgm(track_name: String) -> void:
	# Nếu bản nhạc này đang phát rồi thì giữ nguyên, không phát lại từ đầu
	if current_bgm_name == track_name and bgm_player.playing:
		return
		
	var path: String = BGM_TRACKS.get(track_name, track_name)
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] Chưa có file BGM tại: " + path)
		return
		
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		current_bgm_name = track_name
		bgm_player.stream = stream
		bgm_player.play()


## Dừng phát nhạc nền
func stop_bgm() -> void:
	bgm_player.stop()
	current_bgm_name = ""


# ==========================================
# QUẢN LÝ HIỆU ỨNG ÂM THANH - SFX (SCRUM-71)
# ==========================================

## Phát hiệu ứng âm thanh theo tên sfx_name theo Class Diagram
func play_sfx(sfx_name: String) -> void:
	var path: String = SFX_SOUNDS.get(sfx_name, sfx_name)
	if not ResourceLoader.exists(path):
		return
		
	var stream: AudioStream = load(path) as AudioStream
	if not stream:
		return
		
	for player in sfx_pool:
		if not player.playing:
			player.stream = stream
			player.play()
			return
			
	# Nếu tất cả kênh trong pool đều bận, ghi đè lên kênh đầu tiên
	sfx_pool[0].stream = stream
	sfx_pool[0].play()

func _on_tree_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button_sfx(node as BaseButton)


func _connect_buttons_recursive(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is BaseButton:
			_connect_button_sfx(child as BaseButton)
		_connect_buttons_recursive(child)


func _connect_button_sfx(btn: BaseButton) -> void:
	var callable := func(): play_sfx("ui_click")
	if not btn.pressed.is_connected(callable):
		btn.pressed.connect(callable)

# ==========================================
# ĐIỀU CHỈNH ÂM LƯỢNG KÊNH AUDIO BUS (SCRUM-70)
# ==========================================

## Cập nhật âm lượng kênh âm thanh từ giá trị tuyến tính (0.0 -> 1.0) sang dB
func set_volume(bus_name: String, value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	if value <= 0.001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


## Lấy giá trị âm lượng tuyến tính hiện tại (0.0 -> 1.0) của kênh âm thanh
func get_volume(bus_name: String) -> float:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return 1.0
	if AudioServer.is_bus_mute(bus_idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
