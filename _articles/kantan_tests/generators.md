---
title: Random generators
layout: article
series: kantan_tests
code:   https://github.com/nrinaudo/kantan.tests/blob/main/src/main/scala/Rand.scala
date:   20260102
---

## A quick introduction to `Gen`

All property-based testing (PBT from here onwards) libraries I've played with have the concept of _something that generates random values of a given type_. This is typically called a generator, and traditionally has type `Gen[A]`. So, for example, `Gen[Int]` is the type of something that can generate random ints.

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

## Useful combinators

Now that we have our base capability, we need to start providing more directly useful ways of interacting with it. It's probably a good idea to at least skim through [this article](../capability_types.html) before going further, as it explains why we declare these combinators the way we do.

### `int` and `range`

The way I've learned to work with capabilities is mostly to ignore them: they should be available, certainly, but we should almost never manipulate them explicitly. Rather, a set of predefined combinators should be exposed, allowing users to build more and more complex and powerful functions relying on the underlying capability.

The most basic one we can provide is the ability to generate a random number - a proxy for `Rand`'s core operation. We'll call this `int`, and while _this_ will need to explicitly work with a `Rand`, everything else can be built on top of it.
```scala
object Rand:
  def int(max: Int)(using handler: Rand): Int =
    handler.nextInt(math.max(0, max))
```

Note how I declared `int` in the companion object of `Rand`. This is very intentional: one of the conventions I've landed on after some experimentation is to always put the base combinators there. It scopes them nicely without having to do convoluted things like creating a package per capability, and allows you to:
- use syntax like `Rand.int` to make it very clear what's going on.
- import `Rand.*` and simply call `int` if you prefer.

Another important thing to note is that `Rand.int` is not _exactly_ of the type we identified for generators: it's not a `Rand ?-> Int`, as you might have expected. I've taken to declaring effectful computations this way because it makes capture checking more or less disappear until it finds an error in your code, which is exactly as it should be. Additionally, the compiler knows how to automatically turn methods of the shape of `Rand.int` into context functions through a mechanism called eta-expansion, so we can _treat_ it as a `Rand ?-> Int`.

Now that we have `Rand.int`, we can build more complex operations on top of it. `Rand.range`, for example, which generates a random number given a specified range:

```scala
def range(min: Int, max: Int)(using Rand): Int =
  Rand.int(max - min) + min
```

Which I feel is very pleasantly readable. We have a dependency on `Rand`, specified by `using Rand`, but never explicitly refer to it. As a result, the body of `Rand.range` is very straightforward and noise-free.


### Working with characters

`Rand.range` opens the door to working with anything that can be mapped to and from integers. A trivial but very useful example of that is characters, which we can make very convenient to work with with the following combinator:

```scala
def range(min: Char, max: Char)(using Rand): Char =
  Rand.range(min.toInt, max.toInt).toChar
```

Note that unless explicitly stated otherwise, all these combinators are declared in the companion object of `Rand`.

This new, char-based, `Rand.range` allows us to trivialy write useful little generators. For example, 3 classes of characters that come up a lot in testing:

```scala
def lowerAscii(using Rand): Char =
  range('a', 'z')

def upperAscii(using Rand): Char =
  range('A', 'Z')

def digit(using Rand): Char =
  range('0', '9')
```

The obvious next step would be to compose these generators into one that produces strings. I typically make heavy use of a common PBT combinator called `identifier` when writing tests - a generator for valid variable names.

This is a little more involved, so we'll first design a way to generate random lists of _something_, and then rely on that to tie things up neatly.

### Generating lists

A list has two main moving bits:
- the elements it contains.
- its length.

We'll start by solving the first problem: generating a list of `n` random elements for a given `n`. Not the most complicated thing in the world:

<a name="Rand.listOfN"/>
```scala
def listOfN[A](n: Int, content: => A): List[A] =
  List.fill(n)(content)
```

This is probably a lot simpler than you expected - it's certainly a lot simpler than my first, naive implementation.

The first thing that might come as a surprise is that `content` is not of type `Rand ?=> A`, as would seem natural - in order to generate a list of random `A`s, surely you need the ability to generate random `A`s.

It turns out you don't. You need the ability to generate `A`s, but who says they _must_ be random? You might want to generate a list of `1`s, for example. Or a list of whatever has been read from a file. Using a by-name parameter makes it clear `content` is _potentially_ effectful, but if it is, all its effects - which may or may not include `Rand` - have been fulfilled. We are, in a slightly roundabout way, being effect polymorphic here: you can pass an effectful computation that returns an `A` _having any set of effects_ (provided they've been fulfilled).

The second thing that's maybe a little surprising is that `Rand.listOfN` doesn't take a `Rand` at all. Well, look at its body: we don't actually need to do anything random in there! We merely need the ability to generate `A`s, which `content` gives us. In fact, `Rand.listOfN` is _exactly_ `List.fill`! We'll keep it because it's easier to understand you need `Rand.listOfN` to generate a random list than it is to make the connection with `List.fill`.

This is enough to write a subset of the `identifier` generator we had in mind. We can easily generate lists (of a fixed length) of (lower case) letters:

```scala
def identifier(using Rand): String = 
  Rand.listOfN(100, Rand.lowerAscii)
      .mkString
```

Note that _this_ needs a `Rand`, because `Rand.lowerAscii` expects one, and it's `Rand.identifier`'s role to provide it.

We can now quite easily make the length of the list random. This requires no change to `listOfN`, as it's entirely dealt with at call site. Let's say we wanted identifiers to be of size 0 to 100:

```scala
def identifier(using Rand): String = 
  Rand.listOfN(Rand.int(100), Rand.lowerAscii)
      .mkString
```

### Choosing between two generators

We'll want to improve on `Rand.identifier` by allowing it to also contain upper case letters.

In order to do that, we'll need the ability to merge two generators (`Rand.upperAscii` and `Rand.lowerAscii`) into a single one. This is traditionally called `or` and looks something like this:

```scala
def or[A](lhs: => A, rhs: => A)(using Rand): A =
  if Rand.int(2) == 0 
    then lhs
    else rhs
```

There shouldn't be anything new here, but the `Rand.int(2) == 0` bit is a little awkward, isn't it? It's all right for _us_, the library authors, but we don't want end users to have to do that (it all but guarantees off-by-one errors, if nothing else). This is where things start to fall into place quite nicely - look at how easy it is to write a generator of booleans:

```scala
def bool(using Rand): Boolean =
  Rand.or(true, false)
```

Now that we have a reasonable `Rand.or`, we can improve `Rand.identifier` by having it contain both upper and lower case letters:
```scala
def identifier(using Rand): String = 
  Rand.listOfN(Rand.int(100), Rand.or(Rand.lowerAscii, Rand.upperAscii))
      .mkString
```

While the code is actually quite simple, it's a little wordy. I prefer to split calls and name intermediate things for readability purposes, but this leads us straight into one of the really dangerous corner cases of capabilities. Look at the following code:
```scala
def identifier(using Rand): String = 
  val legalChar = Rand.or(Rand.lowerAscii, Rand.upperAscii)

  Rand.listOfN(Rand.int(100), legalChar)
      .mkString
```

Can you spot the error? You know, the one the compiler should definitely be allowed to tell you about but isn't, the bug that you'll only observe at runtime when we would really prefer to catch it at compile time? Give it a second, it's quite subtle.

This will always generate identifiers composed of the same character - `aaaa`, `OO`... `legalChar` is not an effectful computation, but the result of running one. Passing it to `listOfN` will not run our generator at all, it will just use the result of calling it that one time.

One way of working around that is what you presumably already do whenever you want to name sub-computations: make them `def`s.

```scala
def identifier(using Rand): String = 
  def legalChar = Rand.or(Rand.lowerAscii, Rand.upperAscii)

  Rand.listOfN(Rand.int(100), legalChar)
      .mkString
```

Aside from the odd compiler bug that I'm pretty confident will be fixed, _this_ is the really tricky part of capabilities. Because of the compiler's inability to let you know when you're passing a value where an effectful computation is expected, you _will_ end up writing bugs.

Do note that it's not really related to capabilities, however. This is inherent to by-names (and context functions), capabilities or not.

### Choosing between a set of generators

We're almost done. `Rand.identifier` is _almost_ correct, but for one thing: a variable name can contain letters _and_ digits. We need the ability to combine 2 _or more_ generators, which `Rand.or` isn't quite powerful enough to achieve yet.

The implementation is straightforward, even if the types are a little more convoluted than I'd like because of the way [varargs and by-names](../capability_types.html#limitation-variadic-parameters) interract (or rather, don't):

```scala
def oneOf[A](head: => A, tail: (Rand ?=> A)*)(using Rand): A =
  val index = int(tail.length)

  if index == 0 then head
  else tail(index - 1)
```

Note that at the time of writing, things are actually a little worse than that and I need some odd capture checking annotations, but I chose to ignore that because it's pretty clearly a bug in the compiler.


### Generating identifiers

Having done all that work, we can finally write what we set out to do in the first place: a generator for strings of letters and digits.

```scala
def identifier(using Rand): String = 
  def legalChar = Rand.or(Rand.lowerAscii, Rand.upperAscii, Rand.digit)
  
  Rand.listOfN(Rand.int(100), legalChar)
      .mkString
```

This isn't _quite_ right yet though:
- identifiers cannot be empty.
- their first character cannot be a digit.

This is very easy and natural to address:

```scala
def identifier(using Rand): String = 
  def legalChar = Rand.or(Rand.lowerAscii, Rand.upperAscii, Rand.digit)

  val head = Rand.oneOf(Rand.lowerAscii, Rand.upperAscii)
  val tail = Rand.listOfN(Rand.int(100), legalChar)

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

An interesting thing to note is that `body` is not a by-name parameter as we've seen so far, but a context function. The `Rand ?=> A` type tells us `body` is an effectful computation that needs a `Rand` handler, and might also run any number of other effects that have all been fulfilled. Since `apply`'s role is to provide that `Rand` handler, it's natural for it to expect computations for which it hasn't yet been provided.


You would then call this as follows:
```scala
Rand:
  Rand.identifier
```

The `Rand:` bit is called a _prompt_, and it declares a scope in which a `Rand` handler is available. Thanks to capture checking, it cannot escape its intended scope, which means you cannot find yourself working with "dead" handlers.

## Conclusion

There are many (many, many) more standard combinators we could write, but for the purposes of this article, I think we've done enough. Starting from a very small capability - it only exposes a single function, `nextInt` - we've been able to write a library of fairly complex generators. Their implementations tend to be relatively trivial, even if their types can get a little convoluted when reach capabilities are involved (look at `choose`...). I'm still secretly hoping for a breakthrough on that front that'll make things more obvious to non-experts.

The next thing we'll study is _properties_ themselves, and how, at least in the context of kantan.tests, they sort of become irrelevant.
