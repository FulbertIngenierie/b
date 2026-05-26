extends Control

# =========================================================
# NODES
# =========================================================

@onready var player_health_label = $PlayerPanel/PlayerHealthLabel
@onready var player_health_bar = $PlayerPanel/PlayerHealthBar
@onready var player_ammo_label = $PlayerPanel/PlayerAmmoLabel

@onready var enemy_health_label = $EnemyPanel/EnemyHealthLabel
@onready var enemy_health_bar = $EnemyPanel/EnemyHealthBar
@onready var enemy_ammo_label = $EnemyPanel/EnemyAmmoLabel

# =========================================================
# VARIABLES
# =========================================================

var player: CharacterBody3D
var enemy: CharacterBody3D

# =========================================================
# READY
# =========================================================

func _ready():
	find_player_and_enemy()
	update_hud()

# =========================================================
# PROCESS
# =========================================================

func _process(_delta):
	if not player or not enemy:
		find_player_and_enemy()
	
	update_hud()

# =========================================================
# TROUVER JOUEUR ET ENNEMI
# =========================================================

func find_player_and_enemy():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	
	var enemies = get_tree().get_nodes_in_group("enemy_target")
	if enemies.size() > 0:
		enemy = enemies[0]

# =========================================================
# UPDATE HUD
# =========================================================

func update_hud():
	# Mise à jour joueur
	if player:
		if player.has_method("get_health"):
			var player_health = player.get_health()
			player_health_label.text = "VIE: " + str(player_health)
			player_health_bar.value = player_health
		
		if player.has_method("get_ammo"):
			var player_ammo = player.get_ammo()
			player_ammo_label.text = "MUNITIONS: " + str(player_ammo)
		else:
			# Si le joueur n'a pas de système de munitions, afficher infini
			player_ammo_label.text = "MUNITIONS: ∞"
	
	# Mise à jour ennemi
	if enemy:
		if enemy.has_method("get_health"):
			var enemy_health = enemy.get_health()
			enemy_health_label.text = "VIE: " + str(enemy_health)
			enemy_health_bar.value = enemy_health
		else:
			# Accès direct à la variable health
			if "health" in enemy:
				enemy_health_label.text = "VIE: " + str(enemy.health)
				enemy_health_bar.value = enemy.health
		
		if enemy.has_method("get_ammo"):
			var enemy_ammo = enemy.get_ammo()
			enemy_ammo_label.text = "MUNITIONS: " + str(enemy_ammo)
		else:
			# Accès direct à la variable ammo
			if "ammo" in enemy:
				enemy_ammo_label.text = "MUNITIONS: " + str(enemy.ammo)
