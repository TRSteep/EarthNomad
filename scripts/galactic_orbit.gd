extends Node3D
## One orbit, two scales: stable local arc and a separate galactocentric map.
const Physics = preload("res://scripts/physics.gd")
const ORBIT_COLOR = Color("cf8cff")
const MAP_RADIUS = 80.0
const MAP_LAYER = 2
var local_arc = MeshInstance3D.new()
var map_root = Node3D.new()
var map_orbit = MeshInstance3D.new()
var sun_marker: MeshInstance3D
var direction_arrow = MeshInstance3D.new()
var map_labels: Array[Label3D] = []
var local_key: Array = []

func _ready():
	add_child(local_arc)
	local_arc.material_override = line_material()
	add_child(map_root)
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(513):
		mesh.surface_set_color(ORBIT_COLOR)
		mesh.surface_add_vertex(map_position(TAU*float(i)/512.0))
	mesh.surface_end()
	map_orbit.mesh = mesh
	map_orbit.material_override = line_material()
	map_orbit.layers = MAP_LAYER
	map_root.add_child(map_orbit)
	sun_marker = marker(0.85,Color("ffd284"))
	marker(0.65,Color("b2e7ef"))
	map_root.add_child(direction_arrow)
	direction_arrow.layers = MAP_LAYER
	direction_arrow.material_override = line_material()
	map_labels.append(map_label("Солнечная система",Color("ffd284")))
	map_labels.append(map_label("Центр Млечного Пути",Color("b2e7ef")))
	map_labels.append(map_label("Орбита Солнца",ORBIT_COLOR))
	map_labels[1].position = Vector3.UP*5.0
	map_labels[2].position = map_position(PI*1.4)
	map_root.visible = false
	local_arc.visible = false

static func map_position(phase: float) -> Vector3:
	return Vector3(cos(phase),sin(phase)*sin(PI/3.0),sin(phase)*cos(PI/3.0))*MAP_RADIUS

func line_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func marker(radius: float, color: Color) -> MeshInstance3D:
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius*2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var instance = MeshInstance3D.new()
	instance.mesh = sphere
	instance.material_override = material
	instance.layers = MAP_LAYER
	map_root.add_child(instance)
	return instance

func map_label(caption: String, color: Color) -> Label3D:
	var label = Label3D.new()
	label.text = caption
	label.modulate = color
	label.font_size = 36
	label.pixel_size = 0.13
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.layers = MAP_LAYER
	map_root.add_child(label)
	return label

func update_local(sun: Vector3, day: float, units_per_au: float, extent: float):
	local_arc.position = sun
	var key = [day,units_per_au,extent]
	if key==local_key:
		return
	local_key = key
	var radius = Physics.GALACTIC_RADIUS_AU*units_per_au
	var span = minf(PI,extent/radius)
	var phase = TAU*day/Physics.GALACTIC_PERIOD_DAYS
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(129):
		var angle = lerpf(-span,span,float(i)/128.0)
		mesh.surface_set_color(Color(ORBIT_COLOR,0.85))
		mesh.surface_add_vertex(Physics.galactic_arc_delta(angle,phase)*units_per_au)
	mesh.surface_end()
	local_arc.mesh = mesh

func update_map(day: float, show_labels: bool):
	var phase = TAU*day/Physics.GALACTIC_PERIOD_DAYS
	sun_marker.position = map_position(phase)
	map_labels[0].position = sun_marker.position+Vector3.UP*5.0
	for label in map_labels:
		label.visible = show_labels
	# Arrow tangent to the same orbit, indicating the actual direction of travel.
	var tangent = Vector3(-sin(phase),cos(phase)*sin(PI/3.0),cos(phase)*cos(PI/3.0))
	var radial = sun_marker.position.normalized()
	var tip = sun_marker.position+tangent*8.0
	var points = [sun_marker.position,tip,tip,tip-tangent*3.0+radial*1.8,tip,tip-tangent*3.0-radial*1.8]
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point in points:
		mesh.surface_set_color(Color("ffd284"))
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	direction_arrow.mesh = mesh
