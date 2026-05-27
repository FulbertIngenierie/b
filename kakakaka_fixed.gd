extends CharacterBody3D

# =========================================================
# AKA_FPK — AKAZZA Player Controller
# =========================================================
# Gunfeel AAA + Mouvement fluide + Killstreaks + Armes

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
# SLIDE
# =========================================================

var is_sliding := false
var slide_speed := 14.0
var slide_timer := 0.0
var slide_duration := 0.8
var slide_direction := Vector3.ZERO
var slide_cooldown := 0.0
var can_slide := true

# =========================================================
# VAULT
# =========================================================

var is_vaulting := false
var vault_timer := 0.0
var vault_duration := 0.4
var vault_start_pos := Vector3.ZERO
var vault_end_pos := Vector3.ZERO

# =========================================================
# ARMES — système complet
# =========================================================

var current_weapon := 0

# Arme 0: AK-47, Arme 1: PISTOL, Arme 2: SHOTGUN
var weapons := ["AK47", "PISTOL", "SHOTGUN"]
var weapon_names := ["AK-47", "PISTOL", "SHOTGUN"]
var weapon_fire_rates := [0.09, 0.18, 0.6]
var weapon_damages := [28, 42, 15]
var weapon_ammos := [30, 12, 8]
var weapon_max_ammos := [30, 12, 8]
var weapon_total_ammos := [120, 48, 32]
var weapon_recoil_pitch := [0.012, 0.008, 0.04]
var weapon_recoil_yaw := [0.004, 0.002, 0.015]
var weapon_recoil_recovery := [6.0, 8.0, 4.0]
var weapon_spread := [0.01, 0.005, 0.06]
var weapon_pellets := [1, 1, 6]

# =========================================================
# GRENADES
# =========================================================

var grenades := 3
var max_grenades := 5
var can_throw_grenade := true
var grenade_cooldown := 1.5

# =========================================================
# SHOOT
# =========================================================

var is_aiming = false
var shooting = false
var can_auto_fire = false
var fire_rate = 0.09
var player_damage = 28

# =========================================================
# GUNFEEL — recoil dynamique
# =========================================================

var recoil_pitch := 0.0
var recoil_yaw := 0.0
var recoil_target_pitch := 0.0
var recoil_target_yaw := 0.0
var recoil_recovery_speed := 6.0
var current_recoil_pitch_per_shot := 0.012
var current_recoil_yaw_per_shot := 0.004
var current_spread := 0.01

# =========================================================
# GUNFEEL — camera shake au tir
# =========================================================

var camera_shake_intensity := 0.0
var shoot_shake_amount := 0.015

# =========================================================
# GUNFEEL — muzzle flash
# =========================================================

var muzzle_flash: MeshInstance3D = null
var muzzle_flash_timer := 0.0

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
var headshot_marker := false

# =========================================================
# KILL CONFIRMATION
# =========================================================

var kill_confirm_timer := 0.0
var kill_confirm_text := ""

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
# UI ELEMENTS
# =========================================================

var hit_marker_ui: Control = null
var kill_streak_label: Label = null
var kill_counter_label: Label = null
var weapon_label: Label = null
var grenade_label: Label = null
var kill_confirm_label: Label = null

# =========================================================
# KILLSTREAKS
# =========================================================

var killstreak_rewards := {3: "RADAR", 5: "TOURELLE", 7: "DRONE", 10: "MISSILE"}
var active_killstreaks: Array[String] = []
var killstreak_label: Label = null
var ai_director = null
var radar_active := false
var radar_timer := 0.0
var radar_duration := 15.0
var turret_node: Node3D = null
var turret_timer := 0.0
var turret_duration := 20.0
var drone_active := false
var drone_timer := 0.0
var drone_duration := 12.0

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
	_create_weapon_label()
	_create_grenade_label()
	_create_muzzle_flash()
	_create_kill_confirm_label()
	_create_killstreak_label()
	_find_ai_director()
	
	_switch_weapon(0)

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
		
		if event.keycode == KEY_1 and event.pressed:
			_switch_weapon(0)
		if event.keycode == KEY_2 and event.pressed:
			_switch_weapon(1)
		if event.keycode == KEY_3 and event.pressed:
			_switch_weapon(2)
		
		if event.keycode == KEY_G and event.pressed:
			throw_grenade()
		
		# Killstreak activation
		if event.keycode == KEY_4 and event.pressed:
			_activate_killstreak()

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
	
	# Mouse look
	if mouse_delta != Vector2.ZERO:
		yaw -= mouse_delta.x * mouse_sensitivity
		pitch += mouse_delta.y * mouse_sensitivity
		pitch = clamp(pitch, -1.5, 1.5)
		rotation.y = yaw
		rotation.x = pitch
		mouse_delta = Vector2.ZERO

	# FOV zoom
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

	# GUNFEEL — recoil recovery (camera revient en place)
	if recoil_pitch > 0.001:
		var recovery = recoil_recovery_speed * delta
		var pitch_recovery = min(recoil_pitch, recovery)
		pitch -= pitch_recovery
		pitch = clamp(pitch, -1.5, 1.5)
		rotation.x = pitch
		recoil_pitch -= pitch_recovery
	
	if abs(recoil_yaw) > 0.0005:
		var yaw_recovery = sign(recoil_yaw) * recoil_recovery_speed * delta * 0.3
		if abs(yaw_recovery) > abs(recoil_yaw):
			yaw_recovery = recoil_yaw
		yaw -= yaw_recovery
		rotation.y = yaw
		recoil_yaw -= yaw_recovery

	# Camera shake (from damage)
	if camera_shake_intensity > 0:
		camera_shake_intensity -= delta * 2.0
		var shake_offset = Vector3(
			randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)
		).normalized() * camera_shake_intensity
		camera.rotation.x += shake_offset.x * 0.02
		camera.rotation.y += shake_offset.y * 0.02
		camera_shake_intensity = max(0, camera_shake_intensity)

	# Muzzle flash fade
	if muzzle_flash_timer > 0:
		muzzle_flash_timer -= delta
		if muzzle_flash:
			muzzle_flash.visible = muzzle_flash_timer > 0
	elif muzzle_flash:
		muzzle_flash.visible = false

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
			# Headshot = rouge, normal = blanc
			for child in hit_marker_ui.get_children():
				if child is ColorRect:
					child.color = Color.RED if headshot_marker else Color.WHITE
	else:
		if hit_marker_ui:
			hit_marker_ui.visible = false

	# Kill confirmation
	if kill_confirm_timer > 0:
		kill_confirm_timer -= delta
		if kill_confirm_label:
			kill_confirm_label.visible = true
			kill_confirm_label.text = kill_confirm_text
			kill_confirm_label.modulate.a = clamp(kill_confirm_timer / 1.5, 0, 1)
	else:
		if kill_confirm_label:
			kill_confirm_label.visible = false

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

	# Slide cooldown
	if slide_cooldown > 0:
		slide_cooldown -= delta
		if slide_cooldown <= 0:
			can_slide = true

	# Killstreak timers
	_update_killstreaks(delta)

	# Update UI
	if kill_counter_label:
		kill_counter_label.text = "KILLS: " + str(kill_count)
	if weapon_label:
		weapon_label.text = weapon_names[current_weapon] + " | " + str(ammo) + "/" + str(total_ammo)
	if grenade_label:
		grenade_label.text = "GRENADES: " + str(grenades)

	update_animation()

# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(delta):
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- SLIDE ---
	if is_sliding:
		slide_timer -= delta
		velocity.x = slide_direction.x * slide_speed
		velocity.z = slide_direction.z * slide_speed
		if slide_timer <= 0:
			is_sliding = false
			slide_cooldown = 1.0
		move_and_slide()
		return

	# --- VAULT ---
	if is_vaulting:
		vault_timer += delta
		var t = clamp(vault_timer / vault_duration, 0.0, 1.0)
		global_position = vault_start_pos.lerp(vault_end_pos, t)
		if t >= 1.0:
			is_vaulting = false
		return

	is_sprinting = Input.is_key_pressed(KEY_SHIFT) and not is_aiming
	current_speed = sprint_speed if is_sprinting else speed

	# Slide: Ctrl pendant le sprint
	if Input.is_key_pressed(KEY_CTRL) and is_sprinting and is_on_floor() and can_slide and not is_sliding:
		_start_slide()

	# Jump
	if Input.is_key_pressed(KEY_SPACE):
		if is_on_floor():
			# Check vault
			if _can_vault():
				_start_vault()
			else:
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
# SLIDE
# =========================================================

func _start_slide():
	is_sliding = true
	can_slide = false
	slide_timer = slide_duration
	slide_direction = -transform.basis.z.normalized()
	# Camera lower effect
	if camera:
		camera.position.y -= 0.5

func _end_slide():
	is_sliding = false
	if camera:
		camera.position.y += 0.5

# =========================================================
# VAULT
# =========================================================

func _can_vault() -> bool:
	var space_state = get_world_3d().direct_space_state
	var forward = -transform.basis.z.normalized()
	
	# Check obstacle devant (hauteur hanche)
	var ray_start = global_position + Vector3(0, 0.8, 0)
	var ray_end = ray_start + forward * 1.5
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if not result:
		return false
	
	# Check espace libre au-dessus
	var top_start = global_position + Vector3(0, 2.2, 0)
	var top_end = top_start + forward * 1.5
	var top_query = PhysicsRayQueryParameters3D.create(top_start, top_end)
	top_query.exclude = [self]
	var top_result = space_state.intersect_ray(top_query)
	
	return top_result == null or top_result.is_empty()

func _start_vault():
	is_vaulting = true
	vault_timer = 0.0
	vault_start_pos = global_position
	var forward = -transform.basis.z.normalized()
	vault_end_pos = global_position + forward * 2.0 + Vector3(0, 1.5, 0)

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
# SHOOT ONCE — avec GUNFEEL
# =========================================================

func _find_ai_director():
	var directors = get_tree().get_nodes_in_group("ai_director")
	if directors.size() > 0:
		ai_director = directors[0]

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
		gun_sound.pitch_scale = randf_range(0.95, 1.05)
		gun_sound.play()

	# GUNFEEL — recoil dynamique
	_apply_recoil()
	
	# GUNFEEL — muzzle flash
	_show_muzzle_flash()
	
	# GUNFEEL — camera micro-shake
	camera_shake_intensity = max(camera_shake_intensity, shoot_shake_amount)

	# Tir
	if ai_director:
		ai_director.register_shot()
	var pellets = weapon_pellets[current_weapon]
	for i in range(pellets):
		shoot()
	
	ammo -= 1
	if ammo <= 0:
		reload_once()

# =========================================================
# GUNFEEL — RECOIL
# =========================================================

func _apply_recoil():
	var pitch_kick = current_recoil_pitch_per_shot
	var yaw_kick = randf_range(-current_recoil_yaw_per_shot, current_recoil_yaw_per_shot)
	
	# Moins de recoil en visant
	if is_aiming:
		pitch_kick *= 0.5
		yaw_kick *= 0.3
	
	pitch += pitch_kick
	pitch = clamp(pitch, -1.5, 1.5)
	yaw += yaw_kick
	rotation.x = pitch
	rotation.y = yaw
	
	recoil_pitch += pitch_kick
	recoil_yaw += yaw_kick

# =========================================================
# GUNFEEL — MUZZLE FLASH
# =========================================================

func _create_muzzle_flash():
	if not gun_tip:
		return
	muzzle_flash = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	muzzle_flash.mesh = quad
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1, 0.8, 0.2, 1)
	mat.emission_energy_multiplier = 5.0
	mat.albedo_color = Color(1, 0.7, 0.1, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	muzzle_flash.material_override = mat
	muzzle_flash.visible = false
	gun_tip.add_child(muzzle_flash)

func _show_muzzle_flash():
	muzzle_flash_timer = 0.04
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.scale = Vector3.ONE * randf_range(0.6, 1.0)
		muzzle_flash.rotation.z = randf() * PI * 2.0

# =========================================================
# SHOOT SYSTEM
# =========================================================

func shoot():
	if gun_tip == null or bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	var spawn_pos = gun_tip.global_position
	# Tir droit devant la caméra (pas décalé)
	var direction = (-camera.global_transform.basis.z).normalized()
	
	# Spread
	var spread = current_spread
	if is_aiming:
		spread *= 0.15
	if is_sprinting:
		spread *= 2.0
	if spread > 0:
		direction += Vector3(
			randf_range(-spread, spread),
			randf_range(-spread, spread),
			randf_range(-spread, spread)
		)
		direction = direction.normalized()

	# Spawn la balle depuis le gun tip mais dans la direction de la caméra
	spawn_pos = camera.global_position + direction * 1.0
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
		# Headshot detection (hit above 1.6m on enemy)
		var is_headshot = false
		if "global_position" in collider:
			var hit_height = pos.y - collider.global_position.y
			is_headshot = hit_height > 1.6
		
		var dmg = player_damage
		if is_headshot:
			dmg = int(dmg * 2.5)
		
		collider.take_damage(dmg)
		_show_hit_marker(is_headshot)
		
		if "is_dead" in collider and collider.is_dead:
			_on_enemy_killed(is_headshot)
	
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
# HIT MARKER — headshot = rouge
# =========================================================

func _show_hit_marker(is_headshot: bool = false):
	hit_marker_timer = hit_marker_duration
	headshot_marker = is_headshot
	if is_headshot:
		hit_marker_timer = 0.4

# =========================================================
# KILL TRACKING — avec killstreak rewards
# =========================================================

func _on_enemy_killed(is_headshot: bool = false):
	kill_count += 1
	kill_streak += 1
	kill_streak_timer = 0.0
	
	# Kill confirmation
	if is_headshot:
		kill_confirm_text = "HEADSHOT!"
		kill_confirm_timer = 2.0
	else:
		kill_confirm_text = "KILL CONFIRMED"
		kill_confirm_timer = 1.5
	
	# Kill streak announcements
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
	
	# Killstreak rewards
	if kill_streak in killstreak_rewards:
		var reward = killstreak_rewards[kill_streak]
		active_killstreaks.append(reward)
		_show_kill_streak("KILLSTREAK: " + reward + " DISPONIBLE! (Touche 4)")

func _show_kill_streak(text: String):
	kill_streak_text = text
	kill_streak_display_timer = 3.0

# =========================================================
# KILLSTREAKS
# =========================================================

func _activate_killstreak():
	if active_killstreaks.is_empty():
		return
	var ks = active_killstreaks.pop_front()
	match ks:
		"RADAR":
			_activate_radar()
		"TOURELLE":
			_activate_turret()
		"DRONE":
			_activate_drone()
		"MISSILE":
			_activate_missile()

func _activate_radar():
	radar_active = true
	radar_timer = radar_duration
	_show_kill_streak("RADAR ACTIF — 15s")

func _activate_turret():
	turret_timer = turret_duration
	# Créer tourelle à la position du joueur
	turret_node = _create_turret()
	_show_kill_streak("TOURELLE DEPLOYÉE — 20s")

func _activate_drone():
	drone_active = true
	drone_timer = drone_duration
	# Le drone révèle tous les ennemis et tire
	_show_kill_streak("DRONE ACTIF — 12s")

func _activate_missile():
	# Missile aérien sur la position du joueur (frappe la zone devant)
	var strike_pos = global_position + (-transform.basis.z.normalized()) * 20.0
	_missile_strike(strike_pos)
	_show_kill_streak("MISSILE AÉRIEN LANCÉ!")

func _update_killstreaks(delta):
	if radar_active:
		radar_timer -= delta
		if radar_timer <= 0:
			radar_active = false
	
	if turret_timer > 0:
		turret_timer -= delta
		if turret_node and is_instance_valid(turret_node):
			_turret_ai(delta)
		if turret_timer <= 0 and turret_node and is_instance_valid(turret_node):
			turret_node.queue_free()
			turret_node = null
	
	if drone_active:
		drone_timer -= delta
		_drone_ai(delta)
		if drone_timer <= 0:
			drone_active = false
	
	# Update killstreak label
	if killstreak_label:
		if not active_killstreaks.is_empty():
			killstreak_label.text = "KILLSTREAK: " + active_killstreaks[0] + " (4)"
			killstreak_label.visible = true
		else:
			killstreak_label.visible = false

func _create_turret() -> Node3D:
	var turret = Node3D.new()
	turret.name = "Turret"
	get_tree().current_scene.add_child(turret)
	turret.global_position = global_position + Vector3(0, 0.5, 0)
	
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 1.0)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.4, 0.3, 1)
	mesh.material_override = mat
	turret.add_child(mesh)
	
	var sound = AudioStreamPlayer3D.new()
	sound.name = "TurretSound"
	turret.add_child(sound)
	
	return turret

var turret_fire_cd := 0.0

func _turret_ai(delta):
	if not turret_node or not is_instance_valid(turret_node):
		return
	turret_fire_cd -= delta
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var nearest_dist := 30.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or ("is_dead" in enemy and enemy.is_dead):
			continue
		var d = turret_node.global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	
	if nearest and turret_fire_cd <= 0:
		turret_fire_cd = 0.3
		if nearest.has_method("take_damage"):
			nearest.take_damage(15)
			if "is_dead" in nearest and nearest.is_dead:
				_on_enemy_killed(false)

func _drone_ai(delta):
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or ("is_dead" in enemy and enemy.is_dead):
			continue
		# Drone tire sur les ennemis visibles
		if randf() < delta * 2.0 and enemy.has_method("take_damage"):
			enemy.take_damage(8)
			if "is_dead" in enemy and enemy.is_dead:
				_on_enemy_killed(false)

func _missile_strike(pos: Vector3):
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = pos.distance_to(enemy.global_position)
		if dist < 15.0:
			var dmg = int(150 * (1.0 - dist / 15.0))
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
				if "is_dead" in enemy and enemy.is_dead:
					_on_enemy_killed(false)
	
	# Effet visuel explosion massive
	if hit_effect_scene:
		for i in range(8):
			var effect = hit_effect_scene.instantiate()
			get_tree().current_scene.add_child(effect)
			effect.global_position = pos + Vector3(randf_range(-5, 5), randf_range(0, 4), randf_range(-5, 5))
			effect.emitting = true
			effect.one_shot = true

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
	if is_dead or not anim_player or shooting:
		return

	var is_moving = abs(velocity.x) > 0.1 or abs(velocity.z) > 0.1
	var new_anim = ""

	if is_sliding:
		new_anim = "RIG_UE5_Comando_AK__Run"
	elif is_aiming:
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
	if ai_director:
		ai_director.register_player_damage()
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
	if ai_director:
		ai_director.register_player_death()
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
# ARMES — changement
# =========================================================

func _switch_weapon(index: int):
	if index < 0 or index >= weapons.size():
		return
	current_weapon = index
	fire_rate = weapon_fire_rates[index]
	player_damage = weapon_damages[index]
	ammo = weapon_ammos[index]
	max_ammo = weapon_max_ammos[index]
	total_ammo = weapon_total_ammos[index]
	current_recoil_pitch_per_shot = weapon_recoil_pitch[index]
	current_recoil_yaw_per_shot = weapon_recoil_yaw[index]
	recoil_recovery_speed = weapon_recoil_recovery[index]
	current_spread = weapon_spread[index]

# =========================================================
# GRENADES
# =========================================================

func throw_grenade():
	if grenades <= 0 or not can_throw_grenade or is_dead:
		return
	
	can_throw_grenade = false
	grenades -= 1
	
	var grenade = _create_grenade()
	if grenade:
		var spawn_pos = global_position + Vector3(0, 1.5, 0)
		var direction = (-camera.global_transform.basis.z).normalized()
		get_tree().current_scene.add_child(grenade)
		grenade.global_position = spawn_pos
		if grenade is RigidBody3D:
			grenade.linear_velocity = direction * 20.0 + Vector3(0, 5.0, 0)
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(grenade_cooldown).timeout
		can_throw_grenade = true

func _create_grenade() -> Node3D:
	var grenade = RigidBody3D.new()
	grenade.name = "Grenade"
	grenade.mass = 0.5
	grenade.gravity_scale = 1.5
	
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.15
	collision.shape = sphere
	grenade.add_child(collision)
	
	var mesh = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	mesh.mesh = sphere_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.3, 0.15, 1)
	mesh.material_override = mat
	grenade.add_child(mesh)
	
	var timer = Timer.new()
	timer.wait_time = 2.5
	timer.one_shot = true
	timer.autostart = true
	grenade.add_child(timer)
	timer.timeout.connect(func(): _grenade_explode(grenade))
	
	return grenade

func _grenade_explode(grenade: Node3D):
	if not grenade or not is_instance_valid(grenade) or not grenade.is_inside_tree():
		return
	
	var explosion_pos = grenade.global_position
	var explosion_radius = 8.0
	var explosion_damage = 80
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = explosion_pos.distance_to(enemy.global_position)
		if dist < explosion_radius:
			var dmg = int(explosion_damage * (1.0 - dist / explosion_radius))
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
				if "is_dead" in enemy and enemy.is_dead:
					_on_enemy_killed(false)
	
	if hit_effect_scene:
		for i in range(5):
			var effect = hit_effect_scene.instantiate()
			get_tree().current_scene.add_child(effect)
			effect.global_position = explosion_pos + Vector3(randf_range(-2, 2), randf_range(0, 3), randf_range(-2, 2))
			effect.emitting = true
			effect.one_shot = true
	
	grenade.queue_free()

# =========================================================
# UI CREATION
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
	
	var line1 = ColorRect.new()
	line1.color = Color.WHITE
	line1.size = Vector2(marker_size, marker_thickness)
	line1.position = Vector2(-marker_size - marker_gap, -marker_thickness / 2.0)
	line1.rotation = 0.785
	line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_marker_ui.add_child(line1)
	
	var line2 = ColorRect.new()
	line2.color = Color.WHITE
	line2.size = Vector2(marker_size, marker_thickness)
	line2.position = Vector2(marker_gap, -marker_thickness / 2.0)
	line2.rotation = 0.785
	line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_marker_ui.add_child(line2)
	
	var line3 = ColorRect.new()
	line3.color = Color.WHITE
	line3.size = Vector2(marker_size, marker_thickness)
	line3.position = Vector2(-marker_thickness / 2.0, -marker_size - marker_gap)
	line3.rotation = 0.785
	line3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_marker_ui.add_child(line3)
	
	var line4 = ColorRect.new()
	line4.color = Color.WHITE
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
	kill_counter_label.position = Vector2(-180, -130)
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

func _create_weapon_label():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	weapon_label = Label.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.text = "AK-47 | 30/120"
	weapon_label.add_theme_font_size_override("font_size", 18)
	weapon_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	weapon_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	weapon_label.add_theme_constant_override("shadow_offset_x", 1)
	weapon_label.add_theme_constant_override("shadow_offset_y", 1)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	weapon_label.position = Vector2(-260, -110)
	weapon_label.size = Vector2(250, 30)
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(weapon_label)

func _create_grenade_label():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	grenade_label = Label.new()
	grenade_label.name = "GrenadeLabel"
	grenade_label.text = "GRENADES: 3"
	grenade_label.add_theme_font_size_override("font_size", 16)
	grenade_label.add_theme_color_override("font_color", Color(0.8, 1, 0.5, 0.9))
	grenade_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	grenade_label.add_theme_constant_override("shadow_offset_x", 1)
	grenade_label.add_theme_constant_override("shadow_offset_y", 1)
	grenade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grenade_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	grenade_label.position = Vector2(-260, -85)
	grenade_label.size = Vector2(250, 25)
	grenade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(grenade_label)

func _create_kill_confirm_label():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	kill_confirm_label = Label.new()
	kill_confirm_label.name = "KillConfirm"
	kill_confirm_label.text = ""
	kill_confirm_label.add_theme_font_size_override("font_size", 22)
	kill_confirm_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	kill_confirm_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	kill_confirm_label.add_theme_constant_override("shadow_offset_x", 2)
	kill_confirm_label.add_theme_constant_override("shadow_offset_y", 2)
	kill_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill_confirm_label.anchors_preset = Control.PRESET_CENTER
	kill_confirm_label.position = Vector2(-100, 50)
	kill_confirm_label.size = Vector2(200, 30)
	kill_confirm_label.visible = false
	kill_confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(kill_confirm_label)

func _create_killstreak_label():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	killstreak_label = Label.new()
	killstreak_label.name = "KillstreakReward"
	killstreak_label.text = ""
	killstreak_label.add_theme_font_size_override("font_size", 16)
	killstreak_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 0.9))
	killstreak_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	killstreak_label.add_theme_constant_override("shadow_offset_x", 1)
	killstreak_label.add_theme_constant_override("shadow_offset_y", 1)
	killstreak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	killstreak_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	killstreak_label.position = Vector2(-260, -155)
	killstreak_label.size = Vector2(250, 25)
	killstreak_label.visible = false
	killstreak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(killstreak_label)
