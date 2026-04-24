class_name RunCatalog
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")

var _loader: ContentLoaderScript
var _nodes_by_pool: Dictionary = {}
var _events_by_id: Dictionary = {}
var _reward_ids_by_source: Dictionary = {}

func _init(loader: ContentLoaderScript) -> void:
	_loader = loader
	_build_cache()

func _build_cache() -> void:
	_nodes_by_pool.clear()
	_events_by_id.clear()
	_reward_ids_by_source.clear()

	for row_any in _loader.load_rows("run_nodes"):
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any
		var pool := String(row.get("pool", "start"))
		if not _nodes_by_pool.has(pool):
			_nodes_by_pool[pool] = []
		var rows: Array = _nodes_by_pool[pool]
		rows.append(row)
		_nodes_by_pool[pool] = rows

	for row_any in _loader.load_rows("events"):
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any
		var event_id := String(row.get("id", ""))
		if event_id != "":
			_events_by_id[event_id] = row

	for row_any in _loader.load_rows("run_rewards"):
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any
		var source := String(row.get("source_node_type", ""))
		var reward_id := String(row.get("reward_id", ""))
		if source == "" or reward_id == "":
			continue
		if not _reward_ids_by_source.has(source):
			_reward_ids_by_source[source] = []
		var reward_rows: Array = _reward_ids_by_source[source]
		for _i in range(max(1, int(row.get("weight", "1")))):
			reward_rows.append(reward_id)
		_reward_ids_by_source[source] = reward_rows

func nodes_for_pool(pool: String) -> Array[Dictionary]:
	if not _nodes_by_pool.has(pool):
		return []
	var out: Array[Dictionary] = []
	for row in _nodes_by_pool[pool]:
		out.append(row)
	return out

func event_by_id(event_id: String) -> Dictionary:
	if not _events_by_id.has(event_id):
		return {}
	return _events_by_id[event_id]

func reward_ids_for_source(source_node_type: String) -> Array[String]:
	if not _reward_ids_by_source.has(source_node_type):
		return []
	var out: Array[String] = []
	for reward_id_any in _reward_ids_by_source[source_node_type]:
		out.append(String(reward_id_any))
	return out
