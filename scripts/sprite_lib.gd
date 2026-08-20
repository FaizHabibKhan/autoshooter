# =============================================================================
#  SpriteLib.gd  (Autoload singleton)
#  Builds shared SpriteFrames (walk + death) for each character kind from the
#  spritesheets in res://art/, slicing each strip into frames with AtlasTexture.
#  One SpriteFrames per kind is shared by every instance (cheap).
#  Regenerate the art with: tools/make_sprites.py
# =============================================================================
extends Node

const FRAME := 128
const WALK_FRAMES := 6
const DEATH_FRAMES := 5
const WALK_FPS := 10.0
const DEATH_FPS := 12.0

var frames: Dictionary = {}   # kind (String) -> SpriteFrames

func _ready() -> void:
	var kinds := ["player", "ally", "zombie"]
	# One recolored soldier per ally weapon (art/ally_<weapon>_*.png).
	for w in Config.ALLY_WEAPONS:
		kinds.append("ally_" + w)
	for kind in kinds:
		frames[kind] = _build(kind)

func get_frames(kind: String) -> SpriteFrames:
	return frames.get(kind)

func _build(kind: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_add_anim(sf, "walk", "res://art/%s_walk.png" % kind, WALK_FRAMES, WALK_FPS, true)
	_add_anim(sf, "death", "res://art/%s_death.png" % kind, DEATH_FRAMES, DEATH_FPS, false)
	return sf

func _add_anim(sf: SpriteFrames, anim: String, sheet_path: String, count: int, fps: float, loop: bool) -> void:
	var tex: Texture2D = load(sheet_path)
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	if tex == null:
		return
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		sf.add_frame(anim, at)
