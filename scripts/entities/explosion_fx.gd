extends CPUParticles2D

func _ready() -> void:
	# Bắt đầu phát hạt ngay khi xuất hiện trên màn hình
	emitting = true
	# Tự động xóa Node khỏi bộ nhớ ngay khi các hạt tan biến hết
	finished.connect(queue_free)
