/datum/computer_file/program/supermatter_monitor
	filename = "smmonitor"
	filedesc = "Supermatter Monitoring"
	ui_header = "smmon_0.gif"
	program_icon_state = "smmon_0"
	extended_desc = "This program connects to specially calibrated supermatter sensors to provide information on the status of supermatter-based engines."
	requires_ntnet = TRUE
	transfer_access = ACCESS_CONSTRUCTION
	network_destination = "supermatter monitoring system"
	size = 5
	tgui_id = "NtosSupermatterMonitor"


	var/last_status = SUPERMATTER_INACTIVE
	var/list/supermatters
	var/obj/machinery/power/supermatter_crystal/active		// Currently selected supermatter crystal.


/datum/computer_file/program/supermatter_monitor/process_tick()
	..()
	var/new_status = get_status()
	if(last_status != new_status)
		last_status = new_status
		ui_header = "smmon_[last_status].gif"
		program_icon_state = "smmon_[last_status]"
		if(istype(computer))
			computer.update_icon()

/datum/computer_file/program/supermatter_monitor/run_program(mob/living/user)
	. = ..(user)
	refresh()

/datum/computer_file/program/supermatter_monitor/kill_program(forced = FALSE)
	for(var/supermatter in supermatters)
		clear_supermatter(supermatter)
	supermatters = null
	..()

// Refreshes list of active supermatter crystals
/datum/computer_file/program/supermatter_monitor/proc/refresh()
	for(var/supermatter in supermatters)
		clear_supermatter(supermatter)
	supermatters = list()
	var/turf/T = get_turf(ui_host())
	if(!T)
		return
	for(var/obj/machinery/power/supermatter_crystal/S in GLOB.machines)
		// Delaminating, not within coverage, not on a tile.
		if (!isturf(S.loc) || !(is_station_level(S.z) || is_mining_level(S.z) || S.get_virtual_z_level() == T.get_virtual_z_level()))
			continue
		supermatters.Add(S)
		RegisterSignal(S, COMSIG_PARENT_QDELETING, .proc/react_to_del)

/datum/computer_file/program/supermatter_monitor/proc/get_status()
	. = SUPERMATTER_INACTIVE
	for(var/obj/machinery/power/supermatter_crystal/S in supermatters)
		. = max(., S.get_status())

/datum/computer_file/program/supermatter_monitor/ui_data()
	var/list/data = get_header_data()

	if(istype(active))
		var/turf/T = get_turf(active)
		if(!T)
			active = null
			refresh()
			return
		var/datum/gas_mixture/air = T.return_air()
		if(!air)
			active = null
			return

		data["active"] = TRUE
		data["SM_integrity"] = active.get_integrity()
		data["SM_power"] = active.power
		data["SM_radiation"] = active.last_rads
		data["SM_ambienttemp"] = air.return_temperature()
		data["SM_ambientpressure"] = air.return_pressure()
		//data["SM_EPR"] = round((air.total_moles / air.group_multiplier) / 23.1, 0.01)
		var/list/gasdata = list()


		if(air.total_moles())
			for(var/gasid in air.get_gases())
				gasdata.Add(list(list(
				"name"= GLOB.gas_data.names[gasid],
				"amount" = round(100*air.get_moles(gasid)/air.total_moles(),0.01))))

		else
			for(var/gasid in air.get_gases())
				gasdata.Add(list(list(
					"name"= GLOB.gas_data.names[gasid],
					"amount" = 0)))

		data["gases"] = gasdata
	else
		var/list/SMS = list()
		for(var/obj/machinery/power/supermatter_crystal/S in supermatters)
			var/area/A = get_area(S)
			if(A)
				SMS.Add(list(list(
				"area_name" = A.name,
				"integrity" = S.get_integrity(),
				"uid" = S.uid
				)))

		data["active"] = FALSE
		data["supermatters"] = SMS

	return data

/datum/computer_file/program/supermatter_monitor/ui_act(action, params)
	if(..())
		return TRUE

	switch(action)
		if("PRG_clear")
			active = null
			return TRUE
		if("PRG_refresh")
			refresh()
			return TRUE
		if("PRG_set")
			var/newuid = text2num(params["target"])
			for(var/obj/machinery/power/supermatter_crystal/S in supermatters)
				if(S.uid == newuid)
					active = S
			return TRUE

/datum/computer_file/program/supermatter_monitor/proc/react_to_del(datum/source)
	SIGNAL_HANDLER
	clear_supermatter(source)

/datum/computer_file/program/supermatter_monitor/proc/clear_supermatter(matter)
	supermatters -= matter
	if(matter == active)
		active = null
	UnregisterSignal(matter, COMSIG_PARENT_QDELETING)
