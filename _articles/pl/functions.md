---
title: Functions
layout: article
series: pl
date:   20240705
---

We've just implemented let bindings, which allow us to write things like this:

```ocaml
let x = 1 in
  x + 2
```

One way of reading that is:
- the `in` part is telling us _give me an `x` and I'll add `2` to it_.
- the `let` part is telling us _here's a specific `x`_.

While local bindings are undoubtedly nice, this also seems needlessly limiting: why make `x` a parameter of the `in` part, but then force it to be fixed? Wouldn't it be much nicer if we could keep the `in` part, but allow people to evaluate it for any `x`?

This notion of _something that takes a parameter and computes something with it_ is called a _function_. We've just come to the conclusion that we'd like to implement functions in our language.

In theory at least, all we need for that is syntax and substitution rules.

## Syntax

### Lambda introduction

We'll use a fairly common syntax for functions:

```ocaml
[PARAMETER] -> [BODY]
```

Where:
- `[PARAMETER]` is the name of our parameter.
- `[BODY]` is the code that will be executed with that parameter.

The `in` part of our previous let binding would thus be expressed as:

```ocaml
x -> x + 2
```

This declares a function that, given some `x`, returns `x + 2`. If you remember the vocabulary we introduced in the previous article of this series, this would then be _function introduction_.

A more common name is _lambda introduction_: _lambda_ is often used as a shorthand for _anonymous function_, and yes, you probably noticed: we have declared a function, but not named it. Is this really something we need to worry about though?

We just spent quite a bit of time figuring out the rules for naming things, and came up with let bindings. That's exactly what we need, isn't it? We can simply write:

```ocaml
let f = x -> x + 2 in
  ???
```

And that has just created a function called `f` in our environment. Of course, this means we've also taken a major decision without necessarily intending to.

Let bindings bind a name to a value. We've just bound the name `f` to a function. This means, then, that we've quite naturally decided that functions were values in our language.

### Lambda elimination

You'll have noticed in that previous code block that I didn't implement the `in` part of our let binding. That's simply because we don't have syntax for it yet: we know how to _introduce_ functions, but not how to _eliminate_ them, which is more commonly known as _applying_ them.

The syntax we'll use for that is fairly common:

```ocaml
[FUNCTION] [ARGUMENT]
```

Where:
- `[FUNCTION]` is, well, a function.
- `[ARGUMENT]` is the value passed to the function.

You'll note a slight lexical subtlety: I've used both _parameter_ and _argument_ to describe "what's passed to a function". There is a distinction: I'll call a parameter the name of the value passed to a function, and argument the actual value. Which is why we'll talk of parameters for lambda introduction and arguments for lambda elimination.

Now that we have syntax for it, we can complete our previous example:

```ocaml
let f = x -> x + 2 in
  f 1
```

And that is exactly the `let` statement we've been using as an example: compute `x + 2` for `x = 1`.

This seems rather convoluted though, and maybe a little counter productive: we just rewrote a let binding as... another, more complicated let binding. But the fact that we're giving a name to our function, and only use that name once, should be a hint that we can maybe skip that step.

When applying a function, our syntax requires the `[FUNCTION]` part to be a function. Well, `x -> x + 2` is one, so we can use that directly, rather than name it and refer to that name:

```ocaml
(x -> x + 2) 1
```

This pattern of creating and immediately applying a function is quite common (especially, I think, in LISPs) and known as _left-left-lambda_.

What we've just invented, then, is quite powerful: not only do we have functions, but we can use them to express let bindings without any loss of expressivity.

## A note on concrete syntax

We've made let bindings obsolete;  we don't need them in the language, since they can be expressed with functions. But do we want to take them out?

Which do you think is clearer:

```ocaml
let x = 1 in x + 2

(x -> x + 2) 1
```

I suppose this is really a matter of preference, but I can't help but feel the let binding reads much better than the function declaration and immediate application. It feels like we need to decide on some sort of trade off:
- support let bindings when we don't need to, meaning that we have more code than we strictly need and a larger potential for bugs / complexity.
- express let bindings as functions, meaning that our language will be a little less approachable.

Luckily, we get to have our cake and eat it, too: we can simply decide that let bindings are syntactic sugar for function application. The surface syntax of our language can absolutely include let bindings - we merely need to turn them into function application when we turn that syntax into an AST.

This is an important concept, and one of the reasons this series is ignoring parsing entirely: the syntax is a little irrelevant. Implementers of our language can choose whatever they prefer, so long as they can turn it into our AST. At this point, we take over and run interpreters, compilers...

One could, for example, decide that naming functions through let bindings is unpleasant, and implement dedicated syntax for it:
```scala
def f(x) = x + 2
f 1
```

One might also decide that our syntax for function application is unclear, and implement parentheses instead:

```scala
def f(x) = x + 2
f(1)
```

And this would be strictly equivalent, at the AST level, to our:
```ocaml
(x -> x + 2) 1
```

Syntax is an implementation detail. This is why we're spending so much time _not_ worrying about implementing any.

## Substitution rules

Now that we have a syntax, let's think about how substitution works for functions. You might think that since we support let bindings, we've actually got that mostly sorted. And that'd be _almost_ correct.

We can start from there, at least, and think of function application as a form of let binding: we'd bind the parameter to the argument, and then perform substitution as we always have. For example:

| Target           | Knowledge | Action                  |
|------------------|-----------|-------------------------|
| `(x -> x + 2) 1` | _N/A_     | Bind `x` to `1`         |
| `x + 2`          | `x = 1`   | Substitute `x` with `1` |
| `1 + 2`          |           | Simplify `1 + 2`        |
| `3`              |           | _N/A_                   |

This seems perfectly reasonable, but there is an edge case to consider. What do you think this evaluates to?

```ocaml
let y = 1 in
  let f = x -> x + y in
    let y = 2 in
      f 3
```

Since we're doing static scoping, you probably expect this to evaluate to `4`: `f` is defined when the first `y` binding is in scope, so you'd expect `f` to be `x -> x + 1`.

If you run our substitution rules however, you'll end up with `5`, because our environment will bind `y` to `2` before `f` is applied.

| Target                                                                                                                                          | Knowledge                    | Action                           |
|-------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------|----------------------------------|
| `let y = 1 in`<br/>&nbsp;&nbsp;`let f = x -> x + y in`<br/>&nbsp;&nbsp;&nbsp;&nbsp;`let y = 2 in`<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`f 3` | _N/A_                        | Bind `y` to `1`                  |
| `let f = x -> x + y in`<br/>&nbsp;&nbsp;`let y = 2 in`<br/>&nbsp;&nbsp;&nbsp;&nbsp;`f 3`                                                        | `y = 1`                      | Bind `f` to `x -> x + y`         |
| `let y = 2 in`<br/>&nbsp;&nbsp;`f 3`                                                                                                            | `y = 1`<br/>`f = x -> x + y` | Bind `y` to `2`                  |
| `f 3`                                                                                                                                           | `y = 2`<br/>`f = x -> x + y` | Substitute `f` with `x -> x + y` |
| `(x -> x + y) 3`                                                                                                                                | `y = 2`<br/>                 | Bind `x` to `3`                  |
| `x + y`                                                                                                                                         | `y = 2`<br/>`x = 3`          | Substitute `x` with `3`          |
| `3 + y`                                                                                                                                         | `y = 2`                      | Substitute `y` with `2`          |
| `3 + 2`                                                                                                                                         |                              | Simplify `3 + 2`                 |
| `5`                                                                                                                                             |                              | _N/A_                            |

Working through that example, we see that the second `y` binding shadows the first and breaks static scoping when `f` is applied. We want `f` to use the value `y` was bound to at _declaration_ time, not _application_ time. Or, put in slightly more general term: applying a function must be done in the environment it was defined in, rather than the one it's applied in.

In our previous example, `y` has a value of `1` when `f` is defined, so we need to store that with `f`. And at application time, we'll ignore whatever `y` is defined in the current environment and use the one we stored. Our program thus evaluates to what static scoping says it should, and sanity is restored.

The technical vocabulary for that (which I'll readily admit I've never fully understood) is that `f` _closes_ over its environment, and is thus called a _closure_.

## Updating the AST

We've seen that we needed two new variants for our AST, the usual introduction and elimination ones.

### Lambda introduction

Lambda introduction is the AST representation of:

```ocaml
x -> x + 2
```

This is fairly straightforward: we need to know the parameter, `x`, as well as the function's body, `x + 1`, which translates directly to:

```scala
  case Lambda(param: String, body: Expr)
```

### Lambda Elimination

Lambda elimination is just as straightforward - problems usually start happening when interpreting things, not when describing them. We're trying to represent:
```ocaml
f 1
```

Which clearly gives us a structure containing a function (the function to apply) and a value (the function's argument). Of course, what we really want to hold are _expressions_ that evaluate to a function and a value of the right type, which gives us the following code:
```scala
  case Apply(lambda: Expr, arg: Expr)
```

Note how I'm being careful to be consistent in our vocabulary: `Lambda` has a parameter, `Apply` an argument.

### Full AST

Putting it all together, we get the following definition for `Expr`:
```scala
enum Expr:
  case Num(value: Int)
  case Bool(value: Boolean)
  case Add(lhs: Expr, rhs: Expr)
  case Cond(pred: Expr, thenBranch: Expr, elseBranch: Expr)
  case Let(name: String, value: Expr, body: Expr)
  case Var(name: String)
  case Lambda(param: String, body: Expr)
  case Apply(lambda: Expr, arg: Expr)
```

And just to make sure we have all we need, we can try to write `let f = x -> x + 2 in f 1` using that updated AST:

```scala
val expr = Let(
  name  = "f",
  value = Lambda(
    param = "x",
    body  = Add(Var("x"), Num(2))
  ),
  body = Apply(
    lambda = Var("f"),
    arg    = Num(1)
  )
)
```

Not the most pleasant thing in the world - our textual syntax is certainly easier on the brain - but it does work.

We seem to have everything in order: a clear substitution model and a working AST. All that's left to do, then, is interpreting that updated AST.

## Interpreting functions

### Lambda introduction
Our first task will be to interpret the `Lambda` branch of our AST, and we hit an immediate snag: we need to go from `Lambda` to `Value`; but `Value` only has two variants, `Num` and `Bool`, neither of which seem suitable for representing a function.

We'll need to adapt `Value` to accommodate functions, which means adding a new variant. So far, these have been extremely similar to their `Expr` equivalents, to the point that we considered re-using the `Expr` variants directly, so let's try the same approach:

```scala
  case Lambda(param: String, body: Expr)
```

That seems reasonable: a function is in fact defined by its parameter and the code to execute when it's applied. But is that _all_ a function is defined by?

If you cast your mind back to our study of substitution rules, you'll remember that in order to respect static scoping, a function also needed to capture the environment in which it was defined: our `Value.Lambda` needs a third field of type `Env`.

```scala
enum Value:
  case Num(value: Int)
  case Bool(value: Boolean)
  case Lambda(param: String, body: Expr, env: Env)
```

I don't know about you, but it felt very odd writing this, like we're mixing things that don't belong together. An `Env` is a very runtime notion - it's literally the runtime environment in which something is being interpreted, while an `Expr` feels more static. But that is what it means to support functions as values: such a value must combine the code to execute as well as the environment in which it was defined.

With this upgraded `Value`, updating `interpret` to handle lambda introduction is relatively easy:

```scala
def interpret(expr: Expr, env: Env): Value = expr match
  case Num(value)             => Value.Num(value)
  case Bool(value)            => Value.Bool(value)
  case Add(lhs, rhs)          => add(lhs, rhs, env)
  case Cond(pred, t, e)       => cond(pred, t, e, env)
  case Var(name)              => env.lookup(name)
  case Let(name, value, body) => let(name, value, body, env)
  case Lambda(param, body)    => Value.Lambda(param, body, env)
```

### Lambda elimination

Lambda elimination is a little more complex. What we're given to work with are two `Expr`s:
- `lambda`, the function to apply.
- `arg`, the argument to apply `lambda` on.

Our first step will be to interpret `lambda` and make sure it correctly evaluates to a function:

```scala
def apply(lambda: Expr, arg: Expr, env: Env) =
  interpret(lambda, env) match
    case Value.Lambda(param, body, closedEnv) =>
      ???
    case _ =>
      sys.error("Type error in Apply")
```

This is basically necessary boilerplate to get to the function we want to apply, but we can already spot a potential source of confusion: we have two environments! `env` is the environment in which the function is being applied, and `closedEnv` the one in which it was defined. We'll need to be very careful not to get them mixed up.

Following our substitution rules, we now need to bind `param` to the value of `arg`. In order to do that, we first need to know the value of `arg`, which is simply done by interpreting it... but in which environment?

This one is not too hard. `arg` has absolutely nothing to do with the environment in which `lambda` was defined, so it wouldn't make sense to interpret it in `closedEnv`.

```scala
def apply(lambda: Expr, arg: Expr, env: Env) =
  interpret(lambda, env) match
    case Value.Lambda(param, body, closedEnv) =>
      val argValue  = interpret(arg, env)
      ???
    case _ =>
      sys.error("Type error in Apply")
```

We're almost ready to apply our function. All we now need is to know in which environment to do so. Our substitution rules tell us it must be in the environment in which it was defined - `closedEnv` - but that's not quite enough, is it? We must also bind `param` to `argValue` in that environment in order for the function to be able to access its parameter.

```scala
def apply(lambda: Expr, arg: Expr, env: Env) =
  interpret(lambda, env) match
    case Value.Lambda(param, body, closedEnv) =>
      val argValue  = interpret(arg, env)
      val lambdaEnv = closedEnv.bind(param, argValue)
      ???
    case _ =>
      sys.error("Type error in Apply")
```

We now have everything we need, all that's left to do is to interpret the `body` of our function in the right environment:

```scala
def apply(lambda: Expr, arg: Expr, env: Env) =
  interpret(lambda, env) match
    case Value.Lambda(param, body, closedEnv) =>
      val argValue   = interpret(arg, env)
      val lambdaEnv = closedEnv.bind(param, argValue)
      interpret(body, lambdaEnv)
    case _ =>
      sys.error("Type error in Apply")
```

Putting all this together, we get our final `interpret` implementation:

```scala
def interpret(expr: Expr, env: Env): Value = expr match
  case Num(value)             => Value.Num(value)
  case Bool(value)            => Value.Bool(value)
  case Add(lhs, rhs)          => add(lhs, rhs, env)
  case Cond(pred, t, e)       => cond(pred, t, e, env)
  case Var(name)              => env.lookup(name)
  case Let(name, value, body) => let(name, value, body, env)
  case Lambda(param, body)    => Value.Lambda(param, body, env)
  case Apply(lambda, arg)     => apply(lambda, arg, env)
```

### Testing our implementation

In order to make sure we got everything right, let's use the edge case we identified while studying substitution rules:

```ocaml
let y = 1 in
  let f = x -> x + y in
    let y = 2 in
      f 3
```

Remember that if we implemented static scope properly, this should evaluate to `4`. If we got it wrong, `5` (and if we got it _very_ wrong, just about anything).

The AST representation of this program is:

```scala
val expr = Let(
  name  = "y",
  value = Num(1),
  body = Let(
    name = "f",
    value = Lambda(
      param = "x",
      body  = Add(Var("x"), Var("y"))
    ),
    body = Let(
      name = "y",
      value = Num(2),
      body = Apply(Var("f"), Num(3))
    )
  )
)
```

And finally, interpreting this yields the expected (hoped for!) `4`.

```scala
interpret(expr, Env.empty)
// val res: Value = Num(4)
```


## Functions with multiple parameters

You might have noticed. In this entire article, we only ever worked with unary functions - functions that take a single parameter. And you might rightfully think that this was a lot of work for a very partial feature. After all, it's very easy to think of dozens of functions that take more than one parameter - our interpreter is one, for example.

The good news is, while it was indeed a lot of work, the feature is not at all partial. Let's take a concrete example to show how.

An `add` function would take two parameters and return their sum. In theory, then, this is something we can't express with our language - not only do we not have syntax for it, but we don't even have the necessary tools in our AST. It certainly feels like we're at a bit of a dead end.

Now, allow your mind to shift a little. What if instead, `add` was a function that took a single parameter - call it `lhs`, returned a function that took a single parameter - call it `rhs`, and returned the sum of `lhs` and `rhs`? Well, that'd be essentially the same thing, wouldn't it?

Here's how that would work with our language:

```ocaml
let add = lhs -> rhs -> lhs + rhs in
  add 1 2
```

That's a perfectly valid expression of our language, and `add` behaves, for all intents and purposes, like a function with two parameters. This process of turning a function that takes _n_ parameters and turning it into a chain of _n_ functions is called _[currying](https://en.wikipedia.org/wiki/Currying)_.

Here's how `add` looks like in our AST - it is _quite_ noisy:

```scala
val expr = Let(
  name  = "add",
  value = Lambda(
    param = "lhs",
    body  = Lambda(
      param = "rhs",
      body  = Add(Var("lhs"), Var("rhs"))
    )
  ),
  body = Apply(
    lambda = Apply(
      lambda = Var("add"),
      arg  = Num(1)
    ),
    arg = Num(2)
  )
)
```

And yes, the sum of `1` and `2` is indeed `3`:

```scala
interpret(expr, Env.empty)
// val res: Value = Num(3)
```


## Should we drop `Let` ?

Earlier, in the bit about syntactic sugar, we realised that we could do away with let bindings entirely, as they could be expressed by simple function declaration and immediate application. In theory, I would do that now - remove the `Let` variant from our AST.

In practice however, the downside of not writing an actual syntax and parser for our language is that we must write everything directly in the AST. We're likely to want to assign names to things in the future, and let bindings are syntactically a lot more pleasant than the alternative. So we'll keep them for the moment, not because they're necessary, but because they're convenient.


## Where to go from there?

At this point, we have a pretty complete programming language. There are a few things that still bother me about it though, and I'm not yet sure which one to tackle first.

My first problem is that we don't have tools for controlling flow such as `for` or `while` loops. These can be expressed in terms of recursive functions... but we don't have these either (try to define a function that refers to itself with what we have). So that's a problem I'd quite like to tackle sooner or later.

My second issue is that we can run programs that don't make any sense, such as `1 + true`. These will be correctly caught at runtime and fail, but it'd be so much nicer if such a program was impossible to represent.

I'm not entirely sure yet which one we'll tackle next. I guess we'll find out!
