extends RefCounted
## The sheet a character is rolled with before anybody has decided who it is.
##
## Section 8 states the order and the reason for it: "first roll the skill sheet
## (sampled from ranges by unit role + local region difficulty), then have the
## LLM write a personality/backstory that explains the rolls (high CHA, low WIS
## -> a charming fool)". This file is the first half of that sentence, and it is
## a separate file from the second half so that the order is a fact about the
## code rather than a claim in a comment: nothing here can see a reply, because
## nothing here is ever handed one.
##
## ## The two things a band is made of
##
##   * **Unit role.** Four of them, each a band per ability score. A role is a
##     shape, not a story: `HERALD` is "the one whose charisma band is high and
##     whose wisdom band is low", and what that *means* about a person is the
##     next call's business and not this file's. The roles are deliberately far
##     apart, so that a rolled sheet is recognisably one of them.
##   * **Local region difficulty**, which is section 5's gradient and is read
##     from the world rather than invented here. `ItemFrontier` already turns a
##     distance from spawn into a level -- it is the file the whole project reads
##     that gradient out of -- and the world origin is spawn (see the spacing
##     rule at the head of `sim/settlement_field.gd`, which places the first
##     village on a ring around it). A spawned character's level *is* that
##     number, unmodified. Its ability bands are lifted more slowly, by one point
##     every `RINGS_A_POINT` rings, which is this file's own conversion and is
##     stated here rather than hidden: a level is unbounded by design and an
##     ability score is compared against item levels, so lifting the two at one
##     rate would put a frontier villager's charisma in the hundreds.
##
## ## The roll is hashed, never streamed
##
## The same discipline `AbilityCheck.rolled` keeps for a die and the combat layer
## keeps for a blow. A stream's numbers depend on how many were drawn before
## them, so who the third character spawned in a run turns out to be would depend
## on how many were spawned first. Hashing the world seed, which spawn this is,
## the role and the ability makes a rolled score a fact about that spawn.
class_name SpawnRoll

## The four unit roles.
const GUARD := "guard"
const HERALD := "herald"
const SCOUT := "scout"
const SCHOLAR := "scholar"

## How many rings of the section 5 gradient lift an ability band by one point.
## This file's own conversion; see the note above.
const RINGS_A_POINT := 4

## One row per role: what it is called, what it looks like to a renderer, and the
## band each of the six ability scores is drawn from -- in `Ability.ALL`'s order,
## which is the order section 2 lists them in.
const ROLES := [
	{
		"role": GUARD, "looks": AssetTags.KNIGHT,
		"bands": [[8, 12], [8, 12], [2, 6], [4, 8], [3, 7], [2, 6]],
	},
	{
		"role": HERALD, "looks": AssetTags.ROGUE,
		"bands": [[2, 6], [3, 7], [12, 16], [4, 8], [1, 4], [5, 9]],
	},
	{
		"role": SCOUT, "looks": AssetTags.RANGER,
		"bands": [[4, 8], [5, 9], [3, 7], [9, 13], [6, 10], [4, 8]],
	},
	{
		"role": SCHOLAR, "looks": AssetTags.MAGE,
		"bands": [[1, 5], [2, 6], [4, 8], [3, 7], [8, 12], [10, 14]],
	},
]


## Every role there is, in the order above.
static func roles() -> PackedStringArray:
	var found := PackedStringArray()
	for row in ROLES:
		found.append(String(row["role"]))
	return found


## One role's row, or an empty dictionary for a name that is not one.
static func row_of(role: String) -> Dictionary:
	for row in ROLES:
		if String(row["role"]) == role:
			return row
	return {}


## Whether a name is one of the roles.
static func is_role(role: String) -> bool:
	return not row_of(role).is_empty()


## What a role looks like, for whatever draws it.
static func looks_of(role: String) -> String:
	var row := row_of(role)
	return AssetTags.KNIGHT if row.is_empty() else String(row["looks"])


# --- The gradient, read from the world ------------------------------------


## The local region difficulty at a world position: section 5's own number, out
## of section 5's own file, for the distance from spawn.
static func difficulty_at(at_x: float, at_z: float) -> int:
	return ItemFrontier.level_at(Vector2(at_x, at_z).length())


## Which ring of the gradient a world position falls in.
static func ring_at(at_x: float, at_z: float) -> int:
	return ItemFrontier.ring_at(Vector2(at_x, at_z).length())


## How much the region lifts every band here, in points of ability score.
static func lift_at(at_x: float, at_z: float) -> int:
	return ring_at(at_x, at_z) / RINGS_A_POINT


# --- The roll --------------------------------------------------------------


## The band one ability score is drawn from here: the role's band, lifted by the
## region.
static func band_for(role: String, ability: String, at_x: float, at_z: float) -> Vector2i:
	var row := row_of(role)
	if row.is_empty() or not Ability.is_ability(ability):
		return Vector2i.ZERO
	var band: Array = row["bands"][Ability.rank(ability)]
	var lift := lift_at(at_x, at_z)
	return Vector2i(int(band[0]) + lift, int(band[1]) + lift)


## One ability score, drawn from that band.
##
## `nth` is which spawn of this run it is, and not an id out of the scene: the
## sheet is rolled before there is anything to give an id to, which is the whole
## point of the order.
##
## The role is folded into the hash with `AbilityCheck.folded`, which is the
## project's one string-to-whole-number fold. Writing a second one here would be
## two.
static func rolled(
	world_seed: int, nth: int, role: String, ability: String,
	at_x: float, at_z: float
) -> int:
	var band := band_for(role, ability, at_x, at_z)
	if band.y <= band.x:
		return band.x
	var drawn := SimRng.hash_ints(
		world_seed ^ AbilityCheck.folded(role), nth, Ability.rank(ability))
	return band.x + drawn % (band.y - band.x + 1)


## The whole sheet, rolled: the level the region gives it, the six scores out of
## the role's bands, and the gear the region's own frontier forges.
##
## It has no name, no backstory, no trait and no tendency, because none of those
## have been written yet. That is not an omission -- it is the state a character
## is in between the two halves of section 8's sentence, and it is a state the
## world can be stepped in.
static func sheet_at(
	world_seed: int, nth: int, role: String, at_x: float, at_z: float
) -> Character:
	var sheet := Character.make("", difficulty_at(at_x, at_z))
	var rolls := {}
	for ability in Ability.ALL:
		rolls[ability] = rolled(world_seed, nth, role, ability, at_x, at_z)
	sheet.record_scores(rolls)
	sheet.inventory.carry_all(ItemFrontier.carried_at(
		world_seed, "spawn/%d/%s" % [nth, role], Vector2(at_x, at_z).length()))
	return sheet


# --- What a rolled sheet has to be explained about ------------------------


## The highest and lowest of the six, and how far apart they are.
##
## What the persona call is shown and what a report prints, so that "the persona
## explains the rolls" is read against the two numbers that most need explaining
## rather than against six.
static func spread_of(sheet: Character) -> Dictionary:
	var high := ""
	var low := ""
	for ability in Ability.ALL:
		if not sheet.has_score(ability):
			continue
		if high == "" or sheet.score(ability) > sheet.score(high):
			high = ability
		if low == "" or sheet.score(ability) < sheet.score(low):
			low = ability
	if high == "":
		return {"high": "", "low": "", "spread": 0}
	return {
		"high": high, "low": low,
		"spread": sheet.score(high) - sheet.score(low),
	}
