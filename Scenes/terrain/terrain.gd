extends RigidBody2D
class_name Terrain

@onready var collision_poly = $CollisionPolygon2D
var area :float = 0.0
var rebased : bool = false
var rebased_trsf : Transform2D
var rebased_poly : PackedVector2Array
var final_polygons : Array = []

var mutex : Mutex
var threads : Array
var threads_nb : int = 3

# Called when the node enters the scene tree for the first time.
func _ready():
	if GAME.terrain_scene == null:
		GAME.terrain_scene = ResourceLoader.load(self.scene_file_path)
	
	mutex = Mutex.new()
	for i in range(threads_nb):
		threads.append(Thread.new())

func _physics_process(_delta):
	if not rebased:
		_rebase_self()
		_ajust_visual_shape($Polygon2D.texture, $Polygon2D.texture_offset, $Polygon2D.uv)

func _rebase_self():
	rebased = true
	var centroid = _compute_centroid()
	if area < 100:
		call_deferred("queue_free")
	
	center_of_mass = centroid
	
	#position = centroid
	#var new_poly = Array(collision_poly.polygon)
	#
	#rebased_trsf = Transform2D().translated(-centroid)
	##for i in range(collision_poly.polygon.size()):
		##new_poly.append(trsf * collision_poly.polygon[i])
	#collision_poly.polygon = PackedVector2Array(new_poly.map(func(vec): return rebased_trsf * vec))


func _ajust_visual_shape(texture = null, offset = Vector2.ZERO, _uv=[]):
	$Polygon2D.polygon = collision_poly.polygon
	$LightOccluder2D.occluder.polygon = collision_poly.polygon
	$Polygon2D.texture_offset = offset
	#$Polygon2D.uv = uv
	if texture :
		$Polygon2D.texture = texture

func clip(clipping_origin : Vector2, clipping_shape : PackedVector2Array) -> void:
	rebased_poly = GAME.rebase_shape(collision_poly.polygon, global_position, global_rotation)
	rebased_poly = collision_poly.polygon
	clipping_shape = GAME.rebase_shape(clipping_shape, -global_position, -global_rotation)
	var clipped_polygons = Terrain.clipPolygons(rebased_poly, clipping_shape)
	#print("Origin Polygon : ", rebased_poly)
	#print("Clipped Polygons : ", clipped_polygons)
	
	## On parcourt tous les polygones pour créer les résidus
	for i in range (clipped_polygons.size()):
		#final_polygons += _threaded_slice(clipped_polygons[i], clipping_origin)
		var thread_idx = -1
		while thread_idx == -1:
			thread_idx = _available_thread()
		#print("start thread : ", thread_idx)
		threads[thread_idx].start(_threaded_slice.bind(clipped_polygons[i], clipping_origin))
	
	for t in threads:
		if t.is_started():
			mutex.lock()
			final_polygons += t.wait_to_finish()
			mutex.unlock()
	
	## On génère les polygones finaux
	for i in range (final_polygons.size()):
		if Terrain.compute_area(final_polygons[i])>100:
			create_new_poly(final_polygons[i], clipping_origin)
	
	queue_free()


func _available_thread()-> int:
	for i in range(threads_nb):
		if not threads[i].is_alive():
			if threads[i].is_started():
				mutex.lock()
				final_polygons += threads[i].wait_to_finish()
				mutex.unlock()
			return i
	return -1

func _threaded_slice(clipped_poly : PackedVector2Array, clipping_origin : Vector2) -> Array:
	var closest_dist = INF
	var closest_point = Vector2.ZERO
	
	var residual_radius = Vector2(50.0, 0.0)
	var cut_lines = []
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var polygons : Array = [clipped_poly]
	
	## On parcourt les nouveaux points de chaque polygone pour identifier le plus proche de l'origine
	var clipped_area = Terrain.compute_area(clipped_poly)
	if clipped_area > 1500:
		for point in clipped_poly:
			var dist = point.distance_squared_to(clipping_origin)
			if dist < closest_dist:
				if not Terrain.is_point_in_polygon(point, rebased_poly):
					closest_dist = dist
					closest_point = point
		
		#print("Clipped Polygon : ", poly)
		#print("Closest Point : ", closest_point)
		## On crée un certain nombre de points dans un rayon donné autour du point le plus proche
		## On relie les points deux à deux pour créer un ensemble de lignes
		## On clip les lignes avec le polygone traité pour créer les résidus
		cut_lines = []
		var nb_lines = 4
		if clipped_area > 2000 :
			nb_lines = 16
		for r in range(nb_lines):
			cut_lines.append([closest_point + residual_radius.rotated(rng.randf_range(0,2*PI)),
								closest_point + residual_radius.rotated(rng.randf_range(0,2*PI))])
		
		
		for line in cut_lines:
			var poly_line = Terrain.offsetPolyline(line, 0.1, true)[0]
			var new_polies : Array = []
			for poly in polygons:
				if Terrain.compute_area(poly) > 100 :
					var result : Array = Terrain.clipPolygons(poly, poly_line, true)
					new_polies += result
		
			polygons.clear()
			polygons += new_polies
	
	elif clipped_area < 100 : 
		return []
	return polygons


func create_new_poly(poly, _clipping_origin)->void:
	var new_terrain = GAME.terrain_scene.instantiate()
	get_parent().add_child(new_terrain)
	new_terrain.collision_poly.polygon = poly
	#new_terrain.collision_poly.polygon = GAME.rebase_shape(poly, -global_position, -global_rotation)
	new_terrain.global_position = global_position
	new_terrain.global_rotation = global_rotation
	var _new_offset = GAME.rebase_shape([$Polygon2D.texture_offset], -global_position, -global_rotation)
	new_terrain._rebase_self()
	new_terrain._ajust_visual_shape($Polygon2D.texture,
									$Polygon2D.texture_offset,# - new_terrain.center_of_mass + center_of_mass, 
									$Polygon2D.uv)
	
	#new_terrain.apply_impulse(sign(Terrain.compute_area(poly) - 1500)*
							  #(new_terrain.global_position - clipping_origin) * 0.4) 
							  ##,closest_point)


static func compute_area(poly: PackedVector2Array)-> float:
	var poly_area = 0.0
	for i in range(poly.size()):
		poly_area += (poly[i].x * poly[(i+1)%poly.size()].y)  - (poly[i].y * poly[(i+1)%poly.size()].x)
	return poly_area/2

func _compute_centroid()->Vector2:
	var poly = collision_poly.polygon
	area = 0.0
	var centroid = Vector2.ZERO
	var temp_value = 0.0
	
	for i in range(poly.size()):
		temp_value = (poly[i].x * poly[(i+1)%poly.size()].y)  - (poly[i].y * poly[(i+1)%poly.size()].x)
		area += temp_value
		centroid.x += (poly[i].x + poly[(i+1)%poly.size()].x) * temp_value
		centroid.y += (poly[i].y + poly[(i+1)%poly.size()].y) * temp_value
	
	area /= 2
	return centroid / (6*area)

static func clipPolygons(poly_a : PackedVector2Array, poly_b : PackedVector2Array, exclude_holes : bool = true) -> Array:
	var new_polygons : Array = Geometry2D.clip_polygons(poly_a, poly_b)
	if exclude_holes:
		return getCounterClockwisePolygons(new_polygons)
	else:
		return new_polygons

#checks all polygons in the array and only returns not clockwise (counter clockwise) polygons (filled polygons)
static func getCounterClockwisePolygons(polygons : Array) -> Array:
	var ccw_polygons : Array = []
	for poly in polygons:
		if not Geometry2D.is_polygon_clockwise(poly):
			ccw_polygons.append(poly)
	return ccw_polygons

static func offsetPolyline(line : PackedVector2Array, delta : float, exclude_holes : bool = true) -> Array:
	var new_polygons : Array = Geometry2D.offset_polyline(line, delta)
	if exclude_holes:
		return getCounterClockwisePolygons(new_polygons)
	else:
		return new_polygons

static func is_point_in_polygon(point: Vector2, polygon: PackedVector2Array, tolerance: float = 0.001) -> bool:
	for p in polygon:
		if point.distance_squared_to(p) < tolerance :
			return true
	return false
