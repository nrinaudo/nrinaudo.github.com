---
title: Repeating actions
layout: article
series: pl
date:   20240713
---

One thing our language still lacks is the ability to repeat an action multiple times. This is typically necessary to compute things over ranges of numbers (or lists or queues or...).

One could, for example, wish to sum all numbers in a given range. There are various ways of going about this, but one I'm particularly fond of is in a _declarative_ fashion - that is, by describing the problem, and having that sort of magically turn into the solution to the problem itself. The description of a sum over a range could be described as:
- if the range is empty, then the sum of its elements is `0`.
- otherwise, it is the first element of the range, added to the sum of all the other elements.

This translates nicely into code using our syntax:

```ocaml
let sum = lower -> upper ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10
```

And this shows us a very convenient way of repeating an action: we're repeatedly adding numbers in a range, by... well, by doing something a little odd. We're having `sum` call itself. `sum` is called a _recursive_ function, and it feels like something we'd quite like to implement in our language.

## A note on "standard" loops

Repeating actions is also traditionally done using _imperative_ loops:
- `for`, used to repeat an action a set number of times.
- `while`, used to repeat an action an arbitrary number of times.

Both these loops inherently rely on mutability. For example, here's `sum` expressed as a `for` loop:

```ocaml
fun sumFor lower upper =
  var acc = 0
  for i = lower to upper do
    acc = acc + i
  acc
```

We must rely on `acc` to accumulate our result, because `for` loops do not evaluate to a value - they just repeat an action.

We will avoid implementing `for` and `while` here for a variety of reasons:
- they do not evaluate to a value. Our entire substitution model is based on expressions that do. This looks like a headache.
- they require mutability. Supporting this (or explicitly deciding not to) is a major design decision that I want to postpone until we don't have a choice.
- it is possible to mechanically rewrite them as recursive functions.

That last point is probably the most salient: since we can write software that turns `for` and `while` loops into recursive functions automatically, then we can view them as mere syntactic sugar. If we decide our language needs them after all, they can simply be features of the user facing language, and turned in recursive functions during parsing. Our AST needs never be aware of them.


## Do we already support recursion?

You might be tempted to think we already support recursive functions - after all, we support `let` bindings and functions, which appear to be all that `sum` needs to work.

Let's confirm this by actually implementing `sum` in our language. We lack something for that, however. Look at the code for `sum` again:

```ocaml
let sum = lower -> upper ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10
```

We need to compare `lower` and `upper`, which our language does not support yet. We can easily fix that, however. First, we'll need a new AST variant, which is very similar to `Add`: a binary operator that takes two expressions.

```scala
  case Gt(lhs: Expr, rhs: Expr)
```

This gives us the following `Expr` implementation:

```scala
enum Expr:
  case Num(value: Int)
  case Bool(value: Boolean)
  case Add(lhs: Expr, rhs: Expr)
  case Gt(lhs: Expr, rhs: Expr)
  case Cond(pred: Expr, thenBranch: Expr, elseBranch: Expr)
  case Let(name: String, value: Expr, body: Expr)
  case Var(name: String)
  case Function(param: String, body: Expr)
  case Function(function: Expr, arg: Expr)
```

We also need to update our interpreter to support it. The logic is straightforward and very similar to what we did for `Add`: evaluate both operands, make sure they’re both numbers, and test whether one is greater than the other.

```scala
def gt(lhs: Expr, rhs: Expr, env: Env) =
  (interpret(lhs, env), interpret(rhs, env)) match
    case (Value.Num(lhs), Value.Num(rhs)) => Value.Bool(lhs > rhs)
    case _                                => sys.error("Type error in gt")
```

Which allows us to update `interpret`:

```scala
def interpret(expr: Expr, env: Env): Value = expr match
  case Num(value)                => Value.Num(value)
  case Bool(value)               => Value.Bool(value)
  case Add(lhs, rhs)             => add(lhs, rhs, env)
  case Gt(lhs, rhs)              => gt(lhs, rhs, env)
  case Cond(pred, t, e)          => cond(pred, t, e, env)
  case Var(name)                 => env.lookup(name)
  case Let(name, value, body)    => let(name, value, body, env)
  case Function(param, body      => Value.Function(param, body, env)
  case Apply(function, arg)      => apply(function, arg, env)
```

And with all that, we now have the tools needed to express and interpret `sum`. First, declaring it:

```scala
val expr = Let(
  name  = "sum",
  value = Function(
    param = "lower",
    body  = Function(
      param = "upper",
      body  = Cond(
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

Not for the faint of heart, but it is a faithful transcription of `sum` in our AST.

In theory, then, we should be able to interpret that directly:

```scala
interpret(expr, Env.empty)
// java.lang.RuntimeException: Unbound variable: sum
```

So, no, apparently, we do not have everything we need. At some point, someone tries to find what value `sum` is bound to in an environment in which it's not bound.

Let's think about why that is by studying the substitution rules of recursive functions.


## Substitution rules

Let's think things through a little. In order for a function to call itself, it needs to have some way of referring to itself: it needs to be named. Our local binding of `sum` is crucial:

```ocaml
let sum = lower -> upper ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10
```

The way this is substituted is first by looking at the `let` part of the statement, and binding `sum` to the right-hand side of the `=`. Of course, you bind names to _values_, so we need to evaluate that right-hand side. Importantly, this will be done in an environment where `sum` is not bound: the reason we're evaluating it is precisely to create that binding.

Which means we'll end up evaluating a function (the one that has `upper` for parameter), and if you remember our substitution rules for functions, this yields a value that stores the environment _in which it was defined_. Which, as we've just seen, doesn't include `sum`.

Ultimately, then, applying `sum` will end up evaluating `sum (lower + 1) upper` in its definition environment, which does not include `sum`. We'll get a binding not found error, which is exactly what we observed by running the code.

The conclusion, then, is that `let` is not powerful enough to declare recursive functions. We'll need a new primitive which does the tricky bit of binding `sum` to its value before it is known.

This is traditionally called `let rec`, and it differs subtly from `let`:
- it can only be used to bind names to functions (I'm not sure what a recursive value is, but my intuition tells me _an infinite loop_).
- upon substitution, it ensures that the environment stored with the closure it declares has a binding for the closure itself.

Here's how `sum` would be defined with this new primitive:

```ocaml
let rec sum = lower -> upper ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10
```

Yes, this is almost character for character what we had for `let`. You might wonder - why do we need `let` at all, if `let rec` does the same, but also supports recursive functions? I certainly did for a bit, at least for declaring functions (remember that `let rec` cannot, in our language, define values).

One reason could be, for example, that we don't actually want our function to be recursive, and we do not want the recursive binding to be present in our environment to prevent unexpected behaviours.


## Updating the AST

We've only really declared a new primitive here: `let rec`, used to introduce recursive functions. These are, once introduced, regular functions, applied exactly like all others, so we don't need a special elimination form for them.

As we've said, a `let rec` statement is very similar to a `let` one, and what few differences exist are only observed at interpretation time. We can then basically clone and rename the `Let` variant:

```scala
  case LetRec(name: String, value: Expr, body: Expr)
```

Which gives us the following full AST:

```scala
enum Expr:
  case Num(value: Int)
  case Bool(value: Boolean)
  case Add(lhs: Expr, rhs: Expr)
  case Gt(lhs: Expr, rhs: Expr)
  case Cond(pred: Expr, thenBranch: Expr, elseBranch: Expr)
  case Let(name: String, value: Expr, body: Expr)
  case LetRec(name: String, value: Expr, body: Expr)
  case Var(name: String)
  case Function(param: String, body: Expr)
  case Apply(function: Expr, arg: Expr)
```

We now have everything we need to represent `sum`. Exactly what we had before, except we need to replace `Let` with `LetRec`:

```scala
val expr = LetRec(
  name  = "sum",
  value = Function(
    param = "lower",
    body  = Function(
      param = "upper",
      body  = Cond(
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


"All" we have to do now is interpret it. Famous last words.


## Updating the interpreter

Now _this_ is going to be a bit of a challenge. We know `LetRec` behaves in a very similar fashion to `Let`, so let's start from there and tweak things.

```scala
def letRec(name: String, value: Expr, body: Expr, env: Env) =
  val actualValue = interpret(value, env)
  val newEnv      = env.bind(name, actualValue)

  interpret(body, newEnv)
```

The first difference we have is that we decided to limit `let rec` to functions, so we can rewrite this to fail for any `value` that doesn't evaluate to a `Function`. We've done similar things before (very recently even, with `gt`), there's nothing too surprising there:

```scala
def letRec(name: String, body: Expr, value: Expr, env: Env) =
  interpret(value, env) match
    case function: Value.Function =>
      val newEnv = env.bind(name, function)
      interpret(body, newEnv)

    case _ => sys.error("Type error in LetRec")
```

The second requirement is a little more complicated. It's telling us we need to interpret `value` in an environment in which `name` is already bound to it. That seems a little unreasonable, doesn't it? How can we bind a name to a value that doesn't exist yet?

Well, there _is_ a way, even if it might leave a slightly bitter taste if you're among the _everything must be pure!_ crowd. See, there's nothing that tells us we can't bind `name` to a nonsensical value, such as `undefined` or `null`, and then change that to the actual value when we know it.

Having a temporary value in the environment _could_ be a problem: we absolutely do not want anyone to look that binding up before it's bound to its final value! Luckily, this isn't a possibility here.

We'll definitely know the final value while interpreting `LetRec`, if only because we must make sure it's a `Function` or fail. Which means we can make sure to set it in the environment before interpreting the `body` of the `let rec` statement.

The function application _must_ happen in the `body` of the `let rec` statement - otherwise, the program is invalid, because it'll refer to a function that does not exist.

So we _know_ that the environment will be updated before the binding is actually looked up, and we're perfectly safe to use this method.


At least in principle, then, we have a solution. It requires a little bit of legwork though: for the moment, our environment is fully immutable, which makes it impossible for us to update bindings in place. We'll need to make it mutable, and to create a new `set` primitive which overrides the value a name is bound to. This gives us:


```scala
import collection.mutable

case class Env(map: mutable.Map[String, Value]):
  def lookup(name: String) =
    map.getOrElse(name, sys.error(s"Unbound variable: $name"))

  def bind(name: String, value: Value) =
    Env(map ++ mutable.Map(name -> value))

  def set(name: String, value: Value) =
    map += (name -> value)
```

Note that `bind` still very much copies our internal map without changing the previous one. If this wasn't the case, we'd have broken static scoping.

And yes, technically, we now support mutability in our interpreter. That is very precisely what `set` does: mutate a binding. But, and this is crucially important, while our interpreter relies on mutability, _we do not expose it to the language itself_. There is no primitive in the AST that uses that feature, so developers cannot possibly write a program that interacts with it. We have, however, done a large chunk of the work that would be needed if, in the future, we were to decide to support mutability.

This new, mutable environment allows us to update our `letRec` implementation to:
- set `name` to a bogus value in our new environment.
- evaluate our function declaration in that environment.
- update the value `name` is bound to to the result.

Which yields the following code:

```scala
def letRec(name: String, value: Expr, body: Expr, env: Env) =
  val newEnv = env.bind(name, null)

  interpret(value, newEnv) match
    case function: Value.Function =>
      newEnv.set(name, function)
      interpret(body, newEnv)

    case _ => sys.error("Type error in LetRec")
```

We can now update `interpret` to handle the `LetRec` variants:

```scala
def interpret(expr: Expr, env: Env): Value = expr match
  case Num(value)                => Value.Num(value)
  case Bool(value)               => Value.Bool(value)
  case Add(lhs, rhs)             => add(lhs, rhs, env)
  case Gt(lhs, rhs)              => Gt(lhs, rhs, env)
  case Cond(pred, t, e)          => cond(pred, t, e, env)
  case Var(name)                 => env.lookup(name)
  case Let(name, value, body)    => let(name, value, body, env)
  case LetRec(name, value, body) => letRec(name, value, body, env)
  case Function(param, body)     => Value.Function(param, body, env)
  case Apply(function, arg)      => apply(function, arg, env)
```

With all that, we can finally confirm that our implementation is correct by interpreting `expr`, the program we declared earlier that computes the sum of all numbers between 1 and 10:

```scala
interpret(expr, Env.empty)
// val res: Value = Num(55)
```

## Where to go from here?

Our language now has all the basic building blocks one needs to write interesting programs - the theory goes that every interesting program can now be written using `Expr`. It might require a lot of work, and we might want to enrich our language to provide more facilities out of the box, but it's possible.

One thing we might want to look into, before moving on to more high-level features, is something I find slightly distasteful: it's perfectly possible to write programs that make no sense, and not find out about it until we interpret them. We can, for example, write code that adds a number to a boolean.

We will start looking into techniques to confirm that a program makes sense before interpreting it in the next part of this series.
