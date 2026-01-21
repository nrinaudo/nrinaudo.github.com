---
title:   The right(?) way to work with capabilities
layout:  article
date:    20260121
---

I've been playing with [capabilities as a way of encoding effectful computations](./capabilities.html), mostly to get a better feel for them and see how far I can take them, and have recently realized a couple of things that radically altered the way I declare them.

In order to explain them, let's start with a fairly simple capability, one with which you're probably familiar if you've been reading some of my recent material: `Rand`, the ability to produce random values.

```scala
import caps.*

trait Rand extends SharedCapability:
  def nextInt(max: Int): Int
```

Of course, that's not quite enough: we'll need simple [atomic effectful computations](./capabilities.html#composing-simple-effectful-computations) to work with it. We're only going to generate random ints and booleans in the rest of this article, so I'll limit myself to that:

```scala
object Rand:
  def int(max: Int): Rand ?-> Int =
    handler ?=> handler.nextInt(max)

  val boolean: Rand ?-> Boolean = 
    Rand.int(2) == 1
```

## Declaring an effectful computation

There has been some debate over how to declare effectful computations, with two main contenders.

First, what I've shown just above: a value of type `Rand ?-> A`. I've always liked this approach because `Rand ?-> A` _is the type of effectful computations_, so it feels reasonable to use it to describe effectful computations. Tautological, almost.

Absolutely everybody else seems to agree that this is silly and we should use a `given Rand` instead, as follows:

```scala
def boolean(using Rand): Boolean = 
  Rand.int(2) == 1
```

The reason for that, one I should have been very sympathetic with but weirdly wasn't, is consistency. Scala developers do not like functions much, and will almost always prefer `def foo(i: Int): Boolean` to `val foo: Int => Boolean`. The `using Rand` approach is a natural consequence of that dislike.

I was always a staunch supporter of the _first_ approach, until recently, when I realised there was one clear, unarguable reason to prefer `using Rand`. In order to show it clearly, let's write another `Rand` combinator: `or`, which, given two effectful computations, randomly chooses one and evaluates it.

My regular approach gives us this:

```scala
def or[A](lhs: Rand ?=> A, rhs: Rand ?=> A): Rand ?->{lhs, rhs} A =
  if Rand.boolean 
    then lhs
    else rhs
```

It's not particularly complicated if you're familiar with context functions and [capture checking](./capture_checking.html), but it turns out to be more complicated than it needs to be.

See, the reason we have the capture checking annotations in the return type is because it's a function: as a function, it captures `lhs` and `rhs` in its body, and must declare that in its type. With the `given Rand` approach, however, we simply return the `A` - we _use_ `lhs` and `rhs`, certainly, but do not _capture_ them:

```scala
def or[A](lhs: Rand ?=> A, rhs: Rand ?=> A)(using Rand): A =
  if Rand.boolean then lhs
  else rhs
```

And for all I enjoy capture checking and what it brings to the table, I must admit I much prefer when it disappears entirely until it catches an error. This implementation of `or` looks a lot more like "normal" Scala code, which is definitely a desirable property: the less esoteric the code, the more comfortable it will be to work with.

## Expecting an effectul computation

There remains one slightly weird bit: both `lhs` and `rhs` are context functions, which are kind of new, kind of unconventional in most code bases.

After a long discussion, [SystemFw](https://systemfw.org/) changed the way I think about effectful computations. In particular, he made me think about the distinction between:
- `a: => A`: meaning `a` is _by-name_, and can more or less be thought as a transparently applied `() => A`.
- `a: Rand ?=> A`: meaning `a` is a function that takes a given `Rand` and produces an `A`.

In the capabilities view of the world, however:
- `a: => A`: effectful computation over _any_ set of capabilities, including the empty set.
- `a: Rand ?=> A`: effectful computation over any set of capabilities that includes `Rand`.

This is how we achieve effect polymorphism in Scala 3 and, I think, very close in spirit to what Effekt calls contextual purity: `a: => A` might be effectful, but all its effects are already handled and we can ignore them. On the other hand, `a: Rand ?=> A` _definitely_ has unfulfilled effect `Rand`, as well as any number of fullfilled ones.

With that view of things, why does `or` take `Rand ?=> A`? It needs to take potentially effectful computations, certainly, but why force them to depend on `Rand`? If we take things to the extreme, we may very well want them to be pure computations: `or(true, false)`, for example. What we _really_ want is not `Rand ?=> A`, but `=> A`:

```scala
def or[A](lhs: => A, rhs: => A)(using Rand):  A =
  if Rand.boolean then lhs
  else rhs
```

In case you're wondering why we need a `using Rand` at all (I know I did for a few seconds), it's not because of `lhs` or `rhs`, but because we're calling `Rand.boolean`. _That_ needs a handler, and it's `or`'s responsibility to provide it.

## Limitation: variadic parameters

Not everything is always that clean and simple, especially in features that are still in development. I've encountered one scenario where these simplifications didn't quite work: varargs.

To expose it clearly, let's take another `Rand` combinator: `oneOf`, which is basically `or` for more values. Its code is straightforward, even if its type is atrocious (it'll be explained in a second):

```scala
def oneOf[A, Tail^](
  head: Rand ?=> A, 
  tail: (Rand ?->{Tail} A)*
): Rand ?->{head, Tail} A =
  val index = int(tail.length)

  if index == 0 
    then head
    else tail(index - 1)
```

I encourage you to read [Martin's explanation](https://users.scala-lang.org/t/capture-leak-when-using-varargs/12086/9) if you feel the need to understand these types. If you don't though, that's also perfectly fine. The point of what we're doing is to get rid of the eldricht bits.

As a first step, then, we'll rewrite `oneOf` with the `using` approach:

```scala
def oneOf[A](head: Rand ?=> A, tail: (Rand ?=> A)*)(using Rand): A =
  val index = int(tail.length)

  if index == 0 
    then head
    else tail(index - 1)
```

That is already so much better, isn't it? Since `oneOf` no longer captures any of its parameters, we don't need to describe what _these_ capture, and all capture checking annotations disappear. Some semblance of clarity is restored to the world.

We can go further by using by-name arguments, but unfortunately not quite as far as I'd like. See, [by-name parameters cannot be variadic](https://github.com/scala/scala3/issues/499). Which means that while we can make `head` by-name, we can't do the same thing with `tail`.


```scala
def oneOf[A](head: => A, tail: (Rand ?=> A)*)(using Rand): A =
  val index = int(tail.length)

  if index == 0 
    then head
    else tail(index - 1)
```

We could go further still, although I am not convinced it's the best idea in the world. `tail` takes a given `Rand`, which is a little arbitrary - there's absolutely no reason to think it needs the `Rand` capability. It's not exactly a show stopper - the compiler is clever enough to seemlessly transform computations that don't need `Rand` into ones that do but ignore it - but a little misleading, maybe.

What we could do instead is decide that we depend on [`DummyImplicit`](https://www.scala-lang.org/api/current/scala/DummyImplicit.html), a type for which there is, by definition, always a given instance:

```scala
def oneOf[A](head: => A, tail: (DummyImplicit ?=> A)*)(using Rand): A =
  val index = int(tail.length)

  if index == 0 
    then head
    else tail(index - 1)
```

This makes it clear that we're taking a given because of limitations in the language, not because we need one. But it also stands out like a sore thumb, and I really am not convinced yet whether it's the right call.

