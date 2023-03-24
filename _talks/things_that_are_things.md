---
title: Thins that are things, but not other things
layout: talk
slides: https://nrinaudo.github.io/things-that-are-things/#1
article: things_that_are_things
date: 20230223
---

When learning things, I find it useful to have concrete example to help build an intuition.

The problem with this approach when explaining categorical abstractions is that a lot of types most developers are used to working with are Monads, and thus, all of the other things as well. Not having concrete examples of things that are, say, a Functor but not an Applicative, makes it harder to build an intuition of the difference between the two.

This talk is an experiment to see whether such examples are, in fact, useful. We will carefully build examples of common abstractions, see what makes them work, and attempt to break that. The hope is that understanding what needs to happen for a Functor to also be an Applicative will make it clearer what those two things are, what they share and, more importantly, what distinguishes them.
