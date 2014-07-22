---
title: Regular expressions in pattern matching
tags: scala
---
While reading `Regex`'s
[documentation](http://www.scala-lang.org/files/archive/nightly/docs/library/index.html#scala.util.matching.Regex), I
discovered that it had a legal `unapplySeq` implementation. This means that it can be used in pattern matching, which
I'm not sure is going to be terribly useful but is certainly very cool.

<!--more-->

The most immediate use of `Regex`'s `unapplySeq` method is to let us write code like this:
```scala
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

Since extractor (`unapply` or `unapplySeq`) methods can be used at variable declaration time, you can also write things
like:
```scala
val point = "\\(([0-9]+),([0-9]+)\\)".r

// It might be because I haven't seen this pattern enough yet, but I always read this as calling a function
// on variables that haven't been defined yet.
val point(x, y) = "(10,12)"

// Prints '10 / 12'
println("%s / %s" format (x, y))
```

Note that you must be absolutely 100% confident that regular expression will match, as this will throw an exception
otherwise.
