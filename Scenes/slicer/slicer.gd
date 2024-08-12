extends Area2D

const HIT_INTENSITY = 1.0

@export var slice_sounds : Array[Resource]
@export var hit_sounds : Array[Resource]

@onready var shape_cast = $ShapeCast2D
@onready var collision_shape = $CollisionPolygon2D
@onready var polygon_visu = $Polygon2D

var direction = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready():
	shape_cast.shape.points = collision_shape.polygon
	polygon_visu.polygon = collision_shape.polygon
	polygon_visu.color.a = 0
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	$AudioStreamPlayer2D.stream = slice_sounds.pick_random()
	$AudioStreamPlayer2D.pitch_scale = rng.randf_range(1.2, 1.4)
	$AudioStreamPlayer2D2.stream = hit_sounds.pick_random()
	$AudioStreamPlayer2D2.volume_db = rng.randf_range(0.90, 1.0)
	$AudioStreamPlayer2D2.pitch_scale = rng.randf_range(6.0, 9.0)
	$AudioStreamPlayer2D3.stream = hit_sounds.pick_random()
	$AudioStreamPlayer2D3.pitch_scale = rng.randf_range(0.15, 0.35)

func slice()-> void:
	$AnimationPlayer.play("slice")

func _slice() -> void:
	#shape_cast.force_shapecast_update()
	var i = shape_cast.get_collision_count()
	while i > 0:
		var collider = shape_cast.get_collider(i-1)
		if collider is Terrain:
			collider.call_deferred("clip",global_position, GAME.rebase_shape(collision_shape.polygon, 
												global_position, 
												global_rotation))
			#collider.clip(global_position, GAME.rebase_shape(collision_shape.polygon, 
												#global_position, 
												#global_rotation))
		if collider is Player:
			collider.receive_hit(direction, HIT_INTENSITY)
		
		i -= 1

func _shake_screen():
	EVENTS.emit_signal("set_shake")
