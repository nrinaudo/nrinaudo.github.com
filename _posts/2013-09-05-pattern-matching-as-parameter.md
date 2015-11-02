---
title: Pattern matching as parameter
tags: scala
---
One of the properties of pattern matches is that, when not used within a `match` statement, they define partial
functions - which makes them legal arguments to higher-order functions.

<!--more-->

To take a concrete example, consider the following code:

```scala
// Unwraps the specified sequence, replacing None by the specified default value.
def unwrap[A](la: Seq[Option[A]], da: A): Seq[A] = la map {va =>
  va match {
    case Some(a) => a
    case None    => da
  }
}
```

The anonymous function passed to `map` is essentially a wrapper for a pattern match. We can transform that into
a partial function and pass it directly to `map`:

```scala
def unwrap[A](la: Seq[Option[A]], da: A): Seq[A] = {
  def mapper: PartialFunction[Option[A], A] = {
    case Some(a) => a
    case None    => da
  }
  la map mapper
}
```

There is little point, however, in using the intermediate `mapper` function. Inlining it yields a much leaner
implementation, free of the boilerplate of the initial version:

```scala
def unwrap[A](la: Seq[Option[A]], da: A): Seq[A] = la map {
  case Some(a) => a
  case None    => da
}
```

Do note that while this example only matches over a single parameter, this is not a requirement. The Scala compiler
has an interesting if somewhat contentious feature that allows it to auto-box multiple parameters into a single tuple.
This allows us to write code such as:

```scala
def foldD[A, B](la: Seq[Option[A]], da: A, init: B, f: (B, A) => B) =
  la.foldLeft(init) {
    // This function takes a single parameter, but foldLeft's "step" function takes 2 (accumulator and value).
    // Scala automatically tuples these, which allows us to pattern match them as follows:
    case (acc, Some(i)) => f(acc, i)
    case (acc, None)    => f(acc, da)
  }
```
