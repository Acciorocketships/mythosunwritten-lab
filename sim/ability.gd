extends RefCounted
## The six ability scores, as a vocabulary and nothing else.
##
## Section 2 names them: STR, CON, CHA, DEX, WIS, INT. They are here, and only
## here, because section 4's ability-score gate has to say *which* score an item
## is read against, and a gate that compares against an untyped integer would be
## a gate that cannot be got wrong -- and therefore one that checks nothing.
##
## What this file deliberately is not: a character sheet. There is no owner of
## these scores anywhere in the project yet, and this file does not invent one.
## It is six strings, a fixed order, and a validity test. When the character
## sheet arrives it holds a score per name from this list; until then an item's
## gate takes a bare score and the name of the ability it is a score for.
##
## It is also not a class, a skill or a learned ability. The design is explicit
## that no character has any of those -- an ability score is what a character is,
## and every ability a character can *do* lives on an item.
class_name Ability

const STR := "str"
const CON := "con"
const CHA := "cha"
const DEX := "dex"
const WIS := "wis"
const INT := "int"

## Every score, in the order section 2 lists them. Reports walk this; nothing
## reads it by position except a draw that needs a fixed order to be repeatable.
const ALL := [STR, CON, CHA, DEX, WIS, INT]


## Whether a name is one of the six. Anything else is a typo, and an item built
## on a typo would gate against a score its wearer can never have.
static func is_ability(name_of: String) -> bool:
	return ALL.has(name_of)


## The position of a score in the fixed order, or -1.
static func rank(name_of: String) -> int:
	return ALL.find(name_of)
