---
layout: post
title: "Pattern matching as parameter"
date: 2013-09-05 17:25
comments: true
categories: scala best-practice
---
Dear future self,

I just discovered a nice trick with pattern matching, which I thought I'd jot down before I forget about. It's a
logical consequence of what I wrote on [partial functions](/blog/2013/08/03/partial-functions/), but it just recently
clicked: a pattern match is a legal argument for higher-order functions expecting unary functions as parameters.

<!-- more -->

As I previously realized, pattern matching is a shortcut for partial function creation. Since partial functions are
unary, it follows that you can pass them to higher-order functions such as, for example, `map`:

```scala
// Unwraps the specified sequence, replacing None by the specified default value.
def badUnwrap[A](la: Seq[Option[A]], da: A): Seq[A] = la map {va =>
  va match {
    case Some(a) => a
    case None    => da
  }
}

// This is doing exactly the same thing as badUnwrap, but takes advantage of the fact
// that one can pass a pattern match directly to to map. I believe it looks much cleaner.
def unwrap[A](la: Seq[Option[A]], da: A): Seq[A] = la map {
  case Some(a) => a
  case None    => da
}
```

It seems obvious in hinsight, but I'd never realized that before. My OCD is probably going to force me to go and "fix"
this in all the Scala code I ever wrote...
