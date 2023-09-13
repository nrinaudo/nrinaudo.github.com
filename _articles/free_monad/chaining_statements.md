---
title: Chaining statements
layout: article
series: free_monad
date:   20231109
---

We now have the ability to describe console statements, and to evaluate _a single one_. This is not quite what we wanted, however: we'd like to be able to evaluate _sequences of statements_.

### Naive implementation

Let's start from the obvious implementation that _sequences of statements_ suggests: a list.


```scala
val program =
  Print("What is your name?") ::
  Read                        ::
  Print("Hello!")             ::
  Nil
```

An evaluation function for this is straightforward, a simple `foreach(eval)`, but there's a problem though, isn't there. We're greeting the user, but we're not greeting them by name. The reason for this (and its fix) is more immediately obvious if you represent `program` as as a diagram:

![Sequence of statements](/img/free_monad/before_continuation_full.svg)

The issue is apparent in that there is no path from `Read` to `Print("Hello!")` - no way for `Read` to pass whatever it read to downstream statements. The links are between the `::` cells, not the console statements.

### Linked console statements

What we really want to do is to take the structure given to us by the `::` cells and move it into `Console`, like so:

![Linked Statements](/img/free_monad/linked_console.svg)

Note how I had to create a new `Stop` instruction. This is the `Console` equivalent of a `List`'s `Nil`: a marker that we have reached the end of our sequence. I'm not thrilled we had to do that: it wasn't part of the initial problem statement, and we've had to introduce it as an implementation detail, which will unfortunately end up being exposed to the rest of the world. This is part of the process of finding a solution: we sometimes have to take a step backwards in order to take two forward. Hopefully we can do something about it later.

The code corresponding to that diagram would look something like:

```scala
enum Console[A]:
  case Print(msg: String, next: Console[A]) extends Console[Unit]
  case Read(next: Console[A]) extends Console[String]
  case Stop extends Console[Unit]
```

The difference with what we had before, on top of `Stop`, is the addition of `next` in both `Print` and `Read`, a reference to the next element in the sequence. `Stop` doesn't have one, as it's by definition the one statement that isn't followed by another one.

There's still a small problem here. Remember how we'd said that `Console[A]`'s `A` parameter was meant to represent the type we'd get when evaluating a statement? Well, now that `Console` represents a chain of statements, the type we'd get when evaluating one would be the type of the _last_ statement in the chain. `Print`, for example, is no longer going to yield a `Unit`, but whatever its `next` statement will yield: an `A`.

Let's update the code to make this clear:

```scala
enum Console[A]:
  case Print(msg: String, next: Console[A]) extends Console[A]
  case Read(next: Console[A]) extends Console[A]
  case Stop extends Console[Unit]
```

We can simplify this a little, because Scala allows us to ignore the `extends` statement on a variant if it's exactly the same as the root type:

```scala
enum Console[A]:
  case Print(msg: String, next: Console[A])
  case Read(next: Console[A])
  case Stop extends Console[Unit]
```

This allows us to rewrite our program in a slightly improved way:

```scala
val program =
  Print("What is your name?",
    Read(
      Print("Hello!",
        Stop)))
```

I'm saying _slightly_ here because, well. We haven't fixed our problem, have we? We're still not greeting our user by name, because we still do not have access to whatever `Read` read from stdin.

### Continuations

The trick here is to realise that in order for `Read` to pass anything to downstream statements, these statements cannot exist _before_ anything has actually been read. They can only be created once that information is available. Which is a long winded way of saying `Read`'s `next` statement should not be a `Console[A]`, but a `String => Console[A]`, where the `String` parameter is whatever was read from stdin.

`next` here is called a _continuation_: the function to call to execute the rest of the program. To continue the program, as it were. And if we're going to be using continuations (or work in a _[Continuation Passing Style](https://en.wikipedia.org/wiki/Continuation-passing_style)_, as it's known), we need to be consistent and also make `Print`'s `next` a continuation, even if one that only has `Unit` as input:

```scala
enum Console[A]:
  case Print(msg: String, next: () => Console[A])
  case Read(next: String => Console[A])
  case Stop extends Console[Unit]
```

And this, finally, solves our problem, as it allows us to rework our program thusly:

```scala
val program =
  Print("What is your name?", () =>
    Read(name =>
      Print(s"Hello, $name!", () =>
        Stop)))
```

Notice how `Read` now exposes `name`, the string it read, to `Print`, and we can finally greet our user by name.

### Evaluation

Now that we can write a chain of console statements, we need to be able to evaluate such a chain. The general idea is fairly straightforward:
- for `Print` and `Read`, keep doing what we were doing, but then recursively call `eval` on the `next` statement.
- do nothing on `Stop`.

Which gives us:

```scala
def eval[A](console: Console[A]): A = console match
  case Print(msg, next) =>
    println(msg)
    eval(next())

  case Read(next)       =>
    val int = scala.io.StdIn.readLine()
    eval(next(in))

  case Stop             =>
    ()
```

Note that while we can now describe and evaluate chains of console statements, we have lost the ability to work at the single statement level. `Console[A]` now declares an entire chain, and we don't really have a type to describe a single statement any longer.

## What next?

At this point, we have mostly solved our problem: we can write a program that asks a user for their name, then greets them by that name. That program is represented as a value for which we can write interpreters, such as `eval`.

I'm not entirely satisfied with our solution though. It feels like we should be able to compose statements, or chains of statements, to create more complex ones. This is what we'll be trying to do in the next few sections, first by decomposing `program` into smaller chains of statements, then by trying to recompose them to produce `program` back.
