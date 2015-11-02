---
title: Binomial Heaps
tags: purely functional data structures, scala, haskell
---

Binomial heaps are a bit more complex than, say, [leftist](/posts/2014-09-08-leftist-heap.html) ones, but still fairly
manageable and with an extremely fast `merge` operation.

<!--more-->

## Overview

## Binomial Trees

A binomial tree is defined recursively as a tree such that:

* a binomial tree of rank `0` contains exactly one element.
* a binomial tree of rank `n` has `n` descendants or ranks `n - 1`, `n - 2`, ..., `0` (in that order).

We also want our binomial trees to be heap-ordered, that is, such that any node's value is smaller than that of its
descendants.

![Fig. 1: A rank 3 binomial tree](/images/binomial-heaps/binomial-tree.svg)

The root of this binomial tree contains 3 descendants, or rank 2, 1 and 0 respectively.

This structures makes it trivial to merge to binomial trees of identical rank `n`: pick the one with the largest value
at its root and stick it as the first descendant of the other. The result is a valid, heap-ordered binomial tree of rank
`n + 1`.


## Binomial Heaps

A binomial heap is a list of binomial trees ordered by ascending rank.

![Fig. 2: A binomial heap](/images/binomial-heaps/binomial-heap.svg)

For insertion & merging, it helps to think of a binomial heap as an integer where bit `b` is lit if the heap contains
a binomial tree of rank `b`.

Merging two binomial heaps is then a simple binary addition, where adding two bits is done by merging the corresponding
trees.
