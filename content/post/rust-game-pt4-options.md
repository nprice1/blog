+++
subtitle = "Options Menu"
title = "Making A Game in Rust: Part 4"
date = "2022-12-31T12:54:24+02:00"
draft = false
series = ["Making A Game in Rust"]
tags = ["rust", "game"]
+++

[Source code for this part.](https://github.com/nprice1/rust-roguelike-tutorial/tree/main/part-04-options)

Roguelike purists would say there should be no sound in a roguelike game, so we should provide that
option. Our `SoundSystem` has access to both the background and sound effects where we can set the
volume to be whatever the user likes, including setting it to 0. While we are there, we can also add
some other helpful options to the menu like toggling the FPS tracker and the cheat menu. Our goal for
this part will be to provide a menu like this:

![options menu](/img/options-menu.gif)

# Options Menu Item

In order to show the options menu we need to actually include that as a possible selection on the 
main menu. To do that, we head over to `gui/main_menu.rs` to add the new option. Looking at this 
code it immediately annoyed me to have so many repetitive blocks for adding a menu item, so I decided
to make a little helper function to render new menu items:

```rust
fn print_menu_option(draw_batch: &mut rltk::DrawBatch, y: i32, is_selected: bool, title: &str) {
    if is_selected {
        draw_batch.print_color_centered(
            y,
            title,
            rltk::ColorPair::new(
                rltk::RGB::named(rltk::MAGENTA),
                rltk::RGB::named(rltk::BLACK),
            ),
        );
    } else {
        draw_batch.print_color_centered(
            y,
            title,
            rltk::ColorPair::new(rltk::RGB::named(rltk::WHITE), rltk::RGB::named(rltk::BLACK)),
        );
    }
}
```

We also need to add a new `MainMenuSelection` for the new `Options` menu item we will be adding:

```rust
pub enum MainMenuSelection {
    NewGame,
    LoadGame,
    Options,
    Quit,
}
```

The main chunk of our main menu rendering chunk can now be simplified to this:

```rust
pub fn main_menu(gs: &mut State, ctx: &mut rltk::BTerm) -> MainMenuResult {
    // ... setup

    let mut y = 24;
    if let RunState::MainMenu {
        menu_selection: selection,
    } = *runstate
    {
        print_menu_option(&mut draw_batch, y, selection == MainMenuSelection::NewGame, "Begin New Game");
        y += 1;

        if save_exists {
            print_menu_option(&mut draw_batch, y, selection == MainMenuSelection::LoadGame, "Load Game");
            y += 1;
        }

        print_menu_option(&mut draw_batch, y, selection == MainMenuSelection::Options, "Options");
        y += 1;

        print_menu_option(&mut draw_batch, y, selection == MainMenuSelection::Quit, "Quit");

        draw_batch.submit(6000).expect("Failed to submit");

        // ... key checking code
    }
}
```

Looks much nicer. We also need to update what happens when the user hits the up and down keys since
we have a new menu option:

```rust
match ctx.key {
    None => {
        return MainMenuResult::NoSelection {
            selected: selection,
        }
    }
    Some(key) => match key {
        rltk::VirtualKeyCode::Escape => {
            return MainMenuResult::NoSelection {
                selected: MainMenuSelection::Quit,
            }
        }
        rltk::VirtualKeyCode::Up => {
            let mut newselection;
            match selection {
                MainMenuSelection::NewGame => newselection = MainMenuSelection::Quit,
                MainMenuSelection::LoadGame => newselection = MainMenuSelection::NewGame,
                MainMenuSelection::Options => newselection = MainMenuSelection::LoadGame,
                MainMenuSelection::Quit => newselection = MainMenuSelection::Options,
            }
            if newselection == MainMenuSelection::LoadGame && !save_exists {
                newselection = MainMenuSelection::NewGame;
            }
            return MainMenuResult::NoSelection {
                selected: newselection,
            };
        }
        rltk::VirtualKeyCode::Down => {
            let mut newselection;
            match selection {
                MainMenuSelection::NewGame => newselection = MainMenuSelection::LoadGame,
                MainMenuSelection::LoadGame => newselection = MainMenuSelection::Options,
                MainMenuSelection::Options => newselection = MainMenuSelection::Quit,
                MainMenuSelection::Quit => newselection = MainMenuSelection::NewGame,
            }
            if newselection == MainMenuSelection::LoadGame && !save_exists {
                newselection = MainMenuSelection::Options;
            }
            return MainMenuResult::NoSelection {
                selected: newselection,
            };
        }
        rltk::VirtualKeyCode::Return => {
            return MainMenuResult::Selected {
                selected: selection,
            }
        }
        _ => {
            return MainMenuResult::NoSelection {
                selected: selection,
            }
        }
    },
}
```

That's it for the new option on the main menu, but now our `main.rs` file has an error since we have
a new unhandled option. Since this is going to be a brand new menu, we will follow the pattern we
have for every other menu:

1. Create a new `RunState` for showing the menu.
1. Create a new file in our `gui` module that will render the new menu.
1. Define the possible results for selecting menu options.
1. Handle the results in `main.rs`, updating the run state when appropriate.

# Implement Options Menu

First we create the new `RunState` in `main.rs`:

```rust
#[derive(PartialEq, Copy, Clone)]
pub enum RunState {
    // ... all the other run states
    OptionsMenu {
        menu_selection: OptionsMenuSelection,
    },
}
```

Since we have a new run state, we need to add a block in our `tick` function to handle it:

```rust
RunState::OptionsMenu { .. } => {
    // TODO: handle show options
}
```

Then in our `RunState::MainMenu` block we can set the new run state to be our options value when
it is selected on the main menu:

```rust
RunState::MainMenu { .. } => {
    let result = gui::main_menu(self, ctx);
    match result {
        gui::MainMenuResult::NoSelection { selected } => {
            newrunstate = RunState::MainMenu {
                menu_selection: selected,
            }
        }
        gui::MainMenuResult::Selected { selected } => match selected {
            gui::MainMenuSelection::NewGame => newrunstate = RunState::PreRun,
            gui::MainMenuSelection::Options => {
                newrunstate = RunState::OptionsMenu {
                    menu_selection: gui::OptionsMenuSelection::ToggleFps,
                }
            }
            gui::MainMenuSelection::LoadGame => {
                saveload_system::load_game(&mut self.ecs);
                newrunstate = RunState::AwaitingInput;
                saveload_system::delete_save();
            }
            gui::MainMenuSelection::Quit => {
                ::std::process::exit(0);
            }
        },
    }
}
```

Now we can make our new menu. In our `gui` module, create a new `options_menu.rs` file with the
following contents:

```rust
use crate::rltk;
use crate::{rex_assets::RexAssets, RunState, State};

#[derive(PartialEq, Copy, Clone)]
pub enum OptionsMenuSelection {
    ToggleFps,
    Quit,
}

#[derive(PartialEq, Copy, Clone)]
pub enum OptionsMenuResult {
    NoSelection { selected: OptionsMenuSelection },
    Selected { selected: OptionsMenuSelection },
}

pub fn options_menu(gs: &mut State, ctx: &mut rltk::BTerm) -> OptionsMenuResult {
    let mut draw_batch = rltk::DrawBatch::new();
    let runstate = gs.ecs.fetch::<RunState>();
    let assets = gs.ecs.fetch::<RexAssets>();
    ctx.render_xp_sprite(&assets.menu, 0, 5);

    draw_batch.draw_double_box(
        rltk::Rect::with_size(24, 18, 31, 10),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHEAT), rltk::RGB::named(rltk::BLACK)),
    );

    draw_batch.print_color_centered(
        20,
        "Options",
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );
    draw_batch.print_color_centered(
        21,
        "Use Up/Down Arrows and Enter",
        rltk::ColorPair::new(rltk::RGB::named(rltk::GRAY), rltk::RGB::named(rltk::BLACK)),
    );

    draw_batch.submit(6000).expect("Failed to submit");

    OptionsMenuResult::NoSelection {
        selected: OptionsMenuSelection::ToggleFps,
    }
}
```

We are copying a lot from the `main_menu` code, but in this case we are just printing a box. We will
implement the actual menu code later, for now we just add a single possible `ToggleFps` option so we
can see that the menu actually does something when we select it. We need to add this to our `gui/mod.rs`
file as well:

```rust
mod options_menu;
pub use options_menu::*;
```

Now over in `main.rs` we can actually implement some of the logic for the `OptionsMenu` run state:

```rust
RunState::OptionsMenu { .. } => {
    let result = gui::options_menu(self, ctx);
    match result {
        gui::OptionsMenuResult::NoSelection { selected } => {
            newrunstate = RunState::OptionsMenu {
                menu_selection: selected,
            }
        }
        gui::OptionsMenuResult::Selected { selected } => match selected {
            gui::OptionsMenuSelection::ToggleFps => {},
            gui::OptionsMenuSelection::Quit => newrunstate = RunState::MainMenu { menu_selection: gui::MainMenuSelection::Options },
        },
    }
}
```

Just like the main menu, we check to see if something was actually selected first, and if not we
keep track of the current selection. If something was selected, we act on it. The `ToggleFps` doesn't
actually do anything right now, and the `Quit` option isn't selectable but when we implement it then
that option will bring the user back to the main menu with the `Options` menu item selected.

If you play test the game now, we see our `Options` available on the main menu. If you select it and
hit `Enter`, you see some weird stuff. It renders the HUD and every NPC on the map while also 
showing the options menu. This is because I forgot to add a check for this special run state in the
very beginning of the `tick` function. We check that the game isn't in the `MainMenu` or `GameOver`
state before calling the camera and GUI functions. The new options menu also should avoid calling 
these methods, so we can just add a check for that as well:

```rust
match newrunstate {
    RunState::MainMenu { .. } => {}
    RunState::GameOver { .. } => {}
    RunState::OptionsMenu { .. } => {}
    _ => {
        camera::render_camera(&self.ecs, ctx);
        gui::draw_ui(&self.ecs, ctx);
    }
}
```

Now if you play test it, the options menu item actually works and renders a little box with `Options`
at the top. Cool, we are part way there. Now we need to actually implement some behavior in our 
new options menu. To start, let's just toggle showing the FPS tracker. Instead of a constant, we
now will need the `SHOW_FPS` variable to be mutable. So, let's create a new `GameOptions` struct
in `main.rs` that can keep track of stuff for us, and include `show_fps` as a field. We also need
to include it in our `State` struct so we keep it alive for our game:

```rust
struct GameOptions {
    show_fps: bool,
}

pub struct State {
    pub ecs: World,
    mapgen_next_state: Option<RunState>,
    mapgen_history: Vec<Map>,
    mapgen_index: usize,
    mapgen_timer: f32,
    dispatcher: Box<dyn systems::UnifiedDispatcher + 'static>,
    game_options: GameOptions,
}
```

Since we added a new field to our `State` struct, it means we need to initialize it. Way down in our 
`main` function we need to add the new default options when we create the `State`:

```rust
let mut gs = State {
    ecs: World::new(),
    mapgen_next_state: Some(RunState::MainMenu {
        menu_selection: gui::MainMenuSelection::NewGame,
    }),
    mapgen_index: 0,
    mapgen_history: Vec::new(),
    mapgen_timer: 0.0,
    dispatcher: systems::build(),
    game_options: GameOptions { show_fps: true },
};
```

We also need to honor this new value, so we should remove the `SHOW_FPS` constant and also update
the code that actually decides to render it to use this new value:

```rust
if self.game_options.show_fps {
    ctx.print(1, 59, &format!("FPS: {}", ctx.fps));
}
```

The last change we need in our `main.rs` file is to actually toggle the `show_fps` option if that
was selected. In our `RunState::OptionsMenu` block we need to make this change:

```rust
RunState::OptionsMenu { .. } => {
    let result = gui::options_menu(self, ctx);
    match result {
        gui::OptionsMenuResult::NoSelection { selected } => {
            newrunstate = RunState::OptionsMenu {
                menu_selection: selected,
            }
        }
        gui::OptionsMenuResult::Selected { selected } => match selected {
            gui::OptionsMenuSelection::ToggleFps => {
                self.game_options.show_fps = !self.game_options.show_fps;
                newrunstate = RunState::OptionsMenu {
                    menu_selection: selected,
                }
            }
            gui::OptionsMenuSelection::Quit => {
                newrunstate = RunState::MainMenu {
                    menu_selection: gui::MainMenuSelection::Options,
                }
            }
        },
    }
}
```

The change here is that when `ToggleFps` is actually selected (not just highlighted) then we will
flip the value in our internal `GameOptions`. We can't actually test this because we never allow 
selecting the `ToggleFps` option, so let's do that now. Head over to `gui/options_menu.rs` so we
can implement actually selecting stuff:

```rust
use super::print_menu_option;

pub fn options_menu(gs: &mut State, ctx: &mut rltk::BTerm) -> OptionsMenuResult {
    let mut draw_batch = rltk::DrawBatch::new();
    let runstate = gs.ecs.fetch::<RunState>();
    let assets = gs.ecs.fetch::<RexAssets>();
    ctx.render_xp_sprite(&assets.menu, 0, 5);

    draw_batch.draw_double_box(
        rltk::Rect::with_size(24, 18, 31, 10),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHEAT), rltk::RGB::named(rltk::BLACK)),
    );

    draw_batch.print_color_centered(
        20,
        "Options",
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );
    draw_batch.print_color_centered(
        21,
        "Use Up/Down Arrows and Enter",
        rltk::ColorPair::new(rltk::RGB::named(rltk::GRAY), rltk::RGB::named(rltk::BLACK)),
    );

    draw_batch.submit(6000).expect("Failed to submit");

    let mut y = 23;
    if let RunState::OptionsMenu {
        menu_selection: selection,
    } = *runstate
    {
        let fps_tracker_title = format!("Show FPS Tracker: {}", gs.game_options.show_fps);
        print_menu_option(
            &mut draw_batch,
            y,
            selection == OptionsMenuSelection::ToggleFps,
            fps_tracker_title,
        );
        y += 1;

        print_menu_option(
            &mut draw_batch,
            y,
            selection == OptionsMenuSelection::Quit,
            "Back",
        );

        draw_batch.submit(6000).expect("Failed to submit");

        match ctx.key {
            None => {
                return OptionsMenuResult::NoSelection {
                    selected: selection,
                }
            }
            Some(key) => match key {
                rltk::VirtualKeyCode::Escape => {
                    return OptionsMenuResult::NoSelection {
                        selected: OptionsMenuSelection::Quit,
                    }
                }
                rltk::VirtualKeyCode::Up => {
                    let newselection;
                    match selection {
                        OptionsMenuSelection::ToggleFps => {
                            newselection = OptionsMenuSelection::Quit
                        }
                        OptionsMenuSelection::Quit => {
                            newselection = OptionsMenuSelection::ToggleFps
                        }
                    }
                    return OptionsMenuResult::NoSelection {
                        selected: newselection,
                    };
                }
                rltk::VirtualKeyCode::Down => {
                    let newselection;
                    match selection {
                        OptionsMenuSelection::ToggleFps => {
                            newselection = OptionsMenuSelection::Quit
                        }
                        OptionsMenuSelection::Quit => {
                            newselection = OptionsMenuSelection::ToggleFps
                        }
                    }
                    return OptionsMenuResult::NoSelection {
                        selected: newselection,
                    };
                }
                rltk::VirtualKeyCode::Return => {
                    return OptionsMenuResult::Selected {
                        selected: selection,
                    }
                }
                _ => {
                    return OptionsMenuResult::NoSelection {
                        selected: selection,
                    }
                }
            },
        }
    }

    OptionsMenuResult::NoSelection {
        selected: OptionsMenuSelection::Quit,
    }
}
```

You may notice a ton of similarities between this and the `main_menu.rs` code, and that is because
this is pretty much a direct copy and paste of that. I wanted to centralize some reusable chunks of 
code, but the main menu is different enough that I think just reusing the `print_menu_option` function
I added earlier was the best I can do for now. This function does the following:

1. Draws the background and overall menu box with our title, that part is unchanged.
1. Gets the current selection for the options menu (and asserts the run state is actually the options
menu).
1. Renders our available options, right now just toggling FPS and going back to the main menu.
1. Shows the current value for the option in the title so the user knows what is happening.

With all that in place you can run the game and see it actually turning off the FPS tracker, and
you can turn it back on. Rad.

# More Options

Now let's add a few more simple options to this menu. We have another constant we use for debugging:
the map visualizer. The first thing we need to do is add our new option menu result and add it to the
menu over in `gui/options_menu.rs`:

```rust
#[derive(PartialEq, Copy, Clone)]
pub enum OptionsMenuSelection {
    ToggleFps,
    ToggleMapVisualizer,
    Quit,
}

pub fn options_menu(gs: &mut State, ctx: &mut rltk::BTerm) -> OptionsMenuResult {
    //... beginning of function unchanged

    let map_visualizer_title = format!("Show Map Visualizer: {}", gs.game_options.show_map_visualizer);
    print_menu_option(
        &mut draw_batch,
        y,
        selection == OptionsMenuSelection::ToggleMapVisualizer,
        &map_visualizer_title,
    );
    y += 1;

    // ... beginning of key match logic unchanged

        rltk::VirtualKeyCode::Up => {
            let newselection;
            match selection {
                OptionsMenuSelection::ToggleFps => {
                    newselection = OptionsMenuSelection::Quit
                }
                OptionsMenuSelection::ToggleMapVisualizer => {
                    newselection = OptionsMenuSelection::ToggleFps
                }
                OptionsMenuSelection::Quit => {
                    newselection = OptionsMenuSelection::ToggleMapVisualizer
                }
            }
            return OptionsMenuResult::NoSelection {
                selected: newselection,
            };
        }
        rltk::VirtualKeyCode::Down => {
            let newselection;
            match selection {
                OptionsMenuSelection::ToggleFps => {
                    newselection = OptionsMenuSelection::ToggleMapVisualizer
                }
                OptionsMenuSelection::ToggleMapVisualizer => {
                    newselection = OptionsMenuSelection::Quit
                }
                OptionsMenuSelection::Quit => {
                    newselection = OptionsMenuSelection::ToggleFps
                }
            }
            return OptionsMenuResult::NoSelection {
                selected: newselection,
            };
        }

    // ... the rest of the function
}
```

This just prints the new menu option like we did for the FPS toggle, as well as fix up the up and
down arrow logic to go to the right place. Once we have that, we just need to update our `main.rs`
file to handle the new option.

Let's remove that constant and add a new field to our `GameOptions` struct in 
`main.rs`:

```rust
struct GameOptions {
    show_fps: bool,
    show_map_visualizer: bool,
}
```

We also have to initialize the value in our `main()` function:

```rust
let mut gs = State {
    ecs: World::new(),
    mapgen_next_state: Some(RunState::MainMenu {
        menu_selection: gui::MainMenuSelection::NewGame,
    }),
    mapgen_index: 0,
    mapgen_history: Vec::new(),
    mapgen_timer: 0.0,
    dispatcher: systems::build(),
    game_options: GameOptions {
        show_fps: true,
        show_map_visualizer: false,
    },
};
```

And we have to update the code that actually reads that value:

```rust
if !self.game_options.show_map_visualizer {
    newrunstate = self.mapgen_next_state.unwrap();
} else {
    // ... map visualizer code
}
```

This also required updating how our map builders work since they rely on that constant. That is a
pretty significant code change, so I would recommend just looking at the 
[source code](https://github.com/nprice1/rust-roguelike-tutorial/tree/main/part-04-options) to get 
the updates for that. The short version is we need to pass in our new option for every one of our 
level builders, so it is just a lot of new parameters to things so when we finally get down to 
building the maps we know what the value should be.

Finally we need to implement what to do when that option is selected over in `main.rs`:

```rust
gui::OptionsMenuSelection::ToggleFps => {
    self.game_options.show_fps = !self.game_options.show_fps;
    newrunstate = RunState::OptionsMenu {
        menu_selection: selected,
    }
}
gui::OptionsMenuSelection::ToggleMapVisualizer => {
    self.game_options.show_map_visualizer =
        !self.game_options.show_map_visualizer;
    newrunstate = RunState::OptionsMenu {
        menu_selection: selected,
    }
}
gui::OptionsMenuSelection::Quit => {
    newrunstate = RunState::MainMenu {
        menu_selection: gui::MainMenuSelection::Options,
    }
}
```

We now have the power to easily toggle the map visualizer, which is super cool. Another simple 
option we can add is allowing the cheat menu. Again we follow the same pattern:

1. Add the option to our `GameOptions` struct in `main.rs`.
1. Initialize the option.
1. Add a new `OptionMenuResult` in `gui/options_menu.rs`.
1. Print the available option in the `option_menu` function.
1. Handle the new up and down arrow logic.
1. Implement what to do when the new option is selected in the options menu.
1. Use the option to modify game behavior.

So let's go through each of those for the cheat menu. In `main.rs`:

```rust
struct GameOptions {
    show_fps: bool,
    show_map_visualizer: bool,
    show_cheat_menu: bool,
}
```

Initialize the option in our `main` function:

```rust
let mut gs = State {
    ecs: World::new(),
    mapgen_next_state: Some(RunState::MainMenu {
        menu_selection: gui::MainMenuSelection::NewGame,
    }),
    mapgen_index: 0,
    mapgen_history: Vec::new(),
    mapgen_timer: 0.0,
    dispatcher: systems::build(),
    game_options: GameOptions {
        show_fps: true,
        show_map_visualizer: false,
        show_cheat_menu: true,
    },
};
```

Update our `gui/options_menu.rs`:

```rust
#[derive(PartialEq, Copy, Clone)]
pub enum OptionsMenuSelection {
    ToggleFps,
    ToggleMapVisualizer,
    ToggleCheatMenu,
    Quit,
}

pub fn options_menu(gs: &mut State, ctx: &mut rltk::BTerm) -> OptionsMenuResult {
    //... beginning of function unchanged

    let cheat_menu_title = format!(
            "Allow Cheat Menu: {}",
            gs.game_options.show_cheat_menu
        );
        print_menu_option(
            &mut draw_batch,
            y,
            selection == OptionsMenuSelection::ToggleCheatMenu,
            &cheat_menu_title,
        );
        y += 1;

    // ... beginning of key match logic unchanged

        rltk::VirtualKeyCode::Up => {
            let newselection;
            match selection {
                OptionsMenuSelection::ToggleFps => {
                    newselection = OptionsMenuSelection::Quit
                }
                OptionsMenuSelection::ToggleMapVisualizer => {
                    newselection = OptionsMenuSelection::ToggleFps
                }
                OptionsMenuSelection::ToggleCheatMenu => {
                    newselection = OptionsMenuSelection::ToggleMapVisualizer
                }
                OptionsMenuSelection::Quit => {
                    newselection = OptionsMenuSelection::ToggleCheatMenu
                }
            }
            return OptionsMenuResult::NoSelection {
                selected: newselection,
            };
        }
        rltk::VirtualKeyCode::Down => {
            let newselection;
            match selection {
                OptionsMenuSelection::ToggleFps => {
                    newselection = OptionsMenuSelection::ToggleMapVisualizer
                }
                OptionsMenuSelection::ToggleMapVisualizer => {
                    newselection = OptionsMenuSelection::ToggleCheatMenu
                }
                OptionsMenuSelection::ToggleCheatMenu => {
                    newselection = OptionsMenuSelection::Quit
                }
                OptionsMenuSelection::Quit => {
                    newselection = OptionsMenuSelection::ToggleFps
                }
            }
            return OptionsMenuResult::NoSelection {
                selected: newselection,
            };
        }

    // ... the rest of the function
}
```

And here is how we handle the option being selected in `main.rs`:

```rust
gui::OptionsMenuSelection::ToggleCheatMenu => {
    self.game_options.show_cheat_menu =
        !self.game_options.show_cheat_menu;
    newrunstate = RunState::OptionsMenu {
        menu_selection: selected,
    }
}
```

To implement what we actually do with the option, we will just have our cheat menu immediately cancel
if the option is disabled. Over in `gui/cheat_menu.rs` we can do a simple check:

```rust
pub fn show_cheat_mode(gs: &mut State, ctx: &mut rltk::BTerm) -> CheatMenuResult {
    if !gs.game_options.show_cheat_menu {
        return CheatMenuResult::Cancel;
    }
    // ... the rest of the function is unchanged
}
```

If you play test the game now, you can turn off the cheat menu entirely! We could also do things
like disable getting a score if cheat mode is turned on or whatever, but for now I just want easy
debugging toggles. Now onto the thing I originally talked about what feels like a decade ago: audio
options.

# Volume Changes

Modifying the volume will be a little trickier. I want to display what the current volume value is
as a starting point, and I know at some point I will want to modify the volume for our background 
and sound effects. This means a couple new functions in our `systems/sound_system.rs` file:

```rust
impl SoundSystem {
    // ... existing functions

    pub fn get_background_volume(&self) -> f32 {
        self.background_sink.volume()
    }

    pub fn get_effects_volume(&self) -> f32 {
        self.effects_sink.volume()
    }

    pub fn change_background_volume(&self, offset: f32) {
        self.background_sink.set_volume(self.get_background_volume() + offset);
    }

    pub fn change_effect_volume(&self, offset: f32) {
        self.effects_sink.set_volume(self.get_effects_volume() + offset);
    }
}
```

For our options menu code, we will need 4 possible options:

1. Increase background volume
1. Decrease background volume
1. Increase sound effect volume
1. Decrease sound effect volume

Hitting the enter key on these options doesn't really make sense, it would be much more intuitive
if the user could hit the left and right arrow keys to do the appropriate action. So for our new 
options, we will add some left and right arrow key handling, as well as dynamically update the help
text (the one that currently gives the up/down arrow and enter key help) to indicate left and right
keys can be used for changing the volume. 

We will start with defining a more complex menu selection for our volume menu options in 
`gui/options_menu.rs`:

```rust
#[derive(PartialEq, Copy, Clone)]
pub enum OptionsMenuSelection {
    ToggleFps,
    ToggleMapVisualizer,
    ToggleCheatMenu,
    BackgroundVolume {
        change: VolumeChange,
    },
    EffectsVolume {
        change: VolumeChange,
    },
    Quit,
}

#[derive(PartialEq, Copy, Clone)]
pub enum VolumeChange {
    Increase,
    Decrease,
    None,
}
```

Now we can add the menu options for our volume controls. When they are initially selected, they 
shouldn't do anything so we will initialize the `change` to be `None`. We can also display the
current volume using the helper functions we added to the `SoundSystem`:

```rust
pub fn options_menu(gs: &mut State, ctx: &mut rltk::BTerm) -> OptionsMenuResult {
    //... beginning of function unchanged
    let sound_system = gs.ecs.fetch::<SoundSystem>();

    let background_volume_title = format!(
        "Background Volume: {}",
        sound_system.get_background_volume(),
    );
    print_menu_option(
        &mut draw_batch,
        y,
        selection == OptionsMenuSelection::BackgroundVolume { change: VolumeChange::None },
        &background_volume_title,
    );
    y += 1;

    let effect_volume_title = format!(
        "Sound Effect Volume: {}",
        sound_system.get_effects_volume(),
    );
    print_menu_option(
        &mut draw_batch,
        y,
        selection == OptionsMenuSelection::EffectsVolume { change: VolumeChange::None },
        &effect_volume_title,
    );
    y += 1;

    // ... beginning of key match logic unchanged

        rltk::VirtualKeyCode::Up => {
            let newselection;
            match selection {
                OptionsMenuSelection::ToggleFps => {
                    newselection = OptionsMenuSelection::Quit
                }
                OptionsMenuSelection::ToggleMapVisualizer => {
                    newselection = OptionsMenuSelection::ToggleFps
                }
                OptionsMenuSelection::ToggleCheatMenu => {
                    newselection = OptionsMenuSelection::ToggleMapVisualizer
                }
                OptionsMenuSelection::BackgroundVolume { .. } => {
                    newselection = OptionsMenuSelection::ToggleCheatMenu
                }
                OptionsMenuSelection::EffectsVolume { .. } => {
                    newselection = OptionsMenuSelection::BackgroundVolume { change: VolumeChange::None }
                }
                OptionsMenuSelection::Quit => {
                    newselection = OptionsMenuSelection::EffectsVolume { change: VolumeChange::None }
                }
            }
            return OptionsMenuResult::NoSelection {
                selected: newselection,
            };
        }
        rltk::VirtualKeyCode::Down => {
            let newselection;
            match selection {
                OptionsMenuSelection::ToggleFps => {
                    newselection = OptionsMenuSelection::ToggleMapVisualizer
                }
                OptionsMenuSelection::ToggleMapVisualizer => {
                    newselection = OptionsMenuSelection::ToggleCheatMenu
                }
                OptionsMenuSelection::ToggleCheatMenu => {
                    newselection = OptionsMenuSelection::BackgroundVolume { change: VolumeChange::None }
                }
                OptionsMenuSelection::BackgroundVolume { .. } => {
                    newselection = OptionsMenuSelection::EffectsVolume { change: VolumeChange::None }
                }
                OptionsMenuSelection::EffectsVolume { .. } => {
                    newselection = OptionsMenuSelection::Quit
                }
                OptionsMenuSelection::Quit => {
                    newselection = OptionsMenuSelection::ToggleFps
                }
            }
            return OptionsMenuResult::NoSelection {
                selected: newselection,
            };
        }

    // ... the rest of the function
}
```

We can now add some left and right key handling, but we should only change that when we are on one
of the volume options:

```rust
rltk::VirtualKeyCode::Left => {
    match selection {
        OptionsMenuSelection::BackgroundVolume { .. } => {
            return OptionsMenuResult::Selected { 
                selected: OptionsMenuSelection::BackgroundVolume { 
                    change: VolumeChange::Decrease,
                } 
            }
        }
        OptionsMenuSelection::EffectsVolume { .. } => {
            return OptionsMenuResult::Selected { 
                selected: OptionsMenuSelection::EffectsVolume { 
                    change: VolumeChange::Decrease,
                } 
            }
        }
        _ => {}
    }
    return OptionsMenuResult::NoSelection {
        selected: selection,
    };
}
rltk::VirtualKeyCode::Right => {
    match selection {
        OptionsMenuSelection::BackgroundVolume { .. } => {
            return OptionsMenuResult::Selected { 
                selected: OptionsMenuSelection::BackgroundVolume { 
                    change: VolumeChange::Increase,
                } 
            }
        }
        OptionsMenuSelection::EffectsVolume { .. } => {
            return OptionsMenuResult::Selected { 
                selected: OptionsMenuSelection::EffectsVolume { 
                    change: VolumeChange::Increase,
                } 
            }
        }
        _ => {}
    }
    return OptionsMenuResult::NoSelection {
        selected: selection,
    };
}
```

Head over to `main.rs` to actually implement modifying the volume when these options are selected:

```rust
gui::OptionsMenuSelection::BackgroundVolume { change } => {
    let volume_change;
    match change {
        gui::VolumeChange::None => {
            volume_change = 0.0;
        }
        gui::VolumeChange::Increase => {
            volume_change = 1.0;
        }
        gui::VolumeChange::Decrease => {
            volume_change = -1.0;
        }
    }
    self.ecs.fetch::<SoundSystem>().change_background_volume(volume_change);
    newrunstate = RunState::OptionsMenu { 
        menu_selection: gui::OptionsMenuSelection::BackgroundVolume { 
            change: gui::VolumeChange::None,
        } 
    }
}
gui::OptionsMenuSelection::EffectsVolume { change } => {
    let volume_change;
    match change {
        gui::VolumeChange::None => {
            volume_change = 0.0;
        }
        gui::VolumeChange::Increase => {
            volume_change = 1.0;
        }
        gui::VolumeChange::Decrease => {
            volume_change = -1.0;
        }
    }
    self.ecs.fetch::<SoundSystem>().change_effect_volume(volume_change);
    newrunstate = RunState::OptionsMenu { 
        menu_selection: gui::OptionsMenuSelection::EffectsVolume { 
            change: gui::VolumeChange::None,
        } 
    }
}
```

If you play test the game now you can turn off the background and sound effects! Success! We still 
have a few visual problems though, the options box isn't big enough for our list of options and we
aren't telling the user how to change the volume values. So we need a quick tweak over in 
`gui/options_menu.rs`:

```rust
pub fn options_menu(gs: &mut State, ctx: &mut rltk::BTerm) -> OptionsMenuResult {
    // ... beginning of function is unchanged

    draw_batch.draw_double_box(
        rltk::Rect::with_size(20, 18, 40, 12),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHEAT), rltk::RGB::named(rltk::BLACK)),
    );

    draw_batch.print_color_centered(
        20,
        "Options",
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );
    draw_batch.print_color_centered(
        21,
        "Use Up/Down Arrows to Select Option",
        rltk::ColorPair::new(rltk::RGB::named(rltk::GRAY), rltk::RGB::named(rltk::BLACK)),
    );

    draw_batch.submit(6000).expect("Failed to submit");

    let mut y = 24;
    if let RunState::OptionsMenu {
        menu_selection: selection,
    } = *runstate
    {
        let help_text: &str = match selection {
            OptionsMenuSelection::BackgroundVolume { .. } |
            OptionsMenuSelection::EffectsVolume { .. } => "Use Left/Right Arrows to Change Value",
            OptionsMenuSelection::Quit => "Use Enter to Go Back",
            _ => "Use Enter to Toggle Value",
        };
        draw_batch.print_color_centered(
            22,
            help_text,
            rltk::ColorPair::new(rltk::RGB::named(rltk::GRAY), rltk::RGB::named(rltk::BLACK)),
        );

        let fps_tracker_title = format!("Show FPS Tracker: {}", gs.game_options.show_fps);

        // .. the rest of the function is unchanged
    }
}
```

Here is what we changed:

- We made the options box bigger for our new list of options and for the new help text.
- We made two lines for help text, one to indicate using the up/down arrows for navigating, and
the other is dynamic based on your current selection to tell you how to change the value.

Now our options menu is functional and intuitive! Well intuitive-ish I guess, it is definitely good
enough for me that's for sure. 

# In-Game Menu

There is one last thing I want to tweak while we are messing with the main menu. If you play test 
our game and hit the `Escape` key while playing, you might notice a couple of things:

1. It takes *forever* to go to the main menu, because we save the game when you do that.
1. There is a `Begin New Game` option on the main menu after it finishes saving, but if you select
that option it doesn't actually start a new game. It resumes your original game.

Instead, I think once you have started the game the main menu should have a `Resume` option to 
continue your game, and it shouldn't auto save, it should instead have a `Save Game` option that
will do the expensive save operation if you actually want it to do that.

First let's make the `Begin New Game` menu option become `Resume` if you are already playing a game.
We are already keeping track of the number of turns in our `gamelog`, so let's just check that to
see if any turns have elapsed and change the title for the menu option. Over in `gui/main_menu.rs`:

```rust
let in_progress_game = crate::gamelog::get_event_count("Turn") > 0;

let new_game_text ;
if in_progress_game {
    new_game_text = "Resume";
} else {
    new_game_text = "Begin New Game";
}
print_menu_option(
    &mut draw_batch,
    y,
    selection == MainMenuSelection::NewGame,
    new_game_text,
);
y += 1;
```

That's all it takes to fix that issue. Now we need to add a `SaveGame` menu option, and remove the 
auto save when a player hits the escape key. First we will add the new menu option. Over in 
`gui/main_menu.rs` we follow the pattern we are too familiar with:

Add the option:
```rust
#[derive(PartialEq, Copy, Clone)]
pub enum MainMenuSelection {
    NewGame,
    LoadGame,
    SaveGame,
    Options,
    Quit,
}
```

Print the option and the up/down arrow keys (we also made the main menu box a bit taller). We have
to be a bit tricky when initially loading the menu though, because we only want to present the 
`SaveGame` option if a game is actually in progress, so we can reuse the `in_progress_game` variable
we made for changing the new game text. We also need to get tricky with the up and down arrow logic
since we might not actually have the `SaveGame` option in the list, just like we do for the `LoadGame`
option:

```rust
pub fn main_menu(gs: &mut State, ctx: &mut rltk::BTerm) -> MainMenuResult {
    // ... no changes in beginning

    draw_batch.draw_double_box(
        rltk::Rect::with_size(24, 18, 31, 11),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHEAT), rltk::RGB::named(rltk::BLACK)),
    );

    // ... no changes for other menu options

        if in_progress_game {
            print_menu_option(
                &mut draw_batch,
                y,
                selection == MainMenuSelection::SaveGame,
                "Save Game",
            );
            y += 1;
        }

        // ... no changes in the middle

                rltk::VirtualKeyCode::Up => {
                    let mut newselection;
                    match selection {
                        MainMenuSelection::NewGame => newselection = MainMenuSelection::Quit,
                        MainMenuSelection::LoadGame => newselection = MainMenuSelection::NewGame,
                        MainMenuSelection::SaveGame => newselection = MainMenuSelection::LoadGame,
                        MainMenuSelection::Options => newselection = MainMenuSelection::SaveGame,
                        MainMenuSelection::Quit => newselection = MainMenuSelection::Options,
                    }
                    if newselection == MainMenuSelection::SaveGame && !in_progress_game {
                        newselection = MainMenuSelection::LoadGame;
                    }
                    if newselection == MainMenuSelection::LoadGame && !save_exists {
                        newselection = MainMenuSelection::NewGame;
                    }
                    return MainMenuResult::NoSelection {
                        selected: newselection,
                    };
                }
                rltk::VirtualKeyCode::Down => {
                    let mut newselection;
                    match selection {
                        MainMenuSelection::NewGame => newselection = MainMenuSelection::LoadGame,
                        MainMenuSelection::LoadGame => newselection = MainMenuSelection::SaveGame,
                        MainMenuSelection::SaveGame => newselection = MainMenuSelection::Options,
                        MainMenuSelection::Options => newselection = MainMenuSelection::Quit,
                        MainMenuSelection::Quit => newselection = MainMenuSelection::NewGame,
                    }
                    if newselection == MainMenuSelection::LoadGame && !save_exists {
                        newselection = MainMenuSelection::SaveGame;
                    }
                    if newselection == MainMenuSelection::SaveGame && !in_progress_game {
                        newselection = MainMenuSelection::Options;
                    }
                    return MainMenuResult::NoSelection {
                        selected: newselection,
                    };
                }

        // ... no more changes
}
```

Now we go handle it in `main.rs`. We can actually remove the entire `RunState::SaveGame` block, as
well as the run state itself since we now only handle it in the menu like we do for loading a game:

```rust
RunState::MainMenu { .. } => {
    let result = gui::main_menu(self, ctx);
    match result {
        gui::MainMenuResult::NoSelection { selected } => {
            newrunstate = RunState::MainMenu {
                menu_selection: selected,
            }
        }
        gui::MainMenuResult::Selected { selected } => match selected {
            gui::MainMenuSelection::NewGame => newrunstate = RunState::PreRun,
            gui::MainMenuSelection::Options => {
                newrunstate = RunState::OptionsMenu {
                    menu_selection: gui::OptionsMenuSelection::ToggleFps,
                }
            }
            gui::MainMenuSelection::LoadGame => {
                saveload_system::load_game(&mut self.ecs);
                newrunstate = RunState::AwaitingInput;
                saveload_system::delete_save();
            }
            gui::MainMenuSelection::SaveGame => {
                saveload_system::save_game(&mut self.ecs);
                newrunstate = RunState::MainMenu {
                    menu_selection: gui::MainMenuSelection::Quit,
                };
            }
            gui::MainMenuSelection::Quit => {
                ::std::process::exit(0);
            }
        },
    }
}
```

The `SaveGame` case just saves our game and then auto selects the `Quit` option since it is likely
the player wants to quit after saving. Finally we can head over to `player.rs` and remove the auto
save behavior when hitting the escape key:

```rust
// Picking up items
rltk::VirtualKeyCode::G => get_item(&mut gs.ecs),
rltk::VirtualKeyCode::I => return RunState::ShowInventory { page: 0 },
rltk::VirtualKeyCode::D => return RunState::ShowDropItem { page: 0 },
rltk::VirtualKeyCode::R => return RunState::ShowRemoveItem { page: 0 },

// Main Menu
rltk::VirtualKeyCode::Escape => return RunState::MainMenu { 
    menu_selection: gui::MainMenuSelection::SaveGame
},

// Cheating!
rltk::VirtualKeyCode::Backslash => return RunState::ShowCheatMenu,
```

Hitting the escape key while playing now is super fast, and we only incur the horrible performance
of saving when we choose to. Huzzah.

That's it for the menus! Holy crap this is a lot of non gameplay stuff I've been adding, I definitely
need a palate cleanser after all this. Good news is the next thing I want to add is stealing shit!
That sounds way more fun, so tune in next time.
