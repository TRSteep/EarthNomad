extends SceneTree
var app: Node3D
var failures = 0

func _init():
	call_deferred("run")

func check(condition: bool, message: String):
	if not condition:
		push_error(message)
		failures += 1

func run():
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	for path in app.texture_cache:
		check(app.texture_cache[path] != null,"Loaded texture: " + path)
	app.playing = false
	for i in range(9):
		app._select(i)
		app._update_bodies()
		app._update_camera(1.0)
		check(app.bodies[i].position.length()<0.00001,"Floating render origin for planet %d" % i)
		check(app.camera.position.is_finite(),"Finite camera")
	app._toggle_scale()
	check(abs(app._radius(3)-6371.0/149597870.7*20.0)<1e-10,"True-scale Earth radius")
	app._toggle_galaxy()
	check(app.history.size()==241,"Galactic history prefilled")
	app._draw_trails()
	check(app.trail_instance.mesh.get_surface_count()==9,"Nine trajectory surfaces")
	app._reset()
	check(app.sim.elapsed==0.0,"Reset time")
	check(app.sim.pending==0.0,"Reset residual time")
	app._toggle_galaxy()
	app._toggle_scale()
	app._select(3)
	var before: float = app.target_distance
	app._zoom(0.5)
	check(app.target_distance<before,"Zoom input")
	app._toggle_pause()
	check(app.playing,"Pause resumes")
	app._process(0.1)
	check(app.sim.elapsed+app.sim.pending>0.0,"Clock advances")
	print("APP: ", "PASS" if failures==0 else "FAIL")
	app.queue_free()
	await process_frame
	quit(failures)
