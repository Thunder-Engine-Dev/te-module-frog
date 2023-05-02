extends Powerup

var init: bool = false
var init2: bool = false

func appear_process(delta: float) -> void:
	if init2: return
	init2 = true
	
	var tw = create_tween()
	tw.tween_property(self, "global_position", position + Vector2(0, -100), 0.8) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		appear_distance = 0
		z_index = 5
	)


func motion_process(delta: float, _slide: bool = false) -> void:
	if init: return
	init = true
	
	move_loop(0)


func move_loop(pos: float):
	var tw = create_tween().set_parallel(true)
	tw.tween_callback(func():
		$Sprite.flip_h = true
		pos += 24
	)
	tw.chain().tween_property(self, "position:y", position.y + 24 + pos, 0.6) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "position:x", position.x + 80, 0.6) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(func():
		$Sprite.flip_h = false
		pos += 24
	)
	tw.chain().tween_property(self, "position:y", position.y + 48 + pos, 0.6) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "position:x", position.x, 0.6) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(move_loop.bind(pos))
