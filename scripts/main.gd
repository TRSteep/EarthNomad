extends Node3D

const Physics = preload("res://scripts/physics.gd")
const Satellites = preload("res://scripts/satellites.gd")
const IDS = ["sun", "mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
const NAMES = ["Солнце", "Меркурий", "Венера", "Земля", "Марс", "Юпитер", "Сатурн", "Уран", "Нептун"]
const KINDS = ["ЗВЕЗДА · G2V", "КАМЕННАЯ ПЛАНЕТА", "КАМЕННАЯ ПЛАНЕТА", "НАШ ДОМ", "КАМЕННАЯ ПЛАНЕТА", "ГАЗОВЫЙ ГИГАНТ", "ГАЗОВЫЙ ГИГАНТ", "ЛЕДЯНОЙ ГИГАНТ", "ЛЕДЯНОЙ ГИГАНТ"]
# Mean radii (JPL); the Sun uses the IAU nominal photospheric radius.
const RADII = [695700.0,2439.4,6051.8,6371.0084,3389.5,69911.0,58232.0,25362.0,24622.0]
const TILTS = [7.25,0.034,2.64,23.44,25.19,3.13,26.73,82.23,28.32]
const ROTATIONS = [609.12,1407.6,-5832.5,23.9345,24.6229,9.925,10.656,-17.24,16.11]
const COLORS = [Color("ffd69a"),Color("b4afa9"),Color("dec69b"),Color("71c9ec"),Color("dc9473"),Color("d7b190"),Color("e6d1a2"),Color("9cdfdf"),Color("658eee")]
const SCALE = 20.0
const KM_TO_SCENE = SCALE/Physics.AU_KM
const MAX_DISTANCE_COMPRESSION = 500.0
const VISUAL_SCALE_MIN = 1.0
const VISUAL_SCALE_MAX = 500.0
const SUN_SCALE_MAX = 50.0
const DEFAULT_PLANET_SCALE = 10.0
const DEFAULT_SUN_SCALE = 10.0
const DEFAULT_MOON_SCALE = 10.0
const DEFAULT_DISTANCE_COMPRESSION = 50.0
const DISPLAY_SETTINGS_VERSION = 7
const MOON_ORBIT_DASHES = 96
const MOON_TRAIL_PERIODS = 4.0
const MOON_TRAIL_STEPS = 256
const SETTINGS_PATH = "user://display.cfg"
const SPEEDS = [0.000011574074,0.0416667,1.0,10.0,40.0,120.0]
const SPEED_LABELS = ["Реальное время", "1 час / сек", "1 день / сек", "10 дней / сек", "40 дней / сек", "120 дней / сек"]
var sim = Physics.new()
var satellites = Satellites.new()
var moon_nodes: Array[Node3D] = []
var moon_materials: Array[ShaderMaterial] = []
var moon_labels: Array[Label3D] = []
var moon_orbits: Array[MeshInstance3D] = []
var ring_nodes: Dictionary = {}
var selected_moon = -1
var satellite_system_view = false
var moon_picker: OptionButton
var satellite_system_button: Button
var bodies: Array[Node3D] = []
var spins: Array[Node3D] = []
var materials: Array[ShaderMaterial] = []
var atmospheres: Dictionary = {}
var labels: Array[Label3D] = []
var orbit_root = Node3D.new()
var trail_instance = MeshInstance3D.new()
var moon_trail_instance = MeshInstance3D.new()
var moon_trail_key: Array = []
var history: Array = []
var last_sample = 0.0
var trail_clock = 0.0
var camera = Camera3D.new()
var selected = 3
var overview = false
var galaxy = false
var view_mode = "system"
var actual_size = false
var distance_compression = 1.0
var galaxy_planet_scale = DEFAULT_PLANET_SCALE
var galaxy_sun_scale = DEFAULT_SUN_SCALE
var galaxy_moon_scale = DEFAULT_MOON_SCALE
var helio_planet_scale = DEFAULT_PLANET_SCALE
var helio_sun_scale = DEFAULT_SUN_SCALE
var helio_moon_scale = DEFAULT_MOON_SCALE
var labels_enabled = true
var moons_enabled = true
var moon_path_mode = "orbits"
var playing = true
var speed_index = 1
var yaw = 0.0
var pitch = 0.22
var distance = 4.2
var target_distance = 4.2
var touches: Dictionary = {}
var ui = CanvasLayer.new()
var title_label: Label
var detail_label: Label
var clock_label: Label
var frame_label: Label
var pause_button: Button
var select_buttons: Array[Button] = []
var speed_select: OptionButton
var initial_energy = 0.0
var capture_frames = 0
var startup_args = OS.get_cmdline_user_args()
var texture_cache: Dictionary = {}
var size_panel: PanelContainer
var planet_scale_slider: HSlider
var sun_scale_slider: HSlider
var moon_scale_slider: HSlider
var planet_scale_input: SpinBox
var sun_scale_input: SpinBox
var moon_scale_input: SpinBox
var scale_note: Label
var settings_timer: Timer
var settings_path = SETTINGS_PATH
var visual_preset_path = ""
var labels_toggle: CheckButton
var scale_heading: Label
var navigation_box: VBoxContainer
var view_buttons: Dictionary = {}
var moons_toggle: CheckButton
var moon_path_buttons: Dictionary = {}
var physical_mode_button: Button
var visual_mode_button: Button
var adjust_controls: VBoxContainer
var distance_controls: HBoxContainer
var compression_slider: HSlider
var compression_label: Label

func _ready():
	_load_display_settings()
	settings_timer = Timer.new()
	settings_timer.one_shot = true
	settings_timer.wait_time = 0.4
	settings_timer.timeout.connect(_save_display_settings)
	add_child(settings_timer)
	DisplayServer.window_set_title("EarthNomad · Solar Odyssey · v" + str(ProjectSettings.get_setting("application/config/version")))
	initial_energy = sim.energy()
	_build_environment()
	_build_bodies()
	_build_moons()
	_build_orbits()
	add_child(trail_instance)
	add_child(moon_trail_instance)
	_build_ui()
	_select(3)
	for argument in startup_args:
		if argument.begins_with("--planet="):
			_select(clampi(int(argument.get_slice("=",1)),0,8))
		if argument.begins_with("--moon="):
			_select_moon(clampi(int(argument.get_slice("=",1)),0,satellites.data.size()-1))
	if "--satellites" in startup_args:
		_satellite_system()
	if "--overview" in startup_args:
		_set_overview()
	if "--galaxy" in startup_args:
		_activate_view("galaxy")
	if "--inner" in startup_args:
		_activate_view("inner")
	if "--physical" in startup_args:
		_set_scale_mode(true)
	if "--moon-trails" in startup_args:
		_set_moon_path_mode("trails")
	for argument in startup_args:
		if argument.begins_with("--follow="):
			_select(clampi(int(argument.get_slice("=",1)),0,8))
	_update_bodies()
	_update_camera(1.0)
	if moon_path_mode=="trails":
		_seed_history()
	_refresh_paths()
	if "--capture" in startup_args:
		playing = false
		pause_button.text = "▶  Продолжить"

func _build_environment():
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = PanoramaSkyMaterial.new()
	sky_mat.panorama = _texture("res://assets/textures/8k_stars_milky_way.jpg")
	sky_mat.energy_multiplier = 0.28
	sky.sky_material = sky_mat
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world = WorldEnvironment.new()
	world.environment = env
	add_child(world)
	camera.fov = 48.0
	camera.near = 0.001
	camera.far = 20000.0
	add_child(camera)
	camera.make_current()

func _texture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	var texture: Texture2D = load(path)
	if OS.has_feature("mobile") and texture.get_width() > 2048:
		var data = texture.get_image()
		if data.is_compressed():
			data.decompress()
		data.resize(2048,1024,Image.INTERPOLATE_LANCZOS)
		data.generate_mipmaps()
		texture = ImageTexture.create_from_image(data)
	texture_cache[path] = texture
	return texture

func _sphere(radius: float, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 96 if not OS.has_feature("mobile") else 48
	mesh.rings = 48 if not OS.has_feature("mobile") else 24
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _build_bodies():
	for i in range(9):
		var body = Node3D.new()
		body.name = IDS[i]
		add_child(body)
		bodies.append(body)
		var axis = Node3D.new()
		axis.rotation.z = deg_to_rad(TILTS[i])
		if i in [6,7,8]:
			var pole = Satellites.pole(40.589,83.537) if i==6 else Satellites.pole(257.311,-15.175)
			if i==8:
				pole = Satellites.pole(299.36,43.46)
			axis.quaternion = Quaternion(Vector3.UP,pole.normalized())
		body.add_child(axis)
		var spin = Node3D.new()
		axis.add_child(spin)
		spins.append(spin)
		var material = ShaderMaterial.new()
		material.shader = load("res://shaders/planet.gdshader")
		var texture_path = "res://assets/textures/%s.jpg" % IDS[i]
		if ResourceLoader.exists(texture_path):
			material.set_shader_parameter("surface_map", _texture(texture_path))
		else:
			push_error("Missing surface texture: " + texture_path)
		material.set_shader_parameter("earth", i == 3)
		material.set_shader_parameter("star", i == 0)
		if i == 3:
			material.set_shader_parameter("surface_map",_texture("res://assets/textures/8k_earth_daymap.jpg"))
			material.set_shader_parameter("night_map",_texture("res://assets/textures/8k_earth_nightmap.jpg"))
			material.set_shader_parameter("cloud_map",_texture("res://assets/textures/8k_earth_clouds.jpg"))
			var cloud = ShaderMaterial.new()
			cloud.shader = load("res://shaders/clouds.gdshader")
			cloud.set_shader_parameter("cloud_map",_texture("res://assets/textures/8k_earth_clouds.jpg"))
			_sphere(1.003,cloud,spin)
			atmospheres[30] = cloud
		if i == 2 and ResourceLoader.exists("res://assets/textures/venus_clouds.jpg"):
			material.set_shader_parameter("surface_map",_texture("res://assets/textures/venus_clouds.jpg"))
		materials.append(material)
		_sphere(1.0, material, spin)
		if i in [0,2,3,7,8]:
			var atmosphere = ShaderMaterial.new()
			atmosphere.shader = load("res://shaders/atmosphere.gdshader")
			atmosphere.set_shader_parameter("tint", Vector3(COLORS[i].r,COLORS[i].g,COLORS[i].b))
			atmosphere.set_shader_parameter("corona", i == 0)
			_sphere(1.5 if i == 0 else 1.018, atmosphere, axis)
			atmospheres[i] = atmosphere
		if i in [6,7]:
			_build_rings(axis,i)
		var label = Label3D.new()
		label.text = NAMES[i]
		label.font_size = 40
		label.pixel_size = 0.055
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = COLORS[i]
		add_child(label)
		labels.append(label)

func _build_rings(parent: Node3D, planet: int):
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner = 1.10
	var outer = 2.42 if planet==6 else 4.25
	var segments = 512 if not OS.has_feature("mobile") else 256
	for j in range(segments):
		var a = TAU*float(j)/segments
		var b = TAU*float(j+1)/segments
		var inner_a = Vector3(cos(a),0,sin(a))*inner
		var outer_a = Vector3(cos(a),0,sin(a))*outer
		var inner_b = Vector3(cos(b),0,sin(b))*inner
		var outer_b = Vector3(cos(b),0,sin(b))*outer
		for point in [inner_a,outer_a,outer_b,inner_a,outer_b,inner_b]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/rings.gdshader")
	material.set_shader_parameter("ring_kind",1 if planet==6 else 2)
	materials[planet].set_shader_parameter("ring_kind",1 if planet==6 else 2)
	instance.material_override = material
	parent.add_child(instance)
	atmospheres[planet*10] = material
	ring_nodes[planet] = instance

func _build_moons():
	for i in range(satellites.data.size()):
		var d: Dictionary = satellites.data[i]
		var body = Node3D.new()
		body.name = d.id
		add_child(body)
		moon_nodes.append(body)
		var material = ShaderMaterial.new()
		material.shader = load("res://shaders/planet.gdshader")
		material.set_shader_parameter("surface_map",_texture("res://assets/textures/moons/%s.jpg" % d.id))
		material.set_shader_parameter("haze",d.id=="titan")
		moon_materials.append(material)
		var surface = _sphere(1.0,material,body)
		if d.id in ["phobos","deimos"]:
			surface.scale = Vector3(1.25,0.92,0.83)
		var label = Label3D.new()
		label.text = d.name
		label.font_size = 32
		label.pixel_size = 0.025
		label.modulate = Color("c3d2df")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		moon_labels.append(label)
		var mesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for k in range(MOON_ORBIT_DASHES):
			for fraction in [0.0,0.58]:
				mesh.surface_set_color(Color(0.4,0.6,0.75,0.32))
				var angle = TAU*(float(k)+fraction)/float(MOON_ORBIT_DASHES)
				mesh.surface_add_vertex(satellites.position_km(i,sim.epoch_jd,angle)*KM_TO_SCENE)
		mesh.surface_end()
		var orbit = MeshInstance3D.new()
		orbit.mesh = mesh
		orbit.material_override = _line_material()
		add_child(orbit)
		moon_orbits.append(orbit)

func _moon_radius(index: int) -> float:
	var d: Dictionary = satellites.data[index]
	return d.radius_km*KM_TO_SCENE*_moon_scale()

func _focus_radius() -> float:
	return _moon_radius(selected_moon) if selected_moon>=0 else _radius(selected)

func _system_extent() -> float:
	var extent = _radius(selected)*2.5
	for i in satellites.indices(selected):
		var d: Dictionary = satellites.data[i]
		extent = maxf(extent,d.a_km*(1.0+d.e)*KM_TO_SCENE+_moon_radius(i))
	return extent

func _refresh_moon_picker():
	moon_picker.clear()
	moon_picker.add_item("Выбрать спутник…",1000)
	for i in satellites.indices(selected):
		moon_picker.add_item(satellites.data[i].name,i)
	moon_picker.disabled = not moons_enabled or moon_picker.item_count==1
	satellite_system_button.disabled = moon_picker.disabled
	if selected_moon>=0:
		moon_picker.select(moon_picker.get_item_index(selected_moon))

func _select_moon(index: int):
	if not moons_enabled:
		_set_moons_enabled(true)
	selected = int(satellites.data[index].parent)
	selected_moon = index
	satellite_system_view = false
	overview = false
	_sync_scale_controls()
	_refresh_moon_picker()
	if not galaxy:
		distance = _focus_radius()*4.5
		target_distance = distance
		var p = sim.relative_position(selected,0)
		yaw = atan2(-p.x,-p.z)+0.55
		pitch = 0.22
	_ensure_follow_clearance()
	for i in range(select_buttons.size()):
		select_buttons[i].button_pressed = i==selected

func _satellite_system():
	if satellites.indices(selected).is_empty():
		return
	if not moons_enabled:
		_set_moons_enabled(true)
	selected_moon = -1
	satellite_system_view = true
	overview = false
	_refresh_moon_picker()
	target_distance = _system_extent()*2.8
	distance = target_distance
	pitch = 0.55

func _update_moons():
	var jd = sim.epoch_jd+sim.elapsed+sim.pending
	# The planetary integrator contains Earth+Moon mass once, at their barycenter.
	# Split their local display positions; do not add lunar mass to the integrator again.
	var earth_moon = satellites.position_km(0,jd)*KM_TO_SCENE
	bodies[3].position -= earth_moon*0.0121505856
	for i in range(moon_nodes.size()):
		var d: Dictionary = satellites.data[i]
		var parent = int(d.parent)
		var relative = satellites.position_km(i,jd)*KM_TO_SCENE
		moon_nodes[i].visible = moons_enabled
		moon_orbits[i].visible = moons_enabled and moon_path_mode=="orbits"
		moon_orbits[i].position = bodies[parent].position
		moon_orbits[i].scale = Vector3.ONE
		moon_nodes[i].position = bodies[parent].position+relative
		# Orient from the exact local offset, avoiding cancellation for tiny moons
		# when their parent is far from the floating origin.
		moon_nodes[i].basis = Basis.looking_at(-relative,satellites.orbit_normal(i)).scaled(Vector3.ONE*_moon_radius(i))
		var light = (-sim.relative_position(parent,0)).normalized()
		moon_materials[i].set_shader_parameter("sun_direction",light)
		moon_materials[i].set_shader_parameter("parent_center",bodies[parent].position)
		moon_materials[i].set_shader_parameter("parent_radius",_radius(parent))
		moon_labels[i].position = moon_nodes[i].position+Vector3.UP*(_moon_radius(i)+distance*0.008)
		moon_labels[i].scale = Vector3.ONE*maxf(distance,0.000001)*0.025

func _line_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _build_orbits():
	add_child(orbit_root)
	for i in range(1,9):
		var mesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for j in range(361):
			var p = sim.kepler(i-1,sim.epoch_jd,TAU*float(j)/360.0)
			mesh.surface_set_color(Color(COLORS[i],0.20))
			mesh.surface_add_vertex(Vector3(p[0],p[1],p[2])*SCALE)
		mesh.surface_end()
		var instance = MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _line_material()
		orbit_root.add_child(instance)

func _radius(i: int) -> float:
	var multiplier = _sun_scale() if i == 0 else _planet_scale()
	return RADII[i]*KM_TO_SCENE*multiplier

func _interplanet_scale() -> float:
	return 1.0/distance_compression

func _planet_scale() -> float:
	return galaxy_planet_scale if galaxy else helio_planet_scale

func _sun_scale() -> float:
	return galaxy_sun_scale if galaxy else helio_sun_scale

func _moon_scale() -> float:
	return galaxy_moon_scale if galaxy else helio_moon_scale

func _validated_scale(value: Variant, fallback: float, maximum: float = VISUAL_SCALE_MAX) -> float:
	if not (value is float or value is int):
		return fallback
	var number = float(value)
	return clampf(number,VISUAL_SCALE_MIN,maximum) if is_finite(number) else fallback

func _load_display_settings():
	# Every launch starts with the requested sizes, even with an older config.
	_restore_default_sizes()
	var settings = ConfigFile.new()
	if settings.load(settings_path) == OK:
		var saved_labels = settings.get_value("display","labels_enabled",true)
		labels_enabled = saved_labels if saved_labels is bool else true
		var saved_moons = settings.get_value("display","moons_enabled",true)
		moons_enabled = saved_moons if saved_moons is bool else true
		var saved_path = settings.get_value("display","moon_path_mode","orbits")
		moon_path_mode = saved_path if saved_path in ["orbits","trails"] else "orbits"

func _read_visual_preset() -> Dictionary:
	var config = ConfigFile.new()
	var path = visual_preset_path
	if path.is_empty():
		path = "res://visual.cfg" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("visual.cfg")
	if config.load(path)!=OK:
		config.load("res://visual.cfg")
	return {
		"planets":_validated_scale(config.get_value("sizes","planets",DEFAULT_PLANET_SCALE),DEFAULT_PLANET_SCALE),
		"sun":_validated_scale(config.get_value("sizes","sun",DEFAULT_SUN_SCALE),DEFAULT_SUN_SCALE,SUN_SCALE_MAX),
		"moons":_validated_scale(config.get_value("sizes","moons",DEFAULT_MOON_SCALE),DEFAULT_MOON_SCALE),
		"compression":_validated_scale(config.get_value("sizes","compression",DEFAULT_DISTANCE_COMPRESSION),DEFAULT_DISTANCE_COMPRESSION,MAX_DISTANCE_COMPRESSION)
	}

func _restore_default_sizes():
	var preset = _read_visual_preset()
	galaxy_planet_scale = preset.planets
	galaxy_sun_scale = preset.sun
	galaxy_moon_scale = preset.moons
	helio_planet_scale = preset.planets
	helio_sun_scale = preset.sun
	helio_moon_scale = preset.moons
	actual_size = preset.planets==1.0 and preset.sun==1.0 and preset.moons==1.0
	distance_compression = preset.compression

func _save_display_settings():
	var settings = ConfigFile.new()
	settings.set_value("display","labels_enabled",labels_enabled)
	settings.set_value("display","moons_enabled",moons_enabled)
	settings.set_value("display","moon_path_mode",moon_path_mode)
	settings.set_value("display","schema",DISPLAY_SETTINGS_VERSION)
	var error = settings.save(settings_path)
	if error != OK:
		push_warning("Unable to save display settings: %s" % error)

func _exit_tree():
	if is_instance_valid(settings_timer) and not settings_timer.is_stopped():
		_save_display_settings()

func _set_visual_scale(value: float, sun: bool):
	var safe = _validated_scale(value,DEFAULT_SUN_SCALE if sun else DEFAULT_PLANET_SCALE,SUN_SCALE_MAX if sun else VISUAL_SCALE_MAX)
	if galaxy:
		if sun:
			galaxy_sun_scale = safe
		else:
			galaxy_planet_scale = safe
	else:
		if sun:
			helio_sun_scale = safe
		else:
			helio_planet_scale = safe
	_sync_scale_controls()
	_ensure_follow_clearance()
	settings_timer.start()

func _set_moon_scale(value: float):
	var safe = _validated_scale(value,DEFAULT_MOON_SCALE)
	if galaxy:
		galaxy_moon_scale = safe
	else:
		helio_moon_scale = safe
	_sync_scale_controls()
	_ensure_follow_clearance()
	settings_timer.start()

func _ensure_follow_clearance():
	if not overview:
		var minimum = _focus_radius()*2.0
		distance = maxf(distance,minimum)
		target_distance = maxf(target_distance,minimum)

func _set_size_control(value: float, kind: String):
	if kind=="moons":
		_set_moon_scale(value)
	else:
		_set_visual_scale(value,kind=="sun")

func _sync_scale_controls():
	actual_size = _planet_scale()==1.0 and _sun_scale()==1.0 and _moon_scale()==1.0
	planet_scale_slider.set_value_no_signal(log(_planet_scale())/log(2.0))
	sun_scale_slider.set_value_no_signal(log(_sun_scale())/log(2.0))
	moon_scale_slider.set_value_no_signal(log(_moon_scale())/log(2.0))
	planet_scale_input.set_value_no_signal(_planet_scale())
	sun_scale_input.set_value_no_signal(_sun_scale())
	moon_scale_input.set_value_no_signal(_moon_scale())
	scale_heading.text = "РАЗМЕР ОБЪЕКТОВ · " + ("ГАЛАКТИКА" if galaxy else "ГЕЛИОЦЕНТРИЧЕСКИЙ ВИД")
	physical_mode_button.set_pressed_no_signal(actual_size)
	visual_mode_button.set_pressed_no_signal(not actual_size)
	# Both presets can be reapplied; Visual reloads its file on every press.
	adjust_controls.visible = true
	distance_controls.visible = true
	compression_slider.set_value_no_signal(distance_compression)
	compression_label.text = "÷ %.1f" % distance_compression
	_layout_scale_panel.call_deferred()

func _set_scale_mode(physical: bool):
	var preset = {"planets":1.0,"sun":1.0,"moons":1.0,"compression":1.0} if physical else _read_visual_preset()
	var previous_scale = _interplanet_scale()
	distance_compression = preset.compression
	_rescale_flight_overview(previous_scale)
	if galaxy:
		galaxy_planet_scale = preset.planets
		galaxy_sun_scale = preset.sun
		galaxy_moon_scale = preset.moons
	else:
		helio_planet_scale = preset.planets
		helio_sun_scale = preset.sun
		helio_moon_scale = preset.moons
	_sync_scale_controls()
	_update_bodies()
	_ensure_follow_clearance()
	_refresh_paths()
	settings_timer.start()

func _set_distance_compression(value: float):
	var previous_scale = _interplanet_scale()
	distance_compression = clampf(value,1.0,MAX_DISTANCE_COMPRESSION) if is_finite(value) else 1.0
	_rescale_flight_overview(previous_scale)
	_sync_scale_controls()
	_update_bodies()
	_refresh_paths()

func _rescale_flight_overview(previous_scale: float):
	if galaxy and overview:
		var ratio = _interplanet_scale()/previous_scale
		distance *= ratio
		target_distance *= ratio

func _layout_scale_panel():
	if not is_instance_valid(size_panel):
		return
	size_panel.size = size_panel.get_combined_minimum_size()
	size_panel.position = Vector2(270,maxf(105.0,size_panel.get_parent_control().size.y-130.0-size_panel.size.y))

func _set_moons_enabled(enabled: bool):
	moons_enabled = enabled
	moons_toggle.set_pressed_no_signal(enabled)
	if not enabled and selected_moon>=0:
		_select(selected)
	_refresh_moon_picker()
	_update_bodies()
	_update_labels()
	_sync_moon_path_buttons()
	_refresh_paths()
	settings_timer.start()

func _set_moon_path_mode(mode: String):
	if mode not in ["orbits","trails"]:
		return
	moon_path_mode = mode
	if mode=="trails":
		_seed_history()
	_sync_moon_path_buttons()
	_update_bodies()
	_refresh_paths()
	settings_timer.start()

func _sync_moon_path_buttons():
	for mode in moon_path_buttons:
		moon_path_buttons[mode].set_pressed_no_signal(mode==moon_path_mode)
		moon_path_buttons[mode].disabled = not moons_enabled or mode==moon_path_mode

func _refresh_paths():
	if galaxy:
		_draw_trails()
	moon_trail_instance.visible = moons_enabled and moon_path_mode=="trails"
	if moon_trail_instance.visible:
		_draw_moon_trails()

func _set_labels_enabled(enabled: bool):
	labels_enabled = enabled
	labels_toggle.set_pressed_no_signal(enabled)
	_update_labels()
	settings_timer.start()

func _update_bodies():
	var origin = 0 if overview else selected
	for i in range(9):
		# Selection changes the camera target, never the contents of the scene.
		bodies[i].visible = true
		bodies[i].position = sim.relative_position(i,origin)*SCALE*_interplanet_scale()
		bodies[i].scale = Vector3.ONE * _radius(i)
		spins[i].rotation.y = fmod((sim.elapsed+sim.pending)*24.0/ROTATIONS[i]*TAU, TAU)
		var light = (-sim.relative_position(i,0)).normalized() if i != 0 else Vector3.UP
		materials[i].set_shader_parameter("sun_direction", light)
		materials[i].set_shader_parameter("phase", sim.elapsed)
		if atmospheres.has(i):
			atmospheres[i].set_shader_parameter("sun_direction", light)
		if i in [6,7]:
			atmospheres[i*10].set_shader_parameter("sun_direction",light)
			materials[i].set_shader_parameter("world_to_ring",ring_nodes[i].global_transform.affine_inverse())
		if i == 3:
			atmospheres[30].set_shader_parameter("sun_direction", light)
		labels[i].position = bodies[i].position + Vector3.UP*(_radius(i)+0.5)
		labels[i].visible = (overview or galaxy) and labels_enabled
		labels[i].scale = Vector3.ONE * maxf(1.0,distance/120.0)
	orbit_root.visible = overview and not galaxy
	orbit_root.scale = Vector3.ONE*_interplanet_scale()
	trail_instance.visible = galaxy
	moon_trail_instance.visible = moons_enabled and moon_path_mode=="trails"
	_update_moons()

func _record_history():
	history.append({"day":sim.elapsed,"p":sim.p.duplicate(),"v":sim.v.duplicate()})
	if history.size() > 1200:
		history.pop_front()
	last_sample = sim.elapsed

func _seed_history():
	if history.size() > 10:
		return
	var past = Physics.new()
	past.p = sim.p.duplicate()
	past.v = sim.v.duplicate()
	past.acc = past.acceleration()
	past.elapsed = sim.elapsed
	history.clear()
	for j in range(240):
		for k in range(8):
			past.step(-Physics.STEP)
		history.push_front({"day":past.elapsed,"p":past.p.duplicate(),"v":past.v.duplicate()})
	_record_history()
	_draw_trails()

func _draw_trails():
	if history.size() < 2:
		return
	var mesh = ImmediateMesh.new()
	for i in range(9):
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for j in range(history.size()):
			var point: Dictionary = history[j]
			var p: PackedFloat64Array = point.p
			var pos = _trajectory_point(i,point.day,_relative_sample_position(i,p))
			mesh.surface_set_color(Color(COLORS[i],lerpf(0.04,0.75,float(j)/history.size())))
			mesh.surface_add_vertex(pos)
		mesh.surface_set_color(Color(COLORS[i],0.8))
		mesh.surface_add_vertex(bodies[i].position)
		mesh.surface_end()
	trail_instance.mesh = mesh
	trail_instance.material_override = _line_material()

func _relative_sample_position(body: int, positions: PackedFloat64Array) -> Vector3:
	var origin = (0 if overview else selected)*3
	var relative = Vector3.ZERO
	for k in range(3):
		# Subtract in float64 before converting to GPU/render coordinates.
		relative[k] = positions[body*3+k]-(sim.p[origin+k]+sim.v[origin+k]*sim.pending)
	return relative

func _trajectory_point(body: int, day: float, relative_au: Vector3) -> Vector3:
	var shift = Physics.galactic_offset(day)-Physics.galactic_offset(sim.elapsed+sim.pending) if galaxy else Vector3.ZERO
	# Compress every component of the system's flight, preserving the shape of its
	# helices. Local satellite offsets remain in real km, as in the live scene.
	var point = (relative_au+shift)*(SCALE*_interplanet_scale())
	if body==3:
		point -= satellites.position_km(0,sim.epoch_jd+day)*(KM_TO_SCENE*0.0121505856)
	return point

func _history_relative_position(body: int, day: float) -> Vector3:
	# Planet samples are two days apart, much longer than a Phobos orbit. Cubic
	# Hermite interpolation supplies the moving parent at each satellite sample.
	var low = 0
	var high = history.size()-1
	while low<high:
		var mid = (low+high+1)/2
		if history[mid].day<=day:
			low = mid
		else:
			high = mid-1
	var first: Dictionary = history[low]
	var last: Dictionary = history[low+1] if low+1<history.size() else {"day":sim.elapsed+sim.pending,"p":sim.p,"v":sim.v}
	var span: float = last.day-first.day
	if span<=0.000000001:
		return sim.relative_position(body,0 if overview else selected)
	var t = clampf((day-first.day)/span,0.0,1.0)
	var h00 = 2.0*t*t*t-3.0*t*t+1.0
	var h10 = t*t*t-2.0*t*t+t
	var h01 = -2.0*t*t*t+3.0*t*t
	var h11 = t*t*t-t*t
	var origin = (0 if overview else selected)*3
	var relative = Vector3.ZERO
	for k in range(3):
		var index = body*3+k
		var endpoint: float = last.p[index]
		if low+1==history.size():
			endpoint += sim.v[index]*sim.pending
		var position: float = h00*first.p[index]+h10*span*first.v[index]+h01*endpoint+h11*span*last.v[index]
		relative[k] = position-(sim.p[origin+k]+sim.v[origin+k]*sim.pending)
	return relative

func _moon_trajectory_point(index: int, day: float) -> Vector3:
	var parent = int(satellites.data[index].parent)
	var center = _trajectory_point(parent,day,_history_relative_position(parent,day))
	return center+satellites.position_km(index,sim.epoch_jd+day)*KM_TO_SCENE

func _draw_moon_trails():
	if history.size()<2:
		return
	var now = sim.elapsed+sim.pending
	var key = [now,galaxy,0 if overview else selected,_interplanet_scale(),history[0].day,history[-1].day]
	if key==moon_trail_key:
		return
	moon_trail_key = key
	var mesh = ImmediateMesh.new()
	for i in range(moon_nodes.size()):
		var begin = maxf(history[0].day,now-satellites.data[i].period_days*MOON_TRAIL_PERIODS)
		var previous = _moon_trajectory_point(i,begin)
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for j in range(MOON_TRAIL_STEPS):
			var progress = float(j+1)/MOON_TRAIL_STEPS
			var next = _moon_trajectory_point(i,lerpf(begin,now,progress))
			mesh.surface_set_color(Color(0.50,0.74,0.87,lerpf(0.08,0.65,float(j)/MOON_TRAIL_STEPS)))
			mesh.surface_add_vertex(previous)
			mesh.surface_set_color(Color(0.50,0.74,0.87,lerpf(0.08,0.65,progress)))
			mesh.surface_add_vertex(next if j==MOON_TRAIL_STEPS-1 else previous.lerp(next,0.58))
			previous = next
		mesh.surface_end()
	moon_trail_instance.mesh = mesh
	moon_trail_instance.material_override = _line_material()

func _process(delta: float):
	if playing:
		sim.pending += minf(delta,0.1)*SPEEDS[speed_index]
		var iterations = 0
		while sim.pending >= Physics.STEP and iterations < 64:
			sim.step()
			sim.pending -= Physics.STEP
			iterations += 1
			if sim.elapsed - last_sample >= 2.0:
				_record_history()
	_update_bodies()
	_update_camera(delta)
	_update_labels()
	trail_clock += delta
	if (galaxy or (moons_enabled and moon_path_mode=="trails")) and trail_clock > 0.07:
		_refresh_paths()
		trail_clock = 0.0
	_update_readout()
	if "--capture" in startup_args:
		capture_frames += 1
		if capture_frames == 24:
			get_viewport().get_texture().get_image().save_png("res://build/preview.png")
			get_tree().quit()

func _update_camera(delta: float):
	distance = lerpf(distance,target_distance,1.0-exp(-delta*8.0))
	if overview:
		# Independent large radii and distance compression can put an overview
		# inside the Sun or a giant planet; keep it outside the enlarged bodies.
		var clearance = 0.0
		for i in range(bodies.size()):
			clearance = maxf(clearance,_radius(i)*2.0)
		distance = maxf(distance,clearance)
		target_distance = maxf(target_distance,clearance)
	var target = Vector3.ZERO if overview else bodies[selected].position
	if selected_moon>=0 and not overview:
		target = moon_nodes[selected_moon].position
	if galaxy and overview:
		target = Physics.galactic_offset(-240.0)*SCALE*_interplanet_scale()
	var direction = Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
	camera.position = target + direction*distance
	# Keep a stable projection from physical moon close-ups to compressed overviews.
	camera.near = maxf(0.000000001,minf(distance*0.001,0.1) if overview else distance*0.005)
	var scene_extent = maxf(distance*4.0,20000.0 if galaxy else 0.01)
	for i in range(bodies.size()):
		scene_extent = maxf(scene_extent,camera.position.distance_to(bodies[i].position)+_radius(i)*3.0)
	for i in range(moon_nodes.size()):
		scene_extent = maxf(scene_extent,camera.position.distance_to(moon_nodes[i].position)+_moon_radius(i)*3.0)
	camera.far = minf(scene_extent,camera.near*2000000.0)
	# Build from a unit direction: look_at(position) treats sub-1e-5 separations
	# as coincident, which otherwise breaks physical-scale Phobos/Deimos views.
	camera.basis = Basis.looking_at(-direction,Vector3.UP)

func _place_label(label: Label3D, anchor: Vector3, radius: float):
	var depth = maxf(-camera.to_local(anchor).z,0.000000001)
	var height = maxf(get_viewport().get_visible_rect().size.y,1.0)
	var units_per_pixel = depth*2.0*tan(deg_to_rad(camera.fov*0.5))/height
	label.position = anchor+camera.basis.y*(radius+units_per_pixel*12.0)
	label.scale = Vector3.ONE*units_per_pixel*18.0/(label.font_size*label.pixel_size)

func _update_labels():
	var used: Array[Rect2] = []
	for i in range(labels.size()):
		var label = labels[i]
		_place_label(label,bodies[i].position,_radius(i))
		label.visible = (overview or galaxy) and labels_enabled and camera.is_position_in_frustum(bodies[i].position)
		if not label.visible:
			continue
		var point = camera.unproject_position(label.position)
		var box = Rect2(point-Vector2(52,12),Vector2(104,24))
		for occupied in used:
			if occupied.intersects(box):
				label.visible = false
				break
		if label.visible:
			used.append(box)
	for i in range(moon_labels.size()):
		var label = moon_labels[i]
		_place_label(label,moon_nodes[i].position,_moon_radius(i))
		label.visible = labels_enabled and i!=selected_moon and moon_nodes[i].visible and camera.is_position_in_frustum(moon_nodes[i].position)
		if not label.visible:
			continue
		var point = camera.unproject_position(label.position)
		var box = Rect2(point-Vector2(48,10),Vector2(96,20))
		for occupied in used:
			if occupied.intersects(box):
				label.visible = false
				break
		if label.visible:
			used.append(box)

func _select(index: int):
	selected = index
	selected_moon = -1
	satellite_system_view = false
	overview = false
	_sync_scale_controls()
	_refresh_moon_picker()
	if not galaxy:
		target_distance = _radius(index)*(7.5 if index==7 else (7.0 if index==6 else 4.4))
		distance = target_distance
		var p = sim.position(index)-sim.position(0)
		yaw = atan2(-p.x,-p.z) + 0.55 if index != 0 else 0.5
		pitch = 0.22
	_ensure_follow_clearance()
	for i in range(select_buttons.size()):
		select_buttons[i].button_pressed = i == index

func _set_overview():
	overview = true
	selected_moon = -1
	satellite_system_view = false
	_refresh_moon_picker()
	_sync_scale_controls()
	target_distance = (2000.0 if galaxy else (95.0 if view_mode=="inner" else 1750.0))*_interplanet_scale()
	pitch = 0.42 if galaxy else 0.85
	yaw = 1.05 if galaxy else 0.3
	for button in select_buttons:
		button.button_pressed = false
	_sync_view_buttons()

func _activate_view(mode: String):
	view_mode = mode
	galaxy = mode=="galaxy"
	if galaxy or moon_path_mode=="trails":
		_seed_history()
	_set_overview()

func _sync_view_buttons():
	for mode in view_buttons:
		var current = mode==view_mode
		view_buttons[mode].set_pressed_no_signal(current)
		view_buttons[mode].disabled = current

func _view_button(text_value: String, mode: String) -> Button:
	var button = _button(text_value,_activate_view.bind(mode))
	button.toggle_mode = true
	view_buttons[mode] = button
	return button

func _toggle_galaxy():
	_activate_view("galaxy")

func _system_overview():
	_activate_view("system")

func _inner_overview():
	_activate_view("inner")

func _toggle_scale():
	_set_scale_mode(not actual_size)

func _reset():
	var old_radius = _focus_radius()
	var old_scale = _interplanet_scale()
	_restore_default_sizes()
	_rescale_flight_overview(old_scale)
	_sync_scale_controls()
	if not overview and not galaxy:
		var ratio = _focus_radius()/old_radius
		distance *= ratio
		target_distance *= ratio
	_ensure_follow_clearance()
	sim.reset()
	history.clear()
	last_sample = 0.0
	if galaxy or moon_path_mode=="trails":
		_seed_history()
	_update_bodies()
	_refresh_paths()

func _toggle_pause():
	playing = not playing
	pause_button.text = "Ⅱ  Пауза" if playing else "▶  Продолжить"

func _zoom(factor: float):
	var lower = 8.0*_interplanet_scale() if overview else _focus_radius()*2.0
	var upper = 3500.0 if overview else maxf(3500.0,_focus_radius()*100.0)
	if satellite_system_view:
		upper = maxf(upper,_system_extent()*8.0)
	target_distance = clampf(target_distance*factor,lower,upper)

func _unhandled_input(event: InputEvent):
	if (event is InputEventMouseMotion or event is InputEventMouseButton) and event.device == -1:
		return
	if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		yaw -= event.relative.x*0.005
		pitch = clampf(pitch+event.relative.y*0.005,-1.48,1.48)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.86)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.16)
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
	if event is InputEventScreenDrag:
		if touches.size() == 2 and touches.has(event.index):
			var other = touches.keys()[0] if touches.keys()[1] == event.index else touches.keys()[1]
			var old_distance = (touches[event.index] as Vector2).distance_to(touches[other])
			var new_distance = event.position.distance_to(touches[other])
			if new_distance > 1.0:
				_zoom(old_distance/new_distance)
		else:
			yaw -= event.relative.x*0.005
			pitch = clampf(pitch+event.relative.y*0.005,-1.48,1.48)
		touches[event.index] = event.position
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _toggle_pause()
			KEY_R: _set_overview()
			KEY_G: _toggle_galaxy()
			KEY_L: _set_labels_enabled(not labels_enabled)
			KEY_T: _toggle_scale()
			KEY_H: ui.visible = not ui.visible
			KEY_F: _select(selected)
			KEY_ESCAPE: ui.visible = true
			KEY_EQUAL, KEY_PLUS: _zoom(0.8)
			KEY_MINUS: _zoom(1.25)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9: _select(event.keycode-KEY_1)

func _panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.035,0.052,0.88)
	style.border_color = Color(0.2,0.37,0.44,0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _label(text_value: String, size: int, color = Color("e0eaf0")) -> Label:
	var label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func _button(text_value: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button

func _box(parent: Control, position_value: Vector2, width: float) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.position = position_value
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel",_panel_style())
	parent.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	return box

func _build_ui():
	add_child(ui)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var theme = Theme.new()
	theme.default_font_size = 16
	var regular = _panel_style()
	regular.bg_color = Color(0.04,0.07,0.09,0.7)
	regular.set_corner_radius_all(7)
	regular.content_margin_top = 8
	regular.content_margin_bottom = 8
	var hover = regular.duplicate()
	hover.bg_color = Color("183b49")
	var pressed = regular.duplicate()
	pressed.bg_color = Color("205467")
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal",type,regular)
		theme.set_stylebox("hover",type,hover)
		theme.set_stylebox("pressed",type,pressed)
		theme.set_color("font_color",type,Color("c4d6df"))
	theme.set_stylebox("disabled","Button",pressed)
	theme.set_color("font_disabled_color","Button",Color("85b4c3"))
	root.theme = theme
	var brand = _label("E A R T H N O M A D",23)
	brand.position = Vector2(32,26)
	root.add_child(brand)
	var subtitle = _label("S O L A R   O D Y S S E Y     /     ЖИВАЯ СОЛНЕЧНАЯ СИСТЕМА",12,Color("73929f"))
	subtitle.position = Vector2(33,62)
	root.add_child(subtitle)
	var version_label = _label("v" + str(ProjectSettings.get_setting("application/config/version")),13,Color("73929f"))
	version_label.position = Vector2(310,34)
	root.add_child(version_label)
	frame_label = _label("",14,Color("7fd0cd"))
	frame_label.position = Vector2(610,35)
	root.add_child(frame_label)
	_build_scale_controls(root)
	root.resized.connect(_layout_scale_panel)
	var left = _box(root,Vector2(28,112),207)
	left.add_child(_label("ОБЪЕКТЫ  /  09",12,Color("73929f")))
	for i in range(9):
		var button = _button("%02d   %s" % [i+1,NAMES[i]],_select.bind(i))
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color",COLORS[i])
		left.add_child(button)
		select_buttons.append(button)
	left.add_child(_label("СПУТНИКИ",12,Color("73929f")))
	moon_picker = OptionButton.new()
	moon_picker.custom_minimum_size.y = 44
	moon_picker.focus_mode = Control.FOCUS_NONE
	moon_picker.item_selected.connect(func(index):
		var id = moon_picker.get_item_id(index)
		if id>=0 and id<satellites.data.size():
			_select_moon(id)
		else:
			_select(selected)
	)
	left.add_child(moon_picker)
	satellite_system_button = _button("Планета + спутники",_satellite_system)
	left.add_child(satellite_system_button)
	var right = _box(root,Vector2(1130,112),282)
	navigation_box = right
	(right.get_parent() as Control).anchor_left = 1.0
	(right.get_parent() as Control).anchor_right = 1.0
	(right.get_parent() as Control).offset_left = -310
	(right.get_parent() as Control).offset_right = -28
	right.add_child(_label("ТЕЛЕМЕТРИЯ",12,Color("73929f")))
	title_label = _label("Земля",30)
	right.add_child(title_label)
	detail_label = _label("",15)
	right.add_child(detail_label)
	right.add_child(HSeparator.new())
	right.add_child(_view_button("↗  Галактический полёт","galaxy"))
	right.add_child(_view_button("◎  Обзор системы","system"))
	right.add_child(_view_button("⊙  Земная группа","inner"))
	_sync_view_buttons()
	labels_toggle = CheckButton.new()
	labels_toggle.text = "Подписи объектов"
	labels_toggle.custom_minimum_size.y = 44
	labels_toggle.focus_mode = Control.FOCUS_NONE
	labels_toggle.button_pressed = labels_enabled
	labels_toggle.toggled.connect(_set_labels_enabled)
	right.add_child(labels_toggle)
	moons_toggle = CheckButton.new()
	moons_toggle.text = "Спутники"
	moons_toggle.custom_minimum_size.y = 44
	moons_toggle.focus_mode = Control.FOCUS_NONE
	moons_toggle.button_pressed = moons_enabled
	moons_toggle.toggled.connect(_set_moons_enabled)
	right.add_child(moons_toggle)
	var path_row = HBoxContainer.new()
	right.add_child(path_row)
	for mode in ["orbits","trails"]:
		var button = _button("Орбиты" if mode=="orbits" else "Траектории",_set_moon_path_mode.bind(mode))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",14)
		button.tooltip_text = "Замкнутые орбиты спутников вокруг планет" if mode=="orbits" else "Следы спутников за четыре оборота с учётом движения планет"
		path_row.add_child(button)
		moon_path_buttons[mode] = button
	_sync_moon_path_buttons()
	var note = _label("SSS · CC BY 4.0 · JPL / NASA",11,Color("73929f"))
	right.add_child(note)
	var bottom = PanelContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 28
	bottom.offset_right = -28
	bottom.offset_top = -112
	bottom.offset_bottom = -26
	bottom.add_theme_stylebox_override("panel",_panel_style())
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	bottom.add_child(row)
	var time_box = VBoxContainer.new()
	time_box.custom_minimum_size.x = 310
	row.add_child(time_box)
	time_box.add_child(_label("ВРЕМЯ СИМУЛЯЦИИ · UTC ≈ TDB",11,Color("73929f")))
	clock_label = _label("",21)
	time_box.add_child(clock_label)
	pause_button = _button("Ⅱ  Пауза",_toggle_pause)
	row.add_child(pause_button)
	speed_select = OptionButton.new()
	for caption in SPEED_LABELS:
		speed_select.add_item(caption)
	speed_select.select(speed_index)
	speed_select.item_selected.connect(func(index): speed_index = index)
	row.add_child(speed_select)
	row.add_child(_button("↺  25.10.2026",_reset))
	var help = _label("Перетаскивание — камера  ·  Колесо — зум\nПробел — пауза  ·  R — обзор  ·  H — скрыть UI",12,Color("73929f"))
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(help)

func _scale_row(parent: VBoxContainer, caption: String, value: float, kind: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var label = _label(caption,15)
	label.custom_minimum_size.x = 85
	row.add_child(label)
	# Logarithmic travel gives fine control across the permitted range.
	var slider = HSlider.new()
	slider.min_value = log(VISUAL_SCALE_MIN)/log(2.0)
	var maximum = SUN_SCALE_MAX if kind=="sun" else VISUAL_SCALE_MAX
	slider.max_value = log(maximum)/log(2.0)
	slider.step = 0.001
	slider.value = log(value)/log(2.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(100,44)
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = "Множитель реального радиуса от ×1 до ×%d. Орбиты спутников не меняются." % int(maximum)
	slider.value_changed.connect(func(exponent): _set_size_control(snappedf(pow(2.0,exponent),0.1),kind))
	row.add_child(slider)
	var input = SpinBox.new()
	input.min_value = VISUAL_SCALE_MIN
	input.max_value = maximum
	input.step = 0.1
	input.value = value
	input.suffix = "×"
	input.custom_minimum_size = Vector2(128,44)
	input.value_changed.connect(_set_size_control.bind(kind))
	row.add_child(input)
	if kind=="moons":
		moon_scale_slider = slider
		moon_scale_input = input
	elif kind=="sun":
		sun_scale_slider = slider
		sun_scale_input = input
	else:
		planet_scale_slider = slider
		planet_scale_input = input

func _build_scale_controls(root: Control):
	var box = _box(root,Vector2(270,522),520)
	size_panel = box.get_parent()
	scale_heading = _label("",12,Color("7fd0cd"))
	scale_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scale_heading)
	var modes = HBoxContainer.new()
	box.add_child(modes)
	physical_mode_button = _button("1:1",_set_scale_mode.bind(true))
	physical_mode_button.toggle_mode = true
	physical_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(physical_mode_button)
	visual_mode_button = _button("Visual",_set_scale_mode.bind(false))
	visual_mode_button.toggle_mode = true
	visual_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(visual_mode_button)
	adjust_controls = VBoxContainer.new()
	adjust_controls.add_theme_constant_override("separation",8)
	box.add_child(adjust_controls)
	_scale_row(adjust_controls,"Солнце",_sun_scale(),"sun")
	_scale_row(adjust_controls,"Планеты",_planet_scale(),"planets")
	_scale_row(adjust_controls,"Спутники",_moon_scale(),"moons")
	distance_controls = HBoxContainer.new()
	distance_controls.add_theme_constant_override("separation",12)
	box.add_child(distance_controls)
	distance_controls.add_child(_label("Сжатие расстояний",15))
	compression_slider = HSlider.new()
	compression_slider.min_value = 1.0
	compression_slider.max_value = MAX_DISTANCE_COMPRESSION
	compression_slider.step = 0.1
	compression_slider.value = 1.0
	compression_slider.custom_minimum_size = Vector2(170,44)
	compression_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compression_slider.focus_mode = Control.FOCUS_NONE
	compression_slider.tooltip_text = "Уменьшение межпланетных расстояний от 1 до 500 раз. Радиусы и локальные орбиты спутников не меняются."
	compression_slider.value_changed.connect(_set_distance_compression)
	distance_controls.add_child(compression_slider)
	compression_label = _label("÷ 1.0",15)
	compression_label.custom_minimum_size.x = 70
	distance_controls.add_child(compression_label)
	scale_note = _label("",12,Color("73929f"))
	box.add_child(scale_note)

func _update_readout():
	var date = Time.get_datetime_dict_from_unix_time((sim.epoch_jd-2440587.5+sim.elapsed+sim.pending)*86400.0)
	clock_label.text = "%02d.%02d.%04d  ·  %02d:%02d" % [date.day,date.month,date.year,date.hour,date.minute]
	frame_label.text = ("ГАЛАКТИЧЕСКИЙ ПОЛЁТ" if galaxy else "ГЕЛИОЦЕНТРИЧЕСКИЙ ВИД") + "   /   " + ("РАДИУСЫ 1:1" if actual_size else "VISUAL")
	if galaxy and not overview:
		frame_label.text += "   /   СЛЕЖЕНИЕ"
	scale_note.text = ("Радиусы ×1" if actual_size else "Радиусы Visual") + " · Расстояния ÷ %.1f" % distance_compression
	title_label.text = NAMES[selected]
	var radius_au = sim.position(selected).distance_to(sim.position(0))
	var speed = 0.0
	for k in range(3):
		speed += pow(sim.v[selected*3+k]-sim.v[k],2)
	speed = sqrt(speed)*Physics.AU_KM/86400.0
	detail_label.text = "%s\n\nРадиус          %s км\nОт Солнца     %.3f а.е.\nСкорость       %.2f км/с\nНаклон оси    %.2f°\n%s\nΔE / E₀         %.8f" % [KINDS[selected],str(int(RADII[selected])),radius_au,speed,180.0-TILTS[selected] if selected in [2,7] else TILTS[selected],"9 тел  ·  шаг 6 часов",abs((sim.energy()-initial_energy)/initial_energy)]
	if selected_moon>=0:
		var d: Dictionary = satellites.data[selected_moon]
		title_label.text = d.name
		var km = satellites.position_km(selected_moon,sim.epoch_jd+sim.elapsed+sim.pending).length()
		detail_label.text = "СПУТНИК · %s\n\nРадиус          %.1f км\nОт планеты   %.0f км\nПериод         %.4f сут\nЭксцентрис.  %.4f\nНаклон          %.2f°\n\nКеплер · элементы JPL" % [NAMES[selected],d.radius_km,km,d.period_days,d.e,d.inclination_deg]

