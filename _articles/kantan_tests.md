---
title:  Direct-style property based testing
layout: series_index
series: kantan_tests
date:   20260101
---

## Motivation

I recently gave a talk on Scala 3's capabilities, and part of my motivating example involved random value generation. This gave me the perfectly reasonable urge to expand on it and design an entire property-based testing library, but alas. I was too busy to take that on at the time - that talk wasn't going to write itself.

I eventually did finish writing it, and [gave it](https://scala.io/sessions/paris-2025/hands-on-direct-style) to a decidedly unconvinced audience, after which I was surprised by the number of people who told me that capabilities were fun and all, but could obviously not be used to solve useful problems. The point was not very well argued, or argued at all, really - I think I was meant to accept no useful code exists that does not involve monads. And if that awkward double negative has you feeling a little dazed - good. That's exactly how I felt in these conversations.

This managed to hit two of my main motivators: the desire to do what I want, not what I should, and the need to prove rude people wrong. Because I'm a strong, confident man.

And so, [kantan.tests](https://github.com/nrinaudo/kantan.tests) was born. A fully capability-based generative testing library (not, after all, a property-based one, more on that later), one that was even more fun to write than all the other property-based testing libraries I wrote before - of which I guarantee there are more than what you're thinking right now.

This series of article goes through that journey, which took me to a very different place from the one I was expecting. I will use these articles to explore the design space of generative testing, wrestle with capabilities and capture checking and come up with patterns for working with them that I feel are worth sharing. Not that I expect them to become the accepted convention, but they work _for me_ and one has to start somewhere, doesn't one.

## A few definitions

I will be using some terms and concepts that readers are expected to be familiar with. Among them:
* _capabilities_: a (currently experimental) technique for encoding effects in Scala 3. I wrote an [entire article](./capabilities.html) on them.
* _capture checking_: a (currently experimental) technique for preventing values from escaping their intended scope. I also wrote [an article](./capture_checking.html) on this.
* _generative testing_: a method for testing software that involves generating random test cases. This is usually opposed to _example-based testing_, in which the output of known scenarios is compared to expected results.
* _property-based testing_: a kind of _generative testing_ where general properties of a system are expressed as universal statements: _for all inputs, xxx is true_. It may surprise you that I did not write an article on this. I did give [a talk](../talks/much_ado_testing.html) though.

## The story so far
