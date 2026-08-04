# Basil VM

The Basil (BASIC Application Scripting for Item Logic) is a planned virtual machine intended to develop more complex objects that go beyond what any fixed motives can do. The VM uses JSON as an intermediate representation (IR) with a schema inspired by WebAssembly. 

## 🚦 Dispatching

Characters have a radar that allows them to "see" the room and items emit a signal what needs they offer a character. Characters themselves also emit signals for socializing and buffs.[^1] Items broadcast what they offer to characters. If their need is low enough that overwrites their normal bias for fun and social, it will go and full fill those needs.

## ⌨️ Scripting

Basil's scripting language was inspired by BASIC and features elements from Second Life's LSL.

Characters in the simulation are always searching for something to do, by default they have a bias towards ``fun`` and ``social``. Objects provides that clue through functions the developer can overwrite.

```
state default
	func ambient()
		mut val level = 5
		emit Fun, level 
	end
end

```

The keyword ``emit`` is part of engine's broadcasting architecture. It's similar to Godot's ``signal``. The ``ambient()`` function, however, is a buff that doesn't broadcast to character's radar, per-se, instead it just skips straight to full filling needs or providing any other buffs. This is useful if you have a rare gem, for example, that makes your character happy.

Similar to LSL, a function can skip to a new state and back again.

```
state default
	func touch()
		state off
	end
end

state off
	func touch()
		state default
	end
end

```

## 🤔 FAQ

### Why JSON, Though?

Because an intermediate representation (IR) is *technically* different from an intermediate language (IL). JSON is provided for free and I'm just one person who can't be bothered to write an IL from scratch if I don't have to.

[^1]: One thing I'm still trying to figure out are phones and similar objects. Obviously, they provide all the same benefits as characters when they're not around. Maxis solved by having Sims as objects (it's what makes all the magic stuff) but I also wanted to separate them and put them on their own Household layer. I dunno. Bit of a catch-22.