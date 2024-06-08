---
title: The debatably Free monad
layout: talk
article: free_monad
slides: https://nrinaudo.github.io/free_monad/#1
embed: https://www.youtube.com/embed/Yci07bMTcsM
date: 20231024
---

I've meant to understand `Free` for quite a while, but it turns out most resources on the subject are either far too complex for me, or just really bad. I'd essentially given up on it until a friend of mine, known to be particularly fond of pithy statements, told me _`Free` is merely the defunctionalisation of `Monad` in its most uncomfortable configuration_. He didn't add _what's the problem?_ but it was clearly implied.

What's really odd though is that after playing with this for a bit, it turned out to be exactly what I needed to hear to get me unstuck.

This talk is my slightly expanded version of that statement.

Note that I will not attempt to justify that _programs as values_ are a good thing here. It's sort of taken for granted, and if you're not interested in doing that, then you're not really interested in `Free`.
