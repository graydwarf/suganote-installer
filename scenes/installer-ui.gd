# Main installer UI. Displays branded install/upgrade progress with dark theme.
# Binds to UpgradeManager signals for phase/progress updates.
extends Control

signal install_requested(install_dir: String)
signal cancel_requested()

var _config: InstallerConfig
var _upgrade_manager: UpgradeManager

# UI references
var _logo_rect: TextureRect
var _title_label: Label
var _status_label: Label
var _detail_label: Label
var _progress_bar: ProgressBar
var _action_button: Button
var _cancel_button: Button
var _browse_button: Button
var _path_edit: LineEdit
var _path_container: HBoxContainer
var _button_row: HBoxContainer
var _result_icon: Label
var _space_container: VBoxContainer
var _required_label: Label
var _available_label: Label
var _required_bytes: int = 0

func _ready() -> void:
	_build_ui()

# Configures the UI with the given InstallerConfig
func setup(config: InstallerConfig) -> void:
	_config = config
	if _logo_rect and config.logo_texture:
		_logo_rect.texture = config.logo_texture
	if _title_label:
		_title_label.text = config.app_name + " Installer"
	if _progress_bar:
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = config.accent_color
		fill_style.set_corner_radius_all(3)
		_progress_bar.add_theme_stylebox_override("fill", fill_style)
	if _path_edit:
		_path_edit.text = config.get_default_install_dir()

# Shows the first-install view with location picker
func show_install_view() -> void:
	_path_container.visible = true
	_action_button.text = "Install"
	_action_button.visible = true
	_cancel_button.visible = false
	_progress_bar.visible = false
	_status_label.text = "Choose install location:"
	_detail_label.text = ""
	_result_icon.visible = false
	_space_container.visible = _required_bytes > 0

# Shows the upgrade/progress view
func show_upgrade_view() -> void:
	_path_container.visible = false
	_action_button.visible = false
	_cancel_button.visible = true
	_progress_bar.visible = true
	_progress_bar.value = 0
	_status_label.text = "Preparing upgrade..."
	_detail_label.text = ""
	_result_icon.visible = false
	_space_container.visible = false

# Shows the rollback view
func show_rollback_view() -> void:
	_path_container.visible = false
	_action_button.visible = false
	_cancel_button.visible = false
	_progress_bar.visible = true
	_progress_bar.value = 0
	_status_label.text = "Restoring previous version..."
	_detail_label.text = ""
	_result_icon.visible = false
	_space_container.visible = false

# Binds to an UpgradeManager to receive progress updates
func bind_upgrade_manager(manager: UpgradeManager) -> void:
	_upgrade_manager = manager
	manager.phase_changed.connect(_on_phase_changed)
	manager.progress_updated.connect(_on_progress_updated)
	manager.upgrade_completed.connect(_on_upgrade_completed)

func _on_phase_changed(phase: UpgradeManager.Phase, detail: String) -> void:
	_status_label.text = detail
	match phase:
		UpgradeManager.Phase.DOWNLOADING:
			_progress_bar.visible = true
			_cancel_button.visible = true
		UpgradeManager.Phase.DONE:
			_cancel_button.visible = false
		UpgradeManager.Phase.FAILED, UpgradeManager.Phase.ROLLED_BACK:
			_cancel_button.visible = false

func _on_progress_updated(percent: float, status: String) -> void:
	_progress_bar.value = percent
	_detail_label.text = status

func _on_upgrade_completed(success: bool, message: String) -> void:
	_progress_bar.visible = false
	_cancel_button.visible = false

	if success:
		_result_icon.text = "✓"
		_result_icon.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		_status_label.text = "Success!"
		_detail_label.text = message

		# Auto-close after 3 seconds on success
		var timer = get_tree().create_timer(3.0)
		timer.timeout.connect(func(): get_tree().quit())
	else:
		_result_icon.text = "✕"
		_result_icon.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		_status_label.text = "Failed"
		_detail_label.text = message
		_detail_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.6))

		# Grow window to fit error detail
		var win = get_window()
		win.size = Vector2i(520, 320)

		# Show close button
		_action_button.text = "Close"
		_action_button.visible = true
		if not _action_button.pressed.is_connected(_on_close_pressed):
			_action_button.pressed.connect(_on_close_pressed)

	_result_icon.visible = true

func _build_ui() -> void:
	# Window setup
	var win = get_window()
	win.title = "Installer"
	win.size = Vector2i(520, 268)
	win.min_size = Vector2i(520, 200)
	win.max_size = Vector2i(520, 400)

	# Fill parent so children use full window width
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Root background
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main container
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Logo + Title row
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(header)

	_logo_rect = TextureRect.new()
	_logo_rect.custom_minimum_size = Vector2(64, 64)
	_logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_logo_rect)

	_title_label = Label.new()
	_title_label.text = "Installer"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	header.add_child(_title_label)

	# Status row: result icon + status label inline
	var status_row = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	vbox.add_child(status_row)

	_result_icon = Label.new()
	_result_icon.text = "OK"
	_result_icon.add_theme_font_size_override("font_size", 20)
	_result_icon.visible = false
	status_row.add_child(_result_icon)

	_status_label = Label.new()
	_status_label.text = "Preparing..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	status_row.add_child(_status_label)

	# Detail label (right after status so it's always visible)
	_detail_label = Label.new()
	_detail_label.text = ""
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_label.add_theme_font_size_override("font_size", 12)
	_detail_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_detail_label)

	# Install path row (for first install)
	_path_container = HBoxContainer.new()
	_path_container.add_theme_constant_override("separation", 8)
	_path_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_container.visible = false
	vbox.add_child(_path_container)

	_path_edit = LineEdit.new()
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.placeholder_text = "Install location..."
	var path_style = StyleBoxFlat.new()
	path_style.bg_color = Color(0.16, 0.16, 0.18)
	path_style.border_color = Color(0.3, 0.3, 0.35)
	path_style.set_border_width_all(1)
	path_style.set_corner_radius_all(4)
	path_style.set_content_margin_all(8)
	_path_edit.add_theme_stylebox_override("normal", path_style)
	_path_edit.text_changed.connect(func(_new_text: String): _update_available_space())
	_path_container.add_child(_path_edit)

	_browse_button = Button.new()
	_browse_button.tooltip_text = "Browse..."
	var icon_path = "res://assets/icons/folder-open.svg"
	if ResourceLoader.exists(icon_path):
		var folder_icon = load(icon_path)
		_browse_button.icon = folder_icon
		_browse_button.expand_icon = true
		_browse_button.custom_minimum_size = Vector2(36, 36)
	else:
		_browse_button.text = "..."
	_browse_button.pressed.connect(_on_browse_pressed)
	_apply_icon_button_style(_browse_button)
	_path_container.add_child(_browse_button)

	# Space info (required / available)
	_space_container = VBoxContainer.new()
	_space_container.add_theme_constant_override("separation", 4)
	_space_container.visible = false
	vbox.add_child(_space_container)

	_required_label = Label.new()
	_required_label.add_theme_font_size_override("font_size", 12)
	_required_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))
	_space_container.add_child(_required_label)

	_available_label = Label.new()
	_available_label.add_theme_font_size_override("font_size", 12)
	_available_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))
	_space_container.add_child(_available_label)

	# Button row (right after path input)
	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 12)
	_button_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(_button_row)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_apply_button_style(_cancel_button)
	_button_row.add_child(_cancel_button)

	_action_button = Button.new()
	_action_button.text = "Install"
	_action_button.visible = false
	_action_button.pressed.connect(_on_action_pressed)
	_apply_button_style(_action_button, true)
	_button_row.add_child(_action_button)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 24)
	_progress_bar.visible = false
	_progress_bar.show_percentage = false
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.18, 0.18, 0.2)
	bar_bg.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("background", bar_bg)
	vbox.add_child(_progress_bar)

	# (Detail label is added earlier, right after status row)

# Sets the required space from the version API and shows space info
func set_required_space(size_bytes: int) -> void:
	_required_bytes = size_bytes
	if _required_bytes > 0:
		_required_label.text = "Space required:  " + _format_bytes(_required_bytes)
		_update_available_space()
		_space_container.visible = _path_container.visible

# Updates the available space label based on the current install path
func _update_available_space() -> void:
	var path = _path_edit.text.strip_edges()
	if path == "":
		_available_label.text = "Space available:  —"
		return

	var free = _get_free_space(path)
	if free < 0:
		_available_label.text = "Space available:  —"
	else:
		_available_label.text = "Space available:  " + _format_bytes(free)
		if _required_bytes > 0 and free < _required_bytes:
			_available_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		else:
			_available_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))

# Returns free bytes on the drive of the given path, or -1 on failure
func _get_free_space(path: String) -> int:
	var drive = path.left(2) if path.length() >= 2 and path[1] == ":" else path.left(3)
	var output: Array = []
	var exit_code = OS.execute("powershell", ["-NoProfile", "-Command",
		"(Get-PSDrive " + drive[0] + ").Free"], output)
	if exit_code != 0 or output.is_empty():
		return -1
	var text = output[0].strip_edges()
	if text.is_valid_int():
		return text.to_int()
	return -1

static func _format_bytes(bytes: int) -> String:
	if bytes < 1024:
		return str(bytes) + " B"
	elif bytes < 1048576:
		return "%.1f KB" % (float(bytes) / 1024.0)
	elif bytes < 1073741824:
		return "%.1f MB" % (float(bytes) / 1048576.0)
	else:
		return "%.1f GB" % (float(bytes) / 1073741824.0)

func _apply_icon_button_style(button: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.22, 0.26)
	normal.border_color = Color(0.3, 0.35, 0.45, 0.5)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(6)
	button.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	hover.bg_color = Color(0.25, 0.27, 0.32)
	button.add_theme_stylebox_override("hover", hover)

	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.15, 0.17, 0.2)
	button.add_theme_stylebox_override("pressed", pressed)

func _apply_button_style(button: Button, is_primary: bool = false) -> void:
	var normal = StyleBoxFlat.new()
	if is_primary:
		normal.bg_color = Color(0.2, 0.4, 0.7)
	else:
		normal.bg_color = Color(0.2, 0.22, 0.26)
	normal.border_color = Color(0.3, 0.35, 0.45, 0.5)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	if is_primary:
		hover.bg_color = Color(0.25, 0.45, 0.75)
	else:
		hover.bg_color = Color(0.25, 0.27, 0.32)
	button.add_theme_stylebox_override("hover", hover)

	var pressed = normal.duplicate()
	if is_primary:
		pressed.bg_color = Color(0.15, 0.35, 0.65)
	else:
		pressed.bg_color = Color(0.15, 0.17, 0.2)
	button.add_theme_stylebox_override("pressed", pressed)

func _on_browse_pressed() -> void:
	# Use native OS folder picker (opens as a separate system window)
	var _dialog = DisplayServer.file_dialog_show(
		"Choose Install Location",
		_path_edit.text if _path_edit.text != "" else OS.get_environment("LOCALAPPDATA"),
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_DIR,
		PackedStringArray(),
		func(status: bool, selected: PackedStringArray, _idx: int):
			if status and selected.size() > 0:
				_path_edit.text = selected[0]
				_update_available_space()
	)

func _on_action_pressed() -> void:
	if _action_button.text == "Close":
		get_tree().quit()
		return

	if _action_button.text == "Install":
		var install_dir = _path_edit.text.strip_edges()
		if install_dir == "":
			_detail_label.text = "Please choose an install location."
			return
		install_requested.emit(install_dir)

func _on_cancel_pressed() -> void:
	cancel_requested.emit()

func _on_close_pressed() -> void:
	get_tree().quit()
