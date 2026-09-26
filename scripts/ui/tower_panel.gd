class_name TowerPanel
extends Control

## Cấu hình dữ liệu các loại tháp nạp từ file .tres
@export var archer_data: TowerData
@export var wizard_data: TowerData
@export var barrack_data: TowerData

## Tham chiếu đến GridSystem và Level của trận đấu
@export var grid_system: GridSystem
@export var level_node: Level

## Trạng thái Preview
var current_preview_type: TowerData = null
var is_previewing: bool = false
var is_valid_position: bool = false
var preview_cell: Vector2i = Vector2i.ZERO

@onready var preview_indicator: Node2D = $PreviewIndicator
@onready var preview_sprite: Sprite2D = $PreviewIndicator/Sprite2D


func _ready() -> void:
	preview_indicator.visible = false
	preview_sprite.position = Vector2(0, -44)
	
	# Kết nối sự kiện nút bấm trên HUD
	var btn_archer = find_child("BtnArcher", true, false) as Button
	if btn_archer:
		btn_archer.pressed.connect(func():
			print(">>> ĐÃ CLICK NÚT MUA CUNG! <<<")
			start_placement_preview(archer_data)
		)	
		
	var btn_wizard = find_child("BtnWizard", true, false) as Button
	if btn_wizard:
		btn_wizard.pressed.connect(func(): 
			print(">>> ĐÃ CLICK NÚT MUA PHÁP SƯ! <<<")
			start_placement_preview(wizard_data)
		)	
	
	var btn_barrack = find_child("BtnBarrack", true, false) as Button
	if btn_barrack:
		btn_barrack.pressed.connect(func(): 
			print(">>> ĐÃ CLICK NÚT MUA PHÁP SƯ! <<<")
			start_placement_preview(barrack_data)
		)	
	

func _process(_delta: float) -> void:
	if not is_previewing or not current_preview_type or not grid_system:
		return
	
	var mouse_pos = get_global_mouse_position()
	preview_cell = grid_system.world_to_cell(mouse_pos)
	preview_indicator.global_position = grid_system.cell_to_world(preview_cell)
	
	is_valid_position = grid_system.can_place_at(preview_cell)
	preview_sprite.modulate = Color(0.2, 1.0, 0.2, 0.7) if is_valid_position else Color(1.0, 0.2, 0.2, 0.7)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not is_previewing:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		request_place_tower(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) \
	or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		cancel_preview()
		get_viewport().set_input_as_handled()


## Kích hoạt chế độ Preview khi bấm mua tháp
func start_placement_preview(tower_data: TowerData) -> void:
	if not tower_data:
		return
		
	current_preview_type = tower_data
	is_previewing = true
	preview_indicator.visible = true
	
	# Gán ảnh bóng tháp
	if not tower_data.sprites.is_empty() and tower_data.sprites[0] != null:
		preview_sprite.texture = tower_data.sprites[0]
	
	queue_redraw()


## Hủy bỏ Preview
func cancel_preview() -> void:
	is_previewing = false
	current_preview_type = null
	preview_indicator.visible = false
	queue_redraw()


## Thực hiện kiểm tra và xây tháp
func request_place_tower(world_pos: Vector2) -> bool:
	if not current_preview_type or not grid_system or not level_node:
		return false
	
	var cell_pos = grid_system.world_to_cell(world_pos)
	
	# 1. Kiểm tra vị trí ô hợp lệ
	if not grid_system.can_place_at(cell_pos):
		print("[Xây dựng] Vị trí ô bị chặn hoặc không hợp lệ!")
		return false
	
	# 2. Kiểm tra số dư vàng
	var tower_cost = current_preview_type.cost
	if level_node.current_golds < tower_cost:
		print("[Xây dựng] Không đủ vàng! Cần: %d - Có: %d" % [tower_cost, level_node.current_golds])
		return false
	
	# 3. Trừ vàng & Cập nhật
	level_node.current_golds -= tower_cost
	level_node.gold_changed.emit(level_node.current_golds)
	
	# 4. Tạo thực thể Tháp mới
	var tower_scene = load("res://scenes/towers/tower_base.tscn") as PackedScene
	var tower_instance = tower_scene.instantiate() as Tower
	tower_instance.data = current_preview_type
	
	# Đồng bộ scale x0.4 cho Tháp để không bị tràn ô
	tower_instance.scale = Vector2(0.4, 0.4)
	tower_instance.global_position = grid_system.cell_to_world(cell_pos)
	
	# Đưa tháp vào màn chơi
	var towers_container = level_node.get_node_or_null("TowersContainer")
	if towers_container:
		towers_container.add_child(tower_instance)
	else:
		level_node.add_child(tower_instance)
		
	# 5. Ghi nhận ô đã bị chiếm dụng
	grid_system.register_tower(cell_pos, tower_instance)
	
	# 6. Đóng chế độ Preview
	cancel_preview()
	print("[Xây dựng] Đặt tháp thành công tại ô: ", cell_pos)
	return true


## Vẽ vòng tầm bắn hình tròn đồng bộ với CircleShape2D (Cách 2)
func _draw() -> void:
	if is_previewing and current_preview_type:
		var radius: float = current_preview_type.attack_range[0] * 0.4
		var center: Vector2 = preview_indicator.global_position
		
		# Thiết lập màu sắc: Xanh khi hợp lệ, Đỏ khi không thể đặt
		var fill_color = Color(0.2, 1.0, 0.2, 0.2) if is_valid_position else Color(1.0, 0.2, 0.2, 0.2)
		var border_color = Color(0.2, 1.0, 0.2, 0.8) if is_valid_position else Color(1.0, 0.2, 0.2, 0.8)
		
		# 1. Tô vùng diện tích tròn bên trong
		draw_circle(center, radius, fill_color)
		
		# 2. Vẽ viền tròn bao quanh
		draw_arc(center, radius, 0.0, TAU, 48, border_color, 2.0)
