---
title: Abstract Syntax Trees
layout: article
series: pl
date:   20240615
---

Now that we have a method for code interpretation, we can start thinking of writing a program to do that. The first thing we'll need is a way of representing code in memory, so that we can run substitutions on it.

Let's start with a very simple programming language, one that only supports addition of numbers. The following would be a valid expression in that language:

```scala
1 + 2
```

## A naive encoding

The idea is: we need some sort of function (let's call it `interpret`) that, given the representation of an expression, can run successive substitutions until none can be performed. Which tells us that all the parts of that expression must be of the same type, to serve as input to `interpret`.

We need a data type that is either a number or the addition of numbers, which immediately suggests an encoding: a sum type, which we could naively write as follows.

```scala
enum Expr:
  case Num(value: Int)
  case Add(lhs: Num, rhs: Num)
```

`Num` wraps a number, and `Add` has two numeric operands (called `lhs` and `rhs` for _left-hand side_ and _right-hand side_). This feels reasonable.

There's a problem with that representation which we'll highlight and address soon, but before that, let's think about how to interpret such expressions.

The choice of a sum type guides your implementation: it'll need to be a pattern match. We could, again naively, write it as follows:

```scala
def interpret(expr: Expr): Int = expr match
  case Num(value)              => value
  case Add(Num(lhs), Num(rhs)) => lhs + rhs
```

Both branches of that pattern match are straightforward and don't really need explanation (unless you've spotted why I keep using the word _naively_ and are raring to fix the mistake, which we'll get to soon).

Now that we have an interpreter, let's take it out for a spin:

```scala
val expr = Add(Num(1), Num(2))

interpret(expr)
// val res: Int = 3
```

This all appears to work quite well, and is in fact such a common pattern that things like `Expr` have a name: _Abstract Syntax Tree_, or _AST_ for short.

You can see the tree structure in `Expr`, where `Add` is a node and `Num` a leaf. Now, you might be thinking that it's not much of a tree, since it can only have a depth of 1, and you'd be entirely right. We'll fix that next.

It's called _abstract syntax_ because it's an abstraction over the human facing syntax. The following expressions, clearly different even if evaluating to the same thing, all have the same `Expr` representation:
```scala
1 + 2
(1 + 2)
1 +    2
(((1) + 2))
```

`Expr` unifies all that to `Add(Num(1), Num(2))`, abstracting over the gory details of whitespace and disambiguation parentheses.

## Supporting nested expressions

You might have noticed that our AST is very limited - I've certainly been quite heavy handed at hinting it. How, for example, would we represent the following expression:

```scala
1 + 2 + 3
```

And the answer is, we can't, not with `Expr` such as it is. The trick is to realise that the operands of `Add` are not necessarily numbers: we want to be able to nest expressions, so that `Add` can take another `Add` as an operand, and allow us to add more than 2 numbers.

Here's how we'll fix `Expr`:

```scala
enum Expr:
  case Num(value: Int)
  case Add(lhs: Expr, rhs: Expr)
```

Notice that both of `Add`'s operands are now `Expr` rather than `Num`: we can now use either `Num` or `Add` as operands to `Add`, which is exactly what we wanted.

We'll need to update our interpreter to support this:

```scala
def interpret(expr: Expr): Int = expr match
  case Num(value)    => value
  case Add(lhs, rhs) => ???
```

The `Add` branch might seem a little confusing: since we're not working with `Num` any longer, how do we get the underlying integer? Well, think about it. Do we not have a function that, given an `Expr`, returns its integer value? That's exactly what `interpret` is, isn't it? So we could recurse over `Add`'s operands and add the results:

```scala
def interpret(expr: Expr): Int = expr match
  case Num(value)    => value
  case Add(lhs, rhs) => interpret(lhs) + interpret(rhs)
```

And the `Add` branch is now quite interesting: can you see how it makes our decision to eagerly evaluate expressions explicit?

We're performing a depth-first traversal of our tree, by going all the way down to the nodes (`Num`), and then moving back up, one layer at a time, substituting as we go. That's exactly _innermost first substitution_ - that is, eager evaluation.

We can easily confirm that this all works, by evaluating `1 + 2 + 3`:

```scala
val expr = Add(
  Num(1),
  Add(Num(2), Num(3))
)

interpret(expr)
// val res: Int = 6
```

## Where to go from here?

We can now represent simple arithmetic operations in memory and interpret them. This is obviously not yet a full fledged programming language, but it's a nice start!

In the live coding sessions of this series, I will usually also implement multiplication, subtraction and division, as well as a basic code formatter. They're useful for practice, but maybe not so much for explanations, so I'll skip this here.

You however should feel free to try your hand at it if you have the time. But do not attempt yet to write operations that work with anything but integers - this requires a little subtlety, and we'll tackle that in our next session.
