---
layout: post
title: "Scala's for expressions"
date: 2013-04-25 15:36
comments: true
categories: scala
---
Dear future self,

Today, I worked out that Scala's _for expressions_ were just syntactic sugar for a standard set of methods.

That's exactly the kind of knowledge I tend to vaguely remember - just enough to know there's something there, but not
enough to be actually useful.

The following post explains the conclusions I came to, should you ever need to refresh your memory.



<!-- more -->

## Purpose

As a mostly imperative programmer, I'm used to thinking of _for_ as a loop - give it a lower and upper bound, an
increment, and it'll explore all corresponding values.

While you can do the exact same thing with Scala's for expressions, they're also much more generic and closer to Java's
`foreach` loop: they iterate over one or more collections, optionally yielding a result.

When a for expression yields a result, it's known as a _for comprehension_. When it doesn't, it's a _for loop_. I feel
that _for loops_ are viewed with some scorn by the functional community, as they're inherently non-functional: not
having a result, their only usefulness resides in side-effects.



## Anatomy of a for expression

A typical for expression looks like:

```scala
for(x <- 0 until 4; if x % 2 == 0) yield x
```

This is decomposed in three different parts, which I'll explain in more details below:

* a _generator_, used to provide the values being iterated over.
* a _filter_, used to filter out specific values.
* a _yield expression_, used to construct a return collection (in the case of a _for comprehensions_).



## Generators
The generator of our example is `x <- 0 until 4`. The bit to the right of the `<-` is known as the
_generator expression_.

What the generator does is define a `val` (`x`, in our example) and assign it a series of values taken from the
generator expression.

A single for expression can have multiple nested generators:

```scala
for(x <- 0 until 4; y <- 0 until x) yield (x, y)
```

Under the hood, the compiler transforms generators into method calls on the generator expression. The exact method
depends on the type of for expression and the number of generators:

* for _for loops_, all generators are transformed into calls to `foreach`.
* the last (or only) generator of a _for comprehension_ is transformed into a call to `map`.
* all generators but the last of a _for comprehension_ are transformed into calls to `flatMap`.

Our previous example is thus strictly equivalent to:
```scala
(0 until 4) flatMap {x =>
  (0 until x) map {y =>
    (x, y)
  }
}
```

In order to compile, the result value of a generator expression must support the method(s) required for the
transformations we've just described - that is, for example, the generator expression of a for loop must support
`foreach` (but does not need to support either `map` or `flatMap`).

We'll see in the next section that it might also need to support either `withFilter` or `filter`.

Note that while collections are a natural fit for _for expressions_, they're only a subset of what can be manipulated.
The [Option](http://www.scala-lang.org/api/current/#scala.Option) and
[Try](http://www.scala-lang.org/api/current/#scala.util.Try) classes, for example, are often used in conjunction with
_for comprehensions_.

For readers with functional programming background, _for expressions_ are designed in such a way that they're perfect
for manipulating and combining _monads_.


## Filters
_Filters_ are predicates used to filter out some specific values of our generators.

For example:
```scala
for(x <- 0 until 4; if x % 2 == 0; y <- 0 until x) yield (x, y)
```

In this expression, `if x % 2 == 0` is the filter (also known as _guard_). `x % 2 == 0` is a _filter expression_.

Depending on the capacities of the generator, filters are transformed into calls to:

* `withFilter`, if supported.
* `filter`, if not.

Our previous example is thus strictly equivalent to:
```scala
(0 until 4) withFilter(_ % 2 == 0) flatMap {x =>
  (0 until x) map {y =>
    (x, y)
  }
}
```

Being lazy, `withFilter` is the preferred implementation.
