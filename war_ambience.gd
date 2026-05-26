extends Node3D

# =========================================================
# SONS AMBIANTS DE GUERRE
# =========================================================

@onready var ambience_player = $AmbiencePlayer
@onready var explosion_player = $ExplosionPlayer
@onready var distant_gunfire_player = $DistantGunfirePlayer

# =========================================================
# VARIABLES
# =========================================================

var explosion_sounds = []
var distant_gunfire_sounds = []
var ambience_volume := 0.5
var is_playing := true

# =========================================================
# READY
# =========================================================

func _ready():
	setup_sounds()
	start_ambience_loop()

# =========================================================
# SETUP SONS
# =========================================================

func setup_sounds():
	# Charger les sons d'explosion
	# Pour l'instant, utiliser le son existant comme placeholder
	if ambience_player:
		ambience_player.volume_db = -10.0
		ambience_player.max_distance = 1000.0
	
	if explosion_player:
		explosion_player.volume_db = 0.0
		explosion_player.max_distance = 500.0
	
	if distant_gunfire_player:
		distant_gunfire_player.volume_db = -5.0
		distant_gunfire_player.max_distance = 800.0

# =========================================================
# BOUCLE D'AMBIANCE
# =========================================================

func start_ambience_loop():
	if not is_playing:
		return
	
	# Jouer des sons aléatoires pour créer une ambiance de guerre
	play_random_war_sounds()
	
	# Répéter toutes les 2-5 secondes
	var delay = randf_range(2.0, 5.0)
	await get_tree().create_timer(delay).timeout
	
	if is_playing:
		start_ambience_loop()

# =========================================================
# JOUER SONS ALÉATOIRES DE GUERRE
# =========================================================

func play_random_war_sounds():
	var rand = randf()
	
	# 30% de chance d'explosion lointaine
	if rand < 0.3:
		play_distant_explosion()
	# 50% de chance de tirs au loin
	elif rand < 0.8:
		play_distant_gunfire()
	# 20% de chance de silence (pour créer du contraste)
	else:
		pass

# =========================================================
# EXPLOSION LOINTAINE
# =========================================================

func play_distant_explosion():
	if not explosion_player or not explosion_player.stream:
		return
	
	# Jouer le son avec une variation de pitch
	explosion_player.pitch_scale = randf_range(0.8, 1.2)
	explosion_player.play()
	
	# Position aléatoire autour du joueur
	var random_offset = Vector3(randf_range(-100, 100), 0, randf_range(-100, 100))
	explosion_player.global_position = global_position + random_offset

# =========================================================
# TIRS AU LOIN
# =========================================================

func play_distant_gunfire():
	if not distant_gunfire_player or not distant_gunfire_player.stream:
		return
	
	# Jouer le son avec une variation de pitch
	distant_gunfire_player.pitch_scale = randf_range(0.9, 1.1)
	distant_gunfire_player.play()
	
	# Position aléatoire autour du joueur
	var random_offset = Vector3(randf_range(-80, 80), 0, randf_range(-80, 80))
	distant_gunfire_player.global_position = global_position + random_offset

# =========================================================
# CONTRÔLE VOLUME
# =========================================================

func set_ambience_volume(volume: float):
	ambience_volume = clamp(volume, 0.0, 1.0)
	
	if ambience_player:
		ambience_player.volume_db = linear_to_db(ambience_volume)

# =========================================================
# ACTIVER/DÉSACTIVER
# =========================================================

func enable_ambience():
	is_playing = true
	start_ambience_loop()

func disable_ambience():
	is_playing = false
	if ambience_player:
		ambience_player.stop()
	if explosion_player:
		explosion_player.stop()
	if distant_gunfire_player:
		distant_gunfire_player.stop()
