---
title:  Writing a programming language
layout: series_index
series: pl
date:   20240614
---

In the past couple of years, I've had to implement two (very simple) programming languages for two different companies. I found the experience to be extremely fun, and have thus decided to study the subject a little more in depth - because yes, that is how a reasonable person does it: only after I'm done solving a problem (twice, no less!) will I study how one should actually go about it.

And since it's a fun thing to study, I've started giving informal live coding sessions on the subject at work. This series will follow these sessions, as I find it a good and motivating way to prepare them.

## Why do this?

Other than it being genuinely fun (at least to me!), there's a concrete reason to learn this. Being able to whip up simple domain specific languages for your domain experts to give you solutions in a clear, non-ambiguous language can be a life changer.

In a previous job, I worked on content moderation, where part of the job was automating what expert human moderators did. Of course we had some ML-based solutions, but these are... fuzzy. Sometimes, our moderators wanted to tell us precise things like _if the product is a playstation and it costs less than 100$, this is a known scam and must be rejected_. Things that were too small or transient for models to pick up on in time, but that could trivially be automated if your experts had the means of letting us know.

Initially, this was supremely frustrating. We'd hard-code these rules in our system, but since such scams or patterns tend to change often, we ended up spending more time tweaking rules than maintaining or improving our platform. So we decided to write a simple language that allowed us to write and deploy these rules quickly, which sped things up quite a bit. We could finally spend some time on our actual job, developing a moderation platform.

Eventually however, our experts started complaining. The way we implemented what they described was still too slow - it could take a couple of days after they'd sent an email describing what to do. Or we might get it subtly wrong. And then somebody pointed out - why not provide a surface syntax for our language that these experts could learn? Instead of sending us a long email describing what they wanted us to do, they could write it as an executable description of the solution. Eventually, we wrote the tools necessary for them to do so directly in production.

And just like that, we went from a problem that was threatening the business - platform development was basically at a standstill - to not having to think about it at all. Having written a language in which experts could express themselves directly, we made moderators happy (they were much faster and felt much more empowered), developers happy (maintaining a language is _much_ more fun than endlessly tweaking the same set of rules), and customers happy (the quality and reactivity of our moderation increased drastically).

_This_ is why you might want to learn how to write simple languages. Not just because it's fun, but because it can genuinely make life better for everybody involved.

## A note on parsing

We will not be writing a parser for the language we create. It's a very fun and interesting exercise, but also mostly irrelevant to what we're talking about: parsing a language, and interpreting the result of that parsing, are two distinct activities, and we'll be focusing on the latter.

Readers are encouraged to write parsers for our toy language, obviously - and we'll be suggesting syntax as we enrich it. But, importantly, our suggested syntax will only be one of the many possible variations one could implement, and this is mostly down to personal preferences. We'll be side-stepping this issue entirely by not mandating a syntax, thus hopefully not ruffling anybody's feathers by suggesting something blasphemous, such as meaningful whitespace.

## References and sources

If some of the material feels familiar, you might have read one or more of the books I'm using for inspiration. These include:
- [Programming Languages: Application and Interpretation](https://www.plai.org/).
- [Crafting Interpreters](https://craftinginterpreters.com/)

I'm hoping to enrich this list as more books / articles / papers come my way.

## Articles

Here are the parts that I've written so far, and will continue updating so long as I don't get bored:
