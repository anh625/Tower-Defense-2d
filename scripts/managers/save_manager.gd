extends Node

signal save_imported_success()
signal save_import_failed(error_msg: String)

const SAVE_PATH: String = "user://savegame.json"

var current_process: ProcessData = ProcessData.new()
var _upload_callback: JavaScriptObject = null


func _ready() -> void:
	load_progress()
	if OS.has_feature("web"):
		_upload_callback = JavaScriptBridge.create_callback(_on_file_loaded_from_browser)


## Khôi phục về trạng thái mặc định (Mở khóa Màn 1, 0 sao)
func reset_to_default() -> void:
	current_process = ProcessData.new()
	current_process.unlocked_levels = [1]
	current_process.level_stars = {"1": 0}


## Tải tiến trình từ file cục bộ user://savegame.json khi khởi động game
func load_progress() -> ProcessData:
	if not FileAccess.file_exists(SAVE_PATH):
		reset_to_default()
		save_to_local()
		return current_process

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		reset_to_default()
		return current_process

	var json_str: String = file.get_as_text()
	file.close()

	if not import_save_from_json(json_str):
		reset_to_default()
		save_to_local()

	return current_process


## Ghi dữ liệu hiện tại trong RAM xuống file cục bộ user://savegame.json
func save_to_local() -> bool:
	if not current_process:
		reset_to_default()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Không thể mở file để ghi: " + SAVE_PATH)
		return false

	var json_str: String = JSON.stringify(current_process.to_dict(), "\t")
	file.store_string(json_str)
	file.close()
	return true


## Cập nhật số sao cao nhất, mở khóa màn kế tiếp và lưu xuống máy (SCRUM-76)
func save_progress(level_id: int, stars: int) -> void:
	if not current_process:
		reset_to_default()

	var key: String = str(level_id)
	var old_stars: int = int(current_process.level_stars.get(key, 0))
	current_process.level_stars[key] = max(old_stars, clampi(stars, 0, 3))

	if not current_process.unlocked_levels.has(level_id):
		current_process.unlocked_levels.append(level_id)

	var next_level_id: int = level_id + 1
	if stars > 0 and not current_process.unlocked_levels.has(next_level_id):
		current_process.unlocked_levels.append(next_level_id)
		if not current_process.level_stars.has(str(next_level_id)):
			current_process.level_stars[str(next_level_id)] = 0

	save_to_local()


## Trả về đối tượng ProcessData hiện tại
func get_process_data() -> ProcessData:
	if not current_process:
		reset_to_default()
	return current_process


## Kiểm tra một màn chơi đã được mở khóa hay chưa
func is_level_unlocked(level_id: int) -> bool:
	if not current_process:
		return level_id == 1
	return current_process.unlocked_levels.has(level_id)


## Lấy số sao cao nhất đã đạt được của một màn chơi
func get_level_stars(level_id: int) -> int:
	if not current_process:
		return 0
	return int(current_process.level_stars.get(str(level_id), 0))


## Kiểm tra tính hợp lệ và nạp dữ liệu từ chuỗi JSON
func import_save_from_json(json_str: String) -> bool:
	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		save_import_failed.emit("File JSON bị lỗi cú pháp!")
		return false

	var data = json.data
	if not (data is Dictionary) or not data.has("unlocked_levels") or not data.has("level_stars"):
		save_import_failed.emit("Cấu trúc file save thiếu trường dữ liệu bắt buộc!")
		return false

	if not (data["unlocked_levels"] is Array) or not (data["level_stars"] is Dictionary):
		save_import_failed.emit("Kiểu dữ liệu trong file save không hợp lệ!")
		return false

	if not current_process:
		current_process = ProcessData.new()

	current_process.from_dict(data)
	save_to_local()
	save_imported_success.emit()
	return true


## Xuất file savegame.json về máy người chơi (hỗ trợ cả Web itch.io và Desktop)
func export_save_to_file() -> void:
	save_to_local()
	var json_str: String = JSON.stringify(current_process.to_dict(), "\t")
	if OS.has_feature("web"):
		var buffer: PackedByteArray = json_str.to_utf8_buffer()
		JavaScriptBridge.download_buffer(buffer, "savegame.json", "application/json")
	else:
		print("[SaveManager] Đã lưu file tại: ", ProjectSettings.globalize_path(SAVE_PATH))


## Mở hộp thoại chọn file .json trên trình duyệt Web
func trigger_web_file_upload() -> void:
	if OS.has_feature("web"):
		var window := JavaScriptBridge.get_interface("window")
		window.godot_upload_callback = _upload_callback
		var js_code: String = """
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json';
			input.onchange = function(e) {
				var file = e.target.files[0];
				if (!file) return;
				var reader = new FileReader();
				reader.onload = function(event) {
					window.godot_upload_callback(event.target.result);
				};
				reader.readAsText(file);
			};
			input.click();
		"""
		JavaScriptBridge.eval(js_code)
	else:
		load_progress()
		save_imported_success.emit()


func _on_file_loaded_from_browser(args: Array) -> void:
	if args.size() > 0:
		import_save_from_json(str(args[0]))
