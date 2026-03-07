# Downloads files via HTTPRequest with progress tracking and temp file management.
class_name DownloadManager
extends Node

signal download_progress(bytes_downloaded: int, total_bytes: int, percent: float)
signal download_completed(temp_path: String)
signal download_failed(error: String)

var _http_request: HTTPRequest
var _temp_dir: String = ""
var _temp_path: String = ""
var _expected_size: int = 0
var _downloading: bool = false
var _progress_timer: Timer

# Starts downloading a file from url into temp_dir.
# Returns OK if download started, or an error code.
func start_download(url: String, expected_size: int, temp_dir: String) -> Error:
	if _downloading:
		return ERR_BUSY

	_temp_dir = temp_dir
	_expected_size = expected_size

	# Ensure temp directory exists
	if not DirAccess.dir_exists_absolute(temp_dir):
		var err = DirAccess.make_dir_recursive_absolute(temp_dir)
		if err != OK:
			download_failed.emit("Failed to create temp directory: " + temp_dir)
			return err

	_temp_path = temp_dir.path_join("download.zip")

	# Setup HTTPRequest
	if _http_request:
		_http_request.queue_free()

	_http_request = HTTPRequest.new()
	_http_request.download_file = _temp_path
	_http_request.use_threads = true
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

	# Setup progress polling timer
	if _progress_timer:
		_progress_timer.queue_free()
	_progress_timer = Timer.new()
	_progress_timer.wait_time = 0.1
	_progress_timer.timeout.connect(_poll_progress)
	add_child(_progress_timer)

	# Start download
	var err = _http_request.request(url)
	if err != OK:
		download_failed.emit("Failed to start download: error " + str(err))
		return err

	_downloading = true
	_progress_timer.start()
	return OK

# Cancels an in-progress download
func cancel_download() -> void:
	if not _downloading:
		return
	_downloading = false
	if _progress_timer:
		_progress_timer.stop()
	if _http_request:
		_http_request.cancel_request()
	_cleanup_temp_file()

func _poll_progress() -> void:
	if not _downloading or not _http_request:
		return

	var downloaded = _http_request.get_downloaded_bytes()
	var total = _http_request.get_body_size()

	# Prefer expected_size if server didn't provide Content-Length
	if total <= 0 and _expected_size > 0:
		total = _expected_size

	var percent = 0.0
	if total > 0:
		percent = float(downloaded) / float(total) * 100.0

	download_progress.emit(downloaded, total, percent)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	if _progress_timer:
		_progress_timer.stop()

	if result != HTTPRequest.RESULT_SUCCESS:
		_cleanup_temp_file()
		download_failed.emit("Download failed: HTTPRequest result " + str(result))
		return

	if response_code != 200:
		_cleanup_temp_file()
		download_failed.emit("Download failed: HTTP " + str(response_code))
		return

	# Final progress emission at 100%
	var file_size = FileAccess.get_file_as_bytes(_temp_path).size() if FileAccess.file_exists(_temp_path) else 0
	download_progress.emit(file_size, file_size, 100.0)
	download_completed.emit(_temp_path)

func _cleanup_temp_file() -> void:
	if _temp_path != "" and FileAccess.file_exists(_temp_path):
		DirAccess.remove_absolute(_temp_path)

# Cleans up the entire temp directory
func cleanup_temp_dir() -> void:
	_cleanup_temp_file()
	if _temp_dir != "" and DirAccess.dir_exists_absolute(_temp_dir):
		var dir = DirAccess.open(_temp_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(_temp_dir)
