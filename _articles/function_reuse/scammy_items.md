---
title: Scammy items
layout: article
series: function_reuse
date:   20220907
---

## Problem

Our problem is almost solved. We know how to go from an item to a list of reviews, all we need is some simple logic to decide whether these reviews suggest something suspicious.

We can do something fiendishly clever, such as looking for occurrences of the word _scam_ in their body.

```scala
def scammyReviews(reviews: List[Review]): Boolean =
  reviews.exists(r => r.body.contains("scam"))
```

At this point, all that remains is putting everything together. First, by implementing `scammyItem`, then `scammyItemF`.

I've laid out the type signatures of these functions here:

```scala
def scammyItem[F[_]](
  loadSeller: SellerId => F[Seller],
  loadReview: ReviewId => F[Review],
  item      : Item
): F[Boolean] =
  ???

def scammyItemF[F[_]](
  scammyItem: Item => F[Boolean],
  fitem     : F[Item]
): F[Boolean] =
  ???
```

Here's the entire problem viewed as a diagram:

<span class="figure">
![Ap, lifted](/img/function_reuse/scammy.svg)
</span>

And now it's your turn to do a little work. You have everything you need, let me know what you come up with!
