extends SceneTree
const Physics = preload("res://scripts/physics.gd")
var failures = 0

func check(condition: bool, message: String):
	if not condition:
		push_error(message)
		failures += 1

func _init():
	var sim = Physics.new()
	var original_p = sim.p.duplicate()
	var original_v = sim.v.duplicate()
	var energy = sim.energy()
	# Independent published J2000 heliocentric Earth-Moon barycenter position.
	var earth = sim.kepler(2,2451545.0)
	check(abs(earth[0]-(-0.177171))<0.00002,"J2000 Earth X")
	check(abs(earth[2]-(-0.967214))<0.00002,"J2000 Earth Z")
	# Newton's third law / barycenter frame.
	for k in range(3):
		var momentum = 0.0
		var net_force = 0.0
		for i in range(9):
			momentum += Physics.MASSES[i]*sim.v[i*3+k]
			net_force += Physics.MASSES[i]*sim.acc[i*3+k]
		check(abs(momentum)<1e-16,"Initial momentum")
		check(abs(net_force)<1e-16,"Newton third law")
	var peak = 0.0
	for i in range(14610):
		sim.step()
		if i % 100 == 0:
			peak = maxf(peak,abs((sim.energy()-energy)/energy))
	check(peak<0.00001,"10-year energy drift: %s" % peak)
	for i in range(14610):
		sim.step(-Physics.STEP)
	var reverse_error = 0.0
	for k in range(27):
		reverse_error = maxf(reverse_error,abs(sim.p[k]-original_p[k]))
		check(abs(sim.v[k]-original_v[k])<1e-8,"Velocity reversibility")
	check(reverse_error<1e-7,"Position reversibility")
	# Expected galactic speed for 26,000 ly / 230 Myr ~213 km/s.
	var speed = Physics.galactic_offset(1.0).length()*Physics.AU_KM/86400.0
	check(speed>200.0 and speed<230.0,"Galactic unit conversion")
	check(Physics.galactic_offset(0.0)==Vector3.ZERO,"Stable galactic origin")
	print("10-year peak relative energy error: ",peak)
	print("20-year forward/backward position error (AU): ",reverse_error)
	print("Galactic speed (km/s): ",speed)
	print("PHYSICS: ","PASS" if failures == 0 else "FAIL")
	quit(failures)
