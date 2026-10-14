# Motive Engine Documentation

Motive Engine is a Swift library for building render-agnostic, Sims-style
life simulation AI. It is intended as a set of reusable simulation
building blocks; the game using it owns presentation and player-facing
gameplay.

## Start here

- [Architecture overview](./architecture.md) — current foundations and
  the proposed data-oriented direction.

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
