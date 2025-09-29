extends Area2D

@onready var sprite = $Sprite2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("water"):
		_apply_water_visual_effect()
	elif body.is_in_group("player") && body.health > 0:
		body.start_invincibility()
		queue_free() # disappear
		
func _apply_water_visual_effect() -> void:
	create_tween().tween_property(sprite, "modulate:a", 0.2, 0.1)
