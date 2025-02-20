//File with the circuitboard and circuitboard/machine class definitions and procs


// Circuitboard

/obj/item/circuitboard
	name = "circuit board"
	icon = 'icons/obj/module.dmi'
	icon_state = "circuit_map"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/misc/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/devices_righthand.dmi'
	custom_materials = list(/datum/material/glass=1000)
	w_class = WEIGHT_CLASS_SMALL
	grind_results = list(/datum/reagent/silicon = 20)
	greyscale_colors = CIRCUIT_COLOR_GENERIC
	access_category_define = ACCESS_CATEGORY_LAST_LOADED
	var/build_path = null
	///determines if the circuit board originated from a vendor off station or not.
	var/onstation = TRUE

/obj/item/circuitboard/Initialize()
	set_greyscale(new_config=/datum/greyscale_config/circuit)
	. = ..()
	gen_access()

/obj/item/circuitboard/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("Current access category set: [access_category.name]")
	. += SPAN_NOTICE("You can change the access category with right click")

/obj/item/circuitboard/RightClick(mob/user, modifiers)
	if(!user.canUseTopic(src, BE_CLOSE))
		return FALSE
	var/list/select_list = list()
	var/i = 0
	for(var/datum/access_category/category as anything in SSid_access.access_categories)
		i++
		select_list[category.name] = i
	var/selected_name = input(user, "Select access category", "Acccess", select_list[1]) as null|anything in select_list
	if(!selected_name)
		return TRUE
	if(!user.canUseTopic(src, BE_CLOSE))
		return TRUE
	access_category = SSid_access.access_categories[select_list[selected_name]]
	return TRUE

/obj/item/circuitboard/proc/apply_default_parts(obj/machinery/M)
	if(LAZYLEN(M.component_parts))
		// This really shouldn't happen. If it somehow does, print out a stack trace and gracefully handle it.
		stack_trace("apply_defauly_parts called on machine that already had component_parts: [M]")

		// Move to nullspace so you don't trigger handle_atom_del logic and remove existing parts.
		for(var/obj/item/part in M.component_parts)
			part.moveToNullspace(loc)
			qdel(part)

	// List of components always contains the circuit board used to build it.
	M.component_parts = list(src)
	forceMove(M)

	if(M.circuit != src)
		// This really shouldn't happen. If it somehow does, print out a stack trace and gracefully handle it.
		stack_trace("apply_default_parts called from a circuit board that does not belong to machine: [M]")

		// Move to nullspace so you don't trigger handle_atom_del logic, remove old circuit, add new circuit.
		M.circuit.moveToNullspace()
		qdel(M.circuit)
		M.circuit = src

	return

/**
 * Used to allow the circuitboard to configure a machine in some way, shape or form.
 *
 * Arguments:
 * * machine - The machine to attempt to configure.
 */
/obj/item/circuitboard/proc/configure_machine(obj/machinery/machine)
	return

// Circuitboard/machine
/*Common Parts: Parts List: Ignitor, Timer, Infra-red laser, Infra-red sensor, t_scanner, Capacitor, Valve, sensor unit,
micro-manipulator, console screen, beaker, Microlaser, matter bin, power cells.
*/

/obj/item/circuitboard/machine
	var/needs_anchored = TRUE // Whether this machine must be anchored to be constructed.
	var/list/req_components // Components required by the machine.
							// Example: list(/obj/item/stock_parts/matter_bin = 5)

	var/list/def_components // Default replacements for req_components, to be used in apply_default_parts instead of req_components types
							// Example: list(/obj/item/stock_parts/matter_bin = /obj/item/stock_parts/matter_bin/super)

// Applies the default parts defined by the circuit board when the machine is created
/obj/item/circuitboard/machine/apply_default_parts(obj/machinery/M)
	if(!req_components)
		return

	. = ..()

	for(var/comp_path in req_components)
		var/comp_amt = req_components[comp_path]
		if(!comp_amt)
			continue

		if(def_components && def_components[comp_path])
			comp_path = def_components[comp_path]

		if(ispath(comp_path, /obj/item/stack))
			M.component_parts += new comp_path(M, comp_amt)
		else
			for(var/i in 1 to comp_amt)
				M.component_parts += new comp_path(M)

	M.RefreshParts()

/obj/item/circuitboard/machine/examine(mob/user)
	. = ..()
	if(LAZYLEN(req_components))
		var/list/nice_list = list()
		for(var/B in req_components)
			var/atom/A = B
			if(!ispath(A))
				continue
			nice_list += list("[req_components[A]] [initial(A.name)]")
		. += SPAN_NOTICE("Required components: [english_list(nice_list)].")
