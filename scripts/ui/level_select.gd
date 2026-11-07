class_name SelectLevel
extends Control

@onready var back_btn: BaseButton = find_child("BackBtn", true, false) as BaseButton
@onready var level_1_btn: Button = find_child("Level1Btn", true, false) as Button
@onready var level_2_btn: Button = find_child("Level2Btn", true, false) as Button
@onready var level_3_btn: Button = find_child("Level3Btn", true, false) as Button

@onready var stars_1_label: Label = find_child("Stars1Label", true, false) as Label
@onready var stars_2_label: Label = find_child("Stars2Label", true, false) as Label
@onready var stars_3_label: Label = find_child("Stars3Label", true, false) as Label


func _ready() -> void:
	get_tree().paused = false
	
	if back_btn:
		back_btn.pressed.connect(go_to_main_menu)
		
	if level_1_btn:
		level_1_btn.pressed.connect(func(): go_to_level(1))
	if level_2_btn:
		level_2_btn.pressed.connect(func(): go_to_level(2))
	if level_3_btn:
		level_3_btn.pressed.connect(func(): go_to_level(3))
	
	if not SaveManager.save_imported_success.is_connected(refresh_level_buttons):
		SaveManager.save_imported_success.connect(refresh_level_buttons)
		
	refresh_level_buttons()


## Đọc dữ liệu từ SaveManager để mở khóa nút chọn màn và hiển thị số sao (SCRUM-77)
func refresh_level_buttons() -> void:
	SaveManager.get_process_data()
	_update_single_level_ui(1, level_1_btn, stars_1_label)
	_update_single_level_ui(2, level_2_btn, stars_2_label)
	_update_single_level_ui(3, level_3_btn, stars_3_label)


func _update_single_level_ui(level_id: int, btn: Button, stars_lbl: Label) -> void:
	var is_unlocked: bool = SaveManager.is_level_unlocked(level_id)
	var stars: int = SaveManager.get_level_stars(level_id)
	
	if btn:
		btn.disabled = not is_unlocked
		if is_unlocked:
			btn.text = "LEVEL %d" % level_id
		else:
			btn.text = "LEVEL %d\n(Khóa)" % level_id
			
	if stars_lbl:
		if is_unlocked:
			stars_lbl.text = "★ ".repeat(stars) + "☆ ".repeat(3 - stars)
		else:
			stars_lbl.text = "☆ ☆ ☆"


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func go_to_level(level_id: int) -> void:
	if not SaveManager.is_level_unlocked(level_id):
		print("[SelectLevel] Màn chơi %d chưa được mở khóa!" % level_id)
		return
		
	var level_path: String = "res://scenes/levels/level_%d.tscn" % level_id
	if ResourceLoader.exists(level_path):
		get_tree().change_scene_to_file(level_path)
	else:
		print("[SelectLevel] Màn chơi đã mở khóa nhưng chưa tạo file scene: ", level_path)


func on_upload_save_pressed() -> void:
	SaveManager.trigger_web_file_upload()
