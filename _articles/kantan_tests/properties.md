---
title:  Properties and tests
layout: article
series: kantan_tests
date:   20260102
---

## Properties

The titular properties of _property_-based testing can be seen as simple predicates over universally quantified parameters.

To make this a little more concrete, let's take the traditional basic example:
> For all lists `cs`, the length of `cs` before sorting must be the same as its length after sorting.

This is a predicate (a function of list to boolean), and is universally quantified (it applies to all lists).

This can be turned into code quite easily, and looks something like:

```scala
val prop = forAll(genChars): cs =>
  sort(cs).length == cs.length
```

This is all I'm really interested in about properties. I'm very deliberately ignoring the way they can usually be combined (with disjunctions, conjunctions, implications, etc...), because that's never struck me as useful or interesting. I have a very specific (if not necessarily very original) workflow when writing properties, and combining them is not at all part of it.

Let me clarify that I'm not suggesting combining properties is inherently useless. I'm sure it is incredibly useful to some people, just... not me, and I don't really want to write about something I find a little tedious and do not plan on using. The result would be sure to be more than a little tedious itself.

And so, ignoring the bit about how you can combine properties together, they're really just functions that, given one or more generators (the universally quantified bits), produce a boolean.

Let's think about that last sentence for a bit. Properties combine generators to produce booleans. Properties... are generators of booleans. Very special generators, certainly - ones we hope always produce `true` - but generators nevertheless. And if you'll recall, we [defined](./generators.html#gen-type) a generator of `A` as `Rand ?-> A`: it follows that our type for properties is `Rand ?-> Boolean`.

Our previous property could be written as:
```scala
def prop(using Rand): Boolean =
  val cs = Rand.listOfN(Rand.int(100), Rand.lowerAscii)
  
  sort(cs).length == cs.length
```

And I find that to be _very_ good news, because it solves two problems that matter to me:
- property arity - the number of inputs a property has - which is very awkward to deal with in Scala.
- property-based and example-based tests being written in different ways.

## Ignoring property arity

This is more of a Scala problem than a PBT one, but, well. This is written in Scala.

Scala functions aren't curried by default, the way Haskell or OCaml ones are. There's a type for each function arity - `Function0`, `Function1`, `Function2`... thankfully with syntactic sugar to try and hide this under the rug. But the fact remains: if you want to support properties that take different numbers of inputs, you need one way of creating a property per number of inputs you support. For example, for arities 1 to 3:

```scala
def forAll1[A](genA: Gen[A])
              (test: A => Boolean) =
  for   a <- genA
  yield f(a)

  
def forAll2[A, B](genA: Gen[A], genB: Gen[B])
                 (test: (A, B) => Boolean) =
  for   a <- genA
        b <- genB
  yield f(a, b)

def forAll3[A, B, C](genA: Gen[A], genB: Gen[B], genC: Gen[C])
                    (test: (A, B, C) => Boolean) =
  for   a <- genA
        b <- genB
        c <- genC
  yield f(a, b, c)
```

Users would then write properties as follows:
```scala
val prop1 = forAll1(genChars): cs =>
  sort(cs).length == cs.length
  
val prop2 = forAll2(genChar, genChars): (c, cs) =>
  (c :: cs).head == c
```

You can of course do some work to make this less dreadful - ad hoc polymorphism allows you to give all versions of `forAll` the same name so that users don't need to think about it too much, for example. And if writing that much duplicated code bothers you, there are of course [tools to automate it](https://github.com/sbt/sbt-boilerplate). You can probably also do clever things with tuples - which would lead to some small amount of syntactic overhead for users, not ideal but certainly not a show stopper. But what if somebody wanted to write a property with 23 inputs when the author only wrote up to 22 such functions?

I would much prefer a solution where this problem didn't exist. The good news is, our `Rand ?-> Boolean` encoding is exactly such a solution: we do not take a generator for each input of our property, but the ability to generate random values regardless of how many inputs it has. This allows us to rewrite the above properties as:

```scala
def prop1(using Rand): Boolean =
  val cs = Rand.listOfN(Rand.int(100), Rand.lowerAscii)
  
  sort(cs).length == cs.length

def prop2(using Rand): Boolean =
  val c  = Rand.lowerAscii
  val cs = Rand.listOfN(Rand.int(100), Rand.lowerAscii)

  (c :: cs).head == c
```

I was delighted when I realised this, as I fully expected to have to write the 22 different construction functions at some point and was _not_ looking forward to it.


## Unifying examples and properties
### The problem
Before I can explain what that particular point is, I think it's better to describe how I usually go about writing properties. We're supposed to think hard about our systems and extract deep, meaningful properties who, combined together, specify them entirely. There's something beautiful and elegant and almost philosophical about the whole process. But I mostly can't be bothered.

First, it's really hard! I'm not saying it's too hard to do, _ever_, but it certainly is too much work for a lot of mundane parts of the systems I write. I will expand that much energy on complicated, important bits that lend themselves to it, sure, but not on every single moving part.

Second, it's not how I've been trained to write tests. I've been formatted by studies and professional experience to write example-based tests. Think of a scenario that your system should handle, write that scenario in a test, and make sure it outputs the right thing. I've honed my ability to think of edge cases to a reasonably sharp edge, and fully intend to make use of it.

It's also how a lot of real world things _must_ happen: think about bug reports, for example. If the reporter is any good, you'll get a minimum reproduction scenario, an expected behaviour and an observed one. That is... an example-based test, which you should immediately put in your test suite to prevent regressions (or even simply to confirm that your fix actually fixes something).

And so, because of my training, and because of the way system maintainance works, I end up with a lot of example-based tests. The trick is to realise it's usually quite manageable to turn them into perfectly good properties by:
- identifying all the bits of the input that shouldn't have an impact on what you're testing, and making these random.
- identifying all the bits that _do_ have an impact, and making them random, but constrained to the shape you need for your test.

And voilà! you just wrote a property.

Let me illustrate this by taking a concrete example. Say we're tasked with the exciting, not at all artificial job of testing that `List.headOption` yields the expected result:
- `None` on the empty list
- `Some` of the first element on a non-empty list.

I would personally start with some simple example-based tests to make sure `headOption` is at least reasonably healthy. Ideally, something that looks like this:

```scala
test("non-empty list head"):
  val input = List('a', 'b', 'c')
  
  input.headOption == Some('a')
  
test("empty list head"):
  val input = List()
  
  input.headOption == None
```

Once I'm convinced these two scenarios are handled properly, I'd start generalising them. The _empty list_ test is as good as it's likely to get, but the other one can be improved on by making `input` a random non-empty list. This can be achieved by generating the head of the list, and _cons_-ing onto a random list of any length:

```scala
test("non-empty list head"):
  val head  = Rand.lowerAscii
  val tail  = Rand.listOfN(Rand.int(99), Rand.lowerAscii)
  val input = head :: tail
  
  input.headOption == Some(head)
```

I find that workflow very satisfying. Start with a simple example, because I know how to do that, and then generalise it into something more powerful. And I would love it to be that easy, to simply make constants a little more fun and exciting without touching anything else.

Now admittedly, modern Scala PBT tools usually make this relatively straightforward. There's usually some amount of ceremony to go through (maybe an import or two, a new `extends` clause here and there...), which can be a little frustrating the first couple of times but most people presumably internalise the process sooner than later.

Transforming examples into randomised values can also be a little more work than I'd like - ScalaCheck, for example, expects implicit `Gen` instances, so you need to extract all the test case generation logic to some other location and be careful not to create implicit resolution conflicts. Not a _hard_ task, but one that can prove tricky for beginners, with some potentially mystifying results if the wrong `Gen` ends up being used.

So my workflow is definitely possible with most tools I've tried, but it's not as smooth as I'd like. I would prefer it to be very literally no work at all - because I'm lazy, yes, but also because testing is generally seen as something one must do but would rather not. I do not want to give developers the slightest excuse to give up on writing that test.


### Unifying properties and tests

Fortunately for us, the `Rand ?-> Boolean` encoding makes this absolutely trivial. We merely need to think of an example-based test as a property that ignores its `Rand` capability. With that framing, we don't even need specific code to support it!

Here's a naive implementation of the `test` function I was using above to run a test:

```scala
def test(desc: String)(body: Rand ?=> Boolean) =
  def loop(successCount: Int): Boolean =
    Rand:
      if body
        then if successCount >= 100 
          then true
          else loop(successCount + 1)
        else false

  loop(0)
```

This will attempt the test up to 100 times, aborting on the first failure. And it fully supports my workflow - in fact, all the examples above compile and work just fine with this `test` implementation!

### Test strategies

`test` here is obviously quite naive and limited. The number of attempts is hard-coded, there is no real strategy in looking for failing test cases, just brute force and luck... We can, and will, do much better than this: if I have the stamina for it, we will do things like:
- grow the size of test cases little by little (as done in [QuickCheck](https://dl.acm.org/doi/10.1145/351240.351266)).
- enumerate all small test cases (as done in [SmallCheck](https://dl.acm.org/doi/10.1145/1411286.1411292)).
- use probabilities to drive our exploration of the test space (as presented in [Inputs from hell](https://arxiv.org/pdf/1812.07525)).

We'll also make it easy to swap from one strategy to another, and to do so at runtime.

The point I'm maybe belabouring a little here is, _test strategies_ and _tests_ are not the same thing. `test` does not define a test, but a way of running the test it receives as a parameter. It's quite important we keep the two separated, as failing to do so would have far too high a cost in flexibility.

### Generative tests

Before going on to the next improvement, there's a point I believe needs to be made here. I don't think we're working with properties any longer. We're no longer manipulating predicates universally quantified on their inputs, but simple blocks of code that evaluate to success or failure, and may or may not include some randomness. I think it's more correct to call what we're doing _generative tests_, because calling it properties would be a little misleading.

Now, I know some of you are probably bothered by the current `test` implementation. We've all been trained to look for premature optimisation opportunities and to feel a little smug when we find low-hanging fruits, and there's a rather obvious one here, isn't there? If we pass a non-generative test (that is, one that doesn't rely on randomness) to `test`, it will still be executed 100 times, where once would suffice. Isn't that a little inefficient?

## Enhancing handlers

<a name="mutable-handlers"/> 
We could solve this optimisation problem quite simply if there was some way to know whether the `Rand` capability was used while running a test: if it wasn't, then further iterations won't change anything and we can simply stop there.

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

This is not very satisfying, however. Were we to ever write a new `Rand` handler (and I don't mean to spoil it for you but that's definitely happening), we'd need to duplicate this admittedly rather trivial feature. No, a much better solution would be to figure out how to enhance a handler by tacking new features on.

I've played a little in that design space, went back to my roots as an OOP programmer and tried subclassing handlers, but none of it was quite right. The best way I found was the most obvious (in hindsight only, perhaps): it's possible for handlers to store others and proxy calls to them (yes, I *am* using [Design Patterns](https://en.wikipedia.org/wiki/Proxy_pattern), so glad you noticed).

Here's how it would work for our needs, a handler that modifies an existing one to track whether or not `nextInt` was called:

```scala
def tracking[A](body: Rand ?=> A)(using Rand): A =
  var used = false
  
  given Rand = (max: Int) =>
    used = true
    Rand.int(max)

  body
```

If you look at its type, `tracking` produces an effectful computation - you'll need a `Rand` to run it. But when it does run, it will track the status of `nextInt`. You could call it like this, for example:
```scala
Rand:
  Rand.tracking:
    Rand.lowerAscii
```

Except - we keep track of whether or not `nextInt` was called, but we don't really expose that information, do we?

One approach - the first I tried, the silly one that was obviously never going to work, but this is a skill of mine, making all the mistakes so you don't have to - would be to expose the tracking handler as a type with some public `used` property. But if you think about it a little, isn't the entire point of capture checking to make this useless? Even if we were to do that, the handler would be scoped to the `Rand.tracking` block, and prevented from escaping by the compiler. It would expose `used`, but no one would be able to get their hands on it.

The solution I've come up with - I make it sound like some grand discovery but it really is just the obvious next step - is to change the type of `tracking` to ultimately not return an `A`, but some other type wrapping an `A` and the `used` value. Something like this (scoped to the `Rand` companion object):
<a name="Rand.Tracked"/> 
```scala
case class Tracked[A](value: A, used: Boolean)
```

We can then very easily update `tracking` to make use of it:
```scala
def tracking[A](body: Rand ?=> A)(using Rand): Rand.Tracked[A] =
  var used = false
  
  given Rand = (max: Int) =>
    used = true
    Rand.int(max)

  Rand.Tracked(body, used)
```

This gives us the ability to run some effectful computation and to know whether it called `nextInt`, which was the last bit we needed to complete our initial `test` implementation.

First, I like to extract the bit that declares all the handlers and runs an effectful computation from the main logic; it makes things, in my opinion, far more readable. Let's do that here by writing a function that runs a test:

```scala
def runTest(body: Rand ?=> Boolean): Rand.Tracked[Boolean] =
  Rand:
    Rand.tracking:
      body
```

Updating `test` to keep track of generative and non-generative tests is now straightforward:

```scala
def test(desc: String)(body: Rand ?=> Boolean) =
  def loop(successCount: Int): Boolean =
    runTest(body) match
      case Rand.Tracked(true, isGenerative) =>
        if isGenerative && successCount < 100 
          then loop(successCount + 1)
          else true
    
      case _ => false

  loop(0)
```

This implementation of `test` will run both generative and non-generative tests, while being clever enough to run the latter only once. When I first set out on this project, I didn't really think I'd solve this particular problem, and it was truly delightlful how a solution just sort of happened.

## Conclusion

I think we've achieved rather a lot here. We've solved two problems that matter to me - how cumbersome it is to deal with properties of different arities, and how annoying it can be to turn example-based tests into property-based ones. Our library now has a unified way of running things, and even automatically figures out wether a given test is generative or not.

Along the way, we've learned how to enhance handlers - something we'll be doing quite a bit of - and have hammered in the point that you could choose to ignore available capabilities - to pass in non-effectful computations were effectful ones are expected. This is no longer a mere, vaguely interesting theorical point: it's exactly how we manage to treat non-generative tests and generative ones as the same thing.

Our next task will be to make writing tests a little less cumbersome.
