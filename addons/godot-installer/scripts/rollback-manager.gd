# Manages backup and restore of files during upgrades.
# Creates .backup copies before overwriting, restores on failure.
class_name RollbackManager
extends RefCounted

const BACKUP_SUFFIX: String = ".backup"

# Creates backup copies of the specified files in the directory.
# Returns OK on success, or an error code.
static func create_backups(dir_path: String, filenames: PackedStringArray) -> Error:
	for filename in filenames:
		var source = dir_path.path_join(filename)
		var backup = source + BACKUP_SUFFIX

		if not FileAccess.file_exists(source):
			continue  # Nothing to back up

		# Remove old backup if it exists
		if FileAccess.file_exists(backup):
			var err = DirAccess.remove_absolute(backup)
			if err != OK:
				push_error("RollbackManager: Failed to remove old backup: " + backup)
				return err

		var err = DirAccess.rename_absolute(source, backup)
		if err != OK:
			push_error("RollbackManager: Failed to create backup: " + source + " -> " + backup)
			return err

	return OK

# Restores backup files, overwriting current files.
# Returns OK on success, or an error code.
static func restore_backups(dir_path: String, filenames: PackedStringArray) -> Error:
	var last_error: Error = OK
	for filename in filenames:
		var target = dir_path.path_join(filename)
		var backup = target + BACKUP_SUFFIX

		if not FileAccess.file_exists(backup):
			continue  # No backup to restore

		# Remove the (possibly corrupt) new file
		if FileAccess.file_exists(target):
			var err = DirAccess.remove_absolute(target)
			if err != OK:
				push_error("RollbackManager: Failed to remove file for restore: " + target)
				last_error = err
				continue

		var err = DirAccess.rename_absolute(backup, target)
		if err != OK:
			push_error("RollbackManager: Failed to restore backup: " + backup + " -> " + target)
			last_error = err

	return last_error

# Removes backup files after a successful upgrade.
static func cleanup_backups(dir_path: String, filenames: PackedStringArray) -> Error:
	for filename in filenames:
		var backup = dir_path.path_join(filename) + BACKUP_SUFFIX
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
	return OK

# Finds all .backup files in a directory and returns the original filenames.
static func find_backup_files(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(BACKUP_SUFFIX):
			# Strip the .backup suffix to get the original filename
			result.append(file_name.substr(0, file_name.length() - BACKUP_SUFFIX.length()))
		file_name = dir.get_next()
	dir.list_dir_end()

	return result
