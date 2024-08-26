---
title: Typed Expressions
layout: article
series: pl
date:   20240824
---

One flaw with our current type checking is that while it allows us to confirm an expression is well typed, it does not prevent us from creating one. We can go one step further and have a new AST that is its own proof of type correctness: an AST that makes it impossible to create ill-typed expressions. Note that this a genuinely hard task (at least for me!) and we'll iterate over incomplete but progressively better solutions until we eventually (and hopefully) reach something foolproof.

The general idea is very similar to type checking: an evaluator that, given an `Expr`, yield not a _type_, but a _typed expression_. A typed expression should look very much like an `Expr`, with an important difference: type constraints should be enforced at the type level.

This is a bit of a pithy statement, so let's take a concrete example. We know that `Add` can only work with numeric operands, but this is not at all enforced in `Expr` - `Add(Num(1), Bool(false))` is a valid value representing an invalid program.

We have to verify type correctness during type checking, interpretation, and pretty much any evaluator we write. What we'd like, instead, is for it to be impossible to create an `Add` whose operands aren't numeric, so that no one ever has to check for that again - it's guaranteed by the type system.

A quick note: something that might get a little confusing is _type system_. Am I referring to the one we're implementing, or to the host language's, Scala? In order to try and disambiguate at least a little, I'll be referring to _our_ type system (the one we're implementing) and _the_ type system (that of the language we're writing all our code in).

So: we want _the_ type system to make it impossible for us to create an `Add` whose operands aren't numeric. This means that the type system must somehow be aware of the kind of `Expr` it's working with. How could we modify `Expr` to encode that information?

The typical solution is to make that a type parameter: write a version of `Expr` that has a type parameter, and use this to express the type of the expression. For example, `Add` would take something like `Expr[Num]` and be something like an `Expr[Num]`: it takes numbers and yields a number.

Our typed expression, then, would look something like:
```scala
enum TypedExpr[A]:
  ???
```

We'll spend the rest of this article adapting every `Expr` variant into its properly typed `TypedExpr` one.

## Typed literal values
### Numbers

Here's how we defined untyped numbers:
```scala
case Num(
  value: Int
)
```

We also defined their typing rules:
```
Γ |- Num n : Type.Num
```

If you'll recall, this is telling us that `Num` is always of type `Type.Num`. And, really, this is all we need: the typed version of `Num` must simply declare itself to be of type `Type.Num`:
```scala
case Num(
  value: Int
) extends TypedExpr[Type.Num] // Γ |- Num n : Type.Num
```

This unfortunately doesn't work, however. `Type.Num` is not a type, but an object whose type is `Type.Num.type` (for reasons that are both supremely boring and not at all related to what we're doing). I really want to use `Type.Num` rather than `Type.Num.type` everywhere though, so let's create quick type aliases:

```scala
object Type:
  type Num  = Type.Num.type
  type Bool = Type.Bool.type
```

And with that, the typed version of `Num` as we declared it works.

Note that another popular encoding (one that I've actually always used until it occurred to me that there was an alternative) is to use Scala's `Int` type rather than `Type.Num`. It can, in some cases, be more comfortable: if you're writing an interpreter, for example. In that case, `TypedExpr` is indexed by the result of interpreting it; you know that interpreting a `TypedExpr[Int]` will yield an `Int`.

I now prefer indexing `TypedExpr` with `Type`, as I find it more elegant and a more direct match to our typing rules. It also has less of an "interpreter bias" - you could be writing a compiler to a language that isn't Scala, say, in which case Scala's `Int` would be a very artificial type to use.

This is a fairly important decision, however, and has consequences for `TypedExpr`. Note how at the moment, it has a fully unconstrainted type parameter: we could very well end up working with a `TypedExpr[java.lang.String]`, for example. This makes no sense, as we've just declared that we would only use `Type`. We could move this requirement directly into `TypedExpr` by using a subtyping constraint:

```scala
enum TypedExpr[A <: Type]
```

I usually try to avoid adding subtyping constraints when I can avoid it - they're a little syntax heavy and unpleasant - but here, I feel we probably should. We want `TypedExpr` to be as tight as possible, and unpleasant though it may be, the fact that `A` must be a subtype of `Type` is an important constraint.

### Booleans

Here's how we defined untyped booleans:
```scala
case Bool(
  value: Boolean
)
```

We also defined their typing rules:
```
Γ |- Bool b : Type.Bool
```

We can apply the exact same principle as for `Num` to get the typed version of `Bool`:

```scala
case Bool(
  value: Boolean
) extends TypedExpr[Type.Bool] // Γ |- Bool b : Type.Bool
```

## Typed simple functions
### `Add`

As before, we need to look at the untyped version of `Add`:

```scala
case Add(
  lhs: Expr,
  rhs: Expr
)
```

As well as its typing rules:

```
Γ |- lhs : Type.Num    Γ |- rhs : Type.Num
------------------------------------------
Γ |- Add lhs rhs : Type.Num
```

This rule tells us that both operands must be of type `Type.Num`, and that `Add` itself is of type `Type.Num`. We can merely take this information and move it into the typed version of `Add`:

```scala
case Add(
  lhs: TypedExpr[Type.Num],   // Γ |- lhs : Type.Num
  rhs: TypedExpr[Type.Num]    // Γ |- rhs : Type.Num
) extends TypedExpr[Type.Num] // Γ |- Add lhs rhs : Type.Num
```

It's important to realise that our new typed AST embodies the typing rules. They express exactly the same thing, and it's now impossible to create an `Add` that doesn't conform to its typing rules.


### `Gt`

Here's how the untyped version of `Gt` was defined:

```scala
case Gt(
  lhs: Expr,
  rhs: Expr
)
```

The typing rules are almost the same as for `Add`:
```
Γ |- lhs : Type.Num    Γ |- rhs : Type.Num
------------------------------------------
Γ |- Gt lhs rhs : Type.Bool
```

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
  pred      : Expr,
  thenBranch: Expr,
  elseBranch: Expr
)
```

The typing rules for `Cond` are:

```
Γ |- pred : Type.Bool    Γ |- thenBranch : A    Γ |- elseBranch : A
-------------------------------------------------------------------
Γ |- Cond pred thenBranch elseBranch : A
```

`pred` is straightforward, we know it must be a boolean. That `A`, however, is new: how do we move that into `TypedExpr`?

Well, what these rules are telling us is that `thenBranch` and `elseBranch` must be of the same type, which we'll call `A`. And that will be the type of `Cond` itself. We can simply encode this by making the typed version of `Cond` parametric on `A`:

```scala
case Cond[A <: Type](
  pred      : TypedExpr[Type.Bool], // Γ |- pred : Type.Bool
  thenBranch: TypedExpr[A],         // Γ |- thenBranch : A
  elseBranch: TypedExpr[A]          // Γ |- elseBranch : A
) extends TypedExpr[A]              // Γ |- Cond pred thenBranch elseBranch : A
```

Note how here, again, the data and typing rules are clearly different expressions of the same thing. Our typed `Cond` cannot violate its own typing rules, we know for a fact it'll always be valid.


## Typed local bindings

### `Let`

Local bindings are where we'll start running into real problems with our encoding.

Here's how we defined their untyped version:

```scala
case Let(
  name : String,
  value: Expr,
  body : Expr
)
```

And their typing rules are:

```
Γ |- value : A    Γ[name <- A] |- body : B
------------------------------------------
Γ |- Let name value body : B
```

If we follow the same process we did for `Cond` (ignoring that `name <- A` bit for the moment), we end up with something fairly convincing:

```scala
case Let[A <: Type, B <: Type](
  name : String,
  value: TypedExpr[A], // Γ |- value : A
  body : TypedExpr[B]  // Γ[name <- A] |- body : B
) extends TypedExpr[B] // Γ |- Let name value body : B
```

This is where you should start feeling doubt creep in. The typing rules are no longer an exact match for the typed version of `Let`: we're ignoring the requirement that `name` to be bound to a value of type `A` in `body`. Our encoding looks very much like it'd allow us to have a `body` in which `name` is bound to the wrong type.

In order to explore that further, let's work on the elimination form of `Let`.

### `Var`

The untyped `Var` is as simple as it gets:

```scala
case Var(
  name: String
)
```

And its typing rule is fairly straightforward as well:

```
Γ |- Var name : Γ(name)
```

You'll recall that this means `Var` has whatever type `name` is bound to in our type environment. And this is where the hole in our representation becomes obvious: we don't have a notion of type environment!

The best we can do, without one, is say that `Var` has _some_ type:

```scala
case Var[A <: Type](
  name: String
) extends TypedExpr[A] // Γ |- Var name : Γ(name)
```

This will accept all legal programs: since `A` can be any type, it can certainly be the one that makes the entire expression correct. But, unfortunately, that means it can be _all the other types_ as well.

Let's take a concrete example, with this obviously incorrect program:
```ocaml
let x = true in x + 1
```

A correct type checker would never accept that - you can't add a number and a boolean. Whatever evaluator we'll write to go from `Expr` to `TypedExpr` will deal with that scenario for us. But our types are not yet powerful enough for us to prevent invalid values, as the previous expression translates to the following, perfectly fine as far as the type checker is concerned, `TypedExpr`:
```scala
Let(
  name  = "x",
  value = Bool(true),
  body  = Add(Var("x"), Num(1))
)
```

Our current encoding isn't sufficient to guarantee `TypedExpr` is fully valid. We will need to come up with a way of encoding our type environment at the type level to sort that particular issue, and _that_ is a bit of a challenge (full disclosure: I've not managed to do that at the time of writing, but am certainly hoping to get there eventually).

We _have_ made an interesting observation, however: we know that `TypedExpr` is "broken" whenever a type environment is required. Let me quality that "broken", however: `TypedExpr` is not correct _by definition_. It is possible to represent illegal programs with it. It can still be correct _by construction_: whatever `TypedExpr` we get from the type checker we'll eventually write will be correct. That's not quite as good, but `TypedExpr` does improve quite a bit on `Expr`: any expression that doesn't rely on the type environment is correct _by definition_, a guarantee `Expr` doesn't offer at all.

Let's work with that for the moment, and see if we can make it even better later.

## Typed functions

### Non-recursive functions

This is how we defined untyped function introduction:

```scala
case Function(
  param    : String,
  paramType: Type,
  body     : Expr
)
```

And here's the corresponding typing rules:

```
Γ[name <- paramType] |- body : A
--------------------------------------------------
Γ |- Function name paramType body : paramType -> A
```

If you pay attention to the type of `Function`, you should notice we have a problem. A function's type is defined by its input and output, but `Type.Function` holds no such information, or at least not at the type level!

This is a relatively easy fix however, we can simply add the corresponding type parameters:
```scala
enum Type:
  case Num
  case Bool
  case Function[From <: Type, To <: Type](from: From, to: To)
```

Note how they both must be subtypes of `Type`. We absolutely want to stay within the bounds of `Type` and not get something a little nonsensical, like `Type.Function[java.lang.String, scala.Int]`.

And while we're at it, I'm going to add a little syntactic sugar:

```scala
type ->[A <: Type, B <: Type] = Type.Function[A, B]
```

This allows us to write, for example, `Type.Int -> Type.Int` instead of `Type.Function[Type.Int, Type.Int]`, which is both pleasantly readable and matches the typing rule notation.

Right, so, we should now be able to adapt our untyped `Function`. There's one last wrinkle, however: `paramType`. It's a little unclear what we should do with that. If you remember, we introduced it for type checking purposes, because we had no other way of knowing the parameter's type when checking `body`. But `TypedExpr` is the output of type checking, isn't it? So intuitively, we probably don't need it any longer.

While we probably don't need the _value_ any longer, we absolutely do need it at the type level: it's the input type of our function. We'll just make it a type parameter.

For the rest, we can use the same technique we've been using so far, carry any typing rule we can do the type level, and ignore anything to do with the type environment:

```scala
case Function[A <: Type, B <: Type](
  param: String,
  body : TypedExpr[B]       // Γ[name <- A] |- body : B
) extends TypedExpr[A -> B] // Γ |- Function name A body : A -> B
```

And yes, since we're ignoring the type environment, it does mean `Function` is a little broken. We can, for example, declare a function that accepts a boolean where it needs a number:
```scala
val expr: TypedExpr[Type.Bool -> Type.Num] = Function(
  param = "x",
  body  = Add(Var("x"), Num(1))
)
```

### `Apply`

`Apply` is maybe a little bit of a let down, in that it's absolutely obvious how to deal with it. Here's the untyped declaration:

```scala
case Apply(
  function: Expr,
  arg     : Expr
)
```

Its typing rules do not include anything specific about the environment, which is where most of our difficulties tend to come from:

```
Γ |- function : A -> B    Γ |- arg : A
--------------------------------------
Γ |- Apply function arg : B
```

We can simply move our rules into the typed version of `Apply`:

```scala
case Apply[A <: Type, B <: Type](
  function: TypedExpr[A -> B], // Γ |- function : A -> B
  arg     : TypedExpr[A]       // Γ |- arg : A
) extends TypedExpr[B]         // Γ |- Apply function arg : B
```

And while this was very easy to get to, I quite like how cleanly it describes the essence of function application: given an `A -> B` and an `A`, you get a `B`.


### Recursive functions

We can finally tackle `LetRec`, which was defined in its untyped version as follows:

```scala
case LetRec(
  name     : String,
  value    : Expr,
  valueType: Type.Function,
  body     : Expr
)
```

And here are its typing rules:

```
Γ[name <- (A -> B)] |- value : A -> B    Γ[name <- (A -> B)] |- body : C
------------------------------------------------------------------------
Γ |- LetRec name (value : A -> B) body : C
```

There really is nothing new for us to deal with here:
- ignore the type environment for now.
- parameterize every type we can
- get rid of `valueType` and move it to the type level.

Which gives us the following typed declaration:

```scala
case LetRec[A <: Type, B <: Type, C <: Type](
  name : String,
  value: TypedExpr[A -> B], // Γ[name <- (A -> B)] |- value : A -> B
  body : TypedExpr[C]       // Γ[name <- (A -> B)] |- body : C
) extends TypedExpr[C]      // Γ |- LetRec name (value : A -> B) body : C
```

As usual, the presence of environment constraints in the typing rules means that `LetRec` is not fully safe.


## Where to go from here?
What we've done here is come up with a typed representation of `Expr`, which enforces quite a few of our typing rules by definition. Unfortunately, some of them can't yet be enforced that way, and will need to be by construction instead.

Our next step is going to be to start writing an evaluator from `Expr` to `TypedExpr`. This will turn out to be quite the endeavour, so we'll split over a few articles.
