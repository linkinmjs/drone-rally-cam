# Modified from GodotDrone (GPL-3.0, (c) Cykyrios), 2026: added ground_distance.
class_name FlightState
extends RefCounted


var position := Vector3.ZERO
var orientation := Vector3.ZERO
var velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO

var basis := Basis.IDENTITY
## Distance to the ground below the drone, in meters (INF when nothing is below).
var ground_distance := INF
