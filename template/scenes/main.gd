extends Node2D

func _draw():
	draw_rect(Rect2(0, 0, 640, 360), Color(0.05, 0.1, 0.3))
	draw_circle(Vector2(320, 180), 60, Color(1.0, 0.85, 0.2))

func _process(_d):
	queue_redraw()
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("SHOT_OUT")
	if out != "":
		get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit.call_deferred()
