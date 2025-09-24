extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var jump_audio = $JumpAudioStreamPlayer
@onready var death_timer = $DeathTimer
@onready var death_audio_player = $DeathAudioStreamPlayer

const SPEED = 500.0
const JUMP_VELOCITY = -700.0
const BOUNCE_VELOCITY = -400.0 
const DEATH_ROTATION_RADIANS = 0.05
#const DEATH_SCALEDOWN_RATE = 0.0008
const DEATH_SCALE_RATE = 0.99

var health := 1
var should_bounce := false

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Handle bouncing off enemy if requested
	if should_bounce:
		should_bounce = false
		velocity.y = BOUNCE_VELOCITY

	# If dead, continue death animation sequence
	if health <= 0:
		_death_animation()
	else:
		# Jump
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			jump_audio.play()
			velocity.y = JUMP_VELOCITY

		# Left/Right optionally flips sprite (-1/0/1)
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction < 0:
			animated_sprite.flip_h = true
		elif direction > 0:
			animated_sprite.flip_h = false

		# Move in the direction
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	# Check for hazard collisions (lava)
	if health > 0:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider.is_in_group("hazards"):
				die()
				break

func _death_animation() -> void:
	animated_sprite.rotate(DEATH_ROTATION_RADIANS)
	if animated_sprite.scale.x > 0:
		animated_sprite.scale.x *= DEATH_SCALE_RATE
	if animated_sprite.scale.y > 0:
		animated_sprite.scale.y *= DEATH_SCALE_RATE
# RIP
func die() -> void:
	if health <= 0: return
	health = 0
	death_audio_player.play()
	death_timer.start()
	
	# Replace the sprite with a death sprite
	var death_sprite_frames = SpriteFrames.new()
	death_sprite_frames.add_animation("death")
	var death_texture = load("res://assets/sprites/mariodead.png")
	death_sprite_frames.add_frame("death", death_texture)
	animated_sprite.sprite_frames = death_sprite_frames
	animated_sprite.scale = Vector2(0.12, 0.12)
	animated_sprite.play("death")

# Respawn after the DeathTimer runs
func _on_death_timer_timeout() -> void:
	get_tree().reload_current_scene()
	health = 1
	
func bounce_off_enemy():
	should_bounce = true
