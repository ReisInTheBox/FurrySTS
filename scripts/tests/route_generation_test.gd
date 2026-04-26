class_name RouteGenerationTest
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const RunSimulatorScript = preload("res://scripts/run/run_simulator.gd")

func run() -> bool:
	var loader := ContentLoaderScript.new()
	var simulator := RunSimulatorScript.new(loader)
	var run_a := simulator.create_run(20260422)
	var run_b := simulator.create_run(20260422)
	var ids_a := _route_ids(run_a["state"].route_nodes)
	var ids_b := _route_ids(run_b["state"].route_nodes)
	if ids_a != ids_b:
		push_error("Route map generation is not deterministic for the same seed.")
		return false

	var run_other := simulator.create_run(20260423)
	if _route_ids(run_other["state"].route_nodes) == ids_a:
		push_error("Different seeds produced identical route maps.")
		return false

	if not _check_node_pool_variety(loader):
		return false
	if not _check_route_map_shape(run_a["state"].route_layers):
		return false
	return _check_route_map_distribution(simulator)

func _route_ids(nodes: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for node in nodes:
		out.append(String(node.get("route_node_uid", node.get("id", ""))))
	return out

func _check_node_pool_variety(loader: ContentLoaderScript) -> bool:
	var expected := ["battle", "elite", "event", "supply", "shop", "rest", "boss"]
	var seen := {}
	for row in loader.load_rows("run_nodes"):
		seen[String(row.get("node_type", ""))] = true
	for node_type in expected:
		if not seen.has(node_type):
			push_error("Run node pool missing node type: " + node_type)
			return false
	return true

func _check_route_map_shape(layers: Array) -> bool:
	if layers.size() != 13:
		push_error("Route map should have 13 layers, got " + str(layers.size()))
		return false
	var incoming := {}
	for i in range(layers.size()):
		var layer: Array = layers[i]
		var layer_index := i + 1
		if layer_index == 13:
			if layer.size() != 1:
				push_error("Boss layer should have exactly one node.")
				return false
			if String(Dictionary(layer[0]).get("node_type", "")) != "boss":
				push_error("Layer 13 must be boss.")
				return false
		else:
			if layer.size() < 2 or layer.size() > 4:
				push_error("Non-boss layer node count out of bounds at layer " + str(layer_index))
				return false
		for node_any in layer:
			var node: Dictionary = node_any
			var uid := String(node.get("route_node_uid", ""))
			if uid == "":
				push_error("Route node missing uid.")
				return false
			incoming[uid] = int(incoming.get(uid, 0))
			if layer_index == 1 and String(node.get("node_type", "")) != "battle":
				push_error("Layer 1 should be forced battle entries.")
				return false
			if layer_index < 13:
				var outgoing: Array = node.get("outgoing_uids", [])
				if outgoing.is_empty():
					push_error("Non-boss node missing outgoing edge: " + uid)
					return false
				for target_any in outgoing:
					var target_uid := String(target_any)
					incoming[target_uid] = int(incoming.get(target_uid, 0)) + 1
	for i in range(1, layers.size()):
		var layer: Array = layers[i]
		for node_any in layer:
			var node: Dictionary = node_any
			var uid := String(node.get("route_node_uid", ""))
			if int(incoming.get(uid, 0)) <= 0:
				push_error("Route node has no incoming edge: " + uid)
				return false
	return true

func _check_route_map_distribution(simulator: RunSimulatorScript) -> bool:
	var counts := {"battle": 0, "event": 0, "support": 0, "elite": 0, "boss": 0}
	for seed_value in range(20260500, 20260600):
		var run_bundle := simulator.create_run(seed_value, "cyan_ryder", 13)
		for node in run_bundle["state"].route_nodes:
			var node_type := String(node.get("node_type", ""))
			match node_type:
				"battle":
					counts["battle"] += 1
				"event":
					counts["event"] += 1
				"supply", "shop", "rest":
					counts["support"] += 1
				"elite":
					counts["elite"] += 1
				"boss":
					counts["boss"] += 1
	if int(counts["boss"]) != 100:
		push_error("Each generated map should contain exactly one boss.")
		return false
	if int(counts["elite"]) < 200 or int(counts["elite"]) > 400:
		push_error("Elite visibility should be around 2-4 per map, got total " + str(counts["elite"]))
		return false
	return int(counts["battle"]) > int(counts["event"]) and int(counts["support"]) > 0
