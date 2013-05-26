---
layout: post
title: "Building immutable collections in Scala"
date: 2013-05-26 16:38
comments: true
categories: scala
---
Dear future self,

I'm turning into a big Scala fan. I'm particularly fond of its predilection for immutable instances, which requires a
bit of brain reorganisation but make things *much* safer.

There are some cases, however, where generating immutable collections can be a bit of a pain - maybe the way their
content is retrieved doesn't lend itself well to recursion, for example.

After some head-scratching and documentation-reading, I seem to have found the proper, clean way of dealing with these
cases: [builders](http://www.scala-lang.org/api/current/index.html#scala.collection.mutable.Builder).


<!-- more -->
A `Builder` is quite simply a mutable instance used to incrementally build an immutable collection. The following example
works with a `Set`, but it seems most (all?) collections support the same construct.

```scala
// Creates a builder used to create an immutable Set[Int]
val builder = Set.newBuilder[Int]

// Builds and retrieves the result.
(0 to 5) foreach {builder += _}
val result = builder.result

// Prints 'Set(0, 5, 1, 2, 3, 4)'
println(result)

// Prints 'true'
println(result.isInstanceOf[collection.immutable.Set[Int]])
```
