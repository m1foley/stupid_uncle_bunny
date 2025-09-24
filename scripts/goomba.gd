extends CharacterBody2D

@onready var squish_audio_player = $"../SquishAudioStreamPlayer"

const SPEED = 50.0
const SQUISHED_SECS = 0.4 

var direction: int = 1
var start_position: Vector2
var health: int = 1

func _ready():
	start_position = global_position
	$AnimatedSprite2D.play("walk")

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	if health <= 0: return
	
	# Walk
	velocity.x = direction * SPEED
	move_and_slide()

	# Turn around when hit object
	if is_on_wall():
		direction *= -1

# Being squished
func _on_head_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") && health > 0 && body.health > 0:
		_die(body)

# Body collisions
func _on_body_area_body_entered(body: Node2D) -> void:
	if health <= 0: return
	
	# Hurting player
	if body.is_in_group("player") && body.health > 0:
		body.die()
	# Falling on lava
	elif body.is_in_group("hazards"):
		_die(body)

func _die(body: Node2D) -> void:
	health = 0
	if body.is_in_group("player"):
		squish_audio_player.play()
		body.bounce_off_enemy()
	$AnimatedSprite2D.play("squished")
	await get_tree().create_timer(SQUISHED_SECS).timeout
	queue_free()
