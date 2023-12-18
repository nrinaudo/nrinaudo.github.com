---
title: Decomposing programs
layout: article
series: free_monad
date:   20231115
---

We appear to have solved our initial problem, but this feels a little unsatisfying, doesn't it? Or at least I think it should.

The problem is that while we can compose individual statements to form larger programs, we cannot easily compose these programs. This is ideally something we'd have good support for: the ability to compose simple things to solve more and more complex problems is at the heart of good programming.

To take a more concrete example, we would like to take our previous program and split it into smaller chunks that we can later compose, or re-use in other programs.

## Splitting `program`

Here's `program`, in case you need your memory refreshed:

```scala
val program =
  Print("What is your name?", () =>
    Read(name =>
      Print(s"Hello, $name!", () =>
        Stop)))
```

There appears to be an obvious decomposition, at least logically, of this program:
- `ask`, which asks a user for their name and reads it.
- `greet` which, given a user's name, greets them with it.

`greet` is easy to write, we can just move the code inside of `program`'s `Read` statement to a dedicated function:


```scala
val greet: String => Console[Unit] =
 name =>
   Print(s"Hello, $name!", () =>
     Stop)
```

`ask` is a little more complicated. Instinctively, we'd like to write it as something that prints a message, then reads something from stdin, and "returns" that:

```scala
val ask: Console[String] =
  Print("What is your name?", () =>
    Read(name => name))
```

`ask` must ultimately evaluate to the user's name, which makes it a `Console[String]`. But the compiler will quickly let us know that while our type makes sense, our implementation does not:

```scala
val ask: Console[String] =
  Print("What is your name?", () =>
    Read(name => name))
//               ^^^^
// ⛔ Found:    (name : String)
//   Required: Console[A]
```

## More flexible continuations

There's two ways we can think about this problem, both of which lead us to the same conclusion.

The first one, which is painful work, involves thinking really hard about what a composable chain of statements is, and take this to its logical conclusion. I do not like hard work much however, and since the compiler is giving us the solution for free, let's try that instead. Free solutions to hard problems is more or less exactly the topic of this article, after all.

The compiler is telling us _you're returning a `String` but I want a `Console`_. Well, we _need_ to return a `String`, so clearly the issue is with the return type of our continuations: they should be allowed to return things that aren't `Console[A]`. Let's fix that:

```scala
enum Console[A]:
  case Print(msg: String, next: () => A)
  case Read(next: String => A)
  case Stop extends Console[Unit]
```

This almost allows `ask` to compile, but there's one last issue: it's composed of nested `Console` statements (a `Read` within a `Print`), which must be reflected in its type. `ask` is a `Console` (a `Print`) that evaluates to a `Console` (a `Read`) that evaluates to a `String`:

```scala
val ask: Console[Console[String]] =
  Print("What is your name?", () =>
    Read(name => name))
```

This is clearly an unpleasant type to wield - we do not want to manipulate different types depending on how many statements are linked, as this might grow quite a bit. We'll need to fix this, but first, a small but satisfying simplification.

## Getting rid of `Stop`

Take a look at `greet` in its last form:

```scala
val greet: String => Console[Unit] =
 name =>
   Print(s"Hello, $name!", () =>
     Stop)
```

`Stop` was created as the equivalent to `List`'s `Nil`: to mark the end of the list. We'd decided that this was a `Console[Unit]`, because chains of statements are evaluated for their side effects. But now that our continuations no longer have to return a `Console[A]`, we could just return `Unit` instead:

```scala
val greet: String => Console[Unit] =
 name =>
   Print(s"Hello, $name!", () =>
     ())
```

And with that, `Stop` is no longer required. We could keep it - the ability to interrupt a program when a given condition is met is not uninteresting. But it's also not part of our initial requirements, and would make the code in this article a little more complicated than it needs to be to make my point. I'll get rid of it, but you should feel free to write your own version with `Stop` and see where that takes you, it's quite an enlightening exercise (hint: things will be a lot less painful if you make `Stop` polymorphic and hold the last value in the computation, which may or may not be `Unit`).

Here's a trimmed-down `Console`:

```scala
enum Console[A]:
  case Print(msg: String, next: () => A)
  case Read(next: String => A)
```

You may notice that it's no longer a GADT but a "mere" polymorphic sum type - this feels significant and worth pointing out, even if I'm not quite sure why.

## Reworking `eval`

We've changed `Console` quite a bit, and our evaluation function needs to be updated accordingly. Here's how we left it:
```scala
def eval[A](console: Console[A]): A = console match
  case Print(msg, next) =>
    println(msg)
    eval(next())

  case Read(next)       =>
    val in = scala.io.StdIn.readLine()
    eval(next(in))

  case Stop             =>
    ()
```

The first, obvious thing we need to do is remove the `Stop` branch, as it no longer exists. But this still has compilation errors:

```scala
def eval[A](console: Console[A]): A = console match
  case Print(msg, next) =>
    println(msg)
    eval(next())
//       ^^^^^^
// ⛔ Found:    A
//   Required: Console[A]

  case Read(next)       =>
    val in = scala.io.StdIn.readLine()
    eval(next(in))
//       ^^^^^^^^
// ⛔ Found:    A
//   Required: Console[A]
```

The problem here is that `eval` takes a `Console[A]`, but we just modified `next` to return an `A`. Luckily, the fix is trivial if we just follow the compiler: `eval` must return an `A`, `next` already returns an `A`, we simply need to remove the recursive call.


```scala
def eval[A](console: Console[A]): A = console match
  case Print(msg, next) =>
    println(msg)
    next()

  case Read(next) =>
    val in = scala.io.StdIn.readLine()
    next(in)
```

At this point, `eval` works, but we're back to where we started: since it's no longer recursive, it only evaluates a single statement, not a chain of them.

## Evaluating chains

We can still absolutely write chains of statements - `ask` is one, for example. The problem is evaluating such chains, and deciding when the value returned by `next` is a new console statement to evaluate, or the result of our program.

This duality is made quite clear with the types of `ask`, a `Console[Console[String]]`, and `greet`, a `Console[Unit]`. We either evaluate to a `Console` or to something else, and we'd quite like to know which. Well, the usual solution to this _I have either one type or another_ is to use a _sum type_, which I'll call `Chain`:

```scala
enum Chain[A]:
  case Next(value: Console[Chain[A]])
  case Done(a: A)
```

We have two variants:
- `Done`, for any value that is not a `Console`. If you think about it, it means we've reached the end of our chain, which justifies the `Done` name.
- `Next`, wrapping the next `Console` in a chain.

Note the type of `Next`'s value field: `Console[Chain[A]]`. Instinctively, one might be tempted to put a simple `Console[A]` instead - I certainly was - but think it through: if the wrapped console evaluated to an `A`, then it'd be the end of the chain. We need it to evaluate to something that is either an `A`, or a console that evaluates to an `A`. That is exactly a `Chain[A]`.

Now that we have a type representing a chain of statements, we need to write an evaluation function for it:

```scala
def evalChain[A](chain: Chain[A]): A = ???
```

`Chain` is a sum type, so we'll need to provide an implementation of `evalChain` for both its variants:

```scala
def evalChain[A](chain: Chain[A]): A = chain match
  case Done(a)       => ???
  case Next(console) => ???
```

### `Done`
The `Done` branch writes itself: we have an `A` and must return an `A`. Done.

```scala
def evalChain[A](chain: Chain[A]): A = chain match
  case Done(a)       => a
  case Next(console) => ???
```

### `Next`

The `Next` branch is maybe a little trickier. I'll use it as an opportunity to introduce diagrams as a problem solving tool: explaining code in writing is a hard skill to master (or at least it's hard _for me_), and diagrams make this a very visual exercise.

Here's how I'd represent our problem:

![evalChain for Next: problem](/img/free_monad/evalChain_problem.svg)

We start from `Console[Chain[A]]`, which is the type of the value wrapped in `Next`. This is visually encoded by the arrow going in and the filled-in background.

Our goal is to get an `A`, the return type of `evalChain`. This is visually encoded by the arrow going out and the filled-in background.

From there, the game is to look at all the tools we have and use the right ones to build a path from the starting point to the goal.

Here, for example, we could realise that `evalChain` works on `Chain`, and that `Chain` is a recursive data type. It's very likely that a function that explores an entire `Chain` will need to be recursive, and that `evalChain` will need to be defined in terms of itself. We'll add it to the diagram, as an arrow from `Chain[A]` to `A`:

![evalChain for Next: solution](/img/free_monad/evalChain_step_1.svg)

In order to solve our problem, then, we merely need to find a way of getting a `Chain[A]` from a `Console[Chain[A]]`. Which, if you think about it, is _exactly_ `eval`. This feels satisfying, too: it seems natural that in order to evaluate a chain of statements, we'd rely on the function that evaluates a single statement.

Let's add it to the diagram:

![evalChain for Next: solution](/img/free_monad/evalChain.svg)

And that gives us our solution. The diagram tells us which functions to call on what, we merely have to follow the arrows:

```scala
def evalChain[A](chain: Chain[A]): A = chain match
  case Done(a)       => a
  case Next(console) => evalChain(eval(console))
```

## What next?

We've achieved what we set out to do in this section: `program` is now split into two smaller chains of statements, `ask` and `greet`.

In the process, we have regained the ability to create and evaluate single statements, while still being able to do the same thing for chains of statements.

Our next step, now that we've decomposed `program`, is to try and recompose it, and discover the tools we need to do so.
