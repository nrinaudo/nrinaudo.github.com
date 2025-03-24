---
title  : Inferring types
layout : article
series : pl
date:   20240807
code:   https://github.com/nrinaudo/programming_a_language/tree/main/type_inference/src/main/scala/package.scala
---

Our language now has type checking: the ability to identify programs who perform illegal actions, without running said programs.

It came at a cost, however. Our `sum` function is now _very_ type ascription heavy:

```ocaml
let rec (sum: Num -> Num -> Num) = (lower: Num) -> (upper: Num) ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10
```

This is highly unpleasant to write, and not a little frustrating: one would think it should be possible to infer `lower` and `upper` are both numbers from them being used as operands of `>`, and that `sum` must return a number from the fact that it sometimes returns `0` - which tells us `sum` must be of type `Num -> Num -> Num`.

This is called _type inference_, and is the next thing we'll be adding to the language.

## Type checking as equations

If you think back on what type checking was all about, our typing rules expressed constraints between types in the form of equalities, which we'd validate as we explored ASTs recursively. Take the following expression, for example:

```ocaml
2 > 1
```

The typing rule for [$\texttt{Gt}$](./type_checking.html#gt-typing) tells us its operands must be of type `Type.Num`, and the typing rule for [$\texttt{Num}$](./type_checking.html#num-typing) tells us `2` and `1` are of type `Type.Num`. Put another way, our expression is well-typed if the following equalities hold:
\[\begin{eqnarray}
\texttt{Type.Num} = \texttt{Type.Num}   \\\
\texttt{Type.Num} = \texttt{Type.Num}
\end{eqnarray}\]


This is clearly not the most challenging thing to prove. The one difficulty we encountered was with types that couldn't be known ahead of time, such as function parameters:

```ocaml
x -> x + 1
```

The type of `x` is unknown, and therefore cannot be part of an equality between two known types. We took what can only be described as the easy way out by demanding the type of `x` be provided ahead of time:

```ocaml
(x: Num) -> x + 1
```

This suddenly becomes very easy, as it gives us the trivial:

\[\begin{eqnarray}
\texttt{Type.Num} = \texttt{Type.Num}   \\\
\texttt{Type.Num} = \texttt{Type.Num}
\end{eqnarray}\]

This simplification means no type is ever unknown, and turns all constraints expressed by typing rules into either _tautologies_ (constraints that always hold) or _contradictions_ (constraints that never hold), with the presence of a single contradiction sufficient to prove ill-typedness (no, I'm not entirely sure this is an actual word either). Every equality can be checked on the fly, as it is encountered, which is exactly what `typeCheck` does, failing at the first contradiction or succeeding when the entire AST has been explored.

Type inference is what you get when you go the other way and decide to embrace uncertainty. Rather than demanding to be given the type of `x`, we'd just flag it as unknown and see where that takes us. We'll call such unknowns _type variables_, and conventionally name them $\\$i$, where $i$ is unique to each one. Our previous example would thus be written:


```ocaml
(x: $0) -> x + 1
```

By the same process as before, we get the following set of type equalities:

\[\begin{eqnarray}
$0                &=& \texttt{Type.Num}   \\\
\texttt{Type.Num} &=& \texttt{Type.Num}
\end{eqnarray}\]

And suddenly type checking is no longer confirming trivial equalities, but finding a value of $\\$0$ for which they hold - solving [a linear system](https://en.wikipedia.org/wiki/System_of_linear_equations). We'll spend the rest of this article figuring out how to do that.

## Adapting `Expr` to optional types

The first thing we have to do in order for type inference to make any sort of sense is update `Expr` to make type ascriptions optional - if they're all compulsory, then we don't have any type to infer, do we?

### `LetRec` and `Fun`

`Expr` has two variants which expect a type ascription, `Fun` and `LetRec`. We can simply update them so that the corresponding `Type` parameter is optional:

```scala
case LetRec(name: String, value: Expr, vType: Option[Type], body: Expr)
case Fun(param: String, pType: Option[Type], body: Expr)
```

We do not need to update our operational semantics or typing rules for this change - the former, being a description of what happens at runtime, is not impacted by type annotations, and the latter assumes all types to be known.

### `Let` <a name="updating-let"/>
We're going to go one step further. There's another term that could use a type ascription: `Let`. We didn't give it one because it's not _required_ for type checking, but I like to have one anyway for two reasons.

First, I do not like that `Let` and `LetRec` have different syntaxes, the latter taking a type ascription and the former not. They're extremely similar terms, with slightly different operational semantics, and the lack of consistent syntax across them offends me slightly.

Second, type ascriptions are not _just_ useful for type checking - they won't, for the most part, be needed for that purpose at all by the time we're done. They're also good documentation, because an explicit ascription makes it unnecessary for readers to run through their own version of a type inference algorithm in their head to work out what type a binding has.

There is of course the hidden third reason, which is that _I_ am writing this and therefore get to do things the way I prefer.

For all these reasons, then, we'll be updating `Let` to take an optional `Type` parameter:
```scala
case Let(name: String, value: Expr, vType: Option[Type], body: Expr)
```

This changes our typing rules slightly: we [used to](./type_checking.html#let-typing) get the type of $value$ by type checking it, and must now also confirm that it matches its type ascription. The change is relatively trivial:

<a name="let-typing"/>
\begin{prooftree}
  \AXC{$\Gamma \vdash value: X$}
  \AXC{$\Gamma[name \leftarrow X] \vdash body : Y$}
  \BIC{$\Gamma \vdash \texttt{Let}\ name\ (value : X)\ body : Y$}
\end{prooftree}

If you compare that to the typing rule for [$\texttt{LetRec}$](./type_checking.html#letRec-typing), the subtle difference between the two is now quite clear: one type checks $value$ in $\Gamma$, the other in $\Gamma[name \leftarrow X]$; it's merely a difference in the scope of the binding.


We've now made type ascriptions optional wherever possible. And while on the subject of `Type`, you might have already realised it was not going to be sufficient to express everything we need for inference.

## Type variables

### A new representation of types

`Type` does not allow us to represent type variables, which is rather the cornerstone of type inference. We're going to need something very similar, but able to express a `Var` datatype.

Now you might think that some sort of union of `Type` and `Var`, such as an `Either` or a [union type](https://docs.scala-lang.org/scala3/book/types-union.html), would do the trick. I certainly did at first, at least until I remembered we had to support function types as well. `Type.Fun` allows us to represent functions, of course, but only `Type -> Type` ones. It will not allow us to represent `Type.Num -> $0`, for example, which we definitely need.

The easiest solution is to simply create a new type for "types as used by type inference", which I'll call `TypeInf`:

```scala
enum TypeInf:
  case Num
  case Bool
  case Fun(from: TypeInf, to: TypeInf)
  case Var(index: Int)
```

You might be thinking this is an aggravating amount of code duplication, and I'd agree with you if `Type` was much larger. It's perfectly possible to avoid that duplication and make `TypeInf` a lot more generic (you can reduce it to two variants, one for variables and one for type constructors with a name and a potentially empty list of type parameters), but at the cost of a little peace of mind when we eventually need to turn a `TypeInf` back into a proper `Type`. Rather than a set of known types, we'd be manipulating strings, making it impossible for the compiler to check that we're dealing with all possible cases, and only possible cases.

### Fresh type variables

Now that we have the ability to represent type variables, we need to be able to create fresh ones. Remember that we need each new variable to have a unique identifier, which we'll use later to refer to it. This means we need to store the number used for the last variable, and increment it on each new one.

We're clearly talking about state here, always a controversial subject in a non-pure language like Scala: should we use mutable state, or abstractions like [`State`](https://typelevel.org/cats/datatypes/state.html)?

My preferred approach, at least in a pedagogical context, is to start with mutable state, which I curtail in two ways:
- instead of _global_ mutable state, make it local to the function I'm writing. Mutability that cannot be observed is still referentially transparent, which is all I really care about.
- wrap it in a data type of its own, to make it much simpler to turn that into something like `State` later if I decide to go that route.

Following this approach, then, here's how we'll implement creation of fresh type variables:

```scala
class InfState:
  var currentVar = 0

  def freshVar: TypeInf =
    val v = TypeInf.Var(currentVar)
    currentVar += 1
    v
```

`InfState` values will be created and manipulated within the scope of our type inference function. It will mutate, certainly, but nobody will ever see the `InfState` value, let alone observe it changing.

### Going from `Type` to `TypeInf`

Now that we have both the ability to represent and create type variables, we can finally work on turning `Type` values, as found in `Expr`, into `TypeInf` ones, as used by type inference.

Turning a `Type` into a `TypeInf` is almost obvious and should require no explanation:

```scala
object TypeInf:
  def from(tpe: Type): TypeInf = tpe match
    case Type.Num       => TypeInf.Num
    case Type.Bool      => TypeInf.Bool
    case Type.Fun(a, b) => from(a) -> from(b)
```

The fun part is how we turn an optional type ascription into a `TypeInf`. We've laid enough groundwork by now that it's a rather straightforward task:
- if the type ascription is present, we can simply call `TypeInf.from`.
- otherwise, we've encountered an unknown type and need to  represent it as a type variable.

In other words, we can add the following method to `InfState`:

```scala
def toInf(tpe: Option[Type]) =
  tpe.map(TypeInf.from)
     .getOrElse(freshVar)
```

This might seem trivial, but is heavy in consequences. Since we're now always guaranteed to have a `TypeInf` value, we're _almost_ in the same state as we were for type checking. In fact, we'll soon see that our `typeCheck` function hardly requires any change - further proof that type inference is merely a more powerful form of type checking.


## Updated type checking

We now have both optional type ascriptions, and the tools we need to work with type variables. Adapting type checking is now almost no work at all, as we merely need to:
- replace any occurrence of `Type` with `TypeInf`.
- for terms with optional type ascriptions, wrap the type parameter in `InfState.toInf`.

### Updating `checkFun`

Let's take $\texttt{Fun}$ as an example. We first need to update the corresponding branch of our `typeCheck` pattern match to use `toInf`:

```scala
case Fun(param, pType, body) =>
  checkFun(param, state.toInf(pType), body, Γ)
```

And then simply update [`checkFun`](./type_checking.html#checkFun) so that it's `x` parameter is now a `TypeInf`:

```scala
def checkFun(param: String, x: TypeInf, body: Expr, Γ: TypeEnv) =
  for y <- typeCheck(body, Γ.bind(param, x)) // Γ[param <- X] |- body : Y
  yield x -> y                               // Γ |- Fun (param : X) body : X -> Y
```

And that's really all there is to it. Even our `TypeEnv` is unchanged, aside from manipulating `TypeInf`.

We can do the exact same thing for all other branches of the pattern match, except for $\texttt{Let}$, whose typing rules [have changed](#updating-let), and $\texttt{Apply}$, which requires a little subtlety.

### Updating `checkLet`

Now that $\texttt{Let}$ has an optional type ascription, we'll need to handle it. There really isn't anything we've not seen before here, however.

We first need to update the pattern match to handle the optional type ascription, but we've just seen how to do that:

```scala
case Let(name, value, vType, body) =>
  checkLet(name, value, state.toInf(vType), body, Γ)
```
Type checking will change a little bit more, to match the [new typing rule](#let-typing). But there's really no new pattern or source of complexity for us to wrestle with here, we merely need to adapt [`checkLet`](./type_checking.html#checkLet) to confirm its value is of the expected type:

```scala
def checkLet(name: String, value: Expr, x: TypeInf, body: Expr, Γ: TypeEnv) =
  for _ <- expect(value, x, Γ)              // Γ |- value : X
      y <- typeCheck(body, Γ.bind(name, x)) // Γ[name <- X] |- body : Y
  yield y                                   // Γ |- Let name (value : X) body : Y
```

### Updating `checkApply`

$\texttt{Apply}$ is a little more problematic. It's worth reminding ourselves of the previous implementation:

```scala
def checkApply(fun: Expr, arg: Expr, Γ: TypeEnv) =
  typeCheck(fun, Γ).flatMap:
    case x -> y =>      // Γ |- fun : X -> Y
      expect(arg, x, Γ) // Γ |- arg : X
        .map(_ => y)    // Γ |- Apply fun arg : Y

    case other  => Left(s"Expected function, found $other")
```

Note how we check that `fun` is in fact a function? This was only possible in the absence of type variables. Legal types for `fun` are now functions _and type variables_, and we won't know whether a type variable maps to a function until after we've solved all typing constraints. The only thing we can really do here is declare `fun` must be a function from some `x` to some `y`, and treat it as a new type constraint to solve.

`x` is easy enough to figure out: that's the type of `arg`, which we can get through type checking. `y` is a little harder, because the only way of knowing it would be to know which type applying the function would yield - which is
exactly what we're trying to figure out!

Luckily, all we're really saying is that `y` is a type we know exists but whose value we don't know at this time - that `y` is a type variable. We can simply create a fresh one and place the constraints imposed by typing rules on it.

This gives us the following, updated implementation:

```scala
def checkApply(fun: Expr, arg: Expr, Γ: TypeEnv) =
  val y = freshVar

  for x <- typeCheck(arg, Γ)      // Γ |- arg : X
      _ <- expect(fun, x -> y, Γ) // Γ |- fun : X -> Y
  yield y                         // Γ |- Apply fun arg : Y
```

And with that, we've updated every part of our type checker, except for one: [`expect`](./type_checking.html#expect), whose role is to confirm that two types are equal. We now need to work on updating it to solve constraints.

## Solving constraints

This might appear to be a daunting task, but is actually much simpler than one might expect. Just as with type checking, we encounter constraints as we explore an AST, and just as with type checking, these constraints are expressed as equalities between types. The only difference is that said equalities might now involve type variables, for which we must try to find a value that makes the constraints that involve them hold.

This process of trying to get two types to match is known as _unification_, and is the last bit we need to figure out in order to infer types.

During unification, we're working with a set of known _substitutions_ (mapping from type variable to inferred type), traditionally called $\Phi$, which we'll keep updating as new constraints are encountered. To take a concrete example, imagine we encountered the constraint $\\$i = \texttt{Type.Num}$. This could produce an updated set of substitutions in which $\\$i$ maps to $\texttt{Type.Num}$, or it could fail if $\\$i$ was already mapped to, say, $\texttt{Type.Bool}$.

Unification will be successful if:
- all constraints can be solved that way.
- all type variables are mapped to a concrete type.

### Representing substitutions

Our first task is to represent a set of substitutions, $\Phi$. The obvious encoding that suggests itself is a `Map` from variable to type, where:
- a variable is represented as its identifier, a simple `Int`.
- a type is represented by `TypeInf`.


We also know that we're going to need to update the mapping whenever a new constraint requires it, which brings us back to our previous discussion about mutable state. Well, we already have local mutable state in the shape of `InfState`, and might as well embrace it: we'll make our representation of $\Phi$ mutable, and a property of `InfState`.

```scala
val Φ = collection.mutable.Map.empty[Int, TypeInf]
```

### A unification function

We can now start writing our unification function. Its entire purpose is to:
- reject types that cannot be unified.
- update $\Phi$ whenever necessary.

As usual, we'll be encoding potential failure as an `Either`, with human readable messages for errors. And since we're working with mutable state, we don't really need to return anything in case of success, merely mutate $\Phi$. Which gives us the following method of `InfState`:

```scala
def unify(t1: TypeInf, t2: TypeInf): Either[String, Unit] =
  (t1, t2) match
    ???
```

We now need to handle all possible combinations of `t1` and `t2`, of which only a thankfully small number actually matter.

### Unifying simple types

The simplest scenario we can encounter is a constraint where both operands are the same concrete type: these are no different than what we were doing during type checking, and unification immediately succeeds.

We'll use this very simple case as an opportunity to introduce a new formal syntax. Before we do so, a warning: what we've seen for operational semantics and typing rules is, if not exactly what you'll encounter in the literature, at least very close to and clearly inspired by it. This new one is not, I'm just making it up. I find it useful and it helps me think about the code we'll have to write, but it's nothing "official".

Let's start with $\texttt{Type.Num}$. Here's what we want to write:

\begin{prooftree}
  \AXC{$\Phi \vdash Type.Num = Type.Num \dashv \Phi$}
\end{prooftree}

This reads _given a set of substitutions $\Phi$, $\texttt{Type.Num}$ unifies with itself and produces the same set of substitutions_. It's not the most earth shattering statement to make, but we must start somewhere.

Similarly, we get the following unification rule for $\texttt{Type.Bool}$:

\begin{prooftree}
  \AXC{$\Phi \vdash Type.Bool = Type.Bool \dashv \Phi$}
\end{prooftree}

Both of these inference rules can be trivially translated to code:

```scala
case (TypeInf.Num, TypeInf.Num)   => Right(()) // Φ |- Type.Num  = Type.Num  -| Φ
case (TypeInf.Bool, TypeInf.Bool) => Right(()) // Φ |- Type.Bool = Type.Bool -| Φ
```

### Unifying functions

A somewhat more interesting scenario is constraints where both members are functions: $X_1 \to Y_1 = X_2 \to Y_2$.

For this to hold, we clearly want both domains to be equal, and both ranges to be equal. Or, put another way, we must treat it as if we'd encountered two distinct constraints:
\begin{eqnarray}
X_1 &=& X_2  \\\\\\
Y_1 &=& Y_2
\end{eqnarray}


Solving our initial constraint, then, is equivalent to solving both of these in turn:

\begin{prooftree}
  \AXC{$\Phi \vdash X_1 = Y_2 \dashv \Phi'$}
  \AXC{$\Phi' \vdash X_1 = Y_2 \dashv \Phi''$}
  \BIC{$\Phi \vdash X_1 \to Y_1 = X_2 \to Y_2 \dashv \Phi''$}
\end{prooftree}


Note how we're using the by-now familiar syntax for antecedents and consequents. Another subtlety to pay attention to is that we're threading the state through each unification: the first one produces $\Phi'$, and the second goes from $\Phi'$ to $\Phi''$, which is what the inference rule ultimately produces.

This is, again, relatively straightforward to turn into code:

```scala
case (TypeInf.Fun(x1, y1), TypeInf.Fun(x2, y2)) =>
  for _ <- unify(x1, x2) // Φ |- X1 = X2 -| Φ′
      _ <- unify(y1, y2) // Φ′ |- Y1 = Y2 -| Φ′′
  yield ()               // Φ |- X1 -> Y1 = X2 -> Y2 -| Φ′′
```

### Unifying variables

We're now left with the meat of inference: unification when at least one type is a variable. We'll be talking about constraints of the shape $\\$i = X$. Remember that $X$, here, can be any type, including a type variable. You might object that this isn't sufficient, for one of two reasons.

The first one is that it's also possible to have $X = \\$i$. While true, this is not terribly relevant: unifying $\\$i$ and $X$ is exactly the same as unifying $X$ with $\\$i$. Remember that unification is merely attempting to prove equality, and equality is commutative.

The second one is function types: we may very well encounter something like $\\$i \to Z = X \to Y$. Which is, again, perfectly true, but we've just seen this will be turned into $\\$i = X$ and $Y = Z$ - taking us back to our simple $\\$i = X$ shape.

So, $\\$i = X$ it is, then. We still have two different scenarios to take into account: whether $\\$i$ is already mapped to something or not.


#### Unmapped variables

If nothing is known about $\\$i$ (that is, if $\Phi$ does not map it to anything), then the best possible mapping for it to be equal to $X$ is, well, $X$:

\begin{prooftree}
  \AXC{$\Phi[i \to \emptyset] \vdash \\$i = X \dashv \Phi[i \leftarrow X]$}
\end{prooftree}

Note the two bits of syntax we've introduced:
- $\Phi[i \to X]$ means _$\Phi$ such that variable $i$ is mapped to $X$_ (here, $\emptyset$, meaning _nothing_).
- $\Phi[i \leftarrow X]$ means _$\Phi$, updated with a mapping from $i$ to $X$_.


#### Mapped variables

The other scenario, of course, is when $\\$i$ is already mapped to some $Y$.

In that case, we'll simply rely on the transitivity of equality: if $\\$i = Y$ and $Y = X$, then $\\$i = X$. We'll want to unify $X$ and $Y$, which is sufficient to prove $\\$i = X$.

\begin{prooftree}
  \AXC{$\Phi \vdash X = Y \dashv \Phi'$}
  \UIC{$\Phi[i \to Y] \vdash \\$i = X \dashv \Phi'$}
\end{prooftree}


#### Self-referential variables

There is a subtlety here, however. We must consider the case of self-referential variables, as these are always something of a headache. Mathematicians have built entire careers off of them.

Take the following scenario:
\[\begin{eqnarray}
$0 &=& $0                \\\
$0 &=& \texttt{Type.Num}
\end{eqnarray}\]

If we run through this naively, we'll end up in a situation where $\\$0$ maps to itself, after which we'll try to unify it with $\texttt{Type.Num}$. Since $\\$0$ maps to something, we'll want to unify _that_ with $\texttt{Type.Num}$, meaning we'll want to unify $\\$0$ with $\texttt{Type.Num}$. Again. That's a loop we'll never get out of, unless we take the usual, simple solution to impredicativity: declare it forbidden.

This leads us naturally to the conclusion that our assignment operator, $\Phi[i \leftarrow X]$, must fail if $\\$i$ is self-referential - if it occurs in $X$ one way or another.


#### Implementation

We've formalised all of our unification rules, and can now write the corresponding code.

First, `occurs`, which checks whether $\\$i$ occurs in $X$. There's nothing really complicated here, a straightforward recursive descent in $X$, returning `true` if we encounter $\\$i$ at any point:

```scala
def occurs(i: Int, x: TypeInf): Boolean = x match
  case TypeInf.Bool      => false
  case TypeInf.Num       => false
  case TypeInf.Fun(x, y) => occurs(i, x) || occurs(i, y)
  case TypeInf.Var(`i`)  => true
  case TypeInf.Var(j)    => ϕ.get(j).map(occurs(i, _)).getOrElse(false)
```

Having `occurs`, we can write our assignment operator, `assign`, which only fails if $\\$i$ occurs in $X$:

```scala
def assign(i: Int, x: TypeInf) =
  if occurs(i, x) then Left(s"Infinite type $x")
  else
    ϕ(i) = x
    Right(())
```

And finally, variable unification, which is a straightforward translation of the inference rules we just defined:

```scala
def unifyVar(i: Int, x: TypeInf) =
  ϕ.get(i) match
    case None    => assign(i, x) // ϕ[i -> ∅] |- $i = X -| ϕ[i <- X]

    case Some(y) => unify(x, y)  // ϕ |- Y = X -| ϕ′
                                 // ϕ[i -> Y] |- $i = X -| ϕ′
```

The only thing left is to hook `unifyVar` to our `unify` pattern match. We must not forget to handle both possible cases, $\\$i = X$ and $X = \\$i$:

```scala
case (TypeInf.Var(i), x) => assign(i, x)
case (x, TypeInf.Var(i)) => assign(i, x)
```


### Finishing touches

We're essentially done at this point, but for a few simple finishing touches.

The first thing we need to tidy up is our `unify` function, which is currently a non-exhaustive pattern match. It doesn't, for example, handle $\texttt{Type.Num} = \texttt{Type.Bool}$. But that's easily done: we've handled all scenarios where unification could succeed. Anything else is a failure, so we merely need add a catch-all case:
```scala
case _ => Left(s"Failed to unify $t1 and $t2")
```

And now that `unify` is fully working, we can update [`expect`](./type_checking.html#expect) to use that rather than raw equality:

```scala
def expect(expr: Expr, t: TypeInf, Γ: TypeEnv) =
  typeCheck(expr, Γ).flatMap: t2 =>
    state.unify(t, t2)
```

And we're all done: calling `typeCheck` on a well typed `Expr` will result in $\Phi$ mapping all type variables to the corresponding inferred types! But... because of course there is a but... that's unfortunately not quite enough yet. See, knowing what type each variable maps to is nice, but we don't really have a way to figure out which variable was which missing type in the original expression...

## Substituting missing types for inferred ones

At the end of type inference, we're left with two things:
- an `Expr`, potentially with missing types.
- a map from type variable to actual type.

What we need, then, is a way to map from a missing type to a type variable, and we do not have that yet. Obtaining it requires a little ingenuity and, unfortunately, a fair amount of busywork.

### Filling missing types

The easiest solution for mapping from missing type to type variables is simply to replace the former with the latter in our expression. We want a version of `Expr` in which type ascriptions are not `Option[Type]`, but `TypeInf`. If we manage to produce that, well, we can then simply explore the AST once type inference is finished and replace each `TypeInf` with the corresponding `Type`.

If you've been counting, this means 3 different versions of `Expr`, depending on how we represent type ascriptions:
- `Option[Type]`, before type inference.
- `TypeInf`, during type inference.
- `Type`, after successful type inference.

Writing all 3 versions would be rather a lot of duplicated code. A better solution would be to turn the way we represent type ascriptions into a type parameter. `Expr`, then, would become polymorphic:

```scala
enum Expr[T]:
  case Bool(value: Boolean)
  case Num(value: Int)
  case Gt(lhs: Expr[T], rhs: Expr[T])
  case Add(lhs: Expr[T], rhs: Expr[T])
  case Cond(pred: Expr[T], onT: Expr[T], onF: Expr[T])
  case Let(name: String, value: Expr[T], vType: T, body: Expr[T])
  case LetRec(name: String, value: Expr[T], vType: T, body: Expr[T])
  case Ref(name: String)
  case Fun(param: String, pType: T, body: Expr[T])
  case Apply(fun: Expr[T], arg: Expr[T])
```

The key change to notice is that `Let`, `LetRec` and `Fun` now take a `T` to describe their type parameter. An `Expr[Option[Type]]`, then, is exactly equivalent to our previous version of `Expr`, and will be what parsing yields.


We need to perform two final tasks before wrapping up this section:
- turn an `Expr[Option[Type]]` into an `Expr[TypeInf]` during type inference.
- turn an `Expr[TypeInf]` into an `Expr[Type]` after type inference.

### Substituting `TypeInf` for `Option[Type]`

This must clearly happen during type checking, as that's when we turn missing type ascriptions into type variables. But it raises a bit of a problem, doesn't it? [type checking](#typeCheck) already produces a result, the `TypeInf` of the given expression. We'll need to change that to a type that holds both the new expression and its type:

```scala
case class Typing(expr: Expr[TypeInf], t: TypeInf)
```

Updating type checking to support this is easy, just a little... long and boring, really. I'll not go through the details here (you can browse the [full code](https://github.com/nrinaudo/programming_a_language/blob/main/type_inference/src/main/scala/package.scala) if you're keen), but will merely show you a somewhat high level overview.

First, `typeCheck`'s return type must obviously be updated:
<a name="typeCheck"/>
```scala
def typeCheck(expr: Expr[Option[Type]], Γ: TypeEnv): Either[String, Typing] =
  // ...
```

Of course, if `typeCheck` changes, we'll need to update `expect` to reflect that. As a minor quality of life improvement, we'll have it return an `Expr[TypeInf]` rather than a `Typing`: we don't need to provide the specified expression's type. It's either the one we expected, or `expect` will fail.

```scala
def expect(expr: Expr[Option[Type]], t: TypeInf, Γ: TypeEnv): Expr[TypeInf] =
  for Typing(expr, t2) <- typeCheck(expr, Γ)
      _                <- state.unify(t, t2)
  yield expr
```

We'll then need to update every single `checkXXX` method to return a `Typing`, which is really repackaging its sub-expressions after type checking. This is maybe a little hard to understand before seeing an example, so let's take a look at `Add`:

```scala
def checkAdd(lhs: Expr[Option[Type]], rhs: Expr[Option[Type]], Γ: TypeEnv) =
  for lhs <- expect(lhs, TypeInf.Num, Γ)
      rhs <- expect(rhs, TypeInf.Num, Γ)
  yield Typing(Add(lhs, rhs), TypeInf.Num)
```

We're simply re-creating an `Add` with the type-checked, `Expr[TypeInf]`-typed `lhs` and `rhs`. Of course, `Add` was a simple scenario, merely used to show you the principle. The important part lies in terms with a potentially missing type ascription, such as $\texttt{Let}$:

```scala
def checkLet(name: String, value: Expr[Option[Type]], x: TypeInf,
             body: Expr[Option[Type]],  Γ: TypeEnv) =
  for value           <- expect(value, x, Γ)
      Typing(body, y) <- typeCheck(body, Γ.bind(name, x))
  yield Typing(Let(name, value, x, body), y)
```

Note how we use `x`, the `TypeInf` describing $value$'s type, in the returned `Let`. This is how we ensure that type variables contained in `Expr[TypeInf]` are correctly mapped.

After having performed this change on every single term of our language, `typeCheck` will ultimately yield an `Expr[TypeInf]`, which we can then try to resolve against $\Phi$.

### Retrieving concrete types

Before we can take our `Expr[TypeInf]` and turn it into an `Expr[Type]`, we need to be able to turn a `TypeInf` into a `Type`. This will need access to $\Phi$, and is thus logically a method on `InfState`. Additionally, it's a function that can fail: type inference is not guaranteed to yield a complete mapping (think of trying to infer types for `x -> x`). This tells us the general structure of our function must be:

```scala
def getType(t: TypeInf): Either[String, Type] =
  t match
    ???
```

Concrete types are easy, as we have a one-to-one correspondence:

```scala
case TypeInf.Num  => Right(Type.Num)
case TypeInf.Bool => Right(Type.Bool)
```

Functions are slightly more complicated, but only in that we must recursively retrieve the types of its domain and codomain:

```scala
case TypeInf.Fun(x, y) =>
  for x <- getType(x)
      y <- getType(y)
  yield Type.Fun(x, y)
```

The truly interesting scenario is type variables, which can be one of two cases:
- if the variable is not set, type inference failed and so must we.
- otherwise, it will be set to a `TypeInf`, which we must recursively analyse.

This is easily turned into code:
```scala
case TypeInf.Var(i) =>
  ϕ.get(i) match
    case None     => Left(s"Failed to infer type for variable $$$i")
    case Some(t2) => getType(t2)
```

You'll note how this could easily lead to an endless loop had we not forbidden self-referencing variables.

### Substituting `Type` for `TypeInf`

We can finally write the last missing bit: a function that turns an `Expr[TypeInf]` into an `Expr[Type]`. We'll call this `substitute`, and since it relies on `getType` which can fail, we know it can fail too. This gives us the following general structure:

```scala
def substitute(expr: Expr[TypeInf]): Either[String, Expr[Type]] =
  expr match
    ???
```

As usual, literal values are trivial. There is no moving part, meaning we have no work to do:

```scala
case Bool(value) => Right(Bool(value))
case Num(value)  => Right(Num(value))
```

All the terms that don't involve type variables will be handled similarly: recurse in their sub-expressions and reassemble the result. Here, for example, is $\texttt{Add}$:

```scala
def substAdd(lhs: Expr[TypeInf], rhs: Expr[TypeInf]) =
  for lhs <- substitute(lhs)
      rhs <- substitute(rhs)
  yield Add(lhs, rhs)
```

Finally, all the terms that do involve a type variable will follow the same process: recurse in their sub-expressions, turn the `TypeInf` into a `Type`, and wrap everything back together. Here, for example, is $\texttt{Let}$:

```scala
def substLet(name: String, value: Expr[TypeInf], x: TypeInf,
             body: Expr[TypeInf]) =
  for value <- substitute(value)
      body  <- substitute(body)
      x     <- state.getType(x)
  yield Let(name, value, x, body)
```

You can see the full code [here](https://github.com/nrinaudo/programming_a_language/blob/main/type_inference/src/main/scala/package.scala). It's a lot of what can only be described as boilerplate, and one would think something like [recursion schemes](https://nrinaudo.github.io/articles/recschemes.html) would be able to help here. I just find it hard to convince myself this would be a pedagogically wise choice.

### Tying everything together

That was a lot of code to go through. We need to write just a little bit more to tie things up nicely: the body of our inference method, which runs type checking and follows it by substitution:

```scala
for Typing(expr, _) <- typeCheck(expr, Γ)
    expr            <- substitute(expr)
yield expr
```

And there we have it: a function that takes an expression with potential missing types and, provided it was well-typed, returns a fully typed one. This was admittedly quite a bit of work but, all in all, none of which particularly hard - as most great bits of software engineering tend to be: once the solution is known, it seems perfectly obvious and inevitable. Coming up with it, however...



## Notes on this approach to type inference

Traditionally, type inference happens in two distinct phases: constraint generation, followed by constraint solving. This is how it's described in [Milner's $\mathscr{W}$ algorithm](https://homepages.inf.ed.ac.uk/wadler/papers/papers-we-love/milner-type-polymorphism.pdf), for example, and seems to have been adopted universally - or at least in everything I've read. But [Pottier](https://gallium.inria.fr/~fpottier/publis/fpottier-appsem-2005.pdf) has this sentence:
> Furthermore, for some unknown reason, $\mathscr{W}$ appears to have become more popular than $\mathscr{J}$, even though the latter is viewed—with reason!—by Milner as a simplification of the former.

After a little investigation, my understanding of $\mathscr{J}$ is that it's an optimisation of $\mathscr{W}$: the latter has you iterate through all constraints, eliminating them one after the other and rewriting all the remaining ones with the newfound knowledge. $\mathscr{J}$, on the other hand, uses something closer to [union-find](https://en.wikipedia.org/wiki/Disjoint-set_data_structure) and does not rewrite constraints at all: it merely updates the state of its knowledge in a mapping from type variable to type.

My reasoning, then, is as follows: if $\mathscr{J}$ iterates over every constraint without modifying them, there's no reason to separate type inference in two phases. You can simply unify types as you encounter them, which will yield the same result, but means:
- you can fail at the first type error, without having to explore the entire AST (you may not want to do this if your goal is to provide a comprehensive list of errors to humans).
- you do not need to store all constraints in memory at the same time, since they are discarded as soon as they are encountered.

I may be missing a subtle point, and there might be scenarios in which my reasoning doesn't hold - potentially in languages with parametric polymorphism or type classes ? - but I've not been able to find a counter example. And so, type inference, as presented here, is a (simple) single-phase version of $\mathscr{J}$.

Another thing that's worth pointing out is that our implementation is suboptimal: the larger $\Phi$ grows, the longer chains of variables pointing to each other get, the more expensive variable lookup will become. The fix is obvious (and I did not mention union-find earlier by accident), but I didn't feel it was worth the added complexity in something that is mostly intended to be a pedagogical exercise. If you happen to run in this performance issue, you need to make $\Phi$ behave more like union-find and update links between variables as you explore them. For example, should you encounter $\\$i = \\$j$, $\\$j = \\$k$ and $\\$k = \\$l$ when trying to retrieve the value of $\\$i$, you should update $\\$i$, $\\$j$ and $\\$k$ to all point to $\\$l$ to make lookup a 1-step operation rather than one that would potentially explore the whole of $\Phi$.

Finally, we used local mutable state in this article because I felt it would be a lot easier to understand than [`State`](https://typelevel.org/cats/datatypes/state.html). If you already understand that, however, or would like to see what that approach would be like, the code is available [here](https://github.com/nrinaudo/programming_a_language/tree/main/type_inference_state/src/main/scala/package.scala).


## Where to go from here?

We now have a full fledged type inference implementation, and are capable of identifying well-typed program even when they lack type ascriptions.

This feels a little disappointing, however: it’s still perfectly possible to represent ill-typed programs. We can still write nonsense, it’s just that there is now a validation function to tell us we shouldn’t.

It would be much better if we could somehow represent programs in a way that made illegal expressions impossible - in which adding a number and a boolean did not merely cause type checking to grumble, but was a notion that simply could not exist.

We’ll tackle this and typed ASTs next. This is likely to keep us busy for a little while, as it’s rather harder than anything we’ve done so far. But it’s definitely worth it and quite a bit of fun!
