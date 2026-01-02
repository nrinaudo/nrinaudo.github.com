---
title:  Properties and tests
layout: article
series: kantan_tests
date:   20260102
---

## Properties

The titular properties of _property_-based testing can be seen as simple predicates over universally quantified parameters.

To make this a little more concrete, let's take the property traditionally used as a basic example:
> For all lists `xs`, the length of `xs` before sorting must be the same as its length after sorting.

This is a predicate (a function of list to boolean), and is universally quantified (it applies to all lists).

This can be turned into code quite easily, to something that often looks like this:

```scala
forAll: (xs: List[Int]) =>
  sort(xs).length == xs.length
```

And this is all I'm really interested in about properties. I'm very deliberately ignoring the way they can usually be combined with algebraic operations (disjunction, conjunction, implication, etc...), because I've never found it useful or interesting. I have a very specific (if not necessarily very original) workflow when writing properties, and combining them is not at all part of it. It actually makes it harder for me to write useful tests.

Let me clarify that I'm not suggesting combining properties is inherently useless. I'm sure it is incredibly useful to some people, just... not me, and I don't really want to write about something I find a little tedious and do not plan on using. I'm sure the result would be more than a little tedious itself.

And so, ignoring the bit about how you can combine properties together, they're really just functions that, given one or more generators (the universally quantified bits), produce a boolean.

Let's think about that last sentence for a bit. Properties combine generators to produce booleans. Properties... are generators of booleans. Very special generators, certainly - ones that we hope always produce `true` - but generators nevertheless.

This leads us to a rather obvious encoding of properties: `Rand ?-> Boolean`. Our previous property could be written, using `Rand` (and assuming the existence of `randomInts: Rand ?-> List[Int]`), as:
```scala
val prop: Rand ?-> Boolean =
  val xs = randomInts
  
  sort(xs).length == xs.length
```

And I find that to be _very_ good news, because it solves two problems that matter to me:
- property arity - the number of inputs a property has - which is very awkward to deal with in Scala.
- property-based and example-based tests being written in different ways.

### Ignoring property arity

This is more of a Scala problem than a PBT one, but, well. This is written in Scala.

Scala functions aren't curried by default, the way Haskell or OCaml ones are. There's a type for each function arity - `Function0`, `Function1`, `Function2`... thankfully with syntactic sugar to try and hide this under the rug. But the fact remains: if you want the ability to create properties that take arbitrary numbers of inputs, you need to write one constructor per number of inputs. And if you don't believe me, look at all the different versions of `forAll` defined in [ScalaCheck](https://github.com/typelevel/scalacheck/blob/main/core/shared/src/main/scala/org/scalacheck/Prop.scala).

With our encoding of properties as `Rand ?-> Boolean` though? we don't need to figure out how to solve this particular problem, it does not exist at all. The type of a property doesn't change with its inputs, it's merely a function that, given the ability to create random values, will produce booleans.

### Unifying examples and properties

Before I can explain what that particular point is, I think it's better to describe how I usually go about writing tests. I know we're supposed to think hard about our systems and extract deep, meaningful properties who, combined together, specify the system entirely. There's something beautiful and elegant and almost philosophical about the whole process. But I mostly can't be bothered.

First, it's really hard! I'm not saying it's too hard to do, _ever_, but it certainly is too much work for a lot of mundane parts of the systems I write. I will expand that much energy on complicated, important bits that lend themselves to it, but not every single moving part.

Second, it's not how I've been trained to write tests. I've been formatted by studies and professional experiences to write example-based tests. Think of a scenario that your system should handle, write that scenario in a test, and make sure it outputs the right thing. I've honed my ability to think of edge cases to a reasonably sharp edge, and I fully intend to make use of it.

It's also how a lot of real world things _must_ happen: think about bug reports, for example. If the reporter is any good, you'll get a minimum reproduction scenario, an expected behaviour and an observed one. That is... an example-based test, which you should immediately put in your test suite to prevent regressions (or even simply to confirm that your fix actually fixes something).

And so, because of my training, and because of the way system maintainance works, I end up with a lot of example-based tests. The trick is to realise that it's usually quite manageable to turn them into perfectly good properties by:
- identifying all the bits of the input that shouldn't have an impact on what you're testing, and making these random.
- identifying all the bits that _do_ have an impact, and making them random, but constrained to the shape you need for your test.

And voilà! you just wrote a property.

Let me illustrate this by taking a concrete example. Say we're tasked with testing that `List.headOption` yields the expected result:
- `None` on the empty list
- `Some` of the first element on a non-empty list.

I would personally start with some reasonable example-based tests to make sure `headOption` is at least reasonably healthy:

```scala
test("non-empty list head"):
  val input = List('a', 'b', 'c')
  
  input.headOption == Some('a')
  
test("empty list head"):
  val input = List()
  
  input.headOption == None
```

The _empty list_ test is as good as it's likely to get, but the other one can be improved on by making `input` a random non-empty list. This can be achieved by generating the head of the list, and prepending it to a random list of any length:

```scala
test("non-empty list head"):
  val head  = Rand.lowerAscii
  val tail  = Rand.listOf(Rand.int(99), Rand.lowerAscii)
  val input = head :: tail
  
  input.headOption == Some(head)
```

I find that workflow very satisfying. Start with a simple example, because I know how to do that, and then generalise it into something more powerful. And I would love if it was that easy, if I could simply make constants a little more fun and exciting without touching anything else. But unfortunately, most tools I'm aware of make it very unpleasant, because they do not let you write examples and properties the same way at all, and so moving from the former to the latter requires a lot of unpleasant hoop jumping.

Fortunately for us, the `Rand ?-> Boolean` encoding makes this absolutely trivial. We merely need to think of an example-based test as a property that ignores its `Rand` capability. With that framing, we don't even need specific code to support it!

Here's a slightly naive implementation of the `test` function I was using above to declare a test:

```scala
def test(desc: String)(body: Rand ?=> Boolean) =
  def go(count: Int): Boolean =
    if count <= 0 then true
    else
      Rand:
        if body then go(count - 1)
        else         false

  go(100)
```

This will attempt the test up to 100 times, aborting on the first failure. And it fully supports my workflow - in fact, all the examples above compile just fine with this `test` declaration!

Before going on to the next improvement, there's a point I think needs to be made here. I don't think we're working with properties any longer. We're no longer manipulating predicates universally quantified on their inputs, but simple blocks of code that evaluate to success or failure, and may or may not include some randomness. I think it's more correct to call what we're doing _generative tests_, because calling it properties would be a little misleading.


Now, I know some of you are probably bothered by the current `test` implementation. We've all been trained to look for premature optimisation opportunities and to feel a little smug when we find low-hanging fruits, and there's a rather obvious one here, isn't there? If we pass a non-generative test (that is, one that doesn't rely on randomness) to `test`, it will still be executed 100 times, where once would suffice. Isn't that a little inefficient? 

## Enhancing handlers

We could solve this (premature!) optimisation problem quite simply if there was some way to know whether the `Rand` capability was used while running a test: if it wasn't, then further iterations won't change anything and we can simply stop there.

This sounds a lot like mutable state - some sort of flag set to `true` if and only if `Rand` was used, for example. And we have just the place to store such state: the handler itself! If you remember the one we [wrote earlier](./generators.html#Rand.apply), it's _already_ stateful, which is how it manages to generate different values on successive calls to `nextInt`. We could naively update it to contain a little more state:

```scala
def apply[A](body: Rand ?=> A): A =
  val rand = scala.util.Random
  var used = false

  given Rand = (max: Int) => 
    used = true
    if max <= 0 then 0 else rand.nextInt(max)

  body
```

I do not find this very satisfying, however. Were we to ever write a new `Rand` handler (and I don't mean to spoil it for you but that's definitely happening), we'd need to duplicate this admittedly rather trivial feature. No, a much better solution would be to figure out how to compose handlers, how to take an arbitrary handler and tack new features on to it.

I've played a little in that design space, went back to my roots as an OOP programmer and tried subclassing handlers, but none of it was quite right. The best way I found was the most obvious (in hindsight only, perhaps): it's possible for handlers to store others and proxy calls to them (yes, I *am* using [Design Patterns](https://en.wikipedia.org/wiki/Proxy_pattern), so glad you noticed).

Here's how it would work for our needs, a handler that modifies an existing one to track whether or not `nextInt` was called:

```scala
def tracking[A](body: Rand ?=> A): Rand ?->{body} A = handler ?=>
  var used = false
  
  given Rand = (max: Int) =>
    used = true
    handler.nextInt(max)

  body
```

If you look at its type, `tracking` produces an effectful computation - you'll need a `Rand` to run it. But when it does run, it will track the status of `nextInt`. You could call it like this, for example:
```scala
Rand:
  Rand.tracking:
    val input = List('a', 'b', 'c')
  
    input.headOption == Some('a')
```

Except - we keep track of whether or not `nextInt` was called, but we don't really expose that information, do we?

One approach - the first I tried, the silly one that was obviously never going to work, but this is a skill of mine, making all the mistakes so you don't have to - would be to expose the tracking handler as a type with some `used` property. But if you think about it a little, isn't the entire point of capture checking to make this useless? Even if we were to do that, the handler would be scoped to the `Rand.tracking` block, and unable to escape. It would expose `used`, but no one would be able to get their hands on it.

The solution I've come up with - I make it sound like some grand discovery but it really is just the obvious next step - is to change the type of `tracking` to ultimately not return an `A`, but some other type wrapping an `A` and the `used` value. Something like this:
```scala
case class Tracked[A](value: A, used: Boolean)
```

We can then very easily update `tracking` to make use of it:
```scala
def tracking[A](body: Rand ?=> A): Rand ?->{body} Tracked[A] = handler ?=>
  var used = false
  
  given Rand = (max: Int) =>
    used = true
    handler.nextInt(max)

  Tracked(body, used)
```

We now have the ability to run some effectful computation and to know whether it called `nextInt`, which was the last bit we needed to complete our initial `test` implementation:
```scala
def test(desc: String)(body: Rand ?=> Boolean) =
  def go(count: Int): Boolean =
    if count <= 0 then true
    else
      Rand:
        tracking(body) match
          case Tracked(result, false) => result
          case Tracked(true, __)      => go(count - 1)
          case _                      => false

  go(100)
```

## Conclusion

I think we've achieved rather a lot here. We've solved two problems that dearly matter to me - how cumbersome it is to deal with properties of different arities, and how annoying it is to turn example-based tests into property-based ones. Our library now has a unified way of running things, and even an automated way of deciding wether a given test was generative or not.

We've learned along the way how to compose handlers - something we'll be doing quite a bit of - and have hammered in the point that you could choose to ignore capabilities you were given - to pass in non-effectful computations were effectful ones are expected. This is no longer a mere, vaguely interesting theorical point: it's exactly how we manage to treat non-generative tests and generative ones as the same thing.


