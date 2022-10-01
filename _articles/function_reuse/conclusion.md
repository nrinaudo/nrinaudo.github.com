---
title: Conclusion
layout: article
series: function_reuse
date:   20220908
---

This series had two main goals. First, build a solid intuition for some of the abstractions that, for better or worse, are increasingly becoming synonymous with functional programming. Second, demonstrate a powerful software design technique that has gotten me out of many a sticky situation.

We've learned about *wishful thinking-driven development*, whose point is mostly, but not entirely, about avoiding complex issues by making them somebody else's problem. It is of course slightly more subtle than that, and involves boring notions such as being reasonable in what one wishes for, and designing ways for the people who actually solve problems to communicate their solutions. But, really, the main point is to focus on the problems that we're interested in and delegate the rest to others.

We've seen a first set of abstractions whose main purpose is to take simple functions and re-use them in various, arbitrarily complex contexts:
- `Functor` for functions with a single parameter.
- `Apply` for functions with 1 or more parameters.
- `Applicative` for functions with any number of parameters.

We've also talked about `FlatMap`, which is about working with functions that return a value in some `F` - really, it's about composing such functions.

And finally, we've encountered the dreaded `Monad`, for which we came up with a rather pedestrian definition: an `Applicative` that also happens to be a `FlatMap`.

There is, of course, much more to be said about these abstractions. This series isn't meant to be exhaustive, but to show how they solve common problems and give readers the foundation to learn more on their own.
