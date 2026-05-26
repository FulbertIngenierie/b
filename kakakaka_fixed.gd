extends CharacterBody3D

# =========================================================
# NODES
# =========================================================

@onready var camera = $Head/Camera3D
@onready var head = $Head

@onready var anim_player = $CharacterModel/AnimationPlayer

@onready var gun_sound = $GunSound

var damage_sound: AudioStreamPlayer3D = null
var damage_overlay: ColorRect = null

var damage_flash_timer := 0.0
var camera_shake_intensity := 0.0

# =========================================================
# CROSSHAIR
# =========================================================

var crosshair = null

# =========================================================
# GUN TIP
# =========================================================

@onready var gun_tip = $CharacterModel/Sketchfab_model/fbx_merge_fbx/Object_2/RootNode/SKEL_AK_47_Rifle/GunTip

# =========================================================
# SCENES
# =========================================================

var bullet_scene = preload("res://Bullet.tscn")
var impact_scene = preload("res://Impact.tscn")
var hit_effect_scene = preload("res://HitEffect.tscn")
var bullet_impact_scene = preload("res://BulletImpact.tscn")

# =========================================================
# MOVEMENT
# =========================================================

var speed := 6.0
var sprint_speed := 10.0
var jump_velocity = 4.5
var gravity = 9.8
var detection_range := 100.0

var mouse_sensitivity = 0.002

var yaw = 0.0
var pitch = 0.0

var mouse_delta = Vector2.ZERO

var current_speed = 5.0
var is_sprinting := false

# =========================================================
# SHOOT
# =========================================================

var is_aiming = false

var shooting = false
var can_auto_fire = false

var fire_rate = 0.08

# =========================================================
# ZOOM
# =========================================================

var normal_fov := 75.0
var aim_fov := 40.0
var current_fov := 75.0
var zoom_speed := 10.0

# =========================================================
# PLAYER
# =========================================================

var current_anim = ""

var health = 100
var max_health = 100
var ammo = 30
var max_ammo = 30
var total_ammo = 120
var is_dead = false

# =========================================================
# RÉGÉNÉRATION DE VIE
# =========================================================

var regen_delay := 4.0
var regen_rate := 15.0
var time_since_damage := 0.0

# =========================================================
# KILL TRACKING
# =========================================================

var kill_count := 0
var kill_streak := 0
var kill_streak_timer := 0.0
var kill_streak_display_timer := 0.0
var kill_streak_text := ""

# =========================================================
# HIT MARKER
# =========================================================

var hit_marker_timer := 0.0
var hit_marker_duration := 0.2

# =========================================================
# LOW HEALTH VIGNETTE
# =========================================================

var vignette_overlay: ColorRect = null
var vignette_pulse_timer := 0.0

# =========================================================
# DEATH SCREEN
# =========================================================

var death_screen: Control = null

# =========================================================
# HIT MARKER UI
# =========================================================

var hit_marker_ui: Control = null

# =========================================================
# KILL STREAK UI
# =========================================================

var kill_streak_label: Label = null

# =========================================================
# KILL COUNTER UI
# =========================================================

var kill_counter_label: Label = null

# =========================================================
# READY
# =========================================================

func _ready():

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	play_idle()

	add_to_group("player")

	crosshair = get_tree().current_scene.get_node_or_null("CanvasLayer/Crosshair")
	if crosshair:
		crosshair.show()

	damage_sound = AudioStreamPlayer3D.new()
	add_child(damage_sound)
	damage_sound.volume_db = 0.0
	damage_sound.max_distance = 50.0
	
	_create_damage_overlay()
	_create_vignette_overlay()
	_create_hit_marker_ui()
	_create_kill_counter_ui()
	_create_kill_streak_label()
	_create_death_screen()

# =========================================================
# INPUT
# =========================================================

func _input(event):

	if is_dead:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			get_tree().reload_current_scene()
		return
	
	if get_tree().paused:
		return

	if event is InputEventMouseMotion:
		mouse_delta += event.relative

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_RIGHT:

			is_aiming = event.pressed

			update_animation()
			
			if crosshair:
				crosshair.set_aiming(is_aiming)
			
			if is_aiming:
				aim_at_nearest_enemy()

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:

				shooting = true

				start_auto_fire()

			else:

				shooting = false

				update_animation()

	if event is InputEventKey:

		if event.keycode == KEY_R:

			if event.pressed:

				reload_once()

# =========================================================
# AUTO FIRE
# =========================================================

func start_auto_fire():

	if can_auto_fire:
		return

	can_auto_fire = true

	while shooting and not is_dead:

		shoot_once()

		await get_tree().create_timer(fire_rate).timeout

	can_auto_fire = false

# =========================================================
# PROCESS
# =========================================================

func _process(delta):

	if is_dead:
		_update_death_screen(delta)
		return
	
	check_enemies_alive()
	
	if mouse_delta != Vector2.ZERO:
		yaw -= mouse_delta.x * mouse_sensitivity
		pitch += mouse_delta.y * mouse_sensitivity
		pitch = clamp(pitch, -1.5, 1.5)
		
		rotation.y = yaw
		rotation.x = pitch
		
		mouse_delta = Vector2.ZERO

	var target_fov = aim_fov if is_aiming else normal_fov
	current_fov = lerp(current_fov, target_fov, zoom_speed * delta)

	if camera:
		camera.fov = current_fov

	# Damage flash
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		var flash_alpha = clamp(damage_flash_timer / 0.3, 0.0, 1.0)
		if damage_overlay:
			damage_overlay.color = Color(0.8, 0.0, 0.0, flash_alpha * 0.4)
			damage_overlay.visible = true
	else:
		if damage_overlay:
			damage_overlay.visible = false

	# Camera shake
	if camera_shake_intensity > 0:
		camera_shake_intensity -= delta * 2.0
		var shake_offset = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		).normalized() * camera_shake_intensity
		camera.rotation.x += shake_offset.x * 0.02
		camera.rotation.y += shake_offset.y * 0.02
		camera_shake_intensity = max(0, camera_shake_intensity)

	# Régénération de vie
	time_since_damage += delta
	if time_since_damage >= regen_delay and health < max_health:
		health += int(regen_rate * delta)
		health = min(health, max_health)

	# Low health vignette
	_update_vignette(delta)

	# Hit marker fade
	if hit_marker_timer > 0:
		hit_marker_timer -= delta
		if hit_marker_ui:
			hit_marker_ui.visible = true
			hit_marker_ui.modulate.a = clamp(hit_marker_timer / hit_marker_duration, 0, 1)
	else:
		if hit_marker_ui:
			hit_marker_ui.visible = false

	# Kill streak display
	if kill_streak_display_timer > 0:
		kill_streak_display_timer -= delta
		if kill_streak_label:
			kill_streak_label.visible = true
			kill_streak_label.text = kill_streak_text
			kill_streak_label.modulate.a = clamp(kill_streak_display_timer / 2.0, 0, 1)
	else:
		if kill_streak_label:
			kill_streak_label.visible = false

	# Kill streak reset
	kill_streak_timer += delta
	if kill_streak_timer > 5.0:
		kill_streak = 0

	# Update kill counter
	if kill_counter_label:
		kill_counter_label.text = "KILLS: " + str(kill_count)

	update_animation()

# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(delta):

	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	is_sprinting = Input.is_key_pressed(KEY_SHIFT) and not is_aiming
	current_speed = sprint_speed if is_sprinting else speed

	if Input.is_key_pressed(KEY_SPACE):
		if is_on_floor():
			velocity.y = jump_velocity

	var input_dir = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	var direction = (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()

# =========================================================
# AIM AT NEAREST ENEMY
# =========================================================

func aim_at_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	
	var nearest_enemy = null
	var nearest_distance = detection_range
	var camera_direction = -camera.global_transform.basis.z.normalized()
	
	for enemy in enemies:
		if not enemy or not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		
		var enemy_center = enemy.global_position + Vector3(0, 1.2, 0)
		var distance = global_position.distance_to(enemy_center)
		if distance > nearest_distance:
			continue
		
		var direction_to_enemy = (enemy_center - camera.global_position).normalized()
		var dot_product = direction_to_enemy.dot(camera_direction)
		if dot_product > 0.7:
			nearest_distance = distance
			nearest_enemy = enemy
	
	if nearest_enemy:
		var enemy_center = nearest_enemy.global_position + Vector3(0, 1.2, 0)
		var direction = (enemy_center - camera.global_position).normalized()
		
		yaw = atan2(direction.x, direction.z)
		pitch = -asin(direction.y)
		pitch = clamp(pitch, -1.5, 1.5)
		
		rotation.y = yaw
		rotation.x = pitch

# =========================================================
# SHOOT ONCE
# =========================================================

func shoot_once():

	var fire_anim = ""

	if is_aiming:
		fire_anim = "RIG_UE5_Comando_AK_Aim_Fire"
	else:
		fire_anim = "RIG_UE5_Comando_AK_Fire"

	if anim_player:
		if anim_player.has_animation(fire_anim):
			anim_player.speed_scale = 2.0
			anim_player.stop(true)
			anim_player.play(fire_anim)
			current_anim = fire_anim

	if gun_sound:
		gun_sound.play()

	shoot()

# =========================================================
# SHOOT SYSTEM
# =========================================================

func shoot():

	if gun_tip == null:
		return

	if bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()

	get_tree().current_scene.add_child(bullet)

	var spawn_pos = gun_tip.global_position

	var direction = (-camera.global_transform.basis.z).normalized()

	spawn_pos += direction * 0.5

	bullet.global_position = spawn_pos
	bullet.direction = direction
	bullet.look_at(spawn_pos + direction, Vector3.UP)

	var space_state = get_world_3d().direct_space_state
	var ray_end = spawn_pos + direction * 1000.0
	var query = PhysicsRayQueryParameters3D.create(spawn_pos, ray_end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)

	if result:
		create_impact(result.position, result.normal, result.collider)

# =========================================================
# VISUAL IMPACT
# =========================================================

func create_impact(pos, normal_vec, collider = null):
	if impact_scene == null:
		return
	
	if collider and not is_instance_valid(collider):
		return
	
	var impact = impact_scene.instantiate()
	
	if impact == null:
		return
	
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos
	
	if collider and is_instance_valid(collider) and collider.has_method("take_damage"):
		collider.take_damage(25)
		_show_hit_marker()
		
		if "is_dead" in collider and collider.is_dead:
			_on_enemy_killed()
	
	impact.look_at(pos + normal_vec, Vector3.UP)
	
	if bullet_impact_scene:
		var particles = bullet_impact_scene.instantiate()
		if particles:
			get_tree().current_scene.add_child(particles)
			particles.global_position = pos
			particles.look_at(pos + normal_vec, Vector3.UP)
			particles.emitting = true
			particles.one_shot = true

# =========================================================
# HIT MARKER
# =========================================================

func _show_hit_marker():
	hit_marker_timer = hit_marker_duration

# =========================================================
# KILL TRACKING
# =========================================================

func _on_enemy_killed():
	kill_count += 1
	kill_streak += 1
	kill_streak_timer = 0.0
	
	if kill_streak == 2:
		_show_kill_streak("DOUBLE KILL!")
	elif kill_streak == 3:
		_show_kill_streak("TRIPLE KILL!")
	elif kill_streak == 4:
		_show_kill_streak("MULTI KILL!")
	elif kill_streak == 5:
		_show_kill_streak("KILL STREAK!")
	elif kill_streak >= 6:
		_show_kill_streak("UNSTOPPABLE! x" + str(kill_streak))

func _show_kill_streak(text: String):
	kill_streak_text = text
	kill_streak_display_timer = 3.0

# =========================================================
# RELOAD
# =========================================================

func reload_once():

	if anim_player:
		if anim_player.has_animation("RIG_UE5_Comando_AK_Reload"):
			anim_player.play("RIG_UE5_Comando_AK_Reload")
	
	ammo = max_ammo

# =========================================================
# UPDATE ANIMATION
# =========================================================

func update_animation():

	if is_dead:
		return

	if not anim_player:
		return

	if shooting:
		return

	var is_moving = abs(velocity.x) > 0.1 or abs(velocity.z) > 0.1

	var new_anim = ""

	if is_aiming:
		if is_moving:
			new_anim = "RIG_UE5_Comando_AK_Walk_Aim"
		else:
			new_anim = "RIG_UE5_Comando_AK_Idle_Aim"
	else:
		if is_moving:
			if is_sprinting:
				new_anim = "RIG_UE5_Comando_AK__Run"
			else:
				new_anim = "RIG_UE5_Comando_AK_Walk"
		else:
			new_anim = "RIG_UE5_Comando_AK_Idle"

	if new_anim != current_anim:
		if anim_player.has_animation(new_anim):
			anim_player.play(new_anim)
			current_anim = new_anim

# =========================================================
# IDLE
# =========================================================

func play_idle():
	if anim_player:
		if anim_player.has_animation("RIG_UE5_Comando_AK_Idle"):
			anim_player.play("RIG_UE5_Comando_AK_Idle")
			current_anim = "RIG_UE5_Comando_AK_Idle"

# =========================================================
# DAMAGE
# =========================================================

func take_damage(amount):
	health -= amount
	time_since_damage = 0.0

	damage_flash_timer = 0.4
	camera_shake_intensity = clamp(float(amount) / 20.0, 0.3, 1.5)

	if damage_sound:
		damage_sound.pitch_scale = randf_range(0.8, 1.2)
		if damage_sound.playing:
			damage_sound.stop()
		damage_sound.play()

	if hit_effect_scene:
		var hit_effect = hit_effect_scene.instantiate()
		add_child(hit_effect)
		hit_effect.global_position = global_position + Vector3(0, 1.5, 0)
		hit_effect.emitting = true
		hit_effect.one_shot = true

	if health <= 0:
		die()

# =========================================================
# DIE
# =========================================================

func die():
	is_dead = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if anim_player:
		anim_player.stop()
	
	if death_screen:
		death_screen.visible = true

# =========================================================
# GETTERS
# =========================================================

func get_health():
	return health

func get_ammo():
	return ammo

func check_enemies_alive():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var alive_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dead = false
		if "is_dead" in enemy:
			dead = enemy.is_dead
		if not dead:
			alive_count += 1

# =========================================================
# UI CREATION — éléments modernes
# =========================================================

func _create_damage_overlay():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "DamageCanvas"
		canvas.layer = 100
		get_tree().current_scene.add_child(canvas)
	
	damage_overlay = ColorRect.new()
	damage_overlay.name = "DamageOverlay"
	damage_overlay.color = Color(0.8, 0.0, 0.0, 0.0)
	damage_overlay.anchors_preset = Control.PRESET_FULL_RECT
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.visible = false
	canvas.add_child(damage_overlay)

func _create_vignette_overlay():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	
	vignette_overlay = ColorRect.new()
	vignette_overlay.name = "VignetteOverlay"
	vignette_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	vignette_overlay.anchors_preset = Control.PRESET_FULL_RECT
	vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_overlay.visible = false
	canvas.add_child(vignette_overlay)

func _update_vignette(delta):
	if not vignette_overlay:
		return
	if health < 30:
		vignette_overlay.visible = true
		vignette_pulse_timer += delta * 3.0
		var pulse = (sin(vignette_pulse_timer) + 1.0) / 2.0
		var alpha = lerp(0.1, 0.35, pulse) * (1.0 - float(health) / 30.0)
		vignette_overlay.color = Color(0.6, 0.0, 0.0, alpha)
	else:
		vignette_overlay.visible = false
		vignette_pulse_timer = 0.0

func _create_hit_marker_ui():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	
	hit_marker_ui = Control.new()
	hit_marker_ui.name = "HitMarker"
	hit_marker_ui.anchors_preset = Control.PRESET_CENTER
	hit_marker_ui.visible = false
	hit_marker_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hit_marker_ui)
	
	var marker_size := 16.0
	var marker_thickness := 2.0
	var marker_gap := 4.0
	var colors = [Color.WHITE]
	
	for c in colors:
		var line1 = ColorRect.new()
		line1.color = c
		line1.size = Vector2(marker_size, marker_thickness)
		line1.position = Vector2(-marker_size - marker_gap, -marker_thickness / 2.0)
		line1.rotation = 0.785
		line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit_marker_ui.add_child(line1)
		
		var line2 = ColorRect.new()
		line2.color = c
		line2.size = Vector2(marker_size, marker_thickness)
		line2.position = Vector2(marker_gap, -marker_thickness / 2.0)
		line2.rotation = 0.785
		line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit_marker_ui.add_child(line2)
		
		var line3 = ColorRect.new()
		line3.color = c
		line3.size = Vector2(marker_size, marker_thickness)
		line3.position = Vector2(-marker_thickness / 2.0, -marker_size - marker_gap)
		line3.rotation = 0.785
		line3.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit_marker_ui.add_child(line3)
		
		var line4 = ColorRect.new()
		line4.color = c
		line4.size = Vector2(marker_size, marker_thickness)
		line4.position = Vector2(-marker_thickness / 2.0, marker_gap)
		line4.rotation = 0.785
		line4.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit_marker_ui.add_child(line4)

func _create_kill_counter_ui():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	
	kill_counter_label = Label.new()
	kill_counter_label.name = "KillCounter"
	kill_counter_label.text = "KILLS: 0"
	kill_counter_label.add_theme_font_size_override("font_size", 20)
	kill_counter_label.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
	kill_counter_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	kill_counter_label.add_theme_constant_override("shadow_offset_x", 2)
	kill_counter_label.add_theme_constant_override("shadow_offset_y", 2)
	kill_counter_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	kill_counter_label.position = Vector2(-160, -60)
	kill_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(kill_counter_label)

func _create_kill_streak_label():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	
	kill_streak_label = Label.new()
	kill_streak_label.name = "KillStreakLabel"
	kill_streak_label.text = ""
	kill_streak_label.add_theme_font_size_override("font_size", 32)
	kill_streak_label.add_theme_color_override("font_color", Color(1, 0.3, 0, 1))
	kill_streak_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	kill_streak_label.add_theme_constant_override("shadow_offset_x", 2)
	kill_streak_label.add_theme_constant_override("shadow_offset_y", 2)
	kill_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill_streak_label.anchors_preset = Control.PRESET_CENTER_TOP
	kill_streak_label.position = Vector2(-150, 80)
	kill_streak_label.size = Vector2(300, 50)
	kill_streak_label.visible = false
	kill_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(kill_streak_label)

func _create_death_screen():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	
	death_screen = Control.new()
	death_screen.name = "DeathScreen"
	death_screen.anchors_preset = Control.PRESET_FULL_RECT
	death_screen.visible = false
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(death_screen)
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.0, 0.0, 0.7)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_screen.add_child(bg)
	
	var title = Label.new()
	title.text = "VOUS ÊTES MORT"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_CENTER
	title.position = Vector2(-200, -80)
	title.size = Vector2(400, 60)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_screen.add_child(title)
	
	var score = Label.new()
	score.name = "DeathScore"
	score.text = "Score: 0 kills"
	score.add_theme_font_size_override("font_size", 24)
	score.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.anchors_preset = Control.PRESET_CENTER
	score.position = Vector2(-200, -10)
	score.size = Vector2(400, 40)
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_screen.add_child(score)
	
	var restart_label = Label.new()
	restart_label.text = "Appuyez sur R pour recommencer"
	restart_label.add_theme_font_size_override("font_size", 18)
	restart_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.anchors_preset = Control.PRESET_CENTER
	restart_label.position = Vector2(-200, 40)
	restart_label.size = Vector2(400, 30)
	restart_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_screen.add_child(restart_label)

func _update_death_screen(_delta):
	if death_screen and death_screen.visible:
		var score_label = death_screen.get_node_or_null("DeathScore")
		if score_label:
			score_label.text = "Score: " + str(kill_count) + " kills"
