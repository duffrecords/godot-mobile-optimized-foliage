@tool
class_name FoliageImpostorData
extends Resource

## Atlas texture with 4 orthographic views of the shrub arranged in a 2×2 grid.
@export var texture: Texture2D

## Width of the impostor quad in metres, computed from the shrub AABB during bake.
@export var width: float = 2.0

## Height of the impostor quad in metres, computed from the shrub AABB during bake.
@export var height: float = 2.0
