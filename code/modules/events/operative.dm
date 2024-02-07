/datum/round_event_control/operative
	name = "Lone Operative"
	typepath = /datum/round_event/ghost_role/operative
	weight = 0 //Admin only
	max_occurrences = 1

	track = EVENT_TRACK_MAJOR
	tags = list(TAG_COMBAT, TAG_DESTRUCTIVE)

/datum/round_event/ghost_role/operative
	minimum_required = 1
	role_name = "lone operative"
	fakeable = FALSE

/datum/round_event/ghost_role/operative/spawn_role()
	var/list/candidates = get_candidates(ROLE_OPERATIVE, ROLE_OPERATIVE)
	if(!candidates.len)
		return NOT_ENOUGH_PLAYERS

	var/mob/dead/selected = pick_n_take(candidates)

	var/list/spawn_locs = list()
	for(var/obj/effect/landmark/carpspawn/L in GLOB.landmarks_list)
		spawn_locs += L.loc
	if(!spawn_locs.len)
		return MAP_ERROR

	var/mob/living/carbon/human/operative = new(pick(spawn_locs))
	operative.randomize_human_appearance(~RANDOMIZE_SPECIES)
	operative.dna.update_dna_identity()
	var/datum/mind/Mind = new /datum/mind(selected.key)
	Mind.set_assigned_role(SSjob.get_job_by_type(/datum/job/lone_operative))
	Mind.special_role = ROLE_LONE_OPERATIVE
	Mind.active = TRUE
	Mind.transfer_to(operative)
	Mind.add_antag_datum(/datum/antagonist/nukeop/lone)

	message_admins("[ADMIN_LOOKUPFLW(operative)] has been made into lone operative by an event.")
	log_game("[key_name(operative)] was spawned as a lone operative by an event.")
	spawned_mobs += operative
	return SUCCESSFUL_SPAWN
