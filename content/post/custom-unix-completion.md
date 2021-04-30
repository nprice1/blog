+++
title = "Custom Unix Tab Completion Function Zsh"
date = "2018-03-04T10:54:24+02:00"
draft = false
tags = ["unix", "bash"]
+++

I have been getting super into command line tools recently. I have often been made fun of at work for using git
on the command line when it is "so much easier" using a GUI. I have tried a few, but I hate not knowing exactly what
is happening at any given moment even though it is pretty easy to guess. That's when I found 
[tig](https://github.com/jonas/tig), and it was the best of both worlds. Highly customizable, gives all the best 
features of a GUI and lets me know exactly which command is being used at any moment. After finding this I figured I 
would look around and see if there were any other command line tools that could make my life easier. 

After a bit of searching, I found [dnote](https://github.com/dnote-io/cli) for taking notes. The way I was originally 
doing this was to just have a text file open somewhere and add to it whenever I run into something. This seemed to cut 
out at least one step in the process so I thought I would try it out. So far I like it a lot, but it was missing a 
vital feature: tab completion. At this point tab completion is just muscle memory, and by the tenth time I tried tab 
completing on the name of a book I was trying to add a note to, I thought it was worthwhile to see how tab completion 
functions work. It turns out it is pretty straight forward, the difficult part is finding all of the right pieces in 
one place. I had the added complication of using zsh for my shell, so it was even more difficult to find everything
I needed. So I thought I would right this up in the hope I save someone the time I spent tracking down this stuff.

The majority of the helpful information here was pulled from [this awesome article](https://github.com/zsh-users/zsh-completions/blob/master/zsh-completions-howto.org) 
which I highly recommend looking over to learn all the syntax and a great explanation of how things work at a lower
level. This is still missing some critical bits (at least it was for me), but it is still a worthwhile read. 

# Step One: Update ~/.zshrc

The first thing you need to do is add the directory you want to use for your custom completion functions to your 
`$fpath`. I also had to add a bit of extra config to initialize compsys before my system started actually using the 
completion functions. I added the following to my `~/.zshrc` file:

```
fpath=(~/completions $fpath)

# compsys initialization
autoload -U compinit
compinit
```

So if I want a custom completion function to be registered, I just need to add a new file in the `~/completions` 
directory and it will get picked up automatically. 

# Step Two: Create Custom Completion File

Since I'm writing a custom completion for my `dnote` command line tool, I just named it `_dnote`. I don't think this is
actually required since you have to add a `#compdef dnote` in the file anyways to say which function this completion 
should be used for, but it seemed clearer to me. 

Now I had to figure out the syntax I needed for my custom completion function. There are a ton of possible ways to 
achieve the same goal, and after digging through a bunch of articles I found the one I considered to be the simplest 
which is just using the `_arguments` keyword. This just informs the shell which options to show based on which argument
you are auto completing. For `dnote`, the first arguments are just the possible commands so I just add those by hand:

```
#compdef dnote
_arguments "1: :(add edit ls remove)"
```

However the part I actually care about is listing my books. `dnote` has a function to list my books, but it adds some 
formatting to the list which I don't care about. So I made a stupid grep command that will read the results of the
`dnote ls` function and only grab the words. After grabbing the words, it needs to put all of the commands on the same
line so I just pipe that into the handy `tr` command that will replace any newline characters with a space:

```
dnote ls | grep -oh "[A-Za-z]\+" | tr '\n' ' '
```

Now that I know a command to grab all the books I care about I can finish my custom completion function. Since the book
is pretty much always the second parameter to the `dnote` function, I'll add my grep command output as the list of 
possible values for the second argument. To do that I just need to wrap it in `$()` to tell the function to execute my
code tidbit. Here is my completed `_dnote` comdef file:

```
#compdef dnote
_arguments "1: :(add edit ls remove)"\
        "2: :($(dnote ls | grep -oh "[A-Za-z]\+" | tr '\n' ' '))"
```

That's it! Now you're ready to tab complete like the wind. And the wind tab completes a lot. 