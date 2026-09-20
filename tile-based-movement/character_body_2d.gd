extends CharacterBody2D

const tile_size: Vector2 = Vector2(16, 16)
var sprite_node_pos_tween: Tween

func _physics_process(delta: float) -> void:
	if !sprite_node_pos_tween or !sprite_node_pos_tween.is_running():
		if Input.is_action_pressed("ui_up") and !$up.is_colliding():
			_move(Vector2(0, -1))
		elif Input.is_action_pressed("ui_down") and !$down.is_colliding():
			_move(Vector2(0, 1))
		elif Input.is_action_pressed("ui_left") and !$left.is_colliding():
			_move(Vector2(-1, 0))
		elif Input.is_action_pressed("ui_right") and !$right.is_colliding():
			_move(Vector2(1, 0))

func _move(dir: Vector2):
	global_position += dir * tile_size
	$Sprite2D.global_position -= dir * tile_size

	if sprite_node_pos_tween:
		sprite_node_pos_tween.kill()

	sprite_node_pos_tween = create_tween()
	sprite_node_pos_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	sprite_node_pos_tween.tween_property(
		$Sprite2D,
		"global_position",
		global_position,
		0.185
	).set_trans(Tween.TRANS_SINE)
