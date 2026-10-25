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
	app.settings_path = "user://test-display.cfg"
	DirAccess.remove_absolute(app.settings_path)
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
	var positions = app.sim.p.duplicate()
	var velocities = app.sim.v.duplicate()
	app.planet_scale_input.value = 37.5
	app._update_bodies()
	check(not app.actual_size,"Scale editor leaves physical-size mode")
	check(is_equal_approx(app._radius(3),app.DISPLAY_RADII[3]*37.5),"Arbitrary planet scale")
	check(is_equal_approx(app._radius(0),app.DISPLAY_RADII[0]*app.DEFAULT_SUN_SCALE),"Planet scale leaves Sun independent")
	check(app.sim.p==positions and app.sim.v==velocities,"Display scale cannot change dynamics")
	app.sun_scale_slider.value = log(8.0)/log(2.0)
	check(is_equal_approx(app._radius(0),app.DISPLAY_RADII[0]*8.0),"Independent Sun slider")
	app._select(3)
	var camera_ratio: float = app.target_distance/app._radius(3)
	app._set_galaxy_scale(75.0,false)
	check(is_equal_approx(app.target_distance/app._radius(3),camera_ratio),"Close-up remains outside enlarged body")
	app._save_display_settings()
	app.galaxy_planet_scale = 1.0
	app._load_display_settings()
	check(is_equal_approx(app.galaxy_planet_scale,75.0),"Settings survive reload")
	app._set_galaxy_scale(-10.0,false)
	check(app.galaxy_planet_scale==app.VISUAL_SCALE_MIN,"Lower scale bound")
	app._set_galaxy_scale(10000.0,false)
	check(app.galaxy_planet_scale==app.VISUAL_SCALE_MAX,"Upper scale bound")
	app._set_galaxy_scale(1000.0,true)
	app._select(0)
	app._zoom(0.9)
	check(app.target_distance>=app._radius(0)*2.0,"Zoom bounds scale with giant Sun")
	check(app._validated_scale(NAN,20.0)==20.0,"Corrupt saved scale rejected")
	app._toggle_scale()
	check(is_equal_approx(app._radius(3),6371.0/149597870.7*20.0),"Physical scale ignores visual settings")
	app._reset_galaxy_scale()
	check(app.galaxy_planet_scale==20.0 and app.galaxy_sun_scale==1.0,"Restore readable defaults")
	app._reset()
	check(app.sim.elapsed==0.0,"Reset time")
	check(app.sim.pending==0.0,"Reset residual time")
	app._toggle_galaxy()
	check(is_equal_approx(app._radius(3),app.DISPLAY_RADII[3]),"Normal view keeps its original size")
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
	DirAccess.remove_absolute("user://test-display.cfg")
	quit(failures)
