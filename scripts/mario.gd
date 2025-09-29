extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var jump_audio = $JumpAudioStreamPlayer
@onready var death_timer = $DeathTimer
@onready var invincibility_timer = $InvincibilityTimer
@onready var invincibility_ending_timer = $InvincibilityEndingTimer
@onready var music_audio_player = $"../MusicAudioStreamPlayer"
@onready var death_audio_player = $DeathAudioStreamPlayer
@onready var invincibility_audio_player = $InvincibilityAudioStreamPlayer

const SPEED = 300.0
const JUMP_VELOCITY = -500.0
const BOUNCE_VELOCITY = -300.0 
const MAX_JUMPS = 2
const DEATH_ROTATION_RADIANS = 0.05
const DEATH_SCALE_RATE = 0.99

var health: int = 1
var should_bounce: bool = false
var jumps: int = 0
var invincible: bool = false
var invincible_ending: bool = false
var invincibility_tween: Tween
var in_water: bool = false
var jumping: bool = false

func _physics_process(delta: float) -> void:
	if is_on_floor():
		# Disable jumping animation if landed
		jumping = false
	else:
		# Apply gravity
		velocity += get_gravity() * delta

	# If dead, continue death animation sequence
	if health <= 0:
		_death_animation()
	else:
		# Handle bouncing off enemy if requested
		if should_bounce:
			jumps = 0
			velocity.y = BOUNCE_VELOCITY
			jumping = false
			should_bounce = false
			
		# Jump
		if Input.is_action_just_pressed("ui_accept"):
			if is_on_floor(): jumps = 0
			jumps += 1
			if jumps <= MAX_JUMPS || in_water:
				jump_audio.play()
				velocity.y = JUMP_VELOCITY
			jumping = !in_water

		# Left/Right optionally flips sprite (-1/0/1)
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction < 0:
			animated_sprite.flip_h = !in_water
			if in_water:animated_sprite.rotation_degrees = -90
		elif direction > 0:
			animated_sprite.flip_h = in_water
			if in_water: animated_sprite.rotation_degrees = 90
		
		# Set action sprite
		var animation : String
		if jumping:
			animation = "jumping"
		elif direction != 0:
			if in_water:
				animation = "swimming"
			else:
				animation = "running"
		else:
			animation = "idle"
		if animated_sprite.animation != animation:
			animated_sprite.play(animation)
			
		# Move in the direction
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _death_animation() -> void:
	animated_sprite.rotate(DEATH_ROTATION_RADIANS)
	animated_sprite.scale.x *= DEATH_SCALE_RATE
	animated_sprite.scale.y *= DEATH_SCALE_RATE

# RIP
func die() -> void:
	if health <= 0: return
	health = 0
	_stop_invincibility()
	music_audio_player.stop()
	death_audio_player.play()
	death_timer.start()
	
	# Replace the sprite with a death sprite
	var death_sprite_frames = SpriteFrames.new()
	death_sprite_frames.add_animation("death")
	var death_texture = load("res://assets/sprites/mariodead.png")
	death_sprite_frames.add_frame("death", death_texture)
	animated_sprite.sprite_frames = death_sprite_frames
	animated_sprite.scale = Vector2(0.03, 0.03)
	animated_sprite.play("death")

# Respawn after the DeathTimer runs
func _on_death_timer_timeout() -> void:
	get_tree().reload_current_scene()

func bounce_off_enemy():
	should_bounce = true

# Water/hazard collision
func _on_misc_collision_detector_body_entered(body: Node2D) -> void:
	in_water = true
	jumping = false
	_apply_water_visual_effect()
	if body.is_in_group("hazards") && !invincible:
		die()

# Restore full opacity when leaving water/lava
func _on_misc_collision_detector_body_exited(_body: Node2D) -> void:
	in_water = false
	jumping = !is_on_floor()
	_remove_water_visual_effect()

func start_invincibility() -> void:
	if !invincible:
		invincible = true
		_apply_invincibility_flash_animation(0.1)
		music_audio_player.stop()
		invincibility_audio_player.play()
	elif invincible_ending:
		invincible_ending = false
		invincibility_audio_player.play()
	invincibility_timer.start()

# Start winding down invincibility
func _on_invincibility_timer_timeout() -> void:
	invincible_ending = true
	invincibility_tween.kill()
	_apply_invincibility_flash_animation(0.2)
	invincibility_audio_player.stop()
	invincibility_ending_timer.start()
	
func _apply_invincibility_flash_animation(effect_duration: float) -> void:
	invincibility_tween = create_tween()
	invincibility_tween.set_loops()
	# Flash between red and blue colors
	invincibility_tween.tween_property(animated_sprite, "modulate", Color("#FF9999"), effect_duration)
	invincibility_tween.tween_property(animated_sprite, "modulate", Color("#FFFFFF"), effect_duration)
	invincibility_tween.tween_property(animated_sprite, "modulate", Color("#9999FF"), effect_duration)
	## Also flash transparency for extra effect
	invincibility_tween.tween_property(animated_sprite, "modulate:a", 0.4, effect_duration)
	invincibility_tween.tween_property(animated_sprite, "modulate:a", 1.0, effect_duration)

func _on_invincibility_ending_timer_timeout() -> void:
	if !invincible_ending: return
	_stop_invincibility()

func _stop_invincibility() -> void:
	if !invincible: return
	invincible = false
	invincible_ending = false
	invincibility_tween.kill()
	# Explicitly reset sprite to normal appearance
	animated_sprite.modulate = Color.WHITE
	if in_water: _apply_water_visual_effect()
	invincibility_audio_player.stop()
	music_audio_player.play()

func _apply_water_visual_effect() -> void:
	create_tween().tween_property(animated_sprite, "modulate:a", 0.2, 0.1)

func _remove_water_visual_effect() -> void:
	create_tween().tween_property(animated_sprite, "modulate:a", 1.0, 0.1)
	animated_sprite.rotation_degrees = 0
