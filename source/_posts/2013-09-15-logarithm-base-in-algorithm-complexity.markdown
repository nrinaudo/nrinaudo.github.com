---
layout: post
title: "Logarithm base in algorithm complexity"
date: 2013-09-15 11:15
comments: true
categories: complexity
---
Dear future self,

I was reading up on algorithm complexity and found a paragraph that casually tossed the following bit of information:
if an algorithm's complexity contains a logarithm, its base is irrelevant.

This was not demonstrated in any way, just left for the reader to accept. In hindsight, that's probably because it
should be obvious to anyone with some level of familiarity with logarithms, but it wasn't to me and I set out to
understand and prove that assertion.

<!-- more -->


## Constants in algorithm complexity

The first step to understanding the irrelevance of a logarithm's base when expressing algorithm complexity is to
remember that constants are considered irrelevant: a complexity of `2N` is expressed as `N`.

With that in mind, we "just" need to prove that logarithms with different bases are linked together by a constant:

$$\forall i,j \, \exists c_{ij} \mid \forall x \, log_i(x) = c_{ij} * log_j(x)$$



## Linking two logarithms with different bases

Finding this $c_{ij}$ constant turns out to be surprisingly easy, even for someone whose math skills are as rusty as
mine.

Let's start from the definition of a logarithm:
$$y = log_i(x) \Leftrightarrow x = i^y \Leftrightarrow x = i^y \Leftrightarrow log_j(x) = log_j(i^y) \\
\Leftrightarrow log_j(x) = y * log_j(i)$$

Replacing `y` by its actual value, we get:
$$log_j(x) = log_i(x) * log_j(i)$$

Which allows us to state what we set out to prove:
$$\forall i,j,x \, log_j(x) = log_j(i) * log_j(x)$$
