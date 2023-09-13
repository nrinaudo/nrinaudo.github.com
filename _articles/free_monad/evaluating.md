---
title: Evaluating Free
layout: article
series: free_monad
date:   20231119
---

We've now created `Free`, the free monad over a functor, as a generalisation of `Chain`. We've also expressed our initial `program` fully with `Free`. All that remains is to adapt our evaluation functions for it.

Let's take stock of what we have.

## Single statement evaluation

First, `eval`, used to evaluate a single `Console` statement:

```scala
def eval[X](console: Console[X]): X = console match
  case Print(msg, next) =>
    println(msg)
    next()

  case Read(next) =>
    val in = scala.io.StdIn.readLine()
    next(in)
```

You might have noticed that I renamed the type parameter to `X` - it obviously does not change the function's behaviour, but will help in a little while when we have to differentiate between the `A` parameter of one function, and the other, distinct `A` of another function.

`eval` did not use `Chain` in any way, and can remain as is.

## Chain of statements evaluation

Second, `evalChain`, to evaluate an entire chain of `Console` statements. Remember that it relies on `eval` to evaluate single statements, and merely does the recursive exploration of the chain.

```scala
def evalChain[A](chain: Chain[A]): A = chain match
  case Done(a)       => a
  case Next(console) => evalChain(eval(console))
```

This needs to change a little:
- names have changed, so `Chain` becomes `Free`, `Done` becomes `Pure` and `Next` becomes `Flatten`.
- `Free` takes an additional type parameter, the wrapped type. Let's start by having it as `Console`, to keep the same behaviour.

```scala
def evalFree[A](fa: Free[Console, A]): A = fa match
  case Pure(a)      => a
  case Flatten(ffa) => evalFree(eval(ffa))
```

This implementation uses `Free`, but still hard-codes `Console` in two distinct places:
- it currently only takes a `Console` and we'd like to work with any type constructor.
- we're using `eval`, which is strictly a `Console` statement evaluation function.

What we want to do, then, is turn both these things into parameters: `Console` into a type parameter and `eval` into a value parameter.

There's a little bit of a trick for `eval`, however. We might be tempted to write the following:

```scala
def evalFree[F[_], A](
  fa     : Free[F, A],
  handler: F[A] => A
): A = fa match
  case Pure(a)      => a
  case Flatten(ffa) => evalFree(handler(ffa))
```

`handler` is how we receive `eval` as a parameter, and `eval` is a function that given a type `X` and a `Console[X]`, yields an `X`. Our implementation seems reasonable.

Yet it won't compile. If you think it through, in the `Flatten` branch, `ffa` is a `F[Free[F, A]]`, `handler` takes an `F[A]`, this cannot typecheck.

The trick here is to realise that `eval` works for _any_ type `X`, not just `evalFree`'s `A`. It might be a little bit hard to see, but `eval` takes _any_ `X` - in particular, `X = Free[Console, X]`.

The problem for people like me who've done far more Scala 2 than Scala 3 is that, in our head, this notion of a function that takes a type parameter does not exist. _Methods_ are polymorphic, but _functions_ are not. And so you'll likely find needlessly complex implementations of `evalFree` which rely on `F` being a functor, which can be made to work, but also, why bother? Scala 3 has support for polymorphic functions.

The type we want `handler` to have is `[X] => F[X] => X`, which reads _for any type `X`, given an `F[X]`, returns an `X`_. This is exactly what we need:

```scala
def evalFree[F[_], A](
  fa     : Free[F, A],
  handler: [X] => F[X] => X
): A = fa match
  case Pure(a)      => a
  case Flatten(ffa) => evalFree(handler(ffa), handler)
```

## But what about effects though?

For all I think the Scala community is far too obsessed with having every function return some type constructor to encode potential effects (and then mostly using one of _no effect_ with `Id` or _all of the effects_ with `IO`), this is one of the places where it makes undeniable sense.

`evalFree` is meant to evaluate programs such as chains of `Console` statements. These can absolutely be effectful: reading from stdin can fail, for example, and we want `evalFree` to support this; it wouldn't be very useful otherwise. And since the least bad tool Scala offers to encode effects is type constructors, well, we need `evalFree` to be able to return a `G[A]` rather than an `A`, where `G` might be `Either` for encoding errors, for example.

It will thus look something like this:

```scala
def evalFree[F[_], G[_], A](
  fa     : Free[F, A],
  handler: [X] => F[X] => X
): G[A] = fa match
  case Pure(a)      => ???
  case Flatten(ffa) => ???
```

The type of `handler` is almost certainly wrong (intuitively, you'd expect it to return a `G[X]` to match the signature of `evalFree`, but we don't yet _know_ that). Aside from that, this is our previous `evalFree` with a new `G` type parameter and the implementation removed. We know have to write it back.

### Evaluating `Pure`

Let's start with the easy part, the `Pure` branch. We have an `A` and want to return a `G[A]`, which gives us the following diagram:

![evalFree of Pure: problem](/img/free_monad/evalM_pure_before_pure.svg)

We've encountered a function that, given some `A`, lifts it into a `G[A]` multiple times already: that's `pure`. I'm going to take a bit of a shorcut here and say that `pure` is a monadic function - it's not, it's an applicative one, but we're encoding effects and in Scala, correctly or not, we will always associate effects with monads. So in order to be able to go from `A` to `G[A]`, we need `G` to be a monad, which gives us the following solution:

![evalFree of Pure: solution](/img/free_monad/evalM_pure_pure.svg)

The code is then trivial to update:

```scala
def evalFree[F[_], G[_]: Monad, A](
  fa     : Free[F, A],
  handler: [X] => F[X] => X
): G[A] = fa match
  case Pure(a)      => a.pure
  case Flatten(ffa) => ???
```

### Evaluation `Flatten`

`Flatten` is a little more complicated.

We have an `F[Free[F, A]]` (wrapped inside `Flatten`) and want to go to a `G[A]` (`evalFree`'s return type).

`Free` is a recursive data type, so we're almost certain to need `evalFree` to be recursive. We'll add it to the diagram.

![evalFree of Flatten: problem](/img/free_monad/evalM_problem.svg)

That odd, diagonal way of adding `evalFree` is fully intended: it should make you think of a triangle with a missing corner. And we know what triangles mean in these diagrams, right? Something monadic. As luck has it, we've just added the requirement that `G` have an instance of `Monad`, so we can use `flatMap` to draw the missing part of the triangle:

![evalFree of Flatten: flatMap](/img/free_monad/evalM_flatten_problem_flatMap.svg)

Which means the only thing we need to solve our problem is to go from `F[Free[F, A]]` to `G[Free[F, A]]`. This one might be a little tricky to spot, so let's make it a little simpler with a type alias: `X = Free[F, A]`.

With this `X`, we need to go from `F[X]` to `G[X]` - which looks very much like `handler`, but with the modification our instinct told us was probably coming earlier. Updating `handler`'s type to `[X] => F[X] => G[X]`, then, allows us to complete the diagram:

![evalFree of Flatten: solution](/img/free_monad/evalM_flatten_solution_full.svg)

And our final implementation of `evalFree` is obtained by simply following the arrows:

```scala
def evalFree[F[_], G[_]: Monad, A](
  fa     : Free[F, A],
  handler: [X] => F[X] => G[X]
): G[A] = fa match
  case Pure(a)      => a.pure
  case Flatten(ffa) => handler(ffa).flatMap(evalFree(_, handler))
```

## Actual interpreters
It's only fair, after all this work, that I show a couple of interpreters.

### Non-effectful interpreter

A trivial interpreter is `eval` itself, which doesn't encode any effect. The _no effect_ effect is `Id`, traditionally defined as:

```scala
type Id[X] = X
```

`Id` is relatively easily defined to have a `Monad` instance (I'll leave this as an exercise to bored readers).

At the time of writing, Scala 3's support for polymorphic functions type inference and eta-expansion isn't great (I don't think it's actually implemented), so we need a little more boilerplate to let the compiler know `eval` is of the right type:

```scala
val handler: [A] => Console[A] => Id[A] =
  [A] => (ca: Console[A]) => eval(ca)
```

And that's "all" there is to it. `handler` is now a perfectly fine non-effectful interpreter of chains of `Console` statements encoded using `Free`.

## Error handling interpreter

Our previous interpreter assumes console statements can never fail, which is a bit of a stretch. Reading from stdin might throw, for example.

The _this can fail_ effect is `Either`, for which I'm not going to bother giving a definition or a `Monad` instance, as they're part of the standard library.

Here's a possible implementation of such a handler:

```scala
val handler =
  [A] => (ca: Console[A]) => ca match
    case Print(msg, next) =>
      println(msg)
      Right(next())

    case Read(next) =>
      Try(scala.io.StdIn.readLine()).toEither.map(next)
```

## What next?

That's it, really. We've done all we set out to do, and more. All that's left is for us to conclude and hint at potential improvements.
