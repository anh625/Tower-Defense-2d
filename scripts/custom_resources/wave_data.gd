class_name WaveData
extends Resource

@export var wave_index: int = 1
@export var enemy_data: EnemyData     # Kéo file .tres của con quái vào đây
@export var enemy_count: int = 10     # Số lượng quái sinh ra trong đợt
@export var spawn_interval: float = 1.5 # Giãn cách sinh giữa 2 con quái (giây)
