---
layout: post
title: "MongoDB with Scala"
date: 2013-07-15 21:52
comments: true
categories: scala mongodb
---
Dear future self,

I finally know enough Scala to start incorporating it in my day-to-day job. Before I can actually become productive,
however, I need to work out how to do the following, which are prerequisites to a large chunk of my recent weekly tasks:

* read / write CSV files ([sorted](https://github.com/nrinaudo/scala-csv))
* interact with [MongoDB](http://www.mongodb.org)
* read / write XML files
* read / write JSON files

Today's post is about integrating with MongoDB.

<!-- more -->

## Library

This is achieved through [Casbah](http://mongodb.github.io/casbah/), the official Scala MongoDB driver. Casbah builds
are available in standard Maven repositories, which means that it should be rather trivial to integrate with most
modern build tools. I've been working with [sbt](http://www.scala-sbt.org) recently, which makes it as easy as:

```scala
// Note the %% symbol: it lets sbt look for a casbah built that matches the target version of Scala by appending it
// to artifact names.
libraryDependencies += "org.mongodb" %% "casbah" % "2.6.2"
```

Casbah depends on [SLF4j](http://www.slf4j.org), which is brilliant but means that you need a valid SLF4j output
connector in the classpath on pain of ugly warnings at runtime. For testing purposes, I always use their no-op
connector:

```scala
// Note the absence of %% symbol: slf4j is not scala specific and has no version number in its artifact names.
libraryDependencies += "org.slf4j" % "slf4j-nop" % "1.7.5"
```

## Querying MongoDB

At its most basic, querying MongoDB is very reminiscent of the official Java driver:
```scala
// Connects to collection MyCollection of database MyDatabase on the default port.
val col = MongoClient()("MyDatabase")("MyCollection")

// Inserts an object in the collection.
col.insert(MongoDBObject("_id" -> 1, "name" -> "John Smith", "age" -> 34))

// Finds all documents with an _id field of 1
col.find(MongoDBObject("_id" -> 1)) foreach {o => println(o("name"))}

// Sets the "age" field of all documents with an _id field of 1 to 35.
col.update(MongoDBObject("_id" -> 1), MongoDBObject("$set" -> MongoDBObject("age" -> 35)))

// Deletes all documents with an _id field of 1.
col.remove(MongoDBObject("_id" -> 1))
```

Casbah, however, has a clever [DSL](http://mongodb.github.io/casbah/guide/query_dsl.html) to make these verbose calls
much more pleasant to read and closer to standard MongoDB syntax:

```scala
// This is strictly equivalent to col.find(MongoDBObject("_id" -> 1)).
col.find("_id" $eq 1)

// This can alternatively be done with findOneByID (which is a bit of a pain with int ids, as you need to use
// type ascription).
col.findOneByID(1: java.lang.Integer)

// Multiple filters can be chained through the ++ operator:
col.find(("_id" $eq 1) ++ ("age" $eq 34))

// The same is true for update criterias:
col.update("_id" $eq 1, $set("name" -> "Jane Smith") ++ $inc("age" -> 1))
```


## Retrieving field values

Retrieving field values is slightly more verbose, but very flexible:
```scala
cold.find("_id" $eq 1) foreach {o =>
  // Unsafe: if the requested field doesn't exist, an exception is thrown.
  println(o.as[Int]("age"))

  // Safe: returns an Option.
  println(o.getAs[Int]("age"))
}
```

Array fields are handled exactly as you'd expect through the `MongoDBList` class:
```scala
col.insert(MongoDBObject("_id" -> 1, "name" -> "John Smith", "age" -> 34, "numbers" -> MongoDBList(1, 2, 3, 4)))

// Both findOneByID and getAs return an Option, which explains the calls to map.
col.findOneByID(1: java.lang.Integer) map {o =>
  o.getAs[MongoDBList]("numbers") map {n =>
    // n behaves as a standard Seq[Any].
    n foreach println
  }
}
```
