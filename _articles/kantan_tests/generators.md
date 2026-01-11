---
title: Random generators
layout: article
series: kantan_tests
code:   https://github.com/nrinaudo/kantan.tests/blob/main/src/main/scala/Rand.scala
date:   20260102
---

## A quick introduction to `Gen`

All property-based testing (PBT from here on) libraries I've played with have the concept of _something that generates random values of a given type_. This is typically called a generator, and traditionally has type `Gen[A]`. So, for example, `Gen[Int]` is the type of something that can generate random ints.

In the company I usully keep, `Gen` is a monad, which makes it convenient to combine multiple generators into a single one - you can for example easily write a generator for tuples:

```scala
def tuple[A, B](genA: Gen[A], genB: Gen[B]): Gen[(A, B)] =
  for a <- genA
      b <- genB
  yield (a, b)
```

## `Gen` as a capability

What we're trying to do here, however, is replace monads with capabilities. A capability is simply a trait that exposes a minimal set of core operations, which for random value generation, is something like this:

```scala
trait Rand:
  def nextInt(max: Int): Int
```

If this went by a little fast - maybe because you're not too familiar with capabilities - I suggest you read [this article](../capabilities.html) first. 

`nextInt` is the only required core operation, because you can build any other type from numbers. Don't worry if you're not convinced by that statement, it will be backed with concrete examples soon.

`Rand` is not quite finished, however. Most implementations are clearly going to be stateful - how can you generate a different integer on different calls to `nextInt` without having some sort of mutable state? In the world of capabilities, mutability is perfectly fine, so long as you control its scope. The easiest way to do so is to flag `Rand` as a `SharedCapability`:

```scala
import caps.*

trait Rand extends SharedCapability:
  def nextInt(max: Int): Int
```

This will cause the compiler to keep track of any `Rand` instance and prevent it from escaping its intended scope (if you're a little mystified by this statement, you should probably read [this article](../capture_checking.html) first).

<a name="gen-type"/>
And so we now have a capability-based version of `Gen`: a generator of `A` is of type `Rand ?-> A`.

Now that we have our base capability, we need to start providing more directly useful ways of interacting with it.

## Useful combinators

### `int` and `range`

The way I've learned to work with capabilities is mostly to ignore them: they should be available, certainly, but we should almost never manipulate them explicitly. Rather, a set of predefined combinators should be exposed, allowing users to build more and more complex and powerful functions relying on the underlying capability.

Let me try and make that statement a little clearer. Imagine we need the ability to generate a random number in a customisable range. A simple implementation would be:
```scala
def range(min: Int, max: Int): Rand ?-> Int = 
  handler ?=> handler.nextInt(max - min) + min
```

Note how the return type, `Rand ?-> Int`, is _pure_ (in the sense used by capture checking): it captures nothing. I've gotten in the (possibly obvious) habit of making the capture set of return types as precise as possible, which, as we'll soon see, is the opposite of what I do for _input_ types.

`range` is straightforward enough, and it does solve our problem. I hate it.

The two bits that offend me are:
- how the type uses `?->` but the term `?=>`. This rubs me the wrong way every time I see it.
- `handler` feels like an implementation detail that I'd really rather shield my users from.

One way to sidestep these two annoyances is to provide the following proxy to `nextInt`:

```scala
object Rand:
  def int(max: Int): Rand ?-> Int =
    handler ?=> handler.nextInt(math.max(0, max))
```

And yes, this suffers from exactly the same problems as `range` did. The critical difference is that we need only deal with this nastiness once. Every other function that needs to call `nextInt` can now simply rely on `Rand.int` instead.

For example, thanks to automatic conversion to context functions (the compiler's ability to turn pure values into effectful computations where needed), `range` can be rewritten as follows:
```scala
def range(min: Int, max: Int): Rand ?-> Int =
  Rand.int(max - min) + min
```

Which I feel is very pleasantly readable:
- the type of `range` makes it clear it's an effectful computation.
- its body is very straightforward and noise-free - it is, in fact, what you would write in a system that doesn't track effects.

Note how I declared `int` in the companion object of `Rand`. This is very intentional: one of the conventions I've landed on after some experimentation is to always put the base combinators there. It scopes them nicely without having to do convoluted things like creating a package per capability, and allows you to:
- use syntax like `Rand.int` to make it very clear what's going on.
- import `Rand.*` and simply call `int` if you prefer.


### Working with characters

`range` opens the door to working with anything that can be mapped to and from integers. A trivial but very useful example of that is characters, which we can make very convenient to work with with the following combinator:

```scala
def range(min: Char, max: Char): Rand ?-> Char =
  range(min.toInt, max.toInt).toChar
```

Note that unless explicitly stated otherwise, all these combinators are declared in the companion object of `Rand`.

This new, char-based, `range` allows us to trivialy write useful little generators. For example, 3 classes of characters that come up a lot in testing:

```scala
val lowerAscii: Rand ?-> Char =
  range('a', 'z')
  
val upperAscii: Rand ?-> Char =
  range('A', 'Z')

val digit: Rand ?-> Char =
  range('0', '9')
```

The obvious next step would be to compose these generators into one that produces strings. I typically make heavy use of a common PBT combinator called `identifier` when writing tests - a generator for valid variable names.

This is a little more involved, so we'll first design a way to generate random lists of _something_, and then rely on that to tie things up neatly.

### Generating lists

A list has two main moving bits:
- the elements it contains.
- its length.

We'll start by solving the first problem: generating a list of `n` random elements for a given `n`. It will look something like this:

```scala
def listOfN[A](n: Int, content: Rand ?=> A): Rand ?->{content} List[A] =
  ???
```

Before writing the body of that function, we should take a moment to talk about capture checking. Note how `content` is _impure_: `?=>` means it captures `cap`, the root capability. I try and always take such values as input, as it offers the most flexibility for callers: because of the way sub-capturing works, you can pass a value with _any_ capture set where one which captures `cap` is expected. _Any_ here really means any: importantly, you can pass a pure value where an impure one is expected.

The converse is not true: you cannot pass an impure value where a pure one is expected. This should make intuitive sense, even if the actual rules that govern this mechanism can be a little thorny. And so, by accepting impure parameters, users can pass both pure and impure arguments. If I accepted pure parameters only, users would be a little stuck with impure arguments.

This rule - always taking _inputs_ with as wide a capture set as possible - impacts my previous one of _outputs_ having as narrow a capture set as possible. `listOfN` cannot be pure, because it takes an impure parameter and captures it. This is made clear in its return type: `Rand ?->{content} List[A]`.

Now that we're clear on capture checking, the body of `listOfN` all but writes itself:

```scala
def listOfN[A](n: Int, content: Rand ?=> A): Rand ?->{content} List[A] =
  val builder = List.newBuilder[A]

  (0 until n).foreach: _ =>
    builder += content
      
  builder.result
```

And yes, I could _absolutely_ have written that as a recursive function and done away with all the mutability. This is more fun though, a little naughty even, and still perfectly safe.

This is enough to write a subset of the `identifier` generator we had in mind. We can easily generate lists (of a fixed length) of (lower case) letters:

```scala
val identifier: Rand ?-> List[Char] = 
  listOfN(100, lowerAscii)
```

We're left with the other part of the list equation: its length. This one might feel a little bit like magic: we've already solved it without knowing it.

Let's write the obvious implementation anyway, for the sake of demonstration:

```scala
def listOfGen[A](n: Rand ?=> Int, content: Rand ?=> A): Rand ?->{n, content} List[A] =
  listOfN(n, content)
```

Note, in passing, how `n` makes it to the capture set of `listOfGen`. I'll not belabour the point, it's essentially the same one I made a little earlier about `content`.

The body of `listOfGen` is a little suspicious: we're passing a `Rand ?=> Int` where an `Int` is expected, aren't we? But if you remember that context functions are eagerly applied, this makes perfect sense. `n` is applied immediately, and an `Int` is, in fact, passed to `listOfN`.

And so, in order to modify `identifier` to generate lists of random rather than hard-coded sizes, we merely need to pass `int(100)` for the length:

```scala
val identifier: Rand ?-> List[Char] = 
  listOfN(int(100), lowerAscii)
```

This is one of the things that still regularly catches me off guard, how effectful computations can be seemlessly treated as values of their return type, and how much code needs no longer be written because of it.

Now - `identifier` is not _quite_ right yet, is it? It generates random lists of lower case letters. We first want to have it return a string, which is exactly as simple as you'd hope:
```scala
val identifier: Rand ?-> String = 
  listOfN(int(100), lowerAscii)
    .mkString
```

Well, yes. We just saw that effectful computations could be treated as whatever they returned, so of course we can apply a `List` method on a `Rand ?-> List[A]`. No silly hoops to jump through, no awkward combinators to get at the "wrapped value" - it's readily available, and you can write code in a _direct style_.

The second improvement we want to bring to `identifier` is, we need it to also contain upper case letters. This will require a little more legwork.

### Choosing between two generators
In order to allow `identifier` to generate either upper or lower case letters, we need the ability to merge two generators (`upperAscii` and `lowerAscii`) into a single one.

This is traditionally called `or` and looks something like this:

```scala
def or[A](lhs: Rand ?=> A, rhs: Rand ?=> A): Rand ?->{lhs, rhs} A =
  if int(2) == 0 then lhs
  else rhs
```

There shouldn't be anything new here, but the `int(2) == 0` bit is a little awkward, isn't it? It's all right for _us_, the library authors, but we don't want end users to have to do that (it all but guarantees off-by-one errors, if nothing else). This is where things start to fall into place quite nicely - look at how easy it is to write a generator of booleans:

```scala
val bool: Rand ?-> Boolean =
  or(true, false)
```

Yes, I am passing raw values where effectful computations are expected - but that's ok! the compiler automatically transforms the former into the latter, which means our `bool` is strictly equivalent to the far more verbose:

```scala
val verboseBool: Rand ?-> Boolean =
  or((handler: Rand) ?=> true, (handler: Rand) ?=> false)
```

And if you're thinking of this in terms of how you'd implement things using monads, yes, it does in fact mean that you do not need a `const` or `pure` combinator, it's always built-in.

Now that we have a reasonable `or`, we can improve `identifier` yet again by having it contain both upper and lower case letters:
```scala
val identifier: Rand ?-> String = 
  listOfN(int(100), or(lowerAscii, upperAscii))
    .mkString
```

We're almost done. `identifier` is _almost_ correct, but for one thing: a variable name can contain letters _and_ digits. We need the ability to combine 2 _or more_ generators, which `or` isn't quite powerful enough to achieve yet.

### Choosing between a set of generators

Everything I've shown you so far sort of makes everything look pleasant and straightforward when dealing with capabilities and capture checking, so it's only fair I show you some of the rough edges, too. I want to make `or` more useful by allowing us to combine _any_ number of generators, not just two. This took me a while to work out, and in the end [Martin Odersky had to step in](https://users.scala-lang.org/t/capture-leak-when-using-varargs/12086) because I was well out of my depths.

The _body_ of the following function is more or less trivial. Its type though? Yeah. Rough edges.

```scala
def oneOf[A, Tail^](
  head: Rand ?=> A, 
  tail: (Rand ?->{Tail} A)*
): Rand ?->{head, Tail} A =
  val index = int(tail.length)

  if index == 0 then head
  else tail(index - 1)
```

I'll refer you to the previously linked conversation for an explanation - it involves _reach capabilities_, which is usually where I just sort of give up.

### Generating identifiers

Having done all that work, we can finally write what we set out to do in the first place: a generator for strings of letters and digits.

```scala
val identifier: Rand ?-> String = 
  listOfN(int(100), or(lowerAscii, upperAscii, digit))
    .mkString
```

This isn't _quite_ right yet though:
- identifiers cannot be empty.
- their first character cannot be a digit.

This is very easy and natural to address:

```scala
val identifier: Rand ?-> String =
  val head = oneOf(lowerAscii, upperAscii)
  val tail = listOfN(int(100), oneOf(lowerAscii, upperAscii, digit))

  (head :: tail).mkString
```

And I must say I really enjoy how _natural_ this is, both to read and write. The intent of the code is there, clear as day, without any noise between it and our brains.

## Actual random generation

We've spent a little while writing a set of useful random generators, which all rely on the ability to generate random numbers. That's the last bit, the thing without which none of this makes sense: we need to provide a _handler_ for `Rand` (a _handler_ is how we call a concrete value of a capability, a little like how we call a concrete value of a type class an _instance_). Note that we'll likely write more than one over the course of this series, but at least for the time being, we need something simple that we can easily play with.

The pattern I've come to settle on for this is methods (in the companion object) that take effectful computations and run them:

<a name="Rand.apply"/>
```scala
def apply[A](body: Rand ?=> A): A =
  val rand = scala.util.Random

  given Rand = (max: Int) => if max <= 0 then 0 else rand.nextInt(max)

  body
```

You would then call this as follows:
```scala
Rand:
  Rand.identifier
```

The `Rand:` bit is called a _prompt_, and it declares a scope in which a `Rand` handler is available. Thanks to capture checking, it cannot escape its intended scope, which means you cannot find yourself working with "dead" handlers.

## Conclusion

There are many (many, many) more standard combinators we could write, but for the purposes of this article, I think we've done enough. Starting from a very small capability - it only exposes a single function, `nextInt` - we've been able to write a library of fairly complex generators. Their implementations tend to be relatively trivial, even if their types can get a little convoluted when reach capabilities are involved (look at `choose`...). I'm still secretly hoping for a breakthrough on that front that'll make things more obvious to non-experts.

The next thing we'll study is _properties_ themselves, and how, at least in the context of kantan.tests, they sort of become irrelevant.
