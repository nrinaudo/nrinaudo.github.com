---
title: Cheapest of two items
layout: article
series: function_reuse
date:   20220903
---

## Problem

Now that we know how to filter out items that are too expensive, we're faced with another problem: we might find multiple versions of the same item, all affordable, but at difference prices. We obviously want to pick the cheapest one.

The "simple" version of that problem is very manageable. Given two `Item`s, compare the prices and return whichever is cheapest:

```scala
def cheapest(
  item1: Item,
  item2: Item
): Item =
  if item1.price > item2.price then item2
  else                              item1
```

`cheapestF` follows the pattern we've been using so far: add an `F` type parameter, wrap all `Item`s in it, and try to work things out.

```scala
def cheapestF[F[_]](
  fitem1: F[Item],
  fitem2: F[Item]
): F[Item] =
  ???
```

We were a little bit stuck before, because we did not know how to work with an abstract `F`, but we now have a tool that might help: `Functor`.

`Functor` allows us to map into each of our `F[Item]`s and get two `Item`s, which is exactly what we need to call `cheapest`:

```scala
def cheapestF[F[_]: Functor](
  fitem1: F[Item],
  fitem2: F[Item]
): F[Item] =
  fitem1.map { item1 =>
    fitem2.map { item2 =>
      cheapest(item1, item2)
    }
  }
```

The problem with this, however, is that it doesn't work. `map` returns something in an `F`, so if you nest `map`s, you get nested `F`s. If we try to compile this code, we'll get a rather obscure error message which is intended to mean something like _expected an `F[Item]` but got an `F[F[Item]]`_.

And try as we might, we won't be able to massage our `map` calls into something that compiles. `map` is great for working with a _single_ value in some `F`, but we have two here, and we're a little bit stuck.

## Intuition

As before, when stuck, start drawing. This is what we want to solve:

<span class="figure">
![Lift2, before](/img/function_reuse/lift2-before.svg)
</span>

Now, you might think this looks quite a bit like the previous diagram, the one that led us to invent `lift`. You might be tempted to suggest that since `lift` worked for a function with a single parameter, we could create `lift2` for functions that take 2 and be done with it:

<span class="figure">
![Lift2, before](/img/function_reuse/lift2-required.svg)
</span>

And that would actually solve the problem! But it would also make for a very boring article, because my next question would be _how about functions that take... *3* parameters?_ and we could be at it for quite a while.

Well. Maybe not that long, this is Scala after all and for whatever reason, functions cannot take more than 22 parameters. But it's still be extremely boring. Instead, let's try to see if we can find a more generic solution to the problem, a way of solving it that generalises for functions of any arity.

When trying to find generic solutions, I like to remove anything specific from the problem and see where that takes me. Here's the generic diagram that we're trying to solve:

<span class="figure">
![Ap, before](/img/function_reuse/ap-before.svg)
</span>

We'd really like to `lift` that function at the bottom - with this kind of problems, a good reflex is to try and lift anything you can, it usually works out. But we can't, because `lift` only works on functions that take a single parameter, and `f` takes 2.

Interestingly though, there is a way of turning a function with 2 parameters into one that takes a single one: [currying](https://en.wikipedia.org/wiki/Currying). If you're already familiar with the concept, great. Otherwise, I would recommend reading up on it, it's both fun and useful, and not at all as complicated as you probably expect it to be.

Currying `f`, then, yields a function that takes a single parameter and returns another function:

<span class="figure">
![Ap, curried](/img/function_reuse/ap-curried.svg)
</span>

And this is great, because we know how to `lift` functions that take a single parameter:

<span class="figure">
![Ap, lifted](/img/function_reuse/ap-lift.svg)
</span>

That result might not look immediately useful, but this is where we need a little bit of an intuitive leap. `f.curried.lift` might not be useful, but *this* would be:

<span class="figure">
![Ap, lifted](/img/function_reuse/ap-pre-split.svg)
</span>

It'd be a great function to have, because if you look at it a certain way, it looks a lot like the result of currying another function - a function that takes two parameters in some `F` and returns a value in some `F`. And, as luck would have it, currying has an inverse function, which we weirdly usually call uncurrying rather than co-currying.

It's not at all a coincidence that uncurrying our function yields a direct solution to our diagram:

<span class="figure">
![Ap, lifted](/img/function_reuse/ap-pre-split-2.svg)
</span>

So, really, solving our diagram is really solving this:

<span class="figure">
![Ap, lifted](/img/function_reuse/ap-before-split.svg)
</span>

Unfortunately, we do not have the tools to do so. But we can certainly wish for them! What we really wished we could do was turn `F[B => C]` into `F[B] => F[C]`, because then we could compose the resulting arrows into our desired function.

Let's call that `split`, because it kind of looks like we're splitting the content of our `F` in two:

<span class="figure">
![Ap, lifted](/img/function_reuse/ap-before-split-3.svg)
</span>

We now get our desired function by composition:

<span class="figure">
![Ap, lifted](/img/function_reuse/ap-split-2.svg)
</span>

This all finally leads to a diagram that commutes, even if a little heavy on the arrows, like a late-days Boromir.

<span class="figure">
![Ap, lifted](/img/function_reuse/ap-full.svg)
</span>

## Solution

We still have a little bit of work to do though. _Somebody_ (not us) will have to work out how to implement `split`, but we need them to be able to provide us with their solution. As before, we'll write that as a type class that exposes the `split` function:

```scala
trait Split[F[_]] extends Functor[F]:
  extension [A, B](ff: F[A => B])
    def split: F[A] => F[B]
```

Note that we've made `Split` into a `Functor`, because our solution involves lifting a unary function.

And now, by simply following the arrows of our diagram, we get a direct implementation of what we were trying to achieve in the first place, `lift2`:

```scala
trait Split[F[_]] extends Functor[F]:
  extension [A, B](ff: F[A => B])
    def split: F[A] => F[B]

  extension [A, B, C](f: (A, B) => C)
    def lift2: (F[A], F[B]) => F[C] =
      Function.uncurried(
        f.curried.lift andThen (_.split)
      )
```

And this happens to be a generic pattern. We could implement `lift3` or, really, `liftN`, by following the exact same principle: assume that you know how to `lift` a function that takes _n - 1_ parameters, and that you want to work with a function that takes _n_. You can use something that's not quite currying but that's very much the same idea to turn your function into one that takes _n - 1_ parameters and returns another function. This allows you to `lift` it, and you'll find that all you need to finish things off is `split`.

Armed with `split`, then, we can work with functions that take as many parameters as we want, even truly unreasonable numbers such as 21, or even 22. Not 23 though, that'd just be crazy.

Right, so now that we have `lift2`, our initial, `cheapestF` diagram commutes:

<span class="figure">
![Ap, lifted](/img/function_reuse/lift2-after.svg)
</span>

And we can write our solution by just following the arrows:

```scala
def cheapestF[F[_]: Split](
  fitem1: F[Item],
  fitem2: F[Item]
): F[Item] =
  cheapest.lift2.apply(fitem1, fitem2)
```

## Common combinators

As before however, this code is a little bit unpleasant, a little bit too functional for our OOP sensibilities. What we really want to write is a method call, something like:

```scala
def cheapestF[F[_]: Split](
  fitem1: F[Item],
  fitem2: F[Item]
): F[Item] =
  (fitem1, fitem2).map2(cheapest)
```

As you'd probably expect, `map2` really is just another way of calling `lift2`:

```scala
trait Split[F[_]] extends Functor[F]:
  extension [A, B](ff: F[A => B])
    def split: F[A] => F[B]

  extension [A, B, C](f: (A, B) => C)
    def lift2: (F[A], F[B]) => F[C] =
      Function.uncurried(
        f.curried.lift andThen (_.split)
      )

  extension [A, B, C](fab: (F[A], F[B]))
    def map2(f: (A, B) => C): F[C] =
      f.lift2.apply(fab._1, fab._2)
```

## Naming things

Finally, that abstraction is obviously not called `Split`. It has the perhaps unfortunate name of `Apply`, because its primary operation is usually called `apply` - but that's kind of a magic almost-keyword in Scala that we try to avoid unless we know what we're doing. Instead, we've called it `ap`, which is probably meant to sound like `map`.

```scala
trait Apply[F[_]] extends Functor[F]:
  extension [A, B](ff: F[A => B])
    def ap: F[A] => F[B]

  extension [A, B, C](f: (A, B) => C)
    def lift2: (F[A], F[B]) => F[C] =
      Function.uncurried(
        f.curried.lift andThen (_.ap)
      )

  extension [A, B, C](fab: (F[A], F[B]))
    def map2(f: (A, B) => C): F[C] =
      f.lift2.apply(fab._1, fab._2)
```


## Key takeaways

What we've learned so far is that while `Functor` was used to work with functions that take a single parameter, `Apply` allows us to work with functions that take *one or more* parameters.

The core function of `Apply` is `split`, but its most directly useful one is `liftN` or, equivalently, `mapN`.
