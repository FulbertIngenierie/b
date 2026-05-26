extends CharacterBody3D

# =========================================================
# NODES
# =========================================================

@onready var camera = $Head/Camera3D
@onready var head = $Head

@onready var anim_player = $CharacterModel/AnimationPlayer

@onready var gun_sound = $GunSound

var damage_sound: AudioStreamPlayer3D = null

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

var bullet_scene = preload(
	"res://Bullet.tscn"
)

var impact_scene = preload(
	"res://Impact.tscn"
)

var hit_effect_scene = preload(
	"res://HitEffect.tscn"
)

var bullet_impact_scene = preload(
	"res://BulletImpact.tscn"
)

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

# Variables pour stocker les mouvements de souris
var mouse_delta = Vector2.ZERO

var current_speed = 5.0

# =========================================================
# SHOOT
# =========================================================

var is_aiming = false

var shooting = false
var can_auto_fire = false

# AK47 FIRE RATE
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
var ammo = 30
var is_dead = false

# =========================================================
# READY
# =========================================================

func _ready():

	Input.set_mouse_mode(
		Input.MOUSE_MODE_CAPTURED
	)

	print("=== FPS READY ===")

	print("GunTip :", gun_tip)

	play_idle()

	# Ajouter au groupe player pour que les ennemis puissent le trouver
	add_to_group("player")

	# Récupérer le crosshair
	crosshair = get_tree().current_scene.get_node_or_null("CanvasLayer/Crosshair")
	if crosshair:
		crosshair.show()

	# Créer le son de dégâts
	damage_sound = AudioStreamPlayer3D.new()
	add_child(damage_sound)
	damage_sound.volume_db = 0.0
	damage_sound.max_distance = 50.0

# =========================================================
# INPUT
# =========================================================

func _input(event):

	if is_dead:
		return

	# =====================================================
	# CAMERA - Stocker les mouvements de souris
	# =====================================================

	if event is InputEventMouseMotion:
		mouse_delta += event.relative

	# =====================================================
	# AIM
	# =====================================================

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_RIGHT:

			is_aiming = event.pressed

			update_animation()
			
			# Mettre à jour le crosshair
			if crosshair:
				crosshair.set_aiming(is_aiming)
			
			# Cibler automatiquement l'ennemi le plus proche dans la zone de visée
			if is_aiming:
				aim_at_nearest_enemy()

	# =====================================================
	# SHOOT
	# =====================================================

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT:

			# START FIRE
			if event.pressed:

				shooting = true

				start_auto_fire()

			# STOP FIRE
			else:

				shooting = false

				update_animation()

	# =====================================================
	# RELOAD
	# =====================================================

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

		await get_tree().create_timer(
			fire_rate
		).timeout

	can_auto_fire = false

# =========================================================
# PROCESS - Synchronisé au FPS pour la caméra
# =========================================================

func _process(delta):

	if is_dead:
		return
	
	# Vérifier si tous les ennemis sont morts
	check_enemies_alive()
	
	# =====================================================
	# CAMERA - Appliquer les mouvements de souris
	# =====================================================
	
	if mouse_delta != Vector2.ZERO:
		yaw -= mouse_delta.x * mouse_sensitivity
		pitch += mouse_delta.y * mouse_sensitivity
		pitch = clamp(pitch, -1.5, 1.5)
		
		rotation.y = yaw
		rotation.x = pitch
		
		# Réinitialiser mouse_delta
		mouse_delta = Vector2.ZERO

	# =====================================================
	# UPDATE ZOOM
	# =====================================================

	var target_fov = aim_fov if is_aiming else normal_fov
	current_fov = lerp(current_fov, target_fov, zoom_speed * delta)

	if camera:
		camera.fov = current_fov

	# =====================================================
	# DAMAGE FLASH EFFECT
	# =====================================================

	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		var flash_alpha = damage_flash_timer / 0.3
		if camera.environment:
			camera.environment.vignette_intensity = flash_alpha * 2.0
			camera.environment.tonemap_exposure = 1.0 - flash_alpha * 0.5
	else:
		if camera.environment:
			camera.environment.vignette_intensity = 0.0
			camera.environment.tonemap_exposure = 1.0

	# =====================================================
	# CAMERA SHAKE EFFECT
	# =====================================================

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

	update_animation()

# =========================================================
# PHYSICS PROCESS - Mouvement synchronisé à la physique
# =========================================================

func _physics_process(delta):

	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# =====================================================
	# SPEED
	# =====================================================

	current_speed = (
		sprint_speed
		if Input.is_key_pressed(KEY_SHIFT)
		else speed
	)

	# =====================================================
	# JUMP
	# =====================================================

	if Input.is_key_pressed(KEY_SPACE):

		if is_on_floor():

			velocity.y = jump_velocity

	# =====================================================
	# INPUT
	# =====================================================

	var input_dir = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1

	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1

	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1

	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	# =====================================================
	# DIRECTION
	# =====================================================

	var direction = (
		transform.basis
		*
		Vector3(
			-input_dir.x,
			0,
			-input_dir.y
		)
	).normalized()

	# =====================================================
	# MOVE
	# =====================================================

	if direction != Vector3.ZERO:

		velocity.x = (
			direction.x
			*
			current_speed
		)

		velocity.z = (
			direction.z
			*
			current_speed
		)

	else:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			current_speed
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			current_speed
		)

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
	
	for enemy in enemies:
		if not enemy or not is_instance_valid(enemy):
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			# Vérifier si l'ennemi est dans la zone de visée
			var direction_to_enemy = (enemy.global_position - global_position).normalized()
			var camera_direction = -camera.global_transform.basis.z.normalized()
			
			var dot_product = direction_to_enemy.dot(camera_direction)
			if dot_product > 0.5:  # Dans un cône de 60 degrés
				nearest_distance = distance
				nearest_enemy = enemy
	
	if nearest_enemy:
		# Tourner la caméra vers l'ennemi
		var direction = (nearest_enemy.global_position - global_position).normalized()
		var target_angle = atan2(direction.x, direction.z)
		yaw = target_angle
		rotation.y = yaw

# =========================================================
# SHOOT ONCE
# =========================================================

func shoot_once():

	var fire_anim = ""

	if is_aiming:

		fire_anim = (
			"RIG_UE5_Comando_AK_Aim_Fire"
		)

	else:

		fire_anim = (
			"RIG_UE5_Comando_AK_Fire"
		)

	# =====================================================
	# FIRE ANIMATION
	# =====================================================

	if anim_player:

		if anim_player.has_animation(
			fire_anim
		):

			# IMPORTANT :
			# synchro cadence AK47
			anim_player.speed_scale = 2.0

			anim_player.stop(true)

			anim_player.play(
				fire_anim
			)

			current_anim = fire_anim

	# =====================================================
	# GUN SOUND
	# =====================================================

	if gun_sound:

		gun_sound.play()

	# =====================================================
	# CREATE BULLET
	# =====================================================

	shoot()

	print("TIR :", fire_anim)

# =========================================================
# SHOOT SYSTEM
# =========================================================

func shoot():

	if gun_tip == null:

		print("GunTip NULL")

		return

	if bullet_scene == null:

		print("BulletScene NULL")

		return

	# =====================================================
	# CREATE BULLET
	# =====================================================

	var bullet = bullet_scene.instantiate()

	get_tree().current_scene.add_child(
		bullet
	)

	# =====================================================
	# POSITION EXACTE DU CANON
	# =====================================================

	var spawn_pos = gun_tip.global_position

	# =====================================================
	# DIRECTION CAMERA
	# IMPORTANT :
	# ON NE TOUCHE PAS AU GUNTIP
	# =====================================================

	var direction = (
		-camera.global_transform.basis.z
	).normalized()

	# =====================================================
	# PETIT OFFSET DEVANT LE CANON
	# =====================================================

	spawn_pos += (
		direction
		*
		0.5
	)

	# =====================================================
	# POSITION BULLET
	# =====================================================

	bullet.global_position = spawn_pos

	# =====================================================
	# DIRECTION BULLET
	# =====================================================

	bullet.direction = direction

	# =====================================================
	# ROTATION BULLET
	# =====================================================

	bullet.look_at(
		spawn_pos + direction,
		Vector3.UP
	)

	# =====================================================
	# IMPACT RAYCAST
	# =====================================================

	var space_state = (
		get_world_3d().direct_space_state
	)

	var ray_end = (
		spawn_pos
		+
		direction * 1000.0
	)

	var query = (
		PhysicsRayQueryParameters3D.create(
			spawn_pos,
			ray_end
		)
	)

	query.exclude = [self]

	var result = (
		space_state.intersect_ray(
			query
		)
	)

	# =====================================================
	# IMPACT
	# =====================================================

	if result:
		create_impact(
			result.position,
			result.normal,
			result.collider
		)

# =========================================================
# VISUAL IMPACT
# =========================================================

func create_impact(pos, normal, collider = null):
	if impact_scene == null:
		return
	
	# Vérifier si le collider est valide
	if collider and not is_instance_valid(collider):
		return
	
	var impact = impact_scene.instantiate()
	
	if impact == null:
		return
	
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos
	
	# Appliquer des dégâts si le collider a une méthode take_damage
	if collider and is_instance_valid(collider) and collider.has_method("take_damage"):
		collider.take_damage(25)  # Dégâts du joueur
	
	impact.look_at(pos + normal, Vector3.UP)
	
	# Ajouter des particules d'impact
	if bullet_impact_scene:
		var particles = bullet_impact_scene.instantiate()
		if particles:
			get_tree().current_scene.add_child(particles)
			particles.global_position = pos
			particles.look_at(pos + normal, Vector3.UP)
			particles.emitting = true
			particles.one_shot = true

# =========================================================
# RELOAD
# =========================================================

func reload_once():

	if anim_player:

		if anim_player.has_animation(
			"RIG_UE5_Comando_AK_Reload"
		):

			anim_player.play(
				"RIG_UE5_Comando_AK_Reload"
			)

# =========================================================
# UPDATE ANIMATION
# =========================================================

func update_animation():

	if is_dead:
		return

	if not anim_player:
		return

	# IMPORTANT :
	# si tir en cours
	# ne pas remplacer anim tir
	if shooting:
		return

	var is_moving = (
		abs(velocity.x) > 0.1
		or
		abs(velocity.z) > 0.1
	)

	var is_sprinting = (
		Input.is_key_pressed(KEY_SHIFT)
	)

	var new_anim = ""

	# =====================================================
	# AIM
	# =====================================================

	if is_aiming:

		if is_moving:

			new_anim = (
				"RIG_UE5_Comando_AK_Walk_Aim"
			)

		else:

			new_anim = (
				"RIG_UE5_Comando_AK_Idle_Aim"
			)

	# =====================================================
	# NORMAL
	# =====================================================

	else:

		if is_moving:

			if is_sprinting:

				new_anim = (
					"RIG_UE5_Comando_AK__Run"
				)

			else:

				new_anim = (
					"RIG_UE5_Comando_AK_Walk"
				)

		else:

			new_anim = (
				"RIG_UE5_Comando_AK_Idle"
			)

	# =====================================================
	# PLAY
	# =====================================================

	if new_anim != current_anim:

		if anim_player.has_animation(
			new_anim
		):

			anim_player.play(
				new_anim
			)

			current_anim = new_anim

# =========================================================
# IDLE
# =========================================================

func play_idle():

	if anim_player:

		if anim_player.has_animation(
			"RIG_UE5_Comando_AK_Idle"
		):

			anim_player.play(
				"RIG_UE5_Comando_AK_Idle"
			)

			current_anim = (
				"RIG_UE5_Comando_AK_Idle"
			)

# =========================================================
# DAMAGE
# =========================================================

func take_damage(amount):

	health -= amount

	# Effet de flash rouge sur l'écran
	damage_flash_timer = 0.3

	# Effet de caméra secouée
	camera_shake_intensity = 0.5

	# Son de gémissement
	if damage_sound:
		damage_sound.pitch_scale = randf_range(0.9, 1.1)
		if damage_sound.playing:
			damage_sound.stop()
		damage_sound.play()

	# Effet de particules rouge
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
	
	# Afficher l'écran de game over
	get_tree().change_scene_to_file("res://GameOver.tscn")

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
		if enemy.has_method("get_health"):
			if enemy.get_health() > 0:
				alive_count += 1
		elif "health" in enemy:
			if enemy.health > 0:
				alive_count += 1
	
	# Si tous les ennemis sont morts, afficher l'écran de victoire
	if alive_count == 0 and enemies.size() > 0:
		get_tree().change_scene_to_file("res://GameOver.tscn")
