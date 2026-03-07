# Orchestrates the full upgrade flow: download -> verify -> wait for unlock ->
# backup -> extract -> launch -> poll for success -> cleanup.
class_name UpgradeManager
extends Node

enum Phase {
	IDLE,
	DOWNLOADING,
	VERIFYING,
	WAITING_FOR_UNLOCK,
	BACKING_UP,
	EXTRACTING,
	LAUNCHING,
	WAITING_FOR_SUCCESS,
	CLEANING_UP,
	DONE,
	FAILED,
	ROLLED_BACK
}

signal phase_changed(phase: Phase, detail: String)
signal progress_updated(percent: float, status: String)
signal upgrade_completed(success: bool, message: String)

var _config: InstallerConfig
var _manifest: Dictionary = {}
var _current_phase: Phase = Phase.IDLE
var _download_manager: DownloadManager
var _file_lock_manager: FileLockManager
var _success_poll_timer: Timer
var _success_elapsed: float = 0.0
var _managed_files: PackedStringArray = []

# Starts the upgrade process using the given config and manifest.
func start_upgrade(config: InstallerConfig, manifest: Dictionary) -> void:
	_config = config
	_manifest = manifest
	_managed_files = [config.exe_name, config.pck_name]

	_set_phase(Phase.DOWNLOADING, "Downloading update...")
	_start_download()

# Starts the first-install process (no backup/unlock needed).
func start_install(config: InstallerConfig, version_info: Dictionary) -> void:
	_config = config
	_manifest = version_info
	_managed_files = [config.exe_name, config.pck_name]

	# Ensure install directory exists
	if not DirAccess.dir_exists_absolute(config.install_dir):
		var err = DirAccess.make_dir_recursive_absolute(config.install_dir)
		if err != OK:
			_fail("Failed to create install directory: " + config.install_dir)
			return

	_set_phase(Phase.DOWNLOADING, "Downloading " + config.app_name + "...")
	_start_download()

func _start_download() -> void:
	_download_manager = DownloadManager.new()
	add_child(_download_manager)
	_download_manager.download_progress.connect(_on_download_progress)
	_download_manager.download_completed.connect(_on_download_completed)
	_download_manager.download_failed.connect(_on_download_failed)

	var url = _manifest.get("download_url", "")
	var size = _manifest.get("file_size_bytes", 0)
	var err = _download_manager.start_download(url, size, _config.get_temp_dir())
	if err != OK:
		_fail("Failed to start download")

func _on_download_progress(bytes_downloaded: int, total_bytes: int, percent: float) -> void:
	var status = "Downloading... "
	if total_bytes > 0:
		status += _format_bytes(bytes_downloaded) + " / " + _format_bytes(total_bytes)
	else:
		status += _format_bytes(bytes_downloaded)
	progress_updated.emit(percent, status)

func _on_download_completed(temp_path: String) -> void:
	_set_phase(Phase.VERIFYING, "Verifying checksum...")
	progress_updated.emit(0.0, "Verifying file integrity...")

	var expected_hash = _manifest.get("checksum_sha256", "")
	if expected_hash == "":
		# No checksum provided — skip verification
		_after_verification(temp_path)
		return

	# Run verification (synchronous but chunked so it's fast)
	var valid = ChecksumVerifier.verify_sha256(temp_path, expected_hash)
	if not valid:
		_download_manager.cleanup_temp_dir()
		_fail("Checksum verification failed. The download may be corrupted.")
		return

	_after_verification(temp_path)

func _on_download_failed(error: String) -> void:
	_fail("Download failed: " + error)

func _after_verification(temp_path: String) -> void:
	progress_updated.emit(100.0, "Verified!")

	# For first install, skip unlock/backup — go straight to extract
	if _current_phase == Phase.VERIFYING and not FileAccess.file_exists(_config.get_exe_path()):
		_set_phase(Phase.EXTRACTING, "Installing files...")
		_extract_zip(temp_path)
		return

	# Upgrade flow: wait for exe to unlock
	_set_phase(Phase.WAITING_FOR_UNLOCK, "Waiting for " + _config.app_name + " to close...")
	_wait_for_unlock(temp_path)

func _wait_for_unlock(temp_path: String) -> void:
	_file_lock_manager = FileLockManager.new()
	add_child(_file_lock_manager)
	_file_lock_manager.file_unlocked.connect(_on_file_unlocked.bind(temp_path))
	_file_lock_manager.lock_timeout.connect(_on_lock_timeout)
	_file_lock_manager.lock_check_update.connect(_on_lock_check_update)
	_file_lock_manager.wait_for_unlock(_config.get_exe_path(), _config.file_lock_timeout, _config.poll_interval)

func _on_file_unlocked(_file_path: String, temp_path: String) -> void:
	_set_phase(Phase.BACKING_UP, "Creating backups...")
	var err = RollbackManager.create_backups(_config.install_dir, _managed_files)
	if err != OK:
		_fail("Failed to create backups")
		return

	_set_phase(Phase.EXTRACTING, "Extracting update...")
	_extract_zip(temp_path)

func _on_lock_timeout(file_path: String) -> void:
	_fail(_config.app_name + " is still running. Please close it and try again.\n\nLocked file: " + file_path)

func _on_lock_check_update(_file_path: String, elapsed: float, timeout: float) -> void:
	var percent = (elapsed / timeout) * 100.0
	progress_updated.emit(percent, "Waiting for " + _config.app_name + " to close... (" + str(int(timeout - elapsed)) + "s)")

func _extract_zip(zip_path: String) -> void:
	progress_updated.emit(0.0, "Extracting files...")

	var reader = ZIPReader.new()
	var err = reader.open(zip_path)
	if err != OK:
		_handle_extract_failure("Failed to open downloaded zip file")
		return

	var files = reader.get_files()
	var extracted_count = 0

	for file_name in files:
		# Skip directories
		if file_name.ends_with("/"):
			continue

		var content = reader.read_file(file_name)
		# Extract the base filename (zip may contain folder structure)
		var base_name = file_name.get_file()
		var target_path = _config.install_dir.path_join(base_name)

		var file = FileAccess.open(target_path, FileAccess.WRITE)
		if file == null:
			reader.close()
			_handle_extract_failure("Failed to write file: " + target_path)
			return

		file.store_buffer(content)
		file.close()
		extracted_count += 1

		var percent = float(extracted_count) / float(files.size()) * 100.0
		progress_updated.emit(percent, "Extracted: " + base_name)

	reader.close()

	# Clean up temp files
	_download_manager.cleanup_temp_dir()

	# Launch the app
	_set_phase(Phase.LAUNCHING, "Launching " + _config.app_name + "...")
	_launch_app()

func _handle_extract_failure(error_msg: String) -> void:
	# If we made backups, rollback
	if _has_backups():
		_set_phase(Phase.ROLLED_BACK, "Extraction failed, restoring backups...")
		RollbackManager.restore_backups(_config.install_dir, _managed_files)
		_fail(error_msg + " (rolled back to previous version)")
	else:
		_fail(error_msg)

func _launch_app() -> void:
	progress_updated.emit(50.0, "Starting " + _config.app_name + "...")

	var exe_path = _config.get_exe_path()
	if not FileAccess.file_exists(exe_path):
		_handle_launch_failure(_config.app_name + " executable not found: " + exe_path)
		return

	var args: PackedStringArray = []
	if _config.userdata_dir != "":
		args.append("--userdata-dir")
		args.append(_config.userdata_dir)

	var pid = OS.create_process(exe_path, args)
	if pid == -1:
		_handle_launch_failure("Failed to launch " + _config.app_name)
		return

	# For first install, we're done
	if not _has_backups():
		_set_phase(Phase.DONE, _config.app_name + " installed successfully!")
		progress_updated.emit(100.0, "Installation complete!")
		upgrade_completed.emit(true, _config.app_name + " has been installed and launched.")
		return

	# For upgrade, poll for success signal
	_set_phase(Phase.WAITING_FOR_SUCCESS, "Waiting for " + _config.app_name + " to confirm upgrade...")
	_start_success_poll()

func _handle_launch_failure(error_msg: String) -> void:
	if _has_backups():
		RollbackManager.restore_backups(_config.install_dir, _managed_files)
		_fail(error_msg + " (rolled back to previous version)")
	else:
		_fail(error_msg)

func _start_success_poll() -> void:
	_success_elapsed = 0.0
	_success_poll_timer = Timer.new()
	_success_poll_timer.wait_time = _config.poll_interval
	_success_poll_timer.timeout.connect(_check_success_signal)
	add_child(_success_poll_timer)
	_success_poll_timer.start()

func _check_success_signal() -> void:
	_success_elapsed += _config.poll_interval

	var signal_path = _config.install_dir.path_join("upgrade-success.signal")
	if FileAccess.file_exists(signal_path):
		_success_poll_timer.stop()

		# Delete the signal file
		DirAccess.remove_absolute(signal_path)

		# Clean up backups
		_set_phase(Phase.CLEANING_UP, "Cleaning up...")
		RollbackManager.cleanup_backups(_config.install_dir, _managed_files)
		_download_manager.cleanup_temp_dir()

		_set_phase(Phase.DONE, "Upgrade complete!")
		progress_updated.emit(100.0, "Upgrade successful!")
		upgrade_completed.emit(true, _config.app_name + " has been upgraded successfully.")
		return

	var percent = (_success_elapsed / _config.success_timeout) * 100.0
	var remaining = int(_config.success_timeout - _success_elapsed)
	progress_updated.emit(percent, "Waiting for confirmation... (" + str(remaining) + "s)")

	if _success_elapsed >= _config.success_timeout:
		_success_poll_timer.stop()
		# Timeout — rollback
		_set_phase(Phase.ROLLED_BACK, "Upgrade confirmation timed out, rolling back...")
		RollbackManager.restore_backups(_config.install_dir, _managed_files)
		_fail("Upgrade timed out waiting for " + _config.app_name + " to confirm. Rolled back to previous version.")

# Cancels the current operation
func cancel() -> void:
	if _download_manager:
		_download_manager.cancel_download()
		_download_manager.cleanup_temp_dir()
	if _file_lock_manager:
		_file_lock_manager.cancel()
	if _success_poll_timer:
		_success_poll_timer.stop()
	_set_phase(Phase.FAILED, "Cancelled by user")
	upgrade_completed.emit(false, "Operation cancelled.")

func _set_phase(phase: Phase, detail: String) -> void:
	_current_phase = phase
	phase_changed.emit(phase, detail)

func _fail(message: String) -> void:
	_set_phase(Phase.FAILED, message)
	progress_updated.emit(0.0, message)
	upgrade_completed.emit(false, message)

func _has_backups() -> bool:
	return RollbackManager.find_backup_files(_config.install_dir).size() > 0

func get_current_phase() -> Phase:
	return _current_phase

static func _format_bytes(bytes: int) -> String:
	if bytes < 1024:
		return str(bytes) + " B"
	elif bytes < 1048576:
		return "%.1f KB" % (float(bytes) / 1024.0)
	else:
		return "%.1f MB" % (float(bytes) / 1048576.0)
