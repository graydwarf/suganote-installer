# Detects and waits for locked files (e.g., exe still running).
# Uses file open attempt to detect locks on Windows.
class_name FileLockManager
extends Node

signal file_unlocked(file_path: String)
signal lock_timeout(file_path: String)
signal lock_check_update(file_path: String, elapsed: float, timeout: float)

var _checking: bool = false
var _target_path: String = ""
var _timeout: float = 15.0
var _poll_interval: float = 1.0
var _elapsed: float = 0.0

# Checks if a file is currently locked by another process.
# Attempts to open for writing — if it fails, the file is locked.
static func is_file_locked(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false  # Non-existent file isn't locked

	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		return true  # Can't open = locked
	return false  # Successfully opened = not locked

# Starts waiting for a file to become unlocked.
# Emits file_unlocked or lock_timeout when done.
func wait_for_unlock(file_path: String, timeout: float = 15.0, poll_interval: float = 1.0) -> void:
	_target_path = file_path
	_timeout = timeout
	_poll_interval = poll_interval
	_elapsed = 0.0
	_checking = true
	set_process(true)

	# Check immediately
	if not is_file_locked(file_path):
		_checking = false
		set_process(false)
		file_unlocked.emit(file_path)
		return

func _ready() -> void:
	set_process(false)

var _poll_accumulator: float = 0.0

func _process(delta: float) -> void:
	if not _checking:
		return

	_elapsed += delta
	_poll_accumulator += delta

	if _elapsed >= _timeout:
		_checking = false
		set_process(false)
		lock_timeout.emit(_target_path)
		return

	if _poll_accumulator >= _poll_interval:
		_poll_accumulator = 0.0
		lock_check_update.emit(_target_path, _elapsed, _timeout)

		if not is_file_locked(_target_path):
			_checking = false
			set_process(false)
			file_unlocked.emit(_target_path)

# Cancels a pending lock check
func cancel() -> void:
	_checking = false
	set_process(false)
