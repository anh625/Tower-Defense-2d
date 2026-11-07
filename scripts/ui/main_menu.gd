class_name MainMenu
extends Control

@onready var play_btn: Button = find_child("PlayBtn", true, false) as Button
@onready var setting_btn: Button = find_child("SettingBtn", true, false) as Button
@onready var load_btn: Button = find_child("LoadBtn", true, false) as Button
@onready var save_btn: Button = find_child("SaveBtn", true, false) as Button

# Tham chiếu bảng SettingsPopup (nếu copy từ level_base sang)
@onready var settings_popup: Control = find_child("SettingsPopup", true, false) as Control
@onready var master_slider: HSlider = find_child("MasterSlider", true, false) as HSlider
@onready var bgm_slider: HSlider = find_child("BgmSlider", true, false) as HSlider
@onready var sfx_slider: HSlider = find_child("SfxSlider", true, false) as HSlider
@onready var close_settings_btn: Button = find_child("CloseSettingsBtn", true, false) as Button


func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_bgm("menu")
	
	if play_btn:
		play_btn.pressed.connect(play_game)
	if setting_btn:
		setting_btn.pressed.connect(_on_setting_pressed)
	if load_btn:
		load_btn.pressed.connect(on_upload_save_pressed)
	if save_btn:
		save_btn.pressed.connect(on_download_save_pressed)
		
	if settings_popup:
		settings_popup.visible = false
		_init_audio_sliders()
		if close_settings_btn:
			close_settings_btn.pressed.connect(func(): settings_popup.visible = false)
			
	# Lắng nghe kết quả nạp file save từ SaveManager
	if not SaveManager.save_imported_success.is_connected(_on_save_imported_success):
		SaveManager.save_imported_success.connect(_on_save_imported_success)
	if not SaveManager.save_import_failed.is_connected(_on_save_import_failed):
		SaveManager.save_import_failed.connect(_on_save_import_failed)


## Chuyển sang màn hình Chọn Level (theo Class Diagram)
func play_game() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


## Mở bảng Cài đặt âm lượng
func _on_setting_pressed() -> void:
	if settings_popup:
		settings_popup.visible = not settings_popup.visible


## Kích hoạt tải file save (.json) lên từ trình duyệt hoặc đọc từ máy (SCRUM-77)
func on_upload_save_pressed() -> void:
	SaveManager.trigger_web_file_upload()


## Xuất file savegame.json về máy người chơi (SCRUM-76)
func on_download_save_pressed() -> void:
	SaveManager.export_save_to_file()


func _on_save_imported_success() -> void:
	print("[MainMenu] Nạp dữ liệu tiến trình thành công!")
	play_game()


func _on_save_import_failed(error_msg: String) -> void:
	push_warning("[MainMenu] Lỗi nạp file save: " + error_msg)
	print("[MainMenu] Tính năng Export Save sẽ kết nối với SaveManager ở Sprint 7.")


# ==========================================
# ĐỒNG BỘ THANH TRƯỢT ÂM LƯỢNG
# ==========================================
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
	if bus_idx == -1 or AudioServer.is_bus_mute(bus_idx):
		return 0.0 if bus_idx != -1 else 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


func _set_bus_volume_linear(bus_name: String, linear_val: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	if linear_val <= 0.001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))
