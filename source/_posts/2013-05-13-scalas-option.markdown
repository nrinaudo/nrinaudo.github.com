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

## Default values
One way in which `Option` is very convenient is default values through the `getOrElse` method:
```scala
// Prints '10'
println(Some(10) getOrElse 0)

// Prints '0'
println(None getOrElse 0)
```

I can see this being useful for default configuration values, for example.


## Pattern matching
`Option` is also very pleasant in pattern matching:
```scala
def check(o: Option[Int]) = o match {
  case Some(x) => println(s"Ok: $x")
  case None    => println("Problem")
}

// Prints 'Ok: 10'
check(Some(10))

// Prints 'Problem'
check(None)
```


## Branching
The `getOrElse` method actually takes a [by-name parameter](/blog/2013/04/11/scalas-by-name-parameters/), which
means it can be used in a rather neat way for branching depending on whether or not the value is set:
```scala
def someMethod() = Some(10)

// The function passed to map will be executed if someMethod returns a value,
// the one passed to getOrElse if someMethod returns None.
// This prints 'Value: 10'
someMethod map {v => 
  println(s"Value: $v")
} getOrElse {
  println("No value specified")
}
```
