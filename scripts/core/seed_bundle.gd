class_name SeedBundle
extends RefCounted

var master_seed: int
var run_seed: int
var dice_seed: int
var ai_seed: int

func _init(p_master_seed: int) -> void:
    master_seed = p_master_seed
    run_seed = _derive(master_seed, 0x11)
    dice_seed = _derive(master_seed, 0x23)
    ai_seed = _derive(master_seed, 0x37)

func _derive(base: int, salt: int) -> int:
    var mixed := int((base ^ salt) * 1103515245 + 12345)
    return abs(mixed)
