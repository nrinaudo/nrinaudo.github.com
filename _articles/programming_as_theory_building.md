---
title:  Programming as Theory Building
layout: article
date:   20251008
enabled: false
---

I was recently introduced to Peter Naur's [_Programming as Theory Building_](https://www.sciencedirect.com/science/article/abs/pii/0165607485900328) paper by my friend [Rosa](https://social.vivaldi.net/@RosaCtrl), and enjoyed it enough that I thought I'd write my thoughts down before I inevitably forgot most of them.

It must be noted that the following is _my_ understanding of what Naur is saying, which might be very different from what he actually meant. I might simply misunderstand him, or view his arguments through the prism of today's environment - very different from when the paper was written, in 1985. I do not pretend that this little article is an accurate representation of Naur's views; it merely describes the thoughts I had as a result of reading it.

In this paper, Naur argues that the main output of programming is the knowledge we acquire, and explores the consequences of this.

## A few definitions

### _Programming_

The first thing we need to do is define what is meant by _programming_. I quite like Naur's view (heavily paraphrased):

> Programming is the act of mapping some part of the real world to code. 

If we can agree on this, then surely we must also agree that modifying code is an inherent part of programming: as the world changes, or our understanding of it evolves, we must update the mapping and therefore the code. This is crucially important, because as we'll see later, the special knowledge acquired by a programmer as they write software is a critical part of modifying and maintaining it.

### The _Theory_ of a program

What that knowledge is is a little more nebulous. Naur uses Ryle's [_Theory_](https://en.wikipedia.org/wiki/The_Concept_of_Mind) to define it: the difference between knowing how to perform an activity, and being able to explain it, answer questions about it, and spot patterns or similarities with other activities.

An example of this might be riding a bike: if I know how to ride a bike, I can ride a bike. If I have a Theory of riding a bike, I can explain why my body needs to be positioned in a certain way go gain speed or to make going uphill easier, and I might be able to use some of this knowledge to learn how to ride a motorbike more easily.

One critical aspect of this Theory is that it cannot be transmitted exhaustively to someone else. This part I feel is a little weak in the paper, but it was explained to me by [Rosa](https://social.vivaldi.net/@RosaCtrl) in a way that convinced me.

However much one studies a topic, one will never master it until one engages with it. You can't learn snowboarding in books, but you _can_ read a bunch and then hop on a board, fall down a lot, and then understand _why_ you were told to lower your center of gravity. You can't learn mathematics without writing proofs yourself - or, as the famous saying goes, [_mathematics is not a spectator sport_](https://www.goodreads.com/quotes/7416457-mathematics-you-see-is-not-a-spectator-sport-to-understand).

So I, as a Theory owner, cannot _give_ you that Theory even if I wanted to. I can certainly answer questions and explain thorny bits, saving you a lot of time, but you ultimately cannot acquire it for yourself without performing the activity and building your own version of it.

The Theory of a program is, according to Naur:
- knowing where a specific part of the world is handled in code, or the converse: given some code, knowing which part of the world it implements.
- knowing the project's history, why things were implemented a certain way (and, perhaps more importantly, why they were _not_ implemented another way).
- the ability to spot how changes in the world are similar to things already in the code, and re-use or tweak them to fix our mapping.

## Programming is Theory building

Naur's argument can be summarized to: it is much easier to modify code when one has access to the program's Theory (directly or through one of the original authors).

And surely any programmer with a little experience must agree with that. We've all had to modify somebody else's code at some point, and seen how much easier it was if they were around to answer questions and aim us in the right direction, regardless of how much documentation was available, how clean the code, ... 

This is why I insisted earlier on making _modifying code_ part of the definition of programming: Naur needs it to make having a Theory important. But I don't think this argument is sufficient - it tells us the Theory is helpful, certainly, but it's a bit of a stretch to go from that to it being the _most important_ thing one gets out of writing code. I managed to convince myself it was by adding the following argument.

Most developers have had that experience where they wrote some code, and then for some reason lost it - a bad git rebase, some kind of hardware failure, ... and then found  rewriting the whole thing surprisingly fast and the result better than what got lost. This is so true for me, in fact, that I will sometimes do it on purpose, when I'm not fully satisfied with what I wrote.

In short: 
* creating the Theory from the code is hard (Naur's argument).
* creating the code from the Theory isn't (my addition).

This certainly seems to imply the real output of programming is the Theory we made along the way, which is in striking contrast to the idea that it's in fact code - an idea I've encountered a lot, even if not always explicitly.

## Consequences

This shift in perspective leads to some rather interesting conclusions about things that are considered common sense or best practice in our industry.

### Programming methods

We'll start with what I feel is the weakest consequence, because frankly, the argument confuses me a little. It reads like Naur is generally aggravated at programming method peddlers and just taking a shot at them - which, let us be clear here, I respect both the sentiment and the drive-by shooting, it's just that I'm not sure it really fits with the rest of the paper.

Across the course of their career, a programmer will be exposed to many concepts that fall under the general description of _programming method_. These range from how to write code (TDD, pair programming, ...), to how to think about and organise it (OOP, structured programming...) to how to produce it (agile, waterfall...). Proponents of these methods often argue that their particular favourite is better than others, and advocate their use as a general purpose solution.

We have however concluded that the Theory of a program cannot be expressed, merely possessed. It is thus extremely hard to argue that a method produces a better Theory, or produces it faster: something that cannot be expressed cannot be quantified. And therefore, since no method can convincingly argue it has a positive impact on _the main output of programming_ - or even merely not a negative one - then the choice of one, if any, must be made with other considerations in mind.

Or, in short: any argument that a given programming method is "better" is not talking about programming.

This is not to say that programming methods are useless: practicing a variety of them equips a programmer with mental tools, a library of possible solutions to general shapes of problems, that will help them when devising the Theory of a new program. They serve a clear _educational_ purpose, but no single method is best suited for that task - in fact, it's critical to practice multiple ones in order to maximise a programmer's reserve of intellectual building material.

There remains the question of the responsibility of the choice of a programming method, if any, for a given project. Here, Naur sort of waves his hands and says it must be the programmer's, because only they can pick the right one for the problem at hand. I'm not convinced - surely methods that are more about communication and team organisation, such as agile, should involve project management as well?

### Project ownership

Software will be modified - we are convinced of this enough that it's part of our definition of what programming is. In fact, in my experience, we spend more time updating software than we do writing it in the first place. It therefore seems reasonable that we should try to make modifying software as easy as possible.

One way that has been very common in a lot of places I've worked at was banning the notion of _code ownership_: if no developer owns a specific project, then anybody can be brought to work on it when needed. This can be somebody cheaper, so maintenance is less expensive, or merely somebody available so the "owner" doesn't become a bottleneck.

The problem with that notion isn't the idea itself, but its usual implementation. More often than not, _no code ownership_ seems to mean anybody can work on any code at any time. Including, as is often the case, somebody who doesn't have a Theory of the software being maintained. Whoever's available, really.

If you view programming as a way of producing code, this is fine: so long as it solves the problem at hand, any code will do. And any developer can produce code. Therefore, you can chuck any developer at any problem. QED.

If, however, you agree with he notion of programming as Theory building, then this is problematic. If you don't own the Theory of a particular program, you're very likely to solve the problem in a way that doesn't integrate well with that Theory. And the more this happens, the more chaotic and hard to maintain a codebase becomes - multiple Theories fighting against each other, not meshing well together, competing for supremacy. We've all worked on such codebases, and it's one of the reasons why development teams tend to trend towards _we need to rewrite this from scratch, it's become unmaintainable_.

The correct way of making sure a large pool of developers can work on any project is not to chuck random people at random projects and hope for the best, but to deliberately expose them to the Theory of each project: assign them tasks under the supervision of a Theory owner, who will guide them, answer questions, explain decisions - essentially help them build their own Theory of the program, a Theory that is as close to and compatible with the original one as possible.

This, of course, requires planning and leadership (and, possibly, some familarity with Aesop's work as it relates to the habits of hares and tortoises). It _is_ easier to pretend that developers are resources that can be swapped as events require, which probably explains the popularity of that view. It's just a little unfortunate that it's entirely wrong.

### Outsourcing and Consulting

A related managerial strategy is outsourcing projects, or hiring consultants to help with the programming effort. In view of what we concluded about project maintenance, those are both very risky propositions.

First, outsourcing. There's the obvious scenario of outsourcing the initial development, with code and documentation as deliverables. If we subscribe to the Theory building view, this is an obvious mistake: you pay for programming to be done, but do not get the main output of that activity in the deal. Such software instantly becomes legacy (or, in Naur's words, _dead_): no one with its Theory is around to maintain it, and the cost of "reviving" it is tremendous, arguably higher than writing it from scratch in some cases.

You could could also have a maintenance deal in place, but we've seen that this is only useful if the people doing the maintaining have the program's Theory. Having worked on the other side of the fence, I find that to be the exception rather than the rule: such shops tend to assign whoever's free when a task needs doing, and the programmers trusted to write software from scratch tend to be in high demand and not very available.

Outsourcing, then, is a necessarily bad proposition in the Theory building view - unless, of course, what you really want to outsource is not programming - it could be, for example, responsibility.

Consulting is a little more nuanced. The naive approach - hiring a consultant to deliver software, then letting them go - is essentially the same as outsourcing. It can be made to work, however, if consultants are integrated in the team, and specifically instructed to train others in the ways described in the _code ownership_ section. This seldom happens, for a variety of reasons - the most obvious one being that it goes against the consultant's self interest. Their goal is to be re-hired, and sharing the Theory makes them a lot less necessary - which is rather the point.

There is, anectodaly, one scenario in which I've seen hiring consultants to be highly effective: when they're not hired to work on a project, but to train a team in skills they lack to deliver that project. This brings us back to another argument we made earlier, that programmer education is supremely important in the Theory building view.

### Generative models
Finally, it's a little hard to talk about programming without at least a nod in the direction of LLMs.

LLMs can, when asked a sufficiently precise question, produce code that appears to solve the desired problem (_appears_ here isn't intended to mean that it usually doesn't, merely that it doesn't sufficiently often that it needs to be checked every time). But in the Theory building view, this is... well, it's just bad, isn't it. You get instantly dead code, very much as if you'd outsourced the development of your software.

It's not entirely unreasonable to imagine a world in which the technology progresses enough that LLMs become capable of answering questions about the code they generate, explain design decisions, and modify things in way that is consistent with the underlying Theory. Should this ever be the case, and of course should the cost - financial, ecological, ethical... - not be prohibitive, LLMs could be considered capable of doing a programmer's job (well - of an average programmer's job, since by definition they generate the most likely outcome). That's very many _ifs_, however, and the current trend has me fairly confident that we're a very long way away from being remotely close to that reality.

This isn't meant to dismiss LLMs entirely, however. There are many scenarios in which they can be useful - they're a great tool for education, for example, if you use them as sparring partners for your own ideas and always assume them wrong, or at least in need of being fact checked (very much like a fellow human student), and we've seen how important programmer education was. I can also imagine them to be great at helping gather insights on a given codebase, if trained on it and its dependencies, ... My point is not that LLMs are bad tools, merely bad programmers, since they don't - _cannot_ - deliver the most valuable output of programming.

## Conclusion

The conclusion to all this is fairly simple: if we agree with the Theory building view, which I think we should, then we should start thinking of _programmers_ as the thing to value, not code. It's ok to lose code (if we still have its Theory), but not the programmers with the Theory (even if we still have the code). This upends a great many things large chunks of the industry takes for granted - lines of code as a useful productivity metric! Agile as the only acceptable way! LLMs making developers obsolete!

And I know this sounds a lot like I, a programmer, am concluding that _I am the most important thing in the industry_. This sounds maybe a little biased. But the Theory building view also disagrees with that statement: the asshole programmer, or 10x programmer as he (because he's always a he, isn't he) is sometimes known, hoards the Theory, doesn't participate in education, becomes a bottleneck and one of the reasons programs eventually become unmaintainable or unmaintained.

No, what we're really concluding is that programmers are more valuable than code, _and_ must be responsible for educating and producing other programmers. I, for one, would love a world in which programming is seen more as a craft to be trained in, and for there to be such things as apprentices and journeyman programmers.
