extends Area2D

@onready var timer = $Timer
@onready var audio_player = $AudioPlayer

func _on_body_entered(body: Node2D) -> void:
	audio_player.play()
	timer.start()

func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
