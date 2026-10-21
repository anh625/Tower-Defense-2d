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
		
	refresh_level_buttons()


## Cập nhật trạng thái Mở khóa & Số sao của các nút chọn màn (theo Class Diagram)
func refresh_level_buttons() -> void:
	# Mặc định ở Sprint 5: Mở khóa Level 1, khóa Level 2 & 3 nếu chưa tạo file scene
	if level_1_btn:
		level_1_btn.disabled = false
	if level_2_btn:
		level_2_btn.disabled = not ResourceLoader.exists("res://scenes/levels/level_2.tscn")
	if level_3_btn:
		level_3_btn.disabled = not ResourceLoader.exists("res://scenes/levels/level_3.tscn")


## Quay về màn hình chính (theo Class Diagram)
func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


## Chuyển vào màn chơi tương ứng với level_id (theo Class Diagram)
func go_to_level(level_id: int) -> void:
	var level_path: String = "res://scenes/levels/level_%d.tscn" % level_id
	if ResourceLoader.exists(level_path):
		get_tree().change_scene_to_file(level_path)
	else:
		print("[SelectLevel] Màn chơi chưa được tạo: ", level_path)


## Dự phòng cho nút Upload Save trên màn chọn Level (theo Class Diagram)
func on_upload_save_pressed() -> void:
	print("[SelectLevel] Tính năng Upload Save sẽ kết nối ở Sprint 7.")
