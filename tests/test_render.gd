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
	print("RENDER: ","PASS" if failures==0 else "FAIL", " (20 satellites in both scales; rings; nine galactic targets; satellite sizes)")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test-render.cfg")
	quit(failures)
