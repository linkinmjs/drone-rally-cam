## Something the player can use by looking at it and pressing "interact". Lives on the
## "interactable" physics layer, which only the player's interaction ray scans.
class_name Interactable
extends Area3D


signal interacted(player: Node3D)

## Text shown while the player aims at it, e.g. "Guardar el dron".
@export var prompt := ""
@export var enabled := true


func can_interact(_player: Node3D) -> bool:
	return enabled


func interact(player: Node3D) -> void:
	if can_interact(player):
		interacted.emit(player)
