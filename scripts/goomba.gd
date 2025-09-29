extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var squish_audio_player = $"../../SquishAudioStreamPlayer"
@onready var jump_timer: Timer
@onready var refractory_timer: Timer
@onready var collision_shape = $CollisionShape2D
@onready var head_area = $HeadArea
@onready var body_area = $BodyArea
@onready var player = $"../../Mario"

const SPEED = 50.0
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
const BOSS_HEALTH = 6
const BOSS_DEATH_ROTATION_RADIANS = 0.05
const BOSS_DEATH_SCALE_RATE = 0.99
const BOSS_DEATH_SECS = 10

var direction: int = 1
var health: int
var invincibility_knocked_back: bool = false
var invincibility_knockback_rotation: float = 0.0
var refractory_tween: Tween
var active: bool = false

func _ready():
	if is_in_group("bossgoomba"):
		set_collision_layer_value(1, false)
		health = BOSS_HEALTH
		jump_timer = Timer.new()
		jump_timer.wait_time = BOSS_JUMP_INTERVAL
		jump_timer.autostart = false # Don't start until activated
		jump_timer.timeout.connect(_on_jump_timer_timeout)
		add_child(jump_timer)
	else:
		health = 1

func _physics_process(delta: float) -> void:
	# Wait until close to player
	if !active && !_activate_if_close_to_player(): return

	# Apply gravity
	if !is_on_floor():
		velocity += get_gravity() * delta
		
	if invincibility_knocked_back:
		animated_sprite.rotate(invincibility_knockback_rotation)
	elif health > 0:	
		# Walk
		if !is_in_group("bossgoomba"):
			velocity.x = direction * SPEED
	# If dead boss, continue death animation sequence
	elif is_in_group("bossgoomba"):
		_boss_death_animation()

	move_and_slide()	
	# Turn around when hit object
	if is_on_wall():
		direction *= -1

# Activate when player is close
func _activate_if_close_to_player() -> bool:
	if active: return true
	if global_position.distance_to(player.global_position) <= ACTIVATION_RANGE:
		active = true
		animated_sprite.play("walk")
		if is_in_group("bossgoomba"): jump_timer.start()
	return active

# Being squished
func _on_head_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") && health > 0 && body.health > 0:
		if is_in_group("bossgoomba"):
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
	elif !is_in_group("bossgoomba"):
		animated_sprite.play("squished")

	var disappear_await_time: float
	if is_in_group("bossgoomba"):
		disappear_await_time = BOSS_DEATH_SECS
	elif invincibility_knocked_back:
		disappear_await_time = INVINCIBILITY_KNOCKBACK_SECS
	else:
		disappear_await_time = SQUISHED_SECS
 
	await get_tree().create_timer(disappear_await_time).timeout
	queue_free()

func _on_body_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("water"):
		create_tween().tween_property(animated_sprite, "modulate:a", 1.0, 0.1)

func _on_jump_timer_timeout() -> void:
	if health > 0 && is_on_floor():
		velocity.y = BOSS_JUMP_SPEED

func _on_refractory_timer_timeout() -> void:
	refractory_tween.kill()
	animated_sprite.modulate = Color.WHITE
	# Boss & player can touch each other
	head_area.set_collision_mask_value(3, true)
	body_area.set_collision_mask_value(3, true)

func _boss_death_animation() -> void:
	animated_sprite.rotate(BOSS_DEATH_ROTATION_RADIANS)
	animated_sprite.scale.x *= BOSS_DEATH_SCALE_RATE
	collision_shape.scale.x *= BOSS_DEATH_SCALE_RATE
	animated_sprite.scale.y *= BOSS_DEATH_SCALE_RATE
	collision_shape.scale.y *= BOSS_DEATH_SCALE_RATE
  
