extends CharacterBody2D
class_name Player

@export var slicer_scene = preload("res://Scenes/slicer/slicer.tscn")

const MAX_SPEED = 300.0
const ACCELERATION = 500.0
const FRICTION = 250.0
const JUMP_VELOCITY = -350.0
const UP_VELOCITY = 300.0
const DOWN_VELOCITY = 600.0
const PUSH_FORCE = 1.0
const SLASH_FORCE = -300.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var last_direction : int = 1
var jump_buffer : bool = false
var click_buffer : bool = false
var coyote_jump : bool = true

@onready var camera = $Camera2D

@onready var slicer = $Slicer
@onready var sprite = $Sprite2D

@onready var jump_timer = $JumpTimer
@onready var click_timer = $ClickTimer
@onready var coyote_timer = $CoyoteTimer
@onready var slice_cooldown = $SliceCooldown

func _ready():
	jump_timer.timeout.connect(_on_JumpTimer_timeout)
	click_timer.timeout.connect(_on_ClickTimer_timeout)
	coyote_timer.timeout.connect(_on_CoyoteTimer_timeout)
	slice_cooldown.timeout.connect(_on_SliceCooldown_timeout)


func _physics_process(delta):
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer = true
		jump_timer.start()
	if Input.is_action_just_pressed("click"):
		click_buffer = true
		click_timer.start()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis("left", "right")
	if direction:
		# We update sprite orientation
		if direction > 0 :
			sprite.flip_h = false
		else :
			sprite.flip_h = true
		
		velocity.x += direction * ACCELERATION * delta
		last_direction = int(sign(velocity.x))
		if abs(velocity.x) > MAX_SPEED:
			velocity.x = sign(velocity.x) * MAX_SPEED 
	else:
		velocity.x -= sign(velocity.x) * FRICTION * delta
		if int(sign(velocity.x)) != last_direction or int(sign(velocity.x)) == 0:
			velocity.x = 0
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
		if coyote_jump and coyote_timer.is_stopped():
			coyote_timer.start()
		var y_direction = Input.get_axis("down", "up")
		if y_direction < 0:
			velocity.y += DOWN_VELOCITY * delta 
			velocity.x -= sign(velocity.x) * FRICTION * delta * 3.0
			if int(sign(velocity.x)) != last_direction or int(sign(velocity.x)) == 0:
				velocity.x = 0
		elif y_direction > 0 and velocity.y > 0:
			velocity.y = max(velocity.y - UP_VELOCITY * delta, JUMP_VELOCITY)
	else:
		coyote_jump = true

	# Handle jump.
	if jump_buffer and coyote_jump:
		jump_buffer = false
		velocity.y = JUMP_VELOCITY
	
	# Update Slicer rotation :
	#var mouse_vec = get_viewport().get_mouse_position() - (global_position + get_viewport().get_visible_rect().size/2)
	var mouse_vec = get_global_mouse_position() - global_position
	slicer.rotation = mouse_vec.angle()
	
	if click_buffer and slice_cooldown.is_stopped():
		click_buffer = false
		slice_cooldown.start()
		slice(mouse_vec)
		
	var tween = get_tree().create_tween().bind_node(self).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(camera, "offset", (velocity * 0.75) + camera.shake_offset, 1.2)
	#camera.offset = velocity
	apply_floor_snap()
	move_and_slide()
	
	# Manage collision with RigidBodies
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			c.get_collider().apply_central_impulse(-c.get_normal() * PUSH_FORCE * 10e2 / c.get_collider().area)


### LOGIC 

func slice(mouse_vec : Vector2) -> void:
	#velocity += mouse_vec.normalized() * SLASH_FORCE
		
	var new_slicer = slicer_scene.instantiate()
	get_parent().add_child(new_slicer)
	new_slicer.global_position = global_position
	new_slicer.rotation = slicer.rotation
	new_slicer.direction = -mouse_vec
	new_slicer.slice()

func receive_hit(hit_direction:Vector2, hit_intensity:float)->void:
	$AnimationPlayer.play("damage")
	velocity += hit_direction * hit_intensity

### SIGNAL RESPONSES

func _on_JumpTimer_timeout()->void:
	jump_buffer = false

func _on_ClickTimer_timeout() -> void:
	click_buffer = false

func _on_CoyoteTimer_timeout()->void:
	coyote_jump = false
	coyote_timer.stop()

func _on_SliceCooldown_timeout() -> void:
	slice_cooldown.stop()
