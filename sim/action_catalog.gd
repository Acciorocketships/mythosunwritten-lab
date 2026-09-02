extends RefCounted
## The atomic actions, as one list, in one file.
##
## The design names the same set twice: section 2.1 lists what a character may
## do, and section 10 lists the calls an agent makes to do it. Two lists of one
## thing drift -- section 10's own text admits it, telling whoever reads it to
## "keep the two in sync" -- and the sync is a promise nobody can check. So
## there are not two lists here. There is one table, and the two are *projections
## of it*: `listed` is section 2.1's wording of a row and `calls` is section
## 10's spelling of the same row. A name cannot appear in one and not the other,
## because neither is written down apart from the other.
##
## What holds that shut is `faults()`, further down: it reads this table and the
## two files that implement it -- `Action`, which is how a caller says what it
## wants, and `ActionEngine`, which is what resolves it -- and reports every name
## that appears on one side and not the other. `tests/test_actions.gd` runs it
## over the real table and requires nothing, and then over deliberately broken
## copies of the table and requires each break to be caught.
##
## ## What a row is
##
##   * `name` -- the action, and the only name the rest of the code uses. It is
##     also the name of `Action`'s constructor for it and of `ActionEngine`'s
##     resolver for it, so the three are one word in three files.
##   * `listed` -- section 2.1's own wording, quoted, so the row can be read
##     against the design without opening the design.
##   * `calls` -- section 10's call-surface spellings. Several may share a row:
##     `MoveTo`, `MoveRelative`, `Roam` and `Flee` are four ways of saying "go
##     to", and a row is the action, not the phrasing.
##   * `occupies` -- how many ticks carrying the action out costs. Section 2.2
##     says an action is "in progress" and re-evaluated while it runs, which is
##     only meaningful if an action takes time; this column is the time it takes.
##     It is here rather than in the control loop for the same reason the two
##     name columns are here: a cost written beside the loop would be a
##     thirteenth list of the twelve actions, and lists of the twelve actions
##     drift. A wait is the one action that names its own duration -- section
##     2.1 spells it "wait (duration)" -- so its row is the floor and the chosen
##     duration is what it actually costs; `ControlLoop.occupies()` is where
##     that one reading lives.
##   * `params` -- the parameters the action cannot be resolved without.
##   * `optional` -- the ones it can.
##
## Two of section 2.1's actions -- jump and wait -- have no spelling in section
## 10's list at all. That is exactly the drift this file exists to end: section
## 2.1 is the authoritative list, so the two rows carry `Jump` and `Wait` here
## and the call surface is complete. Nothing was invented: both actions are
## section 2.1's, in section 2.1's words.
##
## ## What a parameter is
##
## Every action names its target with the same key, `target`, and the table says
## what sort of thing that key may hold. Ids are one space over everything in the
## world -- characters and objects alike -- because section 10's observation
## gives an agent "nearby entities: id; type (NPC/player/monster/object)" as one
## numbered list, and an action that took two id spaces would need the caller to
## know which list a thing came from.
class_name ActionCatalog

## The twelve actions of section 2.1. Section 2.1 writes trade as one entry with
## three moves and pick up / drop as one entry with two, and they are separate
## rows here for the reason the acceptance asks for them separately: propose,
## accept and deny fail differently and are made by different characters.
const GO_TO := "go_to"
const JUMP := "jump"
const ATTACK := "attack"
const SAY := "say"
const TRADE_PROPOSE := "trade_propose"
const TRADE_ACCEPT := "trade_accept"
const TRADE_DENY := "trade_deny"
const PICK_UP := "pick_up"
const DROP := "drop"
const EXAMINE := "examine"
const INTERACT := "interact"
const WAIT := "wait"

## What a parameter may hold. A `target` is checked against one of the first
## three; the rest say what a plain value is.
const ID := "id"
const POSITION := "position"
const ID_OR_POSITION := "id-or-position"
const ID_OR_NAME := "id-or-name"
const TEXT := "text"
const COUNT := "count"
const NAMES := "names"

## The id nobody has: an absent target. Shouting is saying with no one named,
## and dropping on the ground is dropping into nothing named.
const NOBODY := 0

## The one list. Section 2.1 down the `listed` column, section 10 down the
## `calls` column, one row each.
const ROWS := [
	{
		"name": GO_TO,
		"listed": "go to (position / item / character)",
		"calls": ["MoveTo", "MoveRelative", "Roam", "Flee"],
		"occupies": 20,
		"params": {"target": ID_OR_POSITION},
		"optional": {},
	},
	{
		"name": JUMP,
		"listed": "jump (position)",
		"calls": ["Jump"],
		"occupies": 4,
		"params": {"target": POSITION},
		"optional": {},
	},
	{
		"name": ATTACK,
		"listed": "attack (target, with which item)",
		"calls": ["Attack"],
		"occupies": 6,
		"params": {"target": ID, "item": TEXT},
		"optional": {},
	},
	{
		"name": SAY,
		"listed": "say (text; targeted, or shout -> everyone in range hears)",
		"calls": ["Talk"],
		"occupies": 5,
		"params": {"text": TEXT},
		"optional": {"target": ID},
	},
	{
		"name": TRADE_PROPOSE,
		"listed": "trade (propose; items + money in/out)",
		"calls": ["ProposeTrade"],
		"occupies": 4,
		"params": {"target": ID},
		"optional": {
			"give": NAMES, "give_money": COUNT,
			"want": NAMES, "want_money": COUNT,
		},
	},
	{
		"name": TRADE_ACCEPT,
		"listed": "trade (accept)",
		"calls": ["AcceptTrade"],
		"occupies": 3,
		"params": {"target": ID},
		"optional": {},
	},
	{
		"name": TRADE_DENY,
		"listed": "trade (deny)",
		"calls": ["DenyTrade"],
		"occupies": 2,
		"params": {"target": ID},
		"optional": {},
	},
	{
		"name": PICK_UP,
		"listed": "pick up (ground or chest)",
		"calls": ["Take"],
		"occupies": 3,
		"params": {"item": TEXT},
		"optional": {"target": ID},
	},
	{
		"name": DROP,
		"listed": "drop (ground or chest)",
		"calls": ["Drop"],
		"occupies": 2,
		"params": {"item": TEXT},
		"optional": {"target": ID},
	},
	{
		"name": EXAMINE,
		"listed": "examine (observable info on an item/person in sight)",
		"calls": ["Query", "ViewInventory", "AccessInventory"],
		"occupies": 4,
		"params": {"target": ID_OR_NAME},
		"optional": {},
	},
	{
		"name": INTERACT,
		"listed": "interact (generic; target entity + item used)",
		"calls": ["Interact"],
		"occupies": 6,
		"params": {"target": ID},
		"optional": {"item": TEXT},
	},
	{
		"name": WAIT,
		"listed": "wait (duration)",
		"calls": ["Wait"],
		"occupies": 1,
		"params": {"ticks": COUNT},
		"optional": {},
	},
]


# --- Reading the one list -------------------------------------------------


## Every action name, in the table's order.
static func names(table: Array = ROWS) -> PackedStringArray:
	var found := PackedStringArray()
	for row in table:
		found.append(row["name"])
	return found


## Every call-surface name, in the table's order. Section 10's list, and it is
## this because there is nowhere else for it to be.
static func call_names(table: Array = ROWS) -> PackedStringArray:
	var found := PackedStringArray()
	for row in table:
		for spelling in row["calls"]:
			found.append(spelling)
	return found


## The row for an action name, or an empty dictionary.
static func row_of(action_name: String, table: Array = ROWS) -> Dictionary:
	for row in table:
		if row["name"] == action_name:
			return row
	return {}


## The action a call-surface name resolves to, or "".
static func action_for_call(spelling: String, table: Array = ROWS) -> String:
	for row in table:
		if PackedStringArray(row["calls"]).has(spelling):
			return row["name"]
	return ""


## Whether a name is one of the actions.
static func is_action(action_name: String, table: Array = ROWS) -> bool:
	return not row_of(action_name, table).is_empty()


## How many ticks an action of this kind costs to carry out, or zero for a name
## that is not an action. `faults()` requires every row to declare at least one,
## so a zero here always means the name was wrong and never that the table
## forgot.
static func occupies_of(action_name: String, table: Array = ROWS) -> int:
	var row := row_of(action_name, table)
	return 0 if row.is_empty() else int(row.get("occupies", 0))


# --- Whether a chosen action can be resolved at all ------------------------


## Why an action as chosen cannot be resolved, or "" when nothing is wrong.
##
## This is the first way every call can fail, and it is one function rather than
## a check at the head of each resolver: an unknown action, a missing parameter,
## a parameter holding the wrong sort of thing, and a parameter the row does not
## know about are all faults of the *choice*, before the world is consulted at
## all.
static func fault(action: Action, table: Array = ROWS) -> String:
	if action == null:
		return "nothing was chosen"
	var row := row_of(action.kind, table)
	if row.is_empty():
		return "%s is not an action" % action.kind
	var required: Dictionary = row["params"]
	var optional: Dictionary = row["optional"]
	for key in required:
		if not action.params.has(key):
			return "%s needs %s" % [action.kind, key]
		var wrong := _wrong_sort(action.params[key], required[key])
		if wrong != "":
			return "%s's %s %s" % [action.kind, key, wrong]
	for key in action.params:
		if required.has(key):
			continue
		if not optional.has(key):
			return "%s takes no %s" % [action.kind, key]
		var wrong := _wrong_sort(action.params[key], optional[key])
		if wrong != "":
			return "%s's %s %s" % [action.kind, key, wrong]
	return ""


# Whether a value is the sort of thing a parameter takes, said as the tail of a
# sentence so the reason a call failed reads as one.
static func _wrong_sort(value: Variant, sort: String) -> String:
	match sort:
		ID:
			return "" if value is int else "must be an id"
		POSITION:
			return "" if value is Vector2 else "must be a position"
		ID_OR_POSITION:
			return "" if value is int or value is Vector2 else "must be an id or a position"
		ID_OR_NAME:
			return "" if value is int or value is String else "must be an id or a name"
		TEXT:
			return "" if value is String else "must be text"
		COUNT:
			return "" if value is int else "must be a count"
		NAMES:
			return "" if value is PackedStringArray else "must be a list of names"
	return "is of no known sort"


# --- The check that the lists cannot drift --------------------------------


## Every way the one list and the two files implementing it can disagree.
##
## Returns one line per disagreement, empty when there is none. Four things are
## compared, and all four are read rather than restated:
##
##   * every row carries both projections -- a section 2.1 wording and at least
##     one section 10 call name -- so neither column can be left blank;
##   * every row costs at least one tick, so no action can be free and therefore
##     un-interruptible;
##   * no call name is shared by two rows, so a spelling means one action;
##   * `Action` declares a constructor named for every row and for nothing else;
##   * `ActionEngine` declares a resolver named for every row and for nothing
##     else.
##
## `constructors` and `resolvers` are handed in rather than read from disk here,
## so the same function can be run against a table and a pair of lists that were
## deliberately broken -- which is how the test shows the check has teeth.
static func faults(
	table: Array, constructors: PackedStringArray, resolvers: PackedStringArray
) -> PackedStringArray:
	var found := PackedStringArray()
	var seen_calls := {}
	for row in table:
		var action_name: String = row["name"]
		if String(row["listed"]).strip_edges() == "":
			found.append("%s has no section 2.1 wording" % action_name)
		if PackedStringArray(row["calls"]).is_empty():
			found.append("%s has no call-surface name" % action_name)
		if int(row.get("occupies", 0)) < 1:
			found.append("%s costs no ticks to carry out" % action_name)
		for spelling in row["calls"]:
			if seen_calls.has(spelling):
				found.append("%s is the call name of both %s and %s" % [
					spelling, seen_calls[spelling], action_name,
				])
			seen_calls[spelling] = action_name

	var listed := names(table)
	for action_name in listed:
		if not constructors.has(action_name):
			found.append("%s is an action nothing can choose" % action_name)
		if not resolvers.has(action_name):
			found.append("%s is an action nothing resolves" % action_name)
	for declared in constructors:
		if not listed.has(declared):
			found.append("%s can be chosen and is not an action" % declared)
	for declared in resolvers:
		if not listed.has(declared):
			found.append("%s is resolved and is not an action" % declared)
	return found


## The table as a report prints it: section 2.1's wording, the action, and
## section 10's calls, one row per line.
static func table_lines(table: Array = ROWS) -> PackedStringArray:
	var written := PackedStringArray()
	for row in table:
		written.append("%-14s %-36s %3dt  %s" % [
			row["name"], " ".join(PackedStringArray(row["calls"])),
			int(row.get("occupies", 0)), row["listed"],
		])
	return written
