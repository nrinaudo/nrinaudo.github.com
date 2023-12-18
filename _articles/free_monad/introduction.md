---
title: Introduction
layout: article
series: free_monad
date:   20231107
---

I've meant to understand `Free` for quite a while now, but it turns out most resources on the subject are either far too complex for me, or just really bad. I'd essentially given up on it until a friend of mine, known to be particularly fond of pithy statements, told me _`Free` is merely the defunctionalisation of `Monad` in its most uncomfortable configuration_. He didn't add [_what's the problem?_](http://james-iry.blogspot.com/2009/05/brief-incomplete-and-mostly-wrong.html) but it was clearly implied.

What's really odd though is that after playing with this for a bit, it turned out to be exactly what I needed to hear get myself over that hurdle.

This article is a slightly expanded version of my friend's statement. Note that I will not attempt to justify that _programs as values_ are a good thing here. It's sort of taken for granted, and if you're not interested in doing that, then you're not really interested in learning `Free`.

We'll use the *extremely* common example of trying to model a simple command line interface, which can print to stdout and read from stdin. To test our solution, we'll write a simple program that asks a user for their name, then greets them. Something like:

```
What is your name?
> Nicolas
Hello, Nicolas!
```

I know - exciting, right?

To spice things up a bit, we'll also want to be able to provide multiple interpreters for this. The obvious one, of course, running the program, but we'd also like the possibility to write a description of it to a string, for example.
