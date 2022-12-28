+++
subtitle = "Clean up the GUI"
title = "Making A Game in Rust: Part 3"
date = "2022-12-28T12:54:24+02:00"
draft = false
series = ["Making A Game in Rust"]
tags = ["rust", "game", "gui"]
+++

[Source code for this part](https://github.com/nprice1/rust-roguelike-tutorial/tree/main/part-03-gui)

After adding a bunch of sounds, I did a bunch of play testing to make sure everything was working.
As I did that, I noticed a pretty major issue with our menus. If you switch over to the buy menu
for any vendor that happens to sell a lot of stuff, like the blacksmith, you get a massive list of
items that is unreadable and unusable. Not only that, but we get weird clipping and rendering
issues when the line length gets too long. Now that I've seen that I can't leave it alone, so we
are going to work on adding some paging to our menus. The goal is to go from this:

![menus before](/img/menus-before.gif)

To this:

![menus after](/img/menus-after.gif)

# Paging Vendor Menus

Right now our inventory menus are alright since it would take a lot of work for a player to get 
enough items to overwhelm the menu, so let's start with the vendor menus since those are easy to
test and actually suffer from the problem right now. Our plan is to add the ability to hit the `,`
key to go back a page, and the `.` key to go forward a page for the vendor menu. In order to do 
that, we need to head over to `gui/vendor_menu.rs` and add some new possible results for the menu:

```rust
#[derive(PartialEq, Copy, Clone)]
pub enum VendorResult {
    NoResponse,
    Cancel,
    Sell,
    BuyMode,
    SellMode,
    Buy,
    NextPage,
    PreviousPage,
}
```

Then we need to add the possible key codes to both the buy and the sell menu:

```rust
rltk::VirtualKeyCode::Space => (VendorResult::BuyMode, None, None, None),
rltk::VirtualKeyCode::Escape => (VendorResult::Cancel, None, None, None),
rltk::VirtualKeyCode::Comma => (VendorResult::PreviousPage, None, None, None),
rltk::VirtualKeyCode::Period => (VendorResult::NextPage, None, None, None),
```

We then have to head over to `main.rs` to handle the new results with some TODO comments about 
actually implementing the paging logic:

```rust
gui::VendorResult::BuyMode => {
    newrunstate = RunState::ShowVendor {
        vendor,
        mode: VendorMode::Buy,
    }
}
gui::VendorResult::SellMode => {
    newrunstate = RunState::ShowVendor {
        vendor,
        mode: VendorMode::Sell,
    }
}
gui::VendorResult::PreviousPage => {
    // TODO: Update page information
    newrunstate = RunState::ShowVendor {
        vendor,
        mode: VendorMode::Sell,
    }
}
gui::VendorResult::NextPage => {
    // TODO: Update page information
    newrunstate = RunState::ShowVendor {
        vendor,
        mode: VendorMode::Sell,
    }
}
```

To implement the actual paging, we need to pass in which page we are currently looking at as well 
as get the appropriate slice of our items to display. Over in `gui/vendor_menu.rs` we have a 
centralized `show_vendor_menu` function that is called from our main game loop. That seems like a
great place to add our index, so we will add a `page` integer as a parameter that we will pass into
both of our menu render functions:

```rust
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
    }
}
```

We also need to add the new parameter to our two render functions:

```rust
fn vendor_sell_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    _vendor: Entity,
    page: usize,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    // ... the function
}

fn vendor_buy_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    vendor: Entity,
    page: usize,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    // ... the function
}
```

To actually implement the logic we need to do things a bit differently for each method. Our buy
menu relies on fetching all purchasable items as a vector from our raws, so we need to slice that
vector making sure we don't exceed the length of the vector if we page too far back or forwards.
We also need to define a constant we can use for the number of items we want to show per page. To
start with I just went with 20 as a constant in the vendor file:

```rust
const ITEMS_PER_PAGE: usize = 20;
```

Then in our buy menu code I sliced up the vector:

```rust
let vendors = gs.ecs.read_storage::<Vendor>();

let inventory = crate::raws::get_vendor_items(
    &vendors.get(vendor).unwrap().categories,
    &RAWS.lock().unwrap(),
);
let start_index = std::cmp::min(page * ITEMS_PER_PAGE, inventory.len() - 1);
let end_index = std::cmp::min(start_index + ITEMS_PER_PAGE, inventory.len());
let paged_inventory = &inventory[start_index..end_index].to_vec();
let count = paged_inventory.len();

let mut y = (25 - (count / 2)) as i32;
```

All this does is move forward the number of pages (zero indexed here, so we start with page 0) then
leave all the other logic in place. We essentially fake out the existing list to think there are 
only 20 entries in the available list. We need those `min` checks to make sure we don't walk past
the end of the list of entries, so if the user advances to page 20 when there is only 1 page of 
items we will still just show the last item. Not the best but a good place to start.

The sell menu is a little trickier, we rely on an iterator from Specs to grab all of our available
sell items so we have to advance our iterator if necessary:

```rust
let start_index = page * ITEMS_PER_PAGE;
let inventory = (&backpack, &names)
    .join()
    .filter(|item| item.0.owner == *player_entity)
    .skip(start_index);
let count = std::cmp::min(inventory.count(), ITEMS_PER_PAGE);
```

We check if the provided page should advance our iterator and then bump it up so it started reading
from the correct index. But what about if we have 100 items, and we only advanced by 20? We also 
need to fix the actual iteration part to check if we have rendered too many items:

```rust
let mut j = 0;
for (entity, _pack, item) in (&entities, &backpack, &items)
    .join()
    .filter(|item| item.1.owner == *player_entity)
{
    if j > ITEMS_PER_PAGE {
        break;
    }
    draw_batch.set(
        rltk::Point::new(17, y),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHITE), rltk::RGB::named(rltk::BLACK)),
        rltk::to_cp437('('),
    );
    // ... the rest of the drawing code
}
```

Cool now we have the vendor rendering code setup so we just need to pass in the proper page when we
actually show the vendor menu, and move the pages when the keys are pressed. To do that we head over
to `main.rs`. We need a way to keep track of the current page we are on, and we are already doing
that by adding the `VendorMode` to the `ShowVendor` run state, so let's just add a `page` value
in there to keep track of:

```rust
ShowCheatMenu,
ShowVendor {
    vendor: Entity,
    mode: VendorMode,
    page: usize,
},
TeleportingToOtherLevel {
    x: i32,
    y: i32,
    depth: i32,
},
```

Now we can actually add in the page numbers properly by updating all our vendor results:

```rust
RunState::ShowVendor { vendor, mode, page } => {
    use crate::raws::*;
    let result = gui::show_vendor_menu(self, ctx, vendor, mode, page);
    match result.0 {
        gui::VendorResult::Cancel => newrunstate = RunState::AwaitingInput,
        gui::VendorResult::NoResponse => {}
        gui::VendorResult::Sell => {
            // ... sell code stays the same
        }
        gui::VendorResult::Buy => {
            // ... buy code stays the same
        }
        gui::VendorResult::BuyMode => {
            // Switching modes should reset the page
            newrunstate = RunState::ShowVendor {
                vendor,
                mode: VendorMode::Buy,
                page: 0,
            }
        }
        gui::VendorResult::SellMode => {
            // Switching modes should reset the page
            newrunstate = RunState::ShowVendor {
                vendor,
                mode: VendorMode::Sell,
                page: 0,
            }
        }
        gui::VendorResult::PreviousPage => {
            newrunstate = RunState::ShowVendor {
                vendor,
                mode: mode,
                // Don't let us go into a negative number for the page
                page: std::cmp::max(0, page - 1),
            }
        }
        gui::VendorResult::NextPage => {
            newrunstate = RunState::ShowVendor {
                vendor,
                mode: mode,
                page: page + 1,
            }
        }
    }
}
```

We have one new red file: `player.rs`. That is where we actually set the initial `ShowVendor` run
state, so we need to head over there and set the initial page to be 0:

```rust
if let Some(_vendor) = vendors.get(potential_target) {
    return Some(RunState::ShowVendor {
        vendor: potential_target,
        mode: VendorMode::Sell,
        page: 0
    });
}
```

If you run the game now you will notice a few things if you try out our new vendor menus:

1. When you advance too many pages, you only see the last item in the list.
1. You can advance a bunch of pages past the end of the list, and then you have to go back the
same number of pages to actually see any results. 
1. Long names overlay the box.
1. The gold value is overlaid over our characters inventory system.

The first two issues are caused by our new paging system, so let's fix those first. Instead of just
blindly going to the next or previous page when the keys are hit, we should add some logic when 
the keys are pressed to ensure there is an actual next page to go to. Our buy menu logic is pretty
simple, we don't want to try and go back a page if we are already at page 0, and we don't want to
go back a page if there aren't even enough items to have multiple pages:

```rust
rltk::VirtualKeyCode::Comma => {
    if page > 0 && inventory.len() > paged_inventory.len() {
        (VendorResult::PreviousPage, None, None, None)
    } else {
        (VendorResult::NoResponse, None, None, None)
    }
},
```

When going forward a page, we want to make sure there are enough items in the full inventory to
need multiple pages, and we want to ensure our paged inventory is full since that means we had 
enough items to fill the full page, and there are more to be loaded (or we have exactly enough 
items for that many pages but I'll deal with that later):

```rust
rltk::VirtualKeyCode::Period => {
    if paged_inventory.len() == ITEMS_PER_PAGE && inventory.len() > ITEMS_PER_PAGE {
        (VendorResult::NextPage, None, None, None)
    } else {
        (VendorResult::NoResponse, None, None, None)
    }
},
```

We can reuse that same logic for our sell menu, we just have to change some variable around. We 
will rely on how many items we actually rendered on the page which was originally called `j` since
it was just a counter, but I renamed it to `item_num` in the for loop since we are using it in 
more places and it has more meaning, then our key-code logic can become:

```rust
rltk::VirtualKeyCode::Comma => {
    if page > 0 && count > ITEMS_PER_PAGE {
        (VendorResult::PreviousPage, None, None, None)
    } else {
        (VendorResult::NoResponse, None, None, None)
    }
},
rltk::VirtualKeyCode::Period => {
    if item_num == ITEMS_PER_PAGE && count > ITEMS_PER_PAGE {
        (VendorResult::NextPage, None, None, None)
    } else {
        (VendorResult::NoResponse, None, None, None)
    }
},
```

Now if you run the game the paging won't let you go off into infinity, and will only navigate
when necessary.

# Generalized Paging

Now that we have paging working for our vendor menus, let's make it more generic so we can use it
for player inventory as well. We will lay the groundwork like we did for the vendor menus first, 
then we can actually implement the code. Just like for the vendor menus, the first thing we need to
do is add `NextPage` and `PreviousPage` to our `ItemMenuResult` enum over in `inventory_menu.rs`:

```rust
#[derive(PartialEq, Copy, Clone)]
pub enum ItemMenuResult {
    Cancel,
    NoResponse,
    Selected,
    NextPage,
    PreviousPage,
}
```

Our `main.rs` file will light up with errors now, but first I want to fix all of the GUI functions
that will need to know about the page number so we can fix `main.rs` all at once. So, which of our
functions need to care? Looking into `main.rs` for all the various `ItemMenuResult` possibilities, 
it looks like we need to update the `drop_item_menu`, `identify_menu`, `show_inventory`, 
`remove_curse_menu`, and `remove_item_menu`. Our targeting menu also reuses `ItemMenuResult`, but
paging doesn't make any sense there so we just won't add it. We need to update the parameters for
all of those functions:

In `gui/drop_item_menu.rs`:
```rust
pub fn drop_item_menu(gs: &mut State, ctx: &mut rltk::BTerm, page: usize) -> (ItemMenuResult, Option<Entity>) {
    // ... function unchanged
}
```

In `gui/identify_menu.rs`:
```rust
pub fn identify_menu(gs: &mut State, ctx: &mut rltk::BTerm, page: usize) -> (ItemMenuResult, Option<Entity>) {
    // ... function unchanged
}
```

In `gui/inventory_menu.rs`:
```rust
pub fn show_inventory(gs: &mut State, ctx: &mut rltk::BTerm, page: usize) -> (ItemMenuResult, Option<Entity>) {
    // ... function unchanged
}
```

In `gui/remove_curse_menu.rs`:
```rust
pub fn remove_curse_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    page: usize
) -> (ItemMenuResult, Option<Entity>) {
    // ... function unchanged
}
```

In `gui/remove_item_menu.rs`:
```rust
pub fn remove_item_menu(gs: &mut State, ctx: &mut rltk::BTerm, page: usize) -> (ItemMenuResult, Option<Entity>) {
    // ... function unchanged
}
```

Now we have enough to fix our `main.rs` file so when we do actually implement paging it will just
work which is always fun. First we need to keep track of the page number for our various `Show` 
run states like we did for the vendor menu:

```rust
#[derive(PartialEq, Copy, Clone)]
pub enum RunState {
    // ... other run states
    ShowInventory {
        page: usize,
    },
    ShowDropItem {
        page: usize,
    },
    ShowTargeting {
        range: i32,
        item: Entity,
        // note we don't add a page tracker here since we dont page on targeting
    },
    ShowRemoveItem {
        page: usize,
    },
    ShowVendor {
        vendor: Entity,
        mode: VendorMode,
        page: usize,
    },
    ShowRemoveCurse {
        page: usize,
    },
    ShowIdentify {
        page: usize,
    },
}
```

Now each of those `Show` blocks will have errors, and all we have to do is add `page` as a 
parameter to the match statement and handle the `NextPage` and `PreviousPage` for each of those
results just like we did for the vendor menu. Here is how we do it for the `ShowInventory` block:

```rust
RunState::ShowInventory { page } => {
    let result = gui::show_inventory(self, ctx, page);
    match result.0 {
        gui::ItemMenuResult::Cancel => newrunstate = RunState::AwaitingInput,
        gui::ItemMenuResult::NoResponse => {}
        gui::ItemMenuResult::Selected => {
            let item_entity = result.1.unwrap();
            let is_ranged = self.ecs.read_storage::<Ranged>();
            let is_item_ranged = is_ranged.get(item_entity);
            if let Some(is_item_ranged) = is_item_ranged {
                newrunstate = RunState::ShowTargeting {
                    range: is_item_ranged.range,
                    item: item_entity,
                };
            } else {
                let mut intent = self.ecs.write_storage::<WantsToUseItem>();
                intent
                    .insert(
                        *self.ecs.fetch::<Entity>(),
                        WantsToUseItem {
                            item: item_entity,
                            target: None,
                        },
                    )
                    .expect("Unable to insert intent");
                newrunstate = RunState::Ticking;
            }
        }
        gui::ItemMenuResult::NextPage => {
            newrunstate = RunState::ShowInventory { page: page + 1 }
        },
        gui::ItemMenuResult::PreviousPage => {
            newrunstate = RunState::ShowInventory { page: page - 1 }
        }
    }
}
```

Here is what we changed:

- We added the `{ page }` parameter to the match statement.
- We passed the `page` parameter into the `show_inventory` function.
- We added two new match blocks for the `ItemMenuResult` to handle next and previous page, and all
we do there is set the run state to be the proper page like we did for vendor menus.

We need to repeat that process for all of the `Show` run states we modified. I won't go over that 
here, instead check the source code for the exact details. We also need to handle the `NextPage`
and `PreviousPage` results in our `ShowTargeting` run state, but we just add no-ops there:

```rust
RunState::ShowTargeting { range, item } => {
    let result = gui::ranged_target(self, ctx, range);
    match result.0 {
        gui::ItemMenuResult::Cancel => newrunstate = RunState::AwaitingInput,
        gui::ItemMenuResult::NoResponse => {}
        gui::ItemMenuResult::NextPage => {},
        gui::ItemMenuResult::PreviousPage => {},
        gui::ItemMenuResult::Selected => {
            // ... the selected code is unchanced
        }
    }
}
```

After all that we still have some errors. Since we added `page` as a parameter to our run states we
need to properly initialize them. In our `RunState::Ticking` block in `main.rs` we set the run state
to be the ones that care about pages, so we need to add the page parameter in those cases:

```rust
RunState::Ticking => {
    let mut should_change_target = false;
    while newrunstate == RunState::Ticking {
        self.run_systems();
        self.ecs.maintain();
        match *self.ecs.fetch::<RunState>() {
            RunState::AwaitingInput => {
                newrunstate = RunState::AwaitingInput;
                should_change_target = true;
            }
            RunState::MagicMapReveal { .. } => {
                newrunstate = RunState::MagicMapReveal { row: 0 }
            }
            RunState::TownPortal => newrunstate = RunState::TownPortal,
            RunState::TeleportingToOtherLevel { x, y, depth } => {
                newrunstate = RunState::TeleportingToOtherLevel { x, y, depth }
            }
            RunState::ShowRemoveCurse { page } => newrunstate = RunState::ShowRemoveCurse { page },
            RunState::ShowIdentify { page } => newrunstate = RunState::ShowIdentify { page },
            _ => newrunstate = RunState::Ticking,
        }
    }
    if should_change_target {
        player::end_turn_targeting(&mut self.ecs);
    }
}
```

Then over in `player.rs` where we initially return the run states that care about pages, we need
to initialize the page to be `0` like we did for vendor menus:

```rust
// Picking up items
rltk::VirtualKeyCode::G => get_item(&mut gs.ecs),
rltk::VirtualKeyCode::I => return RunState::ShowInventory { page: 0 },
rltk::VirtualKeyCode::D => return RunState::ShowDropItem { page: 0 },
rltk::VirtualKeyCode::R => return RunState::ShowRemoveItem { page: 0 },
```

We need to do the same in `effects/trigger.rs`:

```rust
// Remove Curse
if ecs
    .read_storage::<ProvidesRemoveCurse>()
    .get(entity)
    .is_some()
{
    let mut runstate = ecs.fetch_mut::<RunState>();
    *runstate = RunState::ShowRemoveCurse { page: 0 };
    did_something = true;
}

// Identify Item
if ecs
    .read_storage::<ProvidesIdentification>()
    .get(entity)
    .is_some()
{
    let mut runstate = ecs.fetch_mut::<RunState>();
    *runstate = RunState::ShowIdentify { page: 0 };
    did_something = true;
}
```

That's a lot of setup, but now our skeleton is in place and we can implement the paging logic like
we did for vendor menus. All of our item inventory stuff relies on the `item_menu_result` function
in `gui/menus.rs`. We can update that function to take in a page number so we can calculate which 
items to show. We need to do pretty much exactly what we did for the vendor menu, where we calculate
the start and end index based on the page and slice the item list, then handle the `,` and `.` keys
to properly page the menu. Here is our modified `item_menu_result` function:

```rust
const ITEMS_PER_PAGE: usize = 20;

pub fn item_result_menu<S: ToString>(
    draw_batch: &mut rltk::DrawBatch,
    title: S,
    items: &[(Entity, String)],
    key: Option<rltk::VirtualKeyCode>,
    page: usize,
) -> (ItemMenuResult, Option<Entity>) {
    // Calculate paging
    let start_index = std::cmp::min(page * ITEMS_PER_PAGE, items.len() - 1);
    let end_index = std::cmp::min(start_index + ITEMS_PER_PAGE, items.len());
    let paged_items = &items[start_index..end_index];
    let count = paged_items.len();

    // ... menu box drawing is unchanged

    let mut item_list: Vec<Entity> = Vec::new();
    let mut item_num = 0;
    for item in paged_items {
        menu_option(draw_batch, 17, y, 97 + item_num as rltk::FontCharType, &item.1);
        item_list.push(item.0);
        y += 1;
        item_num += 1;
    }

    match key {
        None => (ItemMenuResult::NoResponse, None),
        Some(key) => match key {
            rltk::VirtualKeyCode::Escape => (ItemMenuResult::Cancel, None),
            rltk::VirtualKeyCode::Comma => {
                if page > 0 && items.len() > ITEMS_PER_PAGE {
                    (ItemMenuResult::PreviousPage, None)
                } else {
                    (ItemMenuResult::NoResponse, None)
                }
            },
            rltk::VirtualKeyCode::Period => {
                if item_num == ITEMS_PER_PAGE && items.len() > ITEMS_PER_PAGE {
                    (ItemMenuResult::NextPage, None)
                } else {
                    (ItemMenuResult::NoResponse, None)
                }
            },
            _ => {
                let selection = rltk::letter_to_option(key);
                if selection > -1 && selection < count as i32 {
                    return (
                        ItemMenuResult::Selected,
                        Some(item_list[selection as usize]),
                    );
                }
                (ItemMenuResult::NoResponse, None)
            }
        },
    }
}
```

We did the following:

- Added a new `ITEMS_PER_PAGE` const like we did for the vendor menus.
- Removed the `count` parameter since we need to page first before calculating that.
- Calculated the paging indexes and sliced the provided items array.
- Used the paged array when iterating over available options.
- Added match statements for the `Comma` and `Period` keys and returned the proper response 
depending on the paging information.

For each of the `gui` files that lit up red, we just need to remove the count parameter and add in
the page parameter that we already passed in when calling the `item_result_menu` function. For 
example, here is the updated call for `gui/drop_item_menu.rs`:

```rust
let result = item_result_menu(
    &mut draw_batch,
    "Drop which item?",
    &items,
    ctx.key,
    page,
);
```

## Testing

In order to test that paging actually works you could go around and collect a butt load of items,
but that sounded really annoying so I'm going to just expand my favorite cheat menu to provide a
"give me all items" option, very similar to how we gave all spells. I will leave that code out since
this post is already super long, you can check out the source code for specifics. It does make the
player VERY encumbered, but it is useful for testing.

# Bigger Menu Box

After gathering every single item in the inventory it became evident our menu box is too small for
some of our items, so we are going to shift over the box and make it a bit bigger. Thankfully that
is super easy, over in our `gui/menus.rs` we just need to adjust the box drawing code in the 
`item_result_menu` code:

```rust
pub fn item_result_menu<S: ToString>(
    draw_batch: &mut rltk::DrawBatch,
    title: S,
    items: &[(Entity, String)],
    key: Option<rltk::VirtualKeyCode>,
    page: usize,
) -> (ItemMenuResult, Option<Entity>) {
    // ... paging logic

    let mut y = (25 - (count / 2)) as i32;
    draw_batch.draw_box(
        rltk::Rect::with_size(5, y - 2, 38, (count + 3) as i32),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHITE), rltk::RGB::named(rltk::BLACK)),
    );
    draw_batch.print_color(
        rltk::Point::new(8, y - 2),
        &title.to_string(),
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );
    draw_batch.print_color(
        rltk::Point::new(8, y + count as i32 + 1),
        "ESCAPE to cancel",
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );

    let mut item_list: Vec<Entity> = Vec::new();
    let mut item_num = 0;
    for item in paged_items {
        menu_option(draw_batch, 7, y, 97 + item_num as rltk::FontCharType, &item.1);
        item_list.push(item.0);
        y += 1;
        item_num += 1;
    }

    // ... the rest of the function
}
```

Now we can fit every item into the menu box, at least for now. We could always add some logic to 
wrap our text in the menu, but I am holding off on that. If you play test this you will notice a
gap: the vendor menus are still small. Our vendor menus use their own logic for displaying what is
available which is annoying when we want to add any new generic menu box logic. So let's centralize
the code and reuse some of our `item_result_menu` code for vendor menus. The main things we want
to reuse are the paging logic, and rendering a standard size menu box. For the menu box we just
need to modify our existing `menu_box` function in `gui/menu.rs` and we can hard code the `x` 
value since we want all of them to be the same size:

```rust
const MENU_X: i32 = 5;
const MENU_WIDTH: i32 = 38;
const MENU_PADDING: i32 = 2;

pub fn menu_box<T: ToString>(
    draw_batch: &mut rltk::DrawBatch,
    y: i32,
    width: i32,
    title: T,
) {
    draw_batch.draw_box(
        rltk::Rect::with_size(MENU_X, y - MENU_PADDING, MENU_WIDTH, width),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHITE), rltk::RGB::named(rltk::BLACK)),
    );
    draw_batch.print_color(
        rltk::Point::new(MENU_X + MENU_PADDING, y - MENU_PADDING),
        &title.to_string(),
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::MAGENTA),
            rltk::RGB::named(rltk::BLACK),
        ),
    );
}
```

Notice we removed the `x` parameter from the function, so we need to go and remove that from everything
calling this function. We have new constants for our menu sizes because magic numbers in code are 
hard to understand and reason about. 

For paging, we can make a super simple utility function that just slices a vector for us in `gui/menus.rs`:

```rust
pub fn page_list<T>(items: &[T], page: usize) -> &[T] {
    let start_index = std::cmp::min(page * ITEMS_PER_PAGE, items.len() - 1);
    let end_index = std::cmp::min(start_index + ITEMS_PER_PAGE, items.len());
    return &items[start_index..end_index];
}
```

This allows us to shorten the `item_menu_result` function, but I will leave that as an exercise for
the reader. I also think it would be really handy to show the item color for each menu option so I
will also edit the `menu_option` function while I am here to take in a color:

```rust
pub fn menu_option<T: ToString>(
    draw_batch: &mut rltk::DrawBatch,
    y: i32,
    hotkey: rltk::FontCharType,
    text: T,
    color: rltk::RGB,
) {
    draw_batch.set(
        rltk::Point::new(MENU_X + MENU_PADDING, y),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHITE), rltk::RGB::named(rltk::BLACK)),
        rltk::to_cp437('('),
    );
    draw_batch.set(
        rltk::Point::new(MENU_X + MENU_PADDING + 1, y),
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
        hotkey,
    );
    draw_batch.set(
        rltk::Point::new(MENU_X + MENU_PADDING + 2, y),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHITE), rltk::RGB::named(rltk::BLACK)),
        rltk::to_cp437(')'),
    );
    draw_batch.print_color(
        rltk::Point::new(MENU_X + MENU_PADDING + 5, y),
        &text.to_string(),
        rltk::ColorPair::new(
            color,
            rltk::RGB::named(rltk::BLACK),
        ),
    );
}
```

This means going into all of the files we edited earlier to add in paging parameters to also use
the `get_item_color` function to get the color we should render. Here is an example for the
`gui/drop_item_menu.rs` file:

```rust
let mut items: Vec<(Entity, String, rltk::RGB)> = Vec::new();
(&entities, &backpack)
    .join()
    .filter(|item| item.1.owner == *player_entity)
    .for_each(|item| {
        items.push((
            item.0,
            get_item_display_name(&gs.ecs, item.0),
            get_item_color(&gs.ecs, item.0),
        ))
    });
```

Now we can basically rewrite the vendor menus and use helper functions for most of the complex stuff.
Here is the rewrite for the `vendor_sell_menu` function in `gui/vendor_menu.rs`:

```rust
const PRICE_X: i32 = 34;

fn vendor_sell_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    _vendor: Entity,
    page: usize,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    let mut draw_batch = rltk::DrawBatch::new();
    let player_entity = gs.ecs.fetch::<Entity>();
    let backpack = gs.ecs.read_storage::<InBackpack>();
    let items = gs.ecs.read_storage::<Item>();
    let entities = gs.ecs.entities();

    let mut inventory: Vec<(Entity, Item)> = Vec::new();
    (&entities, &backpack, &items)
        .join()
        .filter(|item| item.1.owner == *player_entity)
        .for_each(|item| inventory.push((item.0, item.2.clone())));
    let paged_inventory = page_list(&inventory, page);
    let count = paged_inventory.len();

    let mut y = (25 - (count / 2)) as i32;
    menu_box(
        &mut draw_batch,
        y,
        (count + 3) as i32,
        "Sell Which Item? (space to switch to buy mode)",
    );
    draw_batch.print_color(
        rltk::Point::new(8, y + count as i32 + 1),
        "ESCAPE to cancel",
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );

    let mut equippable: Vec<Entity> = Vec::new();
    for (j, item) in paged_inventory.iter().enumerate() {
        menu_option(
            &mut draw_batch,
            y,
            97 + j as rltk::FontCharType,
            get_item_display_name(&gs.ecs, item.0),
            get_item_color(&gs.ecs, item.0),
        );
        draw_batch.print(
            rltk::Point::new(PRICE_X, y),
            &format!("{:.1} gp", item.1.base_value * 0.8),
        );
        equippable.push(item.0);
        y += 1;
    }

    draw_batch.submit(6000).expect("Failed to submit");

    match ctx.key {
        None => (VendorResult::NoResponse, None, None, None),
        Some(key) => match key {
            rltk::VirtualKeyCode::Space => (VendorResult::BuyMode, None, None, None),
            rltk::VirtualKeyCode::Escape => (VendorResult::Cancel, None, None, None),
            rltk::VirtualKeyCode::Comma => {
                if page > 0 && inventory.len() > ITEMS_PER_PAGE {
                    (VendorResult::PreviousPage, None, None, None)
                } else {
                    (VendorResult::NoResponse, None, None, None)
                }
            }
            rltk::VirtualKeyCode::Period => {
                if count == ITEMS_PER_PAGE && inventory.len() > ITEMS_PER_PAGE {
                    (VendorResult::NextPage, None, None, None)
                } else {
                    (VendorResult::NoResponse, None, None, None)
                }
            }
            _ => {
                let selection = rltk::letter_to_option(key);
                if selection > -1 && selection < count as i32 {
                    return (
                        VendorResult::Sell,
                        Some(equippable[selection as usize]),
                        None,
                        None,
                    );
                }
                (VendorResult::NoResponse, None, None, None)
            }
        },
    }
}
```

The major changes here were:

- Changed how we collect the inventory to add everything to a vector so our `page_list` function
could work on it properly. This required restructuring some other code since we are collecting
different things now.
- Used the `menu_box` and `menu_option` helper functions for most of the drawing.
- Used the `get_item_display_name` and `get_item_color` function to make sure we render items in an
easy to read way.
- Made a constant for where to draw the gold value since it was drawing it over the player HUD
before. The value of `34` works pretty well, but there are still some instances of the item name
overflowing and getting lost behind the value, but we can deal with that later.
- Minor tweaks to the comma and period key checking to use new values.

The buy menu is even easier:

```rust
fn vendor_buy_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    vendor: Entity,
    page: usize,
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
        "Buy Which Item? (space to switch to sell mode)",
    );
    draw_batch.print_color(
        rltk::Point::new(8, y + count as i32 + 1),
        "ESCAPE to cancel",
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );

    for (j, sale) in paged_inventory.iter().enumerate() {
        menu_option(
            &mut draw_batch,
            y,
            97 + j as rltk::FontCharType,
            &sale.0,
            rltk::RGB::named(rltk::WHITE),
        );

        draw_batch.print(
            rltk::Point::new(PRICE_X, y),
            &format!("{:.1} gp", sale.1 * 1.2),
        );
        y += 1;
    }

    draw_batch.submit(6000).expect("Failed to submit");

    // ... key match logic is unchanged
}
```

We did basically the same thing here, using our shared utility functions to draw the menu in a more
consistent way and for paging the list properly. 


# Instructions 

If you play test it now, we have much more consistent menus! Finally! Wow this took a lot longer 
than I thought. There is however one more thing I want to do. We don't have anywhere to tell the
user how to page through the menus which is not great. We have our `ESCAPE to cancel` indicator, so
we should extend that a bit and make a helper function that can render help text (because the vendor
menu and the item menu have different button options, namely the vendor menu allows pressing the 
space bar). Over in `gui/menus.rs` let's make a function that can render a decent help menu:

```rust
const HELP_WIDTH: usize = 25;

pub fn help_menu(draw_batch: &mut rltk::DrawBatch, y: i32, extra_options: Vec<(&str, &str)>) {
    print_help_text(draw_batch, y, ("ESC", "Cancel"));
    print_help_text(draw_batch, y + 1, (",", "Previous Page"));
    print_help_text(draw_batch, y + 2, (".", "Next Page"));
    for (j, option) in extra_options.iter().enumerate() {
        print_help_text(draw_batch, j as i32 + y + 3, *option);
    }
    draw_batch.print_color(
        rltk::Point::new(MENU_X + MENU_PADDING, extra_options.len() as i32 + y + 3),
        format!("└{:width$}┘", "", width=(MENU_WIDTH - 5) as usize),
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );
}

fn print_help_text(draw_batch: &mut rltk::DrawBatch, y: i32, option: (&str, &str)) {
    let command_text = format!("({}):", option.0);
    draw_batch.print_color(
        rltk::Point::new(MENU_X + MENU_PADDING, y),
        format!("├ {:mid_width$}{:right_width$}┤", command_text, option.1, mid_width=7, right_width=HELP_WIDTH),
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::YELLOW),
            rltk::RGB::named(rltk::BLACK),
        ),
    );
}
```

The `help_menu` function is what we will provide to our GUI menus. The user of the function passes
in the draw batch for the menu, the y position for the help menu, and a vector of extra help options
if you need them (like the spacebar for vendor menus). The pair is the expected key and the help text
for each option. The function prints the three common commands first, then loops through any provided
extra options and draws them to the screen. Since we don't know the length of both the expected key
and the help text, we use some handy parameters to the `format!` macro that allow us to pad out
the strings we are putting in there. 

To actually use this new help menu we can modify our `menu_box` function since that has most of what
we need to render the help menu. In `gui/menus.rs` we modify our `menu_box` function to be the 
following:

```rust
pub fn menu_box<T: ToString>(
    draw_batch: &mut rltk::DrawBatch,
    y: i32,
    width: i32,
    title: T,
    help_options: Vec<(&str, &str)>,
) {
    draw_batch.draw_box(
        rltk::Rect::with_size(MENU_X, y - MENU_PADDING, MENU_WIDTH, width),
        rltk::ColorPair::new(rltk::RGB::named(rltk::WHITE), rltk::RGB::named(rltk::BLACK)),
    );
    draw_batch.print_color(
        rltk::Point::new(MENU_X + MENU_PADDING, y - MENU_PADDING),
        &title.to_string(),
        rltk::ColorPair::new(
            rltk::RGB::named(rltk::MAGENTA),
            rltk::RGB::named(rltk::BLACK),
        ),
    );
    help_menu(draw_batch, y + width - MENU_PADDING, help_options);
}
```

We need to fix our `item_menu_result` usage of this function now. Our item result menus don't use
any extra options, so we can just pass an empty vector:

```rust
pub fn item_result_menu<S: ToString>(
    draw_batch: &mut rltk::DrawBatch,
    title: S,
    items: &[(Entity, String, rltk::RGB)],
    key: Option<rltk::VirtualKeyCode>,
    page: usize,
) -> (ItemMenuResult, Option<Entity>) {
    let paged_items = page_list(items, page);
    let count = paged_items.len();

    let mut y = (25 - (count / 2)) as i32;
    menu_box(draw_batch, y, (count + 3) as i32, title, Vec::new());
    // ... the rest of the function is unchanged
}
```

Over in our `vendor_menu.rs` we can modify our two uses of the `menu_box` function to also include
our space bar option, as well as remove that extra instruction from the title. In our 
`vendor_sell_menu` we can use this:

```rust
fn vendor_sell_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    _vendor: Entity,
    page: usize,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    // ... beginning of function unchanged

    let mut y = (25 - (count / 2)) as i32;
    menu_box(
        &mut draw_batch,
        y,
        (count + 3) as i32,
        "Sell Which Item?",
        vec![("SPC", "Buy Menu")],
    );

    // ... end of function is unchanged
}
```

We can do something very similar in the `vendor_buy_menu` function:

```rust
fn vendor_buy_menu(
    gs: &mut State,
    ctx: &mut rltk::BTerm,
    vendor: Entity,
    page: usize,
) -> (VendorResult, Option<Entity>, Option<String>, Option<f32>) {
    // ... beginning of function unchanged

    let mut y = (25 - (count / 2)) as i32;
    menu_box(
        &mut draw_batch,
        y,
        (count + 3) as i32,
        "Buy Which Item?",
        vec![("SPC", "Sell Menu")],
    );

    // ... end of function unchanged
}
```

Now we can finally leave the in-game menus alone! Yay! Notice I said "in-game" there, because there
is yet another menu change I want to make. I want to add an options menu so we can tweak the various
sound effect volumes, as well as potentially add other options for modifying our game. I was going
to add that to this tutorial, but since it is so freaking long I will save it for the next one. We
can just enjoy our new amazing menus...for now.
