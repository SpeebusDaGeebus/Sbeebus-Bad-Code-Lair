/datum/component/simple_rotation
	/// Additional stuff to do after rotation
	var/datum/callback/AfterRotation
	/// Rotation flags for special behavior
	var/rotation_flags = NONE

/**
 * Adds the ability to rotate an object by Alt-click or Right-click.
 *
 * args:
 * * rotation_flags (optional) Bitflags that determine behavior for rotation (defined in rotation.dm)
 * * AfterRotation (optional) Callback proc that is used after the object is rotated (sound effects, balloon alerts, etc.)
**/
/datum/component/simple_rotation/Initialize(rotation_flags = NONE, AfterRotation)
	if(!ismovable(parent))
		return COMPONENT_INCOMPATIBLE

	src.rotation_flags = rotation_flags
	src.AfterRotation = AfterRotation || CALLBACK(src, PROC_REF(DefaultAfterRotation))

/datum/component/simple_rotation/proc/AddSignals()
	RegisterSignal(parent, COMSIG_CLICK_ALT, PROC_REF(RotateLeft))
	RegisterSignal(parent, COMSIG_ATOM_ATTACK_HAND_SECONDARY, PROC_REF(RotateRight))
	RegisterSignal(parent, COMSIG_PARENT_EXAMINE, PROC_REF(ExamineMessage))

/datum/component/simple_rotation/proc/RemoveSignals()
	UnregisterSignal(parent, list(COMSIG_CLICK_ALT, COMSIG_ATOM_ATTACK_HAND_SECONDARY, COMSIG_PARENT_EXAMINE))

/datum/component/simple_rotation/RegisterWithParent()
	AddSignals()
	return ..()

/datum/component/simple_rotation/PostTransfer()
	//Because of the callbacks which we don't track cleanly we can't transfer this
	//item cleanly, better to let the new of the new item create a new rotation datum
	//instead (there's no real state worth transferring)
	return COMPONENT_NOTRANSFER

/datum/component/simple_rotation/UnregisterFromParent()
	RemoveSignals()
	return ..()

/datum/component/simple_rotation/Destroy()
	AfterRotation = null
	//Signals + verbs removed via UnRegister
	return ..()

/datum/component/simple_rotation/proc/ExamineMessage(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	if(rotation_flags & ROTATION_REQUIRE_WRENCH)
		examine_list += span_notice("This requires a wrench to be rotated.")

/datum/component/simple_rotation/proc/RotateRight(datum/source, mob/user)
	SIGNAL_HANDLER
	Rotate(user, ROTATION_CLOCKWISE)

/datum/component/simple_rotation/proc/RotateLeft(datum/source, mob/user)
	SIGNAL_HANDLER
	Rotate(user, ROTATION_COUNTERCLOCKWISE)

/datum/component/simple_rotation/proc/Rotate(mob/user, degrees)
	if(QDELETED(user))
		CRASH("[src] is being rotated [user ? "with a qdeleting" : "without a"] user")
	if(!istype(user))
		CRASH("[src] is being rotated without a user of the wrong type: [user.type]")
	if(!isnum(degrees))
		CRASH("[src] is being rotated without providing the amount of degrees needed")

	if(!CanBeRotated(user, degrees) || !CanUserRotate(user, degrees))
		return

	var/obj/rotated_obj = parent
	rotated_obj.setDir(turn(rotated_obj.dir, degrees))
	if(rotation_flags & ROTATION_REQUIRE_WRENCH)
		playsound(rotated_obj, 'sound/misc/ratchet.ogg', 25, TRUE)

	AfterRotation?.InvokeAsync(user, degrees)

/datum/component/simple_rotation/proc/CanUserRotate(mob/user, degrees)
	if(isliving(user) && user.can_perform_action(parent, NEED_DEXTERITY))
		return TRUE
	if((rotation_flags & ROTATION_GHOSTS_ALLOWED) && isobserver(user) && CONFIG_GET(flag/ghost_interaction))
		return TRUE
	return FALSE

/datum/component/simple_rotation/proc/CanBeRotated(mob/user, degrees, silent=FALSE)
	var/obj/rotated_obj = parent
	if(!rotated_obj.Adjacent(user))
		silent = TRUE

	if(rotation_flags & ROTATION_REQUIRE_WRENCH)
		if(!isliving(user))
			return FALSE
		var/obj/item/tool = user.get_active_held_item()
		if(!tool || (!(tool.tool_behaviour == TOOL_WRENCH) && !istype(tool, /obj/item/contraption/linker)))
			if(!silent)
				to_chat(user, span_warning("You need a wrench to rotate [rotated_obj]!"))
			return FALSE
	if(!(rotation_flags & ROTATION_IGNORE_ANCHORED) && rotated_obj.anchored)
		if(!silent)
			to_chat(user, span_warning("[rotated_obj] needs to be unanchored!"))
		return FALSE

	// if(rotation_flags & ROTATION_NEEDS_ROOM)
	// 	var/target_dir = turn(rotated_obj.dir, degrees)
	// 	var/obj/structure/window/rotated_window = rotated_obj
	// 	var/fulltile = istype(rotated_window) ? rotated_window.fulltile : FALSE
	// 	if(!valid_build_direction(rotated_obj.loc, target_dir, is_fulltile = fulltile))
	// 		if(!silent)
	// 			rotated_obj.balloon_alert(user, "can't rotate in that direction!")
	// 		return FALSE
	return TRUE

/datum/component/simple_rotation/proc/DefaultAfterRotation(mob/user, degrees)
	to_chat(user, span_smallnotice("I [degrees == ROTATION_FLIP ? "flip" : "rotate"] [parent]."))
	return
