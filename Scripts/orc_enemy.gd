extends CharacterBody2D

@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var player_detector1: RayCast2D = $player_detector
@onready var player_detector2: RayCast2D = $player_detector2
@onready var attack_detector: RayCast2D = $attack_player_detector
@onready var enemy_attack_box = $enemy_attack_box
@onready var health_bar: ProgressBar = $HealthBar  # Adjust the node path if necessary

@onready var state_timer = $StateTimer

@export var wander_speed: int = 50
@export var chase_speed: int = 150
@export var attack_range: float = 30.0  

const JUMP_POWER = -400
const GRAVITY = 50

enum States { WANDER, CHASE, ATTACKING }
var current_state = States.WANDER
var direction: int = 1  # 1 = Right, -1 = Left
var player = null  
var attacking = false  
var last_position: Vector2
var stuck_time: float = 0.0
var hp = 4
var dead = false

func _ready():
	health_bar.max_value = hp
	health_bar.value = hp


func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	state_machine(delta)
	move_and_slide()
	check_if_stuck(delta)

func state_machine(delta: float):
	match current_state:
		States.WANDER:
			handle_wander(delta)
		States.CHASE:
			handle_chase(delta)
		States.ATTACKING:
			handle_attack()

func handle_wander(delta: float):
	move(direction, wander_speed)  

	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_POWER  # Jump when stuck

	# Get colliders safely
	var collider1 = player_detector1.get_collider()
	var collider2 = player_detector2.get_collider()

	# Ensure collider exists before checking group
	if collider1 and collider1.is_in_group("player"):
		print("DETECTING PLAYER")
		player = collider1
		current_state = States.CHASE
	elif collider2 and collider2.is_in_group("player"):
		print("DETECTING PLAYER")
		player = collider2
		current_state = States.CHASE

	if is_on_wall():
		turn_around()

func handle_chase(delta: float):
	if not player:
		current_state = States.WANDER
		return  

	var distance_to_player = global_position.distance_to(player.global_position)
	
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_POWER  # Jump when stuck
		
	if is_on_wall():
		turn_around()
	
	if distance_to_player > attack_range:
		move(sign(player.global_position.x - global_position.x), chase_speed)
	else:
		current_state = States.ATTACKING
		

func handle_attack():
	velocity.x = 0  

	if not attacking:
		attacking = true
		animation_player.play("attack")

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack":
		attacking = false
		if player:
			current_state = States.CHASE
		else:
			current_state = States.WANDER

func move(dir, speed):
	velocity.x = dir * speed
	update_flip(dir)
	handle_animation()

func update_flip(dir):
	sprite.flip_h = dir < 0
	
	# Flip attack hitbox
	enemy_attack_box.scale.x = abs(enemy_attack_box.scale.x) * dir

func handle_animation():
	if is_on_floor():
		if velocity.x != 0:
			animation_player.play("walk")
		else:
			animation_player.play("idle")

func handle_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY

func turn_around():
	direction *= -1
	sprite.flip_h = not sprite.flip_h

	update_flip(direction)  # Ensure attack hitbox flips properly

func _on_enemy_attack_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") and not attacking and is_on_floor():    
		attacking = true  
		velocity = Vector2.ZERO  
		animation_player.play("attack")  

func check_if_stuck(delta: float):
	if current_state != States.ATTACKING:
		# If the position hasn't changed, increase the stuck time
		if global_position == last_position:
			stuck_time += delta
		else:
			stuck_time = 0  # Reset timer if the enemy moves
		
		# Update last known position
		last_position = global_position
		
		# If stuck for 3 seconds, remove enemy
		if stuck_time >= 3.0:
			print("Enemy is stuck! Removing...")
			queue_free()


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("sword"):
		print("ENEMY HIT!")
		hp -= 1
		health_bar.value = hp

		if hp <= 0 and not dead:
			dead = true
			attacking = false  
			animation_player.play("death")
			velocity = Vector2.ZERO  

			# Wait for the death animation to finish, then remove the enemy
			await animation_player.animation_finished
			queue_free()  # Remove enemy from the scene
