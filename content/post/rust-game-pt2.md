+++
subtitle = "Let's Get Some Sound"
title = "Making A Game in Rust: Part 2"
date = "2022-12-19T12:54:24+02:00"
draft = false
series = ["Making A Game in Rust"]
tags = ["rust", "game", "sound"]
+++

[Source code for this part](https://github.com/nprice1/rust-roguelike-tutorial/tree/main/part-02-sound)

Now that my nitpicks have been addressed, we can start adding actual functionality. The first thing 
this game desperately needs is some sound. I want a catchy background tune for the entire game, as 
well as some sound effects to really make our ASCII action more dynamic. To start, we will add a 
simple background tune on repeat. 

# Background Music

I decided to try the [rodio](https://docs.rs/rodio/latest/rodio/) library for my music playing needs
since it looked very straight forward. In order to include this dependency we need to update our 
`Cargo.toml` file:

```toml
[dependencies]
bracket-lib = { version = "~0.8", features = ["serde", "specs"] }
specs = { version = "0.18", features = ["serde"] }
specs-derive = "0.4.1"
serde= { version = "^1.0.44", features = ["derive"] }
serde_json = "^1.0.44"
lazy_static = "1.4.0"
regex = "1.3.6"
rodio = "0.16.0"
```

We also need to grab some royalty free music, I decided to go
with [this one](https://opengameart.org/content/core-descent-8-bit) since it got instantly stuck
in my head and is just all around awesome. This song is available in the `resources` folder in the
source code, added as `sounds/background.mp3`.

We have our tunes, so lets start a simple thread to play it. In our `main.rs` we can add 
some imports to ensure we can use the new dependency:

```rust
use std::fs::File;
use std::io::BufReader;
use rodio::{Decoder, OutputStream, source::Source};
```

And we can load up the background music in our `main()` function before calling into `rltk.main_loop`:

```rust
// Get a output stream handle to the default physical sound device
let (_stream, stream_handle) = OutputStream::try_default().unwrap();
// Load a sound from a file, using a path relative to Cargo.toml
let file = BufReader::new(File::open("resources/sounds/background.mp3").unwrap());
// Decode that sound file into a source
let source = Decoder::new(file).unwrap();
// Play the sound directly on the device
stream_handle.play_raw(source.convert_samples()).expect("Failed to play background music");

rltk::main_loop(context, gs)
```

Just like the docs say, all we are doing is grabbing an output stream for the device, loading our
background music, and playing it. Make sure that the file path used is relative to `Cargo.toml`, 
NOT to your `main.rs` file! Now we have some sweet sweet tunes to accompany us on our journey. 
However, if you sit and wait for the entire background track to finish you will notice a problem:
it ends. We need to repeat forever and eternity. So let's use the `Sink` abstraction instead so
we have some more control over our track. To make sure we are actually repeating, I'll use only
the first second of the background track:

```rust
// Get a output stream handle to the default physical sound device
let (_stream, stream_handle) = OutputStream::try_default().unwrap();
let sink = Sink::try_new(&stream_handle).unwrap();
// Load a sound from a file, using a path relative to Cargo.toml
let file = BufReader::new(File::open("resources/sounds/background.mp3").unwrap());
// Decode that sound file into a source
let source = Decoder::new(file).unwrap().take_duration(std::time::Duration::from_secs_f32(1.0));
// Add the track to the sink to be played
sink.append(source);

rltk::main_loop(context, gs)
```

Now if we run the game we get the first second of the background track. Now how do we loop it?
Turns out we just need to tweak the source a bit:

```rust
// Decode that sound file into a source and repeat infinitely
let source = Decoder::new(file).unwrap().take_duration(std::time::Duration::from_secs_f32(1.0)).repeat_infinite();
```

Cool, now we have an infinite loop for our background music. What happens when we want spells to
make sounds, or a visceral chomp from our bear trap, or fully voice acted quips? Sounds like we
are going to need a new system for our sound effects.

# Sound System

We have done an awful lot of systems so far, so it shouldn't be a surprise that we will be adding
yet another one to handle our sounds. This will be one of our special "other" systems, not an ECS 
system that we need to run with Specs. Instead, we will just make a dumb little struct we can pass
around and anybody can use it to play a sound effect. To start, lets make a new `sound_system.rs`
file in our `systems/` folder and get started with just the background music. Since we want our
background music to start playing right when the game loads, it seems fair to just make the `new`
method for our struct initialize the `rodio::Sink` we will be using to interact with the background
music:

```rust
use std::{fs::File};
use std::io::{BufReader};
use rodio::{Decoder, source::Source, Sink, OutputStreamHandle};

pub struct SoundSystem {
    background_sink: Sink,
}

impl SoundSystem {

    pub fn new(stream_handle: &OutputStreamHandle) -> SoundSystem {
        let background_sink = Sink::try_new(stream_handle).unwrap();
        let effects_sink = Sink::try_new(stream_handle).unwrap();
        let file = BufReader::new(File::open("resources/sounds/background.mp3").unwrap());
        let source = Decoder::new(file).unwrap().repeat_infinite();
        background_sink.append(source);
        return SoundSystem {
            background_sink,
        }
    }

}
```

Over in `systems/mod.rs` we need to add a new import statement to expose the `SoundSystem` struct for
use:

```rust
mod lighting_system;
use lighting_system::LightingSystem;
pub mod sound_system;
```

Then we can actually make one of these things and register it in Specs so our other systems can 
use it over in `main.rs` (after removing our old code that started the music):

```rust
gs.ecs.insert(rex_assets::RexAssets::new());

let (_stream, stream_handle) = OutputStream::try_default().unwrap();
let sound_system = systems::sound_system::SoundSystem::new(&stream_handle);
gs.ecs.insert(sound_system);

gs.generate_world_map(1, 0);
```

If you run it now you will get our awesome backtround track playing just like it was before. Note
that we needed to initialize the stream handle in our `main` function.

## Sound Effects

We have our background music which is awesome, but we want the ability to also play sound effects
for various occurrences in our game. The one that immediately jumps out in my brain is the bear 
trap, we should have some kind of sound effect letting us know we did a bad. To allow for sound
effects we need to create another `rodio::Sink` with its own sound queue. That way sound effects
can play over our background music rather than needing to manage pausing/playing our background
music. In our `system/sound_system.rs` file we need to make a few changes to our `SoundSystem` 
struct:

```rust
pub struct SoundSystem {
    background_sink: Sink,
    effects_sink: Sink,
}

impl SoundSystem {

    pub fn new(stream_handle: &OutputStreamHandle) -> SoundSystem {
        let background_sink = Sink::try_new(stream_handle).unwrap();
        let effects_sink = Sink::try_new(stream_handle).unwrap();
        let file = BufReader::new(File::open("resources/sounds/background.mp3").unwrap());
        let source = Decoder::new(file).unwrap().repeat_infinite();
        background_sink.append(source);
        return SoundSystem {
            background_sink,
            effects_sink,
        }
    }

    pub fn play_sound_effects(&self, file_names: Vec<String>) {
        for (file_name) in file_names {
            let file_path = format!("resources/sounds/{}", file_name);
            let file = BufReader::new(File::open(file_path).unwrap());
            let source = Decoder::new(file).unwrap();
            self.effects_sink.append(source);
        }
    }

}
```

The `play_sound_effects` function is pretty straight forward. For every filename passed into it, it
will load the file (assuming the `resources/sound/` directory to make defining sound effect files
easier), and add that to our special sound effects Sink. Each sound will play in order. 

We want each of our effects in `spawns.json` to be able to define which sounds (if any) it will
trigger with the event. Our `spawns.json` file doesn't actually directly lead to events, it leads
to components being added to our entities that then trigger events in our systems. So we will 
follow the existing pattern and make a new component we can add when a sound should be played. 
In `components.rs` add a new component:

```rust
#[derive(Component, Debug, Serialize, Deserialize, Clone)]
pub struct Sounds {
    pub file_names: Vec<String>,
}
```

Then make sure to add it to our macro in the same file. Isn't it nice not to have to add it to
`main.rs` and `saveload_system.rs`?

We need to provide the new component to our entities when a sound effect should be played. 
Over in `raws/rawmaster.rs` we can extend our `apply_effects` macro to check for sounds as well
(we will reuse the `;` separated tokens like we have been doing for particles):

```rust
fn parse_sounds(n: &str) -> Sounds {
    Sounds {
        file_names: n.split(';')
            .map(|name| String::from(name))
            .collect(),
    }
}

macro_rules! apply_effects {
    ( $effects:expr, $eb:expr ) => {
        for effect in $effects.iter() {
            let effect_name = effect.0.as_str();
            match effect_name {
                //... other effects
                "sounds" => $eb = $eb.with(parse_sounds(&effect.1)),
                _ => rltk::console::log(format!(
                    "Warning: consumable effect {} not implemented.",
                    effect_name
                )),
            }
        }
    };
}
```

We can now add a new entry into the `effects` map for anything in `spawns.json` to include sound
effects that should be played. 

## Playing the Sounds

We have a basic framework in place for defining sounds that should be played, but they never
actually get played at all. For simplicity I want to try and make the sound effect playing very
generic, so that any time an effect triggers for something with sounds defined for it we will play
a sound. I'm not sure if this will lead to a horrific cacophony of sounds yet, but let's try it out.
To start with we will just add some effects for things that trigger effects, like items and traps.
That covers most of the use cases so it is a good place to start. Over in `effects/triggers.rs` we
need to modify the `event_trigger` to also play sounds if we actually did something:

```rust
#[allow(clippy::cognitive_complexity)]
fn event_trigger(
    creator: Option<Entity>,
    entity: Entity,
    targets: &Targets,
    ecs: &mut World,
) -> bool {
    // ... the rest of the event trigger function

    // Damage Over Time
    if let Some(damage) = ecs.read_storage::<DamageOverTime>().get(entity) {
        add_effect(
            creator,
            EffectType::DamageOverTime {
                damage: damage.damage,
            },
            targets.clone(),
        );
        did_something = true;
    }

    // Play sounds if available
    if did_something {
        if let Some(sounds) = ecs.read_storage::<Sounds>().get(entity) {
            ecs.read_resource::<SoundSystem>().play_sound_effects(sounds.file_names.clone());
        }
    }

    did_something
}
```

## Getting Sound Effects

In order to actually test this stuff out we need actual sound effects. I once again utilized the
awesome https://opengameart.org/ resource and found 
[this set of 512 sound effects](https://opengameart.org/content/512-sound-effects-8-bit-style). 
I wanted to test this out with our Bear Trap, and I thought the 
`General Sounds/Impacts/sfx_sounds_impact6.wav` sounded trap-like. I added that sound to our
`resources` folder as `resources/sounds/trap.wav`. Then over in `spawns.json` I can update our
`Bear Trap` entry to include a sound to be played (remember our sound system doesn't need the full
path to the sound):

```json
{
    "name" : "Bear Trap",
    "renderable": {
        "glyph" : "^",
        "fg" : "#FF0000",
        "bg" : "#000000",
        "order" : 2
    },
    "hidden" : true,
    "entry_trigger" : {
        "effects" : {
            "damage" : "6",
            "single_activation" : "1",
            "sounds": "trap.wav"
        }
    }
},
```

That's it! If you run the game you will get a satisfying thunk sound when the trap triggers. I want
to test out sound effects for magic as well, but I don't want to have to manually edit the code to
give my player starting spells for me to test out. Instead, I want better cheating! I want to add a
new option to the cheat menu to allow learning all spells at once which will probably do something 
horrible to the spell list when we go over the expected number but whatever let's try it out. Over
in `gui/cheat_menu.rs` you will find that we didn't update this file when all that GUI code got
refactored. In fact, if you try using the cheat menu it will render behind some map tiles because
we never used the `draw_batch` system to overlay it properly. We will update this menu to the new
hotness while also adding a new result for learning all the spells:

```rust
use super::menu_option;

#[derive(PartialEq, Copy, Clone)]
pub enum CheatMenuResult {
    NoResponse,
    Cancel,
    TeleportToExit,
    Heal,
    Reveal,
    GodMode,
    LearnSpells,
}

pub fn show_cheat_mode(_gs: &mut State, ctx: &mut rltk::BTerm) -> CheatMenuResult {
    let mut draw_batch = rltk::DrawBatch::new();
    let count = 5;
    let mut y = (25 - (count / 2)) as i32;
    draw_batch.draw_box(
        rltk::Rect::with_size(15, y - 2, 31, (count + 3) as i32),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHITE), rltk::RGB::named(rltk::BLACK)),
    );
    draw_batch.print_color(
        rltk::Point::new(18, y - 2),
        "Cheating!",
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );
    draw_batch.print_color(
        rltk::Point::new(18, y + count as i32 + 1),
        "ESCAPE to cancel",
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );

    menu_option(&mut draw_batch, 17, y, rltk::to_cp437('T'), "Teleport to next level");

    y += 1;
    menu_option(&mut draw_batch, 17, y, rltk::to_cp437('H'), "Heal all wounds");

    y += 1;
    menu_option(&mut draw_batch, 17, y, rltk::to_cp437('R'), "Reveal the map");

    y += 1;
    menu_option(&mut draw_batch, 17, y, rltk::to_cp437('G'), "God Mode (No Death)");

    y += 1;
    menu_option(&mut draw_batch, 17, y, rltk::to_cp437('S'), "Learn all spells");
    
    draw_batch.submit(6000).expect("Failed to submit cheat menu draw batch");

    match ctx.key {
        None => CheatMenuResult::NoResponse,
        Some(key) => match key {
            rltk::VirtualKeyCode::T => CheatMenuResult::TeleportToExit,
            rltk::VirtualKeyCode::H => CheatMenuResult::Heal,
            rltk::VirtualKeyCode::R => CheatMenuResult::Reveal,
            rltk::VirtualKeyCode::G => CheatMenuResult::GodMode,
            rltk::VirtualKeyCode::S => CheatMenuResult::LearnSpells,
            rltk::VirtualKeyCode::Escape => CheatMenuResult::Cancel,
            _ => CheatMenuResult::NoResponse,
        },
    }
}
```

Over in `main.rs` we need to implement the logic for this new result. All we need to do is iterate
through all possible spells and add it to the player's `KnownSpells` component:

```rust
gui::CheatMenuResult::GodMode => {
                        let player = self.ecs.fetch::<Entity>();
    let mut pools = self.ecs.write_storage::<Pools>();
    let mut player_pools = pools.get_mut(*player).unwrap();
    player_pools.god_mode = true;
    newrunstate = RunState::AwaitingInput;
}
gui::CheatMenuResult::LearnSpells => {
    let player = self.ecs.fetch::<Entity>();
    let spells = self.ecs.read_storage::<SpellTemplate>();
    let names = self.ecs.read_storage::<Name>();
    let mut known_spells = self.ecs.write_storage::<KnownSpells>();
    let entities = self.ecs.entities();

    let mut updated_spells = Vec::new();
    for (_entity, name, template) in (&entities, &names, &spells).join() {
        updated_spells.push(KnownSpell {
            display_name: name.name.clone(),
            mana_cost: template.mana_cost,
        });
    }
    known_spells.insert(*player, KnownSpells {
        spells: updated_spells,
    }).expect("Unable to insert spells");

    newrunstate = RunState::AwaitingInput;
}
```

Now that we have a nice shortcut, let's add some sound effects to spells and see if they work 
properly. For our `Zap` spell I chose the `Explosions/Shortest/sfx_exp_shortest_hard2.wav` sound
from our 512 pack and added it to our resources as `zap.wav`. Then over in `spawns.json` I will
update the `Zap` spell with the new sound:

```json
{
    "name" : "Zap",
    "mana_cost" : 1,
    "effects" : {
        "ranged" : "6",
        "damage" : "5",
        "particle_line" : "▓;#00FFFF;400.0",
        "sounds": "zap.wav"
    }
},
```

When you run the game and use our handy little shortcut for learning all the spells, you can zap
something with a satisfying sound effect! There is just one more thing I want to make sounds: combat.
I think it would be really nice to get some actual feedback when a character takes damage.

## Non Trigger Sound Effects

I want a very short simple damage sound since most likely combatants will be hammering away at each
other. I think a good one is the `General Sounds/Simple Damage Sounds/sfx_damage_hit4.wav` effect
in the sound effect pack. I moved that into our resources and named it `hit.wav`. Then over in
`effects/damage.rs` we modify the `inflict_damage` function to play the sound effect before dishing
 out the damage:

```rust
if let EffectType::Damage { amount } = damage.effect_type {
    ecs.read_resource::<SoundSystem>().play_sound_effects(vec![String::from("hit.wav")]);
    pool.hit_points.current -= amount;
    add_effect(None, EffectType::Bloodstain, Targets::Single { target });
    // ... the rest of the damage dealing logic
}
```

If you run the game now, you get some satisfying thuds whenever damage is inflicted.

I went ahead and added some more sound effects to various things in `spawns.json` to give a bit
more life to the actions you take on your adventure, see the source code to replicate them all.
However, pure roguelike games don't use sounds, so we may have some push back on our game for 
using them. The next post will be about making an options menu to optionally turn off or turn 
down the new sound effects we added.
