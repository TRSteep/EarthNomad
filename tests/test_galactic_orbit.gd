extends SceneTree
const Physics = preload("res://scripts/physics.gd")
const GalacticOrbit = preload("res://scripts/galactic_orbit.gd")
var failures = 0

func _init():
	call_deferred("run")

func check(condition: bool, message: String):
	if not condition:
		push_error(message)
		failures += 1

func run():
	# The full circle and the local flight must share the same radius and plane.
	var center = Vector3(-Physics.GALACTIC_RADIUS_AU,0,0)
	for i in range(65):
		var angle = TAU*float(i)/64.0
		var offset = Physics.galactic_arc_delta(angle)
		check(abs((offset-center).length()/Physics.GALACTIC_RADIUS_AU-1.0)<0.000001,"Solar orbit has constant galactocentric radius")
		var point = GalacticOrbit.map_position(angle)
		check(abs(point.length()-GalacticOrbit.MAP_RADIUS)<0.00002,"Full orbit map has no radius distortion")
		check((point/GalacticOrbit.MAP_RADIUS).distance_to((offset-center)/Physics.GALACTIC_RADIUS_AU)<0.000001,"Map and flight use the same orbit plane")
	var tiny = Physics.galactic_arc_delta(1e-12)
	check(tiny.is_finite() and tiny.x<0.0 and tiny.length()>0.001,"Sub-AU local arc retains its inward curvature")
	var app = load("res://main.tscn").instantiate()
	app.settings_path = "user://test-galactic-orbit.cfg"
	DirAccess.remove_absolute(app.settings_path)
	root.add_child(app)
	app.playing = false
	app.set_process(false)
	app._update_readout()
	check(not app.galactic_map_button.visible,"Galactic orbit control stays out of heliocentric views")
	app._set_galactic_map(true)
	check(not app.galactic_map,"Map cannot be entered outside galactic flight")
	app._activate_view("galaxy")
	app._select(3)
	app._update_bodies()
	app._update_camera(1.0)
	app._update_readout()
	check(app.galactic_map_button.visible and app.galactic_orbit.local_arc.visible,"Flight displays the highlighted local solar orbit")
	check(app.galactic_orbit.local_arc.position==app.bodies[0].position,"Solar orbit follows the floating origin")
	var state = app.sim.p.duplicate()
	var velocity = app.sim.v.duplicate()
	var frame = [app.distance,app.target_distance,app.yaw,app.pitch]
	app.galactic_map_button.pressed.emit()
	check(app.galactic_map and app.galaxy,"Orbit map remains in galactic flight")
	check(app.camera.cull_mask==GalacticOrbit.MAP_LAYER and not app.size_panel.visible,"Map uses an independent galactic scale")
	check(app.galactic_orbit.map_root.visible and not app.galactic_orbit.local_arc.visible,"Complete orbit replaces the local arc")
	check(app.sim.p==state and app.sim.v==velocity,"Map never moves or reinitializes the planetary integrator")
	check(app.camera.is_position_in_frustum(app.galactic_orbit.sun_marker.position),"Solar system marker is within the map overview")
	var old_distance: float = app.target_distance
	app._zoom(0.8)
	check(app.target_distance<old_distance,"Map supports wheel zoom")
	app._set_overview()
	check(app.galactic_map and app.target_distance==280.0,"R fits the complete galactic orbit")
	app._set_labels_enabled(false)
	app._update_camera(0.0)
	check(app.galactic_orbit.map_labels.all(func(label): return not label.visible),"Map labels honor the shared visibility setting")
	app._set_labels_enabled(true)
	app._update_camera(0.0)
	check(app.galactic_orbit.map_labels.all(func(label): return label.visible),"Map labels can be restored")
	app.galactic_map_button.pressed.emit()
	check(not app.galactic_map and app.camera.cull_mask==1,"Return restores the planetary rendering layer")
	check([app.distance,app.target_distance,app.yaw,app.pitch]==frame,"Return preserves the exact flight framing")
	app._set_galactic_map(true)
	app._select_moon(0)
	check(not app.galactic_map and app.galaxy and app.selected_moon==0,"Selecting a moon returns to flight tracking")
	app._set_galactic_map(true)
	app._system_overview()
	app._update_readout()
	check(not app.galactic_map and not app.galaxy and app.size_panel.visible,"Switching views leaves the galactic map cleanly")
	# A quarter-turn must put the marker on the same trajectory as the flight.
	app.galactic_orbit.update_map(Physics.GALACTIC_PERIOD_DAYS*0.25,true)
	var expected = GalacticOrbit.map_position(PI*0.5)
	check(app.galactic_orbit.sun_marker.position.distance_to(expected)<0.00001,"Marker phase follows the 230 Myr model period")
	print("GALACTIC ORBIT: ","PASS" if failures==0 else "FAIL")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test-galactic-orbit.cfg")
	quit(failures)
