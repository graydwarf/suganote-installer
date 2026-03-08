extends Control

# Shell project main: parses CLI args, configures InstallerConfig,
# wires InstallerUI + UpgradeManager for install/upgrade/rollback.

var _config: InstallerConfig
var _cli: InstallerCLI
var _ui: Control  # InstallerUI
var _upgrade_manager: UpgradeManager
var _version_fetcher: VersionFetcher

func _ready() -> void:
	_config = InstallerConfig.new()

	# Load app identity from app-config.json (created by CI or from template)
	_load_app_config()

	# Load version check config
	_load_license_config()

	# Parse CLI
	_cli = InstallerCLI.new()
	_cli.parse()

	# Create UI
	_ui = preload("res://scenes/installer-ui.gd").new()
	add_child(_ui)
	_ui.setup(_config)

	match _cli.mode:
		InstallerCLI.Mode.FIRST_INSTALL:
			_start_first_install()
		InstallerCLI.Mode.UPGRADE:
			_start_upgrade()
		InstallerCLI.Mode.ROLLBACK:
			_start_rollback()

# Reads app identity (name, exe, logo, colors) from app-config.json
func _load_app_config() -> void:
	var config_path = "res://app-config.json"
	if not FileAccess.file_exists(config_path):
		push_warning("app-config.json not found — using defaults")
		return
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is not Dictionary:
		return

	_config.app_name = data.get("app_name", _config.app_name)
	_config.exe_name = data.get("exe_name", _config.exe_name)
	_config.pck_name = data.get("pck_name", _config.pck_name)

	var color_arr = data.get("accent_color", [])
	if color_arr is Array and color_arr.size() >= 3:
		_config.accent_color = Color(color_arr[0], color_arr[1], color_arr[2])

	var logo_path = data.get("logo_path", "")
	if logo_path != "":
		var logo = load(logo_path)
		if logo:
			_config.logo_texture = logo

func _load_license_config() -> void:
	var config_path = "res://license-config.json"
	if not FileAccess.file_exists(config_path):
		return
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is Dictionary:
		_config.version_check_url = data.get("supabase_license_url", "") + "/functions/v1/version-check"
		_config.version_check_api_key = data.get("supabase_license_key", "")

func _start_first_install() -> void:
	_ui.show_install_view()
	_ui.install_requested.connect(_on_install_location_chosen)
	_ui.cancel_requested.connect(_on_cancel)

func _on_install_location_chosen(install_dir: String) -> void:
	_config.install_dir = install_dir
	_ui.show_upgrade_view()

	# Fetch latest version info then start install
	_version_fetcher = VersionFetcher.new()
	add_child(_version_fetcher)
	_version_fetcher.version_fetched.connect(_on_version_fetched_for_install)
	_version_fetcher.version_fetch_failed.connect(_on_fetch_failed)
	_version_fetcher.fetch_latest(_config.version_check_url, _config.version_check_api_key)

func _on_version_fetched_for_install(version_info: Dictionary) -> void:
	var download_url = version_info.get("download_url", "")
	if download_url == "":
		_ui._status_label.text = "No Release Available"
		_ui._detail_label.text = "There are no published releases yet. Check back later."
		return

	_upgrade_manager = UpgradeManager.new()
	add_child(_upgrade_manager)
	_ui.bind_upgrade_manager(_upgrade_manager)
	_upgrade_manager.start_install(_config, version_info)

func _on_fetch_failed(error: String) -> void:
	_ui._status_label.text = "Failed"
	_ui._detail_label.text = "Could not fetch version info: " + error

func _start_upgrade() -> void:
	_ui.show_upgrade_view()

	# Read manifest from CLI path
	var manifest_path = _cli.manifest_path
	if manifest_path == "":
		manifest_path = ProjectSettings.globalize_path("user://pending-upgrade.json")

	if not FileAccess.file_exists(manifest_path):
		_ui._status_label.text = "Failed"
		_ui._detail_label.text = "Upgrade manifest not found: " + manifest_path
		return

	var file = FileAccess.open(manifest_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_ui._status_label.text = "Failed"
		_ui._detail_label.text = "Invalid upgrade manifest"
		return

	var manifest = json.data
	_config.install_dir = manifest.get("install_dir", "")
	_config.userdata_dir = manifest.get("userdata_dir", "")

	_upgrade_manager = UpgradeManager.new()
	add_child(_upgrade_manager)
	_ui.bind_upgrade_manager(_upgrade_manager)
	_upgrade_manager.start_upgrade(_config, manifest)

func _start_rollback() -> void:
	_ui.show_rollback_view()

	var rollback_dir = _cli.rollback_dir
	if rollback_dir == "":
		_ui._status_label.text = "Failed"
		_ui._detail_label.text = "No rollback directory specified"
		return

	_config.install_dir = rollback_dir
	var managed_files: PackedStringArray = [_config.exe_name, _config.pck_name]
	var err = RollbackManager.restore_backups(rollback_dir, managed_files)
	if err == OK:
		_ui._status_label.text = "Success!"
		_ui._detail_label.text = "Rolled back to previous version."
		_ui._result_icon.text = "OK"
		_ui._result_icon.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		_ui._result_icon.visible = true
	else:
		_ui._status_label.text = "Failed"
		_ui._detail_label.text = "Rollback failed. Backup files may be missing."
		_ui._result_icon.text = "!"
		_ui._result_icon.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		_ui._result_icon.visible = true

func _on_cancel() -> void:
	if _upgrade_manager:
		_upgrade_manager.cancel()
	else:
		get_tree().quit()
