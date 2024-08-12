extends Camera2D

@export var freeze_delay_msec := 5

# How quickly to move through the noise
@export var NOISE_SHAKE_SPEED: float = 30.0
@export var NOISE_SWAY_SPEED: float = 1.0
# Noise returns values in the range (-1, 1)
# So this is how much to multiply the returned value by
@export var NOISE_SHAKE_STRENGTH: float = 60.0
@export var NOISE_SWAY_STRENGTH: float = 10.0
# The starting range of possible offsets using random values
@export var RANDOM_SHAKE_STRENGTH: float = 150.0
# Multiplier for lerping the shake strength to zero
@export var SHAKE_DECAY_RATE: float = 30.0

enum ShakeType {
	Random,
	Noise,
	Sway
}

@export var noise : FastNoiseLite
# Used to keep track of where we are in the noise
# so that we can smoothly move through it
var noise_i: float = 0.0
@onready var rand = RandomNumberGenerator.new()
var shake_type: int = ShakeType.Random
var shake_strength: float = 0.0
var rng : RandomNumberGenerator

var shake_offset: Vector2

### BUILT-IN

func _ready():
	EVENTS.set_shake.connect(_on_EVENTS_set_shake)
	EVENTS.freeze_frame.connect(_on_EVENTS_freeze_frame)
	
	rng = RandomNumberGenerator.new()
	rng.randomize()
	noise.seed = rng.randi()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	match shake_type:
		ShakeType.Random:
			shake_offset = get_random_offset()
		ShakeType.Noise:
			shake_offset = get_noise_offset(delta, NOISE_SHAKE_SPEED, shake_strength)
		ShakeType.Sway:
			shake_offset = get_noise_offset(delta, NOISE_SWAY_SPEED, NOISE_SWAY_STRENGTH)
	rotation = rng.randf_range(-shake_strength, shake_strength) * 10e-5
	shake_strength = max(shake_strength - delta * SHAKE_DECAY_RATE, 0)

### LOGIC

func get_noise_offset(delta: float, speed: float, strength: float) -> Vector2:
	noise_i += delta * speed
	# Set the x values of each call to 'get_noise_2d' to a different value
	# so that our x and y vectors will be reading from unrelated areas of noise
	return Vector2(
		noise.get_noise_2d(1, noise_i) * strength,
		noise.get_noise_2d(100, noise_i) * strength
	)

func get_random_offset() -> Vector2:
	return Vector2(
		rand.randf_range(-shake_strength, shake_strength),
		rand.randf_range(-shake_strength, shake_strength)
	)

func freeze_frame() -> void:
	OS.delay_msec(freeze_delay_msec)


### SIGNAL RESPONSES ###

func _on_EVENTS_set_shake() -> void:
	shake_strength = RANDOM_SHAKE_STRENGTH
	shake_type = ShakeType.Random

func _on_EVENTS_freeze_frame() -> void:
	freeze_frame()

