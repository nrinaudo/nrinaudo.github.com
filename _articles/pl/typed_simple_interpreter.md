---
title  : Interpreting a typed AST
layout : article
series : pl
date   : 20250122
---

We now have a (mostly) typed AST, [`TypedExpr`](./typed_simple_ast.html), and the [means of representing](./typed_simple_type_checker.html) programs in it. The next logical step is to write an interpreter for that AST, which will require a little finesse but I think will ultimately prove very satisfying.

And, as usual, we must start by wondering what kind of value the interpreter will return.

## A new interpreter

As [before](typed_simple_type_checker.html#a-new-type-checker), we're going to start by thinking about the signature of our new interpreter.

We know it'll look roughly like this:

```scala
def interpret[A <: Type](expr: TypedExpr[A], e: Env): ???
```

The entire point is to interpret a `TypedExpr`, so of course we'll take one. And we also know that we need to store bindings in an environment, so we'll take that too. The question is, what should we return?

### Typed values

The reason we wrote `TypedExpr` was to make it impossible to represent a certain kind of invalid programs: the programs whose types don't line up properly. We achieved this by indexing it with the type it would be interpreted as - or, in plainer English, a `TypedExpr[A]` describes an expression that will interpret to some `A`.

We've also made it a constraint that `TypedExpr` was indexed using `Type`, which I find quite elegant: there's a clear distinction between the host language's types and those of our language. But here, we want to get rid of that distinction: the entire point is to interpret an expression into values of the host language!

Scala has a rather convenient tool for mapping types to other types: [_match types_](https://docs.scala-lang.org/scala3/reference/new-types/match-types.html). We can use them to write the obvious mapping:

```scala
type Value[X] = X match
  case Type.Num  => Int
  case Type.Bool => Boolean
  case a -> b    => Value[a] => Value[b]
```

Most of this is intuitive. We want, for example, to interpret a `TypedExpr[Type.Num]` to a Scala `Int`. But maybe functions bear a little more explaining. Why is `Value` present in the right-hand side of the match statement?

If you think about it however, it makes sense. A function from numbers to booleans has type `Type.Num -> Type.Bool`. We do not want to interpret such an expression to `Type.Num => Type.Bool`, but to `Int => Boolean`, do we not? Which is why we must recursively map the type parameters of a `Type.Fun` to their host language's equivalent.

We now have a better idea of what we would like our interpreter to look like:

```scala
def interpret[A <: Type](expr: TypedExpr[A], e: Env): Value[A]
```

This is unfortunately not completely finished yet.

### Error handling

If you remember, we saw that `TypedExpr` has [a major flaw](./typed_simple_ast.html#limitation): it doesn't know anything about the environment. It stands to reason then that it cannot force any environment it's working in to be healthy - to contain the expected bindings, with the expected types.

We can do our best to enforce this by populating the environment sanely, but unfortunately, that's not going to be enough to convince anyone, least of all the type checker: we are going to have to deal with the consequences of looking up a binding that does not exist. Which is to say, `interpret` must have errors baked into its return type, which we'll do with the usual `Either` potentially containing a human readable error message:

```scala
def interpret[A <: Type](expr: TypedExpr[A], e: Env): Either[String, Value[A]]
```

Now that we've done all that preparatory work, things are going to be smooth sailing for a little while. In fact, anything that isn't involved with the environment is going to be almost trivial.

## Interpreting literals

We shall start, as usual, we literals. These don't require anything particular: they contain a value, we can merely return it. That's really all there is to it:

```scala
def interpret[A <: Type](expr: TypedExpr[A], e: Env): Either[String, Value[A]] =
  expr match
    case Bool(value) => Right(value)
    case Num(value)  => Right(value)
```

I don't know how you feel about this, but to me, it seems almost magical. We're merely returning the wrapped value, and the compiler does all the work of making sure everything lines up and just accepts it. I might be easily impressed, but there's something wonderfully simple and straightforward about it.

## Interpreting `Add`

[$\texttt{Add}$](./ast.html#runAdd) is also, well... essentially what you wish it were, if the compiler would but cave in to your every wish. Let's see the result before explaining it:

```scala
def runAdd(lhs: TypedExpr[Type.Num], rhs: TypedExpr[Type.Num], e: Env) =
  for lhs <- interpret(lhs, e)
      rhs <- interpret(rhs, e)
  yield lhs + rhs
```

Yes, it is that simple. Both operands are `TypedExpr[Type.Num]`, which means we know they interpret to `Value[Type.Num]` - which really is just `Int`. We can simply add them.

There is the slight annoyance of having to do this in a for-comprehension. We'll address this a little later when we also make sure a `TypedExpr` cannot be interpreted in an environment that doesn't contain the expected bindings.

## Interpreting `Gt`

[$\texttt{Gt}$](./recursion.html#runGt) is pretty much the same thing as $\texttt{Add}$, except we compare numbers rather than sum them:

```scala
def runGt(lhs: TypedExpr[Type.Num], rhs: TypedExpr[Type.Num], e: Env) =
  for lhs <- interpret(lhs, e)
      rhs <- interpret(rhs, e)
  yield lhs > rhs
```

## Interpreting conditionals

This takes us to the last of the "easy" ones, [$\texttt{Cond}$](./conditionals.html#runCond). There really isn't anything special about it, aside from the unfortunate number of parameters:

```scala
def runCond[X <: Type](
  pred: TypedExpr[Type.Bool],
  onT : TypedExpr[X],
  onF : TypedExpr[X],
  e   : Env
) =
  interpret(pred, e).flatMap:
    case true  => interpret(onT, e)
    case false => interpret(onF, e)
```

## Interpreting bindings

We are now entering the slightly more complicated part of this article: all the terms that involve the environment in one way or another.


### Binding elimination

You'll remember that [binding elimination](./bindings.html#runRef), $\texttt{Ref}$, is merely looking at what the environment contains for a given name. It is, however, a little more complicated here: we cannot return just any old value, it must be a value of the right type.

We'll want something like this:

```scala
def runRef[X <: Type](name: String, e: Env): Either[String, Value[X]]
```

This tells us a few things. First, `Env` will need to be updated to contain `Value`, because that's what we want to find in there. Second, we have a big problem. We cannot know that the environment contains a `Value[X]` for the specified name. It may not contain anything, but that's really not an issue, we can always return a `Left`. No, the problematic scenario is if it does contain something: that'll be a `Value[Y]`, and we'll need to convince the compiler that `X` and `Y` are the same type.


### `Eq`

We've already seen at least a hint of how to achieve this: [GADTs](./typed_simple_type_checker.html#gadts-to-the-rescue). If you'll recall, we've learned that their defining property was allowing the compiler to conclude two types were equal and thus could be used interchangeably. This sounds awfully similar to what we're trying to achieve here, doesn't it.

The prototypical GADT, the one that rules them all, as it were, is `Eq`. It embodies type equality, in that `Eq[A, B]` is a proof that types `A` and `B` are the same. I've [been told](https://scala.io/talks/intro-to-gadts), and have reasons to believe (although I've yet to confirm it for myself) that all GADTs can be implemented with `Eq`.

`Eq` is defined in a way that may seem a little odd at first:

```scala
enum Eq[A, B]:
  case Refl[A]() extends Eq[A, A]
```

It has a single variant, `Refl` (for _reflexivity_), which tells us that any `A` is equal to itself. This seems both obvious and a little useless, but you have to remember that it's possible to manipulate runtime type witnesses - `TypedRepr`, in our case. We'll explore this a little more in depths in a short while, but think of attempting to prove that two types are equal given a `TypeRepr` of each - `a` for `TypeRepr[A]`, say,  and `b` for `TypeRepr[B]`.

The following (non-exhaustive) pattern match produces an `Eq[A, B]`:

```scala
(a, b) match
  case (TypeRepr.Num, TypeRepr.Num) => Eq.Refl()
    // ...
```

We'll make it exhaustive soon enough, but first... how does this even work? Well, let us think it through. `TypeRepr.Num` is a `TypeRepr[Type.Num]`, which allows the compiler to deduce that in that branch of the pattern match, `TypeRepr[A]` and `TypeRepr[B]` are both `TypeRepr[Type.Num]`. `TypeRepr`, like most type constructors, is an [injective function](https://en.wikipedia.org/wiki/Injective_function), leading the compiler to conclude that `A` and `B` are both `Type.Num`. An `Eq[A, B]` is then the same thing as an `Eq[Type.Num, Type.Num]`, which we can produce with `Eq.Refl()`.

We've got our hands on an `Eq[A, B]`. Wonderful. But what good does it do us?

Again, consider that most important property of GADTs: allowing the compiler to conclude types are equal. If it can be convinced that `A` and `B` are the same, it will allow us to use a `B` where an `A` is expected. Yes, I am in fact talking about perfectly safe, statically checked runtime casts. Something like the following `Eq` method:

```scala
def cast(a: A): B = this match
  case Refl() => a
```

If you remember, the reason we started talking about `Eq` was because we had a `Value[A]` and wanted to convince the compiler it was an acceptable `Value[B]`. All we need to do that is an `Eq[Value[A], Value[B]]`. And we have the intuition that given a `TypeRepr[A]` and `TypeRepr[B]`, we might be able to produce an `Eq[A, B]`. As it turns out, this is all we need! Well, that, and knowing about [_congruence_](https://en.wikipedia.org/wiki/Congruence_relation#General), a nice little property of `Eq` that allows to write the following method:

```scala
def congruence[F[_]]: Eq[F[A], F[B]] = this match
  case Refl() => Refl()
```

That is, given an `Eq[A, B]`, we can produce an `Eq[F[A], F[B]]` for any `F` - which of course means we can produce it for `Value`. This is exactly the result we were hoping for, but we have yet to produce that initial `Eq[A, B]`.


### Using `TypeRepr` to prove equality

Our intuition was that we could produce an `Eq` from two `TypeRepr`. This intuition is going to prove correct, even if maybe a little more work than we'd hope for.

A large chunk of it is rather obvious, so let's start there:


```scala
def from[A <: Type, B <: Type](
  a: TypeRepr[A],
  b: TypeRepr[B]
): Either[String, Eq[A, B]] =
  (a, b) match
    case (TypeRepr.Num, TypeRepr.Num)   => Right(Eq.Refl())
    case (TypeRepr.Bool, TypeRepr.Bool) => Right(Eq.Refl())
    case _                              => Left(s"Failed to prove $a = $b")
```

That is: given two `TypeRepr`, we can easily prove that if they're both numbers or both booleans, than `A` and `B` are equal. Otherwise, they're not and we fail with a `Left`. This was all very easy, but that's only because we've been very careful to avoid thinking about functions...


The general idea goes like this: if we have two functions, we need to prove that their domains are equal, and that their codomains are equal. This will be simple enough, `TypeRepr.Fun` stores domains and codomains as `TypeRepr`, allowing us to check for equality by recursively calling `from`. And once we have these equalities, well... Well, we can use my usual strategy when working with type equalities: throw all the `Eq` values you have in a pattern match and let the compiler sort them out. There's probably something more subtle to be done here, but it works and merely needs a type ascription to give the compiler that little extra push it needs to get over the finishing line:

```scala
case (aFrom -> aTo, bFrom -> bTo) =>
  for eqFrom <- from(aFrom, bFrom)
      eqTo   <- from(aTo, bTo)
  yield ((eqFrom, eqTo) match
    case (Refl(), Refl()) => Refl()
  ): Eq[A, B]
```

And with that, we have finished writing `Eq.from`, which produces an `Eq[A, B]` from a `TypeRepr[A]` and `TypeRepr[B]`. Combining this with our `congruence` method, we can now safely cast a `Value[A]` into a `Value[B]`!

### Back to binding elimination

At this point, we have a pretty good idea how to do binding elimination: given a `Ref[A]`, find the corresponding `Value[B]` contained in the environment, acquire an `Eq[A, B]`, and we're essentially done.

The problem, however, is that in order to get that `Eq[A, B]`, we'll need a `TypeRepr[A]` and a `TypeRepr[B]`, and we currently have no way of getting either. We'll need to do something about that.

First, we'll need to update `Ref` to hold a `TypeRepr`:
```scala
case Ref[A <: Type](
    name: String,
    rType: TypeRepr[A]
) extends TypedExpr[A]
```

This also involves a modification of the type checker, but it's a trivial one that we won't bother writing out here.

Then comes the last large amount of work we need to do in this chapter: adapting `Env` to work with `Value` and `TypeRepr`. Since we want both of them to be indexed on the same type (we want `Value[A]` and `TypeRepr[A]` for the same `A`), we'll create a type for that:

```scala
case class TypedValue[A <: Type](value: Value[A], repr: TypeRepr[A])
```

We can go one step further and also bake in the ability to get the underlying value in the type we want:

```scala
def as[B <: Type](to: TypeRepr[B]): Either[String, Value[B]] =
  Eq.from(repr, to)
    .map(_.congruence[Value].cast(value))
```

Finally, we'll need to update `Binding` to associate a name to a `TypedValue`:

```scala
case class Binding(name: String, var value: TypedValue[?] | Null)
```

You'll of course remember we needed the value to be both nullable and mutable to [support recursion](./recursion.html#binding).


Note how we cannot say for sure what kind of `TypedValue` we're holding: a binding may reference _any_ kind of value! But since we have a `TypeRepr`, that's really not much of an issue, as we can always attempt to cast it to the type we need it to be.

Before we can finally adapt `lookup` to our new requirements, we'll need to write one final helper function: one that finds a binding, or fails with a `Left`. We're no longer throwing exceptions when encountering errors, so this will come in handy:

```scala
def find(name: String) =
  env.find(_.name == name)
     .toRight(s"Binding not found: $name")
```

There. All the groundwork is finally done, and we can write [`lookup`](./bindings.html#env), a method on `Env` that looks for a binding with a non-null value of the desired type:

```scala
def lookup[A <: Type](name: String, repr: TypeRepr[A]) =
  for Env.Binding(_, v) <- find(name)
      rawValue          <- Option.fromNullable(v)
                                 .toRight(s"Expected a $repr but found null")
      value             <- rawValue.as(repr)
  yield value
```

And at long last, we can declare that [$\texttt{Ref}$](./bindings.html#runRef) interprets to whatever the environment contains _provided it's of the right type_:

```scala
def runRef[X <: Type](name: String, rType: TypeRepr[X], e: Env) =
  e.lookup(name, rType)
```

### Binding introduction

$\texttt{Let}$ is going to require us to change our existing code again, but only a little this time. We've seen that `Env` needed to store a `Value` _and_ the corresponding `TypeRepr`, which we do not have a way of getting yet. This requires updating [`Let`](./typed_simple_ast.html#let) to store the type of the bound value:


```scala
case Let[A <: Type, B <: Type](
  name: String,
  value: TypedExpr[A],
  vType: TypeRepr[A],
  body: TypedExpr[B]
) extends TypedExpr[B]
```

We'll also need to change `Env`'s [`bind`](./bindings.html#env) method to work with `TypedValue`, since that is what the environment now stores:

```scala
def bind[A <: Type](name: String, value: TypedValue[A] | Null): Env =
  Env(Env.Binding(name, value) :: env)
```

That's really all we needed in order to adapt [`runLet`](bindings.html#runLet), which we can now turn into a tight for-comprehension:

```scala
def runLet[X <: Type, Y <: Type](
  name : String,
  value: TypedExpr[X],
  vType: TypeRepr[X],
  body : TypedExpr[Y],
  e    : Env
) =
  for value <- interpret(value, e)
      body  <- interpret(body, e.bind(name, TypedValue(value, vType)))
  yield body
```

## Interpreting functions

If you've managed to make it all the way here, the good news is that you got through the hard part. `Eq`, and using it in the environment, were the really tricky bits of this article. We still have a few adjustments to make here and there, but things are now going to be rather straightforward for the most part.

### Function introduction

Adapting $\texttt{Fun}$ is easy enough. We need to return a `Value[X -> Y]`, which really is a `Value[X] => Value[Y]`, and have already written all the moving bits. We can simply bind the argument to the right name and interpret the body in the newly defined environment. But... well, in order to call `bind`, we need the type of the argument as a `TypeRepr`, which means we need to update [`TypeRepr.Fun`](./typed_simple_ast.html#fun) to include it:

```scala
case Fun[A <: Type, B <: Type](
    param: String,
    pType: TypeRepr[A],
    body: TypedExpr[B]
) extends TypedExpr[A -> B]
```

This allows us to adapt [`runFun`](./functions#runFun) to our typed AST in a most straightforward way:

```scala
def runFun[X <: Type, Y <: Type](
  param: String,
  pType: TypeRepr[X],
  body : TypedExpr[Y],
  e    : Env
) =
  Right: (x: Value[X]) =>
    interpret(body, e.bind(param, TypedValue(x, pType)))
```

But, because of course there's a but, did you notice the problem? `interpret` does not return a `Value[Y]`, unfortunately, but an `Either[String, Value[Y]]`. Since `TypedExpr` does not encode the environment, interpretation may still fail. This is telling us that, unfortunately, we must update `Value[X -> Y]` to return an `Either`:

```scala
  case a -> b => Value[a] => Either[String, Value[b]]
```

That small modification aside, we're done with function introduction. And isn't it a little wonderful? We can now interpret functions defined in our language to Scala functions. Something about this is delightful to me, and I couldn't stop grinning for a while after I'd realised what I'd created.

### Function elimination

$\texttt{Apply}$ is one of the easy ones. It does not involve the environment in any way, and adapting our [existing work](./functions.html#runApply) yields simpler code thanks to all the types already being guaranteed to line up:

```scala
def runApply[X <: Type, Y <: Type](
  fun: TypedExpr[X -> Y],
  arg: TypedExpr[X],
  e  : Env
) =
  for fun <- interpret(fun, e)
      arg <- interpret(arg, e)
      y   <- fun(arg)
  yield y
```

## Interpreting recursion

The only term we still need to handle is $\texttt{LetRec}$, which is going to require a little bit of work, but nothing too strenuous.

The first thing is that we know we're going to need to create a binding for the recursive value, and we know this will require knowing its type at runtime, as a `TypeRepr`. [`LetRec`](./typed_simple_ast.html#letrec) doesn't contain that information, and we'll need to update it accordingly:

```scala
case LetRec[A <: Type, B <: Type](
    name: String,
    value: TypedExpr[A],
    vType: TypeRepr[A],
    body: TypedExpr[B]
) extends TypedExpr[B]
```

We'll also need to update [`Env.set`](./recursion.html#set) to take a `TypedValue`, since this is what the environment now stores:

```scala
def set[A <: Type](name: String, value: TypedValue[A]) =
  find(name)
    .map(_.value = value)
```

Having done these minor updates, we can easily fix [`runLetRec`](./recursion.html#runLetRec) to handle `TypedExpr`:

```scala
def runLetRec[X <: Type, Y <: Type](
  name : String,
  value: TypedExpr[X],
  vType: TypeRepr[X],
  body : TypedExpr[Y],
  e    : Env
) =
  val eʹ = e.bind(name, null)

  for value <- interpret(value, eʹ)
      _     <- eʹ.set(name, TypedValue(value, vType))
      body  <- interpret(body, eʹ)
  yield body
```

## Testing our implementation

We've adapted our interpreter to work with `TypedExpr`, and all that remains is to check whether it works. We'll again take [`sum`](./recursion.html#updating-the-ast), which computes the sum of all numbers between 1 and 10:

```scala
for checked <- typeCheck(sum, TypeEnv.empty)
    typed   <- checked.cast(TypeRepr.Num)
    result  <- interpret(typed, Env.Empty)
yield result
// val res: Either[String, Int] = Right(55)
```

You'll note how we not only get the right value, but also in a more useful type than [before](./recursion.html#updating-the-interpreter): where we used to get something that needed to be pattern matched on, we now get the unwrapped, well-typed value directly.


## Where to go from here?

We have a fully working typed AST. Writing the interpreter required some fairly advanced type shenanigans (match types, GADTs, type equalities...), for a payoff that can be argued to be a little underwhelming: while we have made an entire class of errors impossible, there are still loopholes. We can see them concretised by the interpreter's return type: it must make provision for runtime failures.

Our next step, then, will be to close these loopholes by encoding the environment in which an expression must be executed in its type. Which, yes, will again require some measure of deviousness with our types, but is perfectly doable and quite a bit of fun.
