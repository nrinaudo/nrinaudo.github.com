---
title: Partial Functions
tags: scala
---
Partial functions are something that many (beginner) Scala developers are not aware of. Once you know of them however,
you realise that Scala uses them *everywhere*, and that they can be terribly convenient.

<!--more-->

## Origin of the name
From what I've been able to find, partial functions are originally a mathematical concept. A partial function is one
that is only defined for a subset of its domain (as opposed to a *total* function, which is defined for the entirety
of its domain).

For example, the square root functions is total over ℕ, but partial over ℤ.



## Partial functions in Scala
Scala's partial function are exactly the same as their mathematical counterparts: they're only defined for a subset of
their domain.

In practical terms, a partial function is an instance of `PartialFunction`, which is roughly an instance of `Function1`
with an added `isDefinedAt` method whose purpose is to let callers know whether the function is defined for a particular
value.

One could write a partial version of `math.sqrt` as follows:

```tut:silent
val sqrt = new PartialFunction[Int, Double] {
  // sqrt is only defined for positive numbers.
  def isDefinedAt(p: Int) = p >= 0

  // Should this be called on a negative number, a MatchError would be thrown.
  def apply(p: Int) = p match {
    case a if a >= 0 => math.sqrt(a)
  }
}
```

That's rather a lot of code to write for something that simple, though. As usual, Scala has dedicated syntax to make
this much easier to write: `case` statements.

```tut:silent
// This is strictly equivalent to our previous example, but with much less boilerplate.
// Note that a partial function's type cannot be inferred and needs always be fully declared.
val sqrt: PartialFunction[Int, Double] = {
  case p if p >= 0 => math.sqrt(p)
}
```

As expected, `sqrt` can be called on `4`:

```tut
sqrt.isDefinedAt(4)
sqrt(4)
```

On the other hand, it's not defined for `-4`:

```tut
sqrt.isDefinedAt(-4)
```

And it'll throw a `MatchException` should it actually be called with `-4`:

```tut:silent:fail
sqrt(-4)
```


## Collecting values through partial functions
Partial functions are very handy for classes that support the `collect` method, which acts as a combined `map` and
`filter`:

* any value for which the partial function isn't defined is filtered out
* all other values are replaced by the return value of the partial function


For example:

```tut
List(4, -4, 9, -9, 16, -16).collect {
  case p if p >= 0 => math.sqrt(p)
}
```

As an aside, a `Seq` is an implementation of `PartialFunction`, which has the odd side-effect of allowing us to write
the following:

```tut
List(0, 2, 4).collect(List(4, -4, 9, -9, 16, -16))
```


## Chaining partial functions
Another interesting feature of partial function is that they can be chained together through their `orElse` method,
which is very similar to, and complements nicely, `andThen`.

For example, let's say we have the two following partial functions, one working on odd numbers, the other on even ones:

```tut:silent
// Multiplies all odd values by 2.
val times2: PartialFunction[Int, Int] = {
  case p: Int if p % 2 == 1 => p * 2
}

// Adds 1 to all even values.
val plus1: PartialFunction[Int, Int] = {
  case p: Int if p % 2 == 0 => p + 1
}
```

We can then chain them together as follows:

```tut
List(1, 2, 3, 4, 5, 6).collect(times2 orElse plus1)
```


## Lifting partial functions
Finally, Scala makes it easy to turn a partial function into a total one that returns instances of `Option` and
vice-versa through `PartialFunction.lift` and `Function.unlift`.

Let's first turn `sqrt` into a total function:

```tut
val safeSqrt = sqrt.lift

safeSqrt(4)
safeSqrt(-4)
```

We can then turn it back into a partial function that fails on negative numbers:

```tut
Function.unlift(safeSqrt).isDefinedAt(-4)
```
