extends SceneTree
## Independent km references and cross-mode geometric invariants.
const AU_KM = 149597870.7
const RADII_KM = [695700.0,2439.4,6051.8,6371.0084,3389.5,69911.0,58232.0,25362.0,24622.0]
# JPL mean radii and semimajor axes, in the catalog's order.
const MOON_RADII = [1737.4,11.08,6.2,1821.49,1560.8,2631.2,2410.3,198.2,252.1,531.1,561.4,763.5,2574.76,734.3,578.9,584.7,788.9,761.4,235.8,1352.6]
const MOON_AXES = [384400.0,9375.0,23457.0,421800.0,671100.0,1070400.0,1882700.0,186000.0,238400.0,295000.0,377700.0,527200.0,1221900.0,3561700.0,190929.0,265986.0,436298.0,583511.0,129846.0,354800.0]
# Rounded NASA perihelion/aphelion values (million km); broad tolerance accounts
# for mean JPL elements versus osculating/reference-epoch factsheet values.
const PLANET_RANGES = [[46.0,69.8],[107.5,108.9],[147.1,152.1],[206.7,249.3],[740.6,816.4],[1357.6,1506.5],[2732.7,3001.4],[4471.1,4558.9]]
var app: Node3D
var failures = 0
var checks = 0

func _init():
	call_deferred("run")

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		push_error(message)
		failures += 1

func expected_center(body: int, origin: int, compression: float) -> Vector3:
	var result = Vector3.ZERO
	for k in range(3):
		result[k] = ((app.sim.p[body*3+k]-app.sim.p[origin*3+k])+(app.sim.v[body*3+k]-app.sim.v[origin*3+k])*app.sim.pending)*20.0/compression
	if body==3:
		result -= app.satellites.position_km(0,app.sim.epoch_jd+app.sim.elapsed+app.sim.pending)*(20.0/AU_KM*0.0121505856)
	return result

func check_geometry(physical: bool, compression: float, factor: float):
	app._set_scale_mode(physical)
	app._set_distance_compression(compression)
	if not physical:
		app._set_visual_scale(factor,false)
		app._set_visual_scale(factor,true)
		app._set_moon_scale(factor)
	app._update_bodies()
	var multiplier = 1.0 if physical else factor
	for i in range(9):
		check(abs(app.bodies[i].scale.x/(20.0/AU_KM)-RADII_KM[i]*(minf(multiplier,50.0) if i==0 else multiplier))<RADII_KM[i]*(minf(multiplier,50.0) if i==0 else multiplier)*0.000001,"Rendered planetary radius in km: %d" % i)
		for j in range(i):
			var expected = expected_center(i,0,compression).distance_to(expected_center(j,0,compression))
			check(abs(app.bodies[i].position.distance_to(app.bodies[j].position)-expected)<maxf(0.00001,expected*0.000001),"Interplanetary center distance: %d/%d" % [i,j])
	for i in range(20):
		var d: Dictionary = app.satellites.data[i]
		check(d.radius_km==MOON_RADII[i] and d.a_km==MOON_AXES[i],"Satellite reference km: "+d.id)
		check(abs(app.moon_nodes[i].basis.x.length()/(20.0/AU_KM)-MOON_RADII[i]*multiplier)<MOON_RADII[i]*multiplier*0.000002,"Rendered moon radius: "+d.id)
		var local = app.moon_nodes[i].position-app.bodies[int(d.parent)].position
		var expected_local = app.satellites.position_km(i,app.sim.epoch_jd+app.sim.elapsed+app.sim.pending)*(20.0/AU_KM)
		# The whole-system render uses float32; selected-parent close-ups below
		# test small orbits without cancellation against a multi-AU origin.
		check(local.distance_to(expected_local)<0.00008,"Local satellite distance remains real: "+d.id)
		check(app.moon_orbits[i].scale==Vector3.ONE,"Orbit mesh has no radius multiplier: "+d.id)

func run():
	app = load("res://main.tscn").instantiate()
	app.settings_path = "user://test-geometry.cfg"
	DirAccess.remove_absolute(app.settings_path)
	root.add_child(app)
	app.playing = false
	app.set_process(false)
	app._system_overview()
	for i in range(8):
		for endpoint in range(2):
			var position = app.sim.kepler(i,app.sim.epoch_jd,PI*endpoint)
			var km = Vector3(position[0],position[1],position[2]).length()*AU_KM
			check(abs(km/(PLANET_RANGES[i][endpoint]*1000000.0)-1.0)<0.015,"Planetary ellipse has the reference physical extent")
	for physical in [false,true]:
		for factor in ([1.0,4.0,5.0,50.0,500.0] if physical else [1.0,4.0,5.0,50.0,150.0,500.0]):
			check_geometry(physical,factor if physical else 1.0,factor)
	check_geometry(false,500.0,500.0)
	app._set_scale_mode(true)
	app._set_distance_compression(1.0)
	var report = {"planets":[],"moons":[]}
	app._system_overview()
	app._update_bodies()
	report["earth_venus_distance_km"] = app.bodies[3].position.distance_to(app.bodies[2].position)*AU_KM/20.0
	for i in range(9):
		report.planets.append({"name":app.NAMES[i],"radius_km":RADII_KM[i],"sun_distance_km":app.bodies[i].position.distance_to(app.bodies[0].position)*AU_KM/20.0})
	for i in range(20):
		var d: Dictionary = app.satellites.data[i]
		app._select(int(d.parent))
		app._update_bodies()
		var km = (app.moon_nodes[i].position-app.bodies[int(d.parent)].position).length()*AU_KM/20.0
		var local = app.satellites.position_km(i,app.sim.epoch_jd)
		check(abs(km-local.length())<MOON_AXES[i]*0.000001,"Focused moon distance in km: "+d.id)
		check(km>=MOON_AXES[i]*(1.0-d.e)*0.999999 and km<=MOON_AXES[i]*(1.0+d.e)*1.000001,"Satellite between periapsis and apoapsis: "+d.id)
		report.moons.append({"name":d.name,"radius_km":MOON_RADII[i],"a_km":MOON_AXES[i],"distance_km":km})
	app._activate_view("galaxy")
	app._update_bodies()
	var samples: Array[Vector3] = []
	for i in range(9):
		for item in app.history:
			samples.append(app._trajectory_point(i,item.day,app._relative_sample_position(i,item.p)))
	app._set_distance_compression(1.0)
	app._set_scale_mode(false)
	for factor in [4.0,5.0,50.0,150.0]:
		app._set_visual_scale(factor,false)
		var sample = 0
		for i in range(9):
			for item in app.history:
				check(app._trajectory_point(i,item.day,app._relative_sample_position(i,item.p))==samples[sample],"Radius mode does not change flight trajectory")
				sample += 1
	app._set_scale_mode(true)
	for compression in [5.0,50.0,500.0]:
		app._set_distance_compression(compression)
		var sample = 0
		for i in range(9):
			for item in app.history:
				var lunar_offset = app.satellites.position_km(0,app.sim.epoch_jd+item.day)*(20.0/AU_KM*0.0121505856) if i==3 else Vector3.ZERO
				var scaled = app._trajectory_point(i,item.day,app._relative_sample_position(i,item.p))
				var original = samples[sample]+lunar_offset
				check(((scaled+lunar_offset)*compression).distance_to(original)<maxf(0.000005,original.length()*0.000001),"Compression preserves the complete flight curve, including its pitch")
				sample += 1
		check(is_equal_approx(app.target_distance,2000.0/compression),"Flight overview follows the compressed scale")
	app.moon_path_buttons.trails.pressed.emit()
	check(app.moon_path_mode=="trails" and app.moon_trail_instance.visible,"Trajectory selector displays satellite trails")
	check(app.moon_orbits.all(func(orbit): return not orbit.visible),"Trails replace closed orbits")
	check(app.moon_trail_instance.mesh.get_surface_count()==20,"Twenty sampled satellite trails")
	for mode in ["galaxy","system"]:
		app._activate_view(mode)
		app._select(4)
		for residual in [0.0,0.137]:
			app.sim.pending = residual
			app._update_bodies()
			for i in range(20):
				var endpoint = app._moon_trajectory_point(i,app.sim.elapsed+app.sim.pending)
				check(endpoint.distance_to(app.moon_nodes[i].position)<0.000001,"Satellite trail meets its live body in every frame")
	app.sim.pending = 0.0
	app._set_distance_compression(1.0)
	app._select(4)
	var reverse = app.Physics.new()
	for j in range(4):
		reverse.step(-0.25)
	for body in [3,4,5,6,7,8]:
		var reconstructed = app._history_relative_position(body,-1.0)
		var expected = app._relative_sample_position(body,reverse.p)
		check(reconstructed.distance_to(expected)*AU_KM<100.0,"Interpolated parent follows its gravitational trajectory")
	# A quarter Phobos orbit must retain its local bend between 2-day parent samples.
	for i in range(20):
		var d: Dictionary = app.satellites.data[i]
		var a = -d.period_days*0.25
		var center = app._trajectory_point(int(d.parent),a,app._history_relative_position(int(d.parent),a))
		var relative = app._moon_trajectory_point(i,a)-center
		check(relative.distance_to(app.satellites.position_km(i,app.sim.epoch_jd+a)*(20.0/AU_KM))<0.00008,"Fast satellite trajectory is resolved independently of planet samples")
	app.moons_toggle.button_pressed = false
	check(not app.moon_trail_instance.visible,"Satellite switch hides trajectories")
	check(app.moon_path_buttons.orbits.disabled and app.moon_path_buttons.trails.disabled,"Path selectors are disabled with satellites hidden")
	app._save_display_settings()
	app.moon_path_mode = "orbits"
	app._load_display_settings()
	check(app.moon_path_mode=="trails" and not app.moons_enabled,"Satellite path preference persists")
	app._set_moons_enabled(true)
	app._activate_view("galaxy")
	app._set_scale_mode(true)
	app._set_distance_compression(50.0)
	app._reset()
	check(app.history.size()==241 and app.moon_trail_instance.visible,"Reset rebuilds visible satellite history")
	check(is_equal_approx(app.target_distance,2000.0),"Reset restores the uncompressed flight camera")
	app.moon_path_buttons.orbits.pressed.emit()
	app._system_overview()
	app._update_bodies()
	check(not app.moon_trail_instance.visible and app.moon_orbits.all(func(orbit): return orbit.visible),"Orbit selector restores closed satellite orbits")
	report["checks"] = checks
	report["failures"] = failures
	FileAccess.open("res://build/scale-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GEOMETRY: ","PASS" if failures==0 else "FAIL"," (",checks," checks; 29 radii, all pair distances, both scale modes and trajectories)")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test-geometry.cfg")
	quit(failures)
