+++
subtitle = "Extending the Brilliant 'Roguelike Tutorial - In Rust'"
title = "Making A Game in Rust"
date = "2022-12-07T15:54:24+02:00"
draft = false
series = ["Making A Game in Rust"]
tags = ["rust", "game"]
+++

I have been very curious about Rust lately. I have historically very much disliked system programming languages, 
the low level concepts and pointer arithmetic has always been a frustration that I loved to avoid. However, Rust is more
interesting. The concept of a "safe" systems programming language is very appealing, and it isn't too bad to write. I 
even wrote a [dumb little game in Rust](https://github.com/nprice1/just-run) a few years ago, but looking back on that
code it became evident that wasn't so much writing a game as it was bastardizing stack overflow responses. It was ugly
but functional, so I wanted to try writing an actual game with Rust and see if I could actually make it pretty.

Enter the amazing [Roguelike Tutorial - In Rust](https://bfnightly.bracketproductions.com/rustbook/chapter_0.html). I
started with it thinking I would quickly deviate from the tutorial to do my own stuff, but holy crap is it a well written
tutorial. Not only that, but it was fun as hell to follow along with. I ended up following the entire tutorial, but it
left me wanting more. So, I decided to attempt to follow Herbert Wolverson's example and make a series where I slowly
increment changes in the game to see if I really understood the tutorial. I will also be following his example of a github
repo with the code locked in time for a given article because that is so much better than... whatever the hell I've been
doing so far. 

This tutorial will assume that you have also followed the tutorial and have the associated code. I will be breezing over
the concepts covered in the tutorial and focusing only on new concepts I introduce here or stuff I want to expand on from
Herbert's tutorial. 

[See the source code for all tutorials here](https://github.com/nprice1/rust-roguelike-tutorial)

## Personal Tweaks

In the source code, I have a [part-00-start](https://github.com/nprice1/rust-roguelike-tutorial/tree/main/part-00-start)
folder where this tutorial is starting from. This is almost exactly the same as the code you would have after completing 
the tutorial with a few minor tweaks:

1. I removed the hunger system because I absolutely hate hunger systems in games. This means I need to modify 
`spawns.json` to completely remove any references to `Rations` as well as `Dried Sausage`. I liked getting meat drops from 
animals, so I just changed the `effects` to `provides_healing: "2"` rather than being food.
1. My FPS was locked to 30 on my M1 Macbook for some reason, so I added a `.with_fps_cap(60.0)` to my `RltkBuilder` and 
that allowed my FPS to actually get to 60. Not sure if there is another option I could use to unlock the FPS cap, but 60 
seems fine to me for now.
1. Changed the by-line of the main menu to be `Inspired by Herbert Wolverson` so I'm not stealing credit while still 
providing it. 

## Update Dependencies

[Source code for this part can be found here](https://github.com/nprice1/rust-roguelike-tutorial/tree/main/part-01-update)

The first thing to do is update to the new hotness. The tutorial was written in 2019, and some stuff has changed since 
then. For example, the `rltk` dependency is no more and has since been replaced with `bracket-lib`. The other dependencies 
can be updated without much trouble, but updating our framework takes some changes. Shocking I know. First we need to 
update our `Cargo.toml` with the new dependency:

```toml
[dependencies]
bracket-lib = { version = "~0.8", features = ["serde", "specs"] }
specs = { version = "0.18", features = ["serde"] }
specs-derive = "0.4.1"
serde= { version = "^1.0.44", features = ["derive"] }
serde_json = "^1.0.44"
lazy_static = "1.4.0"
regex = "1.3.6"
```

And watch the IDE paint a sea of red. Most of these are pretty straightforward since the logic is about the same, the 
package was just split into multiple modules. We will start with `main.rs`, where we will do a fancy mapping where we 
import the `bracket_lib` crate but alias it to `rltk` to prevent breaking the world:

```rust
extern crate bracket_lib;
use bracket_lib::prelude as rltk;
```

We still need a few tweaks since anything named `Rltk` doesn't exist anymore, it has been renamed to `BTerm`. So we update 
our `rltk` import:

```rust
use rltk::{GameState, Point, BTerm};
``` 

Then we have to rename everything using `Rltk` to `BTerm`, and our `RltkBuilder` in our `main` function becomes this:

```rust
use rltk::BTermBuilder;
let mut context = BTermBuilder::simple(80, 60)
    .unwrap()
    .with_title("Roguelike Tutorial")
    .with_font("vga8x16.png", 8, 16)
    .with_sparse_console(80, 30, "vga8x16.png")
    .with_vsync(false)
    .with_fps_cap(60.0)
    .build()?;
```

Now we go to every other red file and change any `use rltk::` to be `use crate::rltk::` to that we get our aliasing 
working. This isn't the most elegant solution in the world, but it helps when referencing examples and now we have the 
most up to date library. 

This requires a TON of changes, especially since it has always bothered me that it is apparently random when to use which 
syntax for an import, so I standardized to using the `rltk::` prefix for everything from that package to make it clear it 
is an external reference. This comes in handy for situations like how there is both a `Rect` in our project as well as in 
the the `bracket_lib` module, so that gets confusing really fast when seeing `Rect` used around the project. See the 
[source code](https://github.com/nprice1/rust-roguelike-tutorial/tree/main/part-01-update) for the full updates. 

## Macros

I'm confident that everyone who followed the original tutorial was sick and tired of 
`make sure to update main.rs and saveload_system.rs` for every damn component. I know I was, and I spent a long freaking 
time figuring out how to make that not a thing. This is more than just a personal nitpick, it will fix a very subtle 
bug that I ran into multiple times. If you forget the `ecs.register::<>` call in `main.rs`, then you will get an error 
when attempting to run because the ECS system is smart enough to notice you are trying to use a component that it doesn't 
know about. However, if you forget to add it in `saveload_system` then that component will just not get serialized and 
will disappear when you try to load a saved game. That happened to me quite often, and I hated it so so much. So much so 
that I dug into the absolute crazy town that is Rust Macros. 

### The Goal

My goal is to have a centralized source of truth for which components we have that is used everywhere we need it and stop 
requiring the duplication of these massive lists everywhere. This will prevent the subtle error noted above as well as 
allowing only a single file to be updated when adding a new component. And the children will rejoice. 

### Possible Solutions

My Java brain immediately went to reflection as the solution here. We have a bunch of structs that implement the 
`Component` trait, so it would be super awesome to be able to load all structs from a module that implement a given trait, 
then iterate on them and do some work. In Rust land that is not a thing, and for 
[good reason](https://stackoverflow.com/questions/36416773/how-does-rust-implement-reflection). So I scrapped
that idea as classic Java brain solutioning, and moved on to what Rust can do which is macros!

We wrote a few macros in the tutorial, in fact two of them are used in the code we are trying to simplify right now. It 
took me a long time to grok macros, and I'm confident I still don't fully understand them but the important part is that 
they are Rust code that writes Rust code, which is both awesome and terrifying. I imagine seasoned Rustaceans (still don't 
like that name but whatever) have a complex relationship with macros since they are the only way to achieve certain 
solutions and they are also just regex, but more. And as we all know, regex is of the devil. This is one of those 
situations where using a macro is the only way I can actually achieve this goal since it requires assigning a dynamic list 
of type parameters, which is not possible with anything that isn't a macro from what I can tell. So, let's attempt to 
write one. 

### Requirements

In order to actually write the macro, we need to decide how we want it to operate based on how we have things setup. Write 
now we have three uses of the list of components: 

1. `main.rs` where we need to call `ecs.register` for each component.
1. `saveload_system.rs` in the call to the `serialize_individually` macro.
1. `saveload_system.rs` in the call to the `deserialize_individually` macro.

All of those share the same use case for how the list is used which is inserting the type as a type argument. That makes 
things easier for us since there is some commonality in the use cases. However, those do some drastically different things 
outside of that commonality. This means we need a way of dynamically passing in what should be done with the types. This 
part was tricky because I wasn't sure how I could pass in an arbitrary set of functionality for a macro while also 
operating on it unless I did some complex lexicographical parsing. Then I finally found that 
[callbacks are supported in macros](https://danielkeep.github.io/tlborm/book/pat-callbacks.html). This is exactly what we 
need, a way to pass in a macro that will operate on the list of types. Now we know the general structure of how we can 
implement this.

### Implementation

So now we know we are going to rely on a callback, and we want to provide all of the available components as arguments to 
that callback. In `components.rs` we add a new macro that can be used outside of the module:

```rust
#[macro_export]
macro_rules! provide_all_components {
    (
        $callback:ident
    ) => {
        $callback!(
            Position,
            Renderable,
            // ... all other components go here
        );
    };
}
```

The `#[macro_export]` allows our macro to be used in `main.rs` and `saveload_system.rs`. All this macro is doing is taking 
in an identifier for a callback, then it calls that callback with our list of types. Cool, we achieved the goal of having 
the list in a single place. But now we need to make it actually work. 

Over in `main.rs`, let's make the macro that will register all of our components. This macro needs to operate on our 
`ecs`, and it will be given a repeatable list of types as an argument from our fancy `provide_all_components` macro:

```rust
macro_rules! register {
    (
        $ecs:expr,
        $(
            $type:ty
        ),*
    ) => {
        $(
            $ecs.register::<$type>();
        )*
    };
}
```

All this macro does is for every `$type` that is passed in as an argument to the macro, it calls `ecs.register` for that 
type. Notice the super fancy `$()*` syntax to indicate repeating parameters and operations like in the serialize and 
deserialize macros we did in the tutorial. Now in our `main()` function, we can replace most of those 
`gs.ecs.register` calls with our new macros. I say most, because we have a special component that is outside our main 
list: `gs.ecs.register::<SimpleMarker<SerializeMe>>();`. That one needs to stay there since it is required for serializing
but shouldn't actually be serialized:

```rust
provide_all_components!(register);
gs.ecs.register::<SimpleMarker<SerializeMe>>();
```

And our compiler isn't happy. Our `provide_all_components` macro is a little too dumb, it isn't providing any necessary 
arguments to our callback, in this case we need to pass `ecs` or else we can't do our register properly. Over in 
`components.rs` we need to change our macro:

```rust
#[macro_export]
macro_rules! provide_all_components {
    (
        $callback:ident,
        $ecs:expr
    ) => {
        $callback!(
            $ecs,
            Position,
            Renderable,
            // ... other components
        );
    };
}
```

And in `main.rs` we can pass in `gs.ecs` to allow our macro to actually do its job:

```rust
provide_all_components!(register, gs.ecs);
gs.ecs.register::<SimpleMarker<SerializeMe>>();
```

And it works! Huzzah and hooray I love removing large chunks of code. Now let's see if we can do the same over in 
`saveload_system.rs`, starting with the `serialize_individually` use case. In the `save_game()` function replace the 
`serialize_individually` call with our new macro:

```rust
provide_all_components!(
    serialize_individually,
    ecs,
    serializer,
    data
);
```

And yet again we are not handling our callback properly. Right now the callback only expects a single parameter, but our 
serialize macros are passing in three. After digging into allowing a dynamic number of parameters here, it seems as though 
the only solution would be defining the `provide_all_components` macro for each possible argument size, which defeats the 
whole purpose! However all is not lost. We also need the `ecs` as a parameter to these callbacks, so instead of passing in 
those extra parameters let's just build them in our macros. Our `serialize_individually` macro can become:

```rust
macro_rules! serialize_individually {
    (
        $ecs:expr,
        $( 
            $type:ty
        ),*
    ) => {
        {
            let writer = File::create("./savegame.json").unwrap();
            let mut serializer = serde_json::Serializer::new(writer);
            $(
                SerializeComponents::<Infallible, SimpleMarker<SerializeMe>>::serialize(
                    &( $ecs.read_storage::<$type>(), ),
                    &$ecs.entities(),
                    &$ecs.read_storage::<SimpleMarker<SerializeMe>>(),
                    &mut serializer,
                )
                .unwrap();
            )*
        }
    };
}
```

This is just letting macros do what they do best: write code. We are literally just replacing the code that was around the 
macro use to instead be done inside the macro before looping over every type, so the end result code is equivalent while 
also only requiring the single `ecs` parameter. We can do the same for the `deserialize_individually` macro:

```rust
macro_rules! deserialize_individually {
    (
        $ecs:expr,
        $( 
            $type:ty
        ),*
    ) => {
        let data = fs::read_to_string("./savegame.json").unwrap();
        let mut de = serde_json::Deserializer::from_str(&data);

        {
            $(
                DeserializeComponents::<Infallible, _>::deserialize(
                    &mut ( &mut $ecs.write_storage::<$type>(), ),
                    &mut $ecs.entities(),
                    &mut $ecs.write_storage::<SimpleMarker<SerializeMe>>(),
                    &mut $ecs.write_resource::<SimpleMarkerAllocator<SerializeMe>>(),
                    &mut de,
                )
                .unwrap();
            )*
        }
    };
}
```

Now all of our callbacks have the same signature. Lastly we need to update our `save_game()` and `load_game()` functions 
to use the new signature and replace the code that now lives in the macro:

```rust
pub fn save_game(ecs: &mut World) {
    // Create helper
    let mapcopy = ecs.get_mut::<super::map::Map>().unwrap().clone();
    let dungeon_master = ecs
        .get_mut::<super::map::MasterDungeonMap>()
        .unwrap()
        .clone();
    let savehelper = ecs
        .create_entity()
        .with(SerializationHelper { map: mapcopy })
        .marked::<SimpleMarker<SerializeMe>>()
        .build();
    let savehelper2 = ecs
        .create_entity()
        .with(DMSerializationHelper {
            map: dungeon_master,
            log: crate::gamelog::clone_log(),
            events: crate::gamelog::clone_events(),
        })
        .marked::<SimpleMarker<SerializeMe>>()
        .build();


    provide_all_components!(
        serialize_individually,
        ecs
    );

    // Clean up
    ecs.delete_entity(savehelper).expect("Crash on cleanup");
    ecs.delete_entity(savehelper2).expect("Crash on cleanup");
}

pub fn load_game(ecs: &mut World) {
    {
        // Delete everything
        let mut to_delete = Vec::new();
        for e in ecs.entities().join() {
            to_delete.push(e);
        }
        for del in to_delete.iter() {
            ecs.delete_entity(*del).expect("Deletion failed");
        }
    }

    provide_all_components!(
        deserialize_individually,
        ecs
    );

    let mut deleteme: Option<Entity> = None;
    let mut deleteme2: Option<Entity> = None;
    // .. the rest of the function is unchanged
}
```

We did it! So now what does this mean? It means when a new component is added, it just needs to be added to the parameter 
list in our `provide_all_components` macro and that's it! We also get the added benefit of if you forget to add it to the 
macro, you get the nice ECS check to tell you something is wrong rather than the super subtle saving bug. 
