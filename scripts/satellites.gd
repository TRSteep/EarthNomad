extends RefCounted
## Approximate two-body satellite orbits, independent of the planetary integrator.
var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/satellites.json"))
const OBLIQUITY = 23.4392911
var orbit_bases: Array[Basis] = []

func _init():
	# Fixed mean elements: compute their frame once, not for every trail vertex.
	for i in range(data.size()):
		var d: Dictionary = data[i]
		var node = deg_to_rad(d.node_deg)
		var arg = deg_to_rad(d.arg_deg)
		var inc = deg_to_rad(d.inclination_deg)
		var x = Vector3(cos(arg)*cos(node)-sin(arg)*sin(node)*cos(inc),cos(arg)*sin(node)+sin(arg)*cos(node)*cos(inc),sin(arg)*sin(inc))
		var y = Vector3(-sin(arg)*cos(node)-cos(arg)*sin(node)*cos(inc),-sin(arg)*sin(node)+cos(arg)*cos(node)*cos(inc),cos(arg)*sin(inc))
		orbit_bases.append(frame(i)*Basis(x,y,x.cross(y)))

static func equatorial_to_scene(v: Vector3) -> Vector3:
	var e = deg_to_rad(OBLIQUITY)
	return Vector3(v.x,-sin(e)*v.y+cos(e)*v.z,-(cos(e)*v.y+sin(e)*v.z))

static func pole(ra: float, dec: float) -> Vector3:
	return equatorial_to_scene(Vector3(cos(deg_to_rad(dec))*cos(deg_to_rad(ra)),cos(deg_to_rad(dec))*sin(deg_to_rad(ra)),sin(deg_to_rad(dec))))

func frame(index: int) -> Basis:
	var d: Dictionary = data[index]
	if d.reference == "ecliptic":
		return Basis(Vector3.RIGHT,Vector3(0,0,-1),Vector3.UP)
	var z = pole(d.pole_ra_deg,d.pole_dec_deg).normalized()
	if d.reference == "equatorial":
		# Uranus's regular moons follow its spin, opposite its IAU north pole.
		z = -pole(257.311,-15.175) if int(d.parent)==7 else pole(299.36,43.46)
	var x = equatorial_to_scene(Vector3(0,0,1)).cross(z).normalized()
	return Basis(x,z.cross(x).normalized(),z)

func position_km(index: int, jd: float, path_angle: float = NAN) -> Vector3:
	var d: Dictionary = data[index]
	var m = wrapf(deg_to_rad(d.mean_deg)+TAU*(jd-d.epoch_jd)/d.period_days,-PI,PI)
	var eccentric = m
	for iteration in range(12):
		var correction = (eccentric-d.e*sin(eccentric)-m)/(1.0-d.e*cos(eccentric))
		eccentric -= correction
		if abs(correction)<1e-12:
			break
	if not is_nan(path_angle):
		eccentric = path_angle
	var x = d.a_km*(cos(eccentric)-d.e)
	var y = d.a_km*sqrt(1.0-d.e*d.e)*sin(eccentric)
	return orbit_bases[index]*Vector3(x,y,0.0)

func indices(parent: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(data.size()):
		if int(data[i].parent)==parent:
			result.append(i)
	return result

func orbit_normal(index: int) -> Vector3:
	var d: Dictionary = data[index]
	var node = deg_to_rad(d.node_deg)
	var inc = deg_to_rad(d.inclination_deg)
	return (frame(index)*Vector3(sin(node)*sin(inc),-cos(node)*sin(inc),cos(inc))).normalized()
