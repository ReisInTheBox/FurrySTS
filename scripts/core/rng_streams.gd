class_name RngStreams
extends RefCounted

const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")

var rng_run: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_dice: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_ai: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(bundle: SeedBundleScript) -> void:
    rng_run.seed = bundle.run_seed
    rng_dice.seed = bundle.dice_seed
    rng_ai.seed = bundle.ai_seed

func roll_dice(min_value: int, max_value: int) -> int:
    return rng_dice.randi_range(min_value, max_value)

func ai_pick(max_exclusive: int) -> int:
    return rng_ai.randi_range(0, max_exclusive - 1)

func run_pick(max_exclusive: int) -> int:
    return rng_run.randi_range(0, max_exclusive - 1)
