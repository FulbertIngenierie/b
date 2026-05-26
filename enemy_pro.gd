extends CharacterBody3D

# =========================================================
# NODES
# =========================================================

@onready var anim_player: AnimationPlayer = null
@onready var soldier_model = $SoldierModel

# Animation resources
var anim_run: Animation
var anim_gunplay: Animation
var anim_dying: Animation

# =========================================================
# VARIABLES
# =========================================================

var speed := 4.0
var detection_range := 60.0
var attack_range := 3.0
var damage := 15.0

var player: CharacterBody3D
var is_attacking := false
var can_attack := true
var attack_cooldown := 0.8
var health := 150
var is_dead := false

var current_anim := ""
var shoot_range := 30.0

# =========================================================
# READY
# =========================================================

func _ready():
	find_player()
	add_to_group("enemies")
	add_to_group("enemy_target")
	
	# Trouver l'AnimationPlayer dans le modèle instancié
	if soldier_model:
		anim_player = soldier_model.find_child("AnimationPlayer", true, false)
		soldier_model.visible = true
	
	# Charger les animations depuis les fichiers FBX
	load_animations()

func load_animations():
	if not anim_player:
		print("AnimationPlayer not found, cannot load animations")
		return
	
	print("AnimationPlayer found, loading animations...")
	print("Available animations in base model:", anim_player.get_animation_list())
	
	# Créer une bibliothèque d'animations
	var anim_library = AnimationLibrary.new()
	
	# Charger l'animation de gunplay depuis le fichier FBX
	var gunplay_scene = load("res://enemy pro /Gunplay (1).fbx")
	if gunplay_scene:
		var gunplay_instance = gunplay_scene.instantiate()
		if gunplay_instance:
			var gunplay_anim_player = gunplay_instance.find_child("AnimationPlayer", true, false)
			if gunplay_anim_player and gunplay_anim_player.get_animation_list().size() > 0:
				var anim_name = gunplay_anim_player.get_animation_list()[0]
				print("Gunplay animation name:", anim_name)
				anim_gunplay = gunplay_anim_player.get_animation(anim_name)
				if anim_gunplay:
					anim_library.add_animation("gunplay", anim_gunplay)
					print("Loaded gunplay animation")
			gunplay_instance.queue_free()
	
	# Charger l'animation de mort depuis le fichier FBX
	var dying_scene = load("res://enemy pro /Dying Backwards.fbx")
	if dying_scene:
		var dying_instance = dying_scene.instantiate()
		if dying_instance:
			var dying_anim_player = dying_instance.find_child("AnimationPlayer", true, false)
			if dying_anim_player and dying_anim_player.get_animation_list().size() > 0:
				var anim_name = dying_anim_player.get_animation_list()[0]
				print("Dying animation name:", anim_name)
				anim_dying = dying_anim_player.get_animation(anim_name)
				if anim_dying:
					anim_library.add_animation("dying", anim_dying)
					print("Loaded dying animation")
			dying_instance.queue_free()
	
	# Charger l'animation de mouvement depuis le fichier FBX
	var moving_scene = load("res://enemy pro /Moving Backward In Prone Position.fbx")
	if moving_scene:
		var moving_instance = moving_scene.instantiate()
		if moving_instance:
			var moving_anim_player = moving_instance.find_child("AnimationPlayer", true, false)
			if moving_anim_player and moving_anim_player.get_animation_list().size() > 0:
				var anim_name = moving_anim_player.get_animation_list()[0]
				print("Moving animation name:", anim_name)
				var anim_moving = moving_anim_player.get_animation(anim_name)
				if anim_moving:
					anim_library.add_animation("moving", anim_moving)
					print("Loaded moving animation")
			moving_instance.queue_free()
	
	# Utiliser l'animation du modèle de base comme animation de course
	if anim_player.get_animation_list().size() > 0:
		var base_anim_name = anim_player.get_animation_list()[0]
		anim_run = anim_player.get_animation(base_anim_name)
		if anim_run:
			anim_library.add_animation("run", anim_run)
			print("Using base animation as run animation")
	
	# Ajouter la bibliothèque à l'AnimationPlayer
	anim_player.add_animation_library("enemy_animations", anim_library)
	print("Animation library added to AnimationPlayer")
	
	# Jouer l'animation idle par défaut
	play_idle()

# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(delta):
	if is_dead:
		return
	
	if not player:
		find_player()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Si le joueur est proche, le chasser
	if distance_to_player <= detection_range:
		# Si assez proche pour tirer
		if distance_to_player <= shoot_range:
			# Si très proche, attaquer au corps à corps
			if distance_to_player <= attack_range:
				attack_player()
			else:
				# Tirer sur le joueur
				shoot_at_player()
		else:
			# Se déplacer vers le joueur
			move_towards_player(delta)
			play_run()
	else:
		# Animation idle si le joueur est loin
		play_idle()
		velocity = Vector3.ZERO
	
	move_and_slide()

# =========================================================
# TROUVER LE JOUEUR
# =========================================================

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# =========================================================
# SE DÉPLACER VERS LE JOUEUR
# =========================================================

func move_towards_player(_delta):
	if not player:
		return
	
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0
	
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)
	
	velocity = direction * speed

# =========================================================
# TIRER SUR LE JOUEUR
# =========================================================

func shoot_at_player():
	if not can_attack or is_dead:
		return
	
	can_attack = false
	is_attacking = true
	
	# Animation de tir
	play_gunplay()
	
	# Appliquer des dégâts au joueur (réduits à distance)
	if player and player.has_method("take_damage"):
		player.take_damage(damage * 0.5)
	
	# Cooldown entre les tirs
	if get_tree():
		await get_tree().create_timer(attack_cooldown).timeout
	
	can_attack = true
	is_attacking = false

# =========================================================
# ATTAQUER LE JOUEUR
# =========================================================

func attack_player():
	if not can_attack or is_dead:
		return
	
	can_attack = false
	is_attacking = true
	
	# Animation d'attaque
	play_gunplay()
	
	# Appliquer des dégâts au joueur (pleins dégâts au corps à corps)
	if player and player.has_method("take_damage"):
		player.take_damage(damage)
	
	# Cooldown entre les attaques
	if get_tree():
		await get_tree().create_timer(attack_cooldown).timeout
	
	can_attack = true
	is_attacking = false

# =========================================================
# ANIMATIONS
# =========================================================

func play_idle():
	if anim_player and anim_player.has_animation("enemy_animations/run"):
		if current_anim != "idle":
			anim_player.play("enemy_animations/run")
			anim_player.speed_scale = 0.1
			current_anim = "idle"
	elif anim_player and anim_player.get_animation_list().size() > 0:
		# Fallback: utiliser l'animation par défaut
		var anim_name = anim_player.get_animation_list()[0]
		if current_anim != "idle":
			anim_player.play(anim_name)
			anim_player.speed_scale = 0.1
			current_anim = "idle"

func play_run():
	if anim_player and anim_player.has_animation("enemy_animations/run"):
		if current_anim != "run":
			anim_player.play("enemy_animations/run")
			anim_player.speed_scale = 1.5
			current_anim = "run"
	else:
		# Fallback: utiliser l'animation par défaut avec vitesse augmentée
		if anim_player and anim_player.get_animation_list().size() > 0:
			var anim_name = anim_player.get_animation_list()[0]
			if current_anim != "run":
				anim_player.play(anim_name)
				anim_player.speed_scale = 2.0
				current_anim = "run"

func play_gunplay():
	if anim_player and anim_player.has_animation("enemy_animations/gunplay"):
		if current_anim != "gunplay":
			anim_player.play("enemy_animations/gunplay")
			anim_player.speed_scale = 1.0
			current_anim = "gunplay"
	else:
		# Fallback: utiliser l'animation par défaut
		if anim_player and anim_player.get_animation_list().size() > 0:
			var anim_name = anim_player.get_animation_list()[0]
			if current_anim != "gunplay":
				anim_player.play(anim_name)
				anim_player.speed_scale = 1.5
				current_anim = "gunplay"

func play_dying():
	if anim_player and anim_player.has_animation("enemy_animations/dying"):
		if current_anim != "dying":
			anim_player.play("enemy_animations/dying")
			anim_player.speed_scale = 1.0
			current_anim = "dying"
	else:
		# Fallback: utiliser l'animation par défaut
		if anim_player and anim_player.get_animation_list().size() > 0:
			var anim_name = anim_player.get_animation_list()[0]
			if current_anim != "dying":
				anim_player.play(anim_name)
				anim_player.speed_scale = 0.5
				current_anim = "dying"

# =========================================================
# DÉGÂTS
# =========================================================

func take_damage(amount):
	if is_dead:
		return
	
	health -= amount
	
	if health <= 0:
		die()

# =========================================================
# MOURIR
# =========================================================

func die():
	if is_dead:
		return
	
	is_dead = true
	
	# Animation de mort
	play_dying()
	
	if get_tree():
		await get_tree().create_timer(3.0).timeout
	queue_free()

# =========================================================
# GETTERS
# =========================================================

func get_health() -> int:
	return health
