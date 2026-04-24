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
		return false

	var varied := false
	for seed_value in [20260423, 20260424, 20260425]:
		var run_other := simulator.create_run(seed_value)
		if _route_ids(run_other["state"].route_nodes) != ids_a:
			varied = true
			break
	return varied

func _route_ids(nodes: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for node in nodes:
		out.append(String(node.get("id", "")))
	return out
