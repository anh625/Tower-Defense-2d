class_name TowerData
extends Resource

## Định danh duy nhất của tháp (Ví dụ: "tower_archer", "tower_wizard")
@export var tower_id: String = ""

## Tên hiển thị trên giao diện người dùng (Ví dụ: "Tháp Cung Thủ", "Tháp Pháp Sư")
@export var tower_name: String = ""

## Cấp độ nâng cấp tối đa của tháp
@export var max_level: int = 3

## Giá vàng ban đầu để mua tháp ở Cấp 1
@export var cost: int = 100

## Mảng chứa texture hiển thị theo từng cấp [Lv1, Lv2, Lv3]
@export var sprites: Array[Texture2D] = []

## Mảng chỉ số sát thương cơ bản theo từng cấp [Lv1, Lv2, Lv3]
@export var base_damage: Array[int] = [20, 35, 55]

## Mảng bán kính tầm bắn (pixel) theo từng cấp [Lv1, Lv2, Lv3]
@export var attack_range: Array[float] = [150.0, 175.0, 200.0]

## Mảng tốc độ đánh (số lần bắn/giây) theo từng cấp [Lv1, Lv2, Lv3]
@export var attack_speed: Array[float] = [1.2, 1.4, 1.6]

## Mảng chi phí vàng để nâng cấp lên cấp tiếp theo [Lv1->Lv2, Lv2->Lv3]
@export var upgrade_cost: Array[int] = [75, 120]

## Scene đạn (Projectile) tương ứng sẽ được tháp bắn ra
@export var projectile_scene: PackedScene
