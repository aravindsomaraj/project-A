class_name SurfaceTransition
extends RefCounted

var active := false
var elapsed := 0.0
var duration := 0.25
var cooldown_left := 0.0
var source_sign := -1.0

func begin(sign_value: float, seconds: float) -> bool:
	if active or cooldown_left > 0.0:
		return false
	source_sign = sign_value
	duration = maxf(seconds, 0.01)
	elapsed = 0.0
	active = true
	return true

func advance(delta: float, cooldown: float) -> bool:
	if not active:
		cooldown_left = maxf(0.0, cooldown_left - delta)
		return false
	elapsed += delta
	if elapsed >= duration:
		active = false
		cooldown_left = maxf(0.0, cooldown - (elapsed - duration))
		return true
	return false

func weight() -> float:
	return smoothstep(0.0, 1.0, clampf(elapsed / duration, 0.0, 1.0))

