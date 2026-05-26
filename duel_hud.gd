extends Control

# =========================================================
# HUD FPS — Vie, munitions, ennemis restants
# =========================================================

@onready var player_health_label = $PlayerPanel/PlayerHealthLabel
@onready var player_health_bar = $PlayerPanel/PlayerHealthBar
@onready var player_ammo_label = $PlayerPanel/PlayerAmmoLabel

@onready var enemy_health_label = $EnemyPanel/EnemyHealthLabel
@onready var enemy_health_bar = $EnemyPanel/EnemyHealthBar
@onready var enemy_ammo_label = $EnemyPanel/EnemyAmmoLabel

var player: CharacterBody3D

func _ready():
	find_player()
	update_hud()

func _process(_delta):
	if not player or not is_instance_valid(player):
		find_player()
	update_hud()

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func update_hud():
	if player and is_instance_valid(player):
		var hp = 100
		if player.has_method("get_health"):
			hp = player.get_health()
		elif "health" in player:
			hp = player.health
		player_health_label.text = "VIE: " + str(hp)
		player_health_bar.value = hp
		
		var am = 30
		if player.has_method("get_ammo"):
			am = player.get_ammo()
		elif "ammo" in player:
			am = player.ammo
		player_ammo_label.text = "MUNITIONS: " + str(am)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var alive_count := 0
	var total_hp := 0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dead = false
		if "is_dead" in e:
			dead = e.is_dead
		if not dead:
			alive_count += 1
			if "health" in e:
				total_hp += e.health
	
	enemy_health_label.text = "ENNEMIS: " + str(alive_count)
	if alive_count > 0:
		enemy_health_bar.value = float(total_hp) / float(alive_count)
	else:
		enemy_health_bar.value = 0
	enemy_ammo_label.text = "RESTANTS: " + str(alive_count) + "/4"
