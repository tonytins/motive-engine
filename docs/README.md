# Motive Engine Documentation

I am designing the Motive Engine as an *extremely* modular framework around the idea of being easily unit testable and render-agnostic as possible. All the engine ever does is pass information back downstream to the frontend.

The engine is made up of two independent subsystems: Needs and Buffs. Only the Sim is aware of any of these. If freewill turned on, they will always search for something to do. 

- Buffs is a plugin system for a classic aspiration system to build upon. 
- An LSL-inspired scripting engine and language is included but not yet tied in.

In theory, it should be possible run this from the terminal using nothing but an ASCII interface and emojis.

## Start here

- [Roadmap](./ROADMAP.md) — completed foundations and planned milestones.
- [Architecture overview](./architecture.md) — current foundations and
  the proposed data-oriented direction.
- [Contributor guide](./contributing.md) — build, test, and contribution
  expectations.
- [Engineering scorecard](./scorecard.md) — advisory performance budgets
  and regression-corpus floors.

## Documentation roadmap

As the engine becomes more realized, this directory can grow to include:

- a getting-started guide for adding the package to a game;
- authoring item definitions and interactions;
- configuring motives and autonomy policies;
- integrating optional buffs and aspirations;
- writing scripted item behavior;
- running simulations, inspecting events, and testing game content.

These guides should document supported, implemented behavior. Proposed
features should be labeled as such rather than presented as usable APIs.

## Source and API references

Use the source code and its comments for precise API details. This guide
is the higher-level explanation of concepts, boundaries, and intended
usage. Public documentation should stay aligned with the implementation
as these APIs evolve.
