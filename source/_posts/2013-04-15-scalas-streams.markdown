---
layout: post
title: "Scala's streams"
date: 2013-04-15 15:54
comments: true
categories: scala
---
Dear future self,

Today, I'm going to write down what I understood of Scala's streams, and why the documentation's Fibonacci example works. I'm sure it seems terribly trivial to you by now, but it was quite a struggle for me to get my head around it. I'll write this down here, just in case. Not that you'll need it. You're welcome.

<!-- more -->

## Definition

Rather confusingly, Scala's streams have nothing to do with their Java counterparts. I expected to find byte streams from, say, a file, but a Scala stream is essentially a list whose content is lazily evaluated.

Take, for example:
```scala
val ints: Stream[Int] = 0 #:: ints.map {_ + 1}
```

This declares a collection that contains all integers from 1 to infinity. We'll do a detailled analysis of how that declaration works, but for now, let's focus on the properties of `ints`.

First, only values that have been accessed are stored in memory:

```scala
// Prints "Stream(0, ?)"
println(ints)

// Explicitly requests the elements at position 1 and 2.
ints(1)
ints(2)

// Prints "Stream(0, 1, 2, ?)"
println(ints)
```

Second, value is computed exactly once:
```scala
// I've modified the definition of "ints" to print something whenever
// it's called.
val ints: Stream[Int] = 0 #:: ints.map {
  println("in ints")
  _ + 1
}

// Prints "in ints" a single time.
for(i <- 0 to 10) {ints(1)}
```

The combinations of these two properties make stream very useful when you need to work with lists whose values are expensive to compute, such as the Fibonacci series. Granted, most programmer never actually need to work with Fibonacci series, but it illustrates the point nicely.

On the other hand, stream can clog memory up rather quickly and should be used carefuly - not monitored properly, they are a memory leak waiting to happen.

## Simple declaration
Now that we know what streams do, let's see how to declare them by taking appart our previous `ints` definition:
```scala
val ints: Stream[Int] = 0 #:: ints.map {_ + 1}
```

There are a few points of interest here.

First, the `#::` method. Since it finishes with the `:` character, it's a right-associative operator and the actual call is:
```scala
val ints: Stream[Int] = (ints.map {_ + 1}).#::(0)
```

In order to know what `#::` is, Scala needs to know `ints`' type - that's the reason why it's declared explicitly rather than left for Scala's type inferer to work out.

The `Stream` companion object declares `#::` as an alias to `Stream.cons`:
```scala
val ints: Stream[Int] = Stream.cons(0, ints.map {_ + 1})
```

This returns a stream whose head is `0` and tail is `ints.map {_ + 1}`, and that's where the magic starts happening.

`ints.map {_ + 1}` is a [by-name parameter](/blog/2013/04/11/scalas-by-name-parameters/), which means it will only be evaluated when requested - this is why you can reference `ints`' `map` method before `ints` is defined.

Of course, `Stream`'s `map` method returns another stream:
```scala
// temp is a Stream[Int].
val temp = ints.map {_ + 1}

// As all streams, its head is already known.
// Prints "Stream(1, ?)"
println(temp)

// Its tail, on the other hand, is computed on demand.
// Prints "Stream(1, 2, 3, ?)"
temp(1)
temp(2)
println(temp)
```

And so, to get back to our initial example:
```scala
// This is the most idiomatic declaration.
val ints: Stream[Int] = 0 #:: ints.map {_ + 1}

// Lazily evaluated to "(ints.map {_ + 1})(0)"
// Prints "2"
println(ints(1))
```

## Fibonacci series
This is how the [Scala documentation](http://www.scala-lang.org/api/2.10.1/index.html#scala.collection.immutable.Stream) declares the [Fibonacci](http://en.wikipedia.org/wiki/Fibonacci_number) series:
```scala
val fibs: Stream[Int] = 0 #:: 1 #:: fibs.zip(fibs.tail).map {n => n._1 + n._2}
```

The first thing that needs explaining is the call to `fibs.zip(fibs.tail)`. The `zip` method associates each element of the calling collection with the element found at the corresponding index of the parameter collection and, and this is important, truncates the longer collection if they do not have the same length.

In this case, since `fibs.tail` is equal to `fibs` minus its first element:
* it's guaranteed to contain one less element than `fibs`.
* `fibs.tail(i)` must always be equal to `fibs(i + 1)`.

Which means that `fibs.zip(fibs.tail)` creates a list that associates each element of `fibs` with the next element in the series:
```scala
// I'm using a List[Int] here to avoid the added complexity brought by streams.
val list = 0 :: 1 :: 2 :: Nil

// Prints "(0, 1, 2)"
println(list)

// Prints "(1, 2)"
println(list.tail)

// Prints "((0, 1), (1, 2))"
println(list.zip(list.tail))
```

Or, put another way, the nth element of `fibs.zip(list.tail)` is equal to `(fibs(n -1), fibs(n))`.

The `map {n => n._1 + n._2}` bit simply creates a new stream such that its nth element is equal to `fibs(n) + fibs(n + 1)`. Since it's defined as the third element of `fibs`, we've succesfully defined `fibs` such that its nth element is equal to `fibs(n - 2) + fibs(n - 1)`.

This can be checked:
```scala
val fibs: Stream[Int] = 0 #:: 1 #:: fibs.zip(fibs.tail).map {n => n._1 + n._2}

// Prints "1": fibs(0) + fibs(1)
for(i <- 2 to 100) assert(fibs(i) == fibs(i - 1) + fibs(i - 2))
```

It's worth pointing out that this only works because the first two elements of `fibs` are explicitly defined: it means that for any value of i greater than or equal to 2, we are guaranteed that `fibs(i - 1)` and `fibs(i - 2)` have already been pushed on the stream and we're not going to start a bottomless recursion.
