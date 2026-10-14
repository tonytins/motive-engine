# Modding Guide

Motive Engine loads all content through content packs. The base game, its
expansions, and your mods use the same format, so anything the base game can
define, a mod can define too.

This guide covers what you can build today: items, their interactions, and
Robusta scripts that decide what an interaction does. Features that are
planned but not finished are listed at the end.

## Your first pack

A pack is a folder. Only the manifest is required.

```text
kitchen-plus/
  pack.json          the manifest
  items.json         item definitions (optional)
  scripts/
    feast.rob        Robusta scripts used by interactions
```

While you work on a mod, keep it unpacked. The engine reads the folder
directly, so you can edit a file and reload without repackaging. A packed
format for distribution is planned.

## The manifest: `pack.json`

```json
{
  "id": "kitchen-plus",
  "name": "Kitchen Plus",
  "version": "1.2",
  "format": 1,
  "dependencies": ["base"],
  "overrides": ["base:fridge"]
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | Yes | Your pack's identifier. It prefixes every item you define, so it can't contain `:` or spaces. Pick something unlikely to clash with other mods. |
| `name` | Yes | The name players see. |
| `version` | Yes | Your mod's own version, shown to players. The engine never compares it. |
| `format` | Yes | The pack format you wrote. This engine reads format `1`; it refuses packs written in a format it doesn't know. |
| `dependencies` | No | Packs that must load before yours. List every pack whose items you use or replace. |
| `overrides` | No | Items from other packs that you replace. See [Replacing another pack's items](#replacing-another-packs-items). |

The full schema is [`schema/pack.json`](../schema/pack.json).

## Items: `items.json`

```json
{
  "items": [
    {
      "id": "radio",
      "name": "Kitchen Radio",
      "modifiers": ["ambient", "recreation"],
      "signals": { "fun": 0.25 },
      "interactions": [
        {
          "id": "listen",
          "name": "Listen",
          "duration": 30,
          "advertises": { "fun": 1.5 },
          "effects": { "fun": 1.5 }
        }
      ]
    }
  ]
}
```

### Item fields

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | Yes | The item's ID within your pack. `radio` in pack `kitchen-plus` becomes `kitchen-plus:radio`. |
| `name` | Yes | The name players see. |
| `modifiers` | Yes | What kind of item it is. Use an empty list for none. See below. |
| `blocking` | No | Whether Sims can walk through it. Leave it out to use the modifiers' default. |
| `capacity` | No | How many Sims can use it at once. Defaults to `1`. |
| `signals` | No | Passive effects on nearby Sims, per second, for `ambient` items. These apply only when the game turns on ambient buffs. |
| `interactions` | No | What Sims can do with the item. |

The modifiers are `appliance`, `bed`, `shower`, `toilet`, `recreation`,
`chair`, `skill`, `ambient`, and `sim`. Items block movement by default if
any modifier except `ambient` or `sim` is present.

### Interaction fields

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | Yes | Unique within the item. |
| `name` | Yes | The action name players see, such as "Have a Snack". |
| `duration` | Yes | How long the interaction lasts, in simulated seconds. Must be more than zero. |
| `advertises` | No | What the interaction promises. Free will uses this to decide what a Sim wants to do. |
| `effects` | No | What actually happens to the Sim's motives while it runs. Ignored when `script` is set. |
| `posture` | No | `standing` or `sitting`, if the Sim must be in that posture to start. |
| `script` | No | A script in your `scripts` folder, without the `.rob` extension. |

### Motives

Motive values are rates per second. The motives are `hunger`, `energy`,
`hygiene`, `bladder`, `social`, and `fun`. Each motive ranges from 0 to 100,
where lower means the Sim needs it more. Positive rates fill a motive and
negative rates drain it.

`advertises` and `effects` are separate on purpose. An item can advertise
more than it delivers, like a fancy fridge whose food is disappointing, and
free will still falls for it.

The full schema is [`schema/pack-items.json`](../schema/pack-items.json).

## Scripts

A script decides an interaction's effects when a Sim starts it. Scripts are
written in Robusta and live in your pack's `scripts` folder.

```robusta
// scripts/feast.rob
state default
    func stateEntry()
        if sim.hunger < 30
            effect.fulfill("hunger", 4)
            effect.fulfill("fun", 0.5)
        else
            effect.fulfill("hunger", 2)
        end
    end
end
```

Every script needs a `default` state with a `stateEntry()` function. The
engine runs it once, when a Sim starts the interaction. The effects it
reports stay the same until the interaction ends.

### What a script can read

| Value | Type |
| --- | --- |
| `sim.id` | text |
| `sim.posture` | `"standing"` or `"sitting"` |
| `sim.hunger`, `sim.energy`, `sim.hygiene`, `sim.bladder`, `sim.social`, `sim.fun` | number, 0 to 100 |
| `item.id` | the placed item's ID |
| `item.definition` | the item's full ID, such as `kitchen-plus:radio` |
| `interaction.id`, `interaction.name` | text |
| `interaction.duration` | number, in seconds |

These values are read-only.

### What a script can do

Call `effect.fulfill(motive, ratePerSecond)` once for each effect. A script
with no `effect.fulfill` calls makes the interaction do nothing. When an
interaction has a script, the script's effects replace that interaction's
`effects` entirely.

Scripts can't change anything else in the game directly, and `print` output
is not shown during play.

For the full language, see the
[Robusta reference](../Sources/MotiveEngine/VM/README.md).

### Limits

A script stops with an error if it runs more than 100,000 instructions or
nests function calls more than 256 deep. Keep scripts short; they run every
time a Sim starts the interaction.

## Replacing another pack's items

To replace an item, write its full ID, including the other pack's prefix,
and list it in your manifest. In `pack.json`:

```json
{
  "id": "kitchen-plus",
  "name": "Kitchen Plus",
  "version": "1.2",
  "format": 1,
  "dependencies": ["base"],
  "overrides": ["base:fridge"]
}
```

In `items.json`:

```json
{ "items": [ { "id": "base:fridge", "name": "Deluxe Fridge", "modifiers": ["appliance"] } ] }
```

The rules:

- You must list the item in `overrides`. An item with another pack's prefix
  that isn't listed is an error, so you can't replace something by accident.
- The other pack must be one of your dependencies, directly or through
  another dependency.
- Every item you list in `overrides` must exist in that pack, and you must
  define it in your `items.json`.
- Your replacement takes over the whole item, including its interactions.
  Copy anything you want to keep.

When two mods replace the same item, the one that loads later wins. The game
can show players which mods conflict.

## Load order

The game or player decides the order packs load in. The engine changes it
only to make sure each pack loads after its dependencies. A missing
dependency, or two packs that depend on each other, stops the packs from
loading.

## When something is wrong

The engine checks your pack when it loads, before any Sim touches your
items. These problems are reported with the file they came from:

- a missing or malformed `pack.json` or `items.json`;
- an unknown motive name or modifier;
- a script that is missing, isn't UTF-8 text, or doesn't compile;
- an `effect.fulfill` call with a written-out motive name that doesn't
  exist, a non-number strength, or the wrong number of arguments.

Some problems only show up while the game runs, such as a script that throws
an error or computes an invalid effect. When that happens, only that one
interaction fails for that Sim, and the game is told why. If free will chose
the interaction, the Sim picks the next best thing instead, so a broken
script can't stop the simulation.

If a script keeps failing, the engine escalates step by step:

1. After a failure, free will leaves the interaction alone for a while, then
   tries again. One success resets the count.
2. After several failures in a row, your script is switched off. If the
   interaction has `effects`, it keeps working with those, so writing
   sensible `effects` alongside a script is a good safety net.
3. If it has no `effects`, the interaction is switched off.
4. If several interactions in your pack break this way, the whole pack is
   switched off, along with any packs that depend on it. Your items stay
   where players placed them but can't be used.

Switched-off content stays off, even after the game is saved and reloaded,
until the player turns it back on. Fix the problem and ask players to
re-enable your mod.

Packs can only read files inside their own folder. Paths that leave the
folder, including through symbolic links, are rejected.

## For game developers

Load each pack, then combine them in your chosen order:

```swift
let packs = try packFolders.map { folder in
    try ContentPack(loadingFrom: DirectoryContentSource(directory: folder))
}
let composition = try ContentComposer.compose(packs)

// Tell players which mods replace the same item. The last one listed wins.
for conflict in composition.conflicts {
    print("\(conflict.packIDs.map(\.rawValue)) all replace \(conflict.definitionID.rawValue)")
}

var session = try SimulationSession(
    state: worldState,
    itemCatalog: composition.catalog,
    motiveDecayRates: decayRates
)
```

Loading errors are `ContentPackError` values. `invalidFile` includes the
path of the file at fault, which is usually what a mod author needs to see.
To read packs from somewhere other than a folder, such as your own archive
format, conform a type to `ContentSource`. Extensions can read their own
files from a loaded pack through `pack.source`.

## Not available yet

These are planned in the [roadmap](./ROADMAP.md):

- a packed format for distributing mods;
- wants and fears in packs;
- source line numbers in script runtime errors.
