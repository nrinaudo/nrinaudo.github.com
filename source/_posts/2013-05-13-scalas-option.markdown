---
layout: post
title: "Scala's Option"
date: 2013-05-13 16:28
comments: true
categories: scala
---
Dear future self,

I used Scala's [Option](http://www.scala-lang.org/api/current/index.html#scala.Option) for the first time today, and
found it confusing enough that I thought I'd write about it.

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

Note that you sometimes need to return another instance of `Option` rather than the wrapped value. In theses cases, the
`orElse` method is perfect:
```scala
// Prints 'Some(10)'
println(Some(10) orElse Some(0))

// Prints 'Some(0)'
println(None orElse Some(0))
```


## Pattern matching
Instances of `Option` are very pleasant in pattern matching:
```scala
def check(o: Option[Int]) = o match {
  case Some(x) => println("Ok: %s" format x)
  case None    => println("Problem")
}

// Prints 'Ok: 10'
check(Some(10))

// Prints 'Problem'
check(None)
```

Note, however, that this isn't considered very idiomatic - nor is it really necessary, when you can use the
`fold` or `getOrElse` methods to achieve the same effect with much less typing.



## Branching
The `getOrElse` method actually takes a [by-name parameter](/blog/2013/04/11/scalas-by-name-parameters/), which
means it can be used in a rather neat way for branching depending on whether or not the value is set:
```scala
// The function passed to map will be executed if someMethod returns a value,
// the one passed to getOrElse if someMethod returns None.
// This prints 'Value: 10'
Some(10) map {v =>
  println("Value: %s" format v)
} getOrElse {
  println("No value specified")
}
```

The `fold` method is a bit of a shortcut for this construct:
```scala
// The first argument is the function to execute if the option is None.
// The second one will be executed if the option is Some(v)
// This prints 'Value: 10'
Some(10).fold {
  println("No value specified")
} {v =>
  println("Value: %s" format v)
}

```


## Interraction with for-comprehensions
Due to the way [for-comprehensions](blog/2013/04/25/scalas-for-comprehension/) work and `Option` defines the `map` and
`flatMap` methods, it's also possible to write some fairly terse code:
```scala
// For the purpose of this example, conf's apply method returns an Option[String]
// containing the value of the requested configuration variable.
val conf = ...

// uri is an Option[String]: either a Some containing the final URI, or a None if at least one of the requested
// configuration variables is not set.
val uri = for(proto <- conf("protocol");
              host <- conf("host");
              port <- conf("port")) yield "%s://%s:%s" format (proto, host, port)

uri.fold {
  println("Failed to extract a URI")
} {u =>
  println("Extracted the following URI: %s" format u)
}
```

This felt a bit like magic to me at first, so let's dissect it.
At compile-time, the for-comprehension is turned into the following code:
```scala
val uri = conf("protocol").flatMap {proto =>
  conf("host").flatMap {host =>
    conf("port").map {port =>
      "%s://%s:%s" format (proto, host, port)
    }
  }
}
```
The way `Option.flatMap` and `Option.map` work is:

* if called on an instance of `Some`, they'll return another instance of `Some` containing the result of the specified
  function.
* if called on an instance of `None`, they'll return `None`.

Which means that should any of the calls to `conf.apply` in the previous code return `None`, the nested functions won't
be evaluated at all and `None` will bubble back to `uri`.

Say, for example, that `conf("host")` isn't defined:

* `conf("protocol")` returns an instance of `Some[String]`. Calling `flatMap` on it returns the result of evaluating its
  argument.
* `conf("host")` returns `None`. Calling `flatMap` on it returns `None` without evaluating its argument: the whole
  `conf("port")` block isn't executed, and `None` is returned immediately.
