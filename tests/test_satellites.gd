extends SceneTree
const Satellites = preload("res://scripts/satellites.gd")
var failures = 0

func check(condition: bool, message: String):
	if not condition:
		push_error(message)
		failures += 1

func _init():
	var model = Satellites.new()
	check(model.data.size()==20,"Twenty satellites")
	check(model.indices(1).is_empty() and model.indices(2).is_empty(),"No fictitious Mercury/Venus moons")
	for i in range(model.data.size()):
		var d: Dictionary = model.data[i]
		var basis = model.frame(i)
		check(abs(basis.determinant()-1.0)<0.00001,"Right handed satellite frame: "+d.id)
		var a = model.position_km(i,2451545.0,0.0).length()
		var b = model.position_km(i,2451545.0,PI).length()
		check(abs(a-d.a_km*(1.0-d.e))<d.a_km*0.000002,"Periapsis: "+d.id)
		check(abs(b-d.a_km*(1.0+d.e))<d.a_km*0.000002,"Apoapsis: "+d.id)
		var start = model.position_km(i,2461338.5)
		var end = model.position_km(i,2461338.5+d.period_days)
		check(start.distance_to(end)<d.a_km*0.00001,"Orbital period closes: "+d.id)
		var h = d.period_days*0.00001
		var velocity = (model.position_km(i,2461338.5+h)-model.position_km(i,2461338.5-h))/(2.0*h)
		check(start.cross(velocity).normalized().dot(model.orbit_normal(i))>0.999,"Orbit normal: "+d.id)
		check(ResourceLoader.exists("res://assets/textures/moons/%s.jpg" % d.id),"Texture: "+d.id)
	check(model.data[0].radius_km==1737.4,"Lunar radius")
	check(abs(model.data[0].period_days-27.321661)<0.00001,"Lunar sidereal period")
	var triton = model.data.size()-1
	check(model.data[triton].id=="triton" and model.orbit_normal(triton).dot(model.frame(triton).z)<0.0,"Retrograde Triton")
	var ariel = model.indices(7)[0]
	check(model.orbit_normal(ariel).dot(-Satellites.pole(257.311,-15.175))>0.999,"Uranian equatorial frame follows retrograde planetary spin")
	check(model.frame(triton).z.dot(Satellites.pole(299.36,43.46))>0.999,"Triton uses Neptune equator")
	print("SATELLITES: ","PASS" if failures==0 else "FAIL")
	quit(failures)
