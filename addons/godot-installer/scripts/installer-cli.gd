# Parses command-line arguments to determine installer mode.
class_name InstallerCLI
extends RefCounted

enum Mode {
	FIRST_INSTALL,
	UPGRADE,
	ROLLBACK
}

var mode: Mode = Mode.FIRST_INSTALL
var manifest_path: String = ""
var rollback_dir: String = ""

# Parses OS.get_cmdline_args() and sets mode + associated paths.
func parse() -> void:
	var args = OS.get_cmdline_args()

	var i = 0
	while i < args.size():
		match args[i]:
			"--upgrade":
				mode = Mode.UPGRADE
				if i + 1 < args.size():
					manifest_path = args[i + 1]
					i += 1
			"--rollback":
				mode = Mode.ROLLBACK
				if i + 1 < args.size():
					rollback_dir = args[i + 1]
					i += 1
			"--install":
				mode = Mode.FIRST_INSTALL
		i += 1

# Returns a human-readable description of the parsed mode
func get_mode_description() -> String:
	match mode:
		Mode.FIRST_INSTALL:
			return "First Install"
		Mode.UPGRADE:
			return "Upgrade (manifest: " + manifest_path + ")"
		Mode.ROLLBACK:
			return "Emergency Rollback (dir: " + rollback_dir + ")"
	return "Unknown"
