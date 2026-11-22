class_name PortraitDance
extends RefCounted
## What a portrait does while they dance, as when their quest is done: on every beat of
## the music the head bounces, and it rocks from side to side over two beats with the body
## swaying the other way. Without music it keeps the music's tempo by itself. The
## [AlienPortrait] it belongs to shows [member amount] as joy and adds [member bounce],
## [member roll] and [member body_roll] to the head and the body.

## How fast the dance comes up and goes away, per second.
const SHOW_SPEED := 4.0
## How high the head bounces on a beat, in the model's units.
const BOUNCE := 0.04
## How far the head and the body rock to either side, in radians.
const ROLL := 0.22
const BODY_ROLL := 0.08

## Whether they dance now. The dance eases out once they stop.
var dancing := false
## How far into the dance they are this frame, from 0 to 1.
var amount := 0.0
## How far the head lifts, and how far the head and the body tip to their right, this frame.
var bounce := 0.0
var roll := 0.0
var body_roll := 0.0

var _time := 0.0


## Moves the dance on by [param delta] seconds. With [param motion] 0, as under Reduce
## motion, it only shows on the face.
func advance(delta: float, motion: float) -> void:
	_time += delta
	amount = move_toward(amount, 1.0 if dancing else 0.0, delta * SHOW_SPEED)
	# Where they are in two beats of the music, from 0 to 1, so the moves land on its beat.
	var bar := 60.0 / Audio.MUSIC_BPM * 2.0
	var to_beat := Audio.seconds_to_beat(2.0)
	var into := 1.0 - to_beat / bar if to_beat > 0.0 else fposmod(_time / bar, 1.0)
	var strength := ease(amount, -2.0) * motion
	bounce = absf(sin(into * TAU)) * BOUNCE * strength
	var rock := cos(into * TAU)
	roll = rock * ROLL * strength
	body_roll = -rock * BODY_ROLL * strength
