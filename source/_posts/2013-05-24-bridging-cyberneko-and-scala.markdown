---
layout: post
title: "Bridging CyberNeko and Scala"
date: 2013-05-24 22:06
comments: true
categories: scala, cyberneko
---
Dear future self,

I just spent a few hours working out how to use my favourite HTML cleaner,
[CyberNeko](http://nekohtml.sourceforge.net), with Scala. Web scrapping is something that I have to do rather often and
I'd rather spare you the frustration I just went through, so here goes.

<!-- more -->

## The Problem

What I wanted to do was to use CyberNeko to do the HTML parsing, but retrieve standard Scala XML elements in order to
use their various enhancements (`XPath`-like path analysis, for example).

The problem is that, in order to do that, one needs to use an instance of
[SAXParser](http://www.scala-lang.org/api/2.11.0-M2/index.html#scala.xml.package@SAXParser=javax.xml.parsers.SAXParser),
which CyberNeko doesn't provide. Well, it does provide a
[SAXParser](http://nekohtml.sourceforge.net/javadoc/org/cyberneko/html/parsers/SAXParser.html) class, but that's a
misnomer since it's actually an implementation of
[XMLReader](http://docs.oracle.com/javase/6/docs/api/org/xml/sax/XMLReader.html). Confused yet?

After digging through Java and Xerces' mess of factories, factory adapters, builders, parsers and readers in
order to find a one-liner, elegant way to turn CyberNeko into a proper `SAXParser`, the only conclusion I came to was
that XML handling in Java is an exercise in obfucastion and it would probably be much quicker to implement a solution
than to find the appropriate classes, if they even exist.


## The Solution

Turns out I was right. Writing a simple wrapper class for CyberNeko is as easy as:

```scala
import scala.xml._
import org.xml.sax._

class HtmlParser extends SAXParser {
  // This is actually an instance of XMLReader. One cannot help but wonder what the !@# they were thinking.
  val reader = new org.cyberneko.html.parsers.SAXParser

  // By default, CyberNeko turns all element names upper-case. I'm not a big fan.
  reader.setProperty("http://cyberneko.org/html/properties/names/elems", "lower")

  // Deprecated, no need to support.
  // This is going to generate warnings at compile time, but I don't see a way around it.
  override def getParser(): org.xml.sax.Parser = null

  override def getProperty(name: String): Object = reader.getProperty(name)

  override def getXMLReader() = reader

  override def isNamespaceAware() = true

  override def isValidating() = false

  override def setProperty(name: String, value: Object) = reader.setProperty(name, value)
}
```

Once this is done, parsing an HTML file can be done with one of
[XML](http://www.scala-lang.org/api/2.11.0-M2/index.html#scala.xml.XML)'s various `load` methods:
```scala
val html = XML.loadFile(new java.io.File("my/html/file.html"))

html \\ "div" foreach {div => println(div.text)}
```
