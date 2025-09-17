---
title:   Controlling program flow with capabilities
layout:  article
date:    20250907
code:    https://github.com/nrinaudo/hands_on_capabilities/blob/main/errors/src/main/scala/errors.scala
---

## Introduction 

I've written about capabilities [before](./capabilities.html), but only presented very simple ones, ones that do not impact the program flow in any way.

This article intends to fix this  by exploring how to jump around in a program, short-circuiting computations as and when necessary. This is a powerful tool that we'll bring to bear to make code that can be a little thorny in a monadic style quite clear in a capabilities-backed direct style, without loosing the properties we care about.

## Sequencing data

The example we'll be using is _sequencing_, the fancy name for _flipping type constructors_ - turning an `F[G[A]]` into a `G[F[A]]`. For simplicity's sake, we'll use hard-coded type constructors: we'll work on turning a `List[Option[A]]` into an `Option[List[A]]`. If the input list contains at least one `None`, the result will be `None`. Otherwise, it will be `Some` of a list containing unwrapped values.

For example:
```scala
sequence(List(Some(1), Some(2)))
// Some(List(1, 2))

sequence(List(Some(1), Some(2), None))
// None
```

I've picked `sequence` because, well, it illustrates my point quite neatly, but also because it's such a common combinator, and one which I feel is quite unpleasant to write in a monadic style.

### Without capabilities

Here's a possible monadic style implementation:
```scala
def sequence[A](oas: List[Option[A]]): Option[List[A]] =
  val flipped = oas.foldLeft(Option(List.empty[A])):
    case (None, _) | (_, None)  => None
    case (Some(acc), Some(cur)) => Some(cur :: acc)

  flipped.map(_.reverse)
```

This might need a little explaining as the code, short though it is, is not necessarily the clearest. `sequence` folds over our list, defaulting to `Option(List.empty)` if the input is empty.

If it's _not_ empty, we really have 3 possible scenarios:
- if the current value is `None`, then `sequence` must return `None`, and so must our fold.
- if the accumulator is `None`, then we've encountered `None` earlier in the list and must return that.
- otherwise, we can unwrap both, concatenate them into a list and wrap it back in a `Some`.

Finally, `foldLeft` builds the list the wrong way around, so we need to reverse it once we're done, meaning we'll traverse the list twice - not _dreadful_, but certainly not ideal.

While on this topic, we're also suffering from the lack of short-circuiting: even if the very first element is `None`, we'll still go through the entire list. It's not a show-stopper, but certainly sub-optimal.


### With capabilities

We're going to try to solve this problem in a somewhat more straightforward way. The general idea is to assume "success" (every `Option` is a `Some`), but provide an escape hatch if a `None` is encountered:
- go through the entire list, unwrapping `Some`s as we encounter them.
- wrap the entire result in a `Some`.
- if we encounter a `None`, abort the whole thing and return `None`.

This last point requires us to flag a part of the code as the place to abort _to_, which we'll do by using the term `boundary`.

Our solution looks something like this:

```scala
def sequence[A](oas: List[Option[A]]): Option[List[A]] =
  boundary:
    Some(oas.map:
      case Some(a) => a
      case None    => break(Option.empty)
    )
```

This, if it worked, would solve our problems:
- `map` explores the list the right way around, meaning we'd traverse it at most once (if all elements are `Some`s).
- `break` yields control to `boundary`, short-circuiting `map` entirely and allowing the program to carry on with a `None`.

There is, of course, one obvious problem. Neither `boundary` nor `break` exist yet, so this only works in our head, or at least in mine. Let's try to fix this.

We're trying to work with capabilities, so what capability do we need to solve this? Well, we've seen that our solution relies on marking a place in the code to jump back to if necessary, so that's what we'll need: a marker of the position to jump to. Very much like the _label_ part in a `goto/label`.

Something like this, then:

```scala
class Label[A]
```

That `A` type parameter needs some explaining. If you look at our code above, `boundary` has two ways of returning:
- if `break` is called, by returning whatever was passed to `break` (`Option.empty` in our example).
- otherwise, by returning the result of the block of code scoped by `boundary` (the `Some(oas.map....)` in our example).

We want to ensure both these values are of the same type, and therefore must keep track of it. That's `A`: the type returned by the `boundary` creating the `Label`.

While we're on `boundary`, we can relatively easily decide its general shape: it must take a computation that, given a `Label[A]`, yields an `A`. It will then provide that `Label[A]` somehow, run the computation, and return its result:

```scala
def boundary[A](ba: Label[A] ?=> A): A = ???
```

`boundary` is what we called a _prompt_ in our [previous article](./capabilities.html).

Similarly, the shape of `break` is easy enough to infer: given an `A`, it creates an effectful computation taking a `Label[A]` to jump to.

```scala
def break[A](a: A): Label[A] ?=> Nothing = ???
```

Note how the return type of that computation is `Nothing`: since `break` will always jump to its label, it will never actually return anything.

But now of course, the critical question: _how_ do we jump to the label? Well, doesn't Scala already have a mechanism for exactly that? Isn't that _precisely_ what exceptions do, aborting whatever is going on and jumping to the closest `catch` block handling them?

We can simply, for a maybe slightly novel definition of the term, rely on exceptions. We'll need our own exception type, which must keep track of:
- the value with which to abort the computation. This is how we carry it back to the `boundary`.
- the `Label` we're breaking to, so that we can later ensure we're not grabbing somebody else's `break` call.

```scala
import scala.util.control.*

case class Break[A](label: Label[A], value: A) 
  extends ControlThrowable with NoStackTrace
```

There's a bit of not terribly important boilerplate here, the `ControlThrowable` and `NoStackTrace` bits, which we merely use to reduce the runtime cost of initialising and throwing exceptions.

With this in mind, `break` becomes trivial: it simply throws a `Break`.

```scala
def break[A](a: A): Label[A] ?=> Nothing = 
  label ?=> throw Break(label, a)
```

`boundary` is a little more complicated, but not unreasonably so:
- it needs to create a `Label[A]` in order to provide it to the effectful computation.
- that effectul computation will be executed in a `try` / `catch` block.
- if a `Break` is thrown with the right `Label[A]`, `boundary` will catch it and return the associated value.

```scala
def boundary[A](ba: Label[A] ?=> A): A =
  val label = new Label[A]

  try ba(using label)
  catch case Break(`label`, value) => value
```

That `catch` part is maybe a little tricky. The back-ticked `label` part always seems to catch people off-guard. It's syntax to say _equal to the value with the same name in scope_ - so we're really saying that `Break` contains the `label` we declared above. This, in turn and through the magic of GADTs, allows the compiler to infer that `value` is of type `A`.

And that's really all there is to it. With that, the following compiles and runs as expected:

```scala
sequence(List(Option(1), Option(2)))
// Some(List(1, 2))

sequence(List(Option(1), Option(2),None))
// None
```

It's probably worth pointing out that if you want to use `boundary` and `break` right now, they're already part of the [standard Scala 3 library](https://www.scala-lang.org/api/3.5.0/scala/util/boundary$.html).

## Specialised boundaries

If we look back at our new implementation of `sequence`, it's maybe better than the initial one (and even that is probably a matter of taste), but not exactly great yet:

```scala
def sequence[A](oas: List[Option[A]]): Option[List[A]] =
  boundary:
    Some(oas.map:
      case Some(a) => a
      case None    => break(Option.empty)
    )
```

There's a lot `Option`-specific bits in there, bits that make the code a little awkward, or at least noisier than I'd like. We're going to try and do a little better.

If you stare long enough at `sequence`, you may see how we can split it in 3 main parts:
- the bulk of the logic: mapping over the list and doing things with its elements.
- what to do if the computation reaches its natural end (wrap the result in a `Some`).
- what to do if the computation _does not_ reach its natural end (return `Option.empty`).

The first part is specific to what we're doing, so we can't really abstract over it. But this notion of what to do on success and failure? _That_ we can allow callers to customize. The general idea is that we'll want to allow them to succeed with some type `S`, fail with some type `E`, but then need to unify both to a unique type `A`, the result of the entire block. For example, a computation might return an `Int` on success, a `String` on failure, and we'll want to unify them for the entire block to return an `Option[Int]`.

Our more general combinator, which we'll creatively call `handle`, then behaves pretty much as `boundary` did, with some post-processing of the success and error cases:

```scala
def handle[E, S, A](
  la     : Label[E] ?=> S,
  success: S => A,
  error  : E => A
): A =
  val label = new Label[E] {}

  try success(la(using label))
  catch case Break(`label`, value) => error(value)
```

We can obviously rewrite `boundary` in terms of `handle`, by simply leaving the success and failure values alone:

```scala
def boundary[A](ba: Label[A] ?=> A): A = 
  handle(ba, identity, identity)
```

But we can also make a specialised version for `Option`, which wraps success in `Some` and ignores failures to return a `None`:

```scala
def option[E, S](os: Label[E] ?=> S): Option[S] =
  handle(os, Option.apply, _ => None)
```

This allows us to rewrite `sequence` in a way that I find a lot more pleasing:
```scala
def sequence[A](oas: List[Option[A]]): Option[List[A]] =
  option:
    oas.map:
      case Some(a) => a
      case None    => break(Option.empty)
```

There's still a small detail I'm not particularly happy with, though: `break(Option.empty)`. We're ignoring whatever is passed to `break`, so why should we pass anything to it?

We can make that a little nicer by providing a version of `break` that doesn't actually take a value:

```scala
def break: Label[Unit] ?=> Nothing =
  break(())
```

Which gives us what I think is a reasonably terse and clear version of `sequence`:

```scala
def sequence[A](oas: List[Option[A]]): Option[List[A]] =
  option:
    oas.map:
      case Some(a) => a
      case None    => break
```


## A little bit of Rust
The Rust community would probably argue that this is nice and all, but in Rust you can use `?` and that's much better. Which, honestly, that's a fair point. Let's see if we can do something about it.

What goes on in the `map` part of `sequence` is a fairly common pattern: given an `Option[A]`, extract the underlying `A` if it exists, break otherwise. This is pretty much what Rust's `?` does, and we can achieve the same result with an extension method:

```scala
extension [A](oa: Option[A]) def ? : Label[Unit] ?=> A =
  oa match
    case Some(a) => a
    case None    => break
```

This extension method allows us to simplify `sequence` drastically:

```scala
def sequence[A](oas: List[Option[A]]): Option[List[A]] =
  option:
    oas.map(_.?)
```

And honestly, I really like this implementation. Assuming you know what `?` does, this is extremely clear, and I would argue quite an improvement on our very first version of `sequence`.

## A very flexible approach

### Sequencing over `Either`

We've seen how to provide a bespoke prompt for handling errors with `Option`. I want to quickly show how little work it is to support a maybe slightly more useful error type, `Either`.

First, we'll need our prompt, which is going to be very similar to `option` but won't ignore the error value:

```scala
def either[E, S](es: Label[E] ?=> S): Either[E, S] =
  handle(es, Right.apply, Left.apply)
```

We'll also want a `?` extension method. It is, again, very similar to the one we wrote for `Option`, except now we have a value to `break` with:

```scala
extension [E, A](ea: Either[E, A]) def ? : Label[E] ?=> A = 
  ea match
    case Right(a) => a
    case Left(e)  => break(e)
```

Which gives us `sequenceEither`, just as simple and straightforward as the `Option` version:

```scala
def sequenceEither[E, A](eas: List[Either[E, A]]): Either[E, List[A]] =
  either:
    eas.map(_.?)
```

### Nested prompts

We now have two interesting prompts: `option` and `either`. This should quite quickly lead to questions such as: how do they mix? Can I nest them? Can I choose which boundary marker to break to?

In order to demonstrate, we'll take the entirely artificial example of `sequencePositive`, a function which sequences a `List[Option[Int]]`, but fails if any of the integers is negative. This needs two different short-circuiting mechanisms:
- one to short-circuit `map` when a `None` is encountered.
- one to fail when a negative value is encountered.

The question is: how to choose which one `break` goes to? And this is where we can use the fact that our capability is simply the `Label` to jump to: we can eschew the context function syntactic sugar and declare it explicitly, and later pass it to a call to `break`.

Or, more concretely:

```scala
def sequencePositive(ois: List[Option[Int]]): Either[String, Option[List[Int]]] =
  either: fail ?=>
    option:
      ois.map: oi =>
        val i = oi.?
        if i >= 0 then i
        else           break(s"Negative number: $i")(using fail)
```

Note how our `either` prompt explicitly declares its label, `fail`, which we later pass explicitly to `break` when encountering a negative number.

This has exactly the desired behaviour:

```scala
sequencePositive(List(Some(1), Some(2)))
// Right(Some(List(1, 2)))

sequencePositive(List(Some(1), Some(2), None))
// Right(None)

sequencePositive(List(Some(1), Some(2), Some(-2), None))
// Left(Negative number: -2)
```

## Making `Label`s safe
One important aspect of all this, one which the previous example highlights, is that labels are _just_ values. Which means they can be captured and, if we're not careful, later used _outside_ of the scope of their prompt.

Here's a simple example using an `Iterator` instead of a `List`:

```scala
def sequenceIterator[A](is: Iterator[Option[A]]): Option[Iterator[A]] =
  option:
    is.map(_.?)
```

This is problematic, because `Iterator` is lazy. The `_.?` bit won't be executed until _after_ `sequenceIterator` exits - outside of the prompt's `try` / `catch` block, allowing the exception to go unchecked and result in a runtime failure.

```scala
val flipped = sequenceIterator(Iterator(Some(1), None, Some(2)))

// Forces consumption of the iterator.
flipped.foreach(_.foreach(println))
// 1
// Exception in thread "main" Break
```

This is a typical problem of value escaping, which Scala now has a mechanism to deal with: [capture checking](./capture_checking.html). If you're using a recent enough version of Scala (I'm using `3.8.0-RC1-bin-20250823-712d5bc-NIGHTLY` for this article), `Iterator` has capture annotations, meaning we can make the problem disappear by marking `Label` as a capability:

```scala
import language.experimental.captureChecking
import scala.caps.*

class Label[E] extends SharedCapability
```

By flagging `Label` this way, we're telling the compiler never to allow it to escape the way it does in `sequenceIterator`. In theory, this should be the end of that, but it unfortunately has a bit of a cascading effect: `Break` no longer compiles, because it now captures a `Label` by way of its `label` field. This _should_ be fine, but at the time of writing, the [compiler treats all Java types as pure](https://users.scala-lang.org/t/boundary-break-and-capture-checking/12036/5) - in our case, it means `Exception`s (which `Break` is) are not allowed to capture anything - which includes `Label`.

Things are about to get a little messy. `Break` must capture its `label`, but is not allowed to. Time for some good old fashionned witchcraft.

First, by making the compiler think `Label` is not tracked when used in `Break`:
```scala
case class Break[A](label: Label[A]^{}, value: A) 
  extends ControlThrowable with NoStackTrace
```

This is saying that even though `Label` is always tracked, we're overriding this specific usage to be untracked by emptying its capture set. Is this dodgy? Definitely! We're specifically allowing it to escape when we said we never wanted that to happen.

What we _actually_ want, however, is for `Label` never to escape in _user code_. Our internal implementation requires it to escape, in a way that we fully control and know to be safe. It's a little like an unsafe cast: sometimes, we just know something is safe but can't convince the compiler otherwise, and must tell it to just trust us.

Speaking of unsafe casting: when creating a new `Break`, we can't simply pass it a `Label`. We must pass it a `Label` _with an empty capture set_ for types to line up. We can do that by, again, telling the compiler we know better than it does:

```scala
import scala.caps.unsafe.unsafeAssumePure

def break[A](a: A): Label[A] ?=> Nothing =
  label ?=> throw Break(label.unsafeAssumePure, a)
```

And yes, this is all a little nasty, but it gets us where we need: our previous `sequenceIterator` now fails to compile with a somewhat obscure error message which more or less translates to _what do you think you're dong, allowing a `Label` to escape_.

This might seem like a relatively minor point, but is quite important: capabilities are scoped to regions of a program, and must only be available within that region. Allowing them to escape leads to all sort of painful, hard to debug problems. Capabilities really need capture checking in order to be safe and remain easy to reason about.

## Conclusion

This articles showed how we could use capabilities to provide flow control mechanisms, and drastically simplify code (that, if we're being honest, was hand-picked for how striking the simplification was). As we've seen, it's not even particularly difficult, provided we don't allow our distaste for exceptions to get in the way.

We've also seen how all this is very nice and all, but without capture checking, we'd only be introducing new, fun ways of failing in obscure fashions.

What we have yet to see, however, is how to use capabilities to do _structured concurrency_. I really hope to make this the subject of a future article, as soon as I actually work out the answer to that question.

## Sources

The content of this article is mostly inspired by / sourced from:
- Noel Welsh's post on [Direct-style Effects](https://noelwelsh.com/posts/direct-style/).
- Riccardo Cardin's [Raise4s](https://github.com/rcardin/raise4s) library.
- Martin Odersky's 2023 talk on [Direct Style Scala](https://www.youtube.com/watch?v=0Fm0y4K4YO8).

