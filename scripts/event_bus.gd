# =============================================================================
#  EventBus.gd  (Autoload singleton)
#  A global signal hub so systems stay decoupled. Emit from anywhere,
#  connect from anywhere. Add new signals here as the game grows.
# =============================================================================
extends Node

# Gameplay
signal enemy_killed(world_pos: Vector2, score_value: int)
signal enemy_spawned(enemy: Node)
signal ally_collected(total_allies: int)
signal ally_spawned(ally: Node)

# Player
signal player_damaged(current_hp: float, max_hp: float)
signal player_died

# Meta / HUD
signal score_changed(score: int)
signal wave_changed(wave: int)
signal game_over(final_score: int, waves_survived: int)
signal game_restarted

# Juice hooks (FX layer listens to these)
signal request_screen_shake(strength: float)
signal request_hit_flash(world_pos: Vector2, color: Color)
