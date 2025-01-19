---
title  : Enforcing typing rules in the AST
layout : article
series : pl
date   : 20240824
---

One flaw with our current type checking is that while it allows us to confirm an expression is well-typed, it does not prevent us from creating an ill-typed one. It's still perfectly possible to create an `Expr` that adds a number to a boolean, we "merely" have a validation function that tells us we should not.

We can go one step further and have a new AST that is its own proof of type-correctness: an AST that makes it impossible to create ill-typed expressions. The general idea is very similar to type checking: an evaluator which, given an `Expr`, yield not a _type_, but a _typed expression_. A typed expression should look very much like an `Expr`, with a key difference: it would include typing rules in its very definition.

That is a bit of a pithy statement, so let's take a concrete example. We know $\texttt{Add}$ can only work with numeric operands, but this is not at all enforced. `Add(Num(1), Bool(false))` is a valid value representing an invalid program.

We need to account for this nonsensical case in type checking, interpretation, and pretty much any evaluator we may want to write. What we'd like instead, is for it to be impossible to create an $\texttt{Add}$ whose operands aren't numeric so that no one ever has to check for that again - it's guaranteed by the type system.

A quick note: something that might get a little confusing is _type system_. Am I referring to the one we're implementing, or to the host language's, Scala? In order to try and disambiguate at least a little, I'll be referring to _our_ type system (the one we're implementing) and _the_ type system (that of the language we're writing all our code in).

So: we want _the_ type system to make it impossible for us to create an $\texttt{Add}$ whose operands aren't numeric. This means the type system must somehow be aware of the kind of `Expr` it's working with. How could we encode that information in types?

## Typed AST

The typical solution is to write a version of `Expr` that has a type parameter, and use it to express the type of an expression. For example, $\texttt{Add}$ would take something like `Expr[Num]` and be something like an `Expr[Num]`: it takes numbers and yields a number.

Our typed expression, then, would look something like:
```scala
enum TypedExpr[A]
```

Of course, we must then ask ourselves - what will go in the type parameter?

A popular encoding (one that I've actually always used until it occurred to me that there was an alternative) is to use the host language's primitive types. `Int` for a numeric expression, say. This is quite comfortable, because then an expression is indexed by the type it will be interpreted as: a numeric expression is interpreted as an `Int`, a boolean one as a `Boolean`...

I now prefer indexing `TypedExpr` with `Type`, as I find it more elegant and a more direct match to our typing rules. It also has less of an "interpreter bias" - you could be writing a compiler to a language that isn't Scala, say, in which case Scala's `Int` would feel very artificial.

We'll be indexing our typed expressions with `Type` then, which forces us to update `TypedExpr`:

```scala
enum TypedExpr[A <: Type]
```

I usually try to avoid adding subtyping constraints when I can avoid it - they're a little syntax heavy and unpleasant - but here, I feel we probably should. We want `TypedExpr` to be as tight as possible, and unpleasant though it may be, the fact that `A` must be a subtype of `Type` is an important constraint.

We'll spend the rest of this article adapting every `Expr` variant into its type checked `TypedExpr` one.

## Typed number literals

Here's how we wrote literal numbers in `Expr`:
```scala
case Num(value: Int)
```

We also defined their typing rule:

\begin{prooftree}
  \AXC{$\Gamma \vdash \texttt{Num}\ value : \texttt{Type.Num}$}
\end{prooftree}

This is telling us $\texttt{Num}$ is always of type $\texttt{Type.Num}$. And, really, this is all we need: the typed version of `Num` must simply declare itself to be of type `Type.Num`:
```scala
case Num(value: Int)
  extends TypedExpr[Type.Num] // Γ |- Num value : Type.Num
```

## Typed boolean literals

Literal booleans are declared as:

```scala
case Bool(value: Boolean)
```

We also defined their typing rule:

\begin{prooftree}
  \AXC{$\Gamma \vdash \texttt{Bool}\ value : \texttt{Type.Bool}$}
\end{prooftree}

We can apply the exact same principle as for `Num` to get the typed version of `Bool`:

```scala
case Bool(value: Boolean)
  extends TypedExpr[Type.Bool] // Γ |- Bool value : Type.Bool
```

## Typed `Add`

As before, we need to look at the untyped version of `Add`:

```scala
case Add(
  lhs: Expr,
  rhs: Expr
)
```

As well as its typing rule:


\begin{prooftree}
  \AXC{$\Gamma \vdash lhs : \texttt{Type.Num}$}
  \AXC{$\Gamma \vdash rhs : \texttt{Type.Num}$}
  \BIC{$\Gamma \vdash \texttt{Add}\ lhs\ rhs : \texttt{Type.Num}$}
\end{prooftree}

This rule tells us both operands and $\texttt{Add}$ itself must all be of type $\texttt{Type.Num}$. We can merely take this information and move it into the typed version of `Add`:

```scala
case Add(
  lhs: TypedExpr[Type.Num],   // Γ |- lhs : Type.Num
  rhs: TypedExpr[Type.Num]    // Γ |- rhs : Type.Num
) extends TypedExpr[Type.Num] // Γ |- Add lhs rhs : Type.Num
```

It's important to realise how our typed AST embodies typing rules. It expresses exactly the same thing, and it's now impossible to create an `Add` that doesn't conform to its typing rule.


## Typed `Gt`

Here's how the untyped version of `Gt` was defined:

```scala
case Gt(
  lhs: Expr,
  rhs: Expr
)
```

The typing rule are almost the same as for $\texttt{Add}$:
\begin{prooftree}
  \AXC{$\Gamma \vdash lhs : \texttt{Type.Num}$}
  \AXC{$\Gamma \vdash rhs : \texttt{Type.Num}$}
  \BIC{$\Gamma \vdash \texttt{Gt}\ lhs\ rhs : \texttt{Type.Bool}$}
\end{prooftree}

We can follow the exact same process as for `Add` and get the following typed `Gt`:

```scala
case Gt(
  lhs: TypedExpr[Type.Num],    // Γ |- lhs : Type.Num
  rhs: TypedExpr[Type.Num]     // Γ |- rhs : Type.Num
) extends TypedExpr[Type.Bool] // Γ |- Gt lhs rhs : Type.Bool
```


## Typed conditionals

Conditionals are a little more interesting. Here's how we declared their untyped version:
```scala
case Cond(
  pred: Expr,
  onT : Expr,
  onF : Expr
)
```

The typing rule for $\texttt{Cond}$ is:

\begin{prooftree}
  \AXC{$\Gamma \vdash pred : \texttt{Type.Bool}$}
  \AXC{$\Gamma \vdash onT : X$}
  \AXC{$\Gamma \vdash onF : X$}
  \TIC{$\Gamma \vdash \texttt{Cond}\ pred\ onT\ onF : X$}
\end{prooftree}

That $X$ here is new. It indicates _some_ type, we just don't really care which. We're using it both as a placeholder, and as a constraint: we want $onT$ and $onF$ to be of the same type.

We can simply make it a type parameter of our typed version of `Cond` - one that, of course, is constrained to be a `Type`.

```scala
case Cond[X <: Type](
  pred: TypedExpr[Type.Bool], // Γ |- pred : Type.Bool
  onT : TypedExpr[X],         // Γ |- onT : X
  onF : TypedExpr[X]          // Γ |- onF : X
) extends TypedExpr[X]        // Γ |- Cond pred onT onF : X
```

Note how here, again, the data and typing rules are clearly different expressions of the same thing. Our typed `Cond` cannot violate its own typing rule, we know for a fact it'll always be valid.


## Typed bindings

Bindings are where we'll start running into real problems with our encoding. As usual, the environment makes things a lot harder.

### Binding introduction

Here's how we defined binding introduction:

```scala
case Let(
  name : String,
  value: Expr,
  body : Expr
)
```

The typing rule for that is:

\begin{prooftree}
  \AXC{$\Gamma \vdash value: X$}
  \AXC{$\Gamma[name \leftarrow X] \vdash body : Y$}
  \BIC{$\Gamma \vdash \texttt{Let}\ name\ value\ body : Y$}
\end{prooftree}

If we follow the same process we did for $\texttt{Cond}$ (ignoring that $name \leftarrow X$ bit for the moment), we end up with something fairly convincing:

```scala
case Let[X <: Type, Y <: Type](
  name : String,
  value: TypedExpr[X], // Γ |- value : X
  body : TypedExpr[Y]  // Γ[name <- X] |- body : Y
) extends TypedExpr[Y] // Γ |- Let name value body : Y
```

This is where you should start to feel doubt creeping in, however. Our encoding doesn't really have a notion of environment, so we cannot express the constraint that $name$ reference a value of type $X$ in $body$. We'll explore this a little more once we've typed binding elimination.

### Binding elimination

The untyped `Ref` is as simple as it gets:

```scala
case Ref(name: String)
```

And its typing rule is fairly straightforward as well:

\begin{prooftree}
  \AXC{$\Gamma \vdash \texttt{Ref}\ name : \Gamma(name)$}
\end{prooftree}

You'll recall that this means $\texttt{Ref}$ has whatever type $name$ references in our type environment, which means we're running in exactly the same problem as for $\texttt{Let}$: we do not have a notion of a type environment! The best we can do without one is to say that `Ref` has _some_ type:

```scala
case Ref[X <: Type](
  name: String
) extends TypedExpr[X] // Γ |- Ref name : Γ(name)
```

This allows us to describe all legal programs: `X` can be any type, so it can certainly be the right one! But unfortunately, it can be _all the other ones_ as well.

Let's take a concrete example, with this obviously incorrect program:
```ocaml
let x = true in
  x + 1
```

This clearly violates our typing rule for $\texttt{Add}$, and would never be accepted by a type checker. Whatever evaluator we'll write to go from `Expr` to `TypedExpr` will deal with that scenario for us. But `TypedExpr` is not yet powerful enough to prevent the manual crafting of values that represent invalid programs:

```scala
Let(
  name  = "x",
  value = Bool(true),
  body  = Add(Ref("x"), Num(1))
)
```

### `TypedExpr` limitations

Our current encoding isn't sufficient to guarantee a `TypedExpr` value describes a valid program.. We will need to come up with a way of encoding our type environment at the type level to sort that particular issue, and _that_ is a bit of a challenge, one we'll tackle later.

We know `TypedExpr` is broken whenever a type environment is required. Let me qualify that _broken_, however: `TypedExpr` is not correct _by definition_: its definition allows for illegal programs. It can still be correct _by construction_: whatever `TypedExpr` we get from the type checker we'll eventually write will always be correct. That's not quite as good, but `TypedExpr` does improve quite a bit on `Expr`: any expression that does not rely on the type environment is correct _by definition_, a guarantee `Expr` doesn't offer at all.

While `TypedExpr` is not perfect, it still makes a large number of type errors impossible. Let's work with that for the moment, and see if we can make it even better later.

## Typed functions

### Function introduction

This is how we defined function introduction:

```scala
case Fun(
  param: String,
  pType: Type,
  body : Expr
)
```

And here's the corresponding typing rule:

\begin{prooftree}
  \AXC{$\Gamma[param \leftarrow X] \vdash body : Y$}
  \UIC{$\Gamma \vdash \texttt{Fun}\ (param : X)\ body : X \to Y$}
\end{prooftree}

If you pay attention to the type of $\texttt{Fun}$, you should notice we have a problem. A function's type is defined by its input and output ($X$ and $Y$ here), but the type `Type.Fun` holds no such information.

```scala
enum Type:
  case Num
  case Bool
  case Fun(from: Type, to: Type)
```

Note that a _value_ of that type does, with its `from` and `to` fields, but we're currently firmly in the domain of types, not that of values. We know we're going from one type to another, but at least at the type level, we don't know which ones. This is a relatively easy fix however, as we can encode that as type parameters to `Type.Fun`:

```scala
case Fun[X <: Type, Y <: Type](from: X, to: Y)
```

Note how they both must be subtypes of `Type`. We absolutely want to stay within the bounds of `Type` and not get something a little nonsensical, like `Type.Fun[java.lang.String, scala.Int]`.

Right, so, we should now be able to adapt our untyped `Fun`. There's one last wrinkle, however: `pType`. It's a little unclear what we should do with that. If you remember, [we introduced it](./type_checking.html#function-introduction) for type checking purposes, because we had no other way of knowing the parameter's type when checking `body`. But `TypedExpr` is the output of type checking, isn't it? So intuitively, we probably don't need `pType` any longer.

While we probably don't need the _value_ any longer, we absolutely do need it at the type level: it's the input type of our function. We'll just make it a type parameter.

For the rest, we can use the same technique we've been using so far, carry any typing rule we can to the type level, and ignore anything to do with the type environment:

```scala
case Fun[X <: Type, Y <: Type](
  param: String,
  body : TypedExpr[Y]       // Γ[param <- X] |- body : Y
) extends TypedExpr[X -> Y] // Γ |- Fun (param : X) body : X -> Y
```

And yes, since we're ignoring the type environment, it does mean `Fun` is a little broken. It can be used, for example, to represent the following program:

```ocaml
(x: Boolean) -> x + 1
```

Here's how:

```scala
val expr: TypedExpr[Type.Bool -> Type.Num] = Fun(
  param = "x",
  body  = Add(Ref("x"), Num(1))
)
```

### Function elimination

`Apply` is maybe a little bit of a let down, in that it's absolutely obvious how to deal with it. Here's the untyped declaration:

```scala
case Apply(
  fun: Expr,
  arg: Expr
)
```

Its typing rule does not include anything specific about the environment, which is where most of our difficulties tend to come from:

\begin{prooftree}
  \AXC{$\Gamma \vdash fun : X \to Y$}
  \AXC{$\Gamma \vdash arg : X$}
  \BIC{$\Gamma \vdash \texttt{Apply}\ fun\ arg : Y$}
\end{prooftree}

We can simply move our rules into the typed version of `Apply`:

```scala
case Apply[X <: Type, Y <: Type](
  fun: TypedExpr[X -> Y], // Γ |- fun : X -> Y
  arg: TypedExpr[X]       // Γ |- arg : X
) extends TypedExpr[Y]    // Γ |- Apply fun arg : Y
```

And while this was very easy to get to, I quite like how cleanly it describes the essence of function application: given an `X -> Y` and an `X`, you get a `Y`.


## Typed recursion

We can finally tackle $\texttt{LetRec}$, which was defined in its untyped version as follows:

```scala
case LetRec(
  name : String,
  value: Expr,
  vType: Type,
  body : Expr
)
```

And here is its typing rule:

\begin{prooftree}
  \AXC{$\Gamma[name \leftarrow X] \vdash value : X$}
  \AXC{$\Gamma[name \leftarrow X] \vdash body : Y$}
  \BIC{$\Gamma \vdash \texttt{LetRec}\ name\ (value : X)\ body : Y$}
\end{prooftree}

There really is nothing new for us to deal with here:
- ignore the type environment for now.
- parameterize every type we can.
- get rid of `valueType` and move it to the type level.

Which gives us the following typed declaration:

```scala
case LetRec[X <: Type, Y <: Type](
  name : String,
  value: TypedExpr[X], // Γ[name <- X] |- value : X
  body : TypedExpr[Y]  // Γ[name <- X] |- body : Y
) extends TypedExpr[Y] // Γ |- LetRec name (value : X) body : Y
```

As usual, the presence of environment constraints in the typing rule means that `LetRec` is not fully safe.


## Where to go from here?
What we've done here is come up with a typed representation of `Expr`, which enforces quite a few of our typing rules by definition. Unfortunately, some of them can't yet be enforced that way, and will need to be by construction instead.

Our next step is going to be to start writing an evaluator from `Expr` to `TypedExpr`.
