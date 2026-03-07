# Configuration resource for the installer addon.
# Set app-specific values (name, exe, colors) and runtime values (paths, manifest).
class_name InstallerConfig
extends Resource

# --- App Identity (set by shell project) ---

@export var app_name: String = "MyApp"
@export var exe_name: String = "MyApp.exe"
@export var pck_name: String = "MyApp.pck"
@export var logo_texture: Texture2D
@export var accent_color: Color = Color(0.3, 0.6, 1.0)

# --- Version Check Endpoint ---

@export var version_check_url: String = ""
@export var version_check_api_key: String = ""

# --- Timeouts ---

@export var success_timeout: float = 30.0
@export var file_lock_timeout: float = 15.0
@export var poll_interval: float = 1.0

# --- Runtime values (set by main.gd at launch) ---

var install_dir: String = ""
var userdata_dir: String = ""
var manifest_path: String = ""

# Returns the default install directory for the app
func get_default_install_dir() -> String:
	var local_appdata = OS.get_environment("LOCALAPPDATA")
	if local_appdata == "":
		local_appdata = OS.get_environment("APPDATA")
	return local_appdata.replace("\\", "/").path_join(app_name)

# Returns the temp directory used during downloads
func get_temp_dir() -> String:
	return install_dir.path_join(".installer-temp")

# Returns the full path to the app executable
func get_exe_path() -> String:
	return install_dir.path_join(exe_name)

# Returns the full path to the app pck file
func get_pck_path() -> String:
	return install_dir.path_join(pck_name)
