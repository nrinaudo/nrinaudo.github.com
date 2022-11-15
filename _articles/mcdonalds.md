---
title:  The Chicken McNugget problem
layout: article
date:   20221113
---

I was recently challenged to solve [The Chiken McNugget problem](https://www.johndcook.com/blog/2022/10/10/mcnugget-monoid/). It's an amusing one that apparently predates McDonalds by a few centuries, but not a particularly hard one, as it's extremely easy and cheap to brute force.

I decided to write a little bit about it however, as it does lend itself to pedagogical pontification.

## Naive solution
The problem is to find all non-McNugget number, where a number is said to be McNugget if you can buy that amount of McNuggets using boxes of 6, 9 or 20 items. This is a concrete example of a [numerical semigroup](https://en.wikipedia.org/wiki/Numerical_semigroup), a concept I obviously had never heard of until working on this.

One interesting property of McNugget numbers is they are finite. This can be proven, but we're not going to bother here - after all, this is information we're given as part of the challenge instructions.

If we know there's a finite amount of McNugget numbers, a solution rather quickly presents itself:
- compute the largest possible non-McNugget number.
- iterate through all numbers smaller than that, checking if they are McNugget or not.

It's not necessarily the cleverest of solutions, but it has the advantage of being pleasantly straightforward.

### Checking if a number is McNugget
Our first task, then, is to write a function that checks whether a number is McNugget.

In order to make this more obvious, let's rephrase the definition. A number is McNugget if it:
- equals 0 (as given to us in the challenge's instructions).
- can be reached by adding 6, 9 or 20 to a McNugget number.

That's clearly a recursive definition - you need to know how to decide whether a number is McNugget in order to decide if a number is McNugget - and lends itself to a relatively simple recursive implementation:

```scala
// Always solve the generic case rather than the specific scenario, some project
// manager will *always* change these values before the deadline.
val sizes = Set(6, 9, 20)

// That i > 0 test is to disqualify negative numbers - you cannot buy a negative
// amount of McNuggets.
def isMcNugget(i: Int): Boolean =
  i == 0 || (i > 0 && sizes.exists(x => isMcNugget(i - x)))
```

### Computing the largest non-McNugget number

The trick to computing that number is to realise that if you find 6 consecutive McNugget numbers, every subsequent number will also be McNugget. We're also told that such a sequence exists, which we'll take on faith and simply look for.

We need, then, to iterate over all numbers, until we encounter a sequence of 6 McNugget ones. When that happens, whatever non-McNugget number we encountered last is the largest possible one.

This reads exactly like the specifications for a while-loop or, in more functionally-minded languages, a tail-recursive function:

```scala
def maxNonMcNugget =
  // The smallest box size; 6, in our case
  val maxConsecutive = sizes.min

  // - i          : current number we're testing, incremented on each step.
  // - consecutive: current number of consecutive McNugget numbers we've found.
  // - result     : current largest known non-McNugget number.
  @scala.annotation.tailrec
  def loop(i: Int, consecutive: Int, result: Int): Int =
    if consecutive >= maxConsecutive then result
    else if isMcNugget(i)            then loop(i + 1, consecutive + 1, result)
    else                                  loop(i + 1, 0, i)

  loop(0, 0, -1)
```

### Computing all non-McNugget numbers

We now have all the moving pieces, all that remains is to bring them together, by taking all potentially non-McNugget numbers, and removing all the ones that are, in fact, McNugget:

```scala
(0 to maxNonMcNugget).filterNot(isMcNugget)
// Vector(1, 2, 3, 4, 5, 7, 8, 10, 11, 13, 14, 16,
//        17, 19, 22, 23, 25, 28, 31, 34, 37, 43)
```

## Improvements
### Merging traversals
While this solution works, and is perfectly reasonable given the small amount of data we're working with, we can do better. The first thing that should jump at us is that we're traversing all numbers from 0 to `maxNonMcNugget` twice.

It is, of course, possible to do this in a single pass: instead of keeping track of the last encountered non-McNugget number, we can simply accumulate them all. This is achieved through a surprisingly minor change to our implementation:

```scala
def allNonMcNugget =
  // The smallest box size; 6, in our case
  val maxConsecutive = sizes.min

  // - i          : current number we're testing, incremented on each step.
  // - consecutive: current number of consecutive McNugget numbers we've found.
  // - result     : all known non-McNugget numbers so far.
  @scala.annotation.tailrec
  def loop(i: Int, consecutive: Int, result: Vector[Int]): Vector[Int] =
    if consecutive >= maxConsecutive then result
    else if isMcNugget(i)            then loop(i + 1, consecutive + 1, result)
    else                                  loop(i + 1, 0, result :+ i)

  loop(0, 0, Vector.empty)
```

### Decoupling recursion and business logic

Our current solution is nice, but also a little bit hard to follow. Two things happen at the same time:
- the "business" logic of keeping track of this whole McNugget thing.
- handling recursion.

This is certainly not a show-stopper, especially with such a simple problem, but it's good practice to try and separate concerns. In the case of recursion, it can usually be achieved quite easily by declaring a custom type for our recursion state (traditionally called our accumulator):

```scala
def allNonMcNugget =
  // The smallest box size; 6, in our case
  val maxConsecutive = sizes.min

  // Recursion state:
  // - consecutive: current number of consecutive McNugget numbers we've found.
  // - current    : all known non-McNugget numbers so far.
  case class Acc(consecutive: Int, current: Vector[Int]):

    // Checks whether we've found all non-McNugget numbers.
    def isFinished = consecutive >= maxConsecutive

    // Updates internal state with the specified number.
    def consume(i: Int) =
      if isMcNugget(i) then copy(consecutive = consecutive + 1)
      else                  copy(consecutive = 0, current = current :+ i)

  // - i  : current number we're analysing.
  // - acc: current "business" state
  @scala.annotation.tailrec
  def loop(i: Int, acc: Acc): Vector[Int] =
    if acc.isFinished then acc.current
    else loop(i + 1, acc.consume(i))

  loop(0, Acc(0, Vector.empty))
```

Note how we've made `Acc` local to `allNonMcNugget`: there is no need for anybody else to ever know of the existence of that data structure. It's purely there as a convenience, to make things more readable.

And, yes, this involves more code than we had before. Weirdly, readability is not an inverse function of code size.

### Memoization
If you've been paying attention, you probably realised that our `isMcNugget` implementation is horribly sub-optimal: we'll be calling it many times for the same number.

If you're not seeing it, run through it for, say, 43 and 37. You'll see that 43 duplicates every single check we needed to run for 37.

Ideally, we would like to cache intermediate results to avoid recomputing things, a process known as memoization.

This is not very hard to implement: we can keep a (mutable) cache of all `Int` to `Boolean` mappings that have already been explored, and check that before actually computing whether a number is McNugget:

```scala
val isMcNugget: Int => Boolean =
  val cache = collection.mutable.Map.empty[Int, Boolean]

  // Business logic.
  def loop(i: Int) =
    i == 0 || (i > 0 && sizes.exists(x => isMcNugget(i - x)))

  // Caches the result for the specified number.
  def cacheFor(i: Int) =
    val result = loop(i)
    cache(i)   = result
    result

  // We either already know the answer for a given number, or need
  // to compute and cache it.
  i => cache.get(i)
    .getOrElse(cacheFor(i))
```

There's one subtlety to this implementation: `isMcNugget` is now a function rather than a method. This allows us to initialise `cache` when `isMcNugget` is created, as opposed to when it's called, which is pretty important: a cache that's reset on every call might as well not be there.

If you're not convinced, consider:

```scala
def isMcNugget(i: Int): Boolean =
  val cache = collection.mutable.Map.empty[Int, Boolean]

  // Business logic.
  def loop(i: Int) =
    i == 0 || (i > 0 && sizes.exists(x => isMcNugget(i - x)))

  // ...
```

What do you think happens when we call `isMcNugget` in `loop`? Are we reusing the same `cache`, or is a new one created for each recursion step?

### Complete solution

At this point, we have a working solution that is reasonably efficient and easy to understand:

```scala
// Always solve the generic case rather than the specific scenario, some project
// manager will *always* change these values before the deadline.
val sizes = Set(6, 9, 20)

// Checks if a number is McNugget or not (with memoization).
val isMcNugget: Int => Boolean =
  val cache = collection.mutable.Map.empty[Int, Boolean]

  // Business logic.
  def loop(i: Int) =
    i == 0 || (i > 0 && sizes.exists(x => isMcNugget(i - x)))

  // Caches the result for the specified number.
  def cacheFor(i: Int) =
    val result = loop(i)
    cache(i)   = result
    result

  // We either already know the answer for a given number, or need
  // to compute and cache it.
  i => cache.get(i)
    .getOrElse(cacheFor(i))

// All existing non-McNugget numbers, sorted ascendingly.
val allNonMcNugget =
  // The smallest box size; 6, in our case
  val maxConsecutive = sizes.min

  // Recursion state:
  // - consecutive: current number of consecutive McNugget numbers we've found.
  // - current    : all known non-McNugget numbers so far.
  case class Acc(consecutive: Int, current: Vector[Int]):

    // Checks whether we've found all non-McNugget numbers.
    def isFinished = consecutive >= maxConsecutive

    // Updates internal state with the specified number.
    def consume(i: Int) =
      if isMcNugget(i) then copy(consecutive = consecutive + 1)
      else                  copy(consecutive = 0, current = current :+ i)

  // - i  : current number we're analysing.
  // - acc: current "business" state
  @scala.annotation.tailrec
  def loop(i: Int, acc: Acc): Vector[Int] =
    if acc.isFinished then acc.current
    else loop(i + 1, acc.consume(i))

  loop(0, Acc(0, Vector.empty))
```

## Massively over-engineering things

This memoization things is quite neat, isn't it? Wouldn't it be great if we could generalise it to any recursive function?

Naively, we could simply replace `loop` in our previous implementation by any function from `A` to `B`, and adjust things accordingly:

```scala
def memoize[A, B](f: A => B): A => B =
  val cache = collection.mutable.Map.empty[A, B]

  // Caches the result for the specified number.
  def cacheFor(a: A) =
    val result = f(a)
    cache(a)   = result
    result

  // We either already know the answer for a given number, or need
  // to compute and cache it.
  a => cache.get(a)
    .getOrElse(cacheFor(a))
```

But the problem here is `f` is not aware of the memoization process: it recursively calls itself, without inserting a check in the cache at every step.

The problem, then, is that we need to be able to plug arbitrary code at every step in the recursion. There's a trick to do that: Continuation Passing Style, or CPS for short. I know I complain a lot about names in programming, but this one is actually good for once: CPS is about _passing_ the next step (the _continuation_) of a process as a parameter.

Typically, that means we'll rewrite the non-memoized version of `isMcNugget` as follows:

```scala
// This is not recursive.
def isMcNuggetCont(i: Int, cont: Int => Boolean): Boolean =
  i == 0 || (i > 0 && sizes.exists(x => cont(i - x)))

// This, on the other hand, is, if indirectly.
val isMcNugget: Int => Boolean =
  i => isMcNuggetCont(i, isMcNugget)
```

It is admittedly a bit awkward, but it does help with our problem: we now have a hook to sneak in code between recursion steps. Let's say, for the sake of argument, that we wanted to print a log message at every recursive step:

```scala
val noisyIsMcNugget: Int => Boolean = i =>
  println(s"Evaluating: $i")
  isMcNuggetCont(i, noisyIsMcNugget)
```

We leave the business logic to `isMcNuggetCont`, and do whatever else we need in the continuation.

Which allows us to rewrite our memoization function in a more satisfactory manner:

```scala
// (A, A => B) => B is the type of isMcNuggetCont:
// a function that takes a current state and a continuation.
def memoize[A, B](f: (A, A => B) => B): A => B =
  val cache = collection.mutable.Map.empty[A, B]

  def loop: A => B = a => cache.get(a)
    .getOrElse {
      val result = f(a, loop)
      cache(a)   = result
      result
    }

  loop
```

And this, in turn, gives us a fully memoized `isMcNugget`:

```scala
val isMcNugget = memoize(isMcNuggetCont)
```

## Conclusion
This entire McNugget thing is really just an excuse for exploring a few concepts I enjoy:
- using bespoke types to extract business logic from recursive functions.
- using CPS to make recursive functions more tractable.
- using mutable caches to massively optimise recursive processes (another good example of that is the [Sieve of Eratosthenes](https://en.wikipedia.org/wiki/Sieve_of_Eratosthenes)).
