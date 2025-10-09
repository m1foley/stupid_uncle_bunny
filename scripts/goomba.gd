extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var squish_audio_player = $"../../SquishAudioStreamPlayer"
@onready var jump_timer: Timer
@onready var spawn_timer: Timer
@onready var refractory_timer: Timer
@onready var collision_shape = $CollisionShape2D
@onready var head_area = $HeadArea
@onready var body_area = $BodyArea
@onready var player = $"../../Mario"
@onready var springboard_bossgoomba = $"../../Items/SpringboardBossGoomba"

const WALKING_SPEED = 50.0
const ACTIVATION_RANGE = 500.0
const BOSS_ACTIVATION_RANGE = 1000.0
const SQUISHED_SECS = 0.4
const INVINCIBILITY_KNOCKBACK_SECS = 1.0
const INVINCIBILITY_KNOCKBACK_X_SPEED_RANGE = Vector2(-250, 250)
const INVINCIBILITY_KNOCKBACK_Y_SPEED_RANGE = Vector2(-500, -50)
const INVINCIBILITY_KNOCKBACK_ROTATION_RANGE = Vector2(-1.1, 1.1)
const BOSS_JUMP_SPEED = -1000.0
const BOSS_JUMP_INTERVAL = 10.0
const BOSS_REFRACTORY_DURATION = 3
const BOSS_HEALTH = 7
const BOSS_DEATH_ROTATION_RADIANS = 0.05
const BOSS_DEATH_SCALE_RATE = 0.99
const BOSS_DEATH_SECS = 10
const BOSS_SPAWN_INTERVAL = 7
const BOSS_SPAWN_COUNT = 3
const BOSS_SPAWN_VELOCITY_X_RANGE = Vector2(100, 800)
const BOSS_SPAWN_VELOCITY_Y_RANGE = Vector2(-900, -1300)
const GOOMBA_SCENE = preload("res://scenes/goomba.tscn")
const WATER_MAX_SPEED = 	30.0

var direction: int = 1
var health: int
var invincibility_knocked_back: bool = false
var invincibility_knockback_rotation: float = 0.0
var refractory_tween: Tween
var active: bool = false
var activation_range: float
var initial_global_position: Vector2
var jumping: bool = false
var in_water: bool = false

func _ready():
	if is_in_group("bossgoomba"):
		initial_global_position = global_position
		# Don't interact on layer 1 because we bump into the spawned goombas
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		health = BOSS_HEALTH
		activation_range = BOSS_ACTIVATION_RANGE
		jump_timer = Timer.new()
		jump_timer.wait_time = BOSS_JUMP_INTERVAL
		jump_timer.autostart = false # Don't start until activated
		jump_timer.timeout.connect(_on_jump_timer_timeout)
		add_child(jump_timer)
		spawn_timer = Timer.new()
		spawn_timer.wait_time = BOSS_SPAWN_INTERVAL
		spawn_timer.autostart = false # Don't start until activated
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		add_child(spawn_timer)
	else:
		health = 1
		activation_range = ACTIVATION_RANGE

func _physics_process(delta: float) -> void:
	# Wait until close to player
	if !active && !_activate_if_close_to_player(): return

	# Apply gravity
	var apply_gravity
	if is_in_group("bossgoomba"):
		apply_gravity = jumping || health <= 0
	else:
		apply_gravity = !is_on_floor()
	if apply_gravity:
		velocity += get_gravity() * delta
		# Cap vertical velocity in water
		if in_water: velocity.y = min(velocity.y, WATER_MAX_SPEED)
		
	if invincibility_knocked_back:
		animated_sprite.rotate(invincibility_knockback_rotation)
	elif health > 0:	
		if !is_in_group("bossgoomba"):
			if _is_chucked_spawn():
				# slow down spawned goombas when they hit the floor
				if is_on_floor() && velocity.x > WALKING_SPEED:
					velocity.x = WALKING_SPEED
			else:
				# Walk
				velocity.x = direction * WALKING_SPEED
	# If dead boss, continue death animation sequence
	elif is_in_group("bossgoomba"):
		_boss_death_animation()

	move_and_slide()	
	
	# bossgoomba doesn't interact on layer 1, so we have to stop the jump ourselves
	if is_in_group("bossgoomba") && jumping && global_position.y >= initial_global_position.y:
		global_position.y = initial_global_position.y
		velocity.y = 0
		jumping = false

	# Turn around when hit object
	if is_on_wall():
		direction *= -1

func _is_chucked_spawn() -> bool:
	return is_in_group("spawn") && velocity.x >= BOSS_SPAWN_VELOCITY_X_RANGE.x

# Activate when player is close
func _activate_if_close_to_player() -> bool:
	if active: return true
	active = is_in_group("spawn") || global_position.distance_to(player.global_position) <= activation_range
	if active:
		animated_sprite.play("walk")
		if is_in_group("bossgoomba"):
			jump_timer.start()
			spawn_timer.start()
	return active

# Being squished
func _on_head_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") && health > 0 && body.health > 0:
		if is_in_group("bossgoomba"):
			# XXX
			# Boss & player can't touch each other 
			head_area.set_collision_mask_value(3, false)
			body_area.set_collision_mask_value(3, false)
			
			if health > 1:
				health -= 1
				# Refactory visual effects
				refractory_tween = create_tween()
				refractory_tween.set_loops()
				animated_sprite.modulate = Color.RED
				refractory_tween.tween_property(animated_sprite, "modulate:a", 0.4, 0.1)
				refractory_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.1)
				# Refactory timer
				refractory_timer = Timer.new()
				refractory_timer.wait_time = BOSS_REFRACTORY_DURATION
				refractory_timer.autostart = true
				refractory_timer.timeout.connect(_on_refractory_timer_timeout)
				add_child(refractory_timer)
				# Bounce player
				body.bounce_off_enemy()
			else:
				_die(body)
		else:
			_die(body)

# Body collisions
func _on_body_area_body_entered(body: Node2D) -> void:
	if health <= 0: return
	# Collision with player
	if body.is_in_group("player"):
		if body.invincible:
			_die(body)
		elif body.health > 0:
			body.die()
	# Falling on lava
	elif body.is_in_group("hazards"):
		_die(body)
	# Entering water
	elif body.is_in_group("water"):
		in_water = true
		create_tween().tween_property(animated_sprite, "modulate:a", 0.2, 0.1)

func _die(body: Node2D) -> void:
	if health <= 0: return
	health = 0
	if body.is_in_group("player"):
		if body.invincible:
			invincibility_knocked_back = true
		else:
			squish_audio_player.play()
			body.bounce_off_enemy()
	
	if invincibility_knocked_back:
		# Disable all collisions while flying away
		set_collision_layer(0)
		set_collision_mask(0)
		# Apply invincibility knockback values
		velocity.x = randf_range(INVINCIBILITY_KNOCKBACK_X_SPEED_RANGE.x, INVINCIBILITY_KNOCKBACK_X_SPEED_RANGE.y)
		velocity.y = randf_range(INVINCIBILITY_KNOCKBACK_Y_SPEED_RANGE.x, INVINCIBILITY_KNOCKBACK_Y_SPEED_RANGE.y)
		invincibility_knockback_rotation = randf_range(INVINCIBILITY_KNOCKBACK_ROTATION_RANGE.x, INVINCIBILITY_KNOCKBACK_ROTATION_RANGE.y)
	elif is_in_group("bossgoomba"):
		jump_timer.stop()
		spawn_timer.stop()
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
	else:
		animated_sprite.play("squished")

	var disappear_await_time: float
	if is_in_group("bossgoomba"):
		disappear_await_time = BOSS_DEATH_SECS
	elif invincibility_knocked_back:
		disappear_await_time = INVINCIBILITY_KNOCKBACK_SECS
	else:
		disappear_await_time = SQUISHED_SECS
 
	await get_tree().create_timer(disappear_await_time).timeout
	# springboard appears when bossgoomba dies
	if is_in_group("bossgoomba"): springboard_bossgoomba.enable()
	queue_free()

func _on_body_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("water"):
		in_water = false
		create_tween().tween_property(animated_sprite, "modulate:a", 1.0, 0.1)

func _on_jump_timer_timeout() -> void:
	velocity.y = BOSS_JUMP_SPEED
	jumping = true

func _on_spawn_timer_timeout() -> void:
	for i in BOSS_SPAWN_COUNT:
		await get_tree().create_timer(0.1).timeout
		_spawn_goomba()

func _spawn_goomba() -> void:
	var spawn = GOOMBA_SCENE.instantiate()
	spawn.add_to_group("spawn")
	spawn.global_position = self.global_position
	spawn.velocity.x = randf_range(BOSS_SPAWN_VELOCITY_X_RANGE.x, BOSS_SPAWN_VELOCITY_X_RANGE.y)
	spawn.velocity.y = randf_range(BOSS_SPAWN_VELOCITY_Y_RANGE.x, BOSS_SPAWN_VELOCITY_Y_RANGE.y)
	add_sibling(spawn)

func _on_refractory_timer_timeout() -> void:
	refractory_tween.kill()
	animated_sprite.modulate = Color.WHITE
	# Boss & player can touch each other
	head_area.set_collision_mask_value(3, true)
	body_area.set_collision_mask_value(3, true)

func _boss_death_animation() -> void:
	animated_sprite.rotate(BOSS_DEATH_ROTATION_RADIANS)
	scale.x *= BOSS_DEATH_SCALE_RATE
	scale.y *= BOSS_DEATH_SCALE_RATE
