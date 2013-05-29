---
layout: post
title: "Array-like objects in Scala"
date: 2013-05-29 19:31
comments: true
categories: scala
---
Dear future self,

I finally decided to look at the documentation and understand how to write objects that behave "like arrays" in that
they support calls to `o(index)` and `o(index) = value`

<!-- more -->

It's actually surprisingly simple: any Scala class can be made to behave that way by implementing the `apply` and
`update` methods:
```scala
class Demo {
  def update(i: Int, v: String) = {
    println(s"Setting index $i to '$v'")
  }

  def apply(i: Int) = {
    println(s"Getting index $i")
    0
  }
}

val a = new Demo

// Prints 'Setting index 0 to 'zero''
a(0) = "zero"

// Prints 'Getting index 0'
a(0)
```

Note the use of [String interpolation](http://docs.scala-lang.org/overviews/core/string-interpolation.html), quite
useful for formatting.
