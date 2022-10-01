---
title: Seller reviews
layout: article
series: function_reuse
date:   20220906
---

## Problem

Recall that our ultimate goal is to retrieve all the reviews associated with an item's seller in order to find scam indicators. We already know how to get a `Seller` from a given `Item`, and now need to perform the next step: retrieve a list of reviews from a given `Seller`.

The first thing we'll need is a data type to describe a review.

```scala
case class Review(
  id   : ReviewId,
  body : String
)
```

We then need to figure out how to retrieve the list of reviews associated with a given seller, which would ideally be a simple function from `Seller` to `List[Review]`.

```scala
def sellerReviews(
  seller: Seller
): List[Review] =
  ???
```

We already know how to get a list of review identifiers, as this is provided by `Seller` directly:

```scala
def sellerReviews(
  seller: Seller
): List[Review] =
  seller.reviews
```

But that's as far as we can go here. Try as we might, we have no way to get any closer to our goal.

## Intuition

If we look at the problem as a diagram, here's what we get:

<span class="figure">
![Ap, lifted](/img/function_reuse/sellerReviews-init.svg)
</span>

Spanning that `List[ReviewId]` to `List[Review]` chasm looks a little bit daunting, but we can try to figure this out one small step at a time. Before tackling the notion of lists, how would we go from a `ReviewId` to a `Review`?

This is a problem we've already looked at when trying to go from a `SellerId` to a `Seller`, and the same conclusion applies: we can only reasonably expect to be provided with a function from `ReviewId` to `F[Review]`, because, among other things, we must account for the possibility of a `ReviewId` that doesn't map to an existing `Review`.

<span class="figure">
![Ap, lifted](/img/function_reuse/sellerReviews-before.svg)
</span>

We now have a unary function, which we've by now learned to lift immediately and see what that gets us. There's a subtlety here, however: so far, we've only ever lifted things into an abstract `F`, but in this scenario, what we really want to do is work with a value of type `List[ReviewId]`; we want to lift `loadReview` into `List`.

We don't know that we can, though. As we've seen, we would need `List` to be a `Functor` in order to be allowed to do that. Of *course* `List` is a `Functor`, but we'll still need to prove it at some point by providing an implementation.

<span class="figure">
![Ap, lifted](/img/function_reuse/sellerReviews-lifted.svg)
</span>

The last step we need to make is from `List[F[Review]]` to `List[Review]`.

<span class="figure">
![Ap, lifted](/img/function_reuse/sellerReviews-nope-2.svg)
</span>

This is not a step we'll be able to make, however. We've already seen that while we could flatten nested contexts with `FlatMap`, we cannot get rid of the context entirely - we can't go from an `F[Review]` to a `Review`. Consider the case where `F` is `Option`, for example; by the very definition of `Option`, we do not know for sure that we have an actual value to unwrap.

What we can do, however, is `flip` our value, which gets us closer to our goal.

<span class="figure">
![Ap, lifted](/img/function_reuse/sellerReviews-flip.svg)
</span>

Finally, by the same argument, we can convince ourselves that we'll never be able to go from `F[List[Review]]` to `List[Review]`. This forces us to change our desired output to `F[List[Review]]`, which is the closest we can get to the initial problem statement.

And with this, we have a diagram that commutes, and a relatively straightforward implementation of `sellerReviews`.

<span class="figure">
![Ap, lifted](/img/function_reuse/sellerReviews-required.svg)
</span>

## Solution

First, of course, we'll need to prove that `List` is a `Functor`. This is mostly busywork, as `List` already provides a default `map` implementation which we can reuse.

```scala
given Functor[List] with
  extension [A, B](f: A => B)
    def lift: List[A] => List[B] =
      as => as.map(f)
```

Implementing `sellerReviews` is now just a matter of following the arrows of our diagram.

```scala
def sellerReviews[F[_]: Applicative](
  loadReview: ReviewId => F[Review],
  seller: Seller
): F[List[Review]] =
  flip(seller.reviews.map(loadReview))
```

## Problem

We can now finally tackle the last leg of our journey: re-using `sellerReviews` for a `Seller` in some `F`. In other words, implementing `sellerReviewsF`.

Its signature follows exactly the same logic as what we did for `itemSeller`. Instead of writing as many versions as there are potential `F`s, we'll have `itemSellerF` take a version of `sellerReviews` specialised to the right `F` and take it from there.

```scala
def sellerReviewsF[F[_]](
  sellerReviews: Seller => F[List[Review]],
  fseller      : F[Seller]
): F[List[Review]] =
  ???
```

The corresponding diagram should look very familiar in its shape if not necessarily in the details of the types.

<span class="figure">
![Ap, lifted](/img/function_reuse/sellerReviewsF-before.svg)
</span>

That is exactly the same kind of diagram we had to solve for `itemSellerF`, and can be solved using the exact same solution: `liftFlat`, which traces an immediate path from our input to our desired output.

<span class="figure">
![Ap, lifted](/img/function_reuse/sellerReviewsF.svg)
</span>

This allows us to quickly write a first `sellerReviewsF` implementation by following the arrows.

```scala
def sellerReviewsF[F[_]: FlatMap](
  sellerReviews: Seller => F[List[Review]],
  fseller      : F[Seller]
): F[List[Review]] =
  sellerReviews.liftFlat.apply(fseller)
```

We already know that `liftFlat` can be replaced with `flatMap` for something a bit closer to Scala's idioms, which gives us a final, fairly satisfactory implementation.

```scala
def sellerReviewsF[F[_]: FlatMap](
  sellerReviews: Seller => F[List[Review]],
  fseller      : F[Seller]
): F[List[Review]] =
  fseller.flatMap(sellerReviews)
```

Now, if you pay attention, we needed two distinct constraints on `F` for this whole thing to work:
- `sellerReviews` needs `F` to be an `Applicative` in order to use `flip`.
- `sellerReviewsF` needs `F` to be a `FlatMap` in order to use `flatMap`.

This combination of constraints is extremely common, and has a famous name: anything that is both a `FlatMap` and an `Applicative` is called a `Monad`.

```scala
trait Monad[F[_]] extends FlatMap[F] with Applicative[F]
```

## Key takeaways

After all this work, we've finally reached a useful, if maybe a little bit anticlimactic, definition: a `Monad` is both an `Applicative` and a `FlatMap`. And... that's really all there is to it.
