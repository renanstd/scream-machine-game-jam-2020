extends KinematicBody2D

class_name BasicMovement2D

const UP : Vector2 = Vector2(0, -1)

export (int, 0, 100) var GRAVITY  = 20
export (float, 0, 1000) var JUMP_FORCE = 500
export (float, 0, 500) var WALK_SPEED : int = 200
export (float, 0, 30) var ACCELERATION = 10
export (float, 0, 1) var DEACELERATION = 0.1
export (float, 0, 1) var AIR_DEACELERATION = 0.02
export (float, 0, 500) var SPRINT_SPEED : int = 200
export (float, 0, 500) var MAX_THRUST = 300
export (float, 0, 50) var THRUST_POWER = 30
export (bool) var CAN_WALK = true
export (bool) var CAN_SPRINT = true
export (bool) var CAN_JUMP = true
export (bool) var CAN_FLY = false
export (PackedScene) var monster_scene

onready var animation_player = $AnimationPlayer
onready var sprite = $Sprite
onready var footstep_sound = $StepSound
onready var timer_step = $TimeEachStep
onready var dialog = $CanvasLayer/DialogBox
onready var blink = $CanvasLayer/Blink
onready var interactive_area = $InteractiveArea
onready var alert_sprite = $AlertSprite
onready var monster_spawn_01_left = $Level1_MonsterSpawnLeft
onready var monster_spawn_01_right = $Level1_MonsterSpawnRight
onready var monster_spawn_02_left = $Level2_MonsterSpawnLeft
onready var monster_spawn_02_right = $Level2_MonsterSpawnRight
onready var dust_particles = $CPUParticles2D

var motion : Vector2 = Vector2()
var max_speed : float = WALK_SPEED
var looking_to_right : bool = true
var can_play_footstep : bool = true
var can_control : bool = true
var elevator_names = ["Elevador", "Elevador2"]
var monster_spawn_01 : Array
var monster_spawn_02 : Array

signal is_walking
signal is_idle
signal is_jumping
signal is_falling
signal is_sprinting
signal is_on_ground
signal is_thrusting
signal player_flipped(to_right)
signal hide_hud
signal show_hud

# ========================================================================
func _ready():
#	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	monster_spawn_01 = [monster_spawn_01_left, monster_spawn_01_right]
	monster_spawn_02 = [monster_spawn_02_left, monster_spawn_02_right]
	var key = ["intro001", "intro002", "intro003", "intro004", "intro005"]
	call_dialog_box(key)

func _process(delta):
	# Interação com itens
	if Input.is_action_just_pressed("interact"):
		var itens = interactive_area.get_overlapping_areas()
		for item in itens:
			# Verifica se é um item que dispara diálogo
			if item.has_method("dialog"):
				var key = item.dialog()
				call_dialog_box(key)
			# Verifica se é uma alavanca
			if item.has_method("open_door"):
				item.open_door()
				get_tree().call_group("door", "open_door", item.door_to_open)
				get_tree().call_group("generators", "turn_on", item.generator_to_activate)

	# Aperta botão UP no elevador
	if Input.is_action_just_pressed("up") and is_on_floor():
		var itens = interactive_area.get_overlapping_areas()
		for item in itens:
			if item.get_parent().name in elevator_names and not item.get_parent().working:
				var actual_floor = item.get_parent().actual_floor
				item.get_parent().change_floor(actual_floor + 1)

	# Aperta botão DOWN no elevador
	if Input.is_action_just_pressed("down") and is_on_floor():
		var itens = interactive_area.get_overlapping_areas()
		for item in itens:
			if item.get_parent().name in elevator_names and not item.get_parent().working:
				var actual_floor = item.get_parent().actual_floor
				item.get_parent().change_floor(actual_floor - 1)

func _physics_process(delta):
	if can_control:
		motion.y += GRAVITY
		motion = transform_inputs_in_motion()
		motion = move_and_slide(motion, UP)
		emit_signals(motion)
		animate()
		emit_sound()
	else:
		motion = move_and_slide(motion, UP)

func transform_inputs_in_motion() -> Vector2:
	var friction : bool = false

	# Sprint (increase max speed)
	if CAN_SPRINT and Input.is_action_pressed("sprint"):
		max_speed = WALK_SPEED + SPRINT_SPEED
	elif max_speed > WALK_SPEED and is_on_floor():
		# Gradually reduce max_speed to walk_speed
		max_speed = lerp(max_speed, 0, DEACELERATION)
		max_speed = max(max_speed, WALK_SPEED)
		pass

	# Accelerate / Deacelerate
	if CAN_WALK:
		if Input.is_action_pressed("right"):
			motion.x = min(motion.x + ACCELERATION, max_speed)
		elif Input.is_action_pressed("left"):
			motion.x = max(motion.x - ACCELERATION, -max_speed)
		else:
			friction = true

	if is_on_floor():
		# Jump
		if CAN_JUMP and Input.is_action_just_pressed("jump"):
			motion.y = -JUMP_FORCE
		# Deaceleration
		if friction:
			motion.x = lerp(motion.x, 0, DEACELERATION)
	else:
		# In air deaceleration
		motion.x = lerp(motion.x, 0, AIR_DEACELERATION)

	if CAN_FLY and Input.is_action_pressed("jump"):
		motion.y -= THRUST_POWER
		motion.y = clamp(motion.y, -MAX_THRUST, 1000)

	return motion

func emit_signals(motion : Vector2):
	if is_on_floor() and motion.x != 0:
		emit_signal("is_on_ground")
		if abs(motion.x) != 0 and abs(motion.x) <= WALK_SPEED:
			emit_signal("is_walking")
		else:
			emit_signal("is_sprinting")

	if motion.x == 0:
		emit_signal("is_idle")

	if motion.x < 0 and looking_to_right:
		sprite.flip_h = true
		emit_signal("player_flipped", looking_to_right)
		looking_to_right = false
	if motion.x > 0 and not looking_to_right:
		emit_signal("player_flipped", looking_to_right)
		looking_to_right = true
		sprite.flip_h = false

	if motion.y < 0:
		if CAN_FLY:
			emit_signal("is_thrusting")
		else:
			emit_signal("is_jumping")
	elif motion.y > 0:
		emit_signal("is_falling")

func animate():
	if is_on_floor():
		if abs(motion.x) > 1.0:
			animation_player.play("walking")
			dust_particles.emitting = true
		else:
			animation_player.play("idle")
			dust_particles.emitting = false
	else:
		dust_particles.emitting = false

func emit_sound():
	if is_on_floor():
		if abs(motion.x) > 1.0 and can_play_footstep:
			can_play_footstep = false
			footstep_sound.play()
			timer_step.start()

func _on_TimeEachStep_timeout():
	can_play_footstep = true

func call_dialog_box(ids : Array):
	"""
	Recebe a chave do json cujo texto é pra ser exibido,
	paralisa o mundo, e abre o dialogbox na tela.
	"""
	# Pausar o timer
	blink.pause_timer()
	# Retirar o controle do jogador
	can_control = false
	emit_signal("hide_hud")
	dialog.prepare_dialog(ids)
	dialog.show()
	dialog.load_dialog()
	# Executa o diálogo, até o signal "complete" ser enviado
	yield(dialog, "complete")
	# Retorna o controle e o timer de blink
	can_control = true
	blink.unpause_timer()
	dialog.hide()
	emit_signal("show_hud")


func _on_InteractiveArea_area_entered(area):
	"""
	Exibe icone de alerta quando o player caminha numa área interativa
	"""
	if area.is_in_group("interactive"):
		alert_sprite.show()

func _on_InteractiveArea_area_exited(area):
	"""
	Oculta ícone de alerta quando o player sai de uma área interativa
	"""
	if area.is_in_group("interactive"):
		alert_sprite.hide()

func _on_Blink_spawn_monster():
	"""
	Spawna o monstro, fora do limite da câmera, e faz ele desaparecer
	segundos após o player ver ele
	"""
	var monster_instance = monster_scene.instance()
	# Sortear se o monstro parecerá na direita ou na esquerda
	var spawn_index = randi() % monster_spawn_01.size()
	var spawn_position = monster_spawn_01[spawn_index].global_position
	# Ajustar a posição dele pra mesma posição dos marcadores
	monster_instance.global_position = spawn_position
	# Ajustar o flip_H
	if monster_instance.global_position.x > global_position.x:
		monster_instance.scale.x = -1
	# Adicionar a cena
#	monster_instance.set_time_visible(2)
	get_parent().add_child(monster_instance)

func _on_Blink_spawn_monster_running():
	pass # Replace with function body.

func _on_Blink_spawn_monster_walking():
	var monster_instance = monster_scene.instance()
	# Sortear se o monstro parecerá na direita ou na esquerda
	var spawn_index = randi() % monster_spawn_01.size()
	var spawn_position = monster_spawn_02[spawn_index].global_position
	# Ajustar a posição dele pra mesma posição dos marcadores
	monster_instance.global_position = spawn_position
	# Ajustar o flip_H
	if monster_instance.global_position.x > global_position.x:
		monster_instance.scale.x = -1
	# Adicionar a cena
#	monster_instance.set_time_visible(2)
	get_parent().add_child(monster_instance)
