---
title: Identifying invalid programs
layout: article
series: pl
date:   20240806
---

Our programming language feels pretty complete now - sure, it lacks a lot of bells and whistles, but it's powerful enough to express just about everything.

One thing that bothers me, however, is that it's perfectly possible to write programs that don't make sense. For example:

```scala
val nonsense = Add(
  Num(1),
  Bool(true)
)
```

And we won't know this doesn't make sense until later, when we attempt to run it:

```scala
interpret(nonsense, Env.empty)
// java.lang.RuntimeException: Type error in add
```

What we'll work on here, then, is a way of separating programs that don't make sense from those that do, and of doing so without having to run them. This is typically called type checking: we'll make sure that all the types line up, such as both operands of `Add` being numbers.

I want to stress something I just said in passing: _without having to run them_. The type checking we're doing is purely static, as we'll weed out programs that don't type check by merely "looking" at them.

You might wonder, _well, what about dynamic checking?_ If so, what do you think we've been doing so far, checking our types while interpreting programs, and failing on mismatch?

## Type checker

The only tools we have at our disposal to work with our AST are evaluators: functions that, given an AST, explore it and return some form of value.

We'll need to write a new one, which we'll call `typeCheck`:

```scala
def typeCheck(expr: Expr): ??? = ???
```

The first thing we'll need to figure out is its return type.

The entire point of `typeCheck` is to find invalid programs without crashing, so we know we'll need to include the possibility of failure. This is traditionally done with `Either`, and we'll keep things simple by treating errors as error messages, which gives us part of our return type: `Either[String, ???]`.

Now, what value would we need to return in case of a success? Well, think about how we'd handle the `Add` branch. We'll first need to type check the left- and right-hand side operands, and then make sure that they're both numbers, because we can only add numbers. This tells us our return value must somehow describe the type of a sub-expression, in order for us to confirm it matches our expectations.

We'll need to declare a new type for that, which we'll cleverly call `Type`. It needs to allow us to differentiate between the 3 types we currently support, numbers, booleans and functions, so a sum type seems in order:

```scala
enum Type:
  case Num
  case Bool
  case Function
```

You can probably see that this is a little flawed, however. The `Function` variant is clearly incomplete: functions go from some type to some other type, which we haven't at all encoded here.

Here's a better implementation:

```scala
enum Type:
  case Num
  case Bool
  case Function(from: Type, to: Type)
```


We now know the return type of our type checker: `Either[String, Type]`:

```scala
def typeCheck(expr: Expr): Either[String, Type] = ???
```

What's left to do is write its body, and run through every possible expression of our AST to decide whether they're type-correct. This might take a while... but it's not actually as hard as you might expect.

## Type checking literal values

Literal values are very straightforward:
- literal numbers have type `Type.Num`.
- literal booleans have `Type.Bool`.

We're going to need to talk a lot about _something having type something_, so let's come up with a more concise notation for this. We'll write _x has type X_ as follows:

```
|- x : X
```

To remove any ambiguity, no, I'm not coming up with brand new notation, but reusing chunks of an existing standard and introducing more of it as the need arises.

For literal values, then, we have the following typing rules:
- numbers: `|- Num n : Type.Num`
- booleans: `|- Bool b : Type.Bool`


Which we can translate easily enough into code:

```scala
def typeCheck(expr: Expr) = expr match
  case Num(value)  => Right(Type.Num)  // |- Num n : Type.Num
  case Bool(value) => Right(Type.Bool) // |- Bool b : Type.Bool
```

## Type checking simple functions

### `Add`

Working our way through the easier things first, let's tackle simple functions such as `Add`. Here's how we might go about it:
- _if_ `lhs` has type `Type.Num`.
- _if_ `rhs` has type `Type.Num`.
- _then_ `Add lhs rhs` has type `Type.Num`.


That's quite a lot of text to write, so let's improve our typing rule syntax. You should see that there are two distinct parts to our set of rules:
- preconditions: the left- and right-hand side operands must be numbers.
- conclusions: `Add` is a number.

These are typically called the _antecedent_ and the _consequent_, and we'll separate them with a horizontal line:

```
|- lhs : Type.Num    |- rhs : Type.Num
--------------------------------------
|- Add lhs rhs : Type.Num
```

In order to translate these rules into code, we'll first need to be able to write `|- x : Type.Num`: confirm that some expression is of type `Type.Num`.

```scala
def expectNum(expr: Expr) =
  typeCheck(expr).flatMap { observed =>
    Either.cond(
      test  = observed == Type.Num,
      left  = s"Expected Num, found $observed",
      right = observed
    )
  }
```

It should be obvious we can make this function a lot more useful with very little work by making the expected type a parameter rather than hard-coding it to `Type.Num`:

```scala
def expect(expr: Expr, expected: Type) =
  typeCheck(expr).flatMap { observed =>
    Either.cond(
      test  = observed == expected,
      left  = s"Expected $expected, found $observed",
      right = observed
    )
  }
```

Armed with `expect`, we can now quite easily write our entire `Add` checking function:

```scala
def checkAdd(lhs: Expr, rhs: Expr) = for
  _ <- expect(lhs, Type.Num) // |- lhs : Type.Num
  _ <- expect(rhs, Type.Num) // |- rhs : Type.Num
yield Type.Num               // |- Add lhs rhs : Type.Num
```

### `Gt`

It shouldn't be too hard to see that the typing rule for `Gt` are:

```
|- lhs : Type.Num    |- rhs : Type.Num
--------------------------------------
|- Gt lhs rhs : Type.Bool
```

That is, given two numeric operands, `Gt` is a boolean. Which easily translates into code:

```scala
def checkGt(lhs: Expr, rhs: Expr) = for
  _ <- expect(lhs, Type.Num) // |- lhs : Type.Num
  _ <- expect(rhs, Type.Num) // |- rhs : Type.Num
yield Type.Bool              // |- Gt lhs rhs : Type.Bool
```

This allows us to complete some missing chunks of our type checker:

```scala
def typeCheck(expr: Expr) = expr match
  case Num(value)    => Right(Type.Num)
  case Bool(value)   => Right(Type.Bool)
  case Add(lhs, rhs) => checkAdd(lhs, rhs)
  case Gt(lhs, rhs)  => checkGt(lhs, rhs)
```

## Type checking conditionals

Conditionals have 3 components: predicate, then-branch and else-branch.

Checking the predicate is simple enough: we need to make sure it has type `Type.Bool`. We have all the tools we need for that.

The then-branch and else-branch are a little trickier though: we don't particularly care what type they have, as they can contain any expression. But if we put no constraint on this, what type would a conditional have?

There are various options here - we could, for example, say that it has either the type of the then-branch or that of the else-branch. But that quickly becomes problematic: it means, in essence, that the type of a conditional depends on the runtime value of the predicate. And if you remember, we said the point of our type checker was to weed out bad programs _without having to run them_. These two seem contradictory.

The easy way out of this is to declare that the then-branch and else-branch must have the same type, which ends up being the type of our conditional. Here, for example:
```ocaml
if true then 1 else 2
```

Since both branches are numbers, the type of this expression will also be number.

Putting all this together, it means that type checking a conditional is done as follows:
 - _if_ `pred` has type `Type.Bool`.
 - _if_ `t` has type `X`.
 - _if_ `e` has the same type `X`.
 - _then_ `Cond pred t e` has type `X`.

Which can be expressed using our typing rule syntax as:

```
|- pred : Type.Bool    |- t : X    |- e : X
-------------------------------------------
|- Cond pred t e : X
```

This can be turned rather directly into code:

```scala
def checkCond(pred: Expr, t: Expr, e: Expr) =
  for
    _      <- expect(pred, Type.Bool) // |- pred : Type.Bool
    x      <- typeCheck(t)            // |- t : X
    _      <- expect(e, x)            // |- e : X
  yield x                             // |- Cond pred t e : X
```

This gives us an improved type checker:

```scala
def typeCheck(expr: Expr) = expr match
  case Num(value)       => Right(Type.Num)
  case Bool(value)      => Right(Type.Bool)
  case Add(lhs, rhs)    => checkAdd(lhs, rhs)
  case Gt(lhs, rhs)     => checkGt(lhs, rhs)
  case Cond(pred, t, e) => checkCond(pred, t, e)
```

## Local bindings

### `Let`

We'll tackle `Let` next, as it introduces a new wrinkle in our type checking.

`Let` has three components: a `name`, a `value` to bind to that name, and a `body` in which that binding is active. So, intuitively, what we want to say is something like:
- _if_ `value` has type `X`.
- _if_ `body` has type `Y` in an environment in which variable `name` has type `X`.
- _then_ `Let` has type `Y`.

There's one thing we're clearly missing in our syntax to express this, however: the notion of environment. We'll write this `Γ` (gamma), and add conditions on an environment as follows:
```
Γ[foo <- X]
```
This describes an environment in which name `foo` has type `X`.

This new bit of syntax allows us to express the typing rule for `let` expressions:
```
Γ |- value : X    Γ[name <- X] |- body : Y
------------------------------------------
Γ |- Let name value body : Y
```

Note how the `Γ` always goes in front of the `|-` operator, which we can now learn to pronounce. `Γ |- e : X` is read _enviroment `Γ` proves that expression `e` has type `X`_.

We now have a clear typing rule for `let` expressions, but translating them to code is going to be a little work: we do not at all have this notion of `Γ`! But we have done something similar while interpreting our AST, haven't we? We wrote an environment in which we kept track of which name was bound to which value. We can do the same thing here, but instead of values, we'll use types.

The code is essentially the same as for `Env`, except that we don't need to expose a `set` method (and thus don't need the underlying `Map` to be mutable):

```scala
case class TypeEnv(map: immutable.Map[String, Type]) {
  def bind(name: String, tpe: Type) = TypeEnv(map + (name -> tpe))

  def lookup(name: String) = map.get(name) match
    case Some(tpe) => Right(tpe)
    case None      => Left(s"Type binding $name not found")
}

object TypeEnv:
  val empty = TypeEnv(immutable.Map.empty)
```

Now that we have a type environment, of course, we need to update `typeCheck` to take it as a parameter. This is not particularly instructive code and will not be writing it here - just pretend that all the functions we wrote so far took an `env: TypeEnv` parameter and passed it where needed.

Having this environment allows us to turn our `let` expression typing rules into code:

```scala
def checkLet(name: String, value: Expr, body: Expr, env: TypeEnv) =
  for
    x <- typeCheck(value, env)              // Γ |- value : X
    y <- typeCheck(body, env.bind(name, x)) // Γ[name <- X] |- body : Y
  yield y                                   // Γ |- Let name value body : Y
```

### `Var`
And, of course, if we have `Let`, we need to do its elimination form, `Var`. The typing rule is as simple as it can be: we're merely saying that the type of a variable is whatever is stored in the environment.

Of course, we don't have syntax for this _whatever is stored in the environment_, so let's introduce some. We'll simply treat `Γ` as a function from name to type, and write:

```
Γ |- Var name : Γ(name)
```

That has an immediate translation to code:

```scala
def checkVar(name: String, env: TypeEnv) =
  env.lookup(name)  // Γ |- Var name : Γ(name)
```

We can now update `typeCheck` with our two new branches:

```scala
def typeCheck(expr: Expr, env: TypeEnv): Either[String, Type] = expr match
  case Num(value)             => Right(Type.Num)
  case Bool(value)            => Right(Type.Bool)
  case Add(lhs, rhs)          => checkAdd(lhs, rhs, env)
  case Gt(lhs, rhs)           => checkGt(lhs, rhs, env)
  case Cond(pred, t, e)       => checkCond(pred, t, e, env)
  case Var(name)              => checkVar(name, env)
  case Let(name, value, body) => checkLet(name, value, body, env)
```

We're almost done, all that's left is functions.

## Non-recursive functions

### `Function`

Function declarations have two components: the `name` of their parameter, and their `body`. The typing rules probably feel intuitive:
- _if_ `body` has type `Y` in an environment where variable `name` has type `X`.
- _then_ `Function name body` has type `X -> Y` (the function from `X` to `Y`).

This is easily translated into our syntax:

```
Γ[name <- X] |- body : Y
--------------------------------
Γ |- Function name body : X -> Y
```

The problem, however, comes when we try to write this in code. Where do we get `X` from? How do we bind `name` to a type we have no knowledge of?

This is where our desire to check programs for validity will start to have an impact on our language: since we don't know that type, we must ask program authors to provide it for us by annotating function parameters with types.

A potential syntax for this could be, for example:

```ocaml
(x : Int) -> x + 1
```

This forces us to rewrite the `Function` variant of `Expr` to add this parameter (I'll not rewrite all of `Expr`, it's starting to get quite big):

```scala
  case Function(param: String, paramType: Type, body: Expr)
```

With this new information, we need to rewrite our typing rules slightly:

```
Γ[name <- P] |- body : X
----------------------------------
Γ |- Function name P body : P -> X
```


With this new information, type checking `Function` becomes relative straightforward:

```scala
def checkFunction(name: String, p: Type, body: Expr, env: TypeEnv) =
  typeCheck(body, env.bind(name, p)).map { x => // Γ[name <- P] |- body : X
    Type.Function(p, x)                         // Γ |- Function name body : P -> X
  }
```

### `Apply`

We must now do the corresponding elimination form: `Apply`. `Apply` has two components, the function to apply and its argument, which type check as follows:
- _if_ `function` has type `X -> Y` for some types `X` and `Y`.
- _if_ `arg` has type `X`.
- _then_ `Apply function arg` has type `Y`.

This is easily translated in our syntax:

```
Γ |- function : X -> Y    Γ |- arg : X
--------------------------------------
Γ |- Apply function arg : Y
```

This appears relatively straightforward to turn into code, except for one detail: we don't really have a way to check whether an expression type checks to a function - at least not if we don't already know it's input and output types. `expect` expects an exact type, which we don't have here.

This is easily remedied:

```scala
def expectFunction(expr: Expr, env: TypeEnv): Either[String, Type.Function] =
  typeCheck(expr, env).flatMap {
    case f: Type.Function => Right(f)
    case other            => Left(s"Expected function, found $other")
  }
```

`expectFunction` fails if the specified expression doesn't evaluate to a function, and returns that function otherwise.

This allows us to turn our typing rules for `Apply` in some relatively clear code:

```scala
def checkApply(function: Expr, arg: Expr, env: TypeEnv) =
  expectFunction(function, env).flatMap {
    case Type.Function(x, y) => // Γ |- function : X -> Y
      expect(arg, x, env)       // Γ |- arg : X
        .map(_ => y)            // Γ |- Apply function arg : Y
  }
```

And to write an _almost_ complete type checker:

```scala
def typeCheck(expr: Expr, env: TypeEnv): Either[String, Type] = expr match
  case Num(value)                       => Right(Type.Num)
  case Bool(value)                      => Right(Type.Bool)
  case Add(lhs, rhs)                    => checkAdd(lhs, rhs, env)
  case Gt(lhs, rhs)                     => checkGt(lhs, rhs, env)
  case Cond(pred, t, e)                 => checkCond(pred, t, e, env)
  case Var(name)                        => checkVar(name, env)
  case Let(name, value, body)           => checkLet(name, value, body, env)
  case Function(param, paramType, body) => checkFunction(param, paramType, body, env)
  case Apply(function, arg)             => checkApply(function, arg, env)
```

## Recursive functions

Our final task is to type check `let rec` expressions. We have _almost_ all the tools we need to do so, and it's in fact a lot easier than interpreting them, but there is one problem.

A `let rec` expression is composed of the same elements as a `let` one: a `name`, a `value` to bind to that name, and a `body` in which the binding is legal.

What we want to express is the following:
- _if_ `value` has type `X` in an environment where variable `name` has type `X`.
- _if_ `body` has type `Y` in the same environment.
- _then_ `LetRec name value body` has type `Y`.

Or, more concisely:

```
Γ[name <- X] |- value : X    Γ[name <- X] |- body : Y
-----------------------------------------------------
Γ |- LetRec name (value : X) body : Y
```

But we're encountering the same problem as for functions: where does that `X` come from? We need to update our environment to say `name` has type `X`, but we don't have an `X` to use.
Additionally, we know that we want the `value` to be a function type (because `let rec` is only used to declare recursive functions in our language).

We'll need to apply the same solution as for functions: update the `LetRec` variant to include `value`'s type. This gives us the following declaration:

```scala
  case LetRec(name: String, value: Expr, valueType: Type.Function, body: Expr)
```

Note how `valueType` is not any type, but a `Type.Function`.

Armed with that new `LetRec`, we can express our typing rules:

```
Γ[name <- (I -> O)] |- value : I -> O    Γ[name <- (I -> O)] |- body : Y
------------------------------------------------------------------------
Γ |- LetRec name (value : I -> O) body : Y
```

And this is surprisingly easy to turn into code, with the only tricky part being to remember that everything must happen in an environment where `name` is bound to `valueType`:

```scala
def checkLetRec(name: String, value: Expr, valueType: Type.Function,
                body: Expr, env: TypeEnv) =
  val newEnv = env.bind(name, valueType)

  for
    _ <- expect(value, valueType, newEnv) // Γ[name <- (I -> O)] |- value : I -> O
    y <- typeCheck(body, newEnv)          // Γ[name <- (I -> O)] |- body : Y
  yield y                                 // Γ |- LetRec name (value : I -> O) body : Y
```

And after all that work, we can finally write our complete type checker:

```scala
def typeCheck(expr: Expr, env: TypeEnv): Either[String, Type] = expr match
  case Num(value)                       => Right(Type.Num)
  case Bool(value)                      => Right(Type.Bool)
  case Add(lhs, rhs)                    => checkAdd(lhs, rhs, env)
  case Gt(lhs, rhs)                     => checkGt(lhs, rhs, env)
  case Cond(pred, t, e)                 => checkCond(pred, t, e, env)
  case Var(name)                        => checkVar(name, env)
  case Let(name, value, body)           => checkLet(name, value, body, env)
  case LetRec(name, value, tpe, body)   => checkLetRec(name, value, tpe, body, env)
  case Function(param, paramType, body) => checkFunction(param, paramType, body, env)
  case Apply(function, arg)             => checkApply(function, arg, env)
```

## Testing our implementation

In order to test that everything we just did at least appears to behave as expected, let's take our old example of the recursive `sum` function and fix it to include the new type parameters for `LetRec` and `Function`.

The code would look something like:

```ocaml
let rec sum = (lower: Num) -> (upper: Num) ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10

```

Which translates to the following AST (you don't really have to read it all, it's a little noisy and you can just trust me):

```scala
val expr = LetRec(
  name  = "sum",
  valueType = Type.Function(Type.Num, Type.Function(Type.Num, Type.Num)),
  value = Function(
    param     = "lower",
    paramType = Type.Num,
    body      = Function(
      param     = "upper",
      paramType = Type.Num,
      body      = Cond(
        pred       = Gt(Var("lower"), Var("upper")),
        thenBranch = Num(0),
        elseBranch = Add(
          lhs = Var("lower"),
          rhs = Apply(
            function = Apply(Var("sum"), Add(Var("lower"), Num(1))),
            arg      = Var("upper"))
        )
      )
    )
  ),
  body = Apply(Apply(Var("sum"), Num(1)), Num(10))
)
```

We want this to type check to a number, since the sum of all numbers in a range is a number. And indeed:

```scala
typeCheck(expr, TypeEnv.empty)
// val res: Either[String, Type] = Right(Num)
```

## Where to go from here?

We've gained a reasonable understanding of how type checking worked, and can now check whether a program is not type correct.

This feels a little disappointing, however: it's still perfectly possible to represent invalid programs, we merely have given ourselves a tool to check that. It would be much better if we could somehow represent programs in a way that made illegal expressions impossible - in which adding a number and a boolean was not merely an error, but just not a notion that could exist.

We'll tackle this and typed ASTs next. This is likely to keep us busy for a little while, as this is far harder than anything we've done so far. But it's definitely worth it and quite a bit of fun!
