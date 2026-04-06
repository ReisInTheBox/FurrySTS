class_name ContentLoader
extends RefCounted

const GENERATED_ROOT := "res://content/generated"
const CSV_ROOT := "res://content/csv"

func load_rows(table_name: String) -> Array[Dictionary]:
    var generated := _load_generated(table_name)
    if not generated.is_empty():
        return generated
    return _load_csv(table_name)

func find_row_by_id(table_name: String, row_id: String) -> Dictionary:
    for row in load_rows(table_name):
        if String(row.get("id", "")) == row_id:
            return row
    return {}

func _load_generated(table_name: String) -> Array[Dictionary]:
    var path := GENERATED_ROOT.path_join(table_name + ".json")
    if not FileAccess.file_exists(path):
        return []
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return []
    var text := f.get_as_text()
    f.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return []
    var rows_any: Variant = parsed.get("rows", [])
    if typeof(rows_any) != TYPE_ARRAY:
        return []
    var out: Array[Dictionary] = []
    for row_any in rows_any:
        if typeof(row_any) == TYPE_DICTIONARY:
            out.append(row_any)
    return out

func _load_csv(table_name: String) -> Array[Dictionary]:
    var path := CSV_ROOT.path_join(table_name + ".csv")
    if not FileAccess.file_exists(path):
        return []
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return []
    var text := f.get_as_text()
    f.close()
    var lines := text.split("\n", false)
    if lines.is_empty():
        return []
    var headers := lines[0].strip_edges().split(",", false)
    var out: Array[Dictionary] = []
    for i in range(1, lines.size()):
        var line := lines[i].strip_edges()
        if line == "":
            continue
        var cols := line.split(",", false)
        var row: Dictionary = {}
        for c in range(headers.size()):
            var key := headers[c].strip_edges()
            var value := cols[c].strip_edges() if c < cols.size() else ""
            row[key] = value
        out.append(row)
    return out
