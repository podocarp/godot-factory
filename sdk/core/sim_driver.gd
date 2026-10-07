class_name SimDriver
extends Node
# Fixed-step simulation clock. Games put their deterministic logic in
# `ticked.emit(tick, dt)` handlers instead of _process, so replays/tests are
# frame-rate independent (FACTORY.md rule 5). `simulate()` lets tests advance
# virtual time without waiting for real physics frames.

signal ticked(tick: int, dt: float)

@export var tick_rate: float = 60.0:
	set(v):
		tick_rate = maxf(1.0, v)
@export var enabled: bool = true
## Seed for the shared gameplay RNG. Reseeding restarts the sequence, so a test
## can replay identical "random" behavior.
@export var rng_seed: int = 0xC0FFEE:
	set(v):
		rng_seed = v
		rng.seed = v

var tick: int = 0
var rng := RandomNumberGenerator.new()
var _acc: float = 0.0

func _init() -> void:
	rng.seed = rng_seed

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	# Clamp catch-up so a stalled frame can't spiral into unbounded ticks.
	_acc += minf(delta, 0.25)
	var step := 1.0 / tick_rate
	var guard := 0
	while _acc >= step and guard < 1000:
		_acc -= step
		tick += 1
		ticked.emit(tick, step)
		guard += 1

## Advance `elapsed` seconds of virtual time synchronously (tests, replays).
func simulate(elapsed: float) -> void:
	var step := 1.0 / tick_rate
	var n := int(elapsed / step)
	for _i in n:
		tick += 1
		ticked.emit(tick, step)

## Reseed and zero the clock for a deterministic replay.
func reset(new_seed: int = -1) -> void:
	if new_seed >= 0:
		rng_seed = new_seed
	rng.seed = rng_seed
	tick = 0
	_acc = 0.0
