extends RefCounted

const TARGET_EXTENSIONS := {
	"gd": true,
	"csv": true,
	"json": true,
	"md": true
}

const SKIP_DIRS := {
	".git": true,
	".godot": true,
	"imported": true
}

func run() -> bool:
	var files: Array[String] = []
	var suspicious_tokens := _suspicious_tokens()
	_collect_files("res://", files)
	for path in files:
		var text := _read_text(path)
		for token in suspicious_tokens:
			if text.find(token) >= 0:
				push_error("Unreadable text marker " + _token_debug(token) + " found in " + path)
				return false
	return true

func _suspicious_tokens() -> Array[String]:
	return [
		String.chr(0xfffd),
		String.chr(0x95c2),
		String.chr(0x93ac),
		String.chr(0x95b8),
		String.chr(0x9207),
		String.chr(0x879f),
		String.chr(0x8b41),
		String.chr(0x7e3a),
		String.chr(0x00c3),
		String.chr(0x00c2),
		String.chr(0x00e2) + String.chr(0x20ac),
		"??" + "??"
	]

func _token_debug(token: String) -> String:
	var parts: Array[String] = []
	for i in range(token.length()):
		parts.append("U+" + ("%04X" % token.unicode_at(i)))
	return "[" + ",".join(parts) + "]"

func _collect_files(root: String, out: Array[String]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		push_error("Cannot open directory for readability scan: " + root)
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with(".") and name != "." and name != "..":
			continue
		var path := root.path_join(name)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(name):
				_collect_files(path, out)
			continue
		if TARGET_EXTENSIONS.has(path.get_extension().to_lower()):
			out.append(path)
	dir.list_dir_end()

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read file for readability scan: " + path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text
