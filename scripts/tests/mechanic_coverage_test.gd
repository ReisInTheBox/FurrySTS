class_name MechanicCoverageTest
extends RefCounted

func run(loader, heroes: Array, simulate_once: Callable) -> bool:
	var all_ok := true
	var per_hero_samples := 60
	for hero_any in heroes:
		var hero := String(hero_any)
		var overclock_events := 0
		var focus_events := 0
		var counter_events := 0
		var resonance_events := 0
		var style_bonus_events := 0
		for i in range(per_hero_samples):
			var seed_value := 900000 + (heroes.find(hero) * 2000) + i
			var res: Dictionary = simulate_once.call(seed_value, hero, loader)
			var entries: Array = res["entries"]
			for e_any in entries:
				var e = e_any
				var ev := String(e.event_type)
				if ev == "overclock_changed":
					overclock_events += 1
				elif ev == "focus_changed":
					focus_events += 1
				elif ev == "counter_attack":
					counter_events += 1
				elif ev == "dice_type_resonance":
					resonance_events += 1
				elif ev == "style_bonus":
					style_bonus_events += 1

		var avg_resonance := float(resonance_events) / float(per_hero_samples)
		print("[SMOKE][COVERAGE] hero=", hero, " resonance_avg=", avg_resonance, " style_bonus=", style_bonus_events, " overclock=", overclock_events, " focus=", focus_events, " counter=", counter_events)
		if avg_resonance < 0.35:
			push_error("Resonance density too low for " + hero + ": " + str(avg_resonance))
			all_ok = false
		if style_bonus_events <= 0:
			push_error("Style bonus never triggered for " + hero)
			all_ok = false

		if hero == "cyan_ryder" and overclock_events <= 0:
			push_error("Cyan overclock events not observed in coverage smoke.")
			all_ok = false
		if hero == "helios_windchaser" and focus_events <= 0:
			push_error("Helios focus events not observed in coverage smoke.")
			all_ok = false
		if hero == "umbral_draxx" and counter_events <= 0:
			push_error("Umbral counter events not observed in coverage smoke.")
			all_ok = false
	return all_ok
