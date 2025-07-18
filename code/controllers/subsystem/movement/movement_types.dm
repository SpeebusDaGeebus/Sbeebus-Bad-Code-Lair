///Template class of the movement datums, handles the timing portion of the loops
/datum/move_loop
	///The movement packet that owns us
	var/datum/movement_packet/owner
	///The subsystem we're processing on
	var/datum/controller/subsystem/movement/controller
	///An extra reference we pass around
	///It is on occasion useful to have a reference to some datum without storing it on the moving object
	///Mostly comes up in high performance senarios where we care about things being singletons
	///This feels horrible, but constantly making components seems worse
	var/datum/extra_info
	///The thing we're moving about
	var/atom/movable/moving
	///Defines how different move loops override each other. Lower numbers beat higher numbers
	var/priority = MOVEMENT_DEFAULT_PRIORITY
	///Bitfield of different things that affect how a loop operates
	var/flags
	///Time till we stop processing in deci-seconds, defaults to forever
	var/lifetime = INFINITY
	///Delay between each move in deci-seconds
	var/delay = 1
	///The next time we should process
	var/timer = 0

/datum/move_loop/New(datum/movement_packet/owner, datum/controller/subsystem/movement/controller, atom/moving, priority, flags, datum/extra_info)
	src.owner = owner
	src.controller = controller
	src.extra_info = extra_info
	if(extra_info)
		RegisterSignal(extra_info, COMSIG_PARENT_QDELETING, PROC_REF(info_deleted))
	src.moving = moving
	src.priority = priority
	src.flags = flags

/datum/move_loop/proc/setup(delay = 1, timeout = INFINITY)
	if(!ismovable(moving) || !owner)
		return FALSE

	src.delay = max(delay, world.tick_lag) //Please...
	src.lifetime = timeout
	return TRUE

/datum/move_loop/proc/start_loop()
	SHOULD_CALL_PARENT(TRUE)
	SEND_SIGNAL(src, COMSIG_MOVELOOP_START)
	//If this is our first time starting to move with this loop
	//And we're meant to start instantly
	if(!timer && flags & MOVEMENT_LOOP_START_FAST)
		timer = world.time
		return
	timer = world.time + delay

/datum/move_loop/proc/stop_loop()
	SHOULD_CALL_PARENT(TRUE)
	SEND_SIGNAL(src, COMSIG_MOVELOOP_STOP)

/datum/move_loop/proc/info_deleted(datum/source)
	SIGNAL_HANDLER
	extra_info = null

/datum/move_loop/Destroy()
	if(owner)
		owner.remove_loop(controller, src)
	owner = null
	moving = null
	controller = null
	extra_info = null
	return ..()

///Exists as a helper so outside code can modify delay while also modifying timer
/datum/move_loop/proc/set_delay(new_delay)
	delay =  max(new_delay, world.tick_lag)
	timer = world.time + delay

/datum/move_loop/process()
	var/old_delay = delay //The signal can sometimes change delay

	if(SEND_SIGNAL(src, COMSIG_MOVELOOP_PREPROCESS_CHECK) & MOVELOOP_SKIP_STEP) //Chance for the object to react
		return

	lifetime -= old_delay //This needs to be based on work over time, not just time passed

	if(lifetime < 0) //Otherwise lag would make things look really weird
		qdel(src)
		return

	var/visual_delay = controller.visual_delay
	var/success = move()

	SEND_SIGNAL(src, COMSIG_MOVELOOP_POSTPROCESS, success, delay * visual_delay)

	timer = world.time + delay
	if(QDELETED(src) || !success) //Can happen
		return

	moving.set_glide_size(MOVEMENT_ADJUSTED_GLIDE_SIZE(delay, visual_delay))

///Handles the actual move, overriden by children
///Returns FALSE if nothing happen, TRUE otherwise
/datum/move_loop/proc/move()
	return FALSE

///Removes the atom from some movement subsystem. Defaults to SSmovement
/datum/controller/subsystem/move_manager/proc/stop_looping(atom/movable/moving, datum/controller/subsystem/movement/subsystem = SSmovement)
	var/datum/movement_packet/our_info = moving.move_packet
	if(!our_info)
		return FALSE
	return our_info.remove_subsystem(subsystem)

/**
 * Replacement for walk()
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * direction - The direction we want to move in
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to infinity
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/move(moving, direction, delay, timeout, subsystem, priority, flags, datum/extra_info, datum/move_loop/move_loop_type = /datum/move_loop/move)
	return add_to_loop(moving, subsystem, move_loop_type, priority, flags, extra_info, delay, timeout, direction)

///Replacement for walk()
/datum/move_loop/move
	var/direction

/datum/move_loop/move/setup(delay, timeout, dir)
	. = ..()
	if(!.)
		return
	direction = dir

/datum/move_loop/move/move()
	var/atom/old_loc = moving.loc
	moving.Move(get_step(moving, direction), direction)
	// We cannot rely on the return value of Move(), we care about teleports and it doesn't
	return old_loc != moving.loc

/**
 * Like move(), but it uses byond's pathfinding on a step by step basis
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * direction - The direction we want to move in
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to infinity
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/move_to_dir(moving, direction, delay, timeout, subsystem, priority, flags, datum/extra_info)
	return add_to_loop(moving, subsystem, /datum/move_loop/move/move_to, priority, flags, extra_info, delay, timeout, direction)

/datum/move_loop/move/move_to

/datum/move_loop/move/move_to/move()
	var/atom/old_loc = moving.loc
	step_to(moving, get_step(moving, direction))
	return old_loc != moving.loc


/**
 * Like move(), but we don't care about collision at all
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * direction - The direction we want to move in
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to infinity
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/force_move_dir(moving, direction, delay, timeout, subsystem, priority, flags, datum/extra_info)
	return add_to_loop(moving, subsystem, /datum/move_loop/move/force, priority, flags, extra_info, delay, timeout, direction)

/datum/move_loop/move/force

/datum/move_loop/move/force/move()
	var/atom/old_loc = moving.loc
	moving.forceMove(get_step(moving, direction))
	return old_loc != moving.loc


/datum/move_loop/has_target
	///The thing we're moving in relation to, either at or away from
	var/atom/target

/datum/move_loop/has_target/setup(delay, timeout, atom/chasing)
	. = ..()
	if(!.)
		return
	if(!isatom(chasing))
		qdel(src)
		return FALSE

	target = chasing

	if(!isturf(target))
		RegisterSignal(target, COMSIG_PARENT_QDELETING, PROC_REF(handle_no_target)) //Don't do this for turfs, because we don't care

/datum/move_loop/has_target/Destroy()
	target = null
	return ..()

/datum/move_loop/has_target/proc/handle_no_target()
	SIGNAL_HANDLER
	qdel(src)


/**
 * Used for force-move loops, similar to move_towards_legacy() but not quite the same
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * chasing - The atom we want to move towards
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to infinity
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/force_move(moving, chasing, delay, timeout, subsystem, priority, flags, datum/extra_info)
	return add_to_loop(moving, subsystem, /datum/move_loop/has_target/force_move, priority, flags, extra_info, delay, timeout, chasing)

///Used for force-move loops
/datum/move_loop/has_target/force_move

/datum/move_loop/has_target/force_move/move()
	var/atom/old_loc = moving.loc
	moving.forceMove(get_step(moving, get_dir(moving, target)))
	return old_loc != moving.loc


///Base class of move_to and move_away, deals with the distance and target aspect of things
/datum/move_loop/has_target/dist_bound
	var/distance = 0

/datum/move_loop/has_target/dist_bound/setup(delay, timeout, atom/chasing, dist = 0)
	. = ..()
	if(!.)
		return
	distance = dist

///Returns FALSE if the movement should pause, TRUE otherwise
/datum/move_loop/has_target/dist_bound/proc/check_dist()
	return FALSE

/datum/move_loop/has_target/dist_bound/move()
	if(!check_dist()) //If we're too close don't do the move
		timer = world.time //Make sure to move as soon as possible
		return FALSE
	return TRUE


/**
 * Wrapper around walk_to()
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * chasing - The atom we want to move towards
 * min_dist - the closest we're allower to get to the target
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to infinity
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/move_to(moving, chasing, min_dist, delay, timeout, subsystem, priority, flags, datum/extra_info)
	return add_to_loop(moving, subsystem, /datum/move_loop/has_target/dist_bound/move_to, priority, flags, extra_info, delay, timeout, chasing, min_dist)

///Wrapper around walk_to()
/datum/move_loop/has_target/dist_bound/move_to

/datum/move_loop/has_target/dist_bound/move_to/check_dist()
	return (get_dist(moving, target) >= distance) //If you get too close, stop moving closer

/datum/move_loop/has_target/dist_bound/move_to/move()
	. = ..()
	if(!.)
		return
	var/atom/old_loc = moving.loc
	step_to(moving, target)
	return old_loc != moving?.loc

/**
 * Wrapper around walk_away()
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * chasing - The atom we want to move towards
 * max_dist - the furthest away from the target we're allowed to get
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to infinity
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/move_away(moving, chasing, max_dist, delay, timeout, subsystem, priority, flags, datum/extra_info)
	return add_to_loop(moving, subsystem, /datum/move_loop/has_target/dist_bound/move_away, priority, flags, extra_info, delay, timeout, chasing, max_dist)

///Wrapper around walk_away()
/datum/move_loop/has_target/dist_bound/move_away

/datum/move_loop/has_target/dist_bound/move_away/check_dist()
	return (get_dist(moving, target) <= distance) //If you get too far out, stop moving away

/datum/move_loop/has_target/dist_bound/move_away/move()
	. = ..()
	if(!.)
		return
	var/atom/old_loc = moving.loc
	step_away(moving, target)
	return old_loc != moving.loc


/**
 * Helper proc for the move_towards datum
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * chasing - The atom we want to move towards
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * home - Should we move towards the object at all times? Or launch towards them, but allow walls and such to take us off track. Defaults to FALSE
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to INFINITY
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/move_towards(moving, chasing, delay, home, timeout, subsystem, priority, flags, datum/extra_info)
	return add_to_loop(moving, subsystem, /datum/move_loop/has_target/move_towards, priority, flags, extra_info, delay, timeout, chasing, home)

/**
 * Helper proc for homing onto something with move_towards
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * chasing - The atom we want to move towards
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * home - Should we move towards the object at all times? Or launch towards them, but allow walls and such to take us off track. Defaults to FALSE
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to INFINITY
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/home_onto(moving, chasing, delay, timeout, subsystem, priority, flags, datum/extra_info)
	return move_towards(moving, chasing, delay, TRUE, timeout, subsystem, priority, flags, extra_info)

///Used as a alternative to walk_towards
/datum/move_loop/has_target/move_towards
	///The turf we want to move into, used for course correction
	var/turf/moving_towards
	///Should we try and stay on the path, or is deviation alright
	var/home = FALSE
	///When this gets larger then 1 we move a turf
	var/x_ticker = 0
	var/y_ticker = 0
	///The rate at which we move, between 0 and 1
	var/x_rate = 1
	var/y_rate = 1
	//We store the signs of x and y seperately, because byond will round negative numbers down
	//So doing all our operations with absolute values then multiplying them is easier
	var/x_sign = 0
	var/y_sign = 0

/datum/move_loop/has_target/move_towards/setup(delay, timeout, atom/chasing, home = FALSE)
	. = ..()
	if(!.)
		return FALSE
	src.home = home

	if(home)
		if(ismovable(target))
			RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(update_slope)) //If it can move, update your slope when it does
		RegisterSignal(moving, COMSIG_MOVABLE_MOVED, PROC_REF(handle_move))
	update_slope()

/datum/move_loop/has_target/move_towards/Destroy()
	if(home)
		if(ismovable(target))
			UnregisterSignal(target, COMSIG_MOVABLE_MOVED)
		if(moving)
			UnregisterSignal(moving, COMSIG_MOVABLE_MOVED)
	return ..()

/datum/move_loop/has_target/move_towards/move()
	//Move our tickers forward a step, we're guaranteed at least one step forward because of how the code is written
	if(x_rate) //Did you know that rounding by 0 throws a divide by 0 error?
		x_ticker = FLOOR(x_ticker + x_rate, x_rate)
	if(y_rate)
		y_ticker = FLOOR(y_ticker + y_rate, y_rate)

	var/x = moving.x
	var/y = moving.y
	var/z = moving.z

	moving_towards = locate(x + round(x_ticker) * x_sign, y + round(y_ticker) * y_sign, z)
	//The tickers serve as good methods of tracking remainder
	if(x_ticker >= 1)
		x_ticker = MODULUS(x_ticker, 1) //I swear to god if you somehow go up by one then one in a tick I'm gonna go mad
	if(y_ticker >= 1)
		y_ticker = MODULUS(x_ticker, 1)
	var/atom/old_loc = moving.loc
	moving.Move(moving_towards, get_dir(moving, moving_towards))

	//YOU FOUND THEM! GOOD JOB
	if(home && get_turf(moving) == get_turf(target))
		x_rate = 0
		y_rate = 0
		return
	return old_loc != moving.loc

/datum/move_loop/has_target/move_towards/proc/handle_move(source, atom/OldLoc, Dir, Forced = FALSE)
	SIGNAL_HANDLER
	if(moving.loc != moving_towards && home) //If we didn't go where we should have, update slope to account for the deviation
		update_slope()

/datum/move_loop/has_target/move_towards/handle_no_target()
	if(home)
		return ..()
	target = null

/**
 * Recalculates the slope between our object and the target, sets our rates to it
 *
 * The math below is reminiscent of something like y = mx + b
 * Except we don't need to care about axis, since we do all our movement in steps of 1
 * Because of that all that matters is we only move one tile at a time
 * So we take the smaller delta, divide it by the larger one, and get smaller step per large step
 * Then we set the large step to 1, and we're done. This way we're guaranteed to never move more then a tile at once
 * And we can have nice lines
**/
/datum/move_loop/has_target/move_towards/proc/update_slope()
	SIGNAL_HANDLER

	//You'll notice this is rise over run, except we flip the formula upside down depending on the larger number
	//This is so we never move more then one tile at once
	var/delta_y = target.y - moving.y
	var/delta_x = target.x - moving.x
	//It's more convienent to store delta x and y as absolute values
	//and modify them right at the end then it is to deal with rounding errors
	x_sign = (delta_x > 0) ? 1 : -1
	y_sign = (delta_y > 0) ? 1 : -1
	delta_x = abs(delta_x)
	delta_y = abs(delta_y)

	if(delta_x >= delta_y)
		if(delta_x == 0) //Just go up/down
			x_rate = 0
			y_rate = 1
			return
		x_rate = 1
		y_rate = delta_y / delta_x //rise over run, you know the deal
	else
		if(delta_y == 0) //Just go right/left
			x_rate = 1
			y_rate = 0
			return
		x_rate = delta_x / delta_y //Keep the larger step size at 1
		y_rate = 1

/**
 * Wrapper for walk_towards, not reccomended, as it's movement ends up being a bit stilted
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * chasing - The atom we want to move towards
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to infinity
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/move_towards_legacy(moving, chasing, delay, timeout, subsystem, priority, flags, datum/extra_info)
	return add_to_loop(moving, subsystem, /datum/move_loop/has_target/move_towards_budget, priority, flags, extra_info, delay, timeout, chasing)

///The actual implementation of walk_towards()
/datum/move_loop/has_target/move_towards_budget

/datum/move_loop/has_target/move_towards_budget/move()
	var/turf/target_turf = get_step_towards(moving, target)
	var/atom/old_loc = moving.loc
	moving.Move(target_turf, get_dir(moving, target_turf))
	return old_loc != moving.loc


/**
 * Helper proc for the move_rand datum
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * directions - A list of acceptable directions to try and move in. Defaults to GLOB.alldirs
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to infinity
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/move_rand(moving, directions, delay, timeout, subsystem, priority, flags, datum/extra_info)
	if(!directions)
		directions = GLOB.alldirs
	return add_to_loop(moving, subsystem, /datum/move_loop/move_rand, priority, flags, extra_info, delay, timeout, directions)

/**
 * This isn't actually the same as walk_rand
 * Because walk_rand is really more like walk_to_rand
 * It appears to pick a spot outside of range, and move towards it, then pick a new spot, etc.
 * I can't actually replicate this on our side, because of how bad our pathfinding is, and cause I'm not totally sure I know what it's doing.
 * I can just implement a random-walk though
**/
/datum/move_loop/move_rand
	var/list/potential_directions

/datum/move_loop/move_rand/setup(delay, timeout, list/directions)
	. = ..()
	if(!.)
		return
	potential_directions = directions

/datum/move_loop/move_rand/move()
	var/list/potential_dirs = potential_directions.Copy()
	while(potential_dirs.len)
		var/testdir = pick(potential_dirs)
		var/turf/moving_towards = get_step(moving, testdir)
		var/atom/old_loc = moving.loc
		moving.Move(moving_towards, testdir)
		if(old_loc != moving.loc)  //If it worked, we're done
			return TRUE
		potential_dirs -= testdir
	return FALSE

/**
 * Wrapper around walk_rand(), doesn't actually result in a random walk, it's more like moving to random places in viewish
 *
 * Returns TRUE if the loop sucessfully started, or FALSE if it failed
 *
 * Arguments:
 * moving - The atom we want to move
 * delay - How many deci-seconds to wait between fires. Defaults to the lowest value, 0.1
 * timeout - Time in deci-seconds until the moveloop self expires. Defaults to infinity
 * subsystem - The movement subsystem to use. Defaults to SSmovement. Only one loop can exist for any one subsystem
 * priority - Defines how different move loops override each other. Lower numbers beat higher numbers, equal defaults to what currently exists. Defaults to MOVEMENT_DEFAULT_PRIORITY
 * flags - Set of bitflags that effect move loop behavior in some way. Check _DEFINES/movement.dm
 *
**/
/datum/controller/subsystem/move_manager/proc/move_to_rand(moving, delay, timeout, subsystem, priority, flags, datum/extra_info)
	return add_to_loop(moving, subsystem, /datum/move_loop/move_to_rand, priority, flags, extra_info, delay, timeout)

///Wrapper around step_rand
/datum/move_loop/move_to_rand

/datum/move_loop/move_to_rand/move()
	var/atom/old_loc = moving.loc
	step_rand(moving)
	return old_loc != moving.loc

/datum/move_loop/minecart
	var/direction
	var/aerial_distance
	var/aerial_velocity

/datum/move_loop/minecart/setup(delay, timeout, dir)
	. = ..()
	if(!.)
		return
	direction = dir

/datum/move_loop/minecart/Destroy()
	if(!QDELETED(moving) && istype(moving, /obj/structure/closet/crate/miningcar))
		var/turf/moving_turf = get_turf(moving)
		if(istype(moving_turf, /turf/open/transparent/openspace))
			var/obj/structure/closet/crate/miningcar/minecart = moving
			minecart.handle_aerial_fall(freefall = TRUE)
	. = ..()

/datum/move_loop/minecart/process()
	. = ..()
	if(QDELETED(src) || QDELETED(moving))
		return
	var/turf/moving_turf = get_turf(moving)
	if(istype(moving_turf, /turf/open/transparent/openspace))
		aerial_velocity += (delay / 10) * 9.8
		aerial_distance += aerial_velocity * (delay / 10)
		if(aerial_distance >= 1)
			aerial_distance -= 1
			if(istype(moving, /obj/structure/closet/crate/miningcar))
				var/obj/structure/closet/crate/miningcar/minecart = moving
				minecart.handle_aerial_fall()
	else
		aerial_distance = 0
		aerial_velocity = 0

/datum/move_loop/minecart/move()
	var/atom/old_loc = moving.loc
	var/atom/new_loc = get_step(moving, direction)
	if(locate(/obj/structure/minecart_rail) in old_loc)
		if(istype(new_loc, /turf/open/transparent/openspace))
			var/turf/below_turf = GET_TURF_BELOW(new_loc)
			if(locate(/obj/structure/minecart_rail) in below_turf)
				new_loc = below_turf
		else if(!(locate(/obj/structure/minecart_rail) in new_loc))
			var/turf/above_turf = GET_TURF_ABOVE(new_loc)
			if(locate(/obj/structure/minecart_rail) in above_turf)
				new_loc = above_turf

	moving.Move(new_loc, direction)
	// We cannot rely on the return value of Move(), we care about teleports and it doesn't
	return old_loc != moving.loc
