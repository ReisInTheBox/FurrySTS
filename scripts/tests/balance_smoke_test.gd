class_name BalanceSmokeTest
extends RefCounted

func run(loader, heroes: Array, strict_balance_gate: bool, simulate_once: Callable) -> bool:
	var all_ok := true
	var hero_win_rates: Dictionary = {}
	for hero_any in heroes:
		var hero := String(hero_any)
		var wins := 0
		var turns_total := 0
		for i in range(100):
			var res: Dictionary = simulate_once.call(100000 + i, hero, loader)
			if String(res["winner"]) == hero:
				wins += 1
			turns_total += int(res["turns"])
		var win_rate := float(wins) / 100.0
		var avg_turns := float(turns_total) / 100.0
		hero_win_rates[hero] = win_rate
		print("[SMOKE][BALANCE] hero=", hero, " win_rate=", win_rate, " avg_turns=", avg_turns)
		if win_rate < 0.40 or win_rate > 0.60:
			if strict_balance_gate:
				push_error("Win-rate out of target for " + hero + ": " + str(win_rate))
				all_ok = false
			else:
				push_warning("Win-rate out of target for " + hero + ": " + str(win_rate))
		if avg_turns < 4.8 or avg_turns > 10.8:
			if strict_balance_gate:
				push_error("Avg turns out of target for " + hero + ": " + str(avg_turns))
				all_ok = false
			else:
				push_warning("Avg turns out of target for " + hero + ": " + str(avg_turns))

	var min_rate := 1.0
	var max_rate := 0.0
	for hero_any in heroes:
		var hero := String(hero_any)
		var r := float(hero_win_rates.get(hero, 0.0))
		min_rate = min(min_rate, r)
		max_rate = max(max_rate, r)
	if (max_rate - min_rate) > 0.12:
		if strict_balance_gate:
			push_error("Hero win-rate spread too high: " + str(max_rate - min_rate))
			all_ok = false
		else:
			push_warning("Hero win-rate spread too high: " + str(max_rate - min_rate))

	return all_ok
