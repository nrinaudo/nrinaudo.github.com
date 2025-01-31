---
title: Naming things
layout: article
series: pl
date:   20240626
---

While our little language is developing apace, we are still lacking basic features. One is the ability to give names to values, commonly known as _variables_. We'll stay clear of that term for the moment however, as it hints strongly at things that can change and we do not want to go there quite yet. Instead, since we're binding a value to a name, we'll call these _bindings_.

For the same reason, I will not be using the common `var` or `val` keywords to declare bindings (`var` feels mutable, `val` immutable, and we're very pointedly not making a decision either way). Instead, we'll use `let`, a very good term that I wish more languages used.

## Intuition

Here, then, is how your typical `let` expression goes:

```ocaml
let x = 1
x
```

You should instinctively feel that this evaluates to `1`, which is perfectly correct. Do note, however, that there are two distinct parts to this:
- `let x = 1`, which creates a binding (we'll call this _binding introduction_).
- `x`, which is how we "consume" a binding by looking up the bound value and substituting the name with it (we'll call this _binding elimination_).

This is important, as it tells us we'll need to add two terms to our language.

### Scope

Here's a slightly less obvious example:

```ocaml
x
let x = 1
```

This should feel uncomfortable: `x` is being used before being defined, surely that can't be right!

Well, technically, it could, depending on how we decide bindings work. But the important point is: there must be some sort of rule to tell us when it's legal to refer to a binding.

We'll call the parts of a program in which a binding can be used its _scope_, and say that a binding is _in scope_ whenever we can refer to it. Note that we're not (yet) defining how scope works. We've merely come to the conclusion that it must exist.

In order to make things clearer, we'll make scope an explicit part of our syntax by introducing the `in` part of a `let` expression:

```ocaml
let [name] = [value] in
  [body]
```

For example:

```ocaml
let x = 1 in
  x
```

The body of our `let` expression is the subset of our program in which the binding is in scope.



### Environment

We now need to think a little about how bindings work. In order to build intuition, let's run through the following, very simple program:

```ocaml
let x = 1 in
  x
```

This is telling us that we should bind name `x` to value `1`, and evaluate the body of the `let` expression in that context. We'll call that context the _environment_ - a mapping of names to values.

In order to keep track of this, we'll use the following notation: $\\{name_1 = value_1, ..., name_n = value_n\\}$.

The environment, then, is where we look for values when a binding is referenced. When evaluating the body of our `let` expression, we merely need to look up what name `x` is references in the environment and substitute it with that. Which tells us that, as expected, this entire program evaluates to `1`.

This gives us a good intuition for the general case for let bindings, but there are still a few stones left unturned.

### Laziness vs eagerness

Consider the following program:

```ocaml
let x = 1 + 2 in
  x
```

Intuitively, there are two ways we could populate our environment:
- $\\{x = 1 + 2\\}$
- $\\{x = 3\\}$

The former is known as _lazy evaluation_ (we'll postpone evaluating things until we absolutely must), while the latter is called _eager evaluation_ (we'll evaluate expressions as soon as possible).

Both are perfectly valid, and there really isn't one that is objectively better than the other. They just have different semantics, with different trade-offs. Let's look at performances, for example, with the following expression:

```ocaml
let x = 1 + 2 in
  x + x
```

Lazily evaluating this will cause us to compute `1 + 2` twice (once per `x` in the `let`'s body), while eager evaluation will only compute it a single time (when storing it in the environment). Eager evaluation would be faster in this scenario.

But that's not always true! Look at the following code fragment:

```ocaml
let x = 1 + 2 in
  if true then 4
  else         x
```

Lazy evaluation means we'll never actually compute `1 + 2`, since our conditional expression will never go in the on-false branch. Were we doing eager evaluation, it would have been computed once, even though it's never needed.

In the rest of these articles, we'll be doing eager evaluation, purely because that's the most common evaluation model and the one you're most likely to have a good intuition for.

### Nesting `let` expressions

Consider the following expression:

```ocaml
let x = 1 in
  let y = 2 in
    x + y
```

We already know how to deal with the outermost `let`: evaluate its body in $\\{x = 1\\}$. This gives us:

```ocaml
let y = 2 in
  x + y
```

We also already know how to do that, but there's a subtlety. We can't merely interpret `x + y` in $\\{y = 2\\}$, because then the reference to `x` would fail to resolve.

What we need, then, is $\\{x = 1, y = 2\\}$ - an environment that contains both the new `y` binding, and all the pre-existing ones.

This is another important conclusion: nested `let` expressions inherit bindings from their parent.


### Shadowing bindings

Consider the following expression:

```ocaml
let x = 1 in
 x + (let x = 2 in x)
```

You should see that we quickly end up having to interpret `let x = 2 in x` in $\\{x = 1\\}$. This forces us to think about what to do with conflicting binding names, which we haven't encountered yet.

One possible way of dealing with that is to simply say that new bindings overwrite existing ones: the environment becomes $\\{x = 2\\}$, and we can finish evaluating the program to get `3` - exactly the result we were expecting.

How about this one though, in which I've merely swapped the operands of `+`?

```ocaml
let x = 1 in
 (let x = 2 in x) + x
```

You hopefully think that it should also evaluate to `3` - it's essentially the same program as before, except we've swapped the addition's operands. Addition is commutative, so this really shouldn't change anything and we should get the same result as before.

But if you follow the rules we've defined, you'll see that it doesn't quite work out:
- the outermost `let` gives us an environment of $\\{x = 1\\}$.
- the innermost `let` updates it to $\\{x = 2\\}$.
- that final `x` reference, then, is substituted with `2`.
- the entire expression ultimately evaluates to `4`.

Which tells us that the order of the operands matters in addition. This is obviously not what we want, even if it's not always been that obvious: many programming languages used to handle bindings that way, even if it's mostly come to be accepted as a generally bad idea.

These semantics are called _dynamic_ scoping: since anybody can overwrite any binding at any time, the only way to be sure what a name is bound to is to observe it at runtime.


The alternative is called _static scoping_, or _lexical scoping_. I personally prefer the word _static_, as it's more clearly in opposition to _dynamic_.

The idea is that rather than overwrite existing bindings, we create a new environment instead. That new environment inherits all previous bindings (as we've seen when handling nested `let` expressions), overwriting conflicting names as needed; but the important distinction is, bindings are only overwritten _in the new environment_, leaving the old one alone.

Let's see how that works in our previous example:

```ocaml
let x = 1 in
 (let x = 2 in x) + x
```

The outermost `let` gives us $e_1 = \\{x = 1\\}$, in which to evaluate `(let x = 2 in x) + x`.

The innermost `let` creates a new environment which duplicates $e_1$ and overwrites `x` to `2`. We'll write this $e_2 = e_1[x \leftarrow 2]$. Interpreting `x` in $e_2$ clearly gives us `2`.

We're then left with evaluating `2 + x` - but since we're finished interpreting the innermost `let`, its environment, $e_2$, has been discarded. We're now working with $e_1$, in which `x` is bound to `1`. This unambiguously leads to a final value of `3` - exactly the result we wanted.

These are the semantics we want: in order to support static scoping, we want nested `let` expressions to create new environments, inheriting their parent environment's bindings, and overwriting things as needed.

## Operational semantics

Now that we have a good idea how bindings work in practice, we need to formalise this understanding.

### Environment

Before we can do that however, we need to update our syntax a little, by adding notation to describe the environment. We've seen that all expressions must be evaluated in an environment, which we'll write as follows:

\begin{prooftree}
  \AXC{$e \vdash expr \Downarrow\ v$}
\end{prooftree}

This reads _expression $expr$ is interpreted as value $v$ in environment $e$_.


### Binding introduction

Let's call the term used to create a binding $\texttt{Let}$. We've seen that $Let$ is composed of a binding's $name$, its $value$, and the block of code in which that binding is in scope, $body$:

```ocaml
let [name] = [value] in
  [body]
```

This, then, is what we're trying to specify the behaviour for:

\begin{prooftree}
  \AXC{$e \vdash \texttt{Let}\ name\ value\ body \Downarrow\ ???$}
\end{prooftree}

We're doing eager evaluation, so we know we must interpret $value$ immediately. There's no real ambiguity about which environment this should happen in: the only one that makes sense is $e$, the one in which $Let$ is being interpreted.

\begin{prooftree}
  \AXC{$e \vdash value \Downarrow v_1$}
  \UIC{$e \vdash \texttt{Let}\ name\ value\ body \Downarrow\ ???$}
\end{prooftree}

The next step is to interpret $body$, which we know must be done in an environment that:
- inherits all of $e$'s bindings.
- binds $v_1$ to $name$.

That is exactly $e[name \leftarrow v_1]$, which gives us the final semantics of $Let$:

\begin{prooftree}
  \AXC{$e \vdash value \Downarrow v_1$}
  \AXC{$e[name \leftarrow v_1] \vdash body \Downarrow v_2$}
  \BIC{$e \vdash \texttt{Let}\ name\ value\ body \Downarrow v_2$}
\end{prooftree}

### Binding elimination

We have a operational semantics for binding introduction, the act of creating a new binding. We now need to do the same work for the opposite action, eliminating (or de-referencing) a binding.

Let's call the term for this $\texttt{Ref}$. Its semantics are really rather straightforward: $\texttt{Ref}$ evaluates to whatever value the environment says the corresponding name references.

We'll need to introduce a new notation for this: $e(name)$ is the value bound to $name$ in $e$. This allows us to write the $Ref$ semantics:

\begin{prooftree}
  \AXC{$e \vdash \texttt{Ref}\ name \Downarrow e(name)$}
\end{prooftree}


## Implementing bindings

### Environment

The first thing we'll need to write is our environment. There's a variety of ways we could achieve that - an immutable `Map` was my first instinct - but the most common one is to realise how much like a stack the environment behaves.

For each new binding, we create a new environment which is exactly the previous one, with a new name / value pair added on top. That's really just pushing a value onto a stack.

Looking up the value bound to a name is merely looking at the earliest binding for that name. That's really just the `find` method on a stack.

Those operations are relatively trivial, so we'll not spend too much time explaining them. Here's the full code for the environment:

```scala
class Env(env: List[Env.Binding]):
  // e(name)
  def lookup(name: String) =
    env.find(_.name == name)
       .map(_.value)
       .getOrElse(sys.error(s"Unbound variable: $name"))

  // e[name <- value]
  def bind(name: String, value: Value) =
    Env(Env.Binding(name, value) :: env)

object Env:
  case class Binding(name: String, value: Value)

  val empty = Env(List.empty)
```

### Updating the AST

Before we can update the interpreter, we need to add 2 new variants to our AST, one for each new term in our language.

Let's start with $Ref$, whose semantics are:

\begin{prooftree}
  \AXC{$e \vdash \texttt{Ref}\ name \Downarrow e(name)$}
\end{prooftree}

This tells us quite clearly that $Ref$ is entirely defined by the name of the binding it references:

```scala
case Ref(name: String)
```

Similarly, looking at the $Let$ semantics will tell us exactly what we need:

\begin{prooftree}
  \AXC{$e \vdash value \Downarrow v_1$}
  \AXC{$e[name \leftarrow v_1] \vdash body \Downarrow v_2$}
  \BIC{$e \vdash \texttt{Let}\ name\ value\ body \Downarrow v_2$}
\end{prooftree}

$Let$ is defined by the binding's $name$, $value$, and $body$:

```scala
case Let(name: String, value: Expr, body: Expr)
```

### Binding elimination

Having done the hard work of specifying our semantics, implementing bindings is actually quite straightforward.

Let's start with $Ref$, whose semantics are:

\begin{prooftree}
  \AXC{$e \vdash \texttt{Ref}\ name \Downarrow e(name)$}
\end{prooftree}

This is simple enough:
```scala
def runRef(name: String, e: Env) =
  e.lookup(name) // e |- Ref name ⇓ e(name)
```

### Binding introduction

And finally, we can tackle $Let$, whose semantics are:

\begin{prooftree}
  \AXC{$e \vdash value \Downarrow v_1$}
  \AXC{$e[name \leftarrow v_1] \vdash body \Downarrow v_2$}
  \BIC{$e \vdash \texttt{Let}\ name\ value\ body \Downarrow v_2$}
\end{prooftree}

As usual, this maps quite easily and directly to code:

```scala
def runLet(name: String, value: Expr, body: Expr, e: Env) =
  val v1 = interpret(value, e)               // e |- value ⇓ v₁
  val v2 = interpret(body, e.bind(name, v1)) // e[name <- v₁] |- body ⇓ v₂
  v2                                         // e |- Let name value body ⇓ v₂
```

At this point, we need to update `interpret` a little: not only does it need to handle our two new variants, but it must be environment-aware - which is really just declaring an `Env` parameter and passing it everywhere it's needed. Here's what this looks like in the end:

```scala
def interpret(expr: Expr, e: Env): Value = expr match
  case Num(value)             => Value.Num(value)
  case Bool(value)            => Value.Bool(value)
  case Add(lhs, rhs)          => runAdd(lhs, rhs, e)
  case Cond(pred, onT, onF)   => runCond(pred, onT, onF, e)
  case Let(name, value, body) => runLet(name, value, body, e)
  case Ref(name)              => runRef(name)
```

## Testing our implementation

We're pretty much done with bindings (spoiler warning: for the moment). We have clear semantics, and an implementation that we feel follows them closely. All we've left to do, then, is to test things out.

We'll use the example we took to talk about static scoping:

```ocaml
let x = 1 in
 (let x = 2 in x) + x
```

And this is where I'm starting to regret not writing a parser for our language - I _love_ a well defined AST, but it's really quite unpleasant to code directly in one:

```scala
val expr = Let(
  name  = "x",
  value = Num(1),
  body  = Add(
    Let(
      name  = "x",
      value = Num(2),
      body  = Ref("x")
    ),
    Ref("x")
  )
)
```

Interpreting that is simple enough, with one small subtlety: we're considering that our initial environment is empty. This might not always be the case, as their might be predefined global bindings, for example.

```scala
interpret(expr, Env.empty)
// val res: Value = Num(3)
```

If you remember, had we implemented dynamic scoping, this would evaluate to `4`. But we get `3`, which is a pretty good hint that we've successfully implemented static scoping, exactly as we wanted. Making sure we don't break this as we add more features to the language will prove a challenge, but at least for the moment, we have good reasons to believe we have a solid implementation of what we set out to support.


## Where to go from there?

We've just finished adding bindings to our language. Inquisitive readers might have realised that these feel very much like functions, except the parameter's value is fixed - if you have, well done, you've correctly guessed what our next step should be: take what we've learned with bindings and attempt to generalise it to support functions.
