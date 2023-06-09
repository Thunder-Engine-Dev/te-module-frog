extends ByNodeScript

signal glided

var player: Player
var suit: PlayerSuit
var config: PlayerConfig

const jump_sound = preload("res://modules/frog/objects/players/prefabs/sounds/small_jump.wav")

var _has_jumped: bool
var jump_delay: float
var swim_delay: float


func _ready() -> void:
	player = node as Player
	suit = node.suit
	config = suit.physics_config
	player.underwater.got_into_water.connect(player.set.bind(&"is_underwater", true), CONNECT_REFERENCE_COUNTED)
	player.underwater.got_out_of_water.connect(player.set.bind(&"is_underwater", false), CONNECT_REFERENCE_COUNTED)


func _physics_process(delta: float) -> void:
	delta = player.get_physics_process_delta_time()
	# Control
	player.control_process()
	# Shape
	_shape_process()
	if player.warp != Player.Warp.NONE: return
	
	# Head
	_head_process()
	# Body
	_body_process()
	# Movement
	_movement_x(delta)
	_movement_y(delta)
	player.motion_process(delta)
	if player.is_on_wall():
		player.speed.x = 0


#= Movement
func _accelerate(to: float, acce: float, delta: float) -> void:
	player.speed.x = move_toward(player.speed.x, to * player.direction, abs(acce) * delta)


func _decelerate(dece: float, delta: float) -> void:
	_accelerate(0, dece, delta)


func _movement_x(delta: float) -> void:
	if player.is_crouching || player.left_right == 0 || player.completed:
		config.walk_deceleration = 312.5 if !player.is_on_floor() else 625.0
		_decelerate(config.walk_deceleration, delta)
		return
	if player.is_underwater:
		return
	if !player.is_on_floor():
		jump_delay = -0.05
	else:
		if jump_delay < 0:
			jump_delay += delta
			player.speed.x = 0
			return
		if player.speed.x == 0 && player.left_right == 0:
			jump_delay = 0
		jump_delay += delta
	# Initial speed
	if player.left_right != 0 && player.speed.x == 0:
		player.direction = player.left_right
		player.speed.x = player.direction * config.walk_initial_speed
	# Acceleration
	if player.left_right == player.direction:
		var max_speed: float
		max_speed = (config.walk_max_running_speed if player.running else config.walk_max_walking_speed)
		_accelerate(max_speed, config.walk_acceleration, delta)
		config.walk_acceleration = 312.5
		if player.is_on_floor():
			config.walk_acceleration = 675.0 if player.running else 468.75
				
			if jump_delay >= 0.45:
				player.speed.x = 0
				jump_delay = -0.15
				Audio.play_sound(jump_sound, player, false, {pitch = suit.sound_pitch})
	elif player.left_right == -player.direction:
		_decelerate(config.walk_turning_acce, delta)
		if player.speed.x == 0:
			player.direction *= -1


var swim_delayed: bool = false

func _movement_y(delta: float) -> void:
	if player.is_crouching && !ProjectSettings.get_setting("application/thunder_settings/player/jumpable_when_crouching", false):
		return
	if player.completed: return
	
	# Swimming
	if player.is_underwater:
		if player.is_underwater_out && player.jumping && player.up_down < 0:
			player.jump(config.swim_out_speed)
			return
		if swim_delay > 0:
			swim_delay += delta
			if !swim_delayed:
				swim_delayed = true
				player.swam.emit()
				Audio.play_sound(config.sound_swim, player, false, {pitch = suit.sound_pitch})
			if swim_delay > 0.8 / (1 + player.jumping):
				swim_delay = 0
				swim_delayed = false
		else:
			swim_delay = int(player.left_right || player.up_down) * 0.01
		if !player.left_right && !player.up_down:
			player.speed.y = min(player.speed.y, 25)
		else:
			player.speed.y = player.up_down * 125 * (1 + player.jumping * 1.1)
			player.speed.x = player.left_right * 125 * (1 + player.jumping * 1.25)
			player.direction = player.left_right
		if !player.left_right:
			player.speed.x = 0
	# Jumping
	else:
		swim_delay = 0
		# Normal Jumping
		if player.is_on_floor():
			if player.jumping > 0 && !_has_jumped:
				_has_jumped = true
				player.jump(config.jump_speed)
				Audio.play_sound(config.sound_jump, player, false, {pitch = suit.sound_pitch})
		# Jump Buffer
		elif player.jumping > 0 && player.speed.y < 0:
			var buff: float = config.jump_buff_dynamic if abs(player.speed.x) > 10 else config.jump_buff_static
			player.speed.y -= abs(buff) * delta
			
	if !player.jumping:
		_has_jumped = false



#= Shape
func _shape_process() -> void:
	var shaper: Shaper2D = suit.physics_shaper_crouch if player.is_crouching && player.warp == Player.Warp.NONE else suit.physics_shaper
	if !shaper: return
	shaper.install_shape_for(player.collision_shape)
	shaper.install_shape_for_caster(player.body)
	
	if player.collision_shape.shape is RectangleShape2D:
		player.head.position.y = player.collision_shape.position.y - player.collision_shape.shape.size.y / 2 - 2


#= Head
func _head_process() -> void:
	player.is_underwater_out = true
	for i in player.head.get_collision_count():
		var collider: Node2D = player.head.get_collider(i) as Node2D
		if collider && collider.is_in_group(&"#water"):
			player.is_underwater_out = false

#= Body
func _body_process() -> void:
	if !player.body.shape: return
	
	player.body.target_position = player.speed.normalized() * 4
	for i in player.body.get_collision_count():
		var collider: Node2D = player.body.get_collider(i) as Node2D
		if !is_instance_valid(collider):
			continue
		if !collider.has_node("EnemyAttacked"): return
		
		var enemy_attacked: Node = collider.get_node("EnemyAttacked")
		var result: Dictionary = enemy_attacked.got_stomped(player)
		if result.is_empty(): return
		if result.result == true:
			if player.jumping > 0:
				player.speed.y = -result.jumping_max * config.jump_stomp_multiplicator
			else:
				player.speed.y = -result.jumping_min * config.jump_stomp_multiplicator
		else:
			player.hurt(enemy_attacked.get_meta(&"stomp_tags", {}))
