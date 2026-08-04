# 📐 Design

I am designing this as an *extremely* modular framework around the idea of being easily unit testable and render-agnostic as possible. All the engine ever does is pass information back downstream to the frontend.

The Motives Engine is made up of three independent subsystems: Needs, Buffs and Aspirations. Only the Sim is aware of any of these. If freewill turned on, they will always search for something to do. 

In theory, it should be possible run this from the terminal using nothing but an ASCII interface and emojis to represent varies items and characters.

## Sim

A Sim "sees" their world through a radar system that occasionally pings their surroundings. Internally, this is known ``Broadcaster``. Every item in the world sends back what their offer and the Sim narrows in what matters most (whatever is below a certain threshold). Generally speaking, a Sim favours social and fun even if those motives are already maxed.

Items can statically full fill needs or a virtual machine (VM) built on top of the broadcasting architecture allows scripting based around varies states. Although dependent on the above architecture, the VM itself is just as independent as everything else. Modifying it will no doubt affect every script dependent on it but not the engine as a whole.

Unfortunately, the Aspirations (Wants/Fears) remains a bit of loose thread at this point.

## Objects

Objects, known as an ``Item`` to avoid naming conflicts with Swift, is where most of the magic happens. The item carries all the logic needed to interact with it. This either can be up to the client to decide or scripted in. You're likely going to be using a bit both.