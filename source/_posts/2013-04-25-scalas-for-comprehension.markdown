---
layout: post
title: "Scala's for-comprehension"
date: 2013-04-25 15:36
comments: true
categories: scala
---
Dear future self,

Today, I worked out that Scala's for-comprehensions were just syntactic sugar for standard collection operations. That's exactly the kind of knowledge I tend to vaguely remember - just enough to know there's something there, but not enough to be actually useful.

The following post explains the conclusions I came to, should you ever need to refresh your memory.

<!-- more -->

## Generators
Generators are the parts of for-comprehension that are used to produce the data to iterate over. As far as I can tell (that is, it makes sense to me but I haven't been able to get a confirmation one way or the other), anything that inherits from [`FilterMonadic`](http://www.scala-lang.org/api/current/index.html#scala.collection.generic.FilterMonadic) can be used as a generator.


### Without `yield`
In a for-comprehension that doesn't yield anything, generators are transformed into nested `foreach` calls:
```scala
// for-comprehension without a yield statement.
for(x <- 0 until 4;
    y <- 0 until x) {
  println((x, y))
}

// De-sugared version of the for-comprehension.
(0 until 4).foreach {x =>
  (0 until x).foreach {y =>
    println((x, y))
  }
}
```

### With `yield`
When for-comprehension yield values, however, all generators but the last one are transformed into nested `flatMap` calls. The last generator is transformed into a `map` call.

```scala
// for-comprehension with a yield statement.
val f1 = for(x <- 0 until 4;
             y <- 0 until x)
         yield (x, y)

// De-sugared version of the for-comprehension.
val f2 = (0 until 4).flatMap {x =>
  (0 until x).map {y =>
    (x, y)
  }
}

assert(f1 == f2)
```

## Guards

Guards are conditional statements you can put in for-comprehensions that allow you to filter the generators that precede them. They are, rather logically, transformed into calls to `withFilter`:

```scala
// for-comprehension with a guard.
val f3 = for(x <- 0 until 4;
             if x % 2 == 0;
             y <- 0 until x)
         yield (x, y)

// De-sugared version of the for-comprehension.
val f4 = (0 until 4).withFilter {_ % 2 == 0}.flatMap {x =>
  (0 until x).map {y =>
    (x, y)
  }
}

assert(f3 == f4)
```
