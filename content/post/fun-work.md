+++
subtitle = "Make The Dream Work"
title = "Fun Work"
date = "2021-10-10T10:54:24+02:00"
draft = false
tags = [ "programming" ]
+++

Sometimes I hit slumps where I don't enjoy the programming work I'm doing at any given moment. It seems like my backlog is
filled with work I don't want to do and I lose my motivation. So I started to wonder, what makes the work in my queue not
fun? What makes work I've done before fun? I have spent weeks eliminating duplicate Java dependencies to allow migration to 
a new runtime (with plenty of cursing along the way) and actually enjoyed it, when every person who has even a vague idea 
what that would be like would say it sounds absolutely horrible. I also have worked on green field services using brand new
technology and hated it, while others would say that sounds like the dream programming task. It is really hard to figure 
out what is actually fun to work on, so I decided to try writing some stuff down to see if I can land on some more 
concrete(ish) descriptions of work I find fun. Obviously this will be very specific to me and my own interests, but I think
there may be some commonalities that other programmers could also relate to. So enjoy my general ramblings.

## Variety Is The Spice Of Life

Before getting into any specifics, I wanted to preface this by saying just giving a huge backlog of one kind of "fun task" 
I will define is not enough. While some fun tasks have longevity and could last months or even years, spending too long on
one task gets dull after a while. It also discourages "putting a bow on it," meaning getting the project to a state where it
can be taken over by others. That in itself is super fun to me, but may not be for other people. 

## The Tasks

### Bugs

#### Fun

I almost always enjoy fixing bugs (the exceptions are outlined in the not fun section below). They inherently come with a 
very specific definition of done. "When you do this, this bad thing happens. Make this bad thing not happen." These kinds of
fixes are awesome for the high of clearing a ticket out of the queue, because they usually don't require long discussions
or requirement gathering, and they are good opportunities for cleaning up some code while you are there. Fixing bugs in 
legacy systems can be surprisingly fun. Bug squashing can lead you into a huge variety of places in the code, areas you 
might have never ventured before. They are usually a mystery, so you get to play detective for a while, and the 
satisfaction that comes with fixing a bug is simple but effective.

#### Not Fun

I dread intermittent bugs. The errors that occur once in a blue moon, with months and months of potential steps to reproduce
that have only caused it to happen once. Each one its own red herring. This is like being a detective on a cold case, there
were clues one day, but those don't help like they once could have. Fixing these issues is often frustrating and time 
consuming. And working for two weeks on a bug ticket is not good for morale.

### Update This Old System

#### Fun

Reimplementing old systems is my absolute favorite task. In my career, my favorite projects have all been of this flavor. 
These tasks usually go like this: a system does x, y, and z. However, it is complex/slow/not user friendly/satanic/etc. We 
want to reimplement this and do x, y, and z better. How it does x, y, and z is up to the engineers. The reason I love these 
tasks is that, like bugs, the definition of done is crystal clear. We need to do x, y and z. We have to do a little digging 
to find out what "better" means, but in my experience these projects only get the green light when there is at least some 
idea of what "better" means for the project. This allows flexing architectural muscles, cleaning up terminology or concepts 
in the system, and not having to go back and forth constantly to understand how it should behave in every given scenario. 
We already know how it should behave, it should do what the old system did by default. However, we also have the ability to 
say "well the old way sucks, can we change it?" and have the possibility of actually doing that since this is going to be 
a new system rather than a modification to the old one.

#### Not Fun

Making an old system faster usually sucks. When I was in my computer science classes in college, we spent a lot of time 
talking about the efficiency of algorithms. It is a super important topic, but thankfully I usually get to ignore it because
computers are fast man. I aim for making simple to understand algorithms first, then tune performance later. Usually the 
tuning is never required and I can go on with my life, but a lot of times the most critical and complex parts of the system
end up being slow as hell, and need to go faster. You might get lucky, and realize that instead of reading that 40 MB file
every second you could just load it once and Bob's your uncle. Or, you might be elbow deep in code written by some super 
programmer at 2am that is designed to grade differential calculus problems. That one is not so easy to speed up. In my 
experience, these also tend to be the areas where architectural refactors are the most difficult as well. 

### Use This New Technology

#### Fun

Learning new technologies is awesome. It is one of the reasons I became a programmer, I like learning new things. I love it 
when a smart person recommends a technology, the team adopts it, and I get to ramp up with it and start using it knowing 
there are people well versed in the tech to help me when I run into road blocks. I am a hands on learner, so actually using
the new tech is the absolute best way for me to learn it. I don't even mind if the tech is prescribed for me, given of 
course it was prescribed by someone that at least knows a little bit about the problem space. More on that part in the not
fun section below.

This description is pretty vague, so I wanted to give an example. Early in my career, the company I was working for decided
that they wanted to start using Docker to standardize our deployments. We had a few people on the team that were familiar, 
they gave some presentations, made documentation, and walked us through the basics. I got plenty of time to experiment and
try out new things, learn the tech, and I had specific people I could ask for help. All in all a very pleasant learning 
experience. There were definitely some bumps in the road, but since the whole team was committed those were sorted out 
quickly.

#### Not Fun

Being the guinea pig for a new tech has the potential to be fun. However, if it never reaches team-level buy in, it really
sucks to be the only person who knows anything about a new piece of tech. You are now the expert, when in reality you barely
got through the most basic of instructions. All maintenance and future changes fall on you, as well as all the criticism for
the failings of the new tech. Programmers are quick to judge something as terrible, because in tech there are so many 
possible choices for a solution, and all we really see are the crappy parts because the problem is already solved. You might
be thinking "well that should be a POC, then sent up to get team-level buy in." But a POC is just a crappy piece of 
production software. I have never worked on a POC that was not deployed directly to prod once it accomplished the task. As
a programmer, who probably didn't choose the tech to use, I don't want to have to be responsible for getting buy in for the
tech. I just want to use it. 

### Tooling

#### Fun

I love making life easier for people. It is extremely satisfying to eliminate a cause of pain and frustration, and allow a 
team to become more efficient in the process. Not only that, but writing scripts can be fun as hell. It is a good 
opportunity to experiment with new languages, it usually has a very limited set of well defined requirements, and the 
benefit is clear immediately. It's even more fun to work on tooling for people you work with frequently, because then 
what needs to be done becomes more and more clear. You can watch where a given team runs into road blocks, where manual 
processes are done that could be automated, where a simple UI could exponentially increase throughput. Having your own
team be the user base is very fun and collaborative. This is some of my favorite work.

#### Not Fun

Sometimes we think we know better than other people. Part of the job of a software engineer is to innovate and figure out
useful features people haven't even asked for, and that's awesome. But we aren't mind readers. Sometimes we can get so 
detached from the users using our software that we make stuff that isn't even useful. I've seen this many times when 
writing tooling. A given engineer has an idea of how it would be easier, and goes down that rabbit hole for a while, and
comes out with some software. However, when it comes time for others to use it, people are hesitant to change their own 
workflows and the new tool isn't really all that much better than the old way. While it may have been fun to write, writing
a tool no one likes is pretty demoralizing. 

## Collaboration

Calling out these specific tasks as fun or not fun overlooks a pretty major factor for me: collaboration. Most engineers
I work with are lifelong learners, and everyone learns in different ways. However, in my experience the best way to learn 
is to work with others. More and more successful engineers need to know how to communicate effectively, and learn that
everyone can teach you something. Working with a wide variety of people is fun, as is working with a small group of people
that really communicate effectively. Even if my backlog was filled with the fun tasks I described above for years and years,
if I was just off in a bubble by myself it would become quickly not fun. 

## Conclusions

Based on what I've outlined above, I will try and boil down some of the aspects of what makes tasks fun in my favorite form
of information transfer: a bullet list.

- **Clear Requirements:** Moving tickets to done is satisfying as hell. The more I get to do that, the better. And tickets 
with unclear requirements, or the ones that encompass too much stuff and end up in a never ending limbo of moving back and
forth between statuses is not fun.
- **Complete Software:** This one sounds a bit like the last bullet point, but it is a different concept. Something can
meet the requirements, but still not be "complete" in my mind. For me, complete means that when another dev comes to work
on the software, they can do it immediately and without needing to talk to a human. It is incredibly difficult to get to 
that point, and it takes a lot of time, but holy crap does it pay off when it works. I can tell you from experience it is 
not fun to pick up some legacy software one person wrote who is no longer there, and of course who also thought "the code
should be self explanatory." That's all well and good, but things like "who uses this" and "why" are not commonly found
in the code. And those are kind of a big deal to know.
- **Clear Impact:** I like knowing the code I write makes a difference. In larger companies we can be pretty disconnected
from the actual end users, so we may not see the impact of the code we write. We also miss out on the opportunity to see 
where we failed, and learn how to make things better the next time around. This is why I like tooling so much, because 
I can handle interacting with other engineers and people I work with. Interacting with clients though, that can be 
daunting, and I know I'm not the only one who thinks that. My dream would be figuring out a system that allows indirect
communication, while also demonstrating impact. A dream, I know. But a good dream. 
- **Learning:** This is my number one aspect to fun work. I don't care if I have to start debugging a compiler, as long 
as I'm learning new things along the way. And by "things," I mean technology things. I don't want to learn business 
trivia, or how one company does things. I want to learn about how software works as a whole. I want to learn how this
problem was solved by others, so I can add it to my tool belt for future use. Learning how one company does things is not
transferrable. 
- **Collaboration:** I want other people to be working with me. I love parallelizing on work, defining interfaces, and 
getting new perspectives that I didn't think about. 100% of the solutions to problems I have been proud of have been a 
problem I collaborated on, even if it was just a quick whiteboard session to work out the kinks. I am a firm believer that
software written in a bubble is crappy software. Small teams made up of experts in different fields (e.g. frontend and 
backend) that can communicate effectively are by far the most effective teams I've ever been a part of.
