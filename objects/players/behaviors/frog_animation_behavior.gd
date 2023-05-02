extends ByNodeScript

const smoke_effect = preload("res://engine/objects/effects/smoke/smoke.tscn")

var player: Player
var suit: PlayerSuit
var sprite: AnimatedSprite2D


func _ready() -> void:
	player = node as Player
	suit = player.suit as PlayerSuit
	sprite = player.sprite as AnimatedSprite2D
	
	# Connect animation signals for the current powerup
	player.suit_appeared.connect(_suit_appeared)
	player.swam.connect(_swam)
	player.shot.connect(_shot)
	player.invinciblized.connect(_invincible)
	
	sprite.animation_looped.connect(_sprite_loop)
	sprite.animation_finished.connect(_sprite_finish)


func _physics_process(delta: float) -> void:
	delta = player.get_physics_process_delta_time()
	# node.suit.extra_vars.p_flying
	_animation_process(delta)


#= Connected
func _suit_appeared() -> void:
	if !sprite: return
	NodeCreator.prepare_2d(smoke_effect, sprite).create_2d(true).bind_global_transform()
	
	sprite.visible = false
	await player.get_tree().create_timer(0.3, false, true).timeout
	if !sprite: return
	sprite.visible = true
	sprite.modulate.a = 1

func _swam() -> void:
	if !sprite: return
	if sprite.animation in [&"swim", &"swim_up", &"swim_down"]:
		sprite.frame = 0
		sprite.play()

func _shot() -> void:
	if !sprite: return
	sprite.play(&"attack")

func _invincible(duration: float) -> void:
	if !sprite: return
	sprite.modulate.a = 1
	Effect.flash(sprite, duration)

func _sprite_loop() -> void:
	if !sprite: return
	#match sprite.animation:
	#	&"swim": sprite.frame = sprite.sprite_frames.get_frame_count(sprite.animation) - 2

func _sprite_finish() -> void:
	if !sprite: return
	if sprite.animation == &"attack": sprite.play(&"default")


func _animation_process(delta: float) -> void:
	if !sprite: return
	
	if player.direction != 0:
		sprite.flip_h = (player.direction < 0)
	sprite.speed_scale = 1
	
	# Non-warping
	if player.warp == Player.Warp.NONE:
		#if sprite.animation in [&"attack"]: return
		if player.is_underwater:
			if player.up_down > 0 && player.left_right == 0:
				sprite.flip_h = false
				if sprite.animation == &"swim_down": return
				sprite.animation = &"swim_down"
				sprite.frame = 2
			elif player.up_down < 0 && player.left_right == 0:
				sprite.flip_h = false
				if sprite.animation == &"swim_up": return
				sprite.animation = &"swim_up"
				sprite.frame = 2
			else:
				if sprite.animation == &"swim": return
				sprite.animation = &"swim"
				sprite.frame = 2
		elif player.is_on_floor():
			if player.speed.x != 0:
				sprite.play(&"walk")
				sprite.speed_scale = 1
			else:
				sprite.play(&"default")
			#if player.is_crouching:
			#	sprite.play(&"default")
		else:
			sprite.play(&"jump")
	# Warping
	else:
		match player.warp_dir:
			Player.WarpDir.UP:
				sprite.play(&"jump")
			Player.WarpDir.DOWN:
				sprite.play(&"default")
			Player.WarpDir.LEFT, Player.WarpDir.RIGHT:
				player.direction = -1 if player.warp_dir == Player.WarpDir.LEFT else 1
				sprite.play(&"walk")
				sprite.speed_scale = 2
	
	if player.completed && player.is_on_floor() && sprite.animation == &"walk":
		sprite.speed_scale = 2
