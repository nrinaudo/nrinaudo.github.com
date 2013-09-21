---
layout: post
title: "Regular expressions in pattern matching"
date: 2013-09-21 19:00
comments: true
categories: scala
---
Dear future self,

While reading `Regex`'s
[documentation](http://www.scala-lang.org/files/archive/nightly/docs/library/index.html#scala.util.matching.Regex), I
discovered that it had a legal `unapplySeq` implementation. This means that it can be used in pattern matching, which
I'm not sure is going to be terribly useful but is certainly very cool.

<!-- more -->

The most immediate use of `Regex`'s `unapplySeq` method is to let us write code like this:
```scala
import scala.util.matching._

// The usual 2D point class, with a horizontal and vertical coordinate.
case class Point(x: Int = 0, y: Int = 0) {
  // Note the .r at the end of each line, which transforms a string into an instance of Regex
  private val left   = "left ([0-9]+)".r
  private val right  = "right ([0-9]+)".r
  private val top    = "top ([0-9]+)".r
  private val bottom = "bottom ([0-9]+)".r

  // The beauty of pattern matching with regular expressions.
  def handle(s: String): Point = s match {
    case left(p)   => Point(x - p.toInt, y)
    case right(p)  => Point(x + p.toInt, y)
    case top(p)    => Point(x, y - p.toInt)
    case bottom(p) => Point(x, y + p.toInt)
  }
}

// Prints 'Point(-10,5)'
println(Point().handle("left 10").handle("bottom 5"))
```

Another fun use, but one that I don't think I'll be using in live code because of how odd it can be to read, is to
parse and assign variables at definition time:
```scala
val point = "\\(([0-9]+),([0-9]+)\\)".r

// It might be because I haven't seen this pattern enough yet, but I always read this as calling a function
// on variables that haven't been defined yet.
val point(x, y) = "(10,12)"

// Prints '10 / 12'
println("%s / %s" format (x, y))
```
