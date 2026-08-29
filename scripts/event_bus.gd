# =============================================================================
#  EventBus.gd  (Autoload singleton)
#  A global signal hub so systems stay decoupled. Emit from anywhere,
#  connect from anywhere. Add new signals here as the game grows.
# =============================================================================
extends Node

# Gameplay
signal enemy_killed(world_pos: Vector2, score_value: int)
signal enemy_hit(world_pos: Vector2)
signal enemy_spawned(enemy: Node)
signal ally_collected(total_allies: int)
signal ally_spawned(ally: Node)
signal shot_fired(world_pos: Vector2)
signal weapon_fired(kind: String, world_pos: Vector2)   # special ally weapons
signal explosion(world_pos: Vector2)
signal health_pickup(world_pos: Vector2)

# Ally weapon selection (pick-on-collect)
signal selection_started
signal selection_ended

# Player
signal player_damaged(current_hp: float, max_hp: float)
signal player_died

# Meta / HUD
signal score_changed(score: int)
signal wave_changed(wave: int)
signal objective_changed(text: String)          # level-mode objective (e.g. countdown)
signal game_over(final_score: int, waves_survived: int)
signal level_completed(level: int, final_score: int)
signal game_won(final_score: int)
signal boss_wave(wave: int)
signal wave_cleared(wave: int)
signal game_restarted

# Juice hooks (FX layer listens to these)
signal request_screen_shake(strength: float)
signal request_hit_flash(world_pos: Vector2, color: Color)
