---
title: Item seller
layout: article
series: function_reuse
date:   20220905
---

## Problem

We have all the basic tools we need to automate online shopping, but there's at least one refinement we should consider. If you've been on an online marketplace recently, you must have noticed the amount of dodgy or outright scammy activity going on.

We'll definitely want to filter out anything that doesn't appear legitimate, which we'll achieve by looking up an item's seller to try and find something fishy in their reviews. In order to do so, we'll need a data type to represent a seller:

```scala
type ReviewId = UUID

case class Seller(
  id     : SellerId,
  name   : String,
  reviews: List[ReviewId]
)
```

Our first task will be to work out how to retrieve an item's seller, which we'd really like to be as simple as a function from `Item` to `Seller`:

```scala
def itemSeller(
  item: Item
): Seller =
  ???
```

This looks easy enough at first blush - after all, `Item` gives us direct access to the corresponding `Seller` identifier, so our first step seems clear:

```scala
def itemSeller(
  item: Item
): Seller =
  item.sellerId
```

But this is where we get stuck. We have nothing to take us from an identifier to the corresponding `Seller`.


## Intuition

Here's a graphical representation of what we're trying to achieve:

<span class="figure">
![Ap, lifted](/img/function_reuse/itemSeller-init.svg)
</span>

This certainly suggests that we should apply our by now-familiar technique of wishful-thinking driven development to get a function from `SellerId` to `Seller`, but... think about it. Can we guarantee that there will always be a `Seller` for a given `SellerID`?

No, we cannot. The `SellerId` might be incorrect, or the corresponding `Seller` might have been deleted, for example. We cannot expect to be provided with a function that somehow summons valid sellers from invalid identifiers - we cannot wish for the impossible.

What we can reasonably wish for, however, is a function from `SellerId` to `Seller` - in some `F`. In the case of a potentially invalid identifier, for example, `F` would be `Option`.

<span class="figure">
![Ap, lifted](/img/function_reuse/itemSeller-loadSeller-full.svg)
</span>

And, using the same example, we can clearly see that we just won't be able to go from `F[Seller]` to `Seller`: if `F` is `Option`, then it might be empty, and we simply won't be able to summon a `Seller` that does not exist. This forces us to change our desired output to the next best thing, `F[Seller]`.

<span class="figure">
![Ap, lifted](/img/function_reuse/itemSeller-required.svg)
</span>

We need to update `itemSeller` to reflect these two modifications:

```scala
def itemSeller[F[_]](
  loadSeller: SellerId => F[Seller],
  item      : Item
): F[Seller] =
  item.sellerId
```

Note how it now takes a `SellerId => F[Seller]`, since we wished for one, and its return type has been changed to `F[Seller]`. This gives us a concrete diagram that commutes:

<span class="figure">
![Ap, lifted](/img/function_reuse/itemSeller-solution.svg)
</span>

Implemeting `itemSeller` is now simply a matter of following the path arrow:

```scala
def itemSeller[F[_]](
  loadSeller: SellerId => F[Seller],
  item      : Item
): F[Seller] =
  loadSeller(item.sellerId)
```

## Problem

We've only solved part of the equation here, though. The point, as always, is to reuse `itemSeller` to work with `F[Item]` - in other words, to write `itemSellerF`.

Before that, however, it's important to pause and realise this is quite a bit different from what we've been doing so far.

From `Functor` to `Applicative`, all we've really been doing is discovering mechanisms for _lifting_ functions in some `F`. When computing the total cost of a basket, for example, we went from `totalCost` (not a single `F` in sight) to `totalCostF`, which wrapped the former's parameters and return value in `F`.

`itemSeller`, however, is different, in that it's already aware of `F`: it returns an `F[Seller]`. This makes things a little bit harder. There's only one `totalCost` function, but there are as many versions of `itemSeller` as there are `F`s - a potentially infinite number. Rather than write infinitely many versions of `itemSellerF`, we'll create a single one that takes a version of `itemSeller` specialised to the right `F`.

This gives us the following signature for `itemSellerF`:

```scala
def itemSellerF[F[_]](
  itemSeller: Item => F[Seller],
  fitem     : F[Item]
): F[Seller] =
  ???
```

Having done all this preparation work, it looks like things might be easy for a change: we have an `F[Item]` and a function that takes an `Item`, this all lines up just right for some functorial goodness:

```scala
def itemSellerF[F[_]: Functor](
  itemSeller: Item => F[Seller],
  fitem     : F[Item]
): F[Seller] =
  fitem.map(itemSeller)
```

This, unfortunately, will not work: `itemSeller` returns a value in some `F`, so does `map` - we're nesting `F`s again, and the compiler is understandably cranky about finding an `F[F[Item]]` where it expected an `F[Item]`.


## Intuition

If we try to represent our problem as a diagram, we get the following:

<span class="figure">
![Ap, lifted](/img/function_reuse/flatMap-before.svg)
</span>

We're trying to go from an `F[Item]` to an `F[Seller]`, and all we know to do is go from an `Item` to an `F[Seller]`.


The first thing that should catch our attention immediately is `itemSeller` - a unary function that's just begging to be lifted.

<span class="figure">
![Ap, lifted](/img/function_reuse/flatMap-lift.svg)
</span>

This diagram almost commutes already: all it needs is a path from `F[F[Seller]]` to `F[Seller]`.

We do not have tools for that yet, but we can certainly wish for them: we need to be able to flatten nested layers of `F`, so we'll ask for the `flatten` function.


<span class="figure">
![Ap, lifted](/img/function_reuse/flatMap-complicated-required.svg)
</span>

## Solution

Having made `flatten` somebody else's problem, we still need to give them a way to provide us with their solution through the usual type class-based encoding:

```scala
trait Flatten[F[_]] extends Functor[F]:
  extension [A](ffa: F[F[A]])
    def flatten: F[A]
```

Armed with `flatten`, we now have a diagram that commutes.


<span class="figure">
![Ap, lifted](/img/function_reuse/flatMap-complicated.svg)
</span>

Implementing `itemSellerF` becomes a simple matter of following arrows, which gives us:

```scala
def itemSellerF[F[_]: Flatten](
  itemSeller: Item => F[Seller],
  fitem     : F[Item]
): F[Seller] =
  (itemSeller.lift andThen (_.flatten)).apply(fitem)
```

## Common combinators

One refinement we can bring to this implementation is to notice this pattern, `lift` followed by `flatten`:

<span class="figure">
![Ap, lifted](/img/function_reuse/flatMap-flatten-hl-2.svg)
</span>

This turns out to be an extremely common pattern - so common, in fact, that we really should give it a name. We'll call it `liftFlat`, since, well, it's `lift`, followed by `flatten`:

```scala
trait Flatten[F[_]] extends Functor[F]:
  extension [A](ffa: F[F[A]])
    def flatten: F[A]

  extension [A, B](f: A => F[B])
    def liftFlat: F[A] => F[B] =
      f.lift andThen (_.flatten)
```

`liftFlat` allows us to remove a large chunk of our diagram and provide a more direct path to the solution.

<span class="figure">
![Ap, lifted](/img/function_reuse/flatMap-flatMap-full.svg)
</span>

Updating the `itemSellerF` implementation accordingly yields something quite a bit simpler as well, even if not yet entirely satisfactory:

```scala
def itemSellerF[F[_]: Flatten](
  itemSeller: Item => F[Seller],
  fitem     : F[Item]
): F[Seller] =
  itemSeller.liftFlat.apply(fitem)
```

As before, we've landed on the functional idiom - not a huge surprise when the diagrams we've been using are really just about function composition.

As OOP developers however, we'd be more comfortable writing something like this:

```scala
def itemSellerF[F[_]: Flatten](
  itemSeller: Item => F[Seller],
  fitem     : F[Item]
): F[Seller] =
  fitem.flatMap(itemSeller)
```

This is trivially implemented, as `flatMap` is just a different way of calling `liftFlat`.

```scala
trait Flatten[F[_]] extends Functor[F]:
  extension [A](ffa: F[F[A]])
    def flatten: F[A]

  extension [A, B](f: A => F[B])
    def liftFlat: F[A] => F[B] =
      f.lift andThen (_.flatten)

  extension [A](fa: F[A])
    def flatMap[B](f: A => F[B]): F[B] =
      f.liftFlat.apply(fa)
```

## Naming things

While `flatten` is the primary operation of `Flatten`, `flatMap` ends up being used far more often - so much so that the abstraction is commonly known as `FlatMap` instead.

```scala
trait FlatMap[F[_]] extends Functor[F]:
  extension [A](ffa: F[F[A]])
    def flatten: F[A]

  extension [A, B](f: A => F[B])
    def liftFlat: F[A] => F[B] =
      f.lift andThen (_.flatten)

  extension [A](fa: F[A])
    def flatMap[B](f: A => F[B]): F[B] =
      f.liftFlat.apply(fa)
```

## Not just a `Functor`

If you've been paying attention, `flatten` might remind you of a problem we solved earlier with `Apply`: when trying to lift a function with 2 parameters, we ended up nesting `map`s, which yielded nested `F`s, and forced us to sidestep the issue entirely by inventing `ap`.

This hints at a relationship between `flatten` and `ap` - they're both things we came up with to avoid nesting `F`s. And it is indeed relatively straightforward to write `ap` in terms of `flatten` (and `map`):

```scala
trait FlatMap[F[_]] extends Apply[F]:
  extension [A](ffa: F[F[A]])
    def flatten: F[A]

  extension [A, B](ff: F[A => B])
    def ap: F[A] => F[B] =
      fa => fa.map { a =>
        ff.map { f =>
          f(a)
        }
      }.flatten

  extension [A, B](f: A => F[B])
    def liftFlat: F[A] => F[B] =
      f.lift andThen (_.flatten)

  extension [A](fa: F[A])
    def flatMap[B](f: A => F[B]): F[B] =
      f.liftFlat.apply(fa)
```

Note that `FlatMap` now extends `Apply`: it's a `Functor` that exposes a valid `ap` implementation, and is therefore a valid `Apply`. This raises an interesting point, if maybe not a terribly useful one: we've used `extends` to mean two different, incompatible things.

`FlatMap extends Functor` means that `Functor` is a *requirement* of `FlatMap` - without a `Functor`, we do not have a `FlatMap`.

`FlatMap extends Apply` means that `Apply` is a *consequence* of `FlatMap` - with a `FlatMap`, we have an `Apply` for free.

Surprisingly, the `extends` keyword, which nobody questions or thinks about too hard, is ambiguous. Not an extremely useful point, certainly, but I do think it's quite interesting.

## Key takeaways

What we've learned so far is that while the `Functor`, `Apply` and `Applicative` family of abstractions is useful to lift functions of any arity in some `F`, they're not sufficient in all scenarios: sometimes, we'll have to work with function that return values in some `F`. When that happens, we'll need `FlatMap`.

`FlatMap`'s core operation is `flatten`, but its most used tool is `liftFlat` or, equivalently, `flatMap`.
