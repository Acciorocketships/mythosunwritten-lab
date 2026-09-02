extends RefCounted
## One effect an item carries, and the slice of the item's budget it was bought
## with.
##
## Two fields: what it is called, and how many points of the item's effects axis
## were spent on it. The magnitudes of an item's effects sum to that axis
## exactly, by the same largest-remainder rule that divides the axes themselves,
## so "this item has three effects" is a statement about how its budget was
## divided and not a list bolted on beside the budget.
##
## ## What this is not, yet
##
## Section 4 describes a unified composable effect base -- melee, projectile,
## spell and action sharing one class, customised by damage, hitbox shape,
## movement, sprite and animation. That is a larger thing and it is not here.
## What is here is the part the power budget needs: an effect is a name and a
## cost, and the cost is real. When the composable base arrives it gains the
## shape and the behaviour; the magnitude is already the number that says how
## much of the item was spent to get them.
##
## The name is a mechanic, never a piece of art. "flame" is what it does; which
## model, colour or animation says so is the render layer's table to answer, and
## this layer does not know one exists.
class_name ItemEffect

## What the effect does, in one word.
var effect_name: String = ""

## How many points of the item's effects budget bought it.
var magnitude: int = 0


static func make(called: String, worth: int) -> ItemEffect:
	var effect := ItemEffect.new()
	effect.effect_name = called
	effect.magnitude = maxi(0, worth)
	return effect


## One line, in the form reports and tests compare.
func line() -> String:
	return "%s:%d" % [effect_name, magnitude]
