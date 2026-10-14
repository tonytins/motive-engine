# Motive Engine Documentation

I am designing the Motive Engine as an *extremely* modular framework around the idea of being easily unit testable and render-agnostic as possible. All the engine ever does is pass information back downstream to the frontend.

The core is needs-driven: Sims have motives that decay, and with free will they choose interactions that best satisfy their most urgent needs. Around that core sit independent pieces, each usable or skippable on its own:

- **Buffs** are passive effects on motives, such as ambient items or a temporary mood. They live in the core but do nothing unless a game adds rules or timed buffs.
- **Robusta** is an LSL-inspired scripting language. Item interaction scripts read a Sim's state through a typed boundary, and the simulation session runs them when an action starts to decide its motive effects.
- **Content packs** carry base content, expansions, and mods in one format: a manifest, item definitions, and scripts. Packs declare dependencies, and their IDs are namespaced so mods can only replace content they deliberately override.
- **Wants and fears (SWAF)** ship as a separate, optional `MotiveEngineSWAF` product. It supports The Sims 2-style wants and fears and The Sims 3-style wishes, and only observes the simulation, so a Sims 1-style game can leave it out entirely.

In theory, it should be possible run this from the terminal using nothing but an ASCII interface and emojis.

## Start here

- [Roadmap](./ROADMAP.md) — the alpha gate, milestones, estimates, and
  what comes next.
- [Architecture overview](./architecture.md) — current foundations and
  the proposed data-oriented direction.
- [Modding guide](./modding.md) — building content packs: manifests,
  items, scripts, and overrides.
- [Contributor guide](./contributing.md) — build, test, and contribution
  expectations.
- [Engineering scorecard](./scorecard.md) — performance budgets and verified
  status for every area, with the tests that prove it.

## Documentation roadmap

As the engine becomes more realized, this directory can grow to include:

- a getting-started guide for adding the package to a game;
- configuring motives and autonomy policies;
- integrating optional buffs and aspirations;
- running simulations, inspecting events, and testing game content.

Authoring items, interactions, and scripted behavior is covered by the
[modding guide](./modding.md).

These guides should document supported, implemented behavior. Proposed
features should be labeled as such rather than presented as usable APIs.

## Source and API references

Use the source code and its comments for precise API details. This guide
is the higher-level explanation of concepts, boundaries, and intended
usage. Public documentation should stay aligned with the implementation
as these APIs evolve.
