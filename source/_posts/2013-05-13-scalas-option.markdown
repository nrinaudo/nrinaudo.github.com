---
layout: post
title: "Scala's Option"
date: 2013-05-13 16:28
comments: true
categories: scala
---
Dear future self,

I used Scala's [`Option`](http://www.scala-lang.org/api/current/index.html#scala.Option) for the first time today, and
found it confusing enough that I thought I'd write a quick post
about it.

<!-- more -->

## Purpose
An instance of `Option` represents an optional value. If the value is set, it's an instance of `Some` - a value set to
10 will be equal to `Some(10)`, for example. If, on the other hand, it isn't set, the value will be equal to `None`.

A typical use case is for methods that might not return a value at all - methods that would return `null` in Java. It
makes things clearer: callers don't need to check against `null` every time, it can be considered (rightly!) to be
an illegal value.

Callers do, however, need to work with the `Option`.

## Retrieving an `Option`'s value
One way in which `Option` is very convenient is default values through the `getOrElse` method:
```scala
// Prints '10'
println(Some(10).getOrElse(0))

// Prints '0'
println(None.getOrElse(0))
```

`Option` is also very pleasant in pattern matching:
```scala
def check(o: Option[Int]) = o match {
  case Some(x) => println("Ok: %d".format(x))
  case None    => println("Problem")
}

// Prints 'Ok: 10'
check(Some(10))

// Prints 'Problem'
check(None)
```

I do however not like `Option` when attempting to compare it to a specific value. Say that you want to check against
`10`, for example. According to the documentation, this is the most idiomatic way of doing it:
```scala
def checkAgainst10(o: Option[Int]) = o.map {_ == 10}.getOrElse(false)

// Prints 'true'
println(checkAgainst10(Some(10)))

// Prints 'false'
println(checkAgainst10(Some(4)))

// Prints 'false'
println(checkAgainst10(None))
```

This might stem from my lack of familiarity with Scala, but I do not find this to be very readable.

The following is still considered ok, but somewhat less idiomatic:
```scala
def checkAgainst10(o: Option[Int]) = o match {
  case Some(10) => true
  case _        => false
}

// Prints 'true'
println(checkAgainst10(Some(10)))

// Prints 'false'
println(checkAgainst10(Some(4)))

// Prints 'false'
println(checkAgainst10(None))

```

That's much easier to understand, but seems like a lot of code for such a simple task.

The only solution I've found that was readable and tight isn't unfortunately very idiomatic, and results in the
creation of a useless `Some` instance:
```scala
def checkAgainst10(o: Option[Int]) = o == Some(10)

// Prints 'true'
println(checkAgainst10(Some(10)))

// Prints 'false'
println(checkAgainst10(Some(4)))

// Prints 'false'
println(checkAgainst10(None))
```

I think, in this instance, I'll probably keep my own counsel and use the more readable solution.
