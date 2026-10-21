class_name SkillHUD
extends Control

## Tham chiếu đến SkillManager trong màn chơi
@export var skill_manager: SkillManager

## Các thuộc tính theo Class Diagram (dùng BaseButton/Range để tương thích cả TextureButton lẫn Button)
@onready var btn_meteor: BaseButton = find_child("BtnMeteor", true, false) as BaseButton
@onready var btn_freeze: BaseButton = find_child("BtnFreeze", true, false) as BaseButton
@onready var meteor_cooldown_overlay: Range = find_child("MeteorCooldownOverlay", true, false) as Range
@onready var freeze_cooldown_overlay: Range = find_child("FreezeCooldownOverlay", true, false) as Range

@onready var meteor_timer_label: Label = find_child("MeteorTimerLabel", true, false) as Label
@onready var freeze_timer_label: Label = find_child("FreezeTimerLabel", true, false) as Label
@onready var aoe_reticle: Node2D = find_child("AoEReticle", true, false) as Node2D

## Trạng thái đang bật vòng ngắm thả Thiên thạch theo Class Diagram
var is_targeting_meteor: bool = false


func _ready() -> void:
	# Tự động tìm SkillManager trong Level nếu chưa gán trên Inspector
	if not skill_manager:
		skill_manager = get_tree().current_scene.find_child("SkillManager", true, false) as SkillManager
		
	if btn_meteor:
		btn_meteor.pressed.connect(on_meteor_pressed)
	if btn_freeze:
		btn_freeze.pressed.connect(on_freeze_pressed)
		
	if skill_manager:
		skill_manager.cooldown_updated.connect(update_skill_cooldowns)
		if meteor_cooldown_overlay:
			meteor_cooldown_overlay.max_value = skill_manager.max_meteor_cooldown
		if freeze_cooldown_overlay:
			freeze_cooldown_overlay.max_value = skill_manager.max_freeze_cooldown
			
	if aoe_reticle:
		aoe_reticle.visible = false
		aoe_reticle.draw.connect(_on_aoe_reticle_draw)
		
	update_skill_cooldowns(0.0, 0.0)


func _process(_delta: float) -> void:
	if is_targeting_meteor and aoe_reticle:
		aoe_reticle.global_position = get_global_mouse_position()
		aoe_reticle.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_targeting_meteor:
		return
		
	# Click chuột trái trên bản đồ -> Xác nhận tọa độ thả Mưa thiên thạch
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target_pos: Vector2 = get_global_mouse_position()
		if skill_manager:
			skill_manager.cast_meteor_strike(target_pos)
		cancel_targeting()
		get_viewport().set_input_as_handled()
		
	# Click chuột phải hoặc nhấn ESC -> Hủy ngắm bắn, không tốn Cooldown (Luồng 3a UC-3.1)
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) \
		or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		cancel_targeting()
		get_viewport().set_input_as_handled()


## Sự kiện khi bấm nút Mưa thiên thạch
func on_meteor_pressed() -> void:
	if not skill_manager or not skill_manager.is_meteor_ready:
		_shake_button(btn_meteor)
		return
		
	if is_targeting_meteor:
		cancel_targeting()
	else:
		start_meteor_targeting()


## Sự kiện khi bấm nút Đóng băng
func on_freeze_pressed() -> void:
	if not skill_manager or not skill_manager.is_freeze_ready:
		_shake_button(btn_freeze)
		return
		
	cancel_targeting()
	skill_manager.cast_freeze_all()


## Bật chế độ chọn vùng rơi Thiên thạch (AoE Reticle)
func start_meteor_targeting() -> void:
	is_targeting_meteor = true
	if aoe_reticle:
		aoe_reticle.visible = true
		aoe_reticle.global_position = get_global_mouse_position()
		aoe_reticle.queue_redraw()


## Hủy chế độ chọn vùng rơi Thiên thạch
func cancel_targeting() -> void:
	is_targeting_meteor = false
	if aoe_reticle:
		aoe_reticle.visible = false


## Cập nhật hiển thị bóng mờ và số giây Cooldown trên 2 nút kỹ năng
func update_skill_cooldowns(meteor_cd: float, freeze_cd: float) -> void:
	# 1. Cập nhật UI nút Thiên thạch
	var meteor_on_cd: bool = meteor_cd > 0.0
	if btn_meteor:
		btn_meteor.modulate = Color(0.275, 0.275, 0.275, 1.0) if meteor_on_cd else Color.WHITE
	if meteor_cooldown_overlay:
		meteor_cooldown_overlay.visible = meteor_on_cd
		meteor_cooldown_overlay.value = meteor_cd
	if meteor_timer_label:
		meteor_timer_label.visible = meteor_on_cd
		meteor_timer_label.text = "%.1fs" % meteor_cd
		
	# 2. Cập nhật UI nút Đóng băng
	var freeze_on_cd: bool = freeze_cd > 0.0
	if btn_freeze:
		btn_freeze.modulate = Color(0.275, 0.275, 0.275, 1.0) if freeze_on_cd else Color.WHITE
	if freeze_cooldown_overlay:
		freeze_cooldown_overlay.visible = freeze_on_cd
		freeze_cooldown_overlay.value = freeze_cd
	if freeze_timer_label:
		freeze_timer_label.visible = freeze_on_cd
		freeze_timer_label.text = "%.1fs" % freeze_cd


## Vẽ vòng tròn hiển thị phạm vi nổ AoE của Thiên thạch
func _on_aoe_reticle_draw() -> void:
	var radius: float = skill_manager.meteor_radius if skill_manager else 120.0
	aoe_reticle.draw_circle(Vector2.ZERO, radius, Color(1.0, 0.2, 0.1, 0.25))
	aoe_reticle.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.3, 0.1, 0.9), 2.5)


## Hiệu ứng rung nhẹ icon khi người chơi bấm vào kỹ năng đang hồi chiêu (Luồng 2a UC-3.1)
func _shake_button(btn: BaseButton) -> void:
	if not btn:
		return
	var orig_x: float = btn.position.x
	var tween: Tween = create_tween()
	tween.tween_property(btn, "position:x", orig_x - 5.0, 0.04)
	tween.tween_property(btn, "position:x", orig_x + 5.0, 0.04)
	tween.tween_property(btn, "position:x", orig_x, 0.04)
