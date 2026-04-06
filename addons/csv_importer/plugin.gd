@tool
extends EditorPlugin

const CSV_ROOT := "res://content/csv"
const OUT_ROOT := "res://content/generated"

var _debounce_timer: SceneTreeTimer

func _enter_tree() -> void:
    add_tool_menu_item("CSV Importer/Rebuild Now", Callable(self, "_rebuild_all"))
    var fs := EditorInterface.get_resource_filesystem()
    if fs and not fs.filesystem_changed.is_connected(_on_filesystem_changed):
        fs.filesystem_changed.connect(_on_filesystem_changed)
    _rebuild_all()

func _exit_tree() -> void:
    remove_tool_menu_item("CSV Importer/Rebuild Now")
    var fs := EditorInterface.get_resource_filesystem()
    if fs and fs.filesystem_changed.is_connected(_on_filesystem_changed):
        fs.filesystem_changed.disconnect(_on_filesystem_changed)

func _on_filesystem_changed() -> void:
    if _debounce_timer != null:
        return
    _debounce_timer = get_tree().create_timer(0.2)
    await _debounce_timer.timeout
    _debounce_timer = null
    _rebuild_all()

func _rebuild_all() -> void:
    _ensure_dir(OUT_ROOT)
    var csv_files := _collect_csv_files(CSV_ROOT)
    for csv_file in csv_files:
        _compile_csv(csv_file)

func _collect_csv_files(root: String) -> Array[String]:
    var out: Array[String] = []
    var dir := DirAccess.open(root)
    if dir == null:
        return out

    dir.list_dir_begin()
    while true:
        var name := dir.get_next()
        if name == "":
            break
        if name.begins_with("."):
            continue
        var path := root.path_join(name)
        if dir.current_is_dir():
            out.append_array(_collect_csv_files(path))
        elif name.get_extension().to_lower() == "csv":
            out.append(path)
    dir.list_dir_end()
    return out

func _compile_csv(csv_path: String) -> void:
    var lines := _read_csv_lines(csv_path)
    if lines.is_empty():
        return

    var headers := lines[0].split(",", false)
    var rows: Array[Dictionary] = []
    for i in range(1, lines.size()):
        var line := lines[i].strip_edges()
        if line == "":
            continue
        var cols := line.split(",", false)
        var row := {}
        for c in range(headers.size()):
            var key := headers[c].strip_edges()
            var value := cols[c].strip_edges() if c < cols.size() else ""
            row[key] = value
        rows.append(row)

    var rel := csv_path.trim_prefix(CSV_ROOT + "/").trim_suffix(".csv")
    var out_dir := OUT_ROOT.path_join(rel.get_base_dir())
    _ensure_dir(out_dir)
    var out_path := OUT_ROOT.path_join(rel + ".json")
    var payload := {"source": csv_path, "row_count": rows.size(), "rows": rows}
    var file := FileAccess.open(out_path, FileAccess.WRITE)
    if file == null:
        push_error("CSV Importer failed to open output: " + out_path)
        return
    file.store_string(JSON.stringify(payload, "\t"))
    file.close()

func _read_csv_lines(path: String) -> PackedStringArray:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return PackedStringArray()
    var text := f.get_as_text()
    f.close()
    return text.split("\n", false)

func _ensure_dir(path: String) -> void:
    if DirAccess.dir_exists_absolute(path):
        return
    DirAccess.make_dir_recursive_absolute(path)
