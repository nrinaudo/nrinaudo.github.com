---
title: Conditionals
layout: article
series: pl
date:   20240621
---

What we've written so far is a glorified calculator - fun, certainly, but not yet exactly a programming language, is it?

One of the things that we'll need in order to be able to program complex behaviours is a way to take decisions - to do one thing or another depending on a condition. That is, we need to support `if / then / else` expressions.

These traditionally look something like:

```ocaml
if predicate
  then thenBranch
  else elseBranch
```

Where, depending on `predicate`, we'll evaluate one branch or the other, but never both.


## Substitution rules

Let's take a concrete example:
```ocaml
if true
  then 1 + 2
  else 3 + 4
```

We could naively consider this to be a function with 3 arguments, `true`, `1 + 2` and `3 + 4`. We're doing eager evaluation, which tells us that we must start by reducing all parameters before doing anything else:

```ocaml
if true
  then 3
  else 7
```

We can now run the logic of the `if` "function", which tells us that since the first parameter is `true`, this evaluates to the `then` branch, `3`.

Have you spotted the mistake we've made, though? The semantics of `if` is that we must evaluate one branch or the other, _but never both_. And we definitely evaluated both.

We'll need different substitution rules for this to work - we cannot treat `if` as a simple function (which, I know, our language doesn't even have functions yet anyway). Instead, the rule must be:
- evaluate the predicate.
- if the resulting value indicates success / truth, then substitute the entire `if` statement with the `then` branch.
- otherwise, substitute the entire `if` statement with the `else` branch.

If we go back to our previous example:
```ocaml
if true
  then 1 + 2
  else 3 + 4
```

Then our updated substitution rule tells us that since the predicate evaluates to true, this should be replaced with:
```ocaml
1 + 2
```

And we can then keep reducing until we get our result, `3`.


## Updating the AST

In order for our language to support this, we need to add a new variant to our AST, which we'll call `Cond` for _conditional_:

```scala
enum Expr:
  case Num(value: Int)
  case Add(lhs: Expr, rhs: Expr)
  case Cond(pred: Expr, thenBranch: Expr, elseBranch: Expr)
```

Now that we can represent conditionals, we'll need to interpret them, which can be a little subtle.

Here's a possible first implementation.

```scala
def interpret(expr: Expr): Int = expr match
  case Num(value)       => value
  case Add(lhs, rhs)    => interpret(lhs) + interpret(rhs)
  case Cond(pred, t, e) =>
    if interpret(pred) then interpret(t)
    else                    interpret(e)
```

We'll first interpret the predicate and, depending on its value, interpret either the _then_ or _else_ branch, exactly as our substitution rules indicate. This seems rather obvious, but doesn't actually compile. Can you see why?

The problem is that `interpret` returns an `Int`, which is not a legal type to use in the predicate part of a Scala `if` statement. We need to somehow turn this into a `Boolean`.

## Truthiness

One way of achieving that goal is to decide on an arbitrary mapping from integers to booleans. A lot of language do this, and go to rather extraordinary lengths to make sure you can pass _any_ value where a boolean is expected.

The technical name for that is _truthiness_: any value is either _truthy_ or _falsy_ - not actually true or false, no, that'd be pushing the lie a little too far, but something that sort of looks like a truth value if you squint and disengage the part of your brain that enjoys things being sane.

I do not like this approach (shocking, I know), as it can easily yield confusing runtime behaviours. For example, what does the following code evaluate to?

```ocaml
if 10 then 1
      else 2
```

Well, it depends on the language in which this is written. A lot of languages would say `2`, some `1` (and the sane ones would say _lol no_). Truthiness, not being actual truth, is a little too malleable, too open to interpretation, to be (in my opinion) a good design choice.

Still, this is easy enough to implement, so let's see quickly how that would work. We'll decide to map `0` to `false` and everything else to `true` because we're not completely mad, and get:

```scala
def interpret(expr: Expr): Int = expr match
  case Num(value)       => value
  case Add(lhs, rhs)    => interpret(lhs) + interpret(rhs)
  case Cond(pred, t, e) =>
    if interpret(pred) != 0 then interpret(t)
    else                         interpret(e)
```

There. We can do this. It's somewhat distasteful and we _shouldn't_ do it, but we _could_.

## Actual truth

But we won't. Instead, we'll do the sane thing and decide that our language must now support booleans, and that `Cond` will only accept boolean predicates.

This, however, is quite a lot more work than truthiness. Let's do it step by step.

### Runtime values

First, `interpret` can't return an `Int` any longer, can it? We now have these two scenarios:
- `Add` must evaluate to an `Int`.
- The predicate of `Cond` must evaluate to a `Boolean`.

So `interpret` must return either an `Int` or a `Boolean`. As usual, when we want a type that is either one or another, our first instinct should be a sum type:

```scala
enum Value:
  case Num(value: Int)
  case Bool(value: Boolean)
```

Now that we can represent a runtime value, we need to update `interpret`'s signature to use that:

```scala
def interpret(expr: Expr): Value = expr match
  case Num(value)       => value
  case Add(lhs, rhs)    => interpret(lhs) + interpret(rhs)
  case Cond(pred, t, e) =>
    if interpret(pred) then interpret(t)
    else                    interpret(e)
```

This, of course, does not compile at all.

### Fixing number literals

Our first problem is the `Num` branch, which returns an `Int` rather than a `Value`.

That's simple enough to fix, we merely need to wrap that `Int` in the right `Value` variant:

```scala
def interpret(expr: Expr): Value = expr match
  case Num(value)       => Value.Num(value)
  case Add(lhs, rhs)    => interpret(lhs) + interpret(rhs)
  case Cond(pred, t, e) =>
    if interpret(pred) then interpret(t)
    else                    interpret(e)
```


### Fixing addition

The `Add` branch is broken as well. Let's extract it to its own function to make it easier to see why:
```scala
def add(lhs: Expr, rhs: Expr) =
  interpret(lhs) + interpret(rhs)
```

Our first problem is that `interpret` no longer returns an `Int`, so we can't just add the two values. We need to make sure they're actually addable, by checking their runtime type. This is achieved by checking which `Value` variant we're manipulating, typically in a pattern match:

```scala
def add(lhs: Expr, rhs: Expr) =
  (interpret(lhs), interpret(rhs)) match
    case (Value.Num(lhs), Value.Num(rhs)) => Value.Num(lhs + rhs)
    case _                                => sys.error("Type error in Add")
```

The branch in which both operands evaluate to a number is straightforward: we'll add these numbers and wrap them in a `Value`, exactly like we did for `Num`.

All other branches are problematic though: they denote an illegal `Add` expression. You cannot add booleans, or booleans and integers. For the moment at least, we'll treat that as a runtime error (which, it very much is, if you think about it) and fail with an exception.


### Fixing conditionals

Just as we did for addition, let's extract conditional interpretation to its own function:

```scala
def cond(pred: Expr, t: Expr, e: Expr) =
  if interpret(pred) then interpret(t)
  else                    interpret(e)
```

The reasoning is very much the same one as for `Add`: we'll need to check, at runtime, that `pred` evaluates to a boolean.

```scala
def cond(pred: Expr, t: Expr, e: Expr) =
  interpret(pred) match
    case Value.Bool(true)  => interpret(t)
    case Value.Bool(false) => interpret(e)
    case _                 => sys.error("Type error in Cond")
```

This is a lot more verbose, certainly, but also now correct: we'll only accept conditionals where the predicate is a boolean.

One interesting aspect about this implementation is that we're making no guarantee that both branches evaluate to the same type. This is either a strength or a weakness of our implementation, depending on your perspective.

### Bringing it all together

Now that we have working implementations for the `Add` and `Cond` branch, we can rewrite `interpret` to use them:

```scala
def interpret(expr: Expr): Value = expr match
  case Num(value)       => Value.Num(value)
  case Add(lhs, rhs)    => add(lhs, rhs)
  case Cond(pred, t, e) => cond(pred, t, e)
```

There is something lacking in that implementation though. Think about it.

Well, we have a working `Cond` construct in our language, but we can't actually use it, can we? How would we create a valid predicate when we have no construct that evaluates to a boolean?

Let's fix that quickly by adding boolean literals to the language:

```scala
enum Expr:
  case Num(value: Int)
  case Bool(value: Boolean)
  case Add(lhs: Expr, rhs: Expr)
  case Cond(pred: Expr, thenBranch: Expr, elseBranch: Expr)
```

We'll of course need to update the interpreter to deal with that new variant, but it's fairly simple. We've already done pretty much the same thing for numbers.

```scala
def interpret(expr: Expr): Value = expr match
  case Num(value)       => Value.Num(value)
  case Bool(value)      => Value.Bool(value)
  case Add(lhs, rhs)    => add(lhs, rhs)
  case Cond(pred, t, e) => cond(pred, t, e)
```

And now that we have all the necessary elements, we can create a simple conditional and confirm that it's interpreted correctly.

Here's what we want to represent:
```ocaml
if true then 1
        else 2
```

Which is expressed as the following AST:

```scala
val expr = Cond(
  pred       = Bool(true),
  thenBranch = Num(1),
  elseBranch = Num(2)
)
```

This, unsurprisingly, evaluates to what it should: `1`.

```scala
interpret(expr)
// val res: Value = Num(1)
```

### Implementation notes

I'm very carefully avoiding having too much fun with this code, so as not to obscure the important points. But yes, these massive pattern matches on runtime values are begging to be refactored. You could play with that a little if you'd like, there are multiple ways of factorising them out and practicing these is always instructive. My favourite solution is to have a concrete `Type` type and, with a well thought out type class, allow syntax such as `interpret(exp).as[Boolean]`.

You could also think that there might be some way of re-using `Expr.Num` and `Expr.Bool` instead of having `Value.Num` and `Value.Bool`, and you'd be right: Scala's encoding of sum types is flexible enough that you can have variants belong to different sum types. I've decided against it, because on top of being a little Scala-specific, it'll eventually break down when we introduce functions.

And while we're on the subject of `Value`, I could probably have used Scala's union types instead of an explicit sum, something like `type Value = Int | Boolean`. This would have worked quite well, at least at first, but I decided against it because:
- union types are a little odd and exotic, where sum types are quite common. If feel that the latter, here, reduces cognitive noise.
- we'll eventually need to start adding variants that aren't standard types, which makes the case for union types a little weaker.

## Where to go from there?

We've added conditionals and distinct types to our language. This is starting to feel a little more like a proper programming language, isn't it? But we're still lacking important bits. Our next step is going to be adding support for variables.
