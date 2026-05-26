extends Area3D

@export var wall : StaticBody3D   # glisse ton mur ici dans l'inspecteur

var player_in_zone = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body is CharacterBody3D and not player_in_zone:
		# Désactive la collision entre le joueur et le mur
		PhysicsServer3D.body_add_collision_exception(body.get_rid(), wall.get_rid())
		player_in_zone = true
		print("Le mur est traversable !")

func _on_body_exited(body):
	if body is CharacterBody3D and player_in_zone:
		# Réactive la collision quand le joueur sort de la zone
		PhysicsServer3D.body_remove_collision_exception(body.get_rid(), wall.get_rid())
		player_in_zone = false
		print("Le mur redevient solide.")
