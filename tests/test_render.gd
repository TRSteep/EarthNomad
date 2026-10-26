extends SceneTree
## Run without --headless to exercise shader compilation and small-body clipping.
var failures = 0

func _init():
	call_deferred("run")

func run():
	var app = load("res://main.tscn").instantiate()
	app.settings_path = "user://test-render.cfg"
	DirAccess.remove_absolute(app.settings_path)
	root.add_child(app)
	app.playing = false
	app.pause_button.text = "▶  Продолжить"
	for physical in [false,true]:
		app.actual_size = physical
		for i in range(app.satellites.data.size()):
			app._select_moon(i)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			if not app.camera.is_position_in_frustum(app.moon_nodes[i].position):
				push_error("Satellite outside rendering frustum: %s / physical=%s" % [i,physical])
				failures += 1
	app.actual_size = false
	for i in [6,7]:
		app._select(i)
		await process_frame
		await RenderingServer.frame_post_draw
	app._toggle_galaxy()
	for i in range(9):
		app._select(i)
		await process_frame
		await RenderingServer.frame_post_draw
		if not app.trail_instance.visible or not app.moon_nodes.all(func(body): return body.visible):
			push_error("Galactic tracking hides trajectories or satellites")
			failures += 1
	app.moon_scale_input.value = 50.0
	app._system_overview()
	app.moon_scale_input.value = 50.0
	await process_frame
	await RenderingServer.frame_post_draw
	# Verify that the new fill actually reveals a surface facing away from the Sun.
	app._reset_visual_scale()
	app._select(4)
	app.yaw += PI
	app.pitch = -app.pitch
	app.materials[4].set_shader_parameter("night_fill",0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var dark_image: Image = root.get_texture().get_image()
	var center = Vector2i(dark_image.get_width()/2,dark_image.get_height()/2)
	var dark = dark_image.get_pixelv(center).get_luminance()
	app.materials[4].set_shader_parameter("night_fill",0.12)
	await process_frame
	await RenderingServer.frame_post_draw
	var filled_image: Image = root.get_texture().get_image()
	var filled = filled_image.get_pixelv(center).get_luminance()
	if filled<=dark+0.01:
		push_error("Night-side fill did not brighten the rendered surface")
		failures += 1
	print("Night-side center luminance: ",dark," -> ",filled)
	filled_image.save_png("res://build/night-side-v0.6.0.png")
	app._select(5)
	app._satellite_system()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dashed-orbits-v0.6.0.png")
	print("RENDER: ","PASS" if failures==0 else "FAIL", " (satellites; rings; galactic tracking; sizing; night fill; dashed orbits)")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test-render.cfg")
	quit(failures)
