---
title: Naming things
layout: article
series: pl
date:   20240626
---

While our little language is developing apace, we are still lacking basic features. One is the ability to give names to values and reuse them, which is commonly known as _variables_. We'll stay clear of that term for the moment however, as it hints strongly at things that can change and we do not want to go there quite yet. Instead, since we're binding a name to a value, we'll call these _bindings_.

For the same reason, I will not be using the common `var` or `val` keywords to declare bindings (`var` feels mutable, `val` immutable, and we're very pointedly not making a decision either way). Instead, we'll use `let`, a very good term that I wish more languages used.

## Substitution rules

Here, then, is how your typical let statement goes:

```ocaml
let x = 1
x
```

You should instinctively feel that this evaluates to `1`, which is perfectly correct. Do note, however, that there are two distinct parts to this:
- `let x = 1`, which creates a binding (we'll call this _binding introduction_).
- `x`, which is how we "consume" a binding by looking the associated value up and substituting the former with the latter (we'll call this _binding elimination_).

This is important, as it tells us we'll need to add two variants to our AST.

Here's a slightly less obvious example:

```ocaml
x
let x = 1
```

This should feel uncomfortable: `x` is being used before being defined, surely that can't be right!

Well, technically, it could, depending on how we decide bindings work. But the important point is: there must be some sort of rule to tell us when it's legal to use a binding.

We'll call the parts of a program in which a binding can be used its _scope_, and say that a binding is _in scope_ to mean it can be used. Note that we're not (yet) defining how scope works, merely that it must exist: at the very least, a binding must exist to be used.

This is why bindings are actually known as _local_ bindings: they are not valid everywhere, but only locally, in their scope.

In order to make things clearer, we'll make scope an explicit part of our syntax by introducing the `in` part of a `let` statement:

```ocaml
let [BINDING] in [SCOPE]
```

For example:

```ocaml
let x = 1 in x
```

This syntax removes any ambiguity as to where `x` comes from. It also shows us something a little interesting: how substitution works for `let` statements.

Let's run through it step by step:

| Target           | Knowledge | Action                                                  |
|------------------|-----------|---------------------------------------------------------|
| `let x = 1 in x` | _N/A_     | Bind `x` to `1`<br/>Substitute _let_ statement with `x` |
| `x`              | `x = 1`   | Substitute `x` with `1`                                 |
| `1`              |           | _N/A_                                                   |

Substitution works by storing whatever knowledge the `let` part of the statement gives us, and then evaluating the `in` part. We're starting to have quite a good model for how local bindings work. But there are still a few stones left unturned.


What do you think the following evaluates to?

```ocaml
let x = 1 in
  x + (let x = 2 in x)
```

You should in theory feel quite confident it evaluates to `3`: the left-hand side operator of `+` is clearly bound to `1`, and the right-hand side declares an entirely different `x`, bound to `2`. Still, this is interesting: there is a notion of a local binding overriding another. This is typically known as _shadowing_, and can feel a lot like we've introduced reassignment to the language - after all, the value `x` is bound to changes, doesn't it?

Consider the following program.

```ocaml
let x = 1 in
 (let x = 2 in x) + x
```

You hopefully think that this should evaluate to `3` - it's essentially the same program as before, except we've swapped the addition's operands. Addition is commutative, so this really shouldn't change anything and we should get the same result as before.

But what this means, then, is that we have not in fact bound `x` to a new value: had we done that, this program would evaluate to `4`, since we're evaluating from left to right and binding `x` to `2` happens before `x` is ever used. No, what we have done is made it legal to declare a new `x`, which masks the old one _locally_, but we'll get the latter back as soon as the former goes out of scope.

What we've just done is decided on a very precise kind of scope management: _static scope_, also known as _lexical_ scope. The scope of a local binding can be understood _statically_, by looking at the code with no need to run it.

Of course, if we need the _static_ qualifier, it means that there must be such a thing as _dynamic_ scope. There really shouldn't but, unfortunately, there is. With dynamic scoping, a binding's value depends on the latest `let` statement that was executed, regardless of its position in the program. With dynamic scoping, our previous example would evaluate to `4`.

This is generally considered to be a bad idea - if anything, it makes addition non-commutative! Some languages do this, but most languages choose static scoping and so will we.

To summarize all this, we've come to the conclusion that local bindings:
- had two parts: an introduction and an elimination.
- had scope, which we've made explicit with our `let... in...` syntax.
- could be _shadowed_, but not overwritten.

We now merely have to implement this!

## Updating the AST

The first task is to update the AST with our new syntax elements. We've seen that we'll need two new variants, one for _introduction_ and one for _elimination_.

Let's start with the simplest one, elimination. That's merely stating _here's a name, substitute it with whatever value it's bound to_, so we only need to store the binding's name:
```scala
  case Var(name: String)
```

Elimination is a little trickier. Recall how a `let` statement looks:
```ocaml
let [NAME] = [VALUE] in [BODY]
```

Where:
- `[NAME]` is the name we'll bind a value to.
- `[VALUE]` is the value that will be bound to `[NAME]`.
- `[BODY]` is the part of the program in which the binding is in scope.

`[NAME]` is clearly a `String` and `[BODY]` an `Expr`, but what about `[VALUE]`? Well, we'll definitely want to support something like this:

```ocaml
let x = 1 + 2 in x * 2
```

We must allow `[VALUE]` to be a complex expression - it must be an `Expr`, too:

```scala
  case Let(name: String, value: Expr, body: Expr)
```

This gives us our complete AST:

```scala
enum Expr:
  case Num(value: Int)
  case Bool(value: Boolean)
  case Add(lhs: Expr, rhs: Expr)
  case Cond(pred: Expr, thenBranch: Expr, elseBranch: Expr)
  case Let(name: String, value: Expr, body: Expr)
  case Var(name: String)
```

## Interpreting local bindings

We're clearly going to need to do a little work here. As we've seen when running substitution, the `let` part of our bindings is put in some sort of knowledge base, to be reused in the `in` part.

This knowledge base is typically called an _environment_. It really is just a mapping of names to the corresponding values, and could be a simple `Map[String, Value]`.

We'll do something a little more interesting and usable, however: it's clear we'll need to be able to query (binding elimination) and update (binding introduction) that environment, so we'll create a bespoke type with dedicated methods:

```scala
case class Env(map: Map[String, Value]):
  def lookup(name: String) =
    map.getOrElse(name, sys.error(s"Unbound variable: $name"))

  def bind(name: String, value: Value) =
    Env(map + (name -> value))
```
`Env` wraps our map, and provides:
- `lookup`, which attempts to retrieve the value bound to the specified name or fail.
- `bind`, which binds a given name to a given value. Note how this produces a new `Env` without changing the old one (we're doing static scoping, after all).

Since we now know that interpretation is done within the scope of a set of bindings (our environment), we also know that this must be passed around, which requires a little refactoring.
We'll need to update the existing code by passing an `Env` everywhere `interpret` will be called:

```scala
def add(lhs: Expr, rhs: Expr, env: Env) =
  (interpret(lhs, env), interpret(rhs, env)) match
    case (Value.Num(lhs), Value.Num(rhs)) => Value.Num(lhs + rhs)
    case _                                => sys.error("Type error in Add")

def cond(pred: Expr, t: Expr, e: Expr, env: Env) =
  interpret(pred, env) match
    case Value.Bool(true)  => interpret(t, env)
    case Value.Bool(false) => interpret(e, env)
    case _                 => sys.error("Type error in Cond")

def interpret(expr: Expr, env: Env): Value = expr matcha
  case Num(value)       => Value.Num(value)
  case Bool(value)      => Value.Bool(value)
  case Add(lhs, rhs)    => add(lhs, rhs, env)
  case Cond(pred, t, e) => cond(pred, t, e, env)
```

And having laid all this groundwork, we can now tackle the more interesting problem of interpreting `Var` and `Let`.

Let's start with `Var`. That's almost trivial: we need to lookup the value a name is bound to in our environment, which is exactly what `lookup` does:

```scala
def interpret(expr: Expr, env: Env): Value = expr matcha
  case Num(value)       => Value.Num(value)
  case Bool(value)      => Value.Bool(value)
  case Add(lhs, rhs)    => add(lhs, rhs, env)
  case Cond(pred, t, e) => cond(pred, t, e, env)
  case Var(name)        => env.lookup(name)
```

`Let` is slightly trickier, but perfectly manageable. Given a `name`, a `value` and a `body`, we need to:
- interpret `value` in the current environment.
- bind `name` to it, thus producing a new environment.
- interpret `body` in that new environment.

This is a little complex, so we'll extract it to a dedicated method:

```scala
def let(name: String, value: Expr, body: Expr, env: Env) =
  val actualValue = interpret(value, env)
  val newEnv      = env.bind(name, actualValue)

  interpret(body, newEnv)
```
Which gives us a final implementation of `interpret`:


```scala
def interpret(expr: Expr, env: Env): Value = expr match
  case Num(value)             => Value.Num(value)
  case Bool(value)            => Value.Bool(value)
  case Add(lhs, rhs)          => add(lhs, rhs, env)
  case Cond(pred, t, e)       => cond(pred, t, e, env)
  case Var(name)              => env.lookup(name)
  case Let(name, value, body) => let(name, value, body, env)
```

## Testing our implementation

Now that we've written something that feels it should work, let's take it out for a spin.

We'll use the example we took to talk about static scoping:

```ocaml
let x = 1 in
 (let x = 2 in x) + x
```

This yields this (relatively noisy) AST:
```scala
val expr = Let(
  name  = "x",
  value = Num(1),
  body  = Add(
    Let(
      name  = "x",
      value = Num(2),
      body  = Var("x")
    ),
    Var("x")
  )
)
```

Interpreting that is simple enough, although we do need to pass some environment to `interpret`. At least for the moment, we'll merely work with the empty environment, for which we'll create a helper:

```scala
object Env:
  val empty: Env = Env(Map.empty)
```

Armed with all these tools, interpreting our `expr` is entirely straightforward:

```scala
interpret(expr, Env.empty)
// val res: Value = Num(3)
```

If you remember, if we implemented static scoping, this should evaluate to `3`, or `4` if we made a mistake an implement dynamic scoping. And, fortunately, it evaluates to `3`, as it should.


## Where to go from there?

We've just finished adding local bindings to our language. Inquisitive readers might have realised that these feel very much like functions, except the parameter's value is fixed - if you have, well done, you've correctly guessed what our next step should be: take what we've learned with local bindings and attempt to generalise it to support functions.
