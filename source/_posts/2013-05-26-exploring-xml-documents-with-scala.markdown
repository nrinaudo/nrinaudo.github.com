---
layout: post
title: "Exploring XML documents with Scala"
date: 2013-05-26 21:58
comments: true
categories: scala xml
---
Dear future self,

After I worked out how to [load HTML](/blog/2013/05/24/bridging-cyberneko-and-scala/) with Scala, I had to figure out
how to explore the resulting documents. It's rather straightfroward in
[Groovy](2013/04/09/using-gpath-with-xmlslurper/), but it turns out to be somewhat less pleasant in Scala.

<!-- more -->



## Element selectors
Finding a specific element, or set of elements, is nicely implemented: it's both easy to read and to write, even if
nothing too fancy.

```scala
import scala.xml._

val xml = <html><body>
            <div><a href="test.html">Test</a></div>
            <div><a href="test2.html">Test 2</a></div>
          </body></html>
 
// `\` returns a sequence containing all elements whose name match the right operand and are direct descendants of the
// left operand.
// Prints:
// <div><a href="test.html">Test</a></div>
// <div><a href="test2.html">Test 2</a></div>
xml \ "body" \ "div" foreach println

// `\\` returns a sequence containing all elements whose name match the right operand, regardless of their depth.
// Prints:
// <a href="test.html">Test</a>
// <a href="test2.html">Test 2</a>
xml \\ "a" foreach println
```

The `\` and `\\` selectors return sequences: you can call `filter`, `map`, `foreach`... on their results.



## Attribute selectors
Selecting an attribute appears simple at first. According to the documentation, you can simply use `@name` with the
standard `\` and `\\` selectors, which sounds brilliant until you realise it doesn't actually work as advertised.

```scala
import scala.xml._

val xml = <html><body>
            <div><a href="test.html">Test</a></div>
            <div><a href="test2.html">Test 2</a></div>
          </body></html>

// This *should* match and print the href attribute of all a elements.
// It doesn't actually work, though, and doesn't print anything.
xml \\ "a" \ "@href" foreach println

// This does what the previous code should do. Not terribly elegant, but gets the job done.
// Prints:
// test.html
// test2.html
xml \\ "a" map {_ \ "@href"} foreach println

// Matches and prints all href attributes, regardless of their parent element.
// Prints:
// test.html
// test2.html
xml \\ "@href" foreach println

```


## Filtering on attribute
This is where things take a turn for the worse, as far as I'm concerned: you *can* filter on attributes, it's just not
very pleasant at all.

```scala
import scala.xml._

val xml = <html><body>
            <div><a href="test.html">Test</a></div>
            <div><a href="test2.html">Test 2</a></div>
            <div><a>No Link</a></div>
          </body></html>
 
// Finds all a elements whose href attribute exists.
// Prints:
// <a href="test.html">Test</a>
// <a href="test2.html">Test 2</a>
xml \\ "a" filter {a => !(a \ "@href").isEmpty} foreach println

// Finds all a elements whose href attribute is equal to test.html.
// Prints:
// <a href="test.html">Test</a>
xml \\ "a" filter {_ \ "@href" contains Text("test.html")} foreach println
```
