extends Node

# Alerts System
signal alert_added(alert_data: Dictionary)
signal alert_removed(alert_id: String)

var active_alerts: Array = []
var past_alerts: Array = []
var last_alert_times: Dictionary = {}

func add_alert(title: String, description: String, alert_type: String, building_ref: Node2D = null) -> void:
	# Cooldown check: prevent alerts of same title/building within 3 minutes (180,000 msec)
	var cooldown_key = title + "_" + (str(building_ref.get_path()) if is_instance_valid(building_ref) else "")
	var now = Time.get_ticks_msec()
	if last_alert_times.has(cooldown_key):
		if now - last_alert_times[cooldown_key] < 180000:
			return
	last_alert_times[cooldown_key] = now

	# Avoid duplicate active alerts for the same building and title
	for active in active_alerts:
		if active.title == title and active.description == description:
			return
			
	var time_str = ""
	if has_node("/root/TimeManager"):
		var tm = get_node("/root/TimeManager")
		time_str = "Day %d - %02d:%02d" % [tm.time_days, tm.time_hours, int(tm.time_minutes)]
	else:
		# Find TimeCycleModulate node in the scene tree
		var time_cycle = get_tree().get_first_node_in_group("TimeCycle")
		if not time_cycle:
			# Check by class/type or name
			for node in get_tree().get_nodes_in_group("TimeCycleModulate"):
				time_cycle = node
				break
		if not time_cycle:
			time_cycle = get_tree().current_scene.find_child("TimeCycleModulate", true, false)
			
		if time_cycle and "current_day" in time_cycle:
			time_str = "Day %d - %02d:%02d" % [time_cycle.current_day, time_cycle.current_hour, time_cycle.current_minute]
		else:
			var dt = Time.get_time_dict_from_system()
			time_str = "%02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]
		
	var alert_id = "alert_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var alert_data = {
		"id": alert_id,
		"title": title,
		"description": description,
		"type": alert_type, # "warning", "info", "danger"
		"time": time_str,
		"building": building_ref
	}
	
	active_alerts.append(alert_data)
	past_alerts.insert(0, alert_data)
	
	alert_added.emit(alert_data)

func remove_alert(alert_id: String) -> void:
	for i in range(active_alerts.size()):
		if active_alerts[i].id == alert_id:
			active_alerts.remove_at(i)
			alert_removed.emit(alert_id)
			break
