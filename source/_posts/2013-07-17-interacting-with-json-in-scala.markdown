---
layout: post
title: "Interacting with JSON in Scala"
date: 2013-07-17 21:58
comments: true
categories: scala json
---
Dear future self,

Many of our current projects require me to work with [JSON](http://www.json.org), either as input or as output, for
punctual scripts. If I'm to phase Groovy out in favour of Scala, this is something I need to be able to do comfortably.

After looking at a few libraries, the one I found I liked the most was [Argonaut](http://argonaut.io).

<!-- more -->
## Why not lift-json?
The general consensus seems to be that
[lift-json](https://github.com/lift/lift/tree/master/framework/lift-base/lift-json/) is the best Scala JSON library
out there. It's full of nice features, reportedly fast, has an expressive DSL...

So why not use that?

Well, I've been playing with it, trying to convince myself that it was as good as people said, but I've come to the
conclusion that it's just not for me - it's either not very stable or not coherent enough for my tastes.

Here's an example of the things that have driven me away from lift-json:
```scala
import net.liftweb.json.JsonDSL._
import net.liftweb.json._

implicit val formats = DefaultFormats

// Extracts all values of "count" found in the specified JSON object, returns them as a list of ints.
// Note that we *must* go through a call to children which, while understandable, is just noise to the reader.
def extractCounts(obj: JValue) = (obj \\ "count").children.extract[List[Int]]

// We're expecting List(10) but getting List()
val v1 = ("id" -> 1) ~ ("count" -> 10)
println(extractCounts(v1))

// We're expecting and getting List()
val v2 = ("id" -> 2) ~ ("other" -> 1)
println(extractCounts(v2))

// We're expecting and getting List(11, 12)
val v3 = ("id" -> 3) ~ ("count" -> 11) ~
              ("nested" -> ("id" -> 4) ~ ("count" -> 12))
println(extractCounts(v3))

// We're expecting List(11) but getting List()
val v4 = ("id" -> 3) ~ ("count" -> 11) ~
            ("nested" -> ("id" -> 4) ~ ("other" -> 2))
println(extractCounts(v4))

// We're expecting List(12) but getting List()
val v5 = ("id" -> 3) ~ ("other" -> 3) ~
            ("nested" -> ("id" -> 4) ~ ("count" -> 12))
println(extractCounts(v5))
```

I don't always have full control over the JSON I consume, and if lift-json cannot be trusted to behave coherently on
different (acceptable) variations of a format, I cannot trust it to work in the real world.



## Argonaut
Argonaut describes itself as a purely functional JSON parser and library. I've played with it for a while and have
been able to do everything I wanted - which is more than I can say for other JSON libraries. It took me a while, some
things were hard to get my head around, but if I want to be honest, it's probably got more to do with my inability
to think in functional terms rather than design flaws in Argonaut.

Also, a JSON library called Argonaut. It's too cute not to fall in love with it.

Importing Argonaut in `sbt` is done through:

```scala
libraryDependencies += "io.argonaut" %% "argonaut" % "6.0-RC3"
```


## Basic operations
Creating a JSON object from scratch is done fairly easily through `argonaut.Json.apply` method:
```scala
import argonaut._, Argonaut._

// Clear and both easy to read and write.
// The same result can be obtained through the cons-like construct ->:, but I prefer this style.
val json = Json("id"     := 1,
                "name"   := "John Smith",
                "age"    := 34,
                "nested" := Json(
                  "id" := 2,
                  "name" := "Jane Smith",
                  "age" := 31))
```

Retrieving field values takes a bit of getting used to, but is very powerful and, more importantly, safe. Everything
is done through instances of `Option`, with helpers methods for standard default values:
```scala
// Retrieves the object's id field, or 0 if it doesn't exist or isn't an int.
// fieldOrZero checks for the existence of the requested field, numberOr attempts to interpret it as a number.
println(json fieldOrZero("id") numberOr(0))

// More convoluted example, with detailled messages for all cases:
json field "id" map {_.number map {i => println("id is an int of value %s".format(i))
} getOrElse println("id is set, but not to a number")
} getOrElse println("id is not set")

// As usual, for comprehensions make this both more readable and usable.
val id = for(i <- json.field("id"); j <- i.number) yield j
println(id.getOrElse(0))
```

All `Json` instances are immutable: modifying a field's value is done by creating a clone of the initial instance with
the desired modification. The documentation didn't make this immediately obvious to me, but it's simply done by
overwriting the field through the `->:` construct (or its option-based variant, `->?:`).

```scala
// Creates a clone of the initial object with an id field of 3.
val json2 = ("id" := 3) ->: json

// Instead of setting id to an arbitrary value, we increment it by 1, and use a default value of 0 if it does not
// exist. The beauty of this is that it cannot fail:
// - if id doesn't exist, it defaults to 0 through fieldOrZero
// - if it exists but isn't an int, withNumber will ignore the entire call and json3 will be strictly equal to json
// - otherwise, we'll get what we asked for.
val json3 = ("id" -> (json fieldOrZero "id" withNumber {_ + 1})) ->: json

// Modifying fields for nested objects is somewhat more convoluted.
// First, we modify the nested object. Note that nested is an Option[Json], None if the 'nested' field does not exist.
val nested = json field "nested" map {("id" := 4) ->: _}

// Then override the previous value of 'nested' - if and only if nested isn't None (that's the meaning of :=? and ->?:).
val json4  = ("nested" :=? nested) ->?: json
```



## Reading / Writing
As far as I'm concerned, this is where Argonaut is at its weakest: reading and writing isn't stream based. You can
only read from / write to strings. An extreme example of why this is bad is a humongous, sevel gigabytes large file
containing mostly whitespace and a tiny JSON object at the end. A stream based library would skip the whitespace and
only load the resulting JSON object, where Argonaut will load the entire file in memory.

This is probably not an issue in the majority of cases, but is definitely suboptimal. My guess is that the designers of
Argonaut are waiting for Scala's IO libraries to settle down (`scala.io.Source`, for example, has a horrible reputation
and seems on the cusp of a major overhaul). Hopefully this all gets sorted in the future.

Due to its lack of stream support, Argonaut reading and writing primitives are dead simple:
```scala
// Pretty prints json with 4 spaces for indentation.
println(json.spaces4)

// Prints a compact version of json. I feel this method should be called nospace - since there isn't even a single
// space, why should it be plural? - but I'm no native speaker.
println(json.nospaces)

val source = """{"id": 1, "name" : "John Smith", "age" : 34}"""

// There are other parsing methods, but they rely on Scalaz datatypes that I have no familiarity with and don't plan
// on learning just now.
Parse.parseOption(source) map {j =>
  println("Parsed into %s".format(j.spaces4))
} getOrElse {
  println("An error occurred")
}
```
