---
layout: post
title: "Using GPath with XmlSlurper"
date: 2013-04-09 21:28
comments: true
categories: groovy xml
---
Dear future self,

Writing quick, discardable tools to parse some sort of XML, extract information from it and put it somewhere else is
something I have to do with some regularity.

The best tool I currently have for this is Groovy - it has access to the wealth of existing Java libraries, but with a
much more flexible syntax that does away with most of its parent's boilerplate.

Also, mostly, `XmlSlurper` and GPath. These make loading and extracting information from XML so smooth and easy that
one would almost forget the nightmare Java's internal XML APIs can be.

That's the theory, at least, but it doesn't appear to work for me. Whenever I have to use GPath, I find myself
stimmied by the same problems. Time and time again, I'll forget the difference between `grep` and `find`, or fail to
remember that detph- or breadth-first searches change the rules slightly.

Not anymore. Since my brain obviously has some sort of block as far as GPath syntax is concerned, this post will do in
its stead.

<!-- more -->

In the rest of this post, the `xml` object is assumed to have been obtained through one of `XmlSlurper`'s `parse`
methods.

## Finding an element by name

The first things I *always* stumble on is when attempting to find all the elements of one type contained in an XML
document - say, for example, all `li` elements in an HTML file.

What I want to write is:
```groovy
xml.'**'.li.each {
    // processing code
}
```

And, for some reason, I *always* distinctly remember having done so in the past.

Well, future self, you're wrong. This syntax isn't supported, nor, as far as I can tell, has it ever been. Don't try to
get it to work.

`**` is an alias for `depthFirst()`, which returns an iterator - a Groovy enhanced one, certainly, but still not one
that supports nested GPath expressions.

Here's what you want to do:

```groovy
xml.'**'.findAll {it.name() == 'li'}.each {
    // processing code
}
```

Pay attention to the way the element's name is retrieved: it's `it.name()`, not `it.name`. A method, not a property. And
yes, I know you feel vaguely insulted by what seems like such a stupid decision, but there's a very good reason for it:
properties describe children of the current node, so `it.name` would referrer to a `name` child element rather than the
element's name.

Honestly, if past me had told me that this morning, I'd have saved a good half hour this afternoon.

## grep VS find VS findAll

These three methods have very similar contracts and purposes, but differ in ways that always do my head in.

I'll use the following input to illustrate these differences:
```xml
<html>
    <body>
        <ul>
            <li class="odd"><span>Element 1</span></li>
            <li class="even"><span>Element 2</span></li>
            <li class="odd"><span>Element 3</span></li>
            <li class="even"><span>Element 4</span></li>
            <li class="odd"><span>Element 5</span></li>
        </ul>
    </body>
</html>
```


### find
`find` is the simplest of the three: it returns the first node for which its closure argument returns `true`.

For example:
```groovy
// Finds the first li element with a class attribute of odd.
// Outputs 'Element 1'.
xml.body.ul.li.find {it.@class == 'odd'}.each {
    println it.text()
}
```

The returned value is an instance of `NodeChild`, which is convenient: you've just essentially obtained the root of a
sub-tree of your original XML document, and can treat it exactly as you did the `xml` object - by, for example, chaining additional GPath filters.

The following example is perfectly valid (and convenient):
```groovy
// Outputs 'Element 1'
xml.body.ul.li.find {it.@class == 'odd'}.span.each {
    println it.text()
}
```

Bear in mind that, once you've called `find`, you've restricted yourself to the *first* element that matched your
closure *only*. I'm sure normal people don't have a problem with that, but it seems to slip my mind very often.

### findAll
`findAll` is also fairly simple: it returns all nodes for which its closure argument returns `true`.

For example:
```groovy
// Finds all li elements with a class attribute of odd.
// Outputs 'Element 1\nElement 3\nElement 5\n'
xml.body.ul.li.findAll {it.@class == 'odd'}.each {
    println it.text()
}
```

The returned value is an instance of `FilteredNodeChildren`, a subclass of `GPathResult`, which *should* be nice but
looks... unfinished.

It basically supports the same nested GPath filters as `find`, with one very notable exception.
```groovy
// Does exactly what you'd expect: prints 'odd\nodd\nodd\n'
xml.body.ul.li.findAll {it.@class == 'odd'}.@class.each {println it.text()}

// Doesn't do what you'd expect at all: no span element is found.
xml.body.ul.li.findAll {it.@class == 'odd'}.span.each {println it.text()}
```

This has had me scratching my head for a while, but I can't find a reason why the `span` selector doesn't work. I'm not
confident enough in my Groovy skills to call this a bug in the standard APIs, but looking at the corresponding code, it
looks like it should work but doesn't.

The only solution I could find was to use the
[spread operator](http://groovy.codehaus.org/Operators#Operators-SpreadOperator) as follows:
```groovy
// Outputs 'Element 1\nElement 3\nElement 5\n'
xml.body.ul.li.findAll {it.@class == 'odd'}*.span.each {println it.text()}
```

While this works, I find it unsatisfactory: it looks out of place in what is an otherwise fairly clean GPath expression.
I'll keep looking and update this post should I find a reason, but for the moment, future self, bear in mind that
`findAll` feels a bit broken. You'd want its result to be manipulable in exactly the same way `find`'s result is, but
this is just not the case.

_Edit: this is apparently a reported [bug](https://jira.codehaus.org/browse/GROOVY-6122) and will hopefully be fixed
eventually_


### grep
`grep` is where I usually get stuck. At a glance, its signature and purpose are the same as `findAll`'s.

For example:
```groovy
// Finds all li elements with a class attribute of odd.
// Outputs 'Element 1\nElement 3\nElement 5\n'
xml.body.ul.li.grep {it.@class == 'odd'}.each {
    println it.text()
}
```

There are, however, two differences between `findAll` and `grep`'s signatures.

The first one is that `grep`'s argument isn't a closure but an object whose `isCase(Object)` method will be evaluated.
You can pass in a closure, in which case the behaviour will be identical to that of `findAll`, but you could also pass
any object with a useful `isCase` method.

The second difference is in the return type: `ArrayList<NodeChild>`. Groovy collections have a fun if sometimes
misleading feature used to simplify calls to `collect`. The following calls are strictly equivalent:
```groovy
def set = ['foo', 'bar']

// Returns ['foo'.bytes, 'bar'.bytes]
set.collect {it.bytes}

// Does the same thing in a slightly more idiomatic way.
set.bytes
```

This means that the following code is perfectly correct, and will behave exactly as one would expect:
```groovy
xml.body.ul.li.grep {it.@class == 'odd'}.span.each {
    println it.text()
}
```

Which is brilliant, until you write the following:
```groovy
xml.body.ul.li.grep {it.@class == 'odd'}.'**'.findAll {it.name() == 'span'}.each {
    println it.text()
}
```
This, as it turns out, throws an exception that is frustrating to understand. So, future self, here's exactly what
happens laid out in simple terms:
```groovy
// 'nodes' is an ArrayList<NodeChild>
def nodes = xml.body.ul.li.grep {it.@class == 'odd'}

// This is strictly equivalent to nodes.collect {it.'**'}.
// 'search' isn't an Iterator<NodeChild> but an ArrayList<Iterator<NodeChild>>
def search = nodes.'**'

// You'd expect 'it' to be a NodeChild, but you actually get an Iterator<NodeChild>.
// Iterators don't support the name() method, which is where the exception is raised.
search.findAll {it.name() == 'span'}.each {
    println it.text()
}
```
