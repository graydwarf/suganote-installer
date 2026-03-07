# Queries the Supabase edge function for the latest version info.
# Used during first install to find what to download.
class_name VersionFetcher
extends Node

signal version_fetched(info: Dictionary)
signal version_fetch_failed(error: String)

var _http_request: HTTPRequest

# Fetches the latest version info from the version-check endpoint.
func fetch_latest(url: String, api_key: String) -> void:
	if _http_request:
		_http_request.queue_free()

	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"apikey: " + api_key,
		"Authorization: Bearer " + api_key
	]

	# No ?since= param -> returns the latest version
	var err = _http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		version_fetch_failed.emit("Failed to start version check: error " + str(err))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		version_fetch_failed.emit("Version check failed: HTTPRequest result " + str(result))
		return

	if response_code != 200:
		version_fetch_failed.emit("Version check failed: HTTP " + str(response_code))
		return

	var json = JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		version_fetch_failed.emit("Failed to parse version response")
		return

	var data = json.data
	if not data is Dictionary:
		version_fetch_failed.emit("Invalid version response format")
		return

	# Validate required fields
	var required = ["current_version", "download_url"]
	for field in required:
		if not data.has(field):
			version_fetch_failed.emit("Version response missing field: " + field)
			return

	# Normalize into standard format
	var info: Dictionary = {
		"version": data.get("current_version", ""),
		"download_url": data.get("download_url", ""),
		"checksum_sha256": data.get("checksum_sha256", ""),
		"file_size_bytes": data.get("file_size_bytes", 0),
		"release_date": data.get("release_date", ""),
		"release_notes": data.get("release_notes", ""),
	}

	version_fetched.emit(info)
