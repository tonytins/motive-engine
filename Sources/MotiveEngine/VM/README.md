# Basil VM

The Basil (BASIC Application Scripting for Item Logic) is a virtual machine currently in developed. The VM allows for more complex objects that go beyond what any fixed motives can do. The VM uses JSON as an intermediate representation (IR) with a schema inspired by WebAssembly. 

<!---
## 🏗️  Architecture

-->
## 🚦 Dispatching

Characters have a radar that allows them to "see" the room and items emit a signal what needs they offer a character. Characters themselves also emit signals for socializing and buffs. Items broadcast what they offer to characters. If their need is low enough that overwrites their normal bias for fun and social, it will go and full fill those needs.

## ⌨️ Scripting

Basil's scripting language was inspired by BASIC and Second Life's LSL.

Characters in the simulation are always searching for something to do, by default they have a bias towards ``fun`` and ``social``. Objects provides that clue through functions the developer can overwrite.

```vb
state default
	func ambient()
		mut val level = 5
		emit Fun, level 
	end
end

```

The keyword ``emit`` is part of engine's broadcasting architecture. It's similar to Godot's ``signal``. The ``ambient()`` function, however, is a buff that doesn't broadcast to character's radar, per-se, instead it just skips straight to full filling needs or providing any other buffs. This is useful if you have a rare gem, for example, that makes your character happy.

Similar to LSL, a function can skip to a new state and back again.

```vb
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

## 💾 Compiling

Compiling is very straight forward (even at an internal level) as it just encodes and decodes the script to and from JSON. The most complex part is the lexing. 

## 🤔 FAQ

### Why JSON, Though?

Because an intermediate representation (IR) is *technically* different from an intermediate language (IL). JSON is provided for free and I'm just one person who can't be bothered to write an IL from scratch if I don't have to.