---
title:  Things that are things, but not other things
layout: article
date:   20221106
---

Categorical abstractions are often explained through example, which I don't think really works and much prefer [teaching by use case]({{ site.baseurl}}/articles/function_reuse/).

But once you understand the purpose of each abstraction, I do feel that examples can be useful to consolidate that understanding. There's a small problem there, however. Take the following diagram, which represents the various abstractions I'm interested in here:

<span class="figure">
![Overview](/img/things_that_are_things/overview.svg)
</span>

The issue is that most common examples of, say, `Functor`, also happen to be `Monad`, which makes it hard to see the subtleties of intermediate elements.

The purpose of this post, then, is to give examples of things that are things, but not other things - things that are a `Functor`, for example, but not an `Apply`.

We'll simply go through each atomic path in the diagram and give an example of something that is the _source_, but not the _target_, of each arrow. This will cover every possible path transitively: if, for example, we have an example of something that is a `Functor` but not an `Apply`, it won't be an `Applicative`, `FlatMap` or `Monad` either.

Note that this article is not intended to be very formal. I'll wave my hands quite a bit, and use relatively lose definitions of the various categorical abstractions. The point is not for this to be absolutely precise (it would involve quite a bit more uninteresting code), but to give intuitions.

## Things that are not a `Functor`

<span class="figure">
![Overview](/img/things_that_are_things/not_functor.svg)
</span>


This one is actually a little bit tricky: most type constructors *are* `Functor`s.

A good example of something that isn't, however, is `Predicate`:

```scala
type Predicate[A] = A => Boolean
```

`Predicate` makes it impossible to write `map`:

```scala
def map[A, B](pa: Predicate[A])(f: A => B): Predicate[B] =
  (b: B) => ???
```

We get stuck immediately: we have a `B`, but both `pa` and `f` take an `A`. There's nothing we can do with that `B`, and certainly not turn it into a `Boolean`.

`Predicate` is not a `Functor` because there's no way of implementing `map` for it.

Technically, that's because our parameter appears in contravariant position, making `Predicate` a contravariant `Functor` (as opposed to a covariant one, which is what most people mean when they use the short form `Functor`).

## Things that are a `Functor`, but not an `Apply`

<span class="figure">
![Functor, not apply](/img/things_that_are_things/functor_not_apply.svg)
</span>

### Intuition

The crucial difference between `Functor` and `Apply` is that the latter can work with 2 (or more) values. Anything that is an `Apply` will have a `map2` function:

```scala
def map2[A, B, C](la: F[A], lb: F[B])(f: (A, B) => C): F[C] =
  ???
```

What we need to find is a type for which we can implement `map`, but not `map2`.


### Counter example

Bearing that in mind, take labelled data: arbitrary data associated with a label (a log level, in our example, just to have something).
```scala
enum Label:
  case Debug, Info, Warn, Error

case class Labelled[A](label: Label, value: A)
```

Importantly, there is no reasonable way of combining labels - what would it mean, for example, to combine `Debug` and `Error`?

`Labelled` has an obvious `map` implementation, but `map2` is problematic:


```scala
def map2[A, B, C](la: Labelled[A], lb: Labelled[B])(f: (A, B) => C): Labelled[C] =
  Labelled(
    value = f(la.value, lb.value),
    label = ???
  )
```

By specification, we can't go any further. It will be impossible to combine the labels of `la` and `lb`, because labels cannot be combined.

We could, had we no shame, write something like this:

```scala
def map2[A, B, C](la: Labelled[A], lb: Labelled[B])(f: (A, B) => C): Labelled[C] =
  Labelled(
    value = f(la.value, lb.value),
    label = Label.Error           // Oh, the shame.
  )
```

But on top of the obvious difficulties we'd have looking at ourselves in the mirror, this is a little bit of a cheat: we've decided that combining two labels always resulted in `Error`. Our implementation is technically correct, and even has the properties you'd expect (such as associativity), but... when the specifications say _you can't combine labels_ and we had to, well, combine labels, in order to write `map2`, it's a little bit hard to argue that our implementation is valid.

This is a pattern we'll encounter again: sometimes, we'll be able to write something that matches the shape of the data, but not its semantics.

### Generic pattern

You can generalise the concept of `Labelled` to the product of a type parameter (`A`) with a type that does not admit a semigroup (`Label`).

It can be entertaining, for an admittedly novel definition of the term, to think about how writing our bad `map2` implementation is actually giving `Label` a `Semigroup` instance, and thus breaking the generic _`Functor` but not `Apply`_ pattern.

## Things that are an `Apply`, but not an `Applicative`

<span class="figure">
![Apply, not Applicative](/img/things_that_are_things/apply_not_applicative.svg)
</span>

### Intuition

The crucial difference between an `Apply` and an `Applicative` is that the latter knows how to lift values: anything that is an `Applicative` must have a `pure` function.

```scala
def pure[A](a: A): F[A] =
  ???
```

What we need to find is a type for which we can implement `map2` but not `pure`.

### Counter example

We can use the same idea as for `Apply` and take a product type that prevents us from implementing `pure`. It must, however, be a type for which it makes sense to combine values.

Take weighted data:

```scala
case class Weighted[A](weight: PosInt, value: A)
```

Where `PosInt` is any integer greater than 0 (such as the one defined in the [refined](https://github.com/fthomas/refined) library).

There is no issue writing `map2`, we can just:
- combine values using the specified `f`.
- combine weights by adding them.

On the other hand, `pure` is more problematic:

```scala
def pure[A](a: A): Weighted[A] =
  Weighted(
    value  = a,
    weight = ???
  )
```

There is no obvious value we can use for the weight, as the only one that would make sense, 0, is not a valid `PosInt`.

And thus, `Weighted` is an `Apply`, but not an `Applicative`.

### Generic pattern

`Weighted` is an instance of a more generic pattern: the product of an `A` with something that admits a `Semigroup` (to combine values) but not a `Monoid` (to prevent `pure` implementations) will always be an `Apply`, but not an `Applicative`.


## Things that are an `Applicative`, but not a `Monad`

<span class="figure">
![Applicative, not Monad](/img/things_that_are_things/applicative_not_monad.svg)
</span>

I know of 2 different families of counter-examples for this.

### Invalid `flatMap`

One set of counter examples would be all the types for which you cannot implement `flatMap` without cheating.

```scala
def flatMap[A, B](fa: F[A])(f: A => F[B]): F[B] =
  ???
```

The trick here is to make it impossible to call `f`, which is easily achieved by not having an `A` to apply it on. For example:

```scala
case class Flag[A](flag: Boolean)
```

`Flag` doesn't actually keep track of the `A` it refers to, but only of whether it has been flagged. We'll consider that the behaviour of the flag is the one you'd intuitively expect:
- defaults to `false` (which gives us `pure`).
- combining two flags is done by taking their logical `OR` (which gives us `map2`).

`flatMap` is problematic, however:


```scala
def flatMap[A, B](fa: Flag[A])(f: A => Flag[B]): Flag[B] =
  Flag(
    flag = ???
  )
```

We have nothing to call apply `f` to. The only way we could conceivably implement `flatMap` is by ignoring `f` altogether and taking `fa`'s flag:

```scala
def flatMap[A, B](fa: Flag[A])(f: A => Flag[B]): Flag[B] =
  Flag(
    flag = fa.flag
  )
```

Intuitively though, this is wrong - `f` might be doing important work and return a useful flag, and we're ignoring that. Our implementation typechecks, but it cannot be legal.

This intuition is captured by the _left associativity_ monad law, which tells us that sane implementations should respect:

```scala
// Lifting `a` and flatMapping `f` into it must be equivalent to
// just applying `f` to `a`.
flatMap(pure(a))(f) == f(a)
```

And we can easily break it using our bad implementation:

```scala
val f = (i: Int) => Flag(i % 2 != 0)
val a = 1

flatMap(pure(a))(f)
// Flag(false)

f(a)
// Flag(true)
```

And again, intuitively, this all makes sense: `flatMap` captures chained computations - computations that depend on the result of previous ones. With `Flag`, we don't store the result of previous computations, which makes it quite a bit harder to depend on them.

Note that `Flag` is a specialisation of a more generic pattern: `Const`, where the non-phantom type parameter admits a `Monoid`, is an `Applicative` but not a `Monad`.


### Wrong semantics

Our second example is `Validated`, which is another example of a type for which we can write an instance that works for the shape of the data, but not its semantics.

The purpose of `Validated` is to encode computations that can fail. You might argue that we already have `Either` for that, but there's a subtle difference: `Either` fails on the first error, where `Validated` will accumulate all of them.

But, yes, `Validated` is very similar to `Either`, so much so that its shape is *exactly* the same:

```scala
type Validated[E, A] = Either[E, A]
```

By constraining the error type to a `Semigroup`, we can easily implement an instance of `Applicative` for `Validated`. Here's the `map2` implementation, for example:

```scala
def map2[A, B, C, E: Semigroup](lhs: Validated[E, A], rhs: Validated[E, B])(f: (A, B) => C): Validated[E, C] =
  (lhs, rhs) match
    case (Left(e1), Left(e2)) => Left(combine(e1, e2))
    case (Left(e1), _)        => Left(e1)
    case (_, Left(e2))        => Left(e2)
    case (Right(a), Right(b)) => Right(f(a, b))
```

We'll combine errors if there are more than one, ignore successes if we have an error, and combine successes using the specified function otherwise. A little boilerplatey, certainly, but not terribly hard to write.

We encounter a problem when trying to write `flatMap`, however:

```scala
def flatMap[A, B, E: Semigroup](fa: Validated[A])(f: A => Validated[B]): Validated[B] =
  fa match
    case Right(a) => f(a)
    case Left(e)  => ???
```

The success case is straightforward, but the error one is a little problematic: `f` takes an `A`, but we don't have one. This means we can't run the second part of the computation, and will not know whether it fails. We cannot accumulate errors.

You might argue that we could definitely write something that works - just return the same error. This would type check, but, and this is important, *not match our specifications*. We want to accumulate errors, but that `flatMap` implementation doesn't. We've provided an answer, certainly, but to a different problem (it would, in fact, be the right `flatMap` implementation for `Either`).

The observation we made for `Flag` applies here too: intuitively, it makes sense that `Validated` cannot have a `flatMap` implementation. In order to accumulate errors, you need to be able to run your computations independently, and `flatMap` is exactly for running computations that depend on each other.

## Things that are an `Apply`, but not a `FlatMap`

<span class="figure">
![Apply, not FlatMap](/img/things_that_are_things/apply_not_flatmap.svg)
</span>

### Intuition

The first thing to realise is that we already have examples of this pattern. We've already come up with types that are `Applicative` but for which we couldn't write `flatMap`. Since an `Applicative` is also an `Apply`, then an `Applicative` for which we cannot implement `flatMap` is... exactly what we're looking for.

It feels like a bit of a cheat, however. When we say that a type is an `Apply`, there's the implication that it's not an `Applicative`. So how could we come up with something that is an `Apply`, but not an `Applicative` or `FlatMap`?

Well, we could merge the patterns of _`Apply` but not `Applicative`_ and _`Applicative` but not `FlatMap`_:
- has a field of a type that admits combination, but not a default value (`Semigroup`, but not `Monoid`).
- doesn't have an `A` on which to apply the function passed to `flatMap`.

### Counter example

This should look very familiar, as it mixes `Flag` and `Weighted`:

```scala
case class Weight[A](weight: PosInt)
```

`Weight` is an `Apply`, with the obvious implementations of `map` and `map2`.

`Weight` is not an `Applicative` for the same reason that `Weighted` isn't: we can't provide a default `PosInt` value.

`Weight` is not a `FlatMap` for the same reason that `Flag` isn't: we can't implement a `flatMap` that actually uses `f`.

### Generic pattern

Like `Flag`, `Weight` is a specialisation of `Const`, but with slightly different constraints: any `Const` where the non-phantom type parameter admits a `Semigroup` but not a `Monoid` is an `Apply` but not a `FlatMap`.

## Things that are a `FlatMap`, but not a `Monad`

<span class="figure">
![FlatMap, not Monad](/img/things_that_are_things/flatmap_not_monad.svg)
</span>

### Intuition

The only difference between a `FlatMap` and a `Monad` is `pure`: a `Monad` must be able to lift values.

We're looking, then, for something that supports `flatten` but not `pure`, where `flatten` is:

```scala
def flatten[A](ffa: F[F[A]]): F[A] =
  ???
```

### Counter example

Consider key/value pairs, such as `Environment`:

```scala
type Environment[A] = Map[NonEmptyString, A]
```

Each key represents the path to a value, represented as a `NonEmptyString` - where `NonEmptyString` is the obvious type, such as the one defined in [refined](https://github.com/fthomas/refined).

Flattening nested `Environment`s is achieved by merging paths:

```scala
def flatten[A](eea: Environment[Environment[A]]): Environment[A] =
  val builder = Map.newBuilder[NonEmptyString, A]

  eea.foreach { case (parent, ea) =>
    ea.foreach { case (child, a) =>
      builder += s"$parent.$child" -> a
    }
  }

  builder.result()
```

Here's an illustration of how this behaves, to clarify things:
```scala
flatten(Map(
  "a" -> Map(
    "b" -> 1,
    "c" -> 2
  ),
  "d" -> Map(
    "e" -> 3,
    "f" -> 4
  )
))
// Map(a.b -> 1, a.c -> 2, d.e -> 3, d.f -> 4)
```

`flatten` wasn't much of a problem, but what about `pure`?

```scala
def pure[A](a: A): Environment[A] =
  Map(
    ??? -> a
  )
```

We don't have a key to associate with the specified value, and have no means of summoning one out of thin air. `pure` cannot be implemented, and thus, `Environment` is a `FlatMap` that isn't a `Monad`.

### Generic pattern

I specialised things to a `Map[NonEmptyString, A]` here, to make things clear, but this actually generalises to `Map[A, B]`, as discussed, for example, [here](https://github.com/typelevel/cats/issues/3).
