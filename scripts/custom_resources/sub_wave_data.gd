class_name SubWaveData
extends Resource

@export var enemy_data: EnemyData      # Loại quái của tốp này (.tres)
@export var enemy_count: int = 5       # Số lượng quái trong tốp
@export var spawn_interval: float = 1.0 # Khoảng cách sinh giữa từng con (giây)
@export var delay_after_subwave: float = 2.0 # Nghỉ bao lâu trước khi sang tốp tiếp theo
