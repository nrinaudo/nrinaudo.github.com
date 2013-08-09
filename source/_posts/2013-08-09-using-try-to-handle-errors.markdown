---
layout: post
title: "Using Try to handle errors"
date: 2013-08-09 16:20
comments: true
categories: scala
---
Dear future self,

While working on my current [pet project](https://github.com/nrinaudo/eshitsuji), I found out about Scala's
[Try](http://www.scala-lang.org/api/current/index.html#scala.util.Try) construct. I'm still coming to grips with it, but
it feels like [Option](blog/2013/05/13/scalas-option/) for error handling, which is a good thing in my books. This post
is meant as a brain dump of what I've understood so far.

<!-- more -->


## Purpose
An instance of `Try` represents the result of an action, either its failure (`Failure[Throwable]`) or its success
(`Success[T]`).

Instances of `Try` are typically retrieved through the companion object's `apply` method:
```scala
import scala.util.{Try, Failure, Success}

// Wraps String.toInt in Try.apply.
// Note that thanks to Scala's syntactic sugar, this looks just like a 'normal' block.
def safeToInt(str: String) = Try {str.toInt}

// Prints 'Success(42)'
println(safeToInt("42"))

// Prints 'Failure(java.lang.NumberFormatException: For input string: "fish")'
println(safeToInt("fish"))
```



## Default values
Just as with `Option`, instances of `Try` make it easy to provide default values in case of failure:

```scala
// getOrElse is used to provide a default value (through a by-name parameter).
def safeToInt(str: String) = Try {str.toInt} getOrElse 0

// Prints '42'
println(safeToInt("42"))

// Prints '0'
println(safeToInt("fish"))
```



## Pattern matching
Instances of `Try` are convenient to manipulate through pattern matching:
```scala
def safeToInt(str: String) = Try {str.toInt} match {
  case Success(i) => println("Success: %d" format i)
  case Failure(e) => println("Failure: %s" format e.getMessage)
}

// Prints 'Success: 42'
safeToInt("42")

// Prints 'Failure: For input string: "fish"'
safeToInt("fish")
```

Note that this isn't significantly less work than an old-fashionned `try / catch` block, though.



## Branching
Just as with `Option`, instances of `Try` can be used for executing different code depending on success or failure
through the `map / getOrElse` construct:
```scala
def safeToInt(str: String) = Try {str.toInt} map {i =>
  println("Success: %d" format i)
} getOrElse {
  println("Failure")
}

// Prints 'Success: 42'
safeToInt("42")

// Prints 'Failure'
safeToInt("fish")
```

Again, this isn't much better than a `try / catch` block. It does get much better, however, when you have multiple
instances of `Try` to deal with.



## Interraction with for-comprehensions
Since `Try` defines both `map` and `flatMap`, it can be used in
[for-comprehensions](blog/2013/04/25/scalas-for-comprehension/) (or in nested `map` / `flatMap` calls, depending on
your preference):
```scala
// This is where Try really shines: all possible errors are handled and passed back to the caller,
// with a minimum of actual code written.
def sum(a: String, b: String) = for(i <- Try {a.toInt};
                                    j <- Try {b.toInt}) yield i + j

// Prints 'Success(3)'
println(sum("1", "2"))

// Prints 'Failure(java.lang.NumberFormatException: For input string: "fish")'
println(sum("1", "fish"))
```

A more generic version of the `sum` function could be written like this:
```scala
// Recursively goes through all entries in args, attempts to parse as them integers
// and returns their sum (or Failure if an error occurred).
def sum(args: List[String]): Try[Int] = args match {
  case head :: rest => for(a <- Try {head.toInt}; b <- sum(rest)) yield a + b
  case Nil          => Success(0)
}

// Prints 'Success(6)'
println(sum(List("1", "2", "3")))

// Prints 'Failure(java.lang.NumberFormatException: For input string: "fish")'
println(sum(List("1", "2", "fish")))
```



## Other toys
`Try` has a few other toys that make its usage pleasant. Among them, the possibility to transform an instance of
`Try` to an instance of `Option` in a single call:
```scala
def safeToInt(str: String) = Try {str.toInt}.toOption

// Prints 'Some(42)'
println(safeToInt("42"))

// Prints 'None'
println(safeToInt("fish"))
```

Another nice method is `filter`, which transforms a `Success` into a `Failure` if some criteria isn't met:
```scala
def toPositiveInt(s: String) = (Try {s.toInt} filter {_ > 0})

// Prints '42'
println(toPositiveInt("42"))

// Prints 'Failure(java.util.NoSuchElementException: Predicate does not hold for -42)'
println(toPositiveInt("-42"))

// Prints 'Failure(java.lang.NumberFormatException: For input string: "fish")'
println(toPositiveInt("fish"))
```

Finally, `recover` deserves a mention: it takes a [partial function](/blog/2013/08/03/partial-functions/) that allows
callers to react to some specific types of failure.
```scala
def safeToInt(str: String) = Try {str.toInt} recover {case e: NumberFormatException => println("Error"); 0}

// Prints 'Success(42)'
println(safeToInt("42"))

// Prints 'Error\nSuccess(0)'
println(safeToInt("fish"))
```


## Usage in public APIs
I feel that using `Try` as a return type for public functions in an API is bad form: it transforms an unchecked
exception (the cause of the `Failure`) into a checked one - after a fashion, anyway: the caller *must* deal with the
failure and cannot ignore it as he would an unchecked one.

In such circumstances, I think it's better to use an exception and let the caller wrap it in a `Try` block if he needs
to.
