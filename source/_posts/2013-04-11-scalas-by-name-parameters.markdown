---
layout: post
title: "Scala's by-name parameters"
date: 2013-04-11 17:39
comments: true
categories: scala
---
Dear future self,

You hopefully remember the time when you were attempting to teach yourself Scala with fondness, now that you have mastered the language. Hopefully.

Well, *I*'m still in the middle of it, and just worked out what by-name parameters were and how they could be useful. Feel free to have a read in case you forget - or, equaly likely, want to make fun of your past self for his limited undestanding of what I hope is an obvious concept to you by now.

## Purpose

As far as I can tell, by-name parameters are syntactic sugar for no-arg closure parameters (I *think* these are actually called [thunks](http://en.wikipedia.org/wiki/Thunk_(functional_programming\))). Take the following higher-order function, for example:
```scala
// Prints the value returned by the specified closure.
def printInt(f: () => Int) {println(f())}
```

This function can be quite awkward to manipulate:
```scala
val x = 1

// We'd really like to get rid of the '() =>' bit, which is just noise.
printInt(() => x + 2)

// This isn't legal: x + 2 has a type of Int, not () => Int
printInt(x + 2)
```

That's when you use by-name parameters, a special Scala syntax that allows you to declare implicit no-arg closure parameters.
```scala
// Note the parameter declaration: ': => Int' is what declares a by-name parameter.
def printInt(value: => Int) {println(value)}

// Prints 3.
val x = 1
printInt(x + 2)

// Prints 4.
printInt(4)

// Prints 5.
val f = () => 5
printInt(f())
```

In these 3 examples, the parameter to `printInt` is implicitly wrapped in a `() => Int` closure. Whenever `printInt` tries to access its parameter's value, the closure is executed and its return value used.

It's worth stressing out that, in the previous example, `f()` is not actually called when passed to `printInt` but when implicitly passed to `println`. The following illustrates this more clearly:
```scala
// Added some trace before value is printed
def printInt(value: => Int) {
  println("in println")
  println(value)
}

// Added some trace before 5 is returned.
val f = () => {
  println("in f")
  5
}

// This prints:
// in println
// in f
// 5
printInt(f())
```

## Origin of the name

I find "by-name" to be an odd choice: after all, you're not passing a name at all.

Here's what Scala's designer has to say about it:

{% blockquote Martin Odersky http://scala-programming-language.1934581.n4.nabble.com/Why-quot-by-name-quot-parameters-are-called-this-way-tt1944598.html#a1944599 Why "by-name" parameters are called this way?  %}
I think it dates back to Algol 60. Algol 60's default convention was that the formal parameter would be literally replaced by the actual argument name (I believe the actual argument needed to be a single identifier then) in a procedure's body. This made it possible to evaluate the argument several times as needed and also to change it by assignment. The language also had ''call by value' parameters (that's what's used in almost all other languages), but these were declared with the special keyword `value' in front of them.
{% endblockquote %}

## Usage

TODO: assertions, log.

## Not lazy parameters
It's important to realize that by-name parameters are not lazy parameters, and can only partially be used that way.

Lazy parameters will [hopefully](https://issues.scala-lang.org/browse/SI-240) make it into Scala at some point. They are parameters whose value is only computed when used for the first time, rather than at declaration time, which is great for values that are expensive to compute and not used in all code paths.

The value of by-name parameters, on the other hand, is computed every single time the parameter is referenced. This can have some unexpected and unpleasant side effects, such as in:
```scala
// Simple class whose sole purpose is to increment and return an integer
// whenever its 'value()' method is called.
class Counter {
  var count = 0

  def value() = {
    count += 1
    count
  }
}

// Prints 'value' 'count' times.
def printNTimes(count: Int, value: => Int) = for(i <- 0 until count) println(value)

// This prints:
// 1
// 2
// 3
val counter = new Counter()
printNTimes(3, counter.value())
```
