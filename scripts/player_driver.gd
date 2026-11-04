extends RefCounted
## Spelarens förare: läser tangentbord och handkontroll.


func drive(car, _delta: float) -> void:
	car.throttle = Input.get_action_strength("gas") - Input.get_action_strength("brake")
	car.steer_in = Input.get_axis("left", "right")
	car.handbrake = Input.is_action_pressed("handbrake")
	car.boost_in = Input.is_action_pressed("boost")
