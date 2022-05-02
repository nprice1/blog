+++
subtitle = "Software Craftsmanship"
title = "Talking Shop"
date = "2019-07-09T10:54:24+02:00"
draft = true
+++

Writing software is a craft. For some that might be obvious, for others it sounds ridiculous, like I'm giving too much
credit to those of us that do it. Too often I speak to engineers that think anybody can program, all you need to do 
is know how to Google. While that is true to a certain extent, that is a skill few people have. And while it might not
have the same satisfaction as building a tangible object, we are still building things. So if writing software is a 
craft, why are we so obsessed with the building, and not so interested in the refinement? There are obvious differences between writing software and something like woodworking, where aesthetics play a role, 
the budget is much more managable, and little has changed in the technology in the last fifty years. I still think this
is an appropriate comparison, though.

I love building things. Lately I have been spending a lot of time in my garage doing basic woodworking, and it gives a 
sense of satisfaction programming lacks: a tangible outcome. I can hold the result of my labor. I also spend 100 times 
as long doing any part of the project. Part of that is because I'm bad at it, but another part is that there is so much
more focus on refinement. After building the structure I need to sand it and shape it, then stain or paint it, then
touch up any problem area, and apply a finishing coat of some kind. The actual building of the structure is a 
relatively small fraction of the actual work. Yet in software I find it is often the opposite. All I do is build new 
things, I rarely revisit anything "old" even if it was built a few days ago unless I need to tack something new onto 
it. Even then we have to verbalize the "boy scout rule" of cleaning up the code you come across rather than taking the
time to put a bow on it when you build it originally. Everything is a POC, and a POC is just production code with no 
tests. 

A coworker of mine constantly uses analogies when discussing software, and since he is also a fan of building things
these analogies are often related to building something in the shop. I find this to be a very appropriate metaphor the
more I think about it, so I'm going to attempt to beat this metaphor to death and see how far I can take it.

## Code Shop vs. Wood Shop

### Get Some Plans

Let's say a friend asked me to build them a table. Sounds great, I have built some tables before so I have a vague 
idea of what I will need but I need some more details from them. When I ask, they tell me 
    
    "I want it to have four legs, I want it to be big, and I want it to be brown." 
    
Obviously I will need more to be able to even begin to build this table, they haven't told me how big that top will be,
how large the legs will be, if they want it painted or stained which will effect the choice of wood, and a plethora of 
other vital information. When pressed about this, my friend responds with

    "I'll figure those parts out soon, but in the mean time you can get started on the basic structure right?"

And this is where I would say hell no and be done with it. This is a ridiculous scenario, but this has legitimately 
happened (thankfully not often to this extent) in my software career. The requirements are vague but since I have built
things similar to what is requested before, the assumption is I can figure it out as I go. And the worst part is 
engineers can and do say yes to the requests, because through the magic of programming freaking anything is possible. 
Programmers love building things, and for some reason we love guessing requirements even more. 

Let's say I did say yes to my friend's table request. Then, let's say I built a 12x8 foot table with trampoline netting
and springs in the middle. My friend comes back and says

    "You built a trampoline. I asked for a table"

I respond that it meets the provided requirements, and that most likely the users of that table would prefer a 
trampoline anyways because that is way more fun. Again, ridiculous scenario, but again it ACTUALLY HAPPENS in software
because building a software trampoline is freaking easy when you're sitting around twiddling your thumbs and have to 
guess what you are supposed to build. 

So who is in the wrong in this scenario? Everybody. Every. Single. Person. You can't build stuff without clear 
requirements, and crafstsman should perfect the building of what is asked, not guess at what should be built (at least
to a certain extent).

