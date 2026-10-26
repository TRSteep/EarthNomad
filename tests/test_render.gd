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
	print("RENDER: ","PASS" if failures==0 else "FAIL", " (20 satellites in both scales; Saturn and Uranus rings)")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test-render.cfg")
	quit(failures)
