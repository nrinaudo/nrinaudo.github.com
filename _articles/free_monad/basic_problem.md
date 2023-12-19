---
title: Initial implementation
layout: article
series: free_monad
date:   20231108
---

The simplest, most intuitive encoding of any sort of program as values is an Algebraic Data Type. We'll start from there and see where it takes us.

## ADT encoding

Here's what such an ADT might look like:

```scala
enum Console:
  case Print(msg: String)
  case Read
```

Nothing particularly fancy - a `Console` can either be a `Read` statement to read from stdin, or a `Print` statement to write to stdout.

But of course, this representation is a little bit useless without an interpreter. Let's start with the obvious one, evaluation:

```scala
def eval(console: Console): Any = console match
  case Print(msg) => println(msg)
  case Read       => scala.io.StdIn.readLine
```

This is fairly straightforward: `Console` is a sum type, so we simply deconstruct it and provide an implementation for each variant.

There's an obvious flaw, however: one branch yields `Unit`, the other `String`, which makes the overall type of the pattern match `Any`, never a good type to manipulate.

## GADT encoding
The solution is well known, at least in languages that support GADTs: we need to index `Console` with the type that its computation returns:
- `Print` evaluates to `Unit`, and is thus a `Console[Unit]`.
- `Read` evaluates to a `String` (the value that was read), and is thus a `Console[String]`.

```scala
enum Console[A]:
  case Print(msg: String) extends Console[Unit]
  case Read extends Console[String]
```

This gives us a much more satisfying evaluation function, as we now know exactly what its return type is:

```scala
def eval[A](console: Console[A]): A = console match
  case Print(msg) => println(msg)
  case Read       => scala.io.StdIn.readLine
```

## Where next?

We now know how to represent a single console statement, and have a basic interpreter for it. This isn't yet a solution to our problem, however, since we're not yet working with chains of console statements.
