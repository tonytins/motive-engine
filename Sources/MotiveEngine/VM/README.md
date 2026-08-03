# Basil VM

The Basil (BASIC-like Application Scripting for Item Logic) is a planned virtual machine intended to develop more complex objects that go beyond what any fixed motives can do. The VM uses JSON as a intermediate representation with a schema inspired by WebAssembly. 

## Scripting

Basil's scripting language was inspired by BASIC and features elements from Second Life's LSL.

Characters in the simulation are always searching for something to do, by default they have a bias towards ``fun`` and ``social``. Objects provides that clue through functions the user can overwrite.

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
