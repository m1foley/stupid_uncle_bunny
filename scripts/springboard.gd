extends StaticBody2D

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var spring_area = $SpringArea2D

func _ready() -> void:
	disable()

func disable() -> void:
	sprite.hide()
	set_collision_layer_value(1, false)
	spring_area.set_collision_mask_value(3, false)

func enable() -> void:
	sprite.show()
	set_collision_layer_value(1, true)
	spring_area.set_collision_mask_value(3, true)

# boing!
func _on_spring_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.bounce_off_springboard()
