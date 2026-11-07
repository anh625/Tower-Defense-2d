class_name ProcessData
extends Resource

@export var unlocked_levels: Array[int] = [1]
@export var level_stars: Dictionary = {"1": 0}


## Chuyển đổi dữ liệu trong RAM sang Dictionary để ghi ra JSON
func to_dict() -> Dictionary:
	return {
		"unlocked_levels": unlocked_levels,
		"level_stars": level_stars
	}


## Phục hồi dữ liệu từ Dictionary khi đọc file JSON
func from_dict(data: Dictionary) -> void:
	if data.has("unlocked_levels") and data["unlocked_levels"] is Array:
		unlocked_levels.clear()
		for lvl in data["unlocked_levels"]:
			var lvl_id: int = int(lvl)
			if not unlocked_levels.has(lvl_id):
				unlocked_levels.append(lvl_id)
	
	if unlocked_levels.is_empty():
		unlocked_levels.append(1)

	if data.has("level_stars") and data["level_stars"] is Dictionary:
		level_stars.clear()
		for k in data["level_stars"].keys():
			level_stars[str(k)] = clampi(int(data["level_stars"][k]), 0, 3)
