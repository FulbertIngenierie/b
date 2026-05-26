extends Area3D

@export var target_marker : Marker3D

func _ready():
	# On connecte le signal body_entered à une fonction du même script
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Quelque chose a touché l'Area : ", body.name)
	if body is CharacterBody3D:
		if target_marker:
			body.global_position = target_marker.global_position
			print("Téléportation réussie !")
		else:
			print("target_marker n'est pas assigné (glisse ton Marker3D dans l'inspecteur)")
