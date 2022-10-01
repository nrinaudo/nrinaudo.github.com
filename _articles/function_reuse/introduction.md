---
title: Introduction
layout: article
series: function_reuse
date:   20220901
---

This series of articles is about, well, monads and stuff. It's a subject I've long wanted to write about, because anybody who's anybody in FP has written or talked about it at some point, and I'd dearly like to be somebody who's somebody. So here we are.

Granted, this justifies me wanting to write about monads, but it really doesn't do much to convince you to read it, does it? So here's what you'll get out of it: first, the usual package. You'll understand what monads and related categorical abstractions are about, and how and when to use them. But that's really the bare minimum you should expect from any such article, isn't it, which is why I'll throw in a little bonus: this article will also expose a design technique that, if you're not already familiar with it, might change the way you write software forever. Bold statement, but you must admit it's intriguing enough that you kind of have to keep reading now, if only to prove me wrong.

As most of my articles, this is inspired by slightly romanticised anecdotes from my life. In this case, the inciting event was attempting to buy a PS5 when they first came out. Now, you might not be into gaming or care much about PS5s, but the entire thing works just as well if you substitute that for something that just flies off the shelves and is really hard to get your hands on - a limited edition from a favourite artist, say. Or maybe tickets for an exciting concert. A Robert Martin action figure for your private shrine, whatever works for you. Anything that's rare and available for online purchase will do.

Things got to the point where it was beginning to feel reasonable to write software to automate the task for me - a clever little crawler that would aggregate product data off of various online market places and alert me whenever one matched a given set of criteria.

Now, this is where the _slightly romanticised_ part comes in. As an engineer, this is absolutely what I would have done. I was not an engineer at the time, however, but a CTO, and so applied a CTO solution to the problem: recruit an intern and have them refresh online market places all day long, which sorted the whole business out right quick.

This article, however, takes place in an alternate, darker timeline where I did the wrong thing and automated a poor intern's job away.

At the heart of the platform that I would have written is the `Item`, which represents anything available for sale on one of our crawled market places:

```scala
type ItemId   = UUID
type SellerId = UUID

case class Item(
  id      : ItemId,
  name    : String,
  price   : Int,
  sellerId: SellerId
)
```

While `Item` is the core of everything we're about to do, depending on which part of the platform you find yourself in, you might be getting many variations on it:
* `Option[Item]`, when looking up an item that might not exist.
* `Future[Item]`, for long running computations.
* `Try[Item]`, if the item retrieval might fail.
* `Either[Error, Item]`, which is really just a pretentious `Try`.
* ... and any other context you might think of, or combination of other contexts.

<span class="figure">
![Item Variations](/img/function_reuse/item-variations.svg)
</span>

This article is about working with `Item`, and not having to re-invent the wheel every time a new context comes along - in other words, _function reuse_.
