---
title: Representing source code
layout: article
series: pl
date:   20240615
---

Let's start with a very simple programming language, one that only supports addition of numbers. The following would be a valid expression in that language:

```ocaml
1 + 2
```

## A naive encoding

We can easily see that there are two distinct things our type for code must support: an expression in our language can be either a number, or the addition of two numbers.

This kind of "one thing or another" type is almost always best encoded as a sum type, which we could naively write as:

```scala
enum Expr:
  case Num(value: Int)
  case Add(lhs: Num, rhs: Num)
```

`Num` wraps a number, and `Add` has two numeric operands (called `lhs` and `rhs` for _left-hand side_ and _right-hand side_). This feels reasonable.

There's a problem with that representation which we'll highlight and address soon, but before that, let's think about how to interpret such expressions. The way we'll do this is by writing formal specifications for how we'd like things to work, and then turn these into actual code. Such specifications are called _operational semantics_, and they're hugely useful in thinking about our language.

### Numbers

Numbers simply evaluate to themselves. In order to express that, we'll need a symbol for the notion of _interprets to_, and the traditional one is $\Downarrow$.

We can then formally express what `Num` is interpreted as:

\begin{prooftree}
  \AXC{$\texttt{Num}\ value \Downarrow value$}
\end{prooftree}

This is a fairly straightforward rule that we can easily turn into code:

```scala
def interpret(expr: Expr): Int = expr match
  case Num(value) => value // Num value ⇓ value
```

### Addition

Instinctively, we'd probably want to write the operational semantics of addition as follows:

\begin{prooftree}
  \AXC{$\texttt{Add}\ lhs\ rhs \Downarrow lhs + rhs$}
\end{prooftree}

This, however, does not really work: $lhs$ and $rhs$ are not actual numbers, but terms of our language. Before we can add them, we need to turn them into numbers, which we do by interpreting them.

We'll write this as follows:

\begin{prooftree}
  \AXC{$lhs \Downarrow v_1$}
  \AXC{$rhs \Downarrow v_2$}
  \BIC{$\texttt{Add}\ lhs\ rhs \Downarrow v_1 + v_2$}
\end{prooftree}

Where the horizontal line separates the _preconditions_ (often called _antecedents_) from the _conclusion_ (often called _consequent_): if the things described above the line hold, then so does what's under the line. Our rule, then, expresses:
- if $lhs$ is interpreted as $v_1$
- and $rhs$ is interpreted as  $v_2$
- then $\texttt{Add}\ lhs\ rhs$ is interpreted as $v_1 + v_2$.

These semantics can be turned into code rather directly:

```scala
def runAdd(lhs: Num, rhs: Num) =
  val v1 = interpret(lhs) // lhs ⇓ v₁
  val v2 = interpret(rhs) // rhs ⇓ v₂

  v1 + v2                 // Add lhs rhs ⇓ v₁ + v₂
```

Which gives us a full interpreter:

```scala
def interpret(expr: Expr): Int = expr match
  case Num(value)    => value
  case Add(lhs, rhs) => runAdd(lhs, rhs)
```

We can then confirm that it works as expected:

```scala
// 1 + 2
val expr = Add(Num(1), Num(2))

interpret(expr)
// val res: Int = 3
```

## Abstract Syntax Trees

This all appears to work quite well, and is in fact such a common pattern that things like `Expr` have a name: _Abstract Syntax Tree_, or _AST_ for short.

That name is composed of two parts: _abstract syntax_, and _syntax tree_.

### Abstract Syntax

It's called _abstract syntax_ because it's an abstraction over the human facing syntax. The following, syntactically different expressions, all parse to the same `Expr`:
```ocaml
1 + 2
(1 + 2)
1 +    2
(((1) + 2))
```

`Expr` unifies all that to `Add(Num(1), Num(2))`, abstracting over the gory details of whitespace and disambiguation parentheses. `Expr` is an abstract syntax.

### Syntax Tree

An `Expr` can be seen as a tree, which is made quite clear by viewing it as a diagram:

<span class="figure">
![](/img/pl/ast.svg)
</span>


The operator, `Add`, is the root of the tree, and its operands are leaves.

Now, you might be thinking that it's not much of a tree: it's got a depth of 1, and cannot grow. It's more of a bonsai than a tree, really. Which is, in fact, the symptom of an underlying issue in our encoding.


## Supporting nested expressions

You might have noticed that our AST is very limited - I've certainly been quite heavy handed at hinting it. How, for example, would we represent the following expression:

```ocaml
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

The interesting bit is that this doesn't cause us to change our semantics at all:

\begin{prooftree}
  \AXC{$lhs \Downarrow v_1$}
  \AXC{$rhs \Downarrow v_2$}
  \BIC{$\texttt{Add}\ lhs\ rhs \Downarrow v_1 + v_2$}
\end{prooftree}


Whether `lhs` and `rhs` are `Num` or `Expr` doesn't matter, they're still things that can be interpreted, which is all we care about. We do have to change the types of operands in `add`'s implementation, however:

```scala
def runAdd(lhs: Expr, rhs: Expr) =
  val v1 = interpret(lhs) // lhs ⇓ v₁
  val v2 = interpret(rhs) // rhs ⇓ v₂

  v1 + v2                 // Add lhs rhs ⇓ v₁ + v₂
```

We can easily confirm that this all works:

```scala
// 1 + (2 + 3)
val expr = Add(Num(1), Add(Num(2), Num(3)))

interpret(expr)
// val res: Int = 6
```

## Where to go from here?

We can now represent simple arithmetic operations in memory and interpret them. This is obviously not yet a full fledged programming language, but it's a nice start!

In the live coding sessions of this series, I will usually also implement multiplication, subtraction and division, as well as a basic code formatter. They're useful for practice, but maybe not so much for explanations, so I'll skip this here.

You however should feel free to try your hand at it if you have the time. But do not attempt yet to write operations that work with anything but numbers - this requires a little subtlety, and we'll tackle that in our next session.
