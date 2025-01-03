---
title:  Programming a language
layout: series_index
series: pl
talk:   pl
date:   20240614
---

In the past couple of years, I've had to implement two (very simple) programming languages for two different companies. I found the experience to be extremely fun, and have thus decided to study the subject a little more in depth - because yes, that is how a reasonable person does it: only after I'm done solving a problem (twice, no less!) will I study how one should actually go about it.

And since it's a fun thing to study, I've started giving informal live coding sessions on the subject at work. This series will follow these sessions, as I find it a good and motivating way to prepare them.

## Why do this?

Other than it being genuinely fun (at least to me!), there's a concrete reason to learn this. Being able to whip up simple domain specific languages for your domain experts to give you solutions in a clear, non-ambiguous form can be a life changer.

In a previous job, I worked on content moderation, where part of the job was automating what expert human moderators did. Of course we had some ML-based solutions, but these are... fuzzy. Sometimes, our moderators wanted to tell us precise things like _if the product is a playstation and it costs less than 100$, this is a known scam and must be rejected_. Things that were too small or transient for models to pick up on in time, but that could trivially be automated if our experts had the means of letting us know.

Initially, this was supremely frustrating. We'd hard-code these rules in our system, but since such scams or patterns tend to change often, we ended up spending more time tweaking rules than maintaining or improving our platform. So we decided to write a simple language that allowed us to write and deploy these rules quickly, which sped things up quite a bit. We could finally spend some time on our actual job, developing a moderation platform.

Eventually however, our experts started complaining. The way we implemented what they described was still too slow - it could take a couple of days after they'd sent an email describing what to do. Or we might get it subtly wrong. And then somebody pointed out - why not provide a surface syntax for our language that these experts could learn? Instead of sending us a long email describing what they wanted us to do, they could write it as an executable description of the solution. Eventually, we wrote the tools necessary for them to do so directly in production.

And just like that, we went from a problem that was threatening the business - platform development was basically at a standstill - to not having to think about it at all. Having written a language in which experts could express themselves directly, we made moderators happy (they were much faster and felt much more empowered), developers happy (maintaining a language is _much_ more fun than endlessly tweaking the same set of rules), and customers happy (the quality and reactivity of our moderation increased drastically).

_This_ is why you might want to learn how to write simple languages. Not just because it's fun, but because it can genuinely make life better for everybody involved.

## A programming language

The first question we should ask ourselves, then, is _what is a programming language?_ My personal, informal and very much unofficial definition is:
> A set of terms and rules to combine them in order to communicate a precise series of instructions to a computer.

These are usually seen in text format, which we traditionally call code. And we pass this code to specialised software to do... stuff with. For example:
- take code and shuffle it around to make it more aesthetically pleasing. We call this _formatting_ code (it is a very good idea and should be part of your CI).
- take code and replace bits of it with semantically equivalent but faster bits. We call this _optimizing_ code.
- take code and rewrite it to equivalent code in a different language. We call this _compiling_ code, or sometimes _transpiling_ (although I don't really understand the subtle difference between the two).
- simulate code and yield whatever value it would return. We call this _interpreting_ code.

We'll hopefully play with all of these before we're done, but our focus will, at least initially, be on interpreters.

Notice how I've been careful to phrase these to make them sound like functions from code to something? We'll call this type of functions _evaluators_ (they turn code into some other _value_), and as with all functions, we must think carefully about their domain and codomain.

All of them take code for input, so we'll need a type to represent code. We could of course do the simple thing of deciding that code is text, and text is usually represented as strings, so code is simply strings. But if you're at all familiar with my work, you know that I'm a bit of a snob when it comes to types and this is simply not good enough - there are infinitely more strings that represent invalid code than valid ones, and we'll need to tighten this a little.


## A note on parsing

Note that at some point, code _will_ be represented as strings - this is how humans interact with it. But in this series of articles we'll just assume that there exists a function from string to whatever better representation we decide on for code. This kind of function is called a _parser_, and while they're very fun and interesting to write, they're not at all what I want to talk about.

Readers are encouraged to write parsers for our toy language, obviously - and we'll be suggesting syntax as we enrich it. But, importantly, our suggested syntax will only be one of the many possible variations one could implement, and this is mostly down to personal preferences. We'll be side-stepping this issue entirely by not mandating a syntax, thus hopefully not ruffling anybody's feathers by suggesting something blasphemous, such as meaningful whitespace.

## References and sources

If some of the material feels familiar, you might have read one or more of the books I'm using for inspiration. These include:
- [Programming Languages: Application and Interpretation](https://www.plai.org/).
- [Crafting Interpreters](https://craftinginterpreters.com/)
- [Structure and Interpretation of Computer Programs](https://mitpress.mit.edu/9780262510875/structure-and-interpretation-of-computer-programs/)

I'm hoping to enrich this list as more books / articles / papers come my way.

## Articles

Here are the parts that I've written so far, and will continue updating so long as I don't get bored:
