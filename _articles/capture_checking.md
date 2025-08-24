---
title:  Hands on Capture Checking
layout: article
date:   20250824
code:   https://github.com/nrinaudo/hands_on_cc/blob/main/main.sc
---

## Introduction 

I gave a live coding session on capture checking at Scala Days 2025. Let's be honest: it was essentially a failure, mostly because I have very little live coding experience and woefully underestimated how long it'd take to go through the material. I was stopped maybe 10% in, much to my annoyance and that of Martin Odersky, who'd kindly agreed to be there and help with the questions I was likely to get. This article is a form of apology for my failure: at least the material is available somewhere!

The rest of this introduction is how the whole talk came about, because I find it entertaining, but it's also mostly irrelevant to the actual _content_ of the article. If you're interested in capture checking more than my life - why would you be?! - you should probably skip to <a href="#problem">the technical bits</a>.

I never really intended to give a talk on capture checking - or even study it, to be honest. Not for a long while, at least. Capture checking is still actively being worked on, and I hate aiming at a moving target, struggling to understand a concept just to find out it's outdated by the time I'm done.

But then I noticed something which captured (wink, nudge) my interest: whenever Martin would go on stage to talk about capabilities and how they will allow us to use a direct style of programming without losing any of the nice properties afforded us by continuation passing style or monadic style, he would invariably say something along the lines of _and of course for all this to work reliably we'll need capture checking, but that's really a detail_. _That's really a detail_. I've used that exact phrasing many times, and it was always either a grand act of self delusion, or me attempting to convince some manager to approve a project they really shouldn't approve. It was interesting to hear Martin use these words.

So I decided to try and see if I could understand what the fuss was all about. To give some context to that decision, I'd been travelling, having just left Tokyo and now finding myself in Hawaii because that's apparenly my life now, very jetlagged, my brain in one timezone, my body in another and they weren't talking with each other. It didn't feel unreasonable to start studying something where all the material was either in academic papers (I don't know about you, but my brain is _not_ wired to read those) or in documentation that was either outdated or a copy/paste of said academic papers or both, whose error messages were explicitly designed for the feature's implementers rather than its users and often read like an exercise in obfuscation... I can't say it was an easy task. But, about a week in, I came to the conclusion that I'd understood everything I needed to use capture checked libraries. Not write them, probably - some features are still a little terrifying, such as reach capabilities or capture set polymorphism - but good enough for the moment at least.

That's when I coincidentally received an email from one of the Krakow Scala User group organizers telling me they were having an event, and since I was going to be in town, why don't I give a talk, it's going to be very informal, there's only going to be a few of us, I should come, it'll be fun.

And I thought - I don't have slides. It usually takes me between 7 weeks and 7 months to write slides, I only had 7 days, that was clearly not going to happen, but maybe I could try live coding? I'm notoriously terrible at that (as evidenced by my Scala Days performance), but there was only going to be a few people, surely it'd be fine. I also thought that I didn't have a story for my explanation yet, and 7 days was clearly not going to be long enough for me to come up with one. I'd be travelling, working, hopefully sleeping at some point that'd be a nice change, there was no way I'd find the time. So - and this should tell you how jetlagged I was - I decided, why not improvise? If you've seen any of my talks, you know I don't improvise. I over-prepare if anything. But, I reasoned, there's only going to be a few of us, surely that'll be fine, what's the worse that could happen?

I'm glad you asked. I know precisely what the worse that could happen was, because it did happen. First, they were using a definition of _a few_ I was previously unaware of. _Quite a few_ was probably a better description - it was the largest meetup I'd ever attended. We even had people who didn't know Scala and had no intention of learning it show up, a little randomly. Also, Zainab and Martin. Two people whose opinion matters to me, whom I respect and am vaguely terrified of. Also also, Martin. Came up with the whole concept of capture checking, has his name on all the papers on the subject, spear-heading its development, knows everything there is to know on the topic... all statements, you'll notice, that emphatically do not apply to me. And yet _I_ was going to be on stage, explaining it all to him. You understand how I maybe felt trapped, a little. Luckily, Martin, noticing my discomfort and ever the gentleman, said it'd be fine, we'd both go on stage, I'd write the code, and he'd criticise it, correct my mistakes, explain things and give context for some of the more... exotic... design decisions. Great! I was going to have to do two things I'm notoriously bad at, live coding and sharing the spotlight.

Long story short, it went quite well, it was supposed to last 20 minutes but went on for an hour and a half (which should maybe have been a bit of a lesson...), and by the end of it everybody had learned something about capture checking. I certainly had. And Martin even submitted a PR a few days later which fixed a bunch of usuability issues we'd ran into while playing with the code.

After the talk, Martin came to me and said _this was fun, we should do it again sometime_. To which I answered _it really was, it's just such a shame that I was rejected from Scala Days or we could have given it there!_ - oh yes, an important thing to know for this story is that I'd just been rejected from Scala Days and wasn't at all feeling salty about it. Martin replied _we'll see about that_, and I guess we have!

The rest of this article, then, is a re-enactment of the talk Martin and I gave together in Krakow. Martin's obviously not writing this with me, which is your loss if I'm being honest because he's the charming one of our double act, but I'll do my best to make it worth your while.

<a name="problem"/>
## What problem are we solving?

Before we can start explaining what capture checking is and how it works, we must talk about the problem it's attempting to solve. And, really, we must start with what _capture_ means here - we're apparently checking for it, but what is it?

It's easier shown than explained:
```scala
val x = 1
def f = (y: Int) => x + y
```

In that code, `f` captures `x` - if we were to call `f` at some point in the future, then it would use `x`, even if it's no longer in scope. And that's fine, isn't it? I'm sure you've seen a lot of code like that, likely even wrote some yourself - it is, after all, how partial application works, and partial application is _good_! So capturing is not inherently bad.

But it can be, because it can lead to values escaping their intended scope. Here, let's refactor things to make it more obvious:
```scala
def createFun = 
  val x = 1
  (y: Int) => x + y
  
val f = createFun
f(2)
```

All I've done is move the creation of our capturing function inside `createFun`, to make it clearer that when `f` is applied later, it uses `x` entirely outside of its lexical scope, the body of `createFun`. But that's merely a more explicit version of what we were already doing before, there is nothing inherently wrong with it, it is in fact sometimes _good_ and desirable!

But sometimes not. Let's take a first example, the canonical example you'll find in every talk, paper, article... on capture checking: the _try-with-resource_ pattern. If, like me, you used to write Java for a living about... oh, 10 years ago? you probably remember how painful it can be to work with a resource. You need to acquire it, which may fail. Then work with it, which may fail, but if it does you need to make sure you release it before you allow yourself to fail. And what if the release itself fails? And then of course you must release it once you're done. It's all very messy and easy to get wrong, and you had to do it every single time. The _try-with-resource_ pattern makes it a lot nicer:

```scala
def withFile[T](name: String)(f: OutputStream => T): T =
  val out    = new FileOutputStream(name) // Resource acquisition
  val result = f(out)
  
  out.close() // Resource release.
  result
```

There's no error handling in there because it'd make the code much more complicated without really bringing anything to the point I'm trying to make, but: `withFile` takes the name of a file, a function that consumes an open stream on that file, and deals with the entire resource acquisition / release process.

Now what do you think happens when we write this:
```scala
val nasty = withFile("log.txt"): 
  out =>
    (i: Int) => out.write(i)

nasty(1)
```

This fails with a _stream closed_ exception, because the value returned by `withFile` is a function that captures a stream, and that stream gets closed _before_ the function is applied - before it's returned, even. This is one example of where you want to prevent a value from escaping its intended scope: it might be stateful, and people might end up interacting with it in a state in which they shouldn't.

It's not the only possible example however, and I want to give another quick one, if only because the _try-with-resource_ pattern is so prevalent in the litterature that it's starting to feel like that's all capture checking is good for. Imagine you're working with a secrets API - you may want, for example, to keep very tight control of a secret, only allowing callers to access them under very narrow conditions. You could write something a little similar to `withFile`:

```scala
type Secret = String

def withSecret[T](f: Secret => T): T
  val secret = "Celui qui lit ça est un !@#"
  val result = f(secret)
  
  result
```

`secret` is only available within the scope of `withSecret`, and `f` is presumably expected to, say, use it to open a connection to a database and return it. You expose the result of having used the secret, but not the secret itself.

That is, of course, unless you do something fiendishly clever such as:
```scala
val secret = withSecret(identity)
```

This clearly exposes the secret to the rest of the world. The problem here is not that `secret` is stateful, but that its semantics are that it shouldn't even exist outside of the scope of `withSecret`. And yet it can be captured and escape its intended scope.

This, then, is the problem we're trying to solve: not preventing value capturing altogether, but allowing code authors to prevent some _specific_ values from escaping.

## Capture sets

Scala being what it is, and its developers having a healthy obsession with types and the weird and wonderful things you can do with them, their solution relies on adding a new feature to the type system: the notion of _capture set_, which allows one to mark a type with all the values it captures.

Let's take a concrete example, it's a lot simpler than it sounds.

```scala
import language.experimental.captureChecking

class A

val a1: A      = A()
val a2: A^{a1} = a1
```

`A` is simply some class - I'll be creating lots of values to show the behaviour of the capture set, and a short, one letter name will help keep things relatively tight.

`a1` is just some value, there's really nothing special about it. Its only purpose is to be captured by `a2`.

`a2` is more interesting. It's essentially an alias for `a1`, which I hope it's clear for everyone that this means `a2` captures `a1`, or really that any value captures itself. The type of `a2` is maybe surprising: `A^{a1}`. The part after `^` is what we're interested in: `{a1}` is called the _capture set_ of `a2`, the set of values that `a2` captures. We'll be saying that `a2` _tracks_ or _captures_ `a1` which, in our context, more or less means that if `a2` escapes, so does `a1`.

And this would be lovely, except it doesn't compile:
```scala
(a1 : A) cannot be tracked since its capture set is empty
```

So in order for `a2` to track `a1`, `a1` must track something itself. That's a bit of a cyclical definition, isn't it? If we wanted `a1` to track another value, that one would also need to track something, and _that_ would need to track something, and round and round we go. Like with all recursive definitions, we need a base case to allow us to stop at some point, some sort of value that's always tracked and can thus be put in a capture set without any other requirement. That value is `cap`:

```scala
import caps.cap

val a1: A^{cap} = A()
val a2: A^{a1} = a1
```

You might be thinking that `cap` stands for _capture_ - I certainly did - but it turns out it stands for _capability_. `cap` is also known as the _root capability_. I find that a little unfortunate, as it seems to imply capture checking is limited in its impact to capabilities when it actually solves a larger problem.


There is something non-obvious but important to see here: `cap` is always considered to be tracked, but we're not really interested in preventing it from escaping - it's available in the global scope, so in a sense, it already has escaped! Or, if you prefer, since its scope is the global one, then it can never escape to a wider scope - there is by definition no such scope to escape to. Either way: we're not really interested in tracking `cap`. So saying that `a1` tracks `cap` really means that we want to prevent `a1` from escaping.

On the other hand, saying that `a2` tracks `a1` means that we're only interested in `a2` because of its relationship with `a1`. This may seem like a subtle distinction, and it's perfectly fine if its significance is a little lost on you at the moment (it took _days_ for me to see it), but we'll come back to this a little later.

### Fixing `withFile`

Before we go any further, let's confirm that capture sets solve our problem. Let's modify `withFile` to make it clear we do not want the resource to escape:
```scala
def withFile[T](name: String)(f: OutputStream^{cap} => T): T =
  val out    = new FileOutputStream(name) // Resource acquisition
  val result = f(out)
  
  out.close() // Resource release.
  result
```

If you're struggling to see the difference, it's merely in the type of `f`: it now takes an `OutputStream^{cap}` where it used to take an `OutputStream`. Which means that we would like the compiler to reject any `f` that captures the stream. Armed with that information, the compiler does in fact reject our previous flawed code, with a message that could maybe be slightly friendlier:

```scala
Found:    (out: java.io.OutputStream^?) ->? Int ->{out} Unit
Required: java.io.OutputStream^ => Int ->? Unit

where:    => refers to a fresh root capability created in value nasty when 
             checking argument to parameter f of method withFile
          ^  refers to the universal root capability

Note that reference out.type cannot be included in outer capture set ?
```

I'll be completely honest with you: I don't understand everything in there. But the gist of it is _`out` escapes its intended scope even though its type says it shouldn't_. Exactly what we were hoping to see.

### Fixing `withSecret`
Something similar happens with `withSecret` if we declare the secret as tracked:

```scala
def withSecret[T](f: Secret^{cap} => T): T =
  val secret = "Celui qui lit ça est un !@#"
  val result = f(secret)
  
  result
```

The error message is a lot clearer but, at least to me, a little frustrating:
```scala
Secret is a pure type, it makes no sense to add a capture set to it
```

This is the compiler telling us that since `Secret` is a primitive type (it's really a `String` in disguise) and thus cannot capture values, we're not allowed to track it. And while I can sort of see the argument, this is a little frustrating: sure, a `String` can never allow _another_ value to escape, but it can certainly escape itself, and sometimes this is what we want to prevent!

It's not an insurmontable problem, all we need to do to work around it is create a wrapper:
```scala
case class Secret(value: String)
```

But my point is that we shouldn't have to!

If we update the code to use our new `Secret` wrapper, we'll see that we get the same error message as with `withFile` - I'll not paste it again because it's essentially noise unless you're a capture checking expert. We can see that capture sets do fix the problem of value escaping.

The rest of this article is going to be about building the understanding required to explain _why_ this is. For the record, this is where I had to stop when I gave the live talk.

## Capture sets and subtyping

You may have noticed something a little odd in `withFile`, something that was bothering you but you couldn't quite put your finger on it. Let's take a closer look:
```scala
def withFile[T](name: String)(f: OutputStream^{cap} => T): T =
  val out: OutputStream = new FileOutputStream(name) // Resource acquisition
  val result            = f(out)
  
  out.close() // Resource release.
  result
```

I've updated the code slightly to add an explicit type ascription to `out`, which should help us see the problem.

`out` is of type `OutputStream`, and we pass it to `f`, which takes an `OutputStream^{cap}`. We're passing an `OutputStream` where an `OutputStream^{cap}` is expected. Those two types are distinct, and yet we can use one in place of the other.

The only mechanism we have in Scala to allow some type to be used where another one is expected is subtyping, which leads us to the conclusion that there must be a subtype relationship between `OutputStream` and `OutputStream^{cap}`.

The critical thing about capture sets, the one thing that must never happen, is for values to be dropped from them. If that were to happen, the value wouldn't be tracked anymore, and could escape, which is exactly what we want to avoid. On the other hand, _adding_ values to a capture set is fine - we're not loosing any information, merely adding more.

This is formalized by the subset rule: 
> If `c1` and `c2` are two capture sets such that `c1` is a subset of `c2`, then `T^c1` is a subtype of `T^c2`.

The rule is actually a little subtler than that (for example, it doesn't need to be `T` on both sides, provided the two types have the right subtyping relationship) but it will suffice for our purposes.

Let's see this with a more obvious example:
```scala
val a1: A^{cap} = A()
val a2: A^{cap} = A()
val a3: A^{a1}  = a1

a3: A^{a1, a2}
```

`a1` and `a2` are both tracked values. `a3`, being an alias of `a1`, tracks it. But we can ask for `a3` to be treated as if it _also_ tracked `a2`, because `{a1}` is a subset of `{a1, a2}`.

We couldn't, however, do something like dropping `a1` from the capture set:
```scala
a3: A^{a2}
```

This would yield the following error, which is entirely consistent with the subset rule we just described:
```scala
Found:    (a3 : A^{a1})
Required: A^{a2}
```

## Syntactic sugar

You may notice that we've been writing an awful lot of `A^{cap}`, something which must come up a lot since every tracked value ultimately starts by tracking `cap`. You may think that it's a bit syntax heavy and there could be syntactic sugar for it. And you'd be entirely right!

The logic behind the sugar comes from the way you pronounce `^`. Most people I asked answered _caret_, which is how I used to pronounce it too. Then I learned LaTeX and started calling it _hat_. It was later pointed out to me that a cap is a sort of hat, and so in the context of capture checking, it should probably be pronounced _cap_ - and therefore `A^{cap}` reads _A cap cap_. That's clearly a cap too many, so we can simply write `A^` instead of `A^{cap}`:

```scala
val a1: A^     = A()
val a2: A^     = A()
val a3: A^{a1} = a1

a3: A^{a1, a2}
```

There's also the possibility of having types you know will always be tracked to extend the `SharedCapability` trait, which will mark _all values_ of that type as tracked, but I won't do that here as we'll need a little more granularity than _track all the things!_ in order to show interesting properties.

### Function types

While on the topic of syntactic sugar, we now have different kind of arrows for functions:
- `A => B` means `Function[A, B]^` - a tracked function from `A` to `B`, also known as an _impure_ function.
- `A -> B` means `Function[A, B]` - a function from `A` to `B` that doesn't capture anything, also known as a _pure_ function.
- `A ->{a1, a2} B` means `Function[A, B]^{a1, a2}` - a function from `A` to `B` capturing values `a1` and `a2`.

This makes the Scala syntax elegant and consistent in a way that I find delightful. For example, `->` means a pure function at the type level, while at the value level, it means... tuple.

This might seem like a somewhat questionable design decision, but there's a reason for it. What you must remember - and this is important, as it explains a lot about Scala as a language; some people say it explains the very existence of Scala - what you need to remember is that Martin and his team are not above a little, let's call it creative obfuscation for the sake of entertainment. They're the people who merged significant whitespace, for example, and that's always good for a laugh.

On a more serious note, there's another inconsistency that irritated me - not quite as bad as the arrow thing, which is obviously there for backwards compatibility, but still, it offended my need for consistency.

The old way of declaring non-function types, such as `Int`, now means _`Int`, not tracking anything_. The old way of declaring function types such as `Int => Int`, however, now means _`Int => Int`, tracking `cap`_. This frustrated me for a while until, one sleepless night as I lay in bed thinking of higher order functions (we all do that, right? That's a perfectly normal, healthy thing to do), I realised there was a good reason to make that design choice.

In order to explain this, I'm going to try and implement two versions of a higher order function, `map`, one taking a pure function and one taking an impure one, and see how they behave. For that, I'll need a pure function, and one which tracks something:

```scala
val a1: A^ = A()

val pure    : Function[Int, Int]      = _ + 1
val tracking: Function[Int, Int]^{a1} = pure
```

The first thing to note in that code is that I'm explicitly ignoring syntactic sugar and using the `Function[A, B]` type. The point is to study what happens if `=>` means pure or impure functions, so I want to be very explicit about what we're manipulating.

The second, less critical thing this code shows is the subset rule again: `pure`'s capture set is a subset of `tracking`'s, and therefore we can assign `pure` to `tracking`.

Now, let's imagine that `=>` means pure functions, and write a `map` function that only takes pure functions:
```scala
def pureMap(f: Function[Int, Int]) = 
  List(1, 2, 3).map(f)
```

This is what happens if you try to apply `pureMap` on `pure` and `tracking`:
```scala
pureMap(pure)     // List(2, 3, 4)
pureMap(tracking) // Found Int ->{a1} Int, required Int -> Int
```

The first one is no surprise: we're passing a `Function[Int, Int]` where a `Function[Int, Int]` is expected, of course this'll work.
The second, however, is more annoying. We're passing a function with a non-empty capture set where a pure function is expected: this cannot work, as the subtyping relationship is the wrong way around. Which means that, if `A => B` meant pure function from `A` to `B`, we would need two different `map` implementations: one for pure functions, and one for tracking ones. Can you imagine the amount of code that'd need to change in the standard library? the sheer _annoyance_ of having to write two versions of every higher order combinator? (if you're feeling aggravated just thinking of that latter one, bear in mind that this is very much the choice you make when you decide to work with monads - `traverse` and `traverseM` anyone?).

Let's now try the same thing, but assuming that `A => B` means `Function[A, B]^`:
```scala
def impureMap(f: Function[Int, Int]^) = 
  List(1, 2, 3).map(f)
  
impureMap(pure)     // List(2, 3, 4)
impureMap(tracking) // List(2, 3, 4)
```

This is much more reasonable, isn't it? if `=>` stands for impure functions, then we can pass both pure and impure functions where an `=>` is expected, and precisely no code needs to be rewritten or duplicated. When put that way, this seems like a very reasonable design decision, even if it's not entirely consistent with others.

## Tracking transivitity

Something you may not have realised happened in our previous example, and _really_ did my head in when I noticed: `impureMap(tracking)` compiled. Why?! `impureMap` takes a `Function[Int, Int]^`, `tracking` is of type `Function[Int, Int]^{a1}`, the capture sets are disjoint and therefore the subset rule doesn't apply, how is the latter a subtype of the former?

That is due to another rule governing how capture sets impact subtyping: the _transitivity_ rule. We all know what a transitive relation is - if `a1` relates to `a2` and `a2` to `a3`, then `a1` relates to `a3`. Let's see how that translates to capture sets:

```scala
val a1: A^     = A()
val a2: A^{a1} = a1
val a3: A^{a2} = a2
```

`a3` tracks `a2` which in turn tracks `a1`, therefore `a3` tracks `a1`. Which the compiler takes to mean the following is ok:
```scala
a3: A^{a1}
```

Which, if you don't pay too much attention, seems perfectly reasonable - of course `a3` tracks `a1`! But... do you see it? Do you see what took me something like 2 days to work through? (alright, I was very jetlagged, leave me alone).

`a2` was dropped from `a3`'s capture set. A thing we said should never, ever happen, as it would allow the dropped value to escape.

This is the point I was making earlier about the different semantics of `^{cap}` and `^{a1}`. If `a1` is tracking `cap`, it means we want to make sure `a1` never escapes. But if `a2` tracks `a1`, what we're really saying is that we want to prevent `a1` from escaping, and we're tracking `a2` incidentally, merely because allowing `a2` to escape also means allowing `a1` to escape.

From that perspective, it's perfectly ok to drop `a2` from the capture set _so long as `a1` is still in it_. In that context, we're still preventing `a1` from escaping, which is really all we care about. Which means that the compiler is perfectly happy to treat `A^{a1}` as a subtype of `A^{a2}`.

This explains why it's ok to pass a `Function[Int, Int]^{a1}` where a `Function[Int, Int]^{cap}` is expected: `a1` tracks `cap`, so `Function[Int, Int]^{a1}` is, by transitivity, a subtype of `Function[Int, Int]^{cap}`.

This, in turns, tells us that my initial description of `=>` as _a tracked function_ was not the right perspective: while it's not technically incorrect, what `A => B` really means is a function from `A => B` that can capture _anything_. Because of the transitivity rule, you can pass any capturing function where an `=>` is expected, which makes the term _impure_ a little less odd.

## Capturing values

So far, we've seen what a _capture set_ was, and how it interacted with subtyping. We've not really thought about how values actually make it to the capture set yet, and will need to take a look at that now.

### Capturing functions

We'll start with functions, since this was the core of our `withFile` and `withSecret` examples, and is suprisingly straightforward.

First, a very simple non-capturing function:
```scala
val f: Int -> Int = 
  x => x + 1
```

`f` is very simple, taking an `Int` and adding `1` to it. You might think that it captures `x`, but there's a subtle difference between that and what we saw before: in all our previous examples, functions captured _free variables_ - variables that were declared oustide of the functions' scope. `x` here is not a free variable, since it's declared in the function itself; it can therefore not be captured by `f`, because the body of `f` is its intended scope.

If we were to interract with a free, tracked variable in any way, however, this would change:


```scala
val a1: A = A()

val f: Int ->{a1} Int = 
  x =>
    println(a1)
    x + 1
```

`f` captures `a1` by the simple act of referring to it in its body. And since `a1` is tracked, we must keep make sure we know what captures it: the compiler must consider the type of `f` be `Int ->{a1} Int`. 

This should feel fairly intuitive: when a function captures a tracked value, that value must appear in the function's capture set.

### Capturing classes

Classes are a little more subtle, but still relatively easy to understand.

Let's declare a very simple wrapper class for `A`:
```scala
case class Wrapper(value: A)
```

We'd like to see what happens when we pass our tracked `a1` to `Wrapper`'s constructor - surely this will have an impact on the capture set:
```scala
val w = Wrapper(a1)
```

Well, this first has an impact on the validity of our program. We're passing an `A^` where an `A` is expected. The subtyping relation is in the wrong direction for this to be acceptable, and our code fails to type check:
```scala
Found:    (a1 : A^)
Required: A
```

To get around this, we'll need to update `Wrapper` to take a tracked type:

```scala
case class Wrapper(value: A^)
```

We already had all the tools we needed to reach the same conclusion as the type checker, but this is still reassuring. We cannot use classes to drop tracked values.

Having code that compiles, we can now look at `w`'s capture set:

```scala
val w: Wrapper^{a1} = Wrapper(a1)
```

Since `w` holds on to a tracked value, the compiler is able to infer that it captures it, and therefore demands this be reflected in its type. If you think about it, this is a very similar mechanism to the one used for capturing functions.

Here's an interesting thought experiment: what if we created a non-tracked `a2` and passed it to `Wrapper.apply` - do you think that should compile? And if so, what would be the result's type?

## Capture sets and type parameters

The last interesting (and rather important) case we have to deal with is what happens in the presence of parametric polymorphism. To demonstrate this, we'll simply make `Wrapper` polymorphic on the value it wraps:

```scala
case class Wrapper[T](value: T)
```

This is where things get a little subtle. Here's what happens when we pass the tracked value `a1` to it:
```scala
val w: Wrapper[A^{a1}] = Wrapper(a1)
```

Note the type. I don't know if it surprises you, but it certainly did me: `w` itself doesn't capture anything! Its `value` field, however, does, which has interesting consequences. In order to make them a little more obvious, I'll add a second, non parametric field to `Wrapper`:
```scala
case class Wrapper[T](value: T, i: Int)

val w: Wrapper[A^{a1}] = Wrapper(a1, 1)
```

This does not change `w`'s type in any way, but allows us to see why `w` itself is not tracking. Look at the following code:
```scala
val f: Int -> Int = 
  x =>
    println(w.i)
    x + 1
```

We are interacting with `w.i` inside of `f` - with the non-tracked field of `w`. We're not at all touching `w.value` which, in our example, tracks `a1`: there is therefore no reason for `f` to capture `a1`. If `w` had been of type `Wrapper[A]^{a1}`, the type checker would have come to a different, unnecessarily restrictive conclusion.

On the other hand, interacting with `w.value` yields the desired result:

```scala
val f: Int ->{a1} Int = 
  x =>
    println(w.value)
    x + 1
```

_That_ causes the type checker to correctly decide that `f` captures `a1`, and to reflect it in its capture set.

This is known as _capture tunneling_, where capture sets of type parameters are not reflected on the containing classes. This allows us to manipulate polymorphic classes without worrying about capture sets but still being able to rely on the capture checker to spot any undesirable escape, and is quite important to keeping the syntactic cost of capturing checking low.

## Catching undesired escapes

We now have all the knowledge we need to see why capture sets allow the compiler to reject our `nasty` example.

```scala
val nasty = withFile("log.txt"): 
  out =>
    val f = (i: Int) => out.write(i)
    f
```
I've reworked it just a little to have an explicit function value, `f`, rather than a literal one. This will allow us to think about its type, which, you should do that right now. What do you think the type of `f` is?

Here's the answer:
```scala
val nasty = withFile("log.txt"): 
  out =>
    val f: Int ->{out} Unit = i => out.write(i)
    f
```
`f` captures `out`. Which is problematic, isn't it? Since `nasty` takes the type of whatever is returned by `withFile`, it would make it an `Int ->{out} Unit`, but `out` doesn't exist in `nasty`'s scope. That type doesn't make any sense.

Fortunately, the type checker has a mechanism for just this, called _avoidance_ (a term I'd never heard of until I looked into capture checking but that apparently has been around for ever).

Let's take a concrete example of that, with the usual example of animals, cats and dogs:
```scala
trait Animal

def createAnimal =
  case class Cat(lives: Int) extends Animal
  
  Cat(9)
  
val cat: Animal = createAnimal
```

While `createAnimal` returns a `Cat`, that is not a type that exists outside of its scope. The compiler will therefore widen it until it finds one that can be used in the parent's scope, where _widening_ is the process of attempting less and less precise types (supertypes) until an acceptable one is found. In our case, that yields `Animal`.

This is exactly what happens with `nasty`: the compiler will look for a supertype of `Int ->{out} Unit` that's known outside of the scope of `withFile` - and by the subtyping rules we've defined, lands on `Int ->{cap} Unit`.

You might wonder how that helps us - sure, our function now captures arbitrary values, but why does that allow the compiler to reject our code? The answer to that is maybe a bit anticlimactic: because of a bespoke heuristic which causes the type checker to treat any type parameter inferred to something capturing `cap` as an escaped value. Which makes sense, if you think about it: if a type parameter is inferred to capture `cap`, it likely got there through avoidance. Avoidance kicks in when some type is not known outside of the current scope, which, for a capture set, means we're attempting to refer to a value outside of its intended scope - which is exactly what escaping is.

In our scenario, here's `withFile`:
```scala
def withFile[T](name: String)(f: OutputStream => T): T =
  val out    = new FileOutputStream(name) // Resource acquisition
  val result = f(out)
  
  out.close() // Resource release.
  result
```

In the case of `nasty`, this tells the compiler that `T` is equal to `Int ->{cap} Unit`, which runs afoul of its heuristic for catching undesirable escapes. This is how the compiler knows to reject `nasty`, because its type clearly describes an escaped value.

## Conclusion

We've seen what capture checking was: a mechanism for preventing specific values from escaping their intended scope. We've seen it worked by indexing types with the set of values they capture, a few updated subtyping rules, and a very simple heuristic relying on existing features of the Scala type system.

It may have felt a little overwhelming - there are a lot of moving pieces - but on the whole, most people won't really need to understand any of this. In my experience, the vast majority of the code I've written with capture checking was exactly the code I'd have written without it, except a few times when I'd get error messages from the compiler telling me I was doing something I shouldn't. The experience has been quite pleasant (except when attempting to make sense of said error messages, which I expect to become friendlier in the future).

My purely subjective opinion, then, is that capture checking is almost a non-event: most developers won't really need to learn about it (or even read this article), and it will not add a massive cognitive cost to learning Scala. It will, in fact, make the language safer _and_ enable the widespread use of _capabilities_, which I've also played with quite a bit and feel reduce the complexity of the language rather drastically.

I'm excited about capture checking becoming a standard feature of the language, which should be fairly soon - after all, the standard library is now fully annotated with capture sets where needed (which was merged a few hours before I took the stage, obviously not a source of stress in any way...)
