# =============================================================================
#  fx.gd  —  listens to EventBus juice signals and spawns Effect instances.
#  Keeps all the "feel" in one place so gameplay code stays clean.
# =============================================================================
extends Node2D

const EffectScript := preload("res://scripts/effect.gd")

func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.request_hit_flash.connect(_on_hit_flash)

func _on_enemy_killed(world_pos: Vector2, _score: int) -> void:
	var e := EffectScript.new()
	add_child(e)
	e.global_position = world_pos
	e.burst(Config.COL_ENEMY)

func _on_hit_flash(world_pos: Vector2, color: Color) -> void:
	var e := EffectScript.new()
	add_child(e)
	e.global_position = world_pos
	e.spark(color)
