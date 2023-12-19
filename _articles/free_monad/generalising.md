---
title: Generalising Chain
layout: article
series: free_monad
date:   20231118
---

We've solved our initial problem, but have reasons to believe that our `Console`-specific solution might be generalisable to a whole class of problems. In this section, we'll explore that intuition further.

## Actual requirements

### `Chain`
`Chain`, if you think about it, has very few actual requirements. Here's its latest iteration:

```scala
enum Chain[A]:
  case Next(value: Console[Chain[A]])
  case Done(a: A)
```

We've hard-coded this to `Console` because it was the problem we were trying to solve, but we now sort of feel it might be more general than that. We can try playing with that thought by making the wrapped type a parameter:

```scala
enum Chain[F[_], A]:
  case Next(value: F[Chain[F, A]])
  case Done(a: A)
```

We've merely added a type parameter, `F`. Of course, it needs to be a type constructor, since `Console[A]` itself is a type constructor. As a quick aside, you might have heard my opinion on calling all type constructors `F` and how much it annoys me, and might be surprised to see me do just that here. Wait a few paragraphs and you'll see why in this case, `F` is not actually a bad name.

The `Next` variant is interesting. If you know what `Fix` is, this should look _very_ familiar, which is of course no accident - `Fix` is typically used to give a sane type signature to recursive types - to avoid things like `Console[Console[A]]`, like we had before. It's no wonder we ended up with a very similar solution when trying to solve the same problem.

## `Monad[Chain]`

We now need to look at the various bits and pieces we've written that rely on `Chain`. First, its `Monad` instance:

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

If you search through that code, we never actually rely on knowing `Chain` wraps a `Console` anywhere. The only place where we even care about its structure is in the `Next` branch of `flatten` and `map`, and even there, we merely use the fact that it has a `Functor` instance.

So, if all we need is for whatever `Chain` wraps to be a functor, we can refactor the code to include `Chain`'s new type parameter, and express the constraint that it must have a `Functor` instance:

```scala
given [F[_]: Functor]: Monad[Chain[F, _]] with
  extension [A](cchain: Chain[F, Chain[F, A]])
    def flatten: Chain[F, A] = cchain match
      case Done(ca)  => ca
      case Next(cca) => Next(cca.map(_.flatten))

  extension [A](chain: Chain[F, A])
    def map[B](f: A => B): Chain[F, B] = chain match
      case Done(a)  => Done(f(a))
      case Next(ca) => Next(ca.map(_.map(f)))

  extension [A](a: A)
    def pure: Chain[F, A] = Done(a)
```

## `liftChain`

Finally, we get to the tools we created to write atomic statements:

```scala
def liftChain[A](console: Console[A]): Chain[A] =
  Next(console.map(Done.apply))

def print(msg: String): Chain[Unit] =
  liftChain(Print(msg, () => ()))

def read: Chain[String] =
  liftChain(Read(str => str))
```

`liftChain` itself is like `Chain`'s `Monad` instance: it never uses any of `Console`'s structure aside from the fact that it's a functor. We can easily rewrite it in terms of any `F` that has a `Functor` instance:

```scala
def liftChain[F[_]: Functor, A](fa: F[A]): Chain[F, A] =
  Next(fa.map(Done.apply))
```

We also need to update `print` and `read` slightly - `Chain` now takes an additional type parameter, which in the case of these two methods must be `Console`:

```scala
def print(msg: String): Chain[Console, Unit] =
  liftChain(Print(msg, () => ()))

def read: Chain[Console, String] =
  liftChain(Read(str => str))
```

## Inventing `Free`

At this point, it's clear that `Chain` is not the right name for this structure. If you think about it a certain, slightly pretentious way, what we have invented is a structure that, given any type constructor that has a `Functor` instance, gives us a monad for free. Or, put another way, we have invented the free monad over a functor.

Let's give it its traditional name, `Free`:

```scala
enum Free[F[_], A]:
  case Next(value: F[Free[F, A]])
  case Done(a: A)
```

We're not quite done with renaming, however. Look at `Done`: it takes an `A` and produces a `Free[F, A]`. That is very much what `pure` does, so we should call it that:

```scala
enum Free[F[_], A]:
  case Next(value: F[Free[F, A]])
  case Pure(a: A)
```

And finally, look at `Next`: given a value of nested `F`s, it removes one layer of `F`. That is exactly what `flatten` does:

```scala
enum Free[F[_], A]:
  case Flatten(value: F[Free[F, A]])
  case Pure(a: A)
```

And there we have the explanation of the statement made in the introduction: _`Free` is merely the defunctionalisation of `Monad` in its most uncomfortable configuration_.

`Free` is exactly the defunctionalisation of a monad, defined via `pure` and `flatten` with a constraint on being a functor. This configuration is less comfortable than the more common definition via `pure` and `flatMap` (where we can implement `flatten` as `flatMap(id)` and `map(f)` as `flatMap(f andThen pure)`).

Oh, and if you're wondering what would happen were we to defunctionalise monad in its more comfortable configuration? hold that thought.

### What _being free_ means

There is some debate on whether `Free` is free as in _free beer_ (at no cost) or as in _free speech_ (without constraints).

As we've seen, `Free` is definitely free as in beer: the free monad over a functor is something we get for free provided we have a functor. There are many such constructions: the free functor over a type constructor (_coyoneda_), the free monoid over a type (`List`), ...

It's also free as in speech, for reasons that are a little beyond me - it's to do with forming a free algebra, which is not a notion I can explain but also am given to understand is not particularly interesting _in the context of programming_ (as opposed to, say, in category theory, which programming is most definitely not).

This isn't something I initially wanted to talk or write about because I know for a fact people will disagree and sort of shake their head at me in disapproval, but I ended up having to give a talk on this in French, a language where no ambiguity about which meaning of _free_ I'm using exists. Imagine, talking about _la monade libre_ when I really meant _la monade gratuite_!

## Cleaning up

There's a bit of cleaning up to do now that we've renamed `Chain` to `Free`. It's really not interesting, just replacing `Chain` with `Free`, `Next` with `Flatten` and `Done` with `Pure` everywhere, but it must be done if we want our code to keep compiling. Feel absolutely free to skip this unless you've been pasting code in a repl.

First, `Monad[Free]`:
```scala
given [F[_]: Functor]: Monad[Free[F, _]] with
  extension [A](ffa: Free[F, Free[F, A]])
    def flatten: Free[F, A] = ffa match
      case Pure(ca)     => ca
      case Flatten(cca) => Flatten(cca.map(_.flatten))

  extension [A](fa: Free[F, A])
    def map[B](f: A => B): Free[F, B] = fa match
      case Pure(a)     => Pure(f(a))
      case Flatten(ca) => Flatten(ca.map(_.map(f)))

  extension [A](a: A)
    def pure: Free[F, A] = Pure(a)
```

Then, `liftFree`:

```scala
def liftFree[F[_]: Functor, A](fa: F[A]): Free[F, A] =
  Flatten(fa.map(Pure.apply))

def print(msg: String): Free[Console, Unit] =
  liftFree(Print(msg, () => ()))

def read: Free[Console, String] =
  liftFree(Read(str => str))
```

And finally we can rewrite our `program`:

```scala
val program: Free[Console, Unit] = for
  _    <- print("What is your name?")
  name <- read
  _    <- print(s"Hello, $name!")
yield ()
```

## What next?

At this point, we're almost done. Not only have we fully solved our initial problem, but we've also _almost_ finished generalising it to solve any such problem.

_Almost_, however, because we need to adapt our evaluation functions for `Free`. This is not very hard, but still deserves its own section, especially since I'm going to start throwing around words like _effects_ and I'd really prefer the part where I sound like an absolute pillock to be separated from the rest of this article.
