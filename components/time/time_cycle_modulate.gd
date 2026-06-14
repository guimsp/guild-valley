extends CanvasModulate

# Keyframes mapping decimal hour (0.0 to 24.0) to Color
var time_keyframes: Dictionary = {
	0.0: Color(0.12, 0.12, 0.3),      # Midnight
	4.0: Color(0.12, 0.12, 0.3),      # Late Night
	6.0: Color(0.85, 0.62, 0.5),      # Sunrise
	9.0: Color(1.0, 1.0, 1.0),        # Morning
	16.0: Color(1.0, 1.0, 1.0),       # Afternoon
	18.0: Color(0.88, 0.54, 0.36),     # Sunset
	20.0: Color(0.4, 0.35, 0.5),       # Dusk
	22.0: Color(0.12, 0.12, 0.3),      # Nightfall
	24.0: Color(0.12, 0.12, 0.3)       # Midnight wrapper
}

func _process(_delta: float) -> void:
	# Calculate decimal in-game hour
	var hours = GameState.time_hours
	var minutes = GameState.time_minutes
	var decimal_time = hours + (minutes / 60.0)
	
	color = _get_color_for_time(decimal_time)

func _get_color_for_time(current_time: float) -> Color:
	# Keep time clamped
	current_time = clamp(current_time, 0.0, 24.0)
	
	# Find surrounding keyframes
	var before_time: float = 0.0
	var before_color: Color = time_keyframes[0.0]
	var after_time: float = 24.0
	var after_color: Color = time_keyframes[24.0]
	
	var keys = time_keyframes.keys()
	keys.sort()
	
	for time_key in keys:
		if time_key <= current_time:
			before_time = time_key
			before_color = time_keyframes[time_key]
		if time_key >= current_time:
			after_time = time_key
			after_color = time_keyframes[time_key]
			break
			
	if is_equal_approx(before_time, after_time):
		return before_color
		
	# Interpolate between keyframes
	var weight = (current_time - before_time) / (after_time - before_time)
	return before_color.lerp(after_color, weight)
