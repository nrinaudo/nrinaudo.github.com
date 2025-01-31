---
title: Identifying invalid programs
layout: article
series: pl
date:   20240806
---

Our programming language feels pretty complete now - sure, it lacks a lot of bells and whistles, but it's powerful enough to express just about everything.

One thing that bothers me, however, is that it's perfectly possible to write programs that don't make sense. For example:

```scala
// 1 + true
val nonsense = Add(
  Num(1),
  Bool(true)
)
```

And we won't know this doesn't make sense until later, when we attempt to interpret it:

```scala
interpret(nonsense, Env.empty)
// java.lang.RuntimeException: Type error in add
```

This is arguably a perfectly valid way of checking whether a program makes sense. If running it breaks, then the program is flawed. It's a little... crude, however, and we should strive for something better.

One category of errors we can reasonably expect to find automatically is called _type errors_: performing operations on values whose type don't support these operations - such as adding a boolean to a number. Looking for type errors is called _type checking_, and is quite a fun endeavour.

Again, you might argue that we are already type checking our programs, and you'd be right: we were able to automatically assert that `nonsense` was ill-typed ("had type errors") by running it. This is called _dynamic checking_, and is considered perfectly sufficient by many languages. We are going to go one step further, however: we want to check whether a program is well-typed ("has no type error") by merely looking at it, without running it. This is called _static checking_, and is my preferred way of type checking.

Note that I'm expressing a taste here, and very carefully not stating that static checking is superior to dynamic checking. I just prefer one over the other.

## Writing a type checker

The only tools we have at our disposal to work with our AST are evaluators: functions that, given an `Expr`, explore it and transform it into some other value. We'll need to write a new one, which we'll call `typeCheck`:

```scala
def typeCheck(expr: Expr): ??? = ???
```

### Naive implementation

Since type checking decides whether an expression is well-typed, it would seem reasonable to have it return a `Boolean` - `false` if a type error was found, `true` otherwise. We could try something like this, limiting it for the moment to the terms of our language we need to describe `nonsense`:

```scala
def typeCheck(expr: Expr): Boolean =
  expr match
    case Num(value)    => true
    case Bool(value)   => true
    case Add(lhs, rhs) => typeCheck(lhs) && typeCheck(rhs)
```
And this is reasonable, right? `Num` and `Bool` are always well-typed, and `Add` is well-typed if both its operands are. Sensible enough.

Except, of course, that if we try and type check `nonsense`, we learn that it's well-typed:

```scala
typeCheck(expr)
// val res7: Boolean = true
```

Our error is that while `Add` does need both its operands to be well-typed, that's not quite enough. We also want them both to be numbers.

In order to check that, we'll need to know their types: we'll need `typeCheck` to return, not a `Boolean`, but a value that describes the type of the expression it analysed.

### Types as values

While working on our interpreter, we ended up having to write `Value` to describe the values an expression can be interpreted as. We'll need to do the same here and write `Type`, which describes the types of these values.

We have 3 kinds of values, numbers, booleans and functions. We'll need a type for each:

```scala
enum Type:
  case Num
  case Bool
  case Fun
```

There's a small flaw there, however. Functions go from one type to another, and we would like to be able to express `Type.Num -> Type.Bool`, for example. For that, we need `Fun` to keep track of its domain and codomain:

```scala
case Fun(from: Type, to: Type)
```

### Finalising `typeCheck`'s signature

Of course, we don't want `typeCheck` to simply return a `Type`, because this would imply all expressions have a type. We must allow the possibility for failure - for ill-typed expressions - which we'll do by allowing `typeCheck` to return either a `Type` or a human-readable error message:

```scala
def typeCheck(expr: Expr): Either[String, Type] = ???
```

All we need to do now is to write the body of `typeCheck`, and run through every possible expression of our AST to decide whether they're well-typed. This might take a while, but is not actually as hard as you might expect.

## Typing literal values

Literal values are very straightforward:
- literal numbers have type `Type.Num`.
- literal booleans have `Type.Bool`.

Remember how we used a formal notation to express our operational semantics? We'll do the same here to express _typing rules_. We don't need much for the moment, merely the ability to say that some expression has some type. This is how we'll write it:

\begin{prooftree}
  \AXC{$expr : X$}
\end{prooftree}

Which we'll read as _expression $expr$ has type $X$_.

Here's the typing rule for $\texttt{Num}$, then:
\begin{prooftree}
  \AXC{$\texttt{Num}\ value : \texttt{Type.Num}$}
\end{prooftree}

And, unsurprisingly, the one for $\texttt{Bool}$:

\begin{prooftree}
  \AXC{$\texttt{Bool}\ value : \texttt{Type.Bool}$}
\end{prooftree}

These are simple enough that we can just stick them directly in our type checker:

```scala
def typeCheck(expr: Expr): Either[String, Type] =
  expr match
    case Num(value)    => Right(Type.Num)  // Num value : Type.Num
    case Bool(value)   => Right(Type.Bool) // Bool value : Type.Bool
```

## Typing `Add`

Working our way through the easier things first, let's now do $\texttt{Add}$.

It has two components: $lhs$, the left-hand side operand, and $rhs$, the right-hand side one. This tells us we want to complete the following:

\begin{prooftree}
  \AXC{$\texttt{Add}\ lhs\ rhs :\ ???$}
\end{prooftree}

We know that for this to be well-typed, $lhs$ and $rhs$ must both be numbers. These are _antecedents_ (preconditions) of our typing rule, and we'll use the same syntax to express them as we did for operational semantics:

\begin{prooftree}
  \AXC{$lhs : \texttt{Type.Num}$}
  \AXC{$rhs : \texttt{Type.Num}$}
  \BIC{$\texttt{Add}\ lhs\ rhs :\ ???$}
\end{prooftree}

It's also pretty clear that adding two numbers yields a number:

\begin{prooftree}
  \AXC{$lhs : \texttt{Type.Num}$}
  \AXC{$rhs : \texttt{Type.Num}$}
  \BIC{$\texttt{Add}\ lhs\ rhs : \texttt{Type.Num}$}
\end{prooftree}

Let's take a step back before implementing this typing rule. Both antecedents tell us they expect some expression to have some type. This is clearly something we'll need to do quite a bit: $\texttt{Gt}$ will need to check that its operands are numbers, $\texttt{Cond}$ that its predicate is a boolean... so let's write a helper function for this common use case:

```scala
def expect(expr: Expr, expected: Type) =
  typeCheck(expr).flatMap: observed =>
    if observed == expected then Right(())
    else Left(s"Expected $expected, found $observed")
```

That's really the code version of $expr: expected$, and will be our basic tool for the rest of this article.

Here's how we can now turn $\texttt{Add}$'s typing rule into code:

```scala
def checkAdd(lhs: Expr, rhs: Expr) =
  for _ <- expect(lhs, Type.Num) // lhs : Type.Num
      _ <- expect(rhs, Type.Num) // rhs : Type.Num
  yield Type.Num                 // Add lhs rhs : Type Num
```

## Typing `Gt`

It shouldn't be too hard to see that the typing rule for $\texttt{Gt}$ is:

\begin{prooftree}
  \AXC{$lhs : \texttt{Type.Num}$}
  \AXC{$rhs : \texttt{Type.Num}$}
  \BIC{$\texttt{Gt}\ lhs\ rhs : \texttt{Type.Bool}$}
\end{prooftree}

That is, given two numeric operands, $\texttt{Gt}$ is a boolean. The translation to code is almost immediate:

```scala
def checkGt(lhs: Expr, rhs: Expr) =
  for _ <- expect(lhs, Type.Num) // lhs : Type.Num
      _ <- expect(rhs, Type.Num) // rhs : Type.Num
  yield Type.Bool                // Gt lhs rhs : Type.Bool
```

## Typing conditionals

Conditionals have 3 parts:
- $pred$, the predicate.
- $onT$, the expression to evaluate if $pred$ is $\texttt{true}$.
- $onF$, the expression to evaluate otherwise.

The _consequent_ (conclusion) of our typing rule for $\texttt{Cond}$ must then look like this:

\begin{prooftree}
  \AXC{$\texttt{Cond}\ pred\ onT\ onF :\ ???$}
\end{prooftree}

First, we clearly want $pred$ to be a boolean. Surely you remember the fuss I made about not having truthiness in our language.

\begin{prooftree}
  \AXC{$pred : \texttt{Type.Bool}$}
  \UIC{$\texttt{Cond}\ pred\ onT\ onF :\ ???$}
\end{prooftree}


$onT$ and $onF$ are a little trickier: we don't particularly care about their types, so long as they're valid. They can contain any expression, and therefore can have any type.

But what type do you think the following expression has (assuming `x` correctly references a boolean value)?
```ocaml
if x then 1
     else false
```

There are various options here - we could, for example, declare that $\texttt{Cond}$ has either the type of $onT$ or that of $onF$. But that quickly becomes problematic: it would mean, in essence, that the type of $\texttt{Cond}$ depends on the runtime value of $pred$. And if you remember, we said the point of our type checker was to weed out bad programs _without having to run them_. The two seem contradictory.

The easy way out of this is to declare that $onT$ and $onF$ can have any type, but it must be the same:

\begin{prooftree}
  \AXC{$pred : \texttt{Type.Bool}$}
  \AXC{$onT : X$}
  \AXC{$onF : X$}
  \TIC{$\texttt{Cond}\ pred\ onT\ onF :\ ???$}
\end{prooftree}

Note the type of $onT$ and $onF$: it's not a concrete type, but a type variable. They have _some type_. We just don't care which, so long as it's the same.

And since $\texttt{Cond}$ is interpreted as either $onT$ or $onF$, its type must clearly be the same as theirs:

\begin{prooftree}
  \AXC{$pred : \texttt{Type.Bool}$}
  \AXC{$onT : X$}
  \AXC{$onF : X$}
  \TIC{$\texttt{Cond}\ pred\ onT\ onF : X$}
\end{prooftree}


As usual, once the typing rule is clear, the concrete implementation becomes almost trivial:

```scala
def checkCond(pred: Expr, onT: Expr, onF: Expr) =
  for _ <- expect(pred, Type.Bool) // pred : Type.Bool
      x <- typeCheck(onT)          // onT : X
      _ <- expect(onF, x)          // onF : X
  yield x                          // Cond pred onT onF : X
```

## Typing bindings

### Environment

Recall that we had to introduce the notion of an environment in which we kept track of what name a value is bound to when working on `let`'s operational semantics. While values have little relevance to what we're doing right now (they happen at runtime, which we're explicitly ignoring), their _type_ is crucially important. We'll need a type environment in which to keep track of what type a name references.

This environment is conceptually very similar to our operation semantics one, so we'll use a similar notation:
\begin{prooftree}
  \AXC{$\Gamma \vdash expr : X$}
\end{prooftree}

This reads _expression $expr$ has type $X$ in environment $\Gamma$ (gamma)_. We're using $\Gamma$ as our default environment name to differentiate it from operational semantics' $e$, but more importantly, because that's what most of the literature uses and we want to follow conventions.

Just like all expressions needed a (potentially empty) environment to be interpreted in, they will need a (potentially empty) type environment in which to be type checked in.

The implementation of this environment is very similar to that of `Env`, except that we're keeping track of `Type` rather than `Value`:

```scala
case class TypeEnv(env: List[TypeEnv.Binding])

object TypeEnv:
  case class Binding(name: String, tpe: Type)

  val empty = TypeEnv(List.empty)
```

### Binding introduction

Recall that $\texttt{Let}$ has three components:
- $name$, the name we'll bind a value to.
- $value$, the value to bind.
- $body$, the expression in which the binding is in scope.

This, then, is the typing rule we want to complete:

\begin{prooftree}
  \AXC{$\Gamma \vdash \texttt{Let}\ name\ value\ body :\ ???$}
\end{prooftree}

The semantics of $\texttt{Let}$ are that $body$ will be interpreted in an environment in which $value$ is bound to $name$. From a type checking perspective, this means that $name$ will have the same type has $value$, so we'll need to check what that is:

\begin{prooftree}
  \AXC{$\Gamma \vdash value: X$}
  \UIC{$\Gamma \vdash \texttt{Let}\ name\ value\ body :\ ???$}
\end{prooftree}

Note how we're again using a type variable. We do not care what concrete type $value$ has, so long as it's a valid one.

The next step is to type check $body$. Recall that our operational semantics had us interpret $body$ in the same environment as $\texttt{Let}$, updated with a binding mapping $name$ to $value$. This tells us that $body$ must be type checked in the same environment as $\texttt{Let}$, updated so that $name$ has type $X$. The notation we used for that in operational semantics was convenient, so we'll use the same: $\Gamma[name \leftarrow X]$.

\begin{prooftree}
  \AXC{$\Gamma \vdash value: X$}
  \AXC{$\Gamma[name \leftarrow X] \vdash body : Y$}
  \BIC{$\Gamma \vdash \texttt{Let}\ name\ value\ body :\ ???$}
\end{prooftree}

$body$ has, again, _some_ type. We're not placing any constraint on it, but merely need a name to reference it. Note also that just because we have two distinct type variables, $X$ and $Y$, it does not mean they cannot refer to the same concrete type. We're using distinct names to allow them to be different, not force them to be.

And since $\texttt{Let}$ is interpreted as the result of interpreting $body$, then it seems natural that it also has type $Y$:

\begin{prooftree}
  \AXC{$\Gamma \vdash value: X$}
  \AXC{$\Gamma[name \leftarrow X] \vdash body : Y$}
  \BIC{$\Gamma \vdash \texttt{Let}\ name\ value\ body : Y$}
\end{prooftree}

Before we can turn this into code, we need to work on `TypeEnv` a little: we need to write its version of `bind`. This is essentially the same thing as for `Env`:
```scala
def bind(name: String, tpe: Type) =
  TypeEnv(TypeEnv.Binding(name, tpe) :: env)
```

And we can now turn $\texttt{Let}$'s typing rule into code:

```scala
def checkLet(name: String, value: Expr, body: Expr, Γ: TypeEnv) =
  for x <- typeCheck(value, Γ)              // Γ |- value : X
      y <- typeCheck(body, Γ.bind(name, x)) // Γ[name <- X] |- body : Y
  yield y                                   // Γ |- Let name value body : Y
```


### Binding elimination

$\texttt{Ref}$'s typing rule is as straightforward as its operational semantics: the type of a reference is whatever the environment says it is. We merely need syntax for this, and again, there's no particular reason not to reuse the one we had for operation semantics: $\Gamma(name)$ is the type of the value bound to $name$ in $\Gamma$.

$\texttt{Ref}$'s typing rule is simply:

\begin{prooftree}
  \AXC{$\Gamma \vdash \texttt{Ref}\ name : \Gamma(name)$}
\end{prooftree}

We'll of course need to update `TypeEnv` to support reference binding lookup:
```scala
def lookup(name: String) =
  env.find(_.name == name)
     .map(_.tpe)
     .toRight(s"Type binding $name not found")
```

It is, again, essentially the same thing as `Env`, except we're now treating failures as a `Left` rather than an exception.


$\texttt{Ref}$'s typing rule can now easily be coded:
```scala
def checkRef(name: String, Γ: TypeEnv) =
  Γ.lookup(name) // Γ |- Ref name : Γ(name)
```

## Typing functions
### Function introduction

Recall that $\texttt{Fun}$ has two components:
- $param$, the name to which we'll bind the function's argument.
- $body$, the expression to interpret when the function is applied.

This gives us the general shape of the consequent we want to write:

\begin{prooftree}
  \AXC{$\Gamma \vdash \texttt{Fun}\ param\ body :\ ???$}
\end{prooftree}

The semantics of $\texttt{Fun}$ are that it produces a function which, given some value, binds it to $param$ and interprets $body$ in that new environment. The type of $\texttt{Fun}$ must then depend on that of $body$, which we must type check in an environment where $param$ has... some type.

What type, though? When we were checking types at runtime, this wasn't a problem, we could simply look at the value bound to $param$ to decide. But we are checking this statically now, so we do not have a value to look at!

This is where static typing must start to have an impact on the syntax of our language. We cannot guess the type of $param$ (aside from running some complex type inference algorithms which we might tackle later but are a little beyond us just now), so we must be provided with that information. We must update our language's syntax to allow us to ascribe a type to $param$:

```ocaml
(x : Int) -> x + 1
```

Of course, since a function now carries the information of its parameter's type with it, we must update $\texttt{Fun}$:

\begin{prooftree}
  \AXC{$\Gamma \vdash \texttt{Fun}\ (param : X)\ body :\ ???$}
\end{prooftree}

This fully unblocks us, because we now know which type must be bound to $param$, which tells us which environment $body$ should be type checked in:

\begin{prooftree}
  \AXC{$\Gamma[param \leftarrow X] \vdash body : Y$}
  \UIC{$\Gamma \vdash \texttt{Fun}\ (param : X)\ body : ???$}
\end{prooftree}

$\texttt{Fun}$, then, produces a function which takes an $X$ and returns a $Y$. $\texttt{Fun}$ has type $X \to Y$.

\begin{prooftree}
  \AXC{$\Gamma[param \leftarrow X] \vdash body : Y$}
  \UIC{$\Gamma \vdash \texttt{Fun}\ (param : X)\ body : X \to Y$}
\end{prooftree}

In order to implement this typing rule, we must first update `Expr` so that `Fun` holds its parameter type:

```scala
case Fun(param: String, pType: Type, body: Expr)
```

After which we can proceed with translating our typing rule into code, which is not very hard at all:

```scala
def checkFun(param: String, x: Type, body: Expr, Γ: TypeEnv) =
  for y <- typeCheck(body, Γ.bind(param, x)) // Γ[param <- X] |- body : Y
  yield x -> y                               // Γ |- Fun (param : X) body : X -> Y
```

### Function elimination

Recall that $\texttt{Apply}$ is composed of:
- $fun$, the function to apply.
- $arg$, the value to apply it on.

Here, then, is the skeleton of our typing rule:

\begin{prooftree}
  \AXC{$\Gamma \vdash \texttt{Apply}\ fun\ arg :\ ???$}
\end{prooftree}


We know we want $fun$ to be a function, so our first step will be confirm that. We don't have any constraint on what kind of function $fun$ is, though. It can be from any type to any type, so long as it's a function.
\begin{prooftree}
  \AXC{$\Gamma \vdash fun : X \to Y$}
  \UIC{$\Gamma \vdash \texttt{Apply}\ fun\ arg :\ ???$}
\end{prooftree}


We will, of course, also want to know the type of $arg$, but this must be constrained. $fun$ is a function from $X$, which we've seen is the type bound to the function's parameter when type checking its body. This tells us that $arg$ must be of that type for things to stay sane:

\begin{prooftree}
  \AXC{$\Gamma \vdash fun : X \to Y$}
  \AXC{$\Gamma \vdash arg : X$}
  \BIC{$\Gamma \vdash \texttt{Apply}\ fun\ arg :\ ???$}
\end{prooftree}

Finally, the semantics of $\texttt{Apply}$ are that it's ultimately interpreted to $body$, which means it must have the same type:

\begin{prooftree}
  \AXC{$\Gamma \vdash fun : X \to Y$}
  \AXC{$\Gamma \vdash arg : X$}
  \BIC{$\Gamma \vdash \texttt{Apply}\ fun\ arg : Y$}
\end{prooftree}

And this makes sense, doesn't it: Applying a function from $X$ to $Y$ to an $X$ yields a $Y$, this is exactly what a function is!

We can now do the straightforward work of translating our typing rule into code:

```scala
def checkApply(fun: Expr, arg: Expr, Γ: TypeEnv) =
  typeCheck(fun, Γ).flatMap:
    case x -> y =>      // Γ |- fun : X -> Y
      expect(arg, x, Γ) // Γ |- arg : X
        .map(_ => y)    // Γ |- Apply fun arg : Y

    case other  => Left(s"Expected function, found $other")
```

## Typing recursion

$\texttt{LetRec}$ is extremely similar to $\texttt{Let}$, the only difference between the two being the environment in which $value$ is interpreted. We can thus start from $\texttt{Let}$'s typing rule, leaving that environment blank:

\begin{prooftree}
  \AXC{$??? \vdash value: X$}
  \AXC{$\Gamma[name \leftarrow X] \vdash body : Y$}
  \BIC{$\Gamma \vdash \texttt{LetRec}\ name\ value\ body : Y$}
\end{prooftree}

Recall that $\texttt{LetRec}$ must interpret $value$ in an environment in which it's already bound to $name$. We can naively write the same thing for types, $name$ must have type $X$ when type checking $value$:

\begin{prooftree}
  \AXC{$\Gamma[name \leftarrow X] \vdash value: X$}
  \AXC{$\Gamma[name \leftarrow X] \vdash body : Y$}
  \BIC{$\Gamma \vdash \texttt{LetRec}\ name\ value\ body : Y$}
\end{prooftree}

Do you see the problem with this? We must know $X$ in order to know $X$. This was a _massive_ issue when interpreting $\texttt{LetRec}$, but here, we can sidestep it altogether and do what we did with $\texttt{Fun}$: decide that if we must know $X$, then someone had better give it to us. That is, update the syntax of our language so that $\texttt{LetRec}$ is aware of the type of $value$:

\begin{prooftree}
  \AXC{$\Gamma[name \leftarrow X] \vdash value : X$}
  \AXC{$\Gamma[name \leftarrow X] \vdash body : Y$}
  \BIC{$\Gamma \vdash \texttt{LetRec}\ name\ (value : X)\ body : Y$}
\end{prooftree}

This of courses forces us to update `Expr` so that `LetRec` stores that information:

```scala
case LetRec(name: String, value: Expr, vType: Type, body: Expr)
```

As usual, now that we've reasoned through this abstractly, the implementation is almost a disappointment:

```scala
def checkLetRec(name: String, value: Expr, x: Type,
                body: Expr, Γ: TypeEnv) =
  val Γʹ = Γ.bind(name, x)

  for _ <- expect(value, x, Γʹ) // Γ[name <- X] |- value : X
      y <- typeCheck(body, Γʹ)  // Γ[name <- X] |- body : Y
  yield y                       // Γ |- LetRec name (value : X) body : Y
```

## Testing our implementation

In order to test that everything we just did at least appears to behave as expected, let's take our old example of the recursive `sum` function and fix it to include type ascriptions for function introduction and recursion.

The code would look something like:

```ocaml
let rec (sum: Num -> Num -> Num) = (lower: Num) -> (upper: Num) ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10
```

Which translates to the following AST (you don't really have to read it all, it's a little noisy and you can just trust me):

```scala
val expr = LetRec(
  name  = "sum",
  vType = Type.Num -> Type.Num -> Type.Num,
  value = Fun(
    param = "lower",
    pType = Type.Num,
    body  = Fun(
      param = "upper",
      pType = Type.Num,
      body  = Cond(
        pred = Gt(Ref("lower"), Ref("upper")),
        onT  = Num(0),
        onF  = Add(
          lhs = Ref("lower"),
          rhs = Apply(
            fun = Apply(Ref("sum"), Add(Ref("lower"), Num(1))),
            arg = Ref("upper")))))),
  body = Apply(Apply(Ref("sum"), Num(1)), Num(10))
)
```

We want this to type check to a number, since the sum of all numbers in a range is a number. And indeed:

```scala
typeCheck(expr, TypeEnv.empty)
// val res: Either[String, Type] = Right(Num)
```

## Where to go from here?

We've gained a reasonable understanding of how type checking works, and can now identify well-typed programs.

This feels a little disappointing, however: it's still perfectly possible to represent ill-typed programs. We can still write `nonsense`, it's just that we now have a validation function to tell us we shouldn't.

It would be much better if we could somehow represent programs in a way that made illegal expressions impossible - in which adding a number and a boolean did not merely cause `typeCheck` to grumble, but was a notion that simply could not exist.

We'll tackle this and typed ASTs next. This is likely to keep us busy for a little while, as it's rather harder than anything we've done so far. But it's definitely worth it and quite a bit of fun!
