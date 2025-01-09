---
title: Taking decisions
layout: article
series: pl
date:   20240621
---

What we've written so far is a glorified calculator - fun, certainly, but not yet exactly a programming language, is it?

One of the things that we'll need in order to be able to program complex behaviours is a way to take decisions - to do one thing or another depending on a condition. That is, we need to support `if / then / else` expressions.

These traditionally look something like:

```ocaml
if true then 1
        else 2
```

Informally, they behave as follows:
- if the expression between `if` and `then` (the _predicate_) evaluates to `true`, we'll interpret the expression after `then` (the _on-true_ branch).
- otherwise, we'll interpret the value after `else` (the _on-false_ branch).

It's important to note that we never interpret both the on-true and on-false branches.


## Operational semantics

Let's start by writing the shape of our conclusion:

\begin{prooftree}
  \AXC{$\texttt{Cond}\ pred\ onT\ onF \Downarrow\ ???$}
\end{prooftree}

$\texttt{Cond}$ needs 3 things:
- a predicate, $pred$.
- the code to execute when $pred$ is $\texttt{true}$, $onT$ (for _on-true_).
- the code to execute when $pred$ is $\texttt{false}$, $onF$ (for _on-false_).

Our semantics are quite clear: we need to interpret either $onT$ or $onF$ depending on what $pred$ evaluates to. But that's not really something our formal syntax seems to support, is it?

The trick is to realise we can have multiple rules for a given term of the language. Here, for example, we will have one rule for the $\texttt{true}$ scenario, and another for the $\texttt{false}$ scenario.

Let's start with the $\texttt{true}$ case. We know exactly what to do: if $pred$ evaluates to $\texttt{true}$, then we must interpret $onT$, and $\texttt{Cond}$ will evaluate to whatever that returns. Or, in a more terse, formal syntax:

\begin{prooftree}
  \AXC{$pred \Downarrow \texttt{true}$}
  \AXC{$onT \Downarrow v$}
  \BIC{$\texttt{Cond}\ pred\ onT\ onF \Downarrow v$}
\end{prooftree}

The $\texttt{false}$ scenario is essentially the same, except we work with $onF$ instead:

\begin{prooftree}
  \AXC{$pred \Downarrow \texttt{false}$}
  \AXC{$onF \Downarrow v$}
  \BIC{$\texttt{Cond}\ pred\ onT\ onF \Downarrow v$}
\end{prooftree}

## Implementing conditionals

In order for our language to support this, we need to add a new variant to our AST, which we'll call `Cond` for _conditional_. We know exactly what its members must be, we merely need look at what our operational semantics need:

```scala
enum Expr:
  case Num(value: Int)
  case Add(lhs: Expr, rhs: Expr)
  case Cond(pred: Expr, onT: Expr, onF: Expr)
```

And its interpretation is a direction translation of the operational semantics:

```scala
def cond(pred: Expr, onT: Expr, onF: Expr) =
  if interpret(pred) then  // pred ⇓ true
    val v = interpret(onT) // onT ⇓ v
    v                      // Cond pred onT onF ⇓ v

  else                     // pred ⇓ false
    val v = interpret(onF) // onF ⇓ v
    v                      // Cond pred onT onF ⇓ v
```

This is of course a little cumbersome. I wrote it that way initially to make it clear how closely it matches the operational semantics, but we can apply our refactoring skills to that first draft and get the much more digestible:

```scala
def cond(pred: Expr, onT: Expr, onF: Expr) =
  if interpret(pred) then interpret(onT)
  else                    interpret(onF)
```

Except... this cannot work, can it? There are three ways you can see why not:
- looking at the operational semantics, you can realise that we're manipulating $\texttt{true}$ and $\texttt{false}$, which are not actually terms of our language.
- in `cond`, you can realise that `interpret` evaluates to `Int`, and that Scala, being a sane language, cannot use an `Int` where a `Boolean` is expected.
- attempt to compile it and see how mad the type checker gets...

Or, put more simply: our language does not have a notion of booleans - which makes it a little awkward to express predicates.

## Truthiness

One way of supporting booleans is to decide on an arbitrary mapping from integers. A lot of language do this, and go to rather extraordinary lengths to make sure you can pass _any_ value where a boolean is expected.

The technical name for that is _truthiness_: any value is either _truthy_ or _falsy_ - not actually true or false, but something that sort of looks like a truth value if you squint and disengage the part of your brain that enjoys things being sane.

I do not like this approach (shocking, I know), as it can easily yield confusing runtime behaviours. For example, what does the following code evaluate to?

```ocaml
if 10 then 1
      else 2
```

Well, it depends on the language in which this is written. A lot of languages would say `2`, some `1` (and the sane ones _lol no_). Truthiness, not being actual truth, is a little too malleable, too open to interpretation, to be (in my opinion) a good design choice.

Still, this is easy enough to implement, so let's see quickly how that would work. We'll decide to map `0` to `false` and everything else to `true` because we're not completely mad, and get:

```scala
def cond(pred: Expr, onT: Expr, onF: Expr) =
  if interpret(pred) != 0 then interpret(onT)
  else                         interpret(onF)
```

There. We can do this. It's somewhat distasteful and we _shouldn't_ do it, but we _could_.

## Actual truth

But we won't. Instead, we'll do the sane thing and decide that our language must now support booleans, and that $\texttt{Cond}$ will only accept things that evaluate to a boolean value.

This, however, is quite a lot more work than truthiness. Let's do it step by step.

### Runtime values

First, `interpret` can't return an `Int` any longer, can it? It must return something that is either an `Int` or a `Boolean`.

As usual, when we want a type that is either one or another, our first instinct should be a sum type:

```scala
enum Value:
  case Num(value: Int)
  case Bool(value: Boolean)
```

Now that we can represent a runtime value, we need to update `interpret`'s signature to use that:

```scala
def interpret(expr: Expr): Value = expr match
  case Num(value)           => value
  case Add(lhs, rhs)        => add(lhs, rhs)
  case Cond(pred, onT, onF) => cond(pred, onT, onF)
```

This, of course, does not come anywhere close to compiling. We'll need to go back to the operational semantics of all existing terms to understand why, and fix them.

### Fixing number literals

The only thing to fix in our handling of numbers is that they evaluate to raw integers, when we need them to yield a $\texttt{Value.Num}$. This is fixed easily enough:

\begin{prooftree}
  \AXC{$\texttt{Num}\ value \Downarrow \texttt{Value.Num}\ value$}
\end{prooftree}

Which rather immediately translates into code:

```scala
def interpret(expr: Expr): Value = expr match
  case Num(value)           => Value.Num(value) // Num value ⇓ Value.Num value
  case Add(lhs, rhs)        => add(lhs, rhs)
  case Cond(pred, onT, onF) => cond(pred, onT, onF)
```

### Fixing addition

Addition is a little more subtle. We need to fix it so that:
- its operands evaluate to numbers.
- it evaluates to a number itself.

\begin{prooftree}
  \AXC{$lhs \Downarrow \texttt{Value.Num}\ v_1$}
  \AXC{$rhs \Downarrow \texttt{Value.Num}\ v_2$}
  \BIC{$\texttt{Add}\ lhs\ rhs \Downarrow \texttt{Value.Num}\ (v_1 + v_2)$}
\end{prooftree}

You might be wondering - wait, what happens in the case where the operands are not numbers? We've not specified that!

That's one of the things I enjoy about this notation: you only specify what's valid. So when turning this into code, we must support everything that's backed by a rule. Anything else though? That's an error, and we should fail accordingly.

Here's what we get when translating the operational semantics to code:

```scala
def add(lhs: Expr, rhs: Expr) =
  (interpret(lhs), interpret(rhs)) match
    case (Value.Num(v1), Value.Num(v2)) => Value.Num(v1 + v2)
    case _                              => typeError("add")
```

Note how we're treating combination of operands that aren't 2 numbers as a type error.

### Fixing conditionals

The problem with conditionals is how they work with raw booleans, when they should really expect the predicate to evaluate to a $\texttt{Value.Bool}$.

\begin{prooftree}
  \AXC{$pred \Downarrow \texttt{Value.Bool}\ \texttt{true}$}
  \AXC{$onT \Downarrow v$}
  \BIC{$\texttt{Cond}\ pred\ onT\ onF \Downarrow v$}
\end{prooftree}

\begin{prooftree}
  \AXC{$pred \Downarrow \texttt{Value.Bool}\ \texttt{false}$}
  \AXC{$onF \Downarrow v$}
  \BIC{$\texttt{Cond}\ pred\ onT\ onF \Downarrow v$}
\end{prooftree}

And that's really all we need to fix. We don't particularly care what kind of value $v$ is, so we don't need to put any restriction on it.

This gives us the following code:

```scala
def cond(pred: Expr, onT: Expr, onF: Expr) =
  interpret(pred) match
    case Value.Bool(true)  => interpret(onT) // pred ⇓ Value.Bool true    onT ⇓ v
    case Value.Bool(false) => interpret(onF) // pred ⇓ Value.Bool false   onF ⇓ v
    case _                 => typeError("cond")
```

## Testing our implementation

Now that everything is done, we should be able to test our code, but... we're lacking something, though. We can't actually write a conditional expression yet, can we. How would we create a valid predicate when we have no construct that evaluates to a boolean?

### Boolean literals

Let's fix that quickly by adding boolean literals to the language:

\begin{prooftree}
  \AXC{$\texttt{Bool}\ value \Downarrow \texttt{Bool.Num}\ value$}
\end{prooftree}

This tells us we need to add the `Bool` variant to our AST:

```scala
case Bool(value: Boolean)
```

We'll of course need to update the interpreter to deal with that new variant, but it's fairly simple. We've already done pretty much the same thing for number literals.

```scala
def interpret(expr: Expr): Value = expr match
  case Num(value)           => Value.Num(value)
  case Bool(value)          => Value.Bool(value) // Bool value ⇓ Value.Bool value
  case Add(lhs, rhs)        => add(lhs, rhs)
  case Cond(pred, onT, onF) => cond(pred, onT, onF)
```

### Checking our work

And now that we have all the necessary elements, we can create a simple conditional and confirm that it's interpreted correctly.

Here's the code we want to interpret:

```ocaml
if true then 1
else         2
```

It translates to the following AST:

```scala
val expr = Cond(
  pred = Bool(true),
  onT  = Num(1),
  onF  = Num(2)
)
```

This, unsurprisingly, evaluates to what it should: `1`.

```scala
interpret(expr)
// val res: Value = Num(1)
```

## Where to go from there?

We've added conditionals and distinct types to our language. This is starting to feel a little more like a proper programming language, isn't it? But we're still lacking important bits. Our next step is going to be adding support for named values (_variables_, although I'm not a big fan of that name).
