
#define NPC_SHIP_LOSE_DELAY 20 MINUTES
#define ON_PROJECTILE_HIT_MESSAGES list(\
"We're taking fire. Requesting assistance from nearby ships! Repeat; Taking fire!",\
"Our hull has been breached! Help!",\
"Sweet hell, is this what we pay our taxses for?!","We're on your side!","Please, we're unarmed!","Oh god, they're firing on us!",\
"This is the captain of F-H-419, we're being fired upon. Requesting assistance."\
)
#define ON_DEATH_MESSAGES list(\
"Do you feel like a hero yet?","Oof-",\
"You bastards.","Automated Alert: Fuel lines damaged. Multiple hull breaches. Immediate assistance required."\
)
#define ALL_CIVILLIAN_SHIPNAMES list(\
"Pete's Cube","The Nomad","The Messenger","Slow But Steady","Road Less Travelled","Dawson's Christian","Flexi Taped","Paycheck","Distant Home"\
)

/obj/effect/overmap/ship/npc_ship
	name = "Ship"
	desc = "A ship, Duh."

	icon = 'code/modules/halo/overmap/freighter.dmi'
	icon_state = "ship"

	var/list/messages_on_hit = ON_PROJECTILE_HIT_MESSAGES
	var/list/messages_on_death = ON_DEATH_MESSAGES

	var/hull = 100 //Essentially used to tell the ship when to "stop" trying to move towards it's area.

	var/move_delay = 6 SECONDS //The amount of ticks to delay for when auto-moving across the system map.
	var/turf/target_loc

	var/unload_at = 0
	var/list/ship_datums = list(/datum/npc_ship)
	var/datum/npc_ship/chosen_ship_datum

	var/list/projectiles_to_spawn = list()

/obj/effect/overmap/ship/npc_ship/proc/lose_to_space()
	if(hull > initial(hull)/4)//If they still have more than quarter of their "hull" left, let them drift in space.
		return
	for(var/mob/player in GLOB.player_list)
		if(player.z in map_z)
			return //Don't disappear if there's people aboard.
	for(var/z_level in map_z)
		shipmap_handler.free_map(z_level)
	GLOB.processing_objects -= src
	qdel(src)

/obj/effect/overmap/ship/npc_ship/proc/generate_ship_name()
	name = pick(ALL_CIVILLIAN_SHIPNAMES)

/obj/effect/overmap/ship/npc_ship/Initialize()
	var/turf/start_turf = locate(x,y,z)
	. = ..()
	map_z.Cut()
	forceMove(start_turf)
	pick_target_loc()
	generate_ship_name()

/obj/effect/overmap/ship/npc_ship/proc/pick_target_loc()

	var/n_x = rand(1, GLOB.using_map.overmap_size - 1)
	var/n_y = rand(1, GLOB.using_map.overmap_size - 1)

	target_loc = locate(n_x,n_y,GLOB.using_map.overmap_z)

/obj/effect/overmap/ship/npc_ship/process()
	if(world.time >= unload_at && unload_at != 0)
		lose_to_space()
	if(hull > initial(hull)/4)
		if(loc == target_loc)
			pick_target_loc()
		else
			walk(src,get_dir(src,target_loc),move_delay)
			dir = get_dir(src,target_loc)
	else
		target_loc = null
		walk(src,0)

/obj/effect/overmap/ship/npc_ship/proc/broadcast_hit(var/ship_disabled = 0)
	var/message_to_use = pick(messages_on_hit)
	if(ship_disabled)
		message_to_use = pick(messages_on_death)
	GLOB.global_headset.autosay("[message_to_use]","[name]","EBAND")

/obj/effect/overmap/ship/npc_ship/proc/take_projectiles(var/obj/item/projectile/overmap/proj)
	projectiles_to_spawn += proj
	hull -= proj.damage
	if(hull <= initial(hull)/4 && target_loc)
		broadcast_hit(1)
	else
		broadcast_hit()

/obj/effect/overmap/ship/npc_ship/proc/pick_ship_datum()
	chosen_ship_datum = pick(ship_datums)
	chosen_ship_datum = new chosen_ship_datum

/obj/effect/overmap/ship/npc_ship/proc/load_mapfile()
	if(unload_at)
		return
	if(!chosen_ship_datum)
		pick_ship_datum()
	map_bounds = chosen_ship_datum.map_bounds
	fore_dir = chosen_ship_datum.fore_dir
	map_z = list()
	for(var/link in chosen_ship_datum.mapfile_links)
		spawn(-1)
			to_world("Loading Ship-Map: [link]... This may cause lag.")
		var/z_to_load_at = shipmap_handler.get_next_usable_z()
		shipmap_handler.un_free_map(z_to_load_at)
		spawn(-1)
			maploader.load_map(link,z_to_load_at)
		map_z += z_to_load_at //The above proc will increase the maxz by 1 to accomodate the new map. This deals with that.
	for(var/zlevel in map_z)
		map_sectors["[zlevel]"] = src
	damage_spawned_ship()
	unload_at = world.time + NPC_SHIP_LOSE_DELAY
	GLOB.processing_objects += src

/obj/effect/overmap/ship/npc_ship/proc/damage_spawned_ship()
	for(var/obj/item/projectile/overmap/proj in projectiles_to_spawn)
		proj.do_z_level_proj_spawn(pick(map_z),src)
		qdel(proj)

/datum/npc_ship
	var/list/mapfile_links = list('maps/civ_hauler/civhauler.dmm')//Multi-z maps should be included in a bottom to top order.

	var/fore_dir = WEST //The direction of "fore" for the mapfile.
	var/list/map_bounds = list(1,50,50,1)//Used for projectile collision bounds for the selected mapfile.

#undef NPC_SHIP_LOSE_DELAY
#undef ON_PROJECTILE_HIT_MESSAGES
#undef ON_DEATH_MESSAGES
#undef ALL_CIVILLIAN_SHIPNAMES