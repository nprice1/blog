+++
subtitle = "Lua Have Mercy"
title = "Tabletop Simulator"
date = "2020-07-16T10:54:24+02:00"
draft = false
+++

I've been playing a ton of [Tabletop Simulator](https://store.steampowered.com/app/286160/Tabletop_Simulator/) lately 
thanks to that jerk COVID-19. The game is awesome, you should go buy it. Playing all the awesome games on there made me
even more excited about my fiancée wanting to make a board game. With Tabletop Simulator, that actually wouldn't be too
hard. It would be time consuming to add all the assets, but I would love to script the game to make setup easier. So I 
decided to try and dip my toes into scripting for Tabletop Simulator. If you want to see the finished product of this
tutorial you can [skip right to the code.](#final-script)

To start, I want to try making buttons. Specifically
I want to try and simulate the wounding mechanic for games like 
[Hellboy: The Board Game](https://www.manticgames.com/games/hellboy/) (which is incredible, go buy that too). This game has
a mechanic where each character has a maximum number of wound tokens that can be placed on their character mat. When that
maximum is reached, the tokens flip to show some detriment the character now has. Since Hellboy has this mechanic, I 
decided to create some custom tiles modeled after Hellboy as a demo.

## Create A Save

Tabletop simulator works off of a save file. Mods in the workshop are simply save files where scripts and assets have been
painstakingly added. So to get started, we will need one of those bad boys. First I loaded the `Custom` game from the
Tabletop Simulator menu. This will allow us to add our custom tiles for testing since it loads in a table. From there, you
need to create a brand new save file. You can do this once you have the `Custom` game loaded by clicking 
`Games -> Save & Load -> Save Game` and entering in a save file name that will help you remember what state this 
particular game will be in. 

I'm going to start by adding some buttons to add and remove wounds from each character 
mat, so I named mine `Button Testing`. Finally, you can't actually save scripts until you have actually loaded into 
your save file, so now you can go to `Games -> Save & Load` and click on the save file you just created. There is probably
a faster way to do this, but I just want to code right now. Which is true for me most of the time. 

## Create Custom Components

We are going to need to create 3 custom components:

1. Character Mat
2. Wound token
3. Wound bag

First let's create the character mat. To do this, we just go to `Objects -> Components -> Custom -> Tile` and use
`https://i.imgur.com/sMnAHZX.jpg` as the top and bottom image URL. Select `Rounded` as the tile type and set the
thickness to `0.10`. That's it, nice and simple. We can do the same thing for the wound token, except change the top URL
to be `https://i.imgur.com/Zqw5VKj.png`and the bottom URL to `https://i.imgur.com/uNfIkfs.png`. Scale up/down both of the
tiles until they are the appropriate size. Now to spawn the bag, just go to `Objects -> Components -> Tools -> Bag` and
drag that onto the table. Clone and drag in a bunch of wound tokens into the bag. Now we are all set up! Make sure to 
update your save file.

## What Shall We Script 

In Hellboy each player gets a character mat with various information about that character such as the special abilities, 
starting items, and the part we care about right now: the wound slots. Each character has their own number of wound
slots where tokens will be placed and flipped when damage is taken. If I were playing Hellboy in Tabletop Simulator, 
adding damage requires going all the way to the wound token bag, pulling out wound tokens, and placing them on the 
character that took damage and/or manually flipping wounds if the slots are already used up. And I also have the 
irrational requirement that the tokens line up on the slots exactly, so it would take me minutes to perform this process 
each time a character takes damage. 

Instead, I want some buttons to hover underneath the character mat that will allow adding and removing wound tokens, and 
will be smart enough to auto flip them when necessary. After skimming the 
[Tabletop Simulator Object API](https://api.tabletopsimulator.com/object/), it looks like we will need to do the following:

1. Create two buttons on the character mat, one for adding wounds and one for removing them.
2. When a wound token needs to be placed, perform one of the following:
    
    1. If there are no wound tokens, then add one in the first slot. 
    2. If there are wounds present and the max has not been reached, shift the new wound token over to be placed in the 
    next open slot. 
    3. If the maximum tokens have been placed, flip the existing wound tokens instead.

That doesn't sound too bad. Time for buttons.

## Buttons
    
We are going to start by adding the character mat that should look like this:

![hellboy character mat](/img/character-mat.png)

I want these buttons to be out of the way of all of the other info on the mat, so I'm going to place them underneath the
mat so they are floating in space. I'm going to add one red one to add wounds, and a blue one to remove them because I like
simple colors. Simple colors for a simple man. 

Creating buttons on objects is super straight forward, we just use the
`createButton()` function for an object and give it the 
[proper parameters](https://api.tabletopsimulator.com/object/#createbutton). Since I want these buttons immediately, I'm 
going to add them in the `onload` event for the character mat object. To do this, you can right click on the Hellboy
character mat and hover over the `Scripting` option and click `Scripting Editor` to use the in-game lua editor. Which is 
super fun to debug with, especially if you're like me and write as many syntax errors as a chimp forced to use a 
typewriter. After a bunch of trial and error to get the positioning of the buttons where I like it, here is the result:

```lua
function onload()
    -- Parameters that create the button
    wound_btn_param = {
        click_function = 'addWound',
        function_owner = self,
        position = {x=-0.7, y=0.25, z=1.1},

        width = 100,
        height = 50,
        font_size = 50,
        label = "+",
        tooltip = "Add wound",
        color = {r=1, g=0, b=0}
    }
    self.createButton(wound_btn_param) -- create add wound button
    -- Parameters that create the button
    minus_btn_param = {
        click_function = 'removeWound',
        function_owner = self,
        position = {x=-0.9, y=0.25, z=1.1},

        width = 100,
        height = 50,
        font_size = 50,
        label = "-",
        tooltip = "Remove wound",
        color = {r=0, g=0, b=1}
    }
    self.createButton(minus_btn_param) -- create button
end

function addWound()
    print("ADD WOUND")
end

function removeWound()
    print("REMOVE WOUND")
end
```

Most likely you will need to change the x, y, and z for the `position` parameter of the buttons to get them where you
want them, but it should look like this at the end:

![character mat with buttons](/img/with-buttons.png)

And they even do stuff when you click them! Now we will make them do cool stuff when we click them.

## Cool Stuff When You Click Them

### Wound Me

Now we want to actually put the wound tokens on the mat when the add wound button is clicked, and remove them when the
remove button is clicked. First I have to get an actual wound token from the bag. To reference another object, you need 
the GUID. Thankfully this is easy to get, you just right click on the `Wound Token` bag, hover over the `Scripting` option 
and click the `GUID: {stuff}` option. That automatically copies the GUID into your clipboard. Now over in our script we 
can use the global `getObjectFromGUID()` function to get the token bag:

```lua
tokenBag = getObjectFromGUID("ba5e10")
```

Once we have a reference to the bag, we can use the `takeObject()` function to pull out individual tokens after we make
sure to give the bag a good shuffle:

```lua
tokenBag.shuffle()
token = tokenBag.takeObject()
```

Once we have a token, we can place it where it needs to go on the character mat. Finding the exact vector to use for 
placing was just trial and error again, there is going to be a lot of that. Now we have our final `addWound()` function:

```lua
function addWound()
    tokenBag = getObjectFromGUID("ba5e10")
    boardPosition = self.getPosition()
    tokenBag.shuffle()
    token = tokenBag.takeObject()
    token.setPosition(boardPosition + Vector(-3.25, 0.25, -2.35))
end
```

Sweet! Now a wound token ends up where it needs to be! Except for one bummer, if I grab and move that character mat, that
token is going to do its own thing. I tried using the `addAttachment()` function to fix this, but I ran into some issues
that you can read about [here](#attachments) if you want. Instead of using attachments, my quick and dirty solution is
to just lock the character mat and the token as soon as one is added: 

```lua
function addWound()
    self.lock()
    tokenBag = getObjectFromGUID("ba5e10")
    boardPosition = self.getPosition()
    tokenBag.shuffle()
    token = tokenBag.takeObject()
    token.setPosition(boardPosition + Vector(-3.25, 0.25, -2.35))
    token.lock()
end
```

Now those jerk players can't mess with our wonderful token placement. Unless of course they rotate the mat before adding
a wound, but if they do that we can just flip the table. Win win. 

### Unwound Me

Now let's take that wound off. With our code now this is impossible, since we have no way to reference the token that
was just added. So we shall use a global table to keep track of the wounds! What could go wrong?! Everything? Probably.
Especially since we will be keeping track of this using a Lua table which is everything and nothing at the same time and
I hate it. 

To add a global we just add the following to the very top of our script:

```lua
wounds = {}
```

And then we will insert our wound in our `addWound()` function:

```lua
function addWound()
    self.lock()
    tokenBag = getObjectFromGUID("ba5e10")
    boardPosition = self.getPosition()
    tokenBag.shuffle()
    token = tokenBag.takeObject()
    token.setPosition(boardPosition + Vector(-3.25, 0.25, -2.35))
    token.lock()
    table.insert(wounds, token)
end
```

Now we can use the `remove()` function of a table to just pop the last wound of, unlock it, and put it back in the bag:

```lua
function removeWound()
    tokenBag = getObjectFromGUID("ba5e10")
    lastToken = table.remove(wounds)
    lastToken.unlock()
    tokenBag.putObject(lastToken)
end
```

And it works like a charm! I can add a wound, then remove it! And then I click it when there isn't a token on the mat and
I get a lovely error. So we need to make sure we don't try to remove a token if it doesn't exist. We can do that by just
keeping track of how many wounds we have added. We can do that by adding a new global value at the top of the script:

```lua
wounds = {}
numWounds = 0
```

**NOTE** I could just get the size of the `wounds` table for the number of wounds, but since we have complex state
where adding a new wound might flip an existing one, I'm just doing the quick and dirty method. 

This will require updating our `addWound()` function:

```lua

function addWound()
    self.lock()
    tokenBag = getObjectFromGUID("ba5e10")
    boardPosition = self.getPosition()
    tokenBag.shuffle()
    token = tokenBag.takeObject()
    token.setPosition(boardPosition + Vector(-3.25, 0.25, -2.35))
    token.lock()
    table.insert(wounds, token)
    numWounds = numWounds + 1
end
```

We can use that constant to check if we have wounds, and only remove them if some are there:

```lua
function removeWound()
    if numWounds > 0 then
        tokenBag = getObjectFromGUID("ba5e10")
        lastToken = table.remove(wounds)
        lastToken.unlock()
        tokenBag.putObject(lastToken)
    end
end
```

Sweet! Now it will remove wounds only if they exist. We are awesome programmers. 

### More Wound Me

So we can add and remove one wound now, but we suck at this game and more wounds are going to be inevitable. So let's 
figure out how to add a bunch of wounds. First through trial and error (shocking) I determined the placement for each tile 
is about `0.9` apart, so using the `numWounds` value from earlier it is easy to figure out where to place 
each wound:

```lua
function addWound()
    self.lock()
    tokenBag = getObjectFromGUID("ba5e10")
    boardPosition = self.getPosition()
    tokenBag.shuffle()
    token = tokenBag.takeObject()
    token.setPosition(boardPosition + Vector(-3.25 + (0.9 * numWounds), 0.25, -2.35))
    token.lock()
    table.insert(wounds, token)
    numWounds = numWounds + 1
end
```

### Flip Wound Me

And now since we really suck at this game, we need to make sure we can flip the wound tokens when the maximum is reached.
For Hellboy, the maximum is 6, so when that is passed we need to flip each wound that is not already flipped in our 
`addWound()` function. We will create a new global constant to keep track of the max damage for this character by adding
this to the top of the script:

```lua
MAX_WOUNDS = 6
```

Now our `addWound()` function can determine if we need to add a wound or flip one:

```lua
function addWound()
    self.lock()
    tokenBag = getObjectFromGUID("ba5e10")
    boardPosition = self.getPosition()
    if numWounds >= (MAX_WOUNDS * 2) then
        return
    end
    if numWounds < MAX_WOUNDS then 
        tokenBag.shuffle()
        token = tokenBag.takeObject()
        token.setPosition(boardPosition + Vector(STARTING_X + (WOUND_WIDTH * numWounds), 0.25, WOUND_Z))
        token.lock()
        table.insert(wounds, token)
    else
        adjustedNumWounds = numWounds - MAX_WOUNDS
        token = wounds[adjustedNumWounds + 1]
        tokenPosition = token.getPosition()
        token.unlock()
        token.flip()
        token.setPosition(tokenPosition)
        token.lock()
    end
    numWounds = numWounds + 1
end
```

There are a couple weird things we had to do:

1. Make sure to unlock the token before flipping, then lock it again.
2. We need to set the position again after flipping because flipping makes the token hover farther off the board and
it makes me crazy.

Now our wounds flip! However, we are still cheating because removing a wound will remove a flipped token. Instead, we
need to un-flip tokens until none are flipped, then we remove them. So we just need some very similar flipping logic in
our `removeWound()` function:

```lua
function removeWound()
    if numWounds <= 0 then
        return
    end
    if numWounds <= MAX_WOUNDS then
        tokenBag = getObjectFromGUID("ba5e10")
        lastToken = table.remove(wounds)
        lastToken.unlock()
        tokenBag.putObject(lastToken)
    else
        adjustedNumWounds = numWounds - MAX_WOUNDS
        token = wounds[adjustedNumWounds]
        tokenPosition = token.getPosition()
        token.unlock()
        token.flip()
        token.setPosition(tokenPosition)
        token.lock()
    end
    numWounds = numWounds - 1
end
```

The key difference here is the index difference, where instead of getting the next token we get the last token so we have
`numWounds <= MAX_WOUNDS` rather than `numWounds < MAX_WOUNDS` in our `addWound()` function, and we don't have the offset
when we fetch the token from our `wounds` global. 

## Profit

I now have an awesome character mat that can track its own damage, and when we get our own character sheets I can easily
adjust this code to handle whatever we decide to use for our board game. The next thing I want to tackle is automatically
settting up scenarios, like how `Hellboy: The Board Game` and `Deep Madness` work where there are a series of 
pre-determined scenarios that can be setup. 

## Final Script {#final-script}

Here is our final script ready to be copied into your character mat of choice (with a few globals added):

```lua
WOUND_Z = -2.35
MAX_WOUNDS = 6
STARTING_X = -3.25
WOUND_WIDTH = 0.9

wounds = {}
numWounds = 0

function onload()
    wound_btn_param = {
        click_function = 'addWound',
        function_owner = self,
        position = {x=-0.7, y=0.25, z=1.1},

        width = 100,
        height = 50,
        font_size = 50,
        label = "+",
        tooltip = "Add wound",
        color = {r=1, g=0, b=0}
    }
    self.createButton(wound_btn_param)
    minus_btn_param = {
        click_function = 'removeWound',
        function_owner = self,
        position = {x=-0.9, y=0.25, z=1.1},

        width = 100,
        height = 50,
        font_size = 50,
        label = "-",
        tooltip = "Remove wound",
        color = {r=0, g=0, b=1}
    }
    self.createButton(minus_btn_param)
end

function addWound()
    self.lock()
    tokenBag = getObjectFromGUID("ba5e10")
    boardPosition = self.getPosition()
    if numWounds >= (MAX_WOUNDS * 2) then
        return
    end
    if numWounds < MAX_WOUNDS then 
        tokenBag.shuffle()
        token = tokenBag.takeObject()
        token.setPosition(boardPosition + Vector(STARTING_X + (WOUND_WIDTH * numWounds), 0.25, WOUND_Z))
        token.setRotation({x=0, y=180, z=0})
        token.lock()
        table.insert(wounds, token)
    else
        adjustedNumWounds = numWounds - MAX_WOUNDS
        token = wounds[adjustedNumWounds + 1]
        tokenPosition = token.getPosition()
        token.unlock()
        token.flip()
        token.setPosition(tokenPosition)
        token.lock()
    end
    numWounds = numWounds + 1
end

function removeWound()
    if numWounds <= 0 then
        return
    end
    if numWounds <= MAX_WOUNDS then
        tokenBag = getObjectFromGUID("ba5e10")
        lastToken = table.remove(wounds)
        lastToken.unlock()
        tokenBag.putObject(lastToken)
    else
        adjustedNumWounds = numWounds - MAX_WOUNDS
        token = wounds[adjustedNumWounds]
        tokenPosition = token.getPosition()
        token.unlock()
        token.flip()
        token.setPosition(tokenPosition)
        token.lock()
    end
    numWounds = numWounds - 1
end
```

## Note: Attachments Didnt Work {#attachments}

I tried using the `addAttachment()` function to make sure the tokens stay attached to the character mat and to avoid the
annoying locking logic. However, the documentation for the `addAttachment()` function states it destroys the object and
creates a new one when it attaches. This means the token we are attaching can't have state different from its initial 
state. For us, it means we couldn't flip a token and attach it, because it would just be destoryed and go back to being 
face down. I could probably get around this by having some state associated with the tokens that is checked on the 
`onload()` function so it can be created as flipped or not, but that sounded way too complicated. 