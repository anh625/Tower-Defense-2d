# res://scripts/ui/tower_panel.gd
class_name TowerPanel
extends Control

## Cấu hình dữ liệu các loại tháp nạp từ file .tres
@export var archer_data: TowerData
@export var wizard_data: TowerData
@export var barrack_data: TowerData

## Tham chiếu đến GridSystem và Level của trận đấu
@export var grid_system: GridSystem
@export var level_node: Level

## Trạng thái Preview đặt tháp mới
var current_preview_type: TowerData = null
var is_previewing: bool = false
var is_valid_position: bool = false
var preview_cell: Vector2i = Vector2i.ZERO

## Trạng thái Tương tác tháp đã đặt (Nâng cấp / Bán)
var selected_tower: Tower = null

@onready var preview_indicator: Node2D = $PreviewIndicator
@onready var preview_sprite: Sprite2D = $PreviewIndicator/Sprite2D
@onready var btn_archer = find_child("BtnArcher", true, false) as Button
@onready var btn_wizard = find_child("BtnWizard", true, false) as Button
@onready var btn_barrack = find_child("BtnBarrack", true, false) as Button

## Tham chiếu các Node trong UpgradePopup
@onready var upgrade_popup: Control = find_child("UpgradePopup", true, false) as Control
@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var stats_label: Label = find_child("StatsLabel", true, false) as Label
@onready var btn_upgrade: Button = find_child("BtnUpgrade", true, false) as Button
@onready var btn_sell: Button = find_child("BtnSell", true, false) as Button
@onready var btn_close: Button = find_child("BtnClose", true, false) as Button


func _ready() -> void:
	if not level_node:
		level_node = get_parent() as Level
	if not grid_system and level_node:
		grid_system = level_node.get_node_or_null("GridSystem") as GridSystem

	preview_indicator.visible = false
	preview_sprite.position = Vector2(0, -44)
	
	if upgrade_popup:
		upgrade_popup.visible = false
	
	if btn_archer and archer_data:
		btn_archer.text = "Mua Cung - " + str(archer_data.cost) + "G"
		btn_archer.pressed.connect(func(): start_placement_preview(archer_data))
		
	if btn_wizard and wizard_data:
		btn_wizard.text = "Mua Pháp Sư - " + str(wizard_data.cost) + "G"
		btn_wizard.pressed.connect(func(): start_placement_preview(wizard_data))
		
	if btn_barrack and barrack_data:
		btn_barrack.text = "Mua Kiếm Sĩ - " + str(barrack_data.cost) + "G"
		btn_barrack.pressed.connect(func(): start_placement_preview(barrack_data))
	
	# Kết nối sự kiện cho các nút Nâng cấp, Bán, Đóng
	if btn_upgrade:
		btn_upgrade.pressed.connect(_on_upgrade_pressed)
	if btn_sell:
		btn_sell.pressed.connect(_on_sell_pressed)
	if btn_close:
		btn_close.pressed.connect(deselect_tower)
		
	if level_node:
		level_node.gold_changed.connect(_on_level_gold_changed)
		_on_level_gold_changed(level_node.current_golds)


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
	# 1. Nếu đang trong chế độ Preview mua tháp mới
	if is_previewing:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			request_place_tower(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) \
		or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
			cancel_preview()
			get_viewport().set_input_as_handled()
		return

	# 2. Nếu KHÔNG Preview: Xử lý click chọn tháp trên bản đồ để mở bảng Nâng cấp / Bán
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_tower: Tower = _get_tower_at_mouse(get_global_mouse_position())
		if clicked_tower:
			select_tower(clicked_tower)
			get_viewport().set_input_as_handled()
		elif selected_tower != null:
			# Click ra ngoài vùng trống -> Đóng bảng thông tin tháp
			deselect_tower()
			
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) \
	or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		if selected_tower != null:
			deselect_tower()
			get_viewport().set_input_as_handled()


## Tìm tháp tại vị trí chuột (ưu tiên theo ô lưới hoặc khoảng cách gần thân tháp)
func _get_tower_at_mouse(world_pos: Vector2) -> Tower:
	if not grid_system:
		return null
		
	var cell: Vector2i = grid_system.world_to_cell(world_pos)
	if grid_system.occupied_cells.has(cell):
		return grid_system.occupied_cells[cell] as Tower
		
	# Hỗ trợ khi người chơi click vào phần thân trên của Sprite tháp Isometric
	for occupied_cell in grid_system.occupied_cells.keys():
		var tower: Tower = grid_system.occupied_cells[occupied_cell] as Tower
		if is_instance_valid(tower) and tower.global_position.distance_to(world_pos + Vector2(0, 20)) <= 45.0:
			return tower
	return null


## Mở Bảng thông tin khi click vào tháp đã xây
func select_tower(tower: Tower) -> void:
	selected_tower = tower
	_update_upgrade_popup_ui()
	
	if upgrade_popup:
		upgrade_popup.visible = true
		# Luôn đảm bảo Popup vẽ nổi lên trên mọi tháp và quái vật
		upgrade_popup.z_index = 100
		
		# Ép контейner tính lại kích thước chuẩn ngay sau khi đổi text
		upgrade_popup.reset_size()
		
		# Khoảng cách từ gốc chân tháp lên phía trên đỉnh tháp (tăng/giảm số 75.0 nếu muốn cao/thấp hơn)
		var tower_top_offset: float = 75.0
		
		var popup_pos: Vector2 = Vector2(
			tower.global_position.x - upgrade_popup.size.x / 2.0,
			tower.global_position.y - upgrade_popup.size.y - tower_top_offset
		)
		
		# Giữ Popup không bị tràn ra ngoài màn hình (nếu tháp đặt sát mép trên)
		var viewport_rect: Rect2 = get_viewport_rect()
		popup_pos.x = clampf(popup_pos.x, 10.0, viewport_rect.size.x - upgrade_popup.size.x - 10.0)
		popup_pos.y = clampf(popup_pos.y, 10.0, viewport_rect.size.y - upgrade_popup.size.y - 10.0)
		
		upgrade_popup.global_position = popup_pos
		
	queue_redraw()


## Ẩn Bảng thông tin và tắt vòng tầm bắn
func deselect_tower() -> void:
	selected_tower = null
	if upgrade_popup:
		upgrade_popup.visible = false
	queue_redraw()


## Cập nhật thông số hiển thị trên Popup
func _update_upgrade_popup_ui() -> void:
	if not is_instance_valid(selected_tower) or not selected_tower.data:
		return
		
	var data: TowerData = selected_tower.data
	if title_label:
		title_label.text = "%s (Lv.%d/%d)" % [data.tower_name, selected_tower.current_level, data.max_level]
		
	if stats_label:
		stats_label.text = "Sát thương: %d\nTầm bắn: %d\nTốc đánh: %.2f/s" % [
			int(selected_tower.get_current_damage()),
			int(selected_tower.get_current_range()),
			selected_tower.get_current_attack_speed()
		]
		
	if btn_upgrade:
		if selected_tower.is_max_level():
			btn_upgrade.text = "Đã đạt cấp tối đa"
			btn_upgrade.disabled = true
		else:
			var upg_cost: int = selected_tower.get_upgrade_cost()
			btn_upgrade.text = "Nâng cấp (%dG)" % upg_cost
			btn_upgrade.disabled = not (level_node and level_node.can_afford(upg_cost))
			
	if btn_sell:
		btn_sell.text = "Bán (+%dG)" % selected_tower.get_sell_refund()


## Xử lý khi bấm nút "Nâng cấp (Upgrade)" (UC-4.2)
func _on_upgrade_pressed() -> void:
	if not is_instance_valid(selected_tower) or not level_node:
		return
		
	if selected_tower.is_max_level():
		print("[Nâng cấp] Tháp đã đạt cấp tối đa!")
		return
		
	var upg_cost: int = selected_tower.get_upgrade_cost()
	if not level_node.spend_gold(upg_cost):
		print("[Nâng cấp] Không đủ vàng nâng cấp!")
		return
		
	selected_tower.upgrade()
	_update_upgrade_popup_ui()
	queue_redraw()
	print("[Nâng cấp] Nâng cấp thành công lên Lv.", selected_tower.current_level)


## Xử lý khi bấm nút "Bán tháp (Sell)" (UC-4.3)
func _on_sell_pressed() -> void:
	if not is_instance_valid(selected_tower) or not level_node or not grid_system:
		return
		
	# 1. Tính và cộng vàng hoàn trả cho người chơi
	var refund: int = selected_tower.get_sell_refund()
	level_node.add_gold(refund)
	
	# 2. Giải phóng ô đất trên GridSystem
	grid_system.unregister_tower(selected_tower.cell_pos)
	
	# 3. Xóa thực thể tháp và đóng Popup
	var sold_cell: Vector2i = selected_tower.cell_pos
	selected_tower.queue_free()
	deselect_tower()
	print("[Bán tháp] Đã bán tháp tại ô %s, hoàn lại %dG" % [str(sold_cell), refund])


## Kích hoạt chế độ Preview khi bấm mua tháp
func start_placement_preview(tower_data: TowerData) -> void:
	if not tower_data:
		return
	deselect_tower() # Đóng bảng thông tin tháp cũ nếu đang mở
	
	current_preview_type = tower_data
	is_previewing = true
	preview_indicator.visible = true
	
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
	
	if not grid_system.can_place_at(cell_pos):
		print("[Xây dựng] Vị trí ô bị chặn hoặc không hợp lệ!")
		return false
	
	if not level_node.spend_gold(current_preview_type.cost):
		print("Không đủ vàng để mua tháp!")
		return false
	
	var tower_scene = load("res://scenes/towers/tower_base.tscn") as PackedScene
	var tower_instance = tower_scene.instantiate() as Tower
	tower_instance.data = current_preview_type
	tower_instance.cell_pos = cell_pos
	tower_instance.scale = Vector2(0.4, 0.4)
	tower_instance.global_position = grid_system.cell_to_world(cell_pos)
	
	var towers_container = level_node.get_node_or_null("TowersContainer")
	if towers_container:
		towers_container.add_child(tower_instance)
	else:
		level_node.add_child(tower_instance)
		
	grid_system.register_tower(cell_pos, tower_instance)
	cancel_preview()
	print("[Xây dựng] Đặt tháp thành công tại ô: ", cell_pos)
	return true


## Vẽ vòng tầm bắn cho chế độ Preview HOẶC cho Tháp đang được chọn
func _draw() -> void:
	# 1. Vẽ tầm bắn khi đang Preview đặt tháp mới
	if is_previewing and current_preview_type:
		var radius: float = current_preview_type.attack_range[0] * 0.4
		var center: Vector2 = preview_indicator.global_position
		var fill_color = Color(0.2, 1.0, 0.2, 0.2) if is_valid_position else Color(1.0, 0.2, 0.2, 0.2)
		var border_color = Color(0.2, 1.0, 0.2, 0.8) if is_valid_position else Color(1.0, 0.2, 0.2, 0.8)
		draw_circle(center, radius, fill_color)
		draw_arc(center, radius, 0.0, TAU, 48, border_color, 2.0)
		
	# 2. Vẽ tầm bắn hiện tại khi click chọn một tháp đã đặt trên bản đồ
	elif is_instance_valid(selected_tower):
		var radius: float = selected_tower.get_current_range() * 0.4
		var center: Vector2 = selected_tower.global_position
		draw_circle(center, radius, Color(0.2, 0.6, 1.0, 0.2))
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.2, 0.6, 1.0, 0.85), 2.0)


func _on_level_gold_changed(new_gold: int) -> void:
	if btn_archer and archer_data:
		btn_archer.disabled = (new_gold < archer_data.cost)
	if btn_wizard and wizard_data:
		btn_wizard.disabled = (new_gold < wizard_data.cost)
	if btn_barrack and barrack_data:
		btn_barrack.disabled = (new_gold < barrack_data.cost)
		
	# Cập nhật lại trạng thái nút Nâng cấp nếu Popup đang mở
	if is_instance_valid(selected_tower) and upgrade_popup and upgrade_popup.visible:
		_update_upgrade_popup_ui()
