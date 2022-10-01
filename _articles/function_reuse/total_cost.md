---
title: Total cost of a basket
layout: article
series: function_reuse
date:   20220904
---

## Problem

Now that we know how to filter for reasonably priced items, and to pick the cheapest of similar ones, we'd like to be able to know how much all the items we selected would cost.

This, again, is pretty easy to implement. We'll represent a basket of items as a `List`, a famously recursive data type, which immediately suggests natural recursion:
- in the empty case, the price of a basket is 0.
- in the non empty case, the price of a basket is the price of its head added to the price of its tail.

```scala
def totalCost(
  items: List[Item]
): Int =
  items match
    case head :: tail => head.price + totalCost(tail)
    case Nil          => 0
```

Our ultimate goal, however, is to work "within some `F`": we want to write `totalCostF` where all `Item`s are wrapped in `F`:

```scala
def totalCostF[F[_]](
  fitems: List[F[Item]]
): F[Int] =
  ???
```

This feels pretty straightforward - we're still working with a `List`, so we can attempt to replicate our natural recursion solution:

```scala
def totalCostF[F[_]](
  fitems: List[F[Item]]
): F[Int] =
  fitems match
    case head :: tail => head.price + totalCostF(tail)
    case Nil          => ???
```

This does not quite work, however. In the non-empty case, `head` is in an `F`, so is the result of `totalCostF`, but `+` works on raw integers. Luckily, we just created a solution for that exact scenario: `map2`, provided that `F` is an `Apply`:

```scala
def totalCostF[F[_]: Apply](
  fitems: List[F[Item]]
): F[Int] =
  fitems match
    case head :: tail => (head, totalCostF(tail)).map2(_.price + _)
    case Nil          => ???
```

We still get stuck, however, in the empty case. We would like the empty list to have a cost of 0, but this needs to be an `F[Int]`, and we do not know how to put 0 in an `F`.

## Solution

We've done this a few times already though, haven't we, so maybe we don't need to mess around with diagrams this time. We know exactly what to wish for: a function that, given a value, lifts it in some `F`. And we know to encode that as a type class with a creative name, such as `LiftValue`:


```scala
trait LiftValue[F[_]] extends Apply[F]:
  extension [A](a: A)
    def liftValue: F[A]
```

Note that `LiftValue` is an `Apply`, because `totalCostF` needs to call `map2` on top of being able to lift a value.

Armed with `LiftValue`, we can update our code to compile and work:

```scala
def totalCostF[F[_]: LiftValue](
  fitems: List[F[Item]]
): F[Int] =
  fitems match
    case head :: tail => (head, totalCostF(tail)).map2(_.price + _)
    case Nil          => 0.liftValue
```

And this is certainly a solution. I would argue, however, that while it *is* a solution, it's not a solution to the problem we were trying to solve. We wanted to write `totalCostF` in terms of `totalCost`, not to re-implement it from scratch and end up something that is very similar but not quite identical, and that certainly doesn't call `totalCost`.

As developers, our usual strategy when faced with this type of situation is to complain that the problem was wrong in the first place, and attempt to get it changed to a different one, hopefully one whose solution is the one we already came up with. And while this might sound like a criticism, it's really not meant to be. This notion of a solution in search of a problem has led to many a success story in our industry - take golang, for example. Or cryptocurrencies. Elon Musk. All solutions in search of a problem that are wildly more successful than they have any right to be.

But today though, we'll try to do the right thing and answer the question that was asked, not the one we felt like answering instead. And in order to work it out, well, we *will* need to draw a few things.


## Intuition

This is the diagram we're trying to solve:

<span class="figure">
![Ap, lifted](/img/function_reuse/pure-before.svg)
</span>

Clearly, it doesn't commute yet. But we do have a function with a single parameter, `totalCost`, and lifting anything we could until we got stuck has worked for us so far, so let's see where that takes us.

<span class="figure">
![Ap, lifted](/img/function_reuse/pure-lift.svg)
</span>

It does make the diagram look a lot more solvable, because now, all we need is to go from `List[F[Item]]` to `F[List[Item]]`. We can't, of course, but that's not stopped us before, we can pretend that it's a solved problem and carry on. Let's call the solution to that problem `flip`, because it kind of looks like we're flipping type constructors.

<span class="figure">
![Ap, lifted](/img/function_reuse/pure-required.svg)
</span>

## Solution

There's a little twist here though: if you look at the diagram, `flip` is not a property of `F`, but of `List`. We'll not use a type class for this, as we don't need to abstract over the notion of flipping - it can be a simple function on `F`:

```scala
def flip[F[_], A](
  fas: List[F[A]]
): F[List[A]] =
  fas match
    case head :: tail => ???
    case Nil          => ???
```

This should be familiar by now: `List` is a recursive data type, we should try natural recursion.

The non-empty case doesn't quite work out immediately because the head and the flipped tailed are in some `F` and `::` takes non-wrapped values, but we know that this is easily solved with `map2`:

```scala
def flip[F[_]: Apply, A](
  fas: List[F[A]]
): F[List[A]] =
  fas match
    case head :: tail => (head, flip(tail)).map2(_ :: _)
    case Nil          => ???
```

The empty case is equally easy to solve: we need to lift `Nil` in `F`, and have just created `LiftValue` for that very purpose:


```scala
def flip[F[_]: LiftValue, A](
  fas: List[F[A]]
): F[List[A]] =
  fas match
    case head :: tail => (head, flip(tail)).map2(_ :: _)
    case Nil          => Nil.liftValue
```

As an aside, it's interesting that our initial solution, the one that almost but not quite answered our problem, turned out to be a critical part of the actual solution.

Armed with `flip`, we get a diagram that commutes:

<span class="figure">
![Ap, lifted](/img/function_reuse/pure-after.svg)
</span>

And implementing `totalCostF` is now a simple matter of following the arrows:

```scala
def totalCostF[F[_]: LiftValue](
  fitems: List[F[Item]]
): F[Int] =
  (flip[F, Item] andThen totalCost.lift).apply(fitem)
```

We can, of course, rewrite that in a way that's a little bit more OOP, a little more pleasant to read:

```scala
def totalCostF[F[_]: LiftValue](
  fitems: List[F[Item]]
): F[Int] =
  flip(fitems).map(totalCost)
```

## Naming things

Finally, we'll need to give `LiftValue` its proper name: `Applicative`, which I believe initially comes from [Applicative Programming with Effects](https://www.staff.city.ac.uk/~ross/papers/Applicative.html), by McBride and Paterson.

And `liftValue` is traditionally known as `pure`, which gives us the following type class:

```scala
trait Applicative[F[_]] extends Apply[F]:
  extension [A](a: A)
    def pure: F[A]
```

## Key takeaways

What we’ve learned so far is that we have `Functor` to work with a single value in some `F`, `Apply` to work with 1 *or more* values in some `F`, and `Applicative` to work with *0 or more* values in some `F`.

`Applicative`'s core function is `pure`, but its most used tool is `flip` (whose actual name is `sequence`, a close sibling to `traverse`, famously the solution to most problems in FP).
