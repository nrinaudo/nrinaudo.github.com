---
title  : Producing a typed AST
layout : article
series : pl
date   : 20250115
code   : https://github.com/nrinaudo/programming_a_language/tree/main/typed_ast/src/main/scala/package.scala
---

We're done implementing a typed AST, `TypedExpr`, but don't yet know how to produce expressions in it. We could wave the problem away by declaring it the responsibility of the parser, but that's not how things are usually done. Commonly, the parser will produce an untyped AST which will then be refined by going through different compiler phases, one of which, type checking, may produce a typed AST.

We'll work on a new, improved type checker; one that produces a typed AST, rather than simply a `Type`. As usual, this will be done as an evaluator - a function that explores an `Expr` and produces... something. But exactly what that something is is worth a little bit of consideration.

## A new type checker

We know we ultimately want to produce a `TypedExpr` while allowing for failures. Not all expressions are well typed, which is rather the point. Something like:

```scala
def typeCheck(expr: Expr): Either[String, TypedExpr[?]] = ???
```

That `?` in `TypedExpr[?]` is Scala syntax for _there's a type there but we don't know what it is_ - technically, an _existential type_: the only thing we know about it is that it exists. And we cannot do any better than that, because there is nothing in `Expr` that tells us what type it will be. We must explore it at runtime to decide that. Statically, all we can say is, yes, there will be a type there, actually.

And that is problematic: we are, at some point, going to need to know exactly what that type is. Think of type checking $\texttt{Add}$, for example: we'll need to say that both operands are well-typed _and_ numbers. We'll need to be able to take a `TypedExpr[?]` and turn it into a `TypedExpr[Type.Num]` somehow.


### Introducing `Typing`


The intuition to follow here is that we are going to make expectations of types, expectations which can only be confirmed at runtime. Type checking $\texttt{Add}$, we'll get a `TypedExpr` of _something_, which we'll need to make sure is a number - and do so at runtime, the domain of values (where types are a purely static notion). Logically, we'll need some sort of value to act as a witness to the types we're manipulating.

We can do something like that by associating each `TypedExpr` with the corresponding type:

```scala
case class Typing[A <: Type](expr: TypedExpr[A], tpe: A)
```

And this feels like we're at least on the right track, doesn't it? If we have a `Type` that we successfully prove is equal to `tpe`, then it's a convincing proof that `expr` is also of that type.

We can put this in a method of `Typing`:

```scala
def cast[B <: Type](to: B): Either[String, Typing[B]] =
  this match
    case Typing(expr, `to`) => Right(Typing(expr, to))
    case Typing(_, other)   => Left(s"Expected $to, found $other")
```

Note the backquoted `to` in the pattern match: this is Scala syntax to say that we're comparing to the existing `to`, not declaring a new binding that shadows it.

Unfortunately, while our reasoning is sound, it's not convincing enough for the compiler, and it will reject `cast` with a type error. I'm unsure whether that's intended or a [flaw in the compiler](https://github.com/scala/scala3/issues/22405), but it's certainly how things stand using Scala 3.6.2.

Of course, if we're confident enough in our argument, we can always overrule the compiler with a call to `asInstanceOf` - but this really should be last resort. Telling the compiler to ignore its conclusions and trust ours instead is a bug waiting to happen, and even if our reasoning is sound _now_, it's one careless refactoring away from being completely daft. Better to rely on the compiler to confirm our proofs for us.

### GADTs to the rescue

Luckily, we can work around this with a little bit of boilerplate. See, Generalized Algebraic Data Types, or GADTs for short (loosely, _polymorphic sum types whose type parameters are more constrained in variants_) allow the compiler to do all sorts of interesting things during pattern matches - well, one thing, really, but with far reaching consequences: the compiler will be able to reason about types being equal, and draw conclusions from that.

Let's see how this helps us, it'll make things clearer. First, then, we'll write a GADT version of `Type` - a polymorphic sum type that mirrors `Type`:
```scala
enum TypeRepr[A <: Type]:
  case Num  extends TypeRepr[Type.Num]
  case Bool extends TypeRepr[Type.Bool]
  case Fun[A <: Type, B <: Type](
    from: TypeRepr[A],
    to: TypeRepr[B]
  ) extends TypeRepr[A -> B]
```

`TypeRepr` is a sum type (that's what `enum` does), it is polymorphic (it has a type parameter), and its variants constraint that parameter:
- `Num` forces it to `Type.Num`.
- `Bool` forces it to `Type.Bool`.
- `Fun[A, B]` forces it to `A -> B`.

All the ingredients are here. Let's try replacing `Type` with `TypeRepr` in `Typing` and see what happens.

```scala
case class Typing[A <: Type](expr: TypedExpr[A], repr: TypeRepr[A]):
  def cast[B <: Type](to: TypeRepr[B]): Either[String, Typing[B]] =
    this match
      case Typing(expr, `to`) => Right(Typing(expr, to))
      case Typing(_, other)   => Left(s"Expected $to, found $other")
```

And yes, this does compile. Trough the magic of GADTs, the compiler has been able to conclude that:
- `to` being equal to `repr` means they're of the same type (which is maybe a [slightly hasty](https://users.scala-lang.org/t/overriding-the-equals-method-leads-to-values-being-assigned-an-incorrect-type/10520) conclusion to draw).
- `TypeRepr[A] = TypeRepr[B]` implies `A = B` (`TypeRepr` being, like most type constructors, an [injective function](https://en.wikipedia.org/wiki/Injective_function)).
- `A = B` implies `TypedExpr[A] = TypedExpr[B]` (because type equality is [congruent](https://en.wikipedia.org/wiki/Congruence_relation#General)).
- `expr`, being a `TypeExpr[A]`, is then a valid `TypedExpr[B]` as well and can be used wherever one is expected.

Which I think is all kinds of wonderful! The first time I started playing with values describing types to safely cast from one type to another at runtime felt slightly odd and wrong, but also incredibly fun.

If you've followed all this, or at least got the general idea, you can relax now. This was the hard part of this article. The rest is merely going to be sprucing up [our first type checker](./type_checking.html) to accommodate `Typing`.


### Type environment

We've written a type checker before. We know we'll eventually need a [type environment](./type_checking.html#environment) - a place in which to store which type a binding references. So let's write one now and be done with it.

The one difference from the type checker we [already wrote](./type_checking.html#TypeEnv) is that we're no longer tracking `Type` as our main "unit" of typing, but `TypeRepr`:

```scala
class TypeEnv (env: List[TypeEnv.Binding])

object TypeEnv:
  case class Binding(name: String, repr: TypeRepr[?])

  val empty = TypeEnv(List.empty)
```

### Putting it all together

We now know exactly what `typeCheck` must look like:
- it must take an `Expr` to type check.
- it must take a `TypeEnv` in which to look bindings up.
- it must return a `Typing[?]`, because it cannot know what type an expression has until after having type checked it.
- it must allow for failure, because not all `Expr`s are well typed.

Which gives us:

```scala
def typeCheck(expr: Expr, Γ: TypeEnv): Either[String, Typing[?]] =
  ???
```

We'll now focus on filling out these `???` by type checking all `Expr` variants. Note that this will be _extremely_ similar to our previous type checker, so I wouldn't necessarily recommend reading through all of them. It's probably ok to sort of skim through the rest of this article, maybe paying a little more attention if something catches your fancy. But we're really only revisiting existing code and replacing `Type` with `Typing` and `TypeRepr`.

## Typing literal values

[Typing literal values](./type_checking.html#typing-literal-values) was trivial: a simple matter of returning the corresponding type, because literal cannot be ill-typed.

We merely need adapt the [code we wrote](./type_checking.html#literals) then to return a `Typing` rather than a `Type`, which offers no challenge:

```scala
  case Expr.Num(value)  => Right(Typing(Num(value), TypeRepr.Num))
  case Expr.Bool(value) => Right(Typing(Bool(value), TypeRepr.Bool))
```

## Typing `Add`

If you'll recall, the first thing we had to do when [type checking $\texttt{Add}$](./type_checking.html#typing-add) was to write [`expect`](./type_checking.html#expect), a function that confirms an expression is of the expected type. We'll start by adapting that.

The necessary changes shouldn't be much of a surprise, for the most part:
- replace `Type` with `TypeRepr`.
- wrap the result in a `Typing` to expose both the type and the well-typed `TypedExpr` value.

The latter is made very simple by our having already written `cast`:

```scala
def expect[A <: Type](expr: Expr, tpe: TypeRepr[A], Γ: TypeEnv) =
  for raw   <- typeCheck(expr, Γ)
      typed <- raw.cast(tpe)
  yield typed
```

Now that we have a working `expect`, we can adapt [`checkAdd`](./type_checking.html#checkAdd) by following the exact same process we used for literals:

```scala
def checkAdd(lhs: Expr, rhs: Expr, Γ: TypeEnv) =
  for lhs <- expect(lhs, TypeRepr.Num, Γ)
      rhs <- expect(rhs, TypeRepr.Num, Γ)
  yield Typing(Add(lhs.expr, rhs.expr), TypeRepr.Num)
```

You might notice (and disagree with!) a convention I use here: I will reuse a variable's name when it represents exactly the same thing, only "better". Here, for example, `lhs` is initially the untyped left-hand-side operand, but becomes its typed version in the for-comprehension. Binding shadowing is a controversial subject, some people love it, some people hate it, and I find myself somewhere in the middle. I'd argue it's often confusing but sometimes useful, and `checkAdd` is a fairly good example of the latter. We're calling the same thing by the same name, and avoiding artificial ones like `typedLhs` or `maybeLhs` or some other unpleasant variation on Hungarian notation.

## Typing `Gt`

$\texttt{Gt}$ is very similar to $\texttt{Add}$ and uses the same tools. We can adapt [what we wrote before](./type_checking.html#checkGt) quite easily:

```scala
def checkGt(lhs: Expr, rhs: Expr, Γ: TypeEnv) =
  for lhs <- expect(lhs, TypeRepr.Num, Γ)
      rhs <- expect(rhs, TypeRepr.Num, Γ)
  yield Typing(Gt(lhs.expr, rhs.expr), TypeRepr.Bool)
```

## Typing conditionals

We saw [earlier](./type_checking.html#checkCond) that $\texttt{Cond}$ introduces a new wrinkle by asking us to keep track of the type of each branch and making sure they were the same.

That's not much of a problem to adapt, however: we get that type information from the `Typing` returned by `typeCheck`:

```scala
def checkCond(pred: Expr, onT: Expr, onF: Expr, Γ: TypeEnv) =
  for pred <- expect(pred, TypeRepr.Bool, Γ)
      onT  <- typeCheck(onT, Γ)
      onF  <- expect(onF, onT.repr, Γ)
  yield Typing(Cond(pred.expr, onT.expr, onF.expr), onT.repr)
```

The only subtlety here is that we call `typeCheck` on `onT`, but `expect` on `onF` - one tells us which type both branches should be, and the other confirms that they are.

## Typing bindings

### Binding introduction

$\texttt{Let}$ only adds one new problem: environment management. We already [adapted `TypeEnv`](#type-environment) however, so most of the hard work has already been done.

We'll first need to rework `TypeEnv`'s [`bind`](./type_checking.html#bind) method, which is really only replacing `Type` with `TypeRepr`:

```scala
def bind(name: String, repr: TypeRepr[?]) =
  TypeEnv(TypeEnv.Binding(name, repr) :: env)
```

Note that we're working with a `TypeRepr[?]`, not a `TypeRepr[A]` for some `A`. Our environment does not keep track of things that precisely, at least not yet. Nor does it need to, really: we have `cast` to transform something of an unknown type into a known one.

We can now adapt [`checkLet`](./type_checking.html#checkLet):

```scala
def checkLet(name: String, value: Expr, body: Expr, Γ: TypeEnv) =
  for value <- typeCheck(value, Γ)
      body  <- typeCheck(body, Γ.bind(name, value.repr))
  yield Typing(Let(name, value.expr, body.expr), body.repr)
```

### Binding elimination

$\texttt{Ref}$ is more of the same. As before, it's merely an environment lookup.

We'll first need to rework [`lookup`](./type_checking.html#lookup), although the changes are extremely slight: `Binding`'s `tpe` field is now called `repr`.

```scala
def lookup(name: String) =
  env
    .find(_.name == name)
    .map(_.repr)
    .toRight(s"Type binding $name not found")
```

And then [`checkRef`](./type_checking.html#checkRef) is simply a matter of wrapping the `TypeRepr` we found in the environment inside of the correct `Typing`.

```scala
def checkRef(name: String, Γ: TypeEnv) =
  Γ.lookup(name)
   .map(repr => Typing(Ref(name), repr))
```


## Typing functions
### Function introduction

Function introduction, $\texttt{Fun}$, is maybe a little trickier. If you [recall](./type_checking.html#function-introduction), we had to store a `Type` in our `Expr.Fun` to know the type of the function's parameter. This will give us a bit of work here, since we're no longer working with `Type` but with `TypeRepr`. We'll need to be able to go from the former to the latter.

There's no real difficulty, however. We can write the `from` method on `TypeRepr`'s companion object as a simple recursive pattern match:
```scala
def from(tpe: Type): TypeRepr[?] = tpe match
  case Type.Bool      => TypeRepr.Bool
  case Type.Num       => TypeRepr.Num
  case Type.Fun(a, b) => TypeRepr.Fun(TypeRepr.from(a), TypeRepr.from(b))
```

Note, again, the existential type. We _know_ that any type maps to a `TypeRepr` of something, we just don't know what that something is. And yes, I wish I could convince the compiler that it must be a `TypeRepr` of the same type as `tpe`, but I've not found a way of coaxing it into accepting that.

Having `from`, we can easily update [checkFun](./type_checking.html#checkFun):

```scala
def checkFun(param: String, x: Type, body: Expr, Γ: TypeEnv) =
  val xRepr = TypeRepr.from(x)

  for body <- typeCheck(body, Γ.bind(param, xRepr))
  yield Typing(Fun(param, body.expr), xRepr -> body.repr)
```

### Function elimination

$\texttt{Apply}$ is, again, a little more involved. [We had](./type_checking.html#function-elimination) to confirm the expression being applied was indeed a function and fail otherwise. But that's really the only hurdle, and we've already solved it, making the adaptation of [`checkApply`](./type_checking.html#checkApply) easy enough:

```scala
def checkApply(fun: Expr, arg: Expr, Γ: TypeEnv) =
  typeCheck(fun, Γ).flatMap:
    case Typing(fun, x -> y) =>
      expect(arg, x, Γ).map: arg =>
        Typing(Apply(fun, arg.expr), y)

    case Typing(_, other) => Left(s"Expected a function, found $other")
```

## Typing recursion

We finally get to recursion, $\texttt{LetRec}$, the last term of our language. We [didn't particularly struggle](./type_checking.html#typing-recursion) with that earlier, and the new version does not use anything new. We merely need to be mindful that we were, again, working with a `Type` to describe the recursive value, and that needs to be turned into a `TypeRepr`.

Other than that, adapting [`checkLetRec`](./type_checking.html#checkLetRec) is very straightforward:

```scala
def checkLetRec(name: String, value: Expr, x: Type, body: Expr, Γ: TypeEnv) =
  val xRepr = TypeRepr.from(x)
  val Γʹ    = Γ.bind(name, xRepr)

  for
    value <- expect(value, xRepr, Γʹ)
    body  <- typeCheck(body, Γʹ)
  yield Typing(LetRec(name, value.expr, value.repr, body.expr), body.repr)
```


## Testing our implementation

We'll use exactly the same test for this as we did for our previous type checker: [`sum`](type_checking.html#sum), which adds all the numbers in a given range, and whose code is:

```ocaml
let rec (sum: Num -> Num -> Num) = (lower: Num) -> (upper: Num) ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10
```

We want this to type check to a `TypedExpr[Type.Num]`, which is exactly what we get:

```scala
for checked <- typeCheck(sum, TypeEnv.empty)
    typed   <- checked.cast(TypeRepr.Num)
yield typed.repr
// val res: Either[String, TypeRepr[Type.Num]] = Right(Num)
```

## Where to go from here?

Now that we know how to go from an AST to a typed AST, we need to rewrite our interpreter to take a `TypedExpr`. As in this article, it will involve a couple of tricky and fun type shenanigans but, once worked out, everything just sort of falls into place without much work.
