extends SceneTree
## Run without --headless to exercise shader compilation and small-body clipping.
var failures = 0

func _init():
	call_deferred("run")

func run():
	var app = load("res://main.tscn").instantiate()
	app.settings_path = "user://test-render.cfg"
	DirAccess.remove_absolute(app.settings_path)
	root.add_child(app)
	app.playing = false
	app.pause_button.text = "▶  Продолжить"
	for physical in [false,true]:
		app._set_scale_mode(physical)
		for i in range(app.satellites.data.size()):
			app._select_moon(i)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			if not app.camera.is_position_in_frustum(app.moon_nodes[i].position):
				push_error("Satellite outside rendering frustum: %s / physical=%s" % [i,physical])
				failures += 1
	app._set_scale_mode(false)
	for i in [6,7]:
		app._select(i)
		await process_frame
		await RenderingServer.frame_post_draw
	app._toggle_galaxy()
	for i in range(9):
		app._select(i)
		await process_frame
		await RenderingServer.frame_post_draw
		if not app.trail_instance.visible or not app.moon_nodes.all(func(body): return body.visible):
			push_error("Galactic tracking hides trajectories or satellites")
			failures += 1
	app.moon_scale_input.value = 50.0
	app._system_overview()
	app.moon_scale_input.value = 50.0
	await process_frame
	await RenderingServer.frame_post_draw
	app.physical_mode_button.pressed.emit()
	app.compression_slider.value = 50.0
	app._inner_overview()
	app._update_camera(1.0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/physical-mode-v0.8.0.png")
	app.moons_toggle.button_pressed = false
	await process_frame
	await RenderingServer.frame_post_draw
	if app.moon_nodes.any(func(body): return body.visible) or app.moon_orbits.any(func(orbit): return orbit.visible):
		push_error("Hidden satellite geometry is still visible")
		failures += 1
	app.moons_toggle.button_pressed = true
	app.visual_mode_button.pressed.emit()
	# Verify that the new fill actually reveals a surface facing away from the Sun.
	app._set_scale_mode(false)
	app._select(4)
	app.yaw += PI
	app.pitch = -app.pitch
	# Sample the surface itself: the four-row size panel may cover the center.
	app.ui.visible = false
	app.materials[4].set_shader_parameter("night_fill",0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var dark_image: Image = root.get_texture().get_image()
	var center = Vector2i(dark_image.get_width()/2,dark_image.get_height()/2)
	var dark = dark_image.get_pixelv(center).get_luminance()
	app.materials[4].set_shader_parameter("night_fill",0.12)
	await process_frame
	await RenderingServer.frame_post_draw
	var filled_image: Image = root.get_texture().get_image()
	var filled = filled_image.get_pixelv(center).get_luminance()
	if filled<=dark+0.01:
		push_error("Night-side fill did not brighten the rendered surface")
		failures += 1
	print("Night-side center luminance: ",dark," -> ",filled)
	filled_image.save_png("res://build/night-side-v0.8.0.png")
	app.ui.visible = true
	app._select(5)
	app._satellite_system()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/adjust-mode-v0.8.0.png")
	app._activate_view("galaxy")
	app._set_scale_mode(true)
	app._set_distance_compression(50.0)
	app.distance = app.target_distance
	app._update_camera(1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/galactic-scale-v0.8.0.png")
	# Inspect the actual submitted GPU mesh, including its live-body endpoints.
	for i in range(9):
		var vertices = app.trail_instance.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
		if vertices.is_empty() or vertices[-1].distance_to(app.bodies[i].position)>0.00001:
			push_error("Planet trajectory misses its current position")
			failures += 1
	app.moon_path_buttons.trails.pressed.emit()
	app.moon_trail_key.clear()
	var started = Time.get_ticks_usec()
	app._draw_moon_trails()
	print("20 satellite trail rebuild (ms): ",(Time.get_ticks_usec()-started)/1000.0)
	for mode in ["galaxy","system"]:
		app._activate_view(mode)
		app._select(5)
		app._satellite_system()
		app._update_bodies()
		app._refresh_paths()
		for i in range(20):
			var vertices = app.moon_trail_instance.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			if vertices.size()!=512 or vertices[-1].distance_to(app.moon_nodes[i].position)>0.00001:
				push_error("Satellite GPU trail misses its current position")
				failures += 1
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/satellite-trails-%s-v0.8.0.png" % mode)
	app.moons_toggle.button_pressed = false
	await process_frame
	if app.moon_trail_instance.visible:
		push_error("Satellite switch leaves GPU trails visible")
		failures += 1
	app.moons_toggle.button_pressed = true
	app.moon_path_buttons.orbits.pressed.emit()
	app._set_scale_mode(false)
	app._select(3)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/controls-v0.8.0.png")
	var nav_bottom: float = app.navigation_box.get_parent().get_global_rect().end.y
	if nav_bottom>root.get_visible_rect().size.y-112.0:
		push_error("Navigation overlaps the time controls")
		failures += 1
	app.planet_scale_input.value = 500.0
	app.sun_scale_input.value = 50.0
	app.moon_scale_input.value = 500.0
	app.compression_slider.value = 500.0
	app._system_overview()
	await process_frame
	await RenderingServer.frame_post_draw
	if app.camera.position.distance_to(app.bodies[0].position)<=app._radius(0):
		push_error("Maximum compression places the overview inside the Sun")
		failures += 1
	app._satellite_system()
	await process_frame
	await RenderingServer.frame_post_draw
	app.visual_mode_button.pressed.emit()
	app.compression_slider.value = 1.0
	app._select(3)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visual-controls-v0.9.0.png")
	app._activate_view("galaxy")
	app._select(0)
	app.distance = 240.0*app._interplanet_scale()
	app.target_distance = app.distance
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/solar-orbit-flight.png")
	app.galactic_map_button.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	var map_image: Image = root.get_texture().get_image()
	map_image.save_png("res://build/solar-galactic-orbit.png")
	var violet_pixels = 0
	for y in range(180,680):
		for x in range(300,1100):
			var pixel = map_image.get_pixel(x,y)
			if pixel.r>0.3 and pixel.b>0.4 and pixel.b>pixel.g*1.3 and pixel.r>pixel.g*1.2:
				violet_pixels += 1
	if violet_pixels<250:
		push_error("Highlighted complete solar orbit is not visible in the GPU frame")
		failures += 1
	var orbit_vertices = app.galactic_orbit.map_orbit.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if orbit_vertices.size()!=513 or orbit_vertices[0].distance_to(orbit_vertices[-1])>0.0001:
		push_error("GPU solar orbit is not a closed curve")
		failures += 1
	app.galactic_map_button.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	if app.camera.cull_mask!=1 or not app.galactic_orbit.local_arc.visible:
		push_error("Return from the orbit map fails to restore the flight scene")
		failures += 1
	print("RENDER: ","PASS" if failures==0 else "FAIL", " (real geometry; compressed flight; satellite paths; GPU endpoints; solar galactic orbit; UI layout; night fill)")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test-render.cfg")
	quit(failures)
