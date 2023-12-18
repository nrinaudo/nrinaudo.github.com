---
title: Composing programs
layout: article
series: free_monad
date:   20231116
---

We have now decomposed our `program` in smaller parts, `ask` and `greet`. Next on the agenda is recomposing them. Or, more concretely, fill in the `???` in the following code:

```scala
val ask: Chain[String] =
  Next(Print("What is your name?", () =>
    Next(Read(name => Done(name)))))

val greet: String => Chain[Unit] =
  name =>
    Next(Print(s"Hello, $name!", () =>
      Done(())))

val program: Chain[Unit] =
  ???
```

This is another problem best solved using diagrams, as viewed in the previous section. Here's how to view this specific problem:

![Problem statement](/img/free_monad/chain_ask_greet_flatmap_before.svg)

We start from `ask`, a `Chain[String]`, and must go to `program`, a `Chain[Unit]`.

We're also provided with `greet`, a `String => Chain[Unit]`.

I quite like such diagrams because they make it easy to spot patterns that I wouldn't necessarily see in code. Here, for example, that triangular shape is very symptomatic of _something monadic is going on_. And yes, if you look at the types that we have and how to get them to match up, `flatMap(greet)` is clearly the solution:

![Solution with flatMap](/img/free_monad/chain_ask_greet_flatmap.svg)



What this means, then, is that we'd really like `Chain` to be a `Monad`, because we'll then get composition for free, in a way that is so idiomatic to the language that it has dedicated syntax in the form of for-comprehensions.

This means that we need to fill in the `???` in the following piece of code:

```scala
given Monad[Chain] with
  extension [A](cchain: Chain[Chain[A]])
    def flatten: Chain[A] = ???

  extension [A](chain: Chain[A])
    def map[B](f: A => B): Chain[B] = ???

  extension [A](a: A)
    def pure: Chain[A] = ???
```

You'll notice that we've chosen the long way around to writing a `Monad` instance. We could write it in terms of `pure` and `flatMap` instead, which is usually less work - in fact, we probably should! But this is an article about `Free` and doing so would lead us to discovering something else entirely (_`Monad` in its most uncomfortable configuration_, remember?).

Right. Now the painful part: actually implementing all of this.

## Implementing `Chain.pure`

Let's start with the simplest problem, `pure`:

```scala
extension [A](a: A)
  def pure: Chain[A] = ???
```

We'll be solving all of these as diagrams, because I feel they make it far easier to see solutions. Of course, `pure` is simple enough that a diagram is a bit overkill, but it makes for a good warmup.

![Chain.pure: problem](/img/free_monad/monad_chain_pure_no_link.svg)

We're starting from an `A` and want to go to a `Chain[A]`. If you think about it a little, you should realise we've already implemented exactly such a function: `Done`.

![Chain.pure: solution](/img/free_monad/monad_chain_pure.svg)

This gives us the following, satisfyingly simple implementation, which we get by just walking the path from start to goal on the diagram:

```scala
extension [A](a: A)
  def pure: Chain[A] = Done(a)
```

## Implementing `Chain.map`

Next up is implementing `map`:

```scala
extension [A](chain: Chain[A])
  def map[B](f: A => B): Chain[B] = ???
```

Our input, `Chain`, is a sum type, so we'll need to solve `map` for all of its variants:

```scala
extension [A](chain: Chain[A])
  def map[B](f: A => B): Chain[B] = chain match
    case Done(a)  => ???
    case Next(ca) => ???
```

### `Done`

Let's start with `Done`, by far the simplest problem. Here's its representation as a diagram:

![Chain.map (Done): problem](/img/free_monad/chain_map_done_problem.svg)

We're starting from an `A`, the value wrapped inside `Done`.

We want to go to a `Chain[B]`, the return type of `map`.

We know how to go from `A` to `B`, because that's exactly what `f` does.

What we need to figure out, then, is how to go from a `B` to a `Chain[B]`, which we've just done when implementing `pure`: that's a call to `Done`.

![Chain.map (Done): solution](/img/free_monad/monad_chain_map_done_solution.svg)

This gives us the implementation for the `Done` branch:

```scala
extension [A](chain: Chain[A])
  def map[B](f: A => B): Chain[B] = chain match
    case Done(a)  => Done(f(a))
    case Next(ca) => ???
```

### `Next`

The `Next` variant is a little more involved, and we'll need to do it in multiple steps.

Here's a diagram of what we have and where we want to go:

![Chain.map (Done): problem](/img/free_monad/monad_chain_map_pure_problem.svg)

We're starting from a `Console[Chain[A]]`, the value wrapped inside of our `Next`.

We want to go to a `Chain[B]`, the return type of `map`.

`f` allows us to go from `A` to `B`.

Finally, we also have `Next`, which allows us to go from a `Console[Chain[B]]` to a `Chain[B]`. Note that I'm cheating a bit for this one - I _know_ we'll need `Next` to solve this diagram and am including it, but not all the other functions that exist and give us a `Chain[B]`, such as `Done`. Hopefully you'll forgive me this small shortcut.

This diagram looks a lot less straightforward to solve. The process now is to try and flesh it out in order to build a path from our start point to our goal.

One function we have but haven't yet included is `map` itself. If you think about it though, we're trying to write a function that works on a recursive data type, the solution is almost guaranteed to be recursive: `map` will need to be defined in terms of itself. Let's add it to the diagram, seen as a function that turns an `A => B` into a `Chain[A] => Chain[B]`:

![Chain.map (Done): recursive step](/img/free_monad/monad_chain_map_pure_recursive_map.svg)

Pay attention to that rectangular shape at the bottom of the diagram. It will almost always denote something functorial going on, just like it does here: this works because `Chain` is a `Functor` (by virtue of being a `Monad`, which is what we're trying to prove).

Bearing that in mind, can you spot another rectangular shape we'd quite like to draw?

Here it is:

![Chain.map (Done): another map](/img/free_monad/monad_chain_map_next_before_lift.svg)

If we managed to lift that bottom arrow to link the two upper nodes, then we'd have a direct path from our starting point to our goal. And as I just said, that rectangular shape means something functioral is going on: we're trying to lift a function inside of `Console`.

That last sentence might seem a little obscure if you're not used to my verbal shorcuts (which might not always be very correct), so: when I say _we want to lift some `A => B` inside of some `G`_, it means we want to be able to produce a `G[A] => G[B]`.

Since we want to lift a function inside of `Console`, that means we need it to be a `Functor`. I'm not going to prove that just yet though. First, I want to finish proving that `Chain` is a `Monad`, so I'll just make proving `Console` is a `Functor` a goal we'll need to discharge later to complete the overarching proof. Second, if you look at `Console`, it _clearly_ is a `Functor`: its polymorphic part is on the return type of a wrapped function, and a function is a `Functor` on its return type. Don't worry if this didn't make sense to you, we'll write a concrete implementation later and you can just take this as _we have good reasons to think that `Console` is a `Functor` and will rely on it for the moment_.

So, assuming `Console` is indeed a `Functor`, we have our solution:

![Chain.map (Done): solution](/img/free_monad/monad_chain_map_pure_solution.svg)

This translates directly into the following code:

```scala
extension [A](chain: Chain[A])
  def map[B](f: A => B): Chain[B] = chain match
    case Done(a)  => Done(f(a))
    case Next(ca) => Next(ca.map(_.map(f)))
```

## Implementing `Chain.flatten`

We now need to implement the last part of the puzzle, `flatten`:

```scala
extension [A](cchain: Chain[Chain[A]])
  def flatten: Chain[A] = ???
```

`Chain` is a sum type, so we'll need to solve `flatten` for all its variants:

```scala
extension [A](cchain: Chain[Chain[A]])
  def flatten: Chain[A] = cchain match
    case Done(ca)  => ???
    case Next(cca) => ???
```

### `Done`

After the relatively complex exercise that was `map`, `flatten` for `Done` will be a pleasant diversion:

![Chain.flatten (Done): solution](/img/free_monad/monad_consolef_pure_flatten.svg)

We have a `Chain[A]` and need to return a `Chain[A]`. There's literally nothing for us to do here:

```scala
extension [A](cchain: Chain[Chain[A]])
  def flatten: Chain[A] = cchain match
    case Done(ca)  => ca
    case Next(cca) => ???
```

### `Next`

`Next` is going to be a little bit more work, but we've already done most of the heavy lifting in `map`. Here's the diagram we're trying to solve:

![Chain.flatten (Done): solution](/img/free_monad/monad_chain_flatten_next_problem.svg)

The start point and goal are the same as usual. We also know that `Chain` is recursive, so we're very likely to need to make `flatten` recursive as well and added it to the diagram. Finally, my usual cheat of including a function I know we'll need a bit later and have already defined: `Next`.

If you've been paying attention, and squint a little at that diagram, you'll spot the telltale rectangular shape. We want to lift that `flatten` inside of `Console` - but, as luck has it, we're already assuming that `Console` is a `Functor`. This allows us to solve the diagram:

![Chain.flatten (Done): solution](/img/free_monad/monad_chain_flatten_next_solution_full.svg)

Which gives us the following implementation:

```scala
extension [A](cchain: Chain[Chain[A]])
  def flatten: Chain[A] = cchain match
    case Done(ca)  => ca
    case Next(cca) => Next(cca.map(_.flatten))
```

## Tying loose ends

If we put everything we've written together, here's the complete `Monad` implementation for `Chain`:

```scala
given Monad[Chain] with
  extension [A](cchain: Chain[Chain[A]])
    def flatten: Chain[A] = cchain match
      case Done(ca)  => ca
      case Next(cca) => Next(cca.map(_.flatten))

  extension [A](chain: Chain[A])
    def map[B](f: A => B): Chain[B] = chain match
      case Done(a)  => Done(f(a))
      case Next(ca) => Next(ca.map(_.map(f)))

  extension [A](a: A)
    def pure: Chain[A] = Done(a)
```

The only thing we still have to do is prove that `Command` is in fact a `Functor`, which means filling in the blanks in the following piece of code:

```scala
given Functor[Console] with
  extension [A](console: Console[A])
    def map[B](f: A => B): Console[B] = console match
      case Print(msg, next) => ???
      case Read(next)       => ???
```

This is not a particularly interesting exercise - it is, in fact, something I'm pretty sure we could get the compiler to derive for us. So here's the solution: we just need to post-compose `f` with `next` (which, rather unsurprisingly, is exactly what the `Functor` instance of a function does):

```scala
given Functor[Console] with
  extension [A](console: Console[A])
    def map[B](f: A => B): Console[B] = console match
      case Print(msg, next) => Print(msg, next andThen f)
      case Read(next)       => Read(next andThen f)
```

And with that, we've finished making `Chain` into a `Monad`, which allows us to implement `program` as the simple composition of `ask` and `greet` (this is what we set out to do, remember?):

```scala
val ask: Chain[String] =
  Next(Print("What is your name?", () =>
    Next(Read(name => Done(name)))))

val greet: String => Chain[Unit] =
  name =>
    Next(Print(s"Hello, $name!", () =>
      Done(())))

val program: Chain[Unit] =
  ask.flatMap(greet)
```

## What next?

We're finished making `Chain` very comfortably composable by giving it a `Monad` instance. But writing the bits we want to compose, however, is _extremely_ uncomfortable - look at all the code required to write `ask` and `greet`. Our next step will be to try and factor out all the boilerplate.
