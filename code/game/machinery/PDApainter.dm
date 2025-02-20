/// Basic machine used to paint PDAs and re-trim ID cards.
/obj/machinery/pdapainter
	name = "\improper PDA & ID Painter"
	desc = "A painting machine that can be used to paint PDAs and trim IDs. To use, simply insert the item and choose the desired preset."
	icon = 'icons/obj/pda.dmi'
	icon_state = "pdapainter"
	base_icon_state = "pdapainter"
	density = TRUE
	max_integrity = 200
	/// Current ID card inserted into the machine.
	var/obj/item/card/id/stored_id_card = null
	/// Current PDA inserted into the machine.
	var/obj/item/pda/stored_pda = null
	/// A blacklist of PDA types that we should not be able to paint.
	var/static/list/pda_type_blacklist = list(
		/obj/item/pda/ai/pai,
		/obj/item/pda/ai,
		/obj/item/pda/heads,
		/obj/item/pda/clear,
		/obj/item/pda/syndicate,
		/obj/item/pda/chameleon,
		/obj/item/pda/chameleon/broken)
	/// Set to a region define (REGION_SECURITY for example) to create a departmental variant, limited to departmental options. If null, this is unrestricted.
	var/target_dept

/obj/machinery/pdapainter/update_icon_state()
	if(machine_stat & BROKEN)
		icon_state = "[base_icon_state]-broken"
		return ..()
	icon_state = "[base_icon_state][powered() ? null : "-off"]"
	return ..()

/obj/machinery/pdapainter/update_overlays()
	. = ..()

	if(machine_stat & BROKEN)
		return

	if(stored_pda || stored_id_card)
		. += "[initial(icon_state)]-closed"

/obj/machinery/pdapainter/Initialize()
	. = ..()

/obj/machinery/pdapainter/Destroy()
	QDEL_NULL(stored_pda)
	QDEL_NULL(stored_id_card)
	return ..()

/obj/machinery/pdapainter/on_deconstruction()
	// Don't use ejection procs as we're gonna be destroyed anyway, so no need to update icons or anything.
	if(stored_pda)
		stored_pda.forceMove(loc)
		stored_pda = null
	if(stored_id_card)
		stored_id_card.forceMove(loc)
		stored_id_card = null

/obj/machinery/pdapainter/contents_explosion(severity, target)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			if(stored_pda)
				SSexplosions.high_mov_atom += stored_pda
			if(stored_id_card)
				SSexplosions.high_mov_atom += stored_id_card
		if(EXPLODE_HEAVY)
			if(stored_pda)
				SSexplosions.med_mov_atom += stored_pda
			if(stored_id_card)
				SSexplosions.med_mov_atom += stored_id_card
		if(EXPLODE_LIGHT)
			if(stored_pda)
				SSexplosions.low_mov_atom += stored_pda
			if(stored_id_card)
				SSexplosions.low_mov_atom += stored_id_card

/obj/machinery/pdapainter/handle_atom_del(atom/A)
	if(A == stored_pda)
		stored_pda = null
		update_appearance(UPDATE_ICON)
	if(A == stored_id_card)
		stored_id_card = null
		update_appearance(UPDATE_ICON)

/obj/machinery/pdapainter/attackby(obj/item/O, mob/living/user, params)
	if(machine_stat & BROKEN)
		if(O.tool_behaviour == TOOL_WELDER && !user.combat_mode)
			if(!O.tool_start_check(user, amount=0))
				return
			user.visible_message(SPAN_NOTICE("[user] is repairing [src]."), \
							SPAN_NOTICE("You begin repairing [src]..."), \
							SPAN_HEAR("You hear welding."))
			if(O.use_tool(src, user, 40, volume=50))
				if(!(machine_stat & BROKEN))
					return
				to_chat(user, SPAN_NOTICE("You repair [src]."))
				set_machine_stat(machine_stat & ~BROKEN)
				obj_integrity = max_integrity
				update_appearance(UPDATE_ICON)
			return
		return ..()

	if(default_unfasten_wrench(user, O))
		power_change()
		return

	// Chameleon checks first so they can exit the logic early if they're detected.
	if(istype(O, /obj/item/card/id/advanced/chameleon))
		to_chat(user, SPAN_WARNING("The machine rejects your [O]. This ID card does not appear to be compatible with the PDA Painter."))
		return

	if(istype(O, /obj/item/pda/chameleon))
		to_chat(user, SPAN_WARNING("The machine rejects your [O]. This PDA does not appear to be compatible with the PDA Painter."))
		return

	if(istype(O, /obj/item/pda))
		insert_pda(O, user)
		return

	if(istype(O, /obj/item/card/id))
		if(stored_id_card)
			to_chat(user, SPAN_WARNING("There is already an ID card inside!"))
			return

		if(!user.transferItemToLoc(O, src))
			return

		stored_id_card = O
		O.add_fingerprint(user)
		update_appearance(UPDATE_ICON)
		return

	return ..()

/obj/machinery/pdapainter/deconstruct(disassembled = TRUE)
	obj_break()

/**
 * Insert a PDA into the machine.
 *
 * Will swap PDAs if one is already inside. Attempts to put the PDA into the user's hands if possible.
 * Returns TRUE on success, FALSE otherwise.
 * Arguments:
 * * new_pda - The PDA to insert.
 * * user - The user to try and eject the PDA into the hands of.
 */
/obj/machinery/pdapainter/proc/insert_pda(obj/item/pda/new_pda, mob/living/user)
	if(!istype(new_pda))
		return FALSE

	if(user && !user.transferItemToLoc(new_pda, src))
		return FALSE
	else
		new_pda.forceMove(src)

	if(stored_pda)
		eject_pda(user)

	stored_pda = new_pda
	new_pda.add_fingerprint(user)
	update_icon()
	return TRUE

/**
 * Eject the stored PDA into the user's hands if possible, otherwise on the floor.
 *
 * Arguments:
 * * user - The user to try and eject the PDA into the hands of.
 */
/obj/machinery/pdapainter/proc/eject_pda(mob/living/user)
	if(stored_pda)
		if(user && !issilicon(user) && in_range(src, user))
			user.put_in_hands(stored_pda)
		else
			stored_pda.forceMove(drop_location())

		stored_pda = null
		update_icon()

/**
 * Insert an ID card into the machine.
 *
 * Will swap ID cards if one is already inside. Attempts to put the card into the user's hands if possible.
 * Returns TRUE on success, FALSE otherwise.
 * Arguments:
 * * new_id_card - The ID card to insert.
 * * user - The user to try and eject the PDA into the hands of.
 */
/obj/machinery/pdapainter/proc/insert_id_card(obj/item/card/id/new_id_card, mob/living/user)
	if(!istype(new_id_card))
		return FALSE

	if(user && !user.transferItemToLoc(new_id_card, src))
		return FALSE
	else
		new_id_card.forceMove(src)

	if(stored_id_card)
		eject_id_card(user)

	stored_id_card = new_id_card
	new_id_card.add_fingerprint(user)
	update_icon()
	return TRUE

/**
 * Eject the stored ID card into the user's hands if possible, otherwise on the floor.
 *
 * Arguments:
 * * user - The user to try and eject the ID card into the hands of.
 */
/obj/machinery/pdapainter/proc/eject_id_card(mob/living/user)
	if(stored_id_card)
		if(user && !issilicon(user) && in_range(src, user))
			user.put_in_hands(stored_id_card)
		else
			stored_id_card.forceMove(drop_location())

		stored_id_card = null
		update_appearance(UPDATE_ICON)

/obj/machinery/pdapainter/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PaintingMachine", name)
		ui.open()

/obj/machinery/pdapainter/ui_data(mob/user)
	var/data = list()

	if(stored_pda)
		data["hasPDA"] = TRUE
		data["pdaName"] = stored_pda.name
	else
		data["hasPDA"] = FALSE
		data["pdaName"] = null

	if(stored_id_card)
		data["hasID"] = TRUE
		data["idName"] = stored_id_card.name
	else
		data["hasID"] = FALSE
		data["idName"] = null

	return data

/obj/machinery/pdapainter/ui_static_data(mob/user)
	var/data = list()

	return data

/obj/machinery/pdapainter/ui_act(action, params)
	. = ..()
	if(.)
		return

	switch(action)
		if("eject_pda")
			if((machine_stat & BROKEN))
				return TRUE

			var/obj/item/held_item = usr.get_active_held_item()
			if(istype(held_item, /obj/item/pda))
				// If we successfully inserted, we've ejected the old item. Return early.
				if(insert_pda(held_item, usr))
					return TRUE
			// If we did not successfully insert, try to eject.
			if(stored_pda)
				eject_pda(usr)
				return TRUE

			return TRUE
		if("eject_card")
			if((machine_stat & BROKEN))
				return TRUE

			var/obj/item/held_item = usr.get_active_held_item()
			if(istype(held_item, /obj/item/card/id))
				// If we successfully inserted, we've ejected the old item. Return early.
				if(insert_id_card(held_item, usr))
					return TRUE
			// If we did not successfully insert, try to eject.
			if(stored_id_card)
				eject_id_card(usr)
				return TRUE

			return TRUE
		if("trim_pda")
			if((machine_stat & BROKEN) || !stored_pda)
				return TRUE
			var/obj/item/pda/pda_path = /obj/item/pda

			stored_pda.icon_state = initial(pda_path.icon_state)
			stored_pda.desc = initial(pda_path.desc)
			return TRUE
		if("reset_card")
			if((machine_stat & BROKEN) || !stored_id_card)
				return TRUE

			stored_id_card.clear_account()

			return TRUE

/// Security departmental variant.
/obj/machinery/pdapainter/security
	name = "\improper Security PDA & ID Painter"

/// Medical departmental variant.
/obj/machinery/pdapainter/medbay
	name = "\improper Medbay PDA & ID Painter"

/// Science departmental variant.
/obj/machinery/pdapainter/research
	name = "\improper Research PDA & ID Painter"

/// Engineering departmental variant.
/obj/machinery/pdapainter/engineering
	name = "\improper Engineering PDA & ID Painter"
