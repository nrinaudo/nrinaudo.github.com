---
title: Affordable item
layout: article
series: function_reuse
date:   20220902
---

## Problem

The first problem we'll want to tackle is filtering items on their price - I want to buy a PS5, but not at any cost.

This is relatively straightforward to implement:

```scala
def affordable(item: Item): Boolean =
  item.price < 500
```

We now have support for `Item`, but not the various contexts we can find it in:

<span class="figure">
![Lift, unsolved](/img/function_reuse/item-focus-item.svg)
</span>


For the sake of argument, let's see how far we can get by doing everything manually.

First, let's try and write an `Option`-specific implementation:


```scala
def affordableOption(
  oitem: Option[Item]
): Option[Boolean] =
  oitem match
    case Some(item) => Some(affordable(item))
    case None       => None
```

The type signature doesn't change much, we've just wrapped parameters and return types in `Option`. The actual implementation, however, is rather a lot of boilerplate that eventually calls `affordable`.

That buys us support for `Option`:

<span class="figure">
![Lift, unsolved](/img/function_reuse/item-item-option.svg)
</span>

What about `Try`? Again, the code isn't too hard to write:

```scala
def affordableTry(
  titem: Try[Item]
): Try[Boolean] =
  titem match
    case Success(item) => Success(affordable(item))
    case Failure(e)    => Failure(e)
```

And we see a similar pattern emerge: parameters wrapped in `Try`, lots of boilerplate, and an eventual call to `affordable`.

Our supported context lists is increasing:

<span class="figure">
![Lift, unsolved](/img/function_reuse/item-item-option-try.svg)
</span>

But that clearly doesn't scale, does it? We've had to write 3 different versions of essentially the same function already, and we're just getting started. There's plenty more work to do:

<span class="figure">
![Lift, unsolved](/img/function_reuse/item-focus-everything-else.svg)
</span>

I'm not too worried about `Future` or `Either` - it'd be nicer not to have to do them, certainly, but it seems manageable, if maybe a little frustrating. What really worries me is the `...` at the bottom right corner: it's unbounded. Anything could be lurking in there, including but not limited to any combination of the contexts we've already written a version of `affordable` for.

That's clearly not going to be possible. We can't reasonably consider having to write infinitely many versions of `affordable`, let alone of every function that takes an `Item` as parameter!

What we really want to do is a generic version of `affordable` that works for any given context:

```scala
def affordableF[F[_]](
  fitem: F[Item]
): F[Boolean] =
  ???
```

A word about naming conventions. The `F` in `affordableF` comes from its type parameter, `F[_]`, and I'm not thrilled about this. It has become idiomatic in the Scala community to call type constructors `F`, because we have a bit of a fetish for effects; a type constructor could not possibly be meant for anything other than encoding effects, and thus, we must call them `F`. Because that's how you spell _effects_. With an _f_ and an _x_, like a bad DJ from the late 90s.

Right, so, rant aside, `affordableF`'s type signature follows the same pattern we used for `Option` and `Try`: wrap parameters and return values in `F`.

The problem, of course, is that we do not know _anything_ about `F`. There's nothing we can do with an `F[Item]`, because `F` could literally be anything, and the smallest common denominator of _everything_ is, well, _nothing_.

We're a little bit stuck, then. But, when stuck, I like to go back to a technique that has served me well since, oh, primary school: doodling.

## Intuition

Here's a diagram of what we're trying to solve:

<span class="figure">
![Lift, unsolved](/img/function_reuse/lift-before.svg)
</span>

We're trying to go from `F[Item]` to `F[Boolean]`, and the only tool we have at our disposal is `affordable`. The goal is to somehow draw a path from the input to the desired output.

This diagram makes it obvious that it's just not going to happen. There is no such path to be found.

What we would really like to do here is to take `affordable` and move it up to `F[Item]` and `F[Boolean]`, _lift_ it, as it were. This would solve our problem immediately:

<span class="figure">
![Lift, solved](/img/function_reuse/lift-intuition-2.svg)
</span>

And this is actually a solid design technique: identify the things that would make our job easy, and pretend that they exist or will be solved, preferably not by us. This strategy of making things somebody else's problem is usually more associated with management, but can also be surprisingly effective in software engineering.

Of course, we still have to do a little bit of work: provide that somebody else with a way of giving us the `lift` implementation.

## Solution

This is typically encoded with a [type class]({{ site.baseurl}}/articles/typeclasses/), which we'll call `Lift` here:

```scala
trait Lift[F[_]]:
  extension [A, B](f: A => B)
    def lift: F[A] => F[B]
```

Don't be scared by the somewhat verbose declaration, it's entirely due to using an _extension method_ to make call sites more pleasant. The important bit is that, given an `A => B`, we can _lift_ it into an `F[A] => F[B]`.

Provided with an instance of `Lift` for our target `F`, then, we can rely on the `lift` method:

<span class="figure">
![Lift, solved](/img/function_reuse/lift-after.svg)
</span>

Looking at this diagram immediately gives us the solution to our problem. If we modify the type signature to require `F` having a `Lift` instance, `affordableF` is simply a lifted version of `affordable`:

```scala
def affordableF[F[_]: Lift](
  fitem: F[Item]
): F[Boolean] =
  affordable.lift.apply(fitem)
```

## Common combinators

Now, while that works, the code is a little bit... unpleasant, isn't? doesn't that `affordable.lift.apply` bit make us a little bit uncomfortable, like something's not quite right and we would fix it if we only could put our finger on it?

If you feel that way, I can tell you why but, word of warning, you're not going to like it.

You feel that way because for all we, Scala developers, like to think of ourselves as fancy functional programmers, Scala is, at its heart, an OOP language, and we're OOP developers. And if you don't believe me... doesn't the following code feel much _nicer_ to you?

```scala
def affordableF[F[_]: Lift](
  fitem: F[Item]
): F[Boolean] =
  fitem.map(affordable)
```

This is the same `affordableF`, with a small twist. The initial version was applying a function (`affordable.lift`) to its argument (`fitem`), which is pretty much what functional programming is about. The updated version produces exactly the same result, but now invokes a method (`map`) of an object (`fitem`), which is a very OOP thing to do.

Just to hammer the point home, here's how you implement `map` in terms of `lift`:

```scala
trait Lift[F[_]]:
  extension [A, B](f: A => B)
    def lift: F[A] => F[B]

  extension [A](fa: F[A])
    def map[B](f: A => B): F[B] = f.lift.apply(fa)
```

It is of course possible, trivial even, to write `lift` in terms of `map` as well. `lift` and `map` are the same function, seen through different perspectives. It just so happens that we feel more comfortable with the OOP perspective than with the FP one, and so I'll keep using that through the rest of this article.

## Naming things

Finally, before moving on, we must do one last thing: give `Lift` its proper name. Because it clearly couldn't just be called `Lift`, that'd be too easy.

No, what we invented is a well known abstraction called `Functor`, for categorical reasons that I will not explain. Because it's not terribly useful to the point of these articles, sure, but mostly because I can't.

```scala
trait Functor[F[_]]:
  extension [A, B](f: A => B)
    def lift: F[A] => F[B]

  extension [A](fa: F[A])
    def map[B](f: A => B): F[B] = f.lift.apply(fa)
```

## Key takeaways

At this point, we have learned two important things:
* `Functor` is about working with one value inside of a context `F`.
* its core function is `lift` or, equivalently, `map`.
