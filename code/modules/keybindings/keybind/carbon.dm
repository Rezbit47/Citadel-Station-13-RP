/datum/keybinding/carbon
	category = CATEGORY_CARBON
	weight = WEIGHT_MOB

/datum/keybinding/carbon/can_use(client/user)
	return iscarbon(user.mob)

/datum/keybinding/carbon/toggle_throw_mode
	hotkey_keys = list("R", "Southwest") // END
	name = "toggle_throw_mode"
	full_name = "Toggle throw mode"
	description = "Toggle throwing the current item or not."
	category = CATEGORY_CARBON

/datum/keybinding/carbon/toggle_throw_mode/down(client/user)
	var/mob/living/carbon/C = user.mob
	C.toggle_throw_mode()
	return TRUE

/datum/keybinding/carbon/overhand_throw_mode
	hotkey_keys = list("CtrlR", "CtrlSouthwest")
	name = "overhand_throw_mode"
	full_name = "Throw item overhand"
	description = "Toggle throwing the current item overhand or not"
	category = CATEGORY_CARBON

/datum/keybinding/carbon/overhand_throw_mode/down(client/user)
	var/mob/living/carbon/C = user.mob
	C.toggle_throw_mode(TRUE)
	return TRUE

/datum/keybinding/carbon/select_help_intent
	hotkey_keys = list("1")
	name = "select_help_intent"
	full_name = "Select help intent"
	description = "No description provided."
	category = CATEGORY_CARBON

/datum/keybinding/carbon/select_help_intent/down(client/user)
	user.mob?.a_intent_change(INTENT_HELP)
	return TRUE

/datum/keybinding/carbon/select_disarm_intent
	hotkey_keys = list("2")
	name = "select_disarm_intent"
	full_name = "Select disarm intent"
	description = "No description provided."
	category = CATEGORY_CARBON

/datum/keybinding/carbon/select_disarm_intent/down(client/user)
	user.mob?.a_intent_change(INTENT_DISARM)
	return TRUE

/datum/keybinding/carbon/select_grab_intent
	hotkey_keys = list("3")
	name = "select_grab_intent"
	full_name = "Select grab intent"
	description = "No description provided."
	category = CATEGORY_CARBON

/datum/keybinding/carbon/select_grab_intent/down(client/user)
	user.mob?.a_intent_change(INTENT_GRAB)
	return TRUE

/datum/keybinding/carbon/select_harm_intent
	hotkey_keys = list("4")
	name = "select_harm_intent"
	full_name = "Select harm intent"
	description = "No description provided."
	category = CATEGORY_CARBON

/datum/keybinding/carbon/select_harm_intent/down(client/user)
	user.mob?.a_intent_change(INTENT_HARM)
	return TRUE
