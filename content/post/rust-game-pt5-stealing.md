+++
subtitle = "Stealing"
title = "Making A Game in Rust: Part 5"
date = "2023-04-04T12:54:24+02:00"
draft = false
series = ["Making A Game in Rust"]
tags = ["rust", "game"]
+++

[Source code for this part](https://github.com/nprice1/rust-roguelike-tutorial/tree/main/part-05-stealing)

I feel like any game that has vendors should allow a bit of thievery. As soon as the original tutorial
added vendors the first thing I wanted to do was add a way to steal items, and of course incur some
cost when items are stolen. To avoid having to make a whole sneaking system, I am instead going to
create a new `Thief` faction, and have entities react accordingly. Vendors won't sell to you, and town
guards will attack you on sight. 

1. A new section in the vendor menus to allow stealing an item.
1. When stealing an item, a stealth check will be done according to the player's current dexterity
stat. If successful, the item will be stolen with no cost. If not, then the player will become part
of the `Thief` faction.
1. Town guards will attack the `Thief` faction on sight, and they will be a very tough enemy. 
1. Vendors will not sell to an entity that is part of the `Thief` faction.

The first thing we need to do is add yet another menu. Oh boy.

# Steal Menu

We are going to make a new `VendorMode` for the steal menu. To do that we head over to `main.rs` and
add to our enum:

```rust
#[derive(PartialEq, Copy, Clone)]
pub enum VendorMode {
    Buy,
    Sell,
    Steal,
}
```

Then we need to head over to `gui/vendor_menu.rs` to actually handle this new mode:

```rust
#[derive(PartialEq, Copy, Clone)]
pub enum VendorResult {
    NoResponse,
    Cancel,
    Sell,
    BuyMode,
    SellMode,
    StealMode,
    Buy,
    NextPage,
    PreviousPage,
    Steal,
}

pub fn show_vendor_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    vendor: Entity,
    mode: VendorMode,
    page: usize,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    match mode {
        VendorMode::Buy => vendor_buy_menu(gs, ctx, vendor, page),
        VendorMode::Sell => vendor_sell_menu(gs, ctx, vendor, page),
        VendorMode::Steal => vendor_steal_menu(gs, ctx, vendor, page),
    }
}
```

Then we can implement the actual logic for the new menu. It turns out this new menu will be almost
exactly the same as the buy menu with the following exceptions:

1. Different title for the menu.
1. Different help options.
1. Different menu option colors (we want to color items red to show you are doing something bad).
1. A different `VendorResult` when an item is selected.

So we will make a shared helper function that does a lot of the shared work and takes all our 
differences as parameters:

```rust
fn vendor_inventory_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    vendor: Entity,
    page: usize,
    title: &str,
    menu_option_color: rltk::RGB,
    help_options: Vec<(&str, &str)>,
    selection_result: VendorResult,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    use crate::raws::*;
    let mut draw_batch = rltk::DrawBatch::new();

    let vendors = gs.ecs.read_storage::<Vendor>();

    let inventory = crate::raws::get_vendor_items(
        &vendors.get(vendor).unwrap().categories,
        &RAWS.lock().unwrap(),
    );
    let paged_inventory = page_list(&inventory, page);
    let count = paged_inventory.len();

    let mut y = (25 - (count / 2)) as i32;
    menu_box(
        &mut draw_batch,
        y,
        (count + 3) as i32,
        title,
        help_options,
    );

    for (j, sale) in paged_inventory.iter().enumerate() {
        menu_option(
            &mut draw_batch,
            y,
            97 + j as rltk::FontCharType,
            &sale.0,
            menu_option_color,
        );

        draw_batch.print(
            rltk::Point::new(PRICE_X, y),
            &format!("{:.1} gp", sale.1 * 1.2),
        );
        y += 1;
    }

    draw_batch.submit(6000).expect("Failed to submit");

    match ctx.key {
        None => (VendorResult::NoResponse, None, None, None),
        Some(key) => match key {
            rltk::VirtualKeyCode::Space => (VendorResult::SellMode, None, None, None),
            rltk::VirtualKeyCode::Escape => (VendorResult::Cancel, None, None, None),
            rltk::VirtualKeyCode::S => (VendorResult::StealMode, None, None, None),
            rltk::VirtualKeyCode::Comma => {
                if page > 0 && inventory.len() > paged_inventory.len() {
                    (VendorResult::PreviousPage, None, None, None)
                } else {
                    (VendorResult::NoResponse, None, None, None)
                }
            }
            rltk::VirtualKeyCode::Period => {
                if paged_inventory.len() == ITEMS_PER_PAGE && inventory.len() > ITEMS_PER_PAGE {
                    (VendorResult::NextPage, None, None, None)
                } else {
                    (VendorResult::NoResponse, None, None, None)
                }
            }
            _ => {
                let selection = rltk::letter_to_option(key);
                if selection > -1 && selection < count as i32 {
                    return (
                        selection_result,
                        None,
                        Some(paged_inventory[selection as usize].0.clone()),
                        Some(paged_inventory[selection as usize].1),
                    );
                }
                (VendorResult::NoResponse, None, None, None)
            }
        },
    }
}
```

Now our buy and steal menus are super simple:

```rust
fn vendor_buy_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    vendor: Entity,
    page: usize,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    vendor_inventory_menu(
        gs,
        ctx,
        vendor,
        page,
        "Buy Which Item?",
        rltk::RGB::named(rltk::WHITE),
        vec![("SPC", "Sell Menu"), ("S", "Steal Menu")],
        VendorResult::Buy,
    )
}

fn vendor_steal_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    vendor: Entity,
    page: usize,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    vendor_inventory_menu(
        gs,
        ctx,
        vendor,
        page,
        "Steal Which Item?",
        rltk::RGB::named(rltk::RED),
        vec![("SPC", "Sell Menu")],
        VendorResult::Steal,
    )
}
```

We also need to include the help for pressing the `S` key in the `vendor_sell_menu` function:

```rust
fn vendor_sell_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    _vendor: Entity,
    page: usize,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    // ... beginning unchanged

    menu_box(
        &mut draw_batch,
        y,
        (count + 3) as i32,
        "Sell Which Item?",
        vec![("SPC", "Buy Menu"), ("S", "Steal Menu")],
    );

    // ... middle unchanged

            rltk::VirtualKeyCode::Space => (VendorResult::BuyMode, None, None, None),
            rltk::VirtualKeyCode::Escape => (VendorResult::Cancel, None, None, None),
            rltk::VirtualKeyCode::S => (VendorResult::StealMode, None, None, None),

    // ... end unchanged
}
```

That fixes all our problems in the vendor menu code, but now we need to handle the new `StealMode` 
and `Steal` results over in `main.rs`:

```rust
gui::VendorResult::Steal => {
    // TODO: Do a dexterity check and add thief faction if failed
    let tag = result.2.unwrap();
    let price = result.3.unwrap();
    let mut pools = self.ecs.write_storage::<Pools>();
    let player_entity = self.ecs.fetch::<Entity>();
    let mut identified = self.ecs.write_storage::<IdentifiedItem>();
    identified
        .insert(*player_entity, IdentifiedItem { name: tag.clone() })
        .expect("Unable to insert");
    std::mem::drop(identified);
    let player_pools = pools.get_mut(*player_entity).unwrap();
    std::mem::drop(player_entity);
    std::mem::drop(pools);
    let player_entity = *self.ecs.fetch::<Entity>();
    crate::raws::spawn_named_item(
        &RAWS.lock().unwrap(),
        &mut self.ecs,
        &tag,
        SpawnType::Carried { by: player_entity },
    );
    self.ecs
        .fetch::<SoundSystem>()
        .play_sound_effects(vec![String::from("steal.wav")]);
}
gui::VendorResult::StealMode => {
    newrunstate = RunState::ShowVendor {
        vendor,
        mode: VendorMode::Steal,
        page: 0,
    }
}
```

We added the proper `VendorMode` when `StealMode` is selected (hitting the `S` key on the vendor menu)
and for now when you select an item on the steal menu it just gives it to the player with no consequences
and plays a little sound effect to make it clear you actually took something. If you play test now you
can steal anything you want and make the game stupidly easy. 

# Town Guards

Before we actually add the logic to do a dexterity check and add the thief faction, we should add the 
new faction to `spawns.json` first, as well as our new Town Guard who will absolutely destroy things: 

```json
"faction_table" : [
    { "name" : "Player", "responses": { }},
    { "name" : "Mindless", "responses": { "Default" : "attack" } },
    { "name" : "Townsfolk", "responses" : { "Default" : "flee", "Player" : "ignore", "Townsfolk" : "ignore" } },
    { "name" : "Bandits", "responses" : { "Default" : "attack", "Bandits" : "ignore" } },
    { "name" : "Cave Goblins", "responses" : { "Default" : "attack", "Cave Goblins" : "ignore" } },
    { "name" : "Carnivores", "responses" : { "Default" : "attack", "Carnivores" : "ignore" } },
    { "name" : "Herbivores", "responses" : { "Default" : "flee", "Herbivores" : "ignore" } },
    { "name" : "Hungry Rodents", "responses": { "Default" : "attack", "Hungry Rodents" : "ignore" }},
    { "name" : "Wyrm", "responses": { "Default" : "attack", "Wyrm" : "ignore", "Fungi" : "ignore" }},
    { "name" : "Dwarven Remnant", "responses": { "Default" : "attack", "Player" : "ignore", "Dwarven Remnant" : "ignore" }},
    { "name" : "Fungi", "responses": { "Default" : "attack", "Fungi" : "ignore", "Wyrm" : "ignore" }},
    { "name" : "DarkElf", "responses" : { "Default" : "attack", "DarkElf" : "ignore" } },
    { "name" : "DarkElfA", "responses" : { "Default" : "attack", "DarkElfA" : "ignore", "DarkElfB" : "attack", "DarkElfC" : "attack" } },
    { "name" : "DarkElfB", "responses" : { "Default" : "attack", "DarkElfB" : "ignore", "DarkElfA" : "attack", "DarkElfC" : "attack" } },
    { "name" : "DarkElfC", "responses" : { "Default" : "attack", "DarkElfC" : "ignore", "DarkElfA" : "attack", "DarkElfB" : "attack" } },
    { "name" : "Town Guard", "responses" : { "Default" : "attack", "Player" : "ignore", "Townsfolk" : "ignore", "Town Guard": "ignore" } },
    { "name" : "Thief", "responses" : { "Default": "attack" }}
],

"mobs": [

    // ... other enemies

    {
        "name" : "Town Guard",
        "renderable": {
            "glyph" : "G",
            "fg" : "#FF0000",
            "bg" : "#000000",
            "order" : 1
        },
        "blocks_tile" : true,
        "vision_range" : 12,
        "movement" : "static",
        "attributes" : {
            "might" : 13,
            "fitness" : 13
        },
        "skills" : {
            "Melee" : 18,
            "Defense" : 16
        },
        "faction" : "Town Guard",
        "level" : 6,
        "gold" : "50d10",
        "equipped" : [ "War Axe", "Tower Shield", "Steel Gloves", "Breastplate", "Steel Greaves", "Steel Helm", "Steel Boots" ]
    },

]
```

Now we should spawn a few town guards in town over in `map_builders/town.rs`. We want them to spawn
around town randomly, but they should be super rare. We also want two posted by the exit, where a guard
would actually be standing:

```rust
pub fn build_rooms(&mut self, build_data: &mut BuilderMap) {
    self.grass_layer(build_data);
    self.water_and_piers(build_data);
    let (mut available_building_tiles, wall_gap_y) = self.town_walls(build_data);
    let mut buildings = self.buildings(build_data, &mut available_building_tiles);
    let doors = self.add_doors(build_data, &mut buildings, wall_gap_y);
    self.add_paths(build_data, &doors);

    // Spawn some town guards near the exit
    let first_guard_idx = build_data.map.xy_idx(build_data.width - 3, wall_gap_y - 3);
    let second_guard_idx = build_data.map.xy_idx(build_data.width - 3, wall_gap_y + 3);
    build_data
        .spawn_list
        .push((first_guard_idx, "Town Guard".to_string()));
    build_data
        .spawn_list
        .push((second_guard_idx, "Town Guard".to_string()));
    for y in wall_gap_y - 3..wall_gap_y + 4 {
        let exit_idx = build_data.map.xy_idx(build_data.width - 2, y);
        build_data.map.tiles[exit_idx] = TileType::DownStairs;
    }

    let building_size = self.sort_buildings(&buildings);
    self.building_factory(build_data, &buildings, &building_size);

    self.spawn_dockers(build_data);
    self.spawn_townsfolk(build_data, &mut available_building_tiles);
    self.spawn_town_guards(build_data, &mut available_building_tiles);

    // Make visible for screenshot
    for t in build_data.map.visible_tiles.iter_mut() {
        *t = true;
    }
    build_data.take_snapshot();
}

fn spawn_town_guards(
        &mut self,
        build_data: &mut BuilderMap,
        available_building_tiles: &mut HashSet<usize>,
    ) {
    for idx in available_building_tiles.iter() {
        if crate::rng::roll_dice(1, 200) == 1 {
            build_data.spawn_list.push((*idx, "Town Guard".to_string()));
        }
    }
}
```

# Make a DEX Roll

We have everything we need in place to actually make a dexterity roll to see if we can successfully
steal something. We should also weight the value of the item to make it harder to steal more valuable
things successfully. If the player fails to check, then they become a `Thief` which means town folk
will flee and town guards will murder. Our faction system is setup to allow everything else to behave
the same towards the player which is super cool. Over in `main.rs`:

```rust
gui::VendorResult::Steal => {
    let tag = result.2.unwrap();
    let price = result.3.unwrap();
    let player_entity = self.ecs.fetch::<Entity>();
    let attributes = self.ecs.read_storage::<Attributes>();
    let player_attributes = attributes.get(*player_entity).unwrap();
    // Calculate the value needed for success
    let target_value = match price {
        i if i < 50.0 => 10,
        i if i < 100.0 => 15,
        i if i < 300.0 => 20,
        _ => 25,
    };
    let natural_roll = crate::rng::roll_dice(1, 20);
    let quickness_bonus = player_attributes.quickness.bonus;
    // No matter what happens, you get the item
    let mut identified = self.ecs.write_storage::<IdentifiedItem>();
    identified
        .insert(*player_entity, IdentifiedItem { name: tag.clone() })
        .expect("Unable to insert");
    std::mem::drop(identified);
    std::mem::drop(player_entity);
    std::mem::drop(attributes);
    let player_entity = *self.ecs.fetch::<Entity>();
    crate::raws::spawn_named_item(
        &RAWS.lock().unwrap(),
        &mut self.ecs,
        &tag,
        SpawnType::Carried { by: player_entity },
    );
    if natural_roll + quickness_bonus > target_value {
        // Successful theft
        self.ecs
            .fetch::<SoundSystem>()
            .play_sound_effects(vec![String::from("steal.wav")]);
    } else {
        // Failed to steal
        let mut factions = self.ecs.write_storage::<Faction>();
        factions
            .insert(
                player_entity,
                Faction {
                    name: "Thief".to_string(),
                },
            )
            .expect("Unable to insert");
        self.ecs
            .fetch::<SoundSystem>()
            .play_sound_effects(vec![String::from("failure.wav")]);
        // Exit the vendor menu
        newrunstate = RunState::AwaitingInput
    }
}
```

This function does quite a bit, so let's break it down:

1. First we determine what the target value for the check will be based on the value of the item
being purloined. I am being pretty aggressive with my values here because it should be really hard
to steal stuff, but I may tweak it after some play testing.
1. Next we roll a die and add our quickness attribute bonus (quickness is what we use rather than 
DEX in our game).
1. If our roll succeeded, we steal it! Nice. This part does what our original function did and just
adds the item to the players inventory and plays a little sound effect.
1. If our roll failed, you are in for some trouble. We set the player to be in the `Thief` faction,
and we boot you out of the vendor menu. We kick you out because vendors now run away from you! So
now you can't buy stuff without us even needing to add more code. That is pretty freaking awesome.
1. No matter how the theft goes, you will have the item in your inventory. Better hope it is a good
one to survive fighting the guards.

If you play test now and try to steal something, you will (hopefully) get super murdered because 
stealing should be hard to do. I was able to find a couple ways to get a great item and kill or 
get past the guard, but since it means never getting to shop again it seems like a decent trade
off. I don't want it to be impossible to use stealing as a viable strategy.

# No Attacking Friendlies

After play-testing a bit I found a pretty glaring game-breaking issue with the introduction of 
super strong town guards: you can hit them with a ranged weapon all you want and they won't do 
anything about it unless you are a thief. That was fine before when we only had townsfolk who aren't
really worth murdering, but town guards have some awesome loot and give you a buttload of experience.
We could add consequences for attacking town-folk, but for now I'm just going to prevent non-hostile
targets from being targeted for ranged attacks. To do that, we head over to `player.rs` to modify
the `get_player_target_list` function. We want to change the deepest if check, since that is where
we have an actual viable target. We will change it from this:

```rust
if possible_target != *player_entity
    && factions.get(possible_target).is_some()
{
    
    possible_targets.push((distance_to_target, possible_target));
}
```

to this:

```rust
if possible_target != *player_entity
    && factions.get(possible_target).is_some()
{

    let faction = factions.get(possible_target).unwrap();
    let player_faction = factions.get(*player_entity).unwrap();
    let reaction = crate::raws::faction_reaction(
        &faction.name,
        &player_faction.name,
        &crate::raws::RAWS.lock().unwrap(),
    );
    if reaction == Reaction::Attack {
        possible_targets.push((distance_to_target, possible_target));
    }
}
```

All this does is a quick faction check to see if the given target is hostile towards whatever faction
the player currently is, we can't just use `Player` here since the player's faction can change now.
We have now succesfully closed the game breaking way to farm experience. 

# No Selling to Thieves

While it is true that our vendors will attempt to flee from a thief player, they will still sell to
the player if they manage to get cornered. This is not ideal since we want real consequences for 
thievery. To fix this, we need to do a quick faction check before openeing the vendor menu over
in `player.rs` in the `try_move_player` function:

```rust
pub fn try_move_player(delta_x: i32, delta_y: i32, ecs: &mut World) -> RunState {
    // ... unchanged

    let mut swap_entities: Vec<(Entity, i32, i32)> = Vec::new();
    let default_faction = Faction { name: "Player".to_string() };
    let player_faction = factions.get(*player_entity).unwrap_or(&default_faction);

    for (entity, pos, viewshed, _player) in
        (&entities, &mut positions, &mut viewsheds, &players).join()
    {
        if pos.x + delta_x < 1
            || pos.x + delta_x > map.width - 1
            || pos.y + delta_y < 1
            || pos.y + delta_y > map.height - 1
        {
            return RunState::AwaitingInput;
        }
        let destination_idx = map.xy_idx(pos.x + delta_x, pos.y + delta_y);

        result = crate::spatial::for_each_tile_content_with_gamemode(
            destination_idx,
            |potential_target| {
                let target_reaction = if let Some(faction) = factions.get(potential_target) {
                    crate::raws::faction_reaction(
                        &faction.name,
                        &player_faction.name,
                        &crate::raws::RAWS.lock().unwrap(),
                    )
                } else {
                    Reaction::Ignore
                };
                if let Some(_vendor) = vendors.get(potential_target) {
                    if target_reaction == Reaction::Ignore {
                        return Some(RunState::ShowVendor {
                            vendor: potential_target,
                            mode: VendorMode::Sell,
                            page: 0,
                        });
                    }
                }
                let hostile = target_reaction == Reaction::Attack;
                if !hostile {
                    // ... unchanged
                }
            }
        )
        // ... unchanged
    }
    // ... unchanged
}
```

While I'm including a lot of the function in the snippet above, we didn't actually change much. We 
just made it easier to check for faction reactions since we need it in two places. Here is what we 
changed:

1. Added a variable to hold the current player faction, and default to our `Player` faction if we
don't have one (which should be never, but better to be safe).
1. Check the target reaction right away when checking our movement into a target, and we default
to ignoring the player if no faction is defined for the target. 
1. Use our new `target_reaction` variable to see if vendors ignore the player (which means they will
sell to them since I don't want to make a whole reaction just for selling). If they don't ignore
the player, then they won't sell to them.
1. Use our new `target_reaction` to check if the target is hostile. Originally this was always using
the `Player` faction, but now our player's faction can change so we need to make sure the current one
is used in case we want any more interesting reactions with a `Thief`.

Now if you play-test you will see that if you steal something and get caught, even if you corner a 
vendor they still won't sell to you. One other thing you may notice is that the rock golems that
ignore the player will attack a thief, and I'm going to leave that alone now because we will just 
say rock golems have a strong sense of justice. 

And now we have a whole new way to play the game. If you want you can steal the best item in the
game and hope that is enough to slay your way through all of our existing levels. And to be honest
that would probably work pretty damn well, so I will probably need to do some tweaking in later 
chapters to make sure that path is harder, like having town guards spawn in more levels hunting the
thief or having other monsters who would normally be friendly attack thieves. Who knows, there are
so many possibilities. 

Up next, I want to expand the magic system a bit and add the ability to summon allies into battle.
