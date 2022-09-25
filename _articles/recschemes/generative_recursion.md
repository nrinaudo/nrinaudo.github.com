---
title: Generative recursion
layout: article
series: recschemes
date:   20210527
---

So far, we have taken a common recursive pattern, structural recursion, and generalised it into a recursion scheme known as a catamorphism. We achieved this through a little bit of creative refactoring and relying heavily on the notion of pattern functor.

I would like to show you that this is basically all you need to know to come up with other recursion schemes.

We'll do so by studying another common recursive pattern, _generative recursion_, whose main purpose is to alleviate the hassle that creating values of recursive data types is.

## Creating ranges


As an example, let's imagine a function that, given an upper bound, will generate a list ranging from that value to 1.

Such a function would commonly be implemented like this:

```scala
def range(
  from: Int
): List = {
  if(from > 0) Cons(from, range(from - 1))
  else         Nil
}
```

The concept is relatively simple: while the input state is not 0, create a cons cell with that value as `head` and the range from the next smallest state as `tail`. Once it reaches 0, end the list.

This behaves exactly like you'd expect:

```scala
mkString(range(3))
// res24: String = 3 :: 2 :: 1 :: nil
```

If you look at it from a higher perspective though, you can see the shape of a more generic pattern:
- given a state, evaluate it against a predicate
- if that predicate holds:
  - transform the state into a next state and a value.
  - create a new list with that value for `head` and the solution of the problem for the next state for `tail`.
- if the predicate doesn't hold, close the list.

You can apply this pattern to solve all sorts of similar problems.

## Extracting character codes

Let's say, for example, that you need to turn a string into a list of its characters, represented as their numerical value - you might be trying to hash it, say, or write it to a raw byte stream.

Here's a possible implementation:

```scala
def charCodes(
  from: String
): List = {
  if(from.nonEmpty)
    Cons(from.head.toInt, charCodes(from.tail))
  else Nil
}
```

This uses the exact same pattern:
- predicate: is the list empty?
- update function:
  - new head: first character of the string as an `Int`.
  - next state: whatever is left of the string.

And this yields the expected result:

```scala
mkString(charCodes("cata"))
// res25: String = 99 :: 97 :: 116 :: 97 :: nil
```

## Key takeaways

Generative recursion is a recursive pattern used to create values of recursive data types.

It's composed of two main parts:
- a predicate that tells us whether to keep building the list or not.
- an update function that yields:
  - the head of the list.
  - the updated state from which to keep recursing.

Knowing these common parts, it'd be nice to generalise generative recursion to parameterize them.
