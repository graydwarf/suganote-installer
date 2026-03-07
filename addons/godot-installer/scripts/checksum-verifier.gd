# Verifies file integrity using SHA-256 checksums via Godot's HashingContext.
class_name ChecksumVerifier
extends RefCounted

const CHUNK_SIZE: int = 65536  # 64KB chunks

# Computes SHA-256 hash of a file. Returns hex string or empty on error.
static func compute_sha256(file_path: String) -> String:
	if not FileAccess.file_exists(file_path):
		push_error("ChecksumVerifier: File not found: " + file_path)
		return ""

	var ctx = HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		push_error("ChecksumVerifier: Failed to start hashing context")
		return ""

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("ChecksumVerifier: Cannot open file: " + file_path)
		return ""

	while not file.eof_reached():
		var chunk = file.get_buffer(CHUNK_SIZE)
		if chunk.size() > 0:
			if ctx.update(chunk) != OK:
				push_error("ChecksumVerifier: Hash update failed")
				return ""

	var hash_bytes = ctx.finish()
	return hash_bytes.hex_encode()

# Verifies a file matches the expected SHA-256 hash
static func verify_sha256(file_path: String, expected_hash: String) -> bool:
	var actual_hash = compute_sha256(file_path)
	if actual_hash == "":
		return false
	return actual_hash.to_lower() == expected_hash.to_lower()
