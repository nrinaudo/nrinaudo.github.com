---
layout: post
title: "Partial Functions"
date: 2013-08-03 19:14
comments: true
categories: scala
---
Dear future self,

I [recently realised](https://twitter.com/NicolasRinaudo/status/351807385217679360) that partial functions and
partially applied functions were two fundamentally different things. Unfortunately, while I now *know* they're not the
same, I still can't remember which is which.

This post will explore partial functions and how to use them, since I'm tired of looking this up every other week.

<!-- more -->


## Origin of the name
It would appear that partial functions are originally a mathematical concept: they are functions that are only defined
for a subset of the input domain (as opposed to *total* functions, which are defined for the entirety of this domain).

The square root function, for example, is a partial function: `sqrt(x)` is only defined for positive values of `x`.



## Partial functions in Scala
Scala's partial function are exactly the same as their mathematical counterparts: they're only defined for a subset of
their input domain.

In practical terms, a partial function is an instance of `PartialFunction`, which is roughly an instance of `Function1`
with an added `isDefinedAt` method whose purpose is to let callers know whether the function is defined for a particular
value.

One could write a partial version of `math.sqrt` as follows:

```scala
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

```scala
// This is strictly equivalent to our previous example, but with much less boilerplate.
// Note that a partial function's type cannot be inferred and needs always be fully declared.
val sqrt: PartialFunction[Int, Double] = {
  case p if p >= 0 => math.sqrt(p)
}

// Prints 'true'
println(sqrt.isDefinedAt(4))

// Prints '2.0'
println(sqrt(4))

// Prints 'false'
println(sqrt.isDefinedAt(-4))

// Throws a MatchError
println(sqrt(-4))
```


## Collecting values through partial functions
Now that we know what partial functions are, one might wonder what's the point of them. Frankly, I initially thought they
were a bit of an affectation and not terribly useful, until I encountered `Seq`'s `collect` method.

`collect` takes a partial function as a parameter and acts a bit like `map`, but only for values for which its
parameter's `isDefinedAt` method returns `true`.

```scala
val sqrt: PartialFunction[Int, Double] = {
  case p if p >= 0 => math.sqrt(p)
}

val n = List(4, -4, 9, -9, 16, -16)

// Prints 'List(2.0, 3.0, 4.0)'
println(n collect sqrt)
```

As an aside, a `Seq` is an implementation of `PartialFunction`, which has the odd side-effect of allowing us to write
the following:
```scala
val from    = List(4, -4, 9, -9, 16, -16)
val indexes = List(0, 2, 4)

// For each value x of indexes such that from(x) is defined, collect from(x).
// Or, in plain english, extracts the values of from found at the values defined in indexes.
// This prints 'List(4, 9, 16)'
println(indexes collect from)
```


## Chaining partial functions
Another interesting feature of partial function is that they can be chained together through their `orElse` and
`andThen` methods.

`orElse` is used to call another partial function for all values that aren't supported by the first one:
```scala
// Multiplies all odd values by 2.
val times2: PartialFunction[Int, Int] = {
  case p: Int if p % 2 == 1 => p * 2
}

// Adds 1 to all even values.
val plus1: PartialFunction[Int, Int] = {
  case p: Int if p % 2 == 0 => p + 1
}

// This will call times2 for all odd values and plus1 for all even ones.
val chained = times2 orElse plus1

// Prints 'List(2, 3, 6, 5, 10, 7)'
println(List(1, 2, 3, 4, 5, 6) collect chained)
```

`andThen` is used to call another partial function after the first one:
```scala
// This will call plus1(times2(x)) for all odd values of x.
val chained = times2 andThen plus1

// Prints 'List(3, 7, 11)'
println(List(1, 2, 3, 4, 5, 6) collect chained)
```


## Lifting partial functions
Finally, Scala makes it easy to turn a partial function into a total one that returns instances of `Option` and
vice-versa through `PartialFunction.lift` and `Function.unlift`:
```scala
val sqrt: PartialFunction[Int, Double] = {
  case p: Int if p >= 0 => math.sqrt(p)
}

// sqrt throws MatchErrors for negative values. safeSqrt, on the other hand, returns None.
val safeSqrt = sqrt.lift

// Prints 'Some(2.0)'
println(safeSqrt(4))

// Prints 'None'
println(safeSqrt(-4))


// unlift does the opposite operation:
val unsafeSqrt = Function.unlift(safeSqrt)

// Prints '2.0'
println(unsafeSqrt(4))

// Throws a MatchError
println(unsafeSqrt(-4))
```
