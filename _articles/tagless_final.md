---
title:  A "quick" introduction to Tagless Final
layout: article
date:   20230523
---

For the past couple of weeks, I've had people ask me, or say very confusing things, about _Tagless Final_. This is a subject that the Scala community seems to be absolutely fascinated with, for reasons that aren't quite clear. And, weirdly, the conclusions it seems to have reached seem only vaguely related to what I understand a tagless final encoding to be.

The purpose of this article is to be the minimum amount of information I feel one needs to understand what this whole thing is about. Should you want a more in-depth look, I've given [an unreasonably long talk]({{ site.baseurl }}/talks/dsl_tagless_final.html) on the subject, or you could go directly to the source and read Oleg Kiselyov's [lecture](https://okmij.org/ftp/tagless-final/course/lecture.pdf).

## Problem statement

We're trying to model a very simple _Domain Specific Language_ that, for the time being, allows us to express:
- integer literals.
- addition of two integers.

For example: `1 + (2 + 4)`.

Admittedly not the most exciting thing in the world, but its simplicity is a feature as it allows us to focus on what actually matters: how to encode this DSL.

We must also be able to provide multiple interpreters. In this article, we'll focus on:
- pretty-printing: take an expression and make it human readable.
- evaluation: compute the result of an expression.

## Initial encoding
### Naive implementation

Anyone familiar with _Algebraic Data Types_ should immediately think of a sum type where each branch represents an element of syntax:

```scala
enum Exp:
  case Lit(value: Int)
  case Add(lhs: Exp, rhs: Exp)
```

An expression can either be a literal or an addition, and an addition is recursive: its operands can be expressions themselves.

The recursive nature of `Add` is important, as without it we would not be able to write such "complex" expressions as:

```scala
// 1 + (2 + 4)
Add(Lit(1), Add(Lit(2), Lit(4)))
```

### Interpreters
This encoding allows us to write interpreters by simple natural recursion. For example, pretty-printing:

```scala
def print(exp: Exp): String = exp match
  case Lit(value)    => value.toString
  case Add(lhs, rhs) => s"(${print(lhs)} + ${print(rhs)})"
```

Evaluation follows the exact same pattern:

```scala
def eval(exp: Exp): Int = exp match
  case Lit(value)    => value
  case Add(lhs, rhs) => eval(lhs) + eval(rhs)
```


Encoding our DSL as a straightforward ADT is known as an _initial encoding_, and is a perfectly fine answer to our original problem.

### The Expression Problem
This encoding does have one flaw, however: adding new elements to our DSL breaks existing interpreters. Let's say that we wanted to add multiplication; we'd need to modify `Exp`:

```scala
enum Exp:
  case Lit(value: Int)
  case Add(lhs: Exp, rhs: Exp)
  case Mult(lhs: Exp, rhs: Exp)
```

Existing interpreters do not know about `Mult` and cannot possibly handle it - it didn't exist when they were written. Every single one of them will break one way or another when presented with expressions containing multiplications.

This, for example, will result in a runtime `MatchError` failure:

```scala
// eval(1 * 2)
eval(Mult(Lit(1), Lit(2)))
```

This is known as [the Expression Problem](https://homepages.inf.ed.ac.uk/wadler/papers/expression/expression.txt): finding a statically checked encoding for a DSL that allows us to add both syntax (such as multiplication) and interpreters (such as pretty-printing) without breaking anything. I'm paraphrasing somewhat, but you get the general idea.

I think the origin of the name is expressed in this quote:
> Whether a language can solve the Expression Problem is a salient indicator of its capacity for expression.

Which, to paraphrase again, means that the Expression Problem is a test of a language's expressivity.

Our encoding clearly does not solve that problem, since adding syntax breaks existing interpreters. Let's see if we can fix this.

## Final encoding
### Modeling with functions
The core intuition behind a final encoding is that instead of using ADTs, we should use functions to encode expressions. I'm not entirely sure how this came about, although one way to get there is to consider that adding elements to an existing DSL can be seen as taking two DSLs, the old one and a new one with all the syntax we want to add, and compose them to form a third, richer one. When looking at things that way, it's clear that ADTs aren't going to be a great tool: they do not compose. Functions, on the other hand, famously do.

So we might get a little bit further if we represented our DSL as functions. Let's try that.

```scala
def lit(value: Int)         = value
def add(lhs: Int, rhs: Int) = lhs + rhs
```

This works fine, and even looks strikingly similar to our initial encoding at use site:

```scala
// 1 + (2 + 4)
add(lit(1), add(lit(2), lit(4)))
```

We've defined our first DSL as functions. Let's define a second one that adds, say, multiplication:

```scala
def mult(lhs: Int, rhs: Int) = lhs * rhs
```

Since all these functions work directly with the result of evaluating an expression, `Int`, they can work together without any particular ceremony:

```scala
mult(lit(1), lit(2))
```

This is known as a _final_ encoding. One of its particularities is that we're working directly with interpreted values: look at `lit`, `mult`, ... they're all taking and returning `Int`. This makes things easy, but is also a major flaw in the encoding.


### Supporting multiple interpreters

The issue with this naive final encoding is that in our creative enthusiasm, we've somewhat lost track of our goal. Our encoding works fine - if you're not interested in writing multiple interpreters. Since our functions immediately evaluate the corresponding expression, we have a single interpreter: the evaluator.

We're trying to solve the Expression Problem, which means writing multiple interpreters without breaking anything, yet our encoding cannot write more than one, breaking changes or not. There's clearly a flaw in our master plan. We need to find a way to write multiple interpreters.

The intuition, here, is that since we're working with functions, the only way to tell them how to interpret some data is to pass an interpreter as a parameter.

Such an interpreter must be able to handle every statement of our language. Something like this, then:

```scala
trait ExpSym:
  def lit(i: Int): ???
  def add(lhs: ???, rhs: ???): ???
```

That `Sym` suffix comes from the fact that this is often called a symantic, a truly dreadful mot-valise of syntax and semantic: the type describes the syntax of our language, values of that type its semantics.

The problem is all these `???` types. It's not necessarily obvious what should go there.

First, the return values: since they're the result of interpreting an expression, they should be of whatever type the interpreter returns (the _interpreted type_ for the rest of this document). This needs to be parametric: a pretty-printer evaluates to a `String` and an evaluator to an `Int`, we clearly need to make this configurable. This gives us:

```scala
trait ExpSym[A]:
  def lit(i: Int): A
  def add(lhs: ???, rhs: ???): A
```

For the remaining holes, remember that we're working on a final encoding: one in which we're manipulating the interpreted value rather than an intermediate representation. So, `add` will take the result of interpreting the nested expressions - and that is `A` as well.

```scala
trait ExpSym[A]:
  def lit(i: Int): A
  def add(lhs: A, rhs: A): A
```

In case this is not perfectly clear, the easiest way to see why these types line up is to write an actual expression:

```scala
// 1 + (2 + 4)
def exp[A](sym: ExpSym[A]): A =
  import sym.*
  add(lit(1), add(lit(2), lit(4)))
```

I've written `exp` as a method rather than a function because it's polymorphic, and support for polymorphic functions is either absent (Scala 2) or saddled with a rather unfortunate syntax (Scala 3).

Now look at the `add(lit(1), ...)` part. It should help see why both our sub-expressions and our interpreted values share a type.

We now have an encoding for our DSL and an expression of it, all we need to confirm that it works is an actual interpreter. Let's do pretty-printing for now, which is just a matter of setting the interpreted type to `String` and filling in the blanks:

```scala
val print = new ExpSym[String]:
  def lit(i: Int)                   = i.toString
  def add(lhs: String, rhs: String) = s"($lhs + $rhs)"
```

After all this, pretty-printing our expression is a simple method application:

```scala
exp(print)
// val res0: String = (1 + (2 + 4))
```

### Syntactic sugar

I'll be the first to admit that the whole thing is a little bit wordy. We can make this better by:
- declaring helper functions for `lit` and `add`, so that we no longer need to import `sym.*`.
- making `ExpSym` implicit, to avoid having to pass it explicitly.

And yes, this essentially means we're making `ExpSym` into a type class with dedicated syntax.

This gives us the following:

```scala
def lit[A](i: Int)(using sym: ExpSym[A]): A =
  sym.lit(i)

def add[A](lhs: A, rhs: A)(using sym: ExpSym[A]): A =
  sym.add(lhs, rhs)
```

These helpers allow us to rewrite our `exp` method in a way that is somewhat more pleasant:

```scala
// 1 + (2 + 4)
def exp[A: ExpSym]: A =
  add(lit(1), add(lit(2), lit(4)))
```

Finally, we need to make our pretty-printer implicit (to turn it into an instance of type class `ExpSym`, if you want to be pretentious about it):

```scala
given ExpSym[String] with
  def lit(i: Int)                   = i.toString
  def add(lhs: String, rhs: String) = s"($lhs + $rhs)"
```

Having done all that, calling an interpreter gets a little easier and, I feel, quite a bit more pleasant:

```scala
exp[String]
```

I particularly like this syntax because it really looks like we're manipulating a polymorphic value. `exp` is a value which changes depending on the type you want to see it as. Nice.


### The Expression Problem

We now have a less naive final encoding that allows us to support multiple interpreters. If this feels like a lot of work to achieve exactly the same thing as our initial encoding, that's absolutely fair. But we've gone through all this trouble because we had the intuition it would solve the Expression Problem, and it is now time to confirm this intuition.

Let's try to add multiplication to our final-encoded DSL. Remember how I mentioned, earlier, that this could be seen as composing two distinct DSLs? This is exactly what we're going to do, by making multiplication its own dedicated DSL.

As we've seen, declaring a new DSL is merely a matter of declaring a \*sigh\* symantic for it, as well as some syntactic sugar because we're not animals.

```scala
trait MultSym[A]:
  def mult(lhs: A, rhs: A): A

def mult[A](lhs: A, rhs: A)(using sym: MultSym[A]): A =
  sym.mult(lhs, rhs)
```

We can then easily write a pretty-printer for it:

```scala
given MultSym[String] with
  def mult(lhs: String, rhs: String) = s"($lhs * $rhs)"
```

This is where all our work pays off: we can now easily compose `MultSym` and `ExpSym`. All we need to do is ask to have an implicit interpreter for both DSLs in scope, and everything works out:

```scala
// (1 + (2 + 4)) * 2
def exp[A: ExpSym: MultSym]: A =
  mult(add(lit(1), add(lit(2), lit(4))), lit(2))
```

If it's not obvious why this should work, walk through it:
* you're allowed to call `mult` because there's an implicit `MultSym` in scope.
* this takes two values of type `A`.
* you're allowed to call all the other functions (`lit`, `add`...) because there's an implicit `ExpSym` in scope.
* they all return values of type `A`.

Everything either takes or returns `A`s, which makes it pleasantly easy for all types to line up.

The call-site is exactly the same as before:

```scala
exp[String]
```

And we've done it: we've added syntax to our DSL without breaking any pre-existing code. I hope it's clear that we can also add interpreters without breaking anything, since that's merely a matter of writing both an `ExpSym` and `MultSym`.


### Manipulating values of our DSL

There's a major flaw in our implementation though: it does not allow us to manipulate expressions of our DSL. All we can do is interpret them - we cannot, for example, pass them to other functions, or return them from functions. This is because we've declared them as methods, which are not first-class citizens.

In theory that shouldn't be much of an issue, because the compiler can mostly turn methods into functions in a pinch, and those *are* first-class citizen. In practice, unfortunately, it won't quite work out because our methods are polymorphic.

If you're working with Scala 2, things are not great. Scala 2 does not support polymorphic functions. You could keep working with methods, which drastically reduces the usefulness of a final encoding (expressions not being values means you cannot, say, parse them from text files), or you could write a lot of scaffolding to simulate polymorphic functions. The latter is definitely possible, but it's not fun - nor is it the topic of this article. I shan't be doing that here.

If you're working with Scala 3, things are *a little* better, because Scala 3 does support polymorphic functions. I encourage you to play with this yourself, and maybe, I don't know, to think about ways of encoding an expression in JSON and back to an in-memory representation. It won't be pleasant, but it *will* be enlightening.

## Higher-order languages

We've talked about the distinction between initial and final encodings. We still need to tackle the _tagless_ part. For this, we must consider a _higher-order language_: one where evaluating an expression might yield more than one type.

For that, we'll take our existing DSL, and add the ability to compare two numbers for equality. For example: `(1 + 2) = 3`.

### Tagged initial encoding

As we've seen, an initial encoding is simply a confusing name for _using an ADT_. Here's what an ADT of that new DSL might look like:

```scala
enum Exp:
  case Lit(value: Int)
  case Add(lhs: Exp, rhs: Exp)
  case Eq(lhs: Exp, rhs: Exp)
```

So far so good, we can represent expressions of our DSL as values. We can also fairly easily write a pretty-printer for them:

```scala
def print(exp: Exp): String = exp match
  case Lit(value)    => value.toString
  case Add(lhs, rhs) => s"(${print(lhs)} + ${print(rhs)})"
  case Eq(lhs, rhs)  => s"(${print(lhs)} = ${print(rhs)})"
```

Evaluation, on the other hand, is problematic. First, how do we type it? an expression might yield an integer (`Add` and `Lit`) or a boolean (`Eq`). And second, how do we implement `Add`, since we have no guarantee that both operands yield integers?

```scala
def eval(exp: Exp): ??? = exp match
  case Lit(value)    => value      // Returns Int
  case Add(lhs, rhs) => ???
  case Eq(lhs, rhs)  => lhs == rhs // returns Boolean
```


We could toy with the idea of using `Any` and runtime type checks, but I'd rather not. First, I still have some pride left. Second, we know it won't solve our problems: if we have to resort to runtime type checks, this by definition means that we're not checking it statically, a requirement for a solution to the Expression Problem.

Instead, we're going to use a Scala 3 goodie, union types. If you're in Scala 2 world, replace that with a sum type, it's slightly less pleasant but works just as well.

A union type allows us to say that a type is one of various alternatives; In our case, `Int` and `Boolean`. It's all checked statically, which is exactly what we want.

Here's a possible implementation:

```scala
def eval(exp: Exp): Int | Boolean = exp match
  case Lit(value)    => value
  case Add(lhs, rhs) => (eval(lhs), eval(rhs)) match
                          case (left: Int, right: Int) => left + right
                          case _                       => sys.error("Type error")
  case Eq(lhs, rhs)  => eval(lhs) == eval(rhs)
```

This is known as a _tagged initial_ encoding. The _tagged_ part comes from the fact that `Int | Boolean`, a _type tag_, is used to keep track of what we're working with. It's not a very pleasant encoding.

The `Add` case, in particular, is... well, it's horrifying. Exceptions, awkward pattern matches... the stuff of nightmares. Keen-eyed readers will notice that I've actually made this less unpleasant than it ought to be, by having the `Eq` case work in scenarios where it shouldn't, and there should be another awkward pattern match there.

This is a symptom of a deeper problem that we've been ignoring, consciously or not: our ADT allows us to write ill-typed exceptions, such as `(1 = 2) + 3`. The solution to that will be a _tagless initial_ encoding.

### Tagless initial encoding

The problem we must solve is that, when `Add`-ing two expressions, we have no way of knowing if they'll evaluate to integers.

To work around this, we'll need to keep track of the type of an expression's _normal form_: what evaluating it will yield. The simplest way of achieving this is to make it a type parameter:

```scala
enum Exp[A]:
  case Lit(value: Int) extends Exp[Int]
  case Add(lhs: Exp[Int], rhs: Exp[Int]) extends Exp[Int]
  case Eq(lhs: Exp[Int], rhs: Exp[Int]) extends Exp[Boolean]
```

Pay special attention to `Add`: it's now impossible to create such an expression with non-numerical operands. We've made it so that our values *must* be well typed, and we can safely evaluate them without jumping through all the type-checking hoops that the tagged initial encoding required:

```scala
def eval[A](exp: Exp[A]): A = exp match
  case Lit(value)    => value
  case Add(lhs, rhs) => eval(lhs) + eval(rhs)
  case Eq(lhs, rhs)  => eval(lhs) == eval(rhs)
```

For people familiar with these things, `Exp` is now a _Generalised Algebraic Data Type_. And, really, that's what _tagless initial_ means: GADT. Which unfortunately means that it only sort of works in Scala 2, whose implementation of GADTs is... well, it's debatable whether it's there at all.

This is, by far, my favourite encoding. It's terse, statically checked, interpreters are simple natural recursions... but it does not solve the Expression Problem. As we've seen earlier, initial encodings, tagged or not, do not.

If solving the Expression Problem is something we care about, we need to go back to final encodings and truly gaze into the abyss.

### Tagless final encoding

Here's a naive final encoding of our new DSL:

```scala
trait ExpSym[A]:
  def lit(i: Int): A
  def add(lhs: A, rhs: A): A
  def eq(lhs: A, rhs: A): A
```

If you think about it a little, you should see that this suffers from the same problem we encountered earlier: we cannot write a well-type evaluator, and will need to do some runtime type analysis.


I'm going to skip the _tagged final_ encoding, because it's frankly useless. We've seen that tagged encodings allowed us to represent illegal values, and I'm not going to spend any time on a solution that we *know* is inherently flawed.

Instead, let's consider what _tagless_ would mean for a final encoding. We need to somehow keep track of two things: the expression's normal form, and the interpreted type.

A naive implementation of this would be to consider that since we're tracking two types, we need two type parameters - something like `ExpSym[N, A]` (where `N` stands for normal form). But we'd immediately hit a dead end: how would you implement `add`?

```scala
def add(lhs: ???, rhs: ???): ???
```

What could we put in the `???` bits? We need it to be both:
- the interpreted type, because this is what's passed to `add` in a final encoding.
- the expression's normal form, to confirm that both operands are numeric.

What we want, really, is to parameterise the interpreted type by the expression's normal form. I realise that this is not the friendliest of sentences, so let's see some code instead:

```scala
def add(lhs: F[Int], rhs: F[Int]): F[Int]
```

Here, `Int` is the expression's normal form, and `F` the interpreted type. This is the trickiest part of this whole business to understand, so don't worry if it doesn't quite click yet. Let's see where that thought takes us, it should help things fall into place.

Now that we've decided to represent an interpreted type as a type parameterised on an expression's normal form, let's write `ExpSym` accordingly:

```scala
trait ExpSym[F[_]]:
  def lit(i: Int): F[Int]
  def add(lhs: F[Int], rhs: F[Int]): F[Int]
  def eq(lhs: F[Int], rhs: F[Int]): F[Boolean]
```

Note how it's now impossible for `add` to take things that do not evaluate to a number. Our expressions are back to being well-typed.

This is a bit abstract, so let's write a concrete \*sigh\* symantic to try and wrap our heads around it.

Take pretty-printing, for example: we know the interpreted type must be `String`. This is problematic, because `String` is not parametric, and we need a type parameter to keep track of an expression's normal form. This is easily worked around with some relatively common type trickery:

```scala
type Pretty[A] = String
```

With this, we can write our interpreter:

```scala
given ExpSym[Pretty] with
  def lit(i: Int)                             = i.toString
  def add(lhs: Pretty[Int], rhs: Pretty[Int]) = s"($lhs + $rhs)"
  def eq(lhs: Pretty[Int], rhs: Pretty[Int])  = s"($lhs = $rhs)"
```

And this all sort of makes sense, doesn't it? every expression keeps track of its normal form, so we can only compose them when it makes sense, but it all ultimately evaluates to a `String`. Note that I could have replaced all the `Pretty[...]` in that snippet with `String` and the compiler would have been fine with it, but I feel this way is clearer.


As before, we'll need a little syntactic sugar to make this less unpleasant to work with:

```scala
def lit[F[_]](i: Int)(using sym: ExpSym[F]): F[Int] =
  sym.lit(i)

def add[F[_]](lhs: F[Int], rhs: F[Int])(using sym: ExpSym[F]): F[Int] =
  sym.add(lhs, rhs)

def eq[F[_], A](lhs: F[A], rhs: F[A])(using sym: ExpSym[F]): F[Boolean] =
  sym.eq(lhs, rhs)
```

And, armed with all that, we can start writing actual expressions:

```scala
// 1 + (2 + 4)
def exp[F[_]: ExpSym]: F[Int] =
  add(lit(1), add(lit(2), lit(4)))
```

As an exercise, you could try to write an evaluator for this expression. It's pretty straightforward, once you figure out how to represent the interpreted type.

Here's the solution:

```scala
type Eval[A] = A

given ExpSym[Eval] with
  def lit(i: Int) = i
  def add(lhs: Eval[Int], rhs: Eval[Int]) = lhs + rhs
  def eq[B](lhs: Eval[B], rhs: Eval[B]) = lhs == rhs
```

### The Expression Problem

Having done all that, we need to check whether we have, in fact, solved the Expression Problem for higher-order languages. We'll do so by adding support for multiplications, as a new \*sigh\* symantic:

```scala
trait MultSym[F[_]]:
  def mult(lhs: F[Int], rhs: F[Int]): F[Int]

def mult[F[_]](lhs: F[Int], rhs: F[Int])(using sym: MultSym[F]): F[Int] =
  sym.mult(lhs, rhs)
```

Writing an evaluator for that is, at this point, not very hard at all:

```scala
given MultSym[Eval] with
  def mult(lhs: Eval[Int], rhs: Eval[Int]) = lhs * rhs
```

And finally, here's an expression that uses both addition and multiplication, without any need to recompile anything:

```scala
// (1 + (2 + 4)) * 2
def exp[F[_]: ExpSym: MultSym]: F[Int] =
  mult(add(lit(1), add(lit(2), lit(4))), lit(2))
```

We have, finally, found an encoding for our DSL that solved the Expression Problem. Not a *nice* encoding, mind, nor even a very convenient one, but one that unarguably does everything we set out to achieve.

## Conclusion

Having gone through this all (well done!), it should be clear that my feelings on the matter are simple: final encodings are an elegant solution to a problem I don't care for much. The Expression Problem is an interesting *intellectual* exercise, but not one commonly found in concrete programming tasks. I will almost always prefer an initial encoding - almost, because there is one scenario in which final encodings are unarguably better: if you find yourself writing multiple, independent DSLs that you know will need to be composed.

An example of such a scenario is SQL, which can be conceived as the composition of 3 different languages (aggregation, projection and joining, if memory serves). There's even a paper on the subject, which I believe is [this one](https://www.researchgate.net/publication/312013372_Language-integrated_query_with_ordering_grouping_and_outer_joins_poster_paper) but can't confirm because the only copies I can find are behind a wall.

Aside from that one, cool but slightly weird, use case, I can't really think of a reason to use a tagless final encoding. Unless, of course, you do what the Scala community seems to have fully embraced: calling any method that puts type class constraints on a higher-order type _tagless final style_. This is technically correct - your type class instances are your \*sigh\* symantics, and they offer syntax that your code can rely on. If you squint, it sort of makes your `Monad` and `Async` type classes look like DSLs that you're composing.

But I feel this is mistaking the implementation details for the concept. Sure, a tagless final encoding relies on type classes and higher-order types. That does however not mean, in my opinion, that every piece of code that uses type classes and higher-order types is a tagless final encoding.
