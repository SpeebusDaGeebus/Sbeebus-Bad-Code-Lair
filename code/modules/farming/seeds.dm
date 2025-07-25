/obj/item/neuFarm/seed/mixed_seed
	name = "mixed seeds"

/obj/item/neuFarm/seed/mixed_seed/Initialize()
	plant_def_type = pick(GLOB.plant_defs)
	seed_identity = "[plant_def_type.name] seed"
	. = ..()

/obj/item/neuFarm/seed
	name = "seeds"
	icon = 'icons/roguetown/items/produce.dmi'
	icon_state = "seeds"
	w_class = WEIGHT_CLASS_TINY
	resistance_flags = FLAMMABLE
	possible_item_intents = list(/datum/intent/use)
	var/datum/plant_def/plant_def_type
	var/seed_identity = "some seed"

/obj/item/neuFarm/seed/Initialize()
	. = ..()
	if(plant_def_type)
		var/datum/plant_def/def = GLOB.plant_defs[plant_def_type]
		color = def.seed_color
	if(icon_state == "seeds")
		icon_state = "seeds[rand(1,3)]"

/obj/item/neuFarm/seed/Crossed(mob/living/L)
	. = ..()
	// Chance to destroy the seed as it's being stepped on
	if(prob(10) && istype(L))
		playsound(loc,"plantcross", 40, FALSE)
		qdel(src)

/obj/item/neuFarm/seed/examine(mob/user)
	. = ..()
	var/show_real_identity = FALSE
	if(isliving(user))
		var/mob/living/living = user
		// Seed knowers, know the seeds (druids and such)
		if(HAS_TRAIT(living, TRAIT_SEEDKNOW))
			show_real_identity = TRUE
		// Journeyman farmers know them too
		else if(living.get_skill_level(/datum/skill/labor/farming) >= 2)
			show_real_identity = TRUE
	else
		show_real_identity = TRUE
	if(show_real_identity)
		. += span_info("I can tell these are [seed_identity]")

/obj/item/neuFarm/seed/attack_turf(turf/T, mob/living/user)
	var/obj/structure/soil/soil = get_soil_on_turf(T)
	if(soil)
		try_plant_seed(user, soil)
		return
	else if(istype(T, /turf/open/floor/dirt))
		if(!(user.get_skill_level(/datum/skill/labor/farming) >= SKILL_LEVEL_JOURNEYMAN))
			to_chat(user, span_notice("I don't know enough to make a mound without tools."))
			return
		to_chat(user, span_notice("I begin making a mound for the seeds..."))
		if(do_after(user, get_farming_do_time(user, 10 SECONDS), target = src))
			apply_farming_fatigue(user, 30)
			soil = get_soil_on_turf(T)
			if(!soil)
				soil = new /obj/structure/soil(T)
		return
	. = ..()

/obj/item/neuFarm/seed/proc/try_plant_seed(mob/living/user, obj/structure/soil/soil)
	if(soil.plant)
		to_chat(user, span_warning("There is already something planted in \the [soil]!"))
		return
	if(!plant_def_type)
		return
	to_chat(user, span_notice("I plant \the [src] in \the [soil]."))
	soil.insert_plant(GLOB.plant_defs[plant_def_type])
	qdel(src)

/obj/item/neuFarm/seed/wheat
	seed_identity = "wheat seeds"
	plant_def_type = /datum/plant_def/wheat

/obj/item/neuFarm/seed/oat
	seed_identity = "oat seeds"
	plant_def_type = /datum/plant_def/oat
	color = "#a3eca3"

/obj/item/neuFarm/seed/manabloom
	seed_identity = "manabloom seeds"
	plant_def_type = /datum/plant_def/manabloom
	color = "#a3cbec"

/obj/item/neuFarm/seed/apple
	seed_identity = "apple seeds"
	plant_def_type = /datum/plant_def/apple

/obj/item/neuFarm/seed/westleach
	seed_identity = "westleach leaf seeds"
	plant_def_type = /datum/plant_def/westleach

/obj/item/neuFarm/seed/swampleaf
	seed_identity = "swampweed seeds"
	plant_def_type = /datum/plant_def/swampweed

/obj/item/neuFarm/seed/berry
	seed_identity = "berry seeds"
	plant_def_type = /datum/plant_def/jacksberry

/obj/item/neuFarm/seed/poison_berries
	seed_identity = "berry seeds"
	plant_def_type = /datum/plant_def/jacksberry_poison

/obj/item/neuFarm/seed/cabbage
	seed_identity = "cabbage seeds"
	plant_def_type = /datum/plant_def/cabbage

/obj/item/neuFarm/seed/onion
	seed_identity = "onion seeds"
	color = "#fff2ca"
	plant_def_type = /datum/plant_def/onion
/obj/item/neuFarm/seed/potato
	seed_identity = "potato seedlings"
	plant_def_type = /datum/plant_def/potato
/obj/item/neuFarm/seed/sunflower
	seed_identity = "sunflower seeds"
	plant_def_type = /datum/plant_def/sunflower

/obj/item/neuFarm/seed/pear
	seed_identity = "pear seeds"
	plant_def_type = /datum/plant_def/pear

/obj/item/neuFarm/seed/turnip
	seed_identity = "turnip seedlings"
	plant_def_type = /datum/plant_def/turnip

/obj/item/neuFarm/seed/fyritius
	seed_identity = "fyritius seeds"
	plant_def_type = /datum/plant_def/fyritiusflower

/obj/item/neuFarm/seed/poppy
	seed_identity = "poppy seeds"
	plant_def_type = /datum/plant_def/poppy

/obj/item/neuFarm/seed/plum
	seed_identity = "plum seeds"
	plant_def_type = /datum/plant_def/plum

/obj/item/neuFarm/seed/lemon
	seed_identity = "lemon seeds"
	plant_def_type = /datum/plant_def/lemon

/obj/item/neuFarm/seed/lime
	seed_identity = "lime seeds"
	plant_def_type = /datum/plant_def/lime

/obj/item/neuFarm/seed/tangerine
	seed_identity = "tangerine seeds"
	plant_def_type = /datum/plant_def/tangerine

/obj/item/neuFarm/seed/sugarcane
	seed_identity = "sugarcane seeds"
	plant_def_type = /datum/plant_def/sugarcane

/obj/item/neuFarm/seed/strawberry
	seed_identity = "strawberry seeds"
	plant_def_type = /datum/plant_def/strawberry

/obj/item/neuFarm/seed/blackberry
	seed_identity = "blackberry seeds"
	plant_def_type = /datum/plant_def/blackberry

/obj/item/neuFarm/seed/raspberry
	seed_identity = "raspberry seeds"
	plant_def_type = /datum/plant_def/raspberry

//alchemical
/obj/item/neuFarm/seed/atropa
	seed_identity = "atropa seeds"
	plant_def_type = /datum/plant_def/alchemical/atropa

/obj/item/neuFarm/seed/matricaria
	seed_identity = "matricaria seeds"
	plant_def_type = /datum/plant_def/alchemical/matricaria

/obj/item/neuFarm/seed/symphitum
	seed_identity = "symphitum seeds"
	plant_def_type = /datum/plant_def/alchemical/symphitum

/obj/item/neuFarm/seed/taraxacum
	seed_identity = "taraxacum seeds"
	plant_def_type = /datum/plant_def/alchemical/taraxacum

/obj/item/neuFarm/seed/euphrasia
	seed_identity = "euphrasia seeds"
	plant_def_type = /datum/plant_def/alchemical/euphrasia

/obj/item/neuFarm/seed/paris
	seed_identity = "paris seeds"
	plant_def_type = /datum/plant_def/alchemical/paris

/obj/item/neuFarm/seed/calendula
	seed_identity = "calendula seeds"
	plant_def_type = /datum/plant_def/alchemical/calendula

/obj/item/neuFarm/seed/mentha
	seed_identity = "mentha seeds"
	plant_def_type = /datum/plant_def/alchemical/mentha

/obj/item/neuFarm/seed/urtica
	seed_identity = "urtica seeds"
	plant_def_type = /datum/plant_def/alchemical/urtica

/obj/item/neuFarm/seed/salvia
	seed_identity = "salvia seeds"
	plant_def_type = /datum/plant_def/alchemical/salvia

/obj/item/neuFarm/seed/hypericum
	seed_identity = "hypericum seeds"
	plant_def_type = /datum/plant_def/alchemical/hypericum

/obj/item/neuFarm/seed/benedictus
	seed_identity = "benedictus seeds"
	plant_def_type = /datum/plant_def/alchemical/benedictus

/obj/item/neuFarm/seed/valeriana
	seed_identity = "valeriana seeds"
	plant_def_type = /datum/plant_def/alchemical/valeriana

/obj/item/neuFarm/seed/artemisia
	seed_identity = "artemisia seeds"
	plant_def_type = /datum/plant_def/alchemical/artemisia

/obj/item/neuFarm/seed/rosa
	seed_identity = "rosa seeds"
	plant_def_type = /datum/plant_def/alchemical/rosa

/obj/item/neuFarm/seed/euphorbia
	seed_identity = "euphorbia seeds"
	plant_def_type = /datum/plant_def/alchemical/euphorbia

/*
/obj/item/neuFarm/seed/nut
	seed_identity = "rocknut seeds"
	plant_def_type = /datum/plant_def/nut

/obj/item/neuFarm/seed/garlic
	seed_identity = "garlic seeds"
	plant_def_type = /datum/plant_def/garlic

/obj/item/neuFarm/seed/rice
	seed_identity = "rice seeds"
	plant_def_type = /datum/plant_def/rice

/obj/item/neuFarm/seed/tea
	seed_identity = "tea seeds"
	plant_def_type = /datum/plant_def/tea

/obj/item/neuFarm/seed/mycelium/amanita
	seed_identity = "red mushroom spores"
	plant_def_type = /datum/plant_def/amanita
*/
