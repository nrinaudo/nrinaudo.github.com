---
title:   Effects as Capabilities
layout:  article
date:    20250901
code:    https://github.com/nrinaudo/hands_on_capabilities/blob/main/numbers/src/main/scala/capabilities.scala
---

Capabilities appear to be _the_ hot topic in the Scala community right now. Some love them, some hate them, most don't really quite seem to understand what they're about, and since I've been studying them a little, I thought I'd share my insights and hopefully not add too much to the confusion.

As usual when looking at new features, I tend to ask myself the simple question of _what problem is this trying to solve?_ And in this case, the most immediate answer I could find was to allow a _direct style_ of programming. There are subtleties and details I'm purposefully ignoring here and we'll get to later, but really, the direct style bit seems to be the inciting incident.

## Direct style

This is all well and good, but what does _direct style_ actually mean? The clearest technical answer I could find (well, synthetise from various sources) is:
> A direct style of programming is one in which control is passed implicitly from one line of code to the next, and is opposed to continuation passing style (or, equivalently, monadic style), where it's made explicit by a _continuation_.

A more honest definition, at least in the context of what Scala is trying to do, could be:
> A direct style of programming is one in which you can write code without faffing about with monads.

And if you're thinking that wait, doesn't that mean old fashioned, imperative code is written in a direct style? then you'd be absolutely right. Let's take a concrete example, one which might initially seem slightly overkill but we'll keep tweaking and refining throughout the rest of the article: the common _guess the number_ game. You must guess a number between 0 and 10, and are given 4 guesses. On each incorrect guess, you're told whether you were too high or too low.

The first thing we'll need is some way to read the user's input. To keep things simple, we'll not do any fancy error handling and simply treat invalid inputs as failed guesses:

```scala
def readInput: Option[Int] =
  try Some(readLine.toInt)
  catch
    case _ => None
```

This is straightforward, we read something from standard input and attempt to interpret it as an `Int`, encoding the failure case in a `None`. Not exactly the most illuminating example of direct style yet, but we're getting to that.

We then need to process a single user guess, by checking it against the target number:

```scala
def guess(target: Int): Boolean =
  readInput match
    // Correct guess
    case Some(`target`) => true

    // Incorrect guess
    case Some(input) =>
      if input < target then println("Too low")
      else                   println("Too high")
      false

    // Invalid guess
    case None =>
      println("Not a valid number")
      false
```

There is, again, nothing particularly confusing about this. We'll return `true` if the user guessed `target`, `false` otherwise. Note how this reads as it executes: for example, interactions with standard input and output are just done when we need them, without ceremony. Of course, this makes our code side-effecting in a way that isn't tracked at all, but it's hard to disagree that the _intent_ of the code is obvious.

Now that we know how to handle a single guess, we can loop until the user succeeds or exhausts their attempts:

```scala
def loop(target: Int, remaining: Int): Boolean =
  // Correct guess
  if guess(target) then
    println("Congratulations!")
    true

  // Incorrect guess, no more attempts
  else if remaining < 0 then
    println("No more attempts")
    false

  // Incorrect guess, some remaining attempts
  else
    if remaining == 0 then println("Last attempt")
    else                   println(s"$remaining attempts remaining")
    loop(target, remaining - 1)
```

And finally, to tie everything together, the program's entry point, in which we generate the target number and start looping:

```scala
def run: Boolean =
  val target = nextInt(10)

  println("Input a value between 0 and 10:")
  loop(target, 2)
```

Note, again, how simple this style is to read. We need a random number, so we just get one.

Of course, there's a trade-off here. This code is quite simple to read, certainly, but relies heavily on _side effects_: bits of code that change the state of the world. For example, `println` changes what's displayed in the console. This can become problematic if multiple functions can do this: you, the developer, have to keep track of the current state of the console to make sure what happens is what you want to happen (what if some previous call changed the font color, for example?)

In general, then, this style of programming is simpler to read, but harder to reason about, a problem that only compounds itself as the code base grows in size. On the other end of that spectrum is monadic style (or continuation passing style, distinct but equivalent).

## Monadic style

Monadic style, perhaps unsurprisingly, relies on monads. There's a variety of ways of using them to make programs easier to reason about, from encoding each effect as a distinct monad to having a single one with interesting constraints. Each approach has its specific trade-offs, but all of them (or at least all the ones I'm familiar with) achieve one important property: effects can be tracked and isolated, allowing developers to reason about them much more easily.

Note that I'm saying _can_ be tracked and not _are_ tracked. The distinction is maybe subtle, but in an inherently impure language like Scala, you can always perform side-effecting operations at any point - calling `println`, say - without the compiler being able to do anything about it. We _can_ track effects, by being rigorous and not cheating. It's not perfect, but it's still far better than the imperative code we wrote earlier where we just didn't have that option at all.

The comparison I like to use is that the style of our initial code makes your code base similar to a giant Rubik's cube, with many faces and many squares per face. Touching one part of the code is equivalent to rotating a face, potentially impacting many others. Using monadic style, your giant Rubik's cube is split into many (many, many) much smaller ones. Each one still needs to be solved, but is a lot easier to work with, and you can ignore all the other ones. A growing code-base doesn't increase the complexity of the entire problem, it merely adds more small problems to solve. Or, put more succinctly: it makes things sane.

I'm not going to get deep into details here because that's not really my point, nor do I feel qualified to. But, regardless of the way you use monads, you run into the following inherent problems:

- values being wrapped in a monadic type makes them harder to work with and combine, involving a lot more ceremony than simply manipulating them with the host's language standard tools.
- you often end up having to implement two versions of the same combinator, one for monadic values, and one for non-monadic ones (think [`traverse`](https://www.javadoc.io/static/org.typelevel/cats-docs_2.13/2.13.0/cats/Traverse.html#traverse[G[_],A,B](fa:F[A])(f:A=%3EG[B])(implicitevidence$1:cats.Applicative[G]):G[F[B]]) and [`flatTraverse`](https://www.javadoc.io/static/org.typelevel/cats-docs_2.13/2.13.0/cats/Traverse.html#flatTraverse[G[_],A,B](fa:F[A])(f:A=%3EG[F[B]])(implicitG:cats.Applicative[G],implicitF:cats.FlatMap[F]):G[F[B]])).

Neither of these issues is a deal-breaker - clearly, if you look at how successful monadic style is in the Scala ecosystem. But they do make things less pleasant than they could be. By and large, the Scala community seems to have concluded that the ease of reasoning about code was worth the added complexity of writing it - which hasn't stopped us from attempting to alleviate that complexity, as the growing number of monad-based effect systems attests.

But it's hard not to be greedy and wish for a style that somehow takes the best of both worlds. Capabilities attempt to be just that.

## Capabilities

The foundational idea behind capabilities is to see effectful computations as functions. For example, the computation that needs to generate random values in order to produce an `Int` can be thought of as a function from "something that can produce random values" to `Int` - let's call it `Rand => Int` to have something concrete.

This "something that can produce a random value" is the _capability_: the ability to do something. An effectful computation, then, is something that, given a set of capabilities, can produce a result.

And if you think this feels a lot like dependency injection, that's because it's exactly dependency injection. Which, in Scala, we really like handling with implicit parameters, because everybody apparently hates passing parameters to functions. So instead of working with a plain `Rand => Int` function, we'd work with a _context function_, the Scala 3 name for _functions with implicit parameters_, whose type is `Rand ?=> Int` (given an implicit `Rand`, produces an `Int`).

One point that is maybe worth putting some emphasis on: `Rand ?=> Int` is an effectful computation, _not_ a capability. It _uses_ a capability, `Rand`, to generate random values. The two are correlated, certainly, but distinct, and it's important not to confuse them.

We'll now take this idea and try to apply it to our number guessing game, to see exactly how close it can take us to our proverbial cake - the one we get to eat, and have too.

## `Rand`: generating random numbers

Recall our `run`:

```scala
def run: Boolean =
  val target = nextInt(10)

  println("Input a value between 0 and 10:")
  loop(target, 2)
```

We can clearly see it needs to generate random numbers, which we want to materialise by an implicit value that provides this ability. This value is often called a _handler_, which I'll readily admit can be a little confusing. Didn't we just say it was called a capability? I _think_ the capability is the type and the handler the value (a little like how in [Tagless Final](./tagless_final.html), the type class is the _syntax_ and its instance the _semantics_), but don't quote me on this.

Here's what the capability could look like:

```scala
package rand

trait Rand:
  def range(min: Int, max: Int): Int
```

This is fairly trivial, isn't it? We simply define the contract of things that can generate random numbers in a given range.

As we've just seen, with capabilities, `run` must be turned into a function taking an implicit `Rand`:

```scala
val run: Rand ?=> Boolean = r ?=>
  val target = r.range(0, 10)

  println("Input a value between 0 and 10:")
  loop(target, 2)
```

And this certainly works, but I find it a little disappointing. We're having to manipulate our implicit `Rand` value rather explicitly, where I would prefer it to be threaded through the code without any need to manage it by hand - ideally, I'd like to be able to pretend it doesn't exist at all, so that the code looks a lot more like our original direct style example.

### Composing simple effectful computations

The first step to achieving this is to prefer composing simple, atomic effectful computations into more complex, molecular ones, over direct access to the capability.

The most basic operation `Rand` provides is `Rand.range`. We can provide the same feature as a `Rand ?=> Int` very easily:

```scala
def range(min: Int, max: Int): Rand ?=> Int =
  r ?=> r.range(min, max)
```

We can even go a little further by writing `nextInt`, the capability-enabled version of `Random.nextInt`, entirely implemented in terms of `range`:

```scala
def nextInt(max: Int): Rand ?=> Int =
  range(0, max)
```

I probably wouldn't do that in real code, but for demonstration purposes, it would be really nice and striking for our capability-improved `run` to be as close as possible to the original one.

`nextInt` allows us to rewrite `run` as:

```scala
val run: Rand ?=> Boolean = r ?=>
  val target = nextInt(10)

  println("Input a value between 0 and 10:")
  loop(target, 2)
```

### Eagerness of context functions

If you're paying attention though, this should be a little surprising. Why does this even compile? `nextInt` returns a `Rand ?=> Int`, yet we use it as an `Int` when passing it to `loop`. How is that possible?

This is due to the "eager" behaviour of context functions: the compiler will _always_ try to apply them immediately, which, yes, it does mean that if the required implicit is not in scope, you get a compilation failure.

For a concrete example, here's how the compiler sees our `run` method (the change is in the second line):
```scala
val run: Rand ?=> Boolean = r ?=>
  val target = nextInt(10)(using r)

  println("Input a value between 0 and 10:")
  loop(target, 2)
```

`nextInt` is applied immediately, meaning that `target` has type `Int`, not, as you might expect, `Rand ?=> Int`.

This behaviour makes context functions pleasant to work with, at least in cases like this one: we want an `Int`, we get an `Int`, no fuss or questions asked. But it can make working with them _as values_ a little harder than we'd like: you need explicit type ascriptions to appease the compiler.

For example, if we wanted `target` to be a `Rand ?=> Int`, we'd need to write:
```scala
val target: Rand ?=> Int =
  nextInt(10)
```

This would work, and does allow you to manipulate context functions as values to an extent, but is a little syntax heavy.


### Automatic conversion to context functions

I'm almost satisfied with our implementation, except for that `r ?=>` bit: we never explicitly manipulate `r`, and I'd much prefer not having to name it, or even declare it at all. Luckily for us, this is made possible by a useful property of context functions: if the compiler finds a `B` where an `A ?=> B` is expected, it will synthesise the `(a: A) ?=>` bit for us.

This allows us to write:

```scala
val run: Rand ?=> Boolean =
  val target = nextInt(10)

  println("Input a value between 0 and 10:")
  loop(target, 2)
```

The compiler will see that `loop` has type `Boolean`, but expects `Rand ?=> Boolean`, so it'll insert `(r: Rand) ?=>` for us. If you compare this to our original implementation, the only difference between the two is in the types: this is exactly a direct style of programming, with effects tracked in types. Lovely.

As a side note, automatic conversion to context functions is how the type ascription example above worked:

```scala
val target: Rand ?=> Int =
  nextInt(10)
```

Due to the eagerness of context functions, `nextInt(10)` is seen as an type `Int`, where the compiler expects a `Rand ?=> Int`. It'll therefore synthesise the following code:

```scala
val target: Rand ?=> Int =
  (r: Rand) ?=> nextInt(10)
```

So it's not exactly that the type ascription gives `nextInt(10)` the right type, but more that it causes it to be wrapped in an additional layer of context function. At least conceptually, that is - I do not know whether this is optimised under the hood to avoid having massive towers of context functions, each simply passing its implicit parameter to the level below.

I'm not sure how useful knowing this is, but I find it delightful. We'll see later another example of how automatic conversion ends up being far more powerful than one would initially assume.


### Writing a `Rand` handler

We've updated our number guessing game to use the `Rand` capability rather than rely on global mutable state. That's only half the problem, though: we need to write the corresponding handler and provide access to it, otherwise no one will ever be able to actually run our game!

Our implementation is going to rely on the default `scala.util.Random`, because that's easy and works just fine. You could easily update that to use a better RNG, maybe one that's more deterministic.

The way we'll do this is by providing a `system` method (for "system's default random") taking an effectful computation and running it:

```scala
def system[A](ra: Rand ?=> A): A =
  val handler = new Rand:
    val r = new scala.util.Random

    override def range(min: Int, max: Int) =
      r.nextInt(max - min) + min

  ra(using handler)
```

This should be fairly clear: `system` takes an effectful computation, creates the obvious `scala.util.Random`-backed `Rand` implementation, and runs the former using the latter.

This allows to call `run` the following way:

```scala
rand.system:
  run
```

The `rand.system:` bit is apparently called a _prompt_ - or at least that's the term used by the EPFL team at Scala Days.

And that's it! our number guessing game no longer uses global mutable state for random number generation, is still very much in direct style, with two relatively lightweight changes:
- the types are a little different, because they now keep track of the capabilities we need.
- executing our program is now scoped to a prompt, which allows us to choose which `Rand` implementation we're using.

That last bit is interesting. We get to choose how to generate random numbers at the call site! Which means, for example, that we could write a handler specifically for testing our implementation - one that always returns the same value, say:

```scala
def const[A](notRandom: Int)(ra: Rand ?=> A): A =
  val handler = new Rand:
    override def range(min: Int, max: Int) =
      notRandom

  ra(using handler)
```

Using this test handler rather than the `system` one is then merely a matter of changing the prompt:

```scala
rand.const(5):
  run
```

## `Print`: printing things

Now that we have the ability to generate random number, we need to tackle the other effectful thing `run` does: printing.

### The `Print` capability

In a very similar way to `Rand`, we'll create the `Print` capability, with basic primitives:

```scala
package print

trait Print:
  def println(s: String): Unit
```

And, just like we did with `Rand`, we'll want to provide atomic effectful computations that people can compose later, rather than rely on direct access to the handler:

```scala
def println(a: Any): Print ?=> Unit =
  p ?=> p.println(a.toString)
```

That's really it for `Print`. We can now update `run` to rely on it. Since our capability-enabled `println` takes precedence over the default `Predefs.println`, all we need to do is update the type of `run`:
```scala
val run: (Rand, Print) ?=> Boolean = // [...]
```

### Order of capabilities

This is the first time we encounter an effectful computation requiring more than one capability, which raises the question: does their order matter? is there a difference between declaring `run` as `(Rand, Print) ?=> Boolean` and `(Print, Rand) ?=> Boolean`?

First, let's try it and see:

```scala
val runSwapped: (Print, Rand) ?=> Boolean =
  run
```

This compiles - which is good! we really don't want there to be a difference between a computation that needs a `Print` and a `Rand`, and one that needs a `Rand` and a `Print`.

The _reason_ it compiles is, I think, quite interesting and clever. Perhaps unexpectedly, it's a consequence of automatic conversion to context functions. Recall that when the compiler finds `B` where `A ?=> B` is expected, it will synthesise the code needed to turn `B` into `A ?=> B`.

Well, here, the compiler expects `runSwapped` to be of type `(Print, Rand) ?=> Boolean`, but finds `(Rand, Print) ?=> Boolean` which, due to eager application, is really `Boolean`, and will thus add the required implicit values:
```scala
val runSwapped: (Print, Rand) ?=> Boolean =
  (p: Print, r: Rand) ?=> run
```

And, to make this as explicit as possible, here's the code after implicit resolution:
```scala
val runSwapped: (Print, Rand) ?=> Boolean =
  (p: Print, r: Rand) ?=> run(using r, p)
```

You might not enjoy this as much as I did, but I initially assumed there was some specific rule to disregard the order of parameters in a context function. Realising it was "merely" a consequence of existing, not obviously related properties of context functions was quite an exhilarating moment.

### Propagating the capability

If you were to try and compile our updated `run`, you'd get a whole bunch of errors, all of them to do with calls to `println` needing but not finding an implicit `Print`. This makes sense: we call `println` at other points in our implementation, and need to propagate the capability there.

This is a slightly obvious but important property of capabilities: since the compiler tracks them, it can reject code that needs one but whose type fails to declare it!

All we need to do to fix everything is update the following types:

```scala
def loop(target: Int, remaining: Int): Print ?=> Boolean = // [...]

def guess(target: Int): Print ?=> Boolean = // [...]
```

This is sufficient thanks to the two properties of context functions we've seen:
- eager application means we can, at call site, still treat `guess` and `loop` as `Boolean`s.
- automatic conversion allows us to avoid declaring the actual `Print` value and let the compiler do that for us.

And so, without touching anything other than types, without compromising our direct-style implementation in any way, we've made our program much easier to reason about.

## `Read`: reading things

We still have one last effect we need to take care of, the one found deep in the internals of our game:
```scala
def readInput: Option[Int] =
  try Some(readLine.toInt)
  catch
    case _ => None
```

`readInput` requires the ability to read strings. This is going to be extremely similar to `Print`. First, the capability:
```scala
package read

trait Read:
  def readLine(): String
```

We then need the primitive operation as an atomic effectful computation:

```scala
val readLine: Read ?=> String =
  r ?=> r.readLine()
```

Following the same logic as earlier, we can update `readInput`'s type to have it use our capability-enabled `readLine`:
```scala
val readInput: Read ?=> Option[Int] = // [...]
```

This is, of course, going to fail to compile, because `guess` calls `readInput`, and therefore needs the `Read` capability. Which means that so does `loop`, and, transitively, so does `run`. But as we've seen, fixing that is just a matter of updating a few types:
```scala
def guess(target: Int): (Read, Print) ?=> Boolean = // [...]

def loop(target: Int, remaining: Int): (Read, Print) ?=> Boolean = // [...]

val run: (Read, Rand, Print) ?=> Boolean = // [...]
```

The fact that we had to fix all these things is a clear positive: it's a somewhat obvious point, but the compiler _will_ find transitive dependencies and require you to satisfy them before accepting your code.

## A handler for `Print` and `Read`
### `Console`: interacting with standard input and output

You may have noticed that we've yet to write a handler for `Print` and `Read`. I waited until now because I want to do them both at once, with a new capability: `Console`, the ability to interact with the console.

The capability itself is fairly trivial: interacting with the console is, simplified to the extreme, simply writing to and reading from it. So, really, a `Console` is a `Print` and a `Read`:

```scala
package console

trait Console extends Print with Read
```

We'll also need to write a prompt, with a handler backed by `scala.Console`:
```scala
def apply[A](ca: Console ?=> A): A =
  val handler = new Console:
    override def readLine() =
      Console.in.readLine

    override def println(s: String) =
      Console.println(s)

  ca(using handler)
```

Note how the method name being `apply` in package `console` allows us, thanks to Scala desugaring rules, to treat `console:` as a prompt.

Since `Console` provides both `Print` and `Read`, we can simply use that to satisfy all the requirements of `run`:

```scala
rand.system:
  console:
    run
```

The point I'm trying to make here is that you can write aggregate capabilities: capabilities that compose existing ones, and potentially add their own twist to them (we could imagine that `Console` also provided the ability to change the terminal's colours, for example).

### Testing our game

Let's not stop with `Console`, though. We can also very easily write test handlers for `Print` and `Read`.

The simplest think I can think of for a test `Print` handler is one that simply ignores everything:
```scala
def ignore[A](pa: Print ?=> A): A =
  val handler = new Print:
    override def println(s: String) =
      ()

  pa(using handler)
```

In the case of `Read`, we'll want to simulate a user typing in a known string, which is going to be very similar to `rand.const`:

```scala
def const[A](s: String)(ra: Read ?=> A): A =
  val handler = new Read:
    override def readLine() =
      s

  ra(using handler)
```

With these two very simple handlers, we can trivially write a test confirming that `run` yields `true` when the first guess is correct:

```scala
def simpleTest(input: Int) =
  print.ignore:
    rand.const(input):
      read.const(input.toString):
        assert(run)
```

You could then hard-code a few interesting values (or all of them, there's only 10 after all...), or turn this into a property, or...

This is another of the critically useful properties of capabilities: by choosing your handler, you can take an effectful computation and run it, or run tests on it, or swap, I don't know, its data store... this flexibility, derived from separating your program's denotational semantics (what it means) from its operational semantics (what it does), has proven shockingly powerful in a monadic style of programming, and is certain to be just as interesting in this new, capability-backed direct style.


## Conclusion

We've seen that capabilities did allow us to use a direct style of programming: we were able to adapt our initial imperative implementation by simply updating its type. All the interesting properties of that style, then (clarity of intent, ease of reading...), carry over to our new implementation.

These new type signatures, however, allow us to track which effect each computation needs to perform, and thus allow us to think about each of them individually, without having to consider all the possible interactions with the rest of the system. This ability to reason locally about code makes things far, far easier to maintain - remember the Rubik's cube comparison?

Finally, we sort of stumbled on the ability to separate a program's meaning from its execution, and how wonderfully easy it made tests, or swapping some dependencies for others... which, yes, you may argue is also a property of dependency injection - but what are capabilities if not fancy dependency injection?

It would be a little disingenuous of me not to point out one, maybe not flaw, but certainly tricky part of this whole design: the way context functions are eagerly applied is surprising, and sometimes a little limiting (since `A ?=> B` is always treated as a `B`, it's not, for example, currently possible to write extension methods for it).

On a final note, the capabilities we've manipulated in this article are extremely simple. I would encourage you to build on top of them and see where that takes you, but however far that is, it will still be limited: capabilities, as introduced in this article, do not have the ability to impact the program's flow.

This is a limitation of the capabilities I chose to use here, but not one inherent to _all_ capabilities, and I hope in later articles to demonstrate how to have sane _goto_ statements, good error handling, structured concurrency...


## Sources

The content of this article is mostly inspired by / sourced from:
- Noel Welsh's post on [Direct-style Effects](https://noelwelsh.com/posts/direct-style/).
- Martin Odersky's 2023 talk on [Direct Style Scala](https://www.youtube.com/watch?v=0Fm0y4K4YO8).
