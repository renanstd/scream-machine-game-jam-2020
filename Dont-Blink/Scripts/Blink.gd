extends TextureRect

onready var anim_player = $AnimationPlayer
onready var blink_sound = $AudioStreamPlayer
onready var timer = $TimerBlink
onready var timer_scare = $TimerScareImg
onready var scare_sprite = $ScareSprite

enum EVENT {
	no_event,
	scare_image,
	scare_glitches
}

var event = EVENT.no_event

signal time_left(time_left)
signal max_value(value)

func _ready():
	yield(get_tree(), "idle_frame")
	timer.start()
	emit_signal("max_value", timer.wait_time)

func _process(delta):
	emit_signal("time_left", timer.time_left)
	if Input.is_action_just_pressed("blink") and not anim_player.is_playing():
		blink()

func blink():
	play_events()
	blink_sound.play()
	anim_player.play("Blink")
	timer.start()

func pause_timer():
	timer.paused = true
	
func unpause_timer():
	timer.paused = false

func _on_TimerScareImg_timeout():
	scare_sprite.hide()

func play_events():
	if event == EVENT.scare_image:
		scare_sprite.show()
		timer_scare.start()
