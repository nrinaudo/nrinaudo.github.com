---
title: Trimming the boilerplate
layout: article
series: free_monad
date:   20231117
---

We now have our console statements comfortably composable, but they're quite noisy and unpleasant to declare. Take, for example, our `ask` and `greet` commands:

```scala
val ask: Chain[String] =
  Next(Print("What is your name?", () =>
    Next(Read(name => Done(name)))))

val greet: String => Chain[Unit] =
  name =>
    Next(Print(s"Hello, $name!", () =>
      Done(())))
```

That is a _lot_ of code to not say much. Our first task will be to extract the boilerplate to helper functions, which always helps.

## Extracting atomic statements

The general idea here is to identify the smallest possible statements we can make - atomic statements - and make them easy to declare. Since they're also easy to compose into more complex, molecular ones, this should make the whole experience a lot more pleasant.

### Printing

First, let's take a look at printing in `greet`:

```scala
val greet: String => Chain[Unit] =
  name =>
    Next(Print(s"Hello, $name!", () =>
      Done(())))
```

The entire body of the function is just "given a string, print it and return unit". This is the smallest possible print statement we can write, and as such needs its helper function. We'll basically copy / paste its content:

```scala
def print(msg: String): Chain[Unit] =
  Next(Print(msg, () => Done(())))
```

This allows us to rewrite `greet` to something quite a bit more pleasant:

```scala
val greet: String => Chain[Unit] =
  name =>
    print(s"Hello, $name")
```

### Reading

Let's then take a look at the last line of `ask`:

```scala
val ask: Chain[String] =
  Next(Print("What is your name?", () =>
    Next(Read(name => Done(name)))))
```

That is the smallest read statement we can write: read a `String` from stdin and return it. We will again extract that to a helper function:

```scala
def read: Chain[String] =
  Next(Read(str => Done(str)))
```

This allows us to rewrite `ask` in a slightly nicer way:

```scala
val ask: Chain[String] =
  Next(Print("What is your name?", () =>
    read))
```

## Factoring out common patterns

One thing you might have noticed with `print` and `read` is that they follow a very similar pattern. Don't worry if you haven't, pattern recognition takes some practice and it frankly took me a while to spot this particular one.

Look at them side by side:

```scala
def print(msg: String): Chain[Unit] =
  Next(Print(msg, () => Done(())))

def read: Chain[String] =
  Next(Read(str => Done(str)))
```

In both cases, the innermost bit of code is a function that given a value of type `A` (either `Unit` or `String`), wraps it in a `Done`. So, really, an `A => Chain[A]`.

That function is then wrapped in a `Console[A]` (either `Print` or `Read`) to produce a `Console[Chain[A]]`.

Or, put another way, they're both represented by the following diagram:

![Read and Print: problem](/img/free_monad/liftChain_building_lift.svg)

Remember what I said about rectangular patterns in diagrams? There's something functorial going on in there. And since `Console` is in fact a `Functor`, we can rewrite our two functions as calls to `map`:

```scala
def print(msg: String): Chain[Unit] =
  Next(Print(msg, () => ()).map(Done.apply))

def read: Chain[String] =
  Next(Read(str => str).map(Done.apply))
```

We're not quite done though. Both `print` and `read` still follow a common pattern: they both take a `Console` (either a `Print` or a `Read`), `map` into it to apply `Done`, and wrap the result in a `Next`. They're basically the same function with a different input.

Let's extract this function:

```scala
def liftChain[A](console: Console[A]): Chain[A] =
  Next(console.map(Done.apply))
```

This allows us to simplify `print` and `read` quite a bit:

```scala
def print(msg: String): Chain[Unit] =
  liftChain(Print(msg, () => ()))

def read: Chain[String] =
  liftChain(Read(str => str))
```

You might think this is a bit overkill - after all, `print` and `read` still work exactly the same from an external perspective, we've just shuffled code around. But doing this has shown us that really, our atomic statements are just taking a simple `Console` statement and moving it inside of `Chain`. It's a pretty good hint of things to come: maybe `Chain` isn't tied to `Console` and is a more general construct?

## Composing atomic statements

And now for our finishing touch, take a look at `ask`:

```scala
val ask: Chain[String] =
  Next(Print("What is your name?", () =>
    read))
```

There's another pattern to spot here, and one that is, again, easier to spot with a diagram. The innermost part is `() => read` - a function from `Unit` to `Chain[String]`.

This is applied inside of a `Next(Print, ...)`, which is a `Chain[Unit]`, and produces a `Chain[String]`.

Which gives us the following diagram:


![ask as flatMap: problem](/img/free_monad/read_flatMap_building.svg)

That triangular shape is typical of something monadic going on. `ask`'s current implementation is merely a convoluted way of calling `flatMap`:

```scala
val ask: Chain[String] =
  Next(Print("What is your name?", () => ())
    .flatMap(_ => read))
```

You might not think this is much of an improvement - it's actually _more_ code than before! But that's because we're not quite done yet. That first line, `Next(Print...`, should be familiar. It's _exactly_ a call to `print`.

We can rewrite `ask` in a much more pleasant fashion:

```scala
val ask: Chain[String] =
  print("What is your name?")
    .flatMap(_ => read))
```

Which is _really_ nice, because, well. Look at our entire code now:

```scala
val ask: Chain[String] =
  print("What is your name?")
    .flatMap(_ => read))

val greet: String => Chain[Unit] =
  name =>
    print(s"Hello, $name")

val program: Chain[Unit] =
  ask.flatMap(greet)
```

This is strictly calls to `flatMap` on atomic statements. Which means we can rewrite the entire thing as a for-comprehension:

```scala
val program: Chain[Unit] = for
  _    <- print("What is your name?")
  name <- read
  _    <- print(s"Hello, $name!")
yield ()
```

And that is lovely. Our program is now quite clear and easy to understand, and feels like very idiomatic Scala.

## What next?

We can now solve our initial problem quite comfortably, by creating atomic statements and composing them into larger, more complex ones using the language's standard syntax.

We could stop here, as we have most definitely fulfilled our assignment. But we also had a hint, while factorising `read` and `print`, that we might have stumbled on something a little more generic than merely a way to chain console statements.

Wouldn't it be a shame to stop now when, rather than solving a specific problem, we might have found a way to solve _all_ such problems?
