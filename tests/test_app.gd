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
	check(app.galaxy_planet_scale==4.0 and app.galaxy_sun_scale==2.0,"Galactic defaults are 4x/2x")
	check(app.helio_planet_scale==4.0 and app.helio_sun_scale==2.0,"Heliocentric defaults are 4x/2x")
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
	app._set_visual_scale(25.0,false)
	check(is_equal_approx(app.target_distance/app._radius(3),camera_ratio),"Close-up remains outside enlarged body")
	app._save_display_settings()
	app.galaxy_planet_scale = 1.0
	app._load_display_settings()
	check(is_equal_approx(app.galaxy_planet_scale,25.0),"Settings survive reload")
	app._set_visual_scale(-10.0,false)
	check(app.galaxy_planet_scale==app.VISUAL_SCALE_MIN,"Lower scale bound")
	app._set_visual_scale(10000.0,false)
	check(app.galaxy_planet_scale==50.0,"Planet maximum is 50x")
	app._set_visual_scale(1000.0,true)
	check(app.galaxy_sun_scale==50.0,"Sun maximum is 50x")
	app._select(0)
	app._zoom(0.9)
	check(app.target_distance>=app._radius(0)*2.0,"Zoom bounds scale with giant Sun")
	check(app._validated_scale(NAN,20.0)==20.0,"Corrupt saved scale rejected")
	app._toggle_scale()
	check(is_equal_approx(app._radius(3),6371.0/149597870.7*20.0),"Physical scale ignores visual settings")
	app._reset_visual_scale()
	check(app.galaxy_planet_scale==4.0 and app.galaxy_sun_scale==2.0,"Scale reset restores 4x/2x")
	app._reset()
	check(app.sim.elapsed==0.0,"Reset time")
	check(app.sim.pending==0.0,"Reset residual time")
	check(app.galaxy_planet_scale==4.0 and app.galaxy_sun_scale==2.0,"Time reset does not restore old defaults")
	app._system_overview()
	app._update_readout()
	check(not app.galaxy and app.size_panel.visible,"Heliocentric size controls are visible")
	app.planet_scale_input.value = 8.0
	app.sun_scale_input.value = 3.0
	check(is_equal_approx(app._radius(3),app.DISPLAY_RADII[3]*8.0),"Heliocentric planet scale")
	check(is_equal_approx(app._radius(0),app.DISPLAY_RADII[0]*3.0),"Heliocentric Sun scale")
	check(app.sim.p==positions and app.sim.v==velocities,"Both view sizes leave physical state unchanged")
	app._toggle_galaxy()
	check(app.planet_scale_input.value==4.0 and app.sun_scale_input.value==2.0,"Galactic controls restored when switching views")
	app._inner_overview()
	check(app.planet_scale_input.value==8.0 and app.sun_scale_input.value==3.0,"Inner group uses heliocentric sizes")
	app._update_bodies()
	app._update_camera(1.0)
	app._update_labels()
	check(app.labels.any(func(label): return label.visible),"Labels can be shown")
	app.labels_toggle.button_pressed = false
	app._update_bodies()
	app._update_labels()
	check(app.labels.all(func(label): return not label.visible),"Labels stay hidden across frame updates")
	app._save_display_settings()
	app.labels_enabled = true
	app.helio_planet_scale = 1.0
	app._load_display_settings()
	check(not app.labels_enabled and app.helio_planet_scale==8.0,"Labels and heliocentric sizes survive reload")
	app.labels_toggle.button_pressed = true
	app._reset_visual_scale()
	check(app.helio_planet_scale==4.0 and app.helio_sun_scale==2.0,"Heliocentric scale reset restores 4x/2x")
	# Existing 0.2.0 settings migrate once, and out-of-range custom values are clamped.
	var legacy = ConfigFile.new()
	legacy.set_value("galaxy","planet_scale",20.0)
	legacy.set_value("galaxy","sun_scale",1.0)
	legacy.save(app.settings_path)
	app._load_display_settings()
	check(app.galaxy_planet_scale==4.0 and app.galaxy_sun_scale==2.0,"Legacy default pair migrates to 4x/2x")
	legacy.set_value("galaxy","planet_scale",1000.0)
	legacy.set_value("galaxy","sun_scale",8.0)
	legacy.save(app.settings_path)
	app._load_display_settings()
	check(app.galaxy_planet_scale==50.0 and app.galaxy_sun_scale==8.0,"Legacy custom sizes keep values within 50x")
	app._sync_scale_controls()
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
