+++
date = "2018-01-08T10:54:24+02:00"
title = "Practical Software Development"
subtitle = "Coding is Easy, Talking is Hard"
+++

**Disclaimer**: This post is mainly just an attempt to somewhat organize thoughts I've been having lately. Many of the 
points are probably radically obvious and this probably reads as one giant rant, but I'm in a rant mood.  

I have had the opportunity to work in a variety of environments in my career so far. I have worked for a small company
teetering between keeping the lights on and expanding, a small company with a successful product starting to expand, 
and a large company with a well established product looking to maintain while staying competitive. Each of these
environments come with their own quirks when it comes to writing software, but the one unifying factor I've found is
everyone is struggling to understand how things work. Vague terminology, complicated code, developers that get lost
in the tech talk, and oh so much more. This problem stems a lot deeper than just a code level, but for now that's what 
I'll focus on since it has the biggest impact for me.  

# The Problem

While it may seem writing code will present a huge variety of problems to solve, really things boil down to a pretty 
small list. After a few years programming, it becomes far less daunting. It turns out, writing code that
works is pretty freaking easy. The real hard part is understanding the problem. Not only that, but once you do write 
your code to solve that problem how can you make it scalable and above all else **understandable**. I don't care how
slick your custom load balancer is, if I don't understand how it works then you better be prepared to work on it for
life or let me gut it. As the scale of projects I work on goes up, I find myself understanding the code less and less. 
I love frameworks and tools that make coding easier, but not at the cost of understanding. The guy who taught me pretty
much everything I know has a scale for how to write code:    
  
1. Easy to understand
2. Easy to use
3. Easy to implement
  
There should be a huge gap between number 1 and number 2. If you want code to live on, then you need to think about who
will be maintaining it when you move on to bigger and better things. The problem I find is that way too often people 
settle or strive for number 2 or 3. "Automagic" becomes prevalent, and the only way to know how a system weaves 
together is to dive all the way in or get a 5 hour lecture from the person that knows the system the best. So far I
have found two major reasons this tendency crops up.

## The Genius Architect

Frequently the answer I get when I ask why the code is structured in a weird way is "Well that's how <Some Person> 
said to do it, and that guy is basically a deity." While I have met my fair share of deity-level programmers, none of 
them are beyond reproach. We all have a set way of thinking, and it can be very difficult to break out of that. Maybe 
that guy didn't know about a new framework, or he has a personal bias towards the existing code, or a litany of other 
reasons that aren't good enough to make me not want to gut the code. 

This is where communication plays a key role.
Either people are too scared to voice their opinion, they can't articulate their complaints and are thus ignored, or 
they just accept the reasoning of those "smarter" than themselves as gospel. I have gone through all of those internal 
struggles at some point in my career, and so has everyone else I've talked to. Talking to people shouldn't be scary 
(I say to a group made up mostly of introverts), at the very least not talking to people about the shit you do for a 
living. Everyone has stuff they don't know, and admitting that doesn't make you stupid. Pretending like you know it 
when you don't makes you stupid. 

## We Can't Break It

This one is a totally understandable reason, but I hate it. I hate it because I'm going to break stuff, and you are 
just gonna have to deal with it. Having a culture of people that are afraid to touch stuff because it works leads to 
cruft. It leads to a system that has 400 configuration flags that turn off various portions of the system because that
one customer still uses it, and we can't tell them to update. It leads to developers that say "Yeah this is pretty
crappy, but 80% of our system hits it so I never want to touch it." If you want to ride the maintenance train and never
add new features, that's totally fine. If you want to continue to grow, that mentality is broken. When you see a way to
improve the system, hash it out with somebody and do it. Not only that, but if you ever get to the point where a core
piece of functionality is so complicated only one person understands it, it is time to revisit it. 

# A Solution

The most difficult problems I've ever come across in the job have not been how to write code. In fact it's the 
opposite: the biggest problems are when I can think of too much code to write. The times when I'm sitting at my desk 
going through 40 different possible solutions for something and not being able to decide which 
one is the "best." These are the time sinks. The times where a developer spends two days on something they thought 
would take two hours. Just giving in and doing it the simple way seems like the coward's way out, we always want to do 
it the right way. The quickest and easiest way to clear through the fog is to just stand next to a whiteboard and try 
and explain the problem to somebody else. You don't even need to write on the whiteboard if you don't want to, 
the point is to just be away from the computer. No looking at code. Explain to someone else what the actual problem is
and explain your plan for fixing it. If you can't succeed at that, there is no way in hell you will write 
understandable code. You might even be writing code that doesn't solve the problem. Once you fully understand the 
problem and a solution that makes sense to at least one other human, sometimes the code basically writes itself. Bonus
points if you do this with someone that doesn't write code for a living, because then you are forced to avoid getting
into the specifics of the code. 

Some treat a whiteboard session as something that happens when designing a system. Others say it is a last ditch effort
to get unstuck. I would say use it for everything. At the very least, use it anytime you find yourself staring at a 
blinking cursor for any extended length of time. I think everyone has had that weird experience 
where they have been stuck for hours working on a problem and they finally ask for help, only to instantly realize the
solution while explaining the problem. Just talk, the code will come.