extends Node3D

const Physics = preload("res://scripts/physics.gd")
const IDS = ["sun", "mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
const NAMES = ["Солнце", "Меркурий", "Венера", "Земля", "Марс", "Юпитер", "Сатурн", "Уран", "Нептун"]
const KINDS = ["ЗВЕЗДА · G2V", "КАМЕННАЯ ПЛАНЕТА", "КАМЕННАЯ ПЛАНЕТА", "НАШ ДОМ", "КАМЕННАЯ ПЛАНЕТА", "ГАЗОВЫЙ ГИГАНТ", "ГАЗОВЫЙ ГИГАНТ", "ЛЕДЯНОЙ ГИГАНТ", "ЛЕДЯНОЙ ГИГАНТ"]
const RADII = [695700.0,2439.7,6051.8,6371.0,3389.5,69911.0,58232.0,25362.0,24622.0]
const DISPLAY_RADII = [2.5,0.26,0.58,0.62,0.38,1.5,1.3,0.95,0.92]
const TILTS = [7.25,0.034,2.64,23.44,25.19,3.13,26.73,82.23,28.32]
const ROTATIONS = [609.12,1407.6,-5832.5,23.9345,24.6229,9.925,10.656,-17.24,16.11]
const COLORS = [Color("ffd69a"),Color("b4afa9"),Color("dec69b"),Color("71c9ec"),Color("dc9473"),Color("d7b190"),Color("e6d1a2"),Color("9cdfdf"),Color("658eee")]
const SCALE = 20.0
const SPEEDS = [0.000011574074,0.0416667,1.0,10.0,40.0,120.0]
const SPEED_LABELS = ["Реальное время", "1 час / сек", "1 день / сек", "10 дней / сек", "40 дней / сек", "120 дней / сек"]
var sim = Physics.new()
var bodies: Array[Node3D] = []
var spins: Array[Node3D] = []
var materials: Array[ShaderMaterial] = []
var atmospheres: Dictionary = {}
var labels: Array[Label3D] = []
var orbit_root = Node3D.new()
var trail_instance = MeshInstance3D.new()
var history: Array = []
var last_sample = 0.0
var trail_clock = 0.0
var camera = Camera3D.new()
var selected = 3
var overview = false
var galaxy = false
var actual_size = false
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

func _ready():
	initial_energy = sim.energy()
	_build_environment()
	_build_bodies()
	_build_orbits()
	add_child(trail_instance)
	_build_ui()
	_select(3)
	for argument in startup_args:
		if argument.begins_with("--planet="):
			_select(clampi(int(argument.get_slice("=",1)),0,8))
	if "--overview" in startup_args:
		_set_overview()
	if "--galaxy" in startup_args:
		galaxy = true
		_set_overview()
		_seed_history()
	_update_bodies()
	_update_camera(1.0)
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
		if i == 6:
			_build_rings(axis)
		var label = Label3D.new()
		label.text = NAMES[i]
		label.font_size = 40
		label.pixel_size = 0.055
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = COLORS[i]
		add_child(label)
		labels.append(label)

func _build_rings(parent: Node3D):
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(256):
		var a = TAU*float(j)/256.0
		var b = TAU*float(j+1)/256.0
		var inner_a = Vector3(cos(a),0,sin(a))*1.24
		var outer_a = Vector3(cos(a),0,sin(a))*2.27
		var inner_b = Vector3(cos(b),0,sin(b))*1.24
		var outer_b = Vector3(cos(b),0,sin(b))*2.27
		for point in [inner_a,outer_a,outer_b,inner_a,outer_b,inner_b]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/rings.gdshader")
	instance.material_override = material
	parent.add_child(instance)
	atmospheres[60] = material

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
	return RADII[i] / Physics.AU_KM * SCALE if actual_size else DISPLAY_RADII[i]

func _update_bodies():
	var origin = 0 if overview else selected
	for i in range(9):
		bodies[i].position = sim.relative_position(i,origin)*SCALE
		bodies[i].scale = Vector3.ONE * _radius(i)
		spins[i].rotation.y = fmod((sim.elapsed+sim.pending)*24.0/ROTATIONS[i]*TAU, TAU)
		var light = (-sim.relative_position(i,0)).normalized() if i != 0 else Vector3.UP
		materials[i].set_shader_parameter("sun_direction", light)
		materials[i].set_shader_parameter("phase", sim.elapsed)
		if atmospheres.has(i):
			atmospheres[i].set_shader_parameter("sun_direction", light)
		if i == 6:
			atmospheres[60].set_shader_parameter("sun_direction", light)
		if i == 3:
			atmospheres[30].set_shader_parameter("sun_direction", light)
		labels[i].position = bodies[i].position + Vector3.UP*(_radius(i)+0.5)
		labels[i].visible = overview
		labels[i].scale = Vector3.ONE * maxf(1.0,distance/120.0)
	orbit_root.visible = overview and not galaxy
	trail_instance.visible = galaxy

func _record_history():
	history.append({"day":sim.elapsed,"p":sim.p.duplicate()})
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
		history.push_front({"day":past.elapsed,"p":past.p.duplicate()})
	_record_history()
	_draw_trails()

func _draw_trails():
	if history.size() < 2:
		return
	var mesh = ImmediateMesh.new()
	var offset_now = Physics.galactic_offset(sim.elapsed+sim.pending)
	var origin = sim.position(0 if overview else selected)
	for i in range(9):
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for j in range(history.size()):
			var point: Dictionary = history[j]
			var p: PackedFloat64Array = point.p
			var shift = Physics.galactic_offset(point.day) - offset_now
			var pos = Vector3(p[i*3],p[i*3+1],p[i*3+2]) - origin + shift
			mesh.surface_set_color(Color(COLORS[i],lerpf(0.04,0.75,float(j)/history.size())))
			mesh.surface_add_vertex(pos*SCALE)
		mesh.surface_set_color(Color(COLORS[i],0.8))
		mesh.surface_add_vertex(bodies[i].position)
		mesh.surface_end()
	trail_instance.mesh = mesh
	trail_instance.material_override = _line_material()

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
	if galaxy and trail_clock > 0.07:
		_draw_trails()
		trail_clock = 0.0
	_update_readout()
	if "--capture" in startup_args:
		capture_frames += 1
		if capture_frames == 24:
			get_viewport().get_texture().get_image().save_png("res://build/preview.png")
			get_tree().quit()

func _update_camera(delta: float):
	distance = lerpf(distance,target_distance,1.0-exp(-delta*8.0))
	var target = Vector3.ZERO if overview else bodies[selected].position
	if galaxy and overview:
		target = Physics.galactic_offset(-240.0)*SCALE
	var direction = Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
	camera.position = target + direction*distance
	camera.near = maxf(0.000001, minf(distance*0.001,0.1))
	camera.look_at(target)

func _update_labels():
	var used: Array[Rect2] = []
	for label in labels:
		label.visible = overview and not camera.is_position_behind(label.position)
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

func _select(index: int):
	selected = index
	overview = false
	target_distance = _radius(index)*(7.0 if index == 6 else 4.4)
	distance = target_distance
	var p = sim.position(index)-sim.position(0)
	yaw = atan2(-p.x,-p.z) + 0.55 if index != 0 else 0.5
	pitch = 0.22
	for i in range(select_buttons.size()):
		select_buttons[i].button_pressed = i == index

func _set_overview():
	overview = true
	target_distance = 2000.0 if galaxy else 1750.0
	pitch = 0.42 if galaxy else 0.85
	yaw = 1.05 if galaxy else 0.3
	for button in select_buttons:
		button.button_pressed = false

func _toggle_galaxy():
	galaxy = not galaxy
	if galaxy:
		_seed_history()
	_set_overview()

func _inner_overview():
	galaxy = false
	_set_overview()
	target_distance = 95.0

func _toggle_scale():
	actual_size = not actual_size
	if not overview:
		_select(selected)

func _reset():
	sim.reset()
	history.clear()
	last_sample = 0.0
	if galaxy:
		_seed_history()

func _toggle_pause():
	playing = not playing
	pause_button.text = "Ⅱ  Пауза" if playing else "▶  Продолжить"

func _zoom(factor: float):
	var lower = 8.0 if overview else _radius(selected)*2.0
	target_distance = clampf(target_distance*factor,lower,3500.0)

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
	root.theme = theme
	var brand = _label("E A R T H N O M A D",23)
	brand.position = Vector2(32,26)
	root.add_child(brand)
	var subtitle = _label("S O L A R   O D Y S S E Y     /     ЖИВАЯ СОЛНЕЧНАЯ СИСТЕМА",12,Color("73929f"))
	subtitle.position = Vector2(33,62)
	root.add_child(subtitle)
	frame_label = _label("",14,Color("7fd0cd"))
	frame_label.position = Vector2(610,35)
	root.add_child(frame_label)
	var left = _box(root,Vector2(28,112),207)
	left.add_child(_label("ОБЪЕКТЫ  /  09",12,Color("73929f")))
	for i in range(9):
		var button = _button("%02d   %s" % [i+1,NAMES[i]],_select.bind(i))
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color",COLORS[i])
		left.add_child(button)
		select_buttons.append(button)
	left.add_child(_button("◎  Обзор системы",_set_overview))
	left.add_child(_button("⊙  Земная группа",_inner_overview))
	var right = _box(root,Vector2(1130,112),282)
	(right.get_parent() as Control).anchor_left = 1.0
	(right.get_parent() as Control).anchor_right = 1.0
	(right.get_parent() as Control).offset_left = -310
	(right.get_parent() as Control).offset_right = -28
	right.add_child(_label("ТЕЛЕМЕТРИЯ",12,Color("73929f")))
	title_label = _label("Земля",30)
	right.add_child(title_label)
	detail_label = _label("",16)
	right.add_child(detail_label)
	right.add_child(HSeparator.new())
	right.add_child(_button("↗  Галактический полёт",_toggle_galaxy))
	right.add_child(_button("⇄  Масштаб размеров",_toggle_scale))
	right.add_child(_button("＋  Приблизить",_zoom.bind(0.75)))
	right.add_child(_button("−  Отдалить",_zoom.bind(1.3333)))
	var note = _label("Орбиты: ньютоновская гравитация\nГалактика: приближённая модель\nОриентация осей: иллюстративная\nТекстуры: Solar System Scope\nCC BY 4.0 · JPL / NASA",12,Color("73929f"))
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

func _update_readout():
	var date = Time.get_datetime_dict_from_unix_time((sim.epoch_jd-2440587.5+sim.elapsed+sim.pending)*86400.0)
	clock_label.text = "%02d.%02d.%04d  ·  %02d:%02d" % [date.day,date.month,date.year,date.hour,date.minute]
	frame_label.text = ("ГАЛАКТИЧЕСКИЙ ПОЛЁТ" if galaxy else "ГЕЛИОЦЕНТРИЧЕСКИЙ ВИД") + "   /   " + ("РАЗМЕРЫ 1:1" if actual_size else "РАЗМЕРЫ УВЕЛИЧЕНЫ")
	title_label.text = NAMES[selected]
	var radius_au = sim.position(selected).distance_to(sim.position(0))
	var speed = 0.0
	for k in range(3):
		speed += pow(sim.v[selected*3+k]-sim.v[k],2)
	speed = sqrt(speed)*Physics.AU_KM/86400.0
	detail_label.text = "%s\n\nРадиус          %s км\nОт Солнца     %.3f а.е.\nСкорость       %.2f км/с\nНаклон оси    %.2f°\n\n%s\nΔE / E₀         %.8f" % [KINDS[selected],str(int(RADII[selected])),radius_au,speed,180.0-TILTS[selected] if selected in [2,7] else TILTS[selected],"9 тел  ·  шаг 6 часов",abs((sim.energy()-initial_energy)/initial_energy)]

