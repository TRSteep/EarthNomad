extends SceneTree
var app: Node3D
var failures = 0

func _init():
	call_deferred("run")

func check(condition: bool, message: String):
	if not condition:
		push_error(message)
		failures += 1

func check_default_sizes(message: String):
	check(app.galaxy_planet_scale==10.0 and app.galaxy_sun_scale==10.0 and app.galaxy_moon_scale==10.0 and app.helio_planet_scale==10.0 and app.helio_sun_scale==10.0 and app.helio_moon_scale==10.0,message)

func check_view_buttons(expected: String):
	for mode in app.view_buttons:
		check(app.view_buttons[mode].disabled==(mode==expected),"Only the current view button is disabled")
		check(app.view_buttons[mode].button_pressed==(mode==expected),"Exactly one view button is selected")

func run():
	app = load("res://main.tscn").instantiate()
	app.settings_path = "user://test-display.cfg"
	# Keep regression defaults independent of the user's editable Visual preset.
	var default_preset_path = "user://test-default-visual.cfg"
	var default_preset = ConfigFile.new()
	for key in ["sun","planets","moons"]:
		default_preset.set_value("sizes",key,10.0)
	default_preset.set_value("sizes","compression",1.0)
	default_preset.save(default_preset_path)
	app.visual_preset_path = default_preset_path
	DirAccess.remove_absolute(app.settings_path)
	var previous_session = ConfigFile.new()
	previous_session.set_value("galaxy","planet_scale",40.0)
	previous_session.set_value("galaxy","sun_scale",25.0)
	previous_session.set_value("galaxy","moon_scale",19.0)
	previous_session.set_value("heliocentric","planet_scale",12.0)
	previous_session.set_value("heliocentric","sun_scale",8.0)
	previous_session.save(app.settings_path)
	root.add_child(app)
	for path in app.texture_cache:
		check(app.texture_cache[path] != null,"Loaded texture: " + path)
	app.playing = false
	check_view_buttons("system")
	check_default_sizes("Startup restores 10x/10x/10x in both views despite a previous-session config")
	check(app.planet_scale_input.value==10.0 and app.sun_scale_input.value==10.0 and app.moon_scale_input.value==10.0,"Startup controls show 10x/10x/10x")
	for i in range(9):
		app._select(i)
		app._update_bodies()
		app._update_camera(1.0)
		if i!=3:
			check(app.bodies[i].position.length()<0.00001,"Floating render origin for planet %d" % i)
		else:
			var earth_moon_center = app.bodies[3].position*(1.0-0.0121505856)+app.moon_nodes[0].position*0.0121505856
			check(earth_moon_center.length()<0.00001,"Earth-Moon render barycenter")
		check(app.camera.position.is_finite(),"Finite camera")
	app._toggle_scale()
	check(abs(app._radius(3)-6371.0084/149597870.7*20.0)<1e-10,"True-scale Earth radius")
	app._toggle_galaxy()
	check(app.history.size()==241,"Galactic history prefilled")
	app._draw_trails()
	check(app.trail_instance.mesh.get_surface_count()==9,"Nine trajectory surfaces")
	var positions = app.sim.p.duplicate()
	var velocities = app.sim.v.duplicate()
	app.planet_scale_input.value = 37.5
	app._update_bodies()
	check(not app.actual_size,"Scale editor leaves physical-size mode")
	check(is_equal_approx(app._radius(3),(app.RADII[3]*app.KM_TO_SCENE)*37.5),"Arbitrary planet scale")
	check(is_equal_approx(app._radius(0),(app.RADII[0]*app.KM_TO_SCENE)*app.DEFAULT_SUN_SCALE),"Planet scale leaves Sun independent")
	check(app.sim.p==positions and app.sim.v==velocities,"Display scale cannot change dynamics")
	app.sun_scale_slider.value = log(8.0)/log(2.0)
	check(is_equal_approx(app._radius(0),(app.RADII[0]*app.KM_TO_SCENE)*8.0),"Independent Sun slider")
	app._select(3)
	var tracked_distance: float = app.target_distance
	app._set_visual_scale(25.0,false)
	check(is_equal_approx(app.target_distance,tracked_distance),"Galactic tracking preserves camera distance while resizing planets")
	app._save_display_settings()
	app.galaxy_planet_scale = 1.0
	app._load_display_settings()
	check_default_sizes("Reload restores defaults instead of previous sizes")
	app._set_visual_scale(-10.0,false)
	check(app.galaxy_planet_scale==app.VISUAL_SCALE_MIN,"Lower scale bound")
	app._set_visual_scale(10000.0,false)
	check(app.galaxy_planet_scale==500.0,"Planet maximum is 500x")
	app._set_visual_scale(1000.0,true)
	check(app.galaxy_sun_scale==50.0,"Sun maximum is 50x")
	app._select(0)
	app._zoom(0.9)
	check(app.target_distance>=app._radius(0)*2.0,"Zoom bounds scale with giant Sun")
	check(app._validated_scale(NAN,20.0)==20.0,"Corrupt saved scale rejected")
	app._toggle_scale()
	check(is_equal_approx(app._radius(3),6371.0084/149597870.7*20.0),"Physical scale ignores visual settings")
	app._set_scale_mode(false)
	check(app.galaxy_planet_scale==10.0 and app.galaxy_sun_scale==10.0 and app.galaxy_moon_scale==10.0,"Scale reset restores 10x/10x/10x")
	app._reset()
	check(app.sim.elapsed==0.0,"Reset time")
	check(app.sim.pending==0.0,"Reset residual time")
	check_default_sizes("Time reset restores the requested defaults in both views")
	app._system_overview()
	app._update_readout()
	check(not app.galaxy and app.size_panel.visible,"Heliocentric size controls are visible")
	app.planet_scale_input.value = 8.0
	app.sun_scale_input.value = 3.0
	check(is_equal_approx(app._radius(3),(app.RADII[3]*app.KM_TO_SCENE)*8.0),"Heliocentric planet scale")
	check(is_equal_approx(app._radius(0),(app.RADII[0]*app.KM_TO_SCENE)*3.0),"Heliocentric Sun scale")
	check(app.sim.p==positions and app.sim.v==velocities,"Both view sizes leave physical state unchanged")
	app._toggle_galaxy()
	check(app.planet_scale_input.value==10.0 and app.sun_scale_input.value==10.0,"Galactic controls restored when switching views")
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
	check(not app.labels_enabled and app.helio_planet_scale==10.0,"Label preference persists while startup sizes reset")
	app.labels_toggle.button_pressed = true
	app._set_scale_mode(false)
	check(app.helio_planet_scale==10.0 and app.helio_sun_scale==10.0,"Heliocentric scale reset restores 10x/10x")
	# Legacy sizes must not override new-session defaults.
	var legacy = ConfigFile.new()
	legacy.set_value("galaxy","planet_scale",20.0)
	legacy.set_value("galaxy","sun_scale",1.0)
	legacy.save(app.settings_path)
	app._load_display_settings()
	check_default_sizes("Legacy defaults are replaced by 10x/10x/10x")
	legacy.set_value("galaxy","planet_scale",1000.0)
	legacy.set_value("galaxy","sun_scale",8.0)
	legacy.save(app.settings_path)
	app._load_display_settings()
	check_default_sizes("Legacy custom sizes cannot override startup defaults")
	app._sync_scale_controls()
	app._select(3)
	var before: float = app.target_distance
	app._zoom(0.5)
	check(app.target_distance<before,"Zoom input")
	app._toggle_pause()
	check(app.playing,"Pause resumes")
	app._process(0.1)
	check(app.sim.elapsed+app.sim.pending>0.0,"Clock advances")
	app.playing = false
	var moon_physics_before = app.sim.p.duplicate()
	for i in range(app.satellites.data.size()):
		app._select_moon(i)
		app._update_bodies()
		app._update_camera(1.0)
		app._update_readout()
		var d: Dictionary = app.satellites.data[i]
		check(app.selected==int(d.parent),"Satellite parent selection")
		check(app.moon_picker.get_selected_id()==i,"Satellite dropdown follows focus")
		check(app.title_label.text==d.name,"Satellite telemetry")
		check(app.moon_nodes[i].visible,"Selected satellite is visible")
		check(app.camera.position.distance_to(app.moon_nodes[i].position)>app._moon_radius(i),"Satellite camera clearance")
		var to_parent = (app.bodies[app.selected].position-app.moon_nodes[i].position).normalized()
		check((-app.moon_nodes[i].basis.z).normalized().dot(to_parent)>0.999,"Tidal locking")
		app._toggle_scale()
		app._update_bodies()
		app._update_camera(1.0)
		check(app.selected_moon==i,"Physical mode preserves satellite focus")
		check(app.camera.far/app.camera.near<4000000.0,"Local satellite projection keeps a safe near/far ratio")
		check(is_equal_approx(app._moon_radius(i)/app._radius(app.selected),d.radius_km/app.RADII[app.selected]),"Satellite/planet radius ratio is preserved")
		app._toggle_scale()
	app._select(5)
	app._satellite_system()
	app._update_bodies()
	check(app.satellite_system_view and app.moon_picker.item_count==5,"Four Galilean moons in picker")
	check(app.moon_orbits[3].visible,"Satellite-system orbits are visible")
	app._set_labels_enabled(false)
	check(app.moon_labels.all(func(label): return not label.visible),"Satellite labels honor the visibility switch")
	app._system_overview()
	app._update_bodies()
	check(app.moon_nodes.all(func(body): return body.visible),"Solar overview keeps every satellite visible")
	check(app.bodies.all(func(body): return body.visible),"Solar overview restores all planets")
	check(app.sim.p==moon_physics_before,"Satellite rendering never modifies planetary integrator")
	check(app.ring_nodes.has(6) and app.ring_nodes.has(7),"Saturn and Uranus ring meshes")
	check(app.materials[6].get_shader_parameter("ring_kind")==1 and app.materials[7].get_shader_parameter("ring_kind")==2,"Planet materials receive their own ring-shadow profile")
	app._select_moon(0)
	app._reset()
	app._update_bodies()
	var initial_moon = app.moon_nodes[0].position
	app.sim.step()
	app._update_bodies()
	check(app.moon_nodes[0].position.distance_to(initial_moon)>0.001,"Satellite advances with model time")
	var paused_moon = app.moon_nodes[0].position
	app._process(0.1)
	check(app.moon_nodes[0].position==paused_moon,"Satellite respects pause")
	app._reset()
	app._update_bodies()
	check(app.moon_nodes[0].position.distance_to(initial_moon)<0.00001,"Time reset restores satellite phase")
	# Galactic object selection is tracking, not an isolated close-up.
	app._toggle_galaxy()
	app._update_bodies()
	app.distance = app.target_distance
	app._update_camera(1.0)
	var follow_distance: float = app.distance
	var follow_yaw: float = app.yaw
	var follow_pitch: float = app.pitch
	for i in range(9):
		app._select(i)
		app._update_bodies()
		app._update_camera(1.0)
		check(app.galaxy and not app.overview,"Galactic selection follows target")
		check(app.distance==follow_distance and app.yaw==follow_yaw and app.pitch==follow_pitch,"Selection keeps flight framing")
		check(app.bodies.all(func(body): return body.visible) and app.moon_nodes.all(func(body): return body.visible),"All planets and satellites remain visible while tracking")
		check(app.trail_instance.visible,"Tracking retains galactic trajectories")
		var offset = app.camera.position-app.bodies[i].position
		app.sim.step()
		app._update_bodies()
		app._update_camera(1.0)
		check((app.camera.position-app.bodies[i].position).distance_to(offset)<0.001,"Camera follows the moving target")
	app._select_moon(0)
	app._update_bodies()
	app._update_camera(1.0)
	check(app.galaxy and app.distance==follow_distance and app.trail_instance.visible,"Satellite selection also preserves galactic flight")
	# Independent satellite size must change only radius, not positions or planet sizes.
	var moon_positions: Array[Vector3] = []
	for body in app.moon_nodes:
		moon_positions.append(body.position)
	var parent_radius: float = app._radius(3)
	var moon_radius: float = app._moon_radius(0)
	var old_moon_scale: float = app._moon_scale()
	app.moon_scale_input.value = 12.5
	app._update_bodies()
	check(is_equal_approx(app._moon_radius(0),moon_radius*12.5/old_moon_scale),"Satellite spinbox controls radius")
	check(app._radius(3)==parent_radius and app.distance==follow_distance,"Satellite size preserves planet size and flight camera")
	for i in range(app.moon_nodes.size()):
		check(app.moon_nodes[i].position==moon_positions[i],"Satellite size does not move orbits")
	app._system_overview()
	check(app.moon_scale_input.value==10.0,"Heliocentric satellite scale is independent")
	app.moon_scale_slider.value = log(7.5)/log(2.0)
	check(is_equal_approx(app.helio_moon_scale,7.5),"Satellite slider controls heliocentric size")
	app._save_display_settings()
	app.helio_moon_scale = 1.0
	app.galaxy_moon_scale = 1.0
	app._load_display_settings()
	check_default_sizes("Reload resets satellite sizes in both views")
	app._set_moon_scale(500.0)
	check(app.helio_moon_scale==500.0,"Satellite size respects the 500x limit")
	app._toggle_scale()
	check(is_equal_approx(app._moon_radius(0),1737.4/149597870.7*20.0),"Physical satellite size ignores exaggeration")
	app._set_scale_mode(false)
	check(app.helio_moon_scale==10.0,"Display reset restores satellite default")
	legacy.set_value("display","schema",2)
	legacy.set_value("galaxy","planet_scale",20.0)
	legacy.set_value("galaxy","sun_scale",1.0)
	legacy.save(app.settings_path)
	app._load_display_settings()
	check_default_sizes("Schema 2 sizes are ignored at startup")
	app._toggle_galaxy()
	app.distance = 1.0
	app.target_distance = 1.0
	app._select(0)
	check(app.distance>=app._radius(0)*2.0,"Selecting a large target cannot put tracking camera inside it")
	app._set_visual_scale(50.0,true)
	check(app.distance>=app._radius(0)*2.0,"Growing a tracked target preserves camera clearance")
	# Radius edits must not move satellites, their parents, or any orbit geometry.
	app._reset()
	app._system_overview()
	app._update_bodies()
	var fixed_moons: Array[Vector3] = []
	var fixed_planets: Array[Vector3] = []
	var fixed_orbits: Array[Transform3D] = []
	var fixed_bounds: Array[AABB] = []
	for body in app.moon_nodes:
		fixed_moons.append(body.position)
	for body in app.bodies:
		fixed_planets.append(body.position)
	for orbit in app.moon_orbits:
		fixed_orbits.append(orbit.transform)
		fixed_bounds.append(orbit.mesh.get_aabb())
	app._set_visual_scale(12.0,false)
	app._set_visual_scale(7.0,true)
	app._set_moon_scale(11.0)
	app._update_bodies()
	for i in range(app.moon_nodes.size()):
		check(app.moon_nodes[i].position==fixed_moons[i],"Planet and moon sizes leave satellite coordinates unchanged")
		check(app.moon_orbits[i].transform==fixed_orbits[i] and app.moon_orbits[i].mesh.get_aabb()==fixed_bounds[i],"Planet size leaves satellite orbit geometry unchanged")
	for i in range(app.bodies.size()):
		check(app.bodies[i].position==fixed_planets[i],"Size changes do not move planetary centers")
	app.physical_mode_button.pressed.emit()
	check(app.actual_size and app.physical_mode_button.button_pressed and not app.visual_mode_button.button_pressed,"1:1 is a selectable scale mode")
	check(app.adjust_controls.visible and app.distance_controls.visible,"All four controls remain visible in 1:1")
	check(is_equal_approx(app._radius(3),6371.0084*app.KM_TO_SCENE),"1:1 restores actual Earth radius")
	var physical_earth_radius: float = app._radius(3)
	var physical_moon_radius: float = app._moon_radius(0)
	app.compression_slider.value = 25.0
	app._update_bodies()
	check(app._radius(3)==physical_earth_radius and app._moon_radius(0)==physical_moon_radius,"Compression preserves real sizes")
	check(is_equal_approx(app.bodies[5].position.length(),fixed_planets[5].length()/25.0),"Interplanetary distance is compressed by the selected factor")
	for i in range(app.moon_nodes.size()):
		var parent = int(app.satellites.data[i].parent)
		var actual_relative = app.moon_nodes[i].position-app.bodies[parent].position
		var fixed_relative = fixed_moons[i]-fixed_planets[parent]
		check(actual_relative.distance_to(fixed_relative)<0.0001,"Compression preserves local satellite orbits")
	app.visual_mode_button.pressed.emit()
	app._update_bodies()
	check(not app.actual_size and app.adjust_controls.visible and app.distance_controls.visible,"Adjust mode shows three size sliders")
	check(is_equal_approx(app._radius(3),6371.0084*app.KM_TO_SCENE*10.0),"Visual loads the preset radius")
	for i in range(app.bodies.size()):
		check(app.bodies[i].position.distance_to(fixed_planets[i])<0.00001,"Visual loads its configured distance compression")
	app._select_moon(0)
	var before_hiding = app.sim.p.duplicate()
	app.moons_toggle.button_pressed = false
	check(app.selected_moon==-1,"Hiding the focused satellite returns to its planet")
	check(app.moon_nodes.all(func(body): return not body.visible),"Satellite toggle hides all twenty moons")
	check(app.moon_orbits.all(func(orbit): return not orbit.visible) and app.moon_labels.all(func(label): return not label.visible),"Satellite toggle also hides orbits and labels")
	check(app.moon_picker.disabled and app.satellite_system_button.disabled,"Satellite controls are disabled while hidden")
	check(app.sim.p==before_hiding,"Visibility does not change the physics state")
	app._save_display_settings()
	app.moons_enabled = true
	app._load_display_settings()
	check(not app.moons_enabled,"Satellite visibility preference survives reload")
	app._set_moons_enabled(true)
	check(app.moon_nodes.all(func(body): return body.visible),"Satellites can be restored")
	for mode in ["inner","galaxy","system"]:
		app.view_buttons[mode].pressed.emit()
		check(app.view_mode==mode and app.galaxy==(mode=="galaxy"),"View buttons activate their explicit mode")
		check_view_buttons(mode)
		app._select(5)
		check_view_buttons(mode)
		app._set_overview()
		check_view_buttons(mode)
	# Presets reload the file and act on radii independently of compression.
	app._activate_view("galaxy")
	app._set_distance_compression(500.0)
	var preset_time: float = app.sim.elapsed+app.sim.pending
	var preset_selected: int = app.selected
	app.physical_mode_button.pressed.emit()
	check(app._planet_scale()==1.0 and app._sun_scale()==1.0 and app._moon_scale()==1.0,"1:1 sets all actual multipliers to one")
	check(app.planet_scale_input.value==1.0 and app.sun_scale_input.value==1.0 and app.moon_scale_input.value==1.0,"1:1 updates all numeric controls")
	check(app.distance_compression==1.0 and app.compression_slider.value==1.0,"1:1 restores real distances and synchronizes the slider")
	check(is_equal_approx(app.target_distance,2000.0),"1:1 restores uncompressed galactic framing")
	check(app.physical_mode_button.get_parent().get_child_count()==2,"Only 1:1 and Visual buttons remain")
	check(app.visual_mode_button.text=="Visual","Visual caption")
	var preset_path = "user://test-visual.cfg"
	var preset = ConfigFile.new()
	preset.set_value("sizes","sun",12.0)
	preset.set_value("sizes","planets",24.0)
	preset.set_value("sizes","moons",36.0)
	preset.set_value("sizes","compression",50.0)
	preset.save(preset_path)
	app.visual_preset_path = preset_path
	app.visual_mode_button.pressed.emit()
	check(app._sun_scale()==12.0 and app._planet_scale()==24.0 and app._moon_scale()==36.0,"Visual reads distinct file values")
	preset.set_value("sizes","planets",42.0)
	preset.save(preset_path)
	app.visual_mode_button.pressed.emit()
	check(app._planet_scale()==42.0,"Clicking Visual again reloads the edited file")
	check(app.distance_compression==50.0 and app.sim.elapsed+app.sim.pending==preset_time and app.selected==preset_selected,"Visual loads compression while preserving time and selection")
	preset.set_value("sizes","sun",500.0)
	preset.set_value("sizes","planets",0.1)
	preset.set_value("sizes","moons","invalid")
	preset.save(preset_path)
	app.visual_mode_button.pressed.emit()
	check(app._sun_scale()==50.0 and app._planet_scale()==1.0 and app._moon_scale()==10.0,"Preset values are bounded and invalid values use defaults")
	app.visual_preset_path = default_preset_path
	app.visual_mode_button.pressed.emit()
	check(app._sun_scale()==10.0 and app._planet_scale()==10.0 and app._moon_scale()==10.0,"Visual restores all fixture radii")
	for pair in [[app.sun_scale_input,50.0],[app.planet_scale_input,500.0],[app.moon_scale_input,500.0]]:
		pair[0].value = pair[1]
		check(pair[0].value==pair[1] and pair[0].min_value==1.0,"Distinct radius input range")
	for pair in [[app.sun_scale_slider,50.0],[app.planet_scale_slider,500.0],[app.moon_scale_slider,500.0]]:
		check(is_equal_approx(pow(2.0,pair[0].max_value),pair[1]) and pair[0].min_value==0.0,"Distinct radius slider range")
	app.compression_slider.value = 999.0
	check(app.distance_compression==500.0,"Distance compression has a 500x limit")
	preset.set_value("sizes","compression",9999.0)
	preset.save(preset_path)
	app.visual_preset_path = preset_path
	app.visual_mode_button.pressed.emit()
	check(app.distance_compression==500.0,"Configured compression is bounded at 500")
	preset.set_value("sizes","compression","invalid")
	preset.save(preset_path)
	app.visual_mode_button.pressed.emit()
	check(app.distance_compression==50.0,"Invalid configured compression falls back to 50")
	preset.set_value("sizes","compression",50.0)
	preset.save(preset_path)
	app._load_display_settings()
	check(app.distance_compression==50.0,"Startup reads compression from the preset")
	app.visual_preset_path = default_preset_path
	DirAccess.remove_absolute(preset_path)
	DirAccess.remove_absolute(default_preset_path)
	print("APP: ", "PASS" if failures==0 else "FAIL")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test-display.cfg")
	quit(failures)
