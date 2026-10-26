extends RefCounted
## AU, days, solar masses. All integration storage is IEEE float64.
## Vector3 is deliberately restricted to the final rendering boundary.
const G = 0.0002959122082855911
const AU_KM = 149597870.7
const GALACTIC_RADIUS_LY = 26000.0
const GALACTIC_RADIUS_AU = GALACTIC_RADIUS_LY * 63241.077
const GALACTIC_PERIOD_DAYS = 230e6 * 365.25
const STEP = 0.25
const MASSES = [1.0, 1.660120e-7, 2.4478383e-6, 3.0404326e-6, 3.227151e-7, 9.547919e-4, 2.858856e-4, 4.366244e-5, 5.151389e-5]
var p = PackedFloat64Array()
var v = PackedFloat64Array()
var acc = PackedFloat64Array()
var elapsed = 0.0
var pending = 0.0
var epoch_jd = 2461338.5
var elements: Array = []

func _init():
	elements = JSON.parse_string(FileAccess.get_file_as_string("res://assets/elements.json"))
	reset()

func kepler(index: int, jd: float, path_angle: float = NAN) -> PackedFloat64Array:
	var row: Dictionary = elements[index]
	var t = (jd - 2451545.0) / 36525.0
	var el = PackedFloat64Array()
	for k in range(6):
		el.append(float(row.elements[k]) + float(row.rates[k]) * t)
	var a = el[0]
	var e = el[1]
	var inc = deg_to_rad(el[2])
	var node = deg_to_rad(el[5])
	var arg = deg_to_rad(el[4] - el[5])
	var m = wrapf(deg_to_rad(el[3] - el[4]), -PI, PI)
	var eccentric = m
	for iteration in range(12):
		var correction = (eccentric - e * sin(eccentric) - m) / (1.0 - e * cos(eccentric))
		eccentric -= correction
		if abs(correction) < 1e-14:
			break
	if not is_nan(path_angle):
		eccentric = path_angle
	var x = a * (cos(eccentric) - e)
	var y = a * sqrt(1.0 - e * e) * sin(eccentric)
	var ex = (cos(arg)*cos(node) - sin(arg)*sin(node)*cos(inc))*x + (-sin(arg)*cos(node)-cos(arg)*sin(node)*cos(inc))*y
	var ey = (cos(arg)*sin(node) + sin(arg)*cos(node)*cos(inc))*x + (-sin(arg)*sin(node)+cos(arg)*cos(node)*cos(inc))*y
	var ez = sin(arg)*sin(inc)*x + cos(arg)*sin(inc)*y
	return PackedFloat64Array([ex, ez, -ey])

func reset():
	p.resize(27)
	v.resize(27)
	p.fill(0.0)
	v.fill(0.0)
	elapsed = 0.0
	pending = 0.0
	for i in range(1, 9):
		var pos = kepler(i - 1, epoch_jd)
		var before = kepler(i - 1, epoch_jd - 0.01)
		var after = kepler(i - 1, epoch_jd + 0.01)
		for k in range(3):
			p[i*3+k] = pos[k]
			v[i*3+k] = (after[k] - before[k]) / 0.02
	# Transform heliocentric initial states into a stationary barycentric frame.
	var total = 0.0
	for mass in MASSES:
		total += mass
	for k in range(3):
		var center = 0.0
		var momentum = 0.0
		for i in range(9):
			center += p[i*3+k] * MASSES[i]
			momentum += v[i*3+k] * MASSES[i]
		for i in range(9):
			p[i*3+k] -= center / total
			v[i*3+k] -= momentum / total
	acc = acceleration()

func acceleration() -> PackedFloat64Array:
	var result = PackedFloat64Array()
	result.resize(27)
	result.fill(0.0)
	for i in range(9):
		for j in range(i+1, 9):
			var dx = p[j*3] - p[i*3]
			var dy = p[j*3+1] - p[i*3+1]
			var dz = p[j*3+2] - p[i*3+2]
			var r2 = dx*dx + dy*dy + dz*dz
			var factor = G / (r2 * sqrt(r2))
			var d = [dx, dy, dz]
			for k in range(3):
				result[i*3+k] += d[k] * factor * MASSES[j]
				result[j*3+k] -= d[k] * factor * MASSES[i]
	return result

func step(dt: float = STEP):
	for k in range(27):
		p[k] += v[k]*dt + 0.5*acc[k]*dt*dt
	var next = acceleration()
	for k in range(27):
		v[k] += 0.5*(acc[k]+next[k])*dt
	acc = next
	elapsed += dt

func position(i: int) -> Vector3:
	# Smooth sub-step rendering; never feeds back into the integrator.
	return Vector3(p[3*i]+v[3*i]*pending, p[3*i+1]+v[3*i+1]*pending, p[3*i+2]+v[3*i+2]*pending)

func relative_position(i: int, origin: int) -> Vector3:
	return Vector3(p[3*i]-p[3*origin]+(v[3*i]-v[3*origin])*pending, p[3*i+1]-p[3*origin+1]+(v[3*i+1]-v[3*origin+1])*pending, p[3*i+2]-p[3*origin+2]+(v[3*i+2]-v[3*origin+2])*pending)

func energy() -> float:
	var value = 0.0
	for i in range(9):
		for k in range(3):
			value += 0.5 * MASSES[i] * v[i*3+k]*v[i*3+k]
		for j in range(i+1, 9):
			var r2 = 0.0
			for k in range(3):
				r2 += pow(p[i*3+k]-p[j*3+k], 2)
			value -= G * MASSES[i]*MASSES[j] / sqrt(r2)
	return value

static func galactic_offset(days: float) -> Vector3:
	# Idealized circular galactic orbit, not a measured Solar ephemeris.
	# 26,000 ly; period 230 Myr. Stable half-angle form avoids cancellation.
	return galactic_arc_delta(TAU*days/GALACTIC_PERIOD_DAYS)

static func galactic_arc_delta(angle: float, phase: float = 0.0) -> Vector3:
	# A local chord starting at phase, computed without subtracting two ~1e9 AU
	# positions. This preserves the small visible arc on a planetary-scale view.
	var radial = -2.0*pow(sin(angle*0.5),2)
	var tangent = sin(angle)
	var inward = GALACTIC_RADIUS_AU*(cos(phase)*radial-sin(phase)*tangent)
	var along = GALACTIC_RADIUS_AU*(sin(phase)*radial+cos(phase)*tangent)
	# Illustrative orientation: velocity 60 degrees above the ecliptic.
	return Vector3(inward, along * sin(PI/3.0), along * cos(PI/3.0))
