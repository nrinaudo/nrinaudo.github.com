---
title: Reusing code
layout: article
series: pl
date:   20240705
---

We've just implemented bindings, which allow us to write things like this:

```ocaml
let x = 1 in
  x + 2
```

One way of reading that is:
- the `in` part is telling us _give me an `x`, any `x`, and I'll add `2` to it_.
- the `let` part is telling us _`x` is only ever going to be `1`, though_.

While bindings are undoubtedly nice, this also seems needlessly limiting: why make `x` a parameter of the `in` part, but then fix it to a unique value? Would it not be much nicer if we could keep the `in` part, but allow people to evaluate it for any `x`?

This notion of _something that takes a parameter and computes something with it_ is called a _function_. We've just come to the conclusion that we'd like to add support for functions to our language.

## Intuition

### Function introduction

Let's start by thinking of how we would declare a new function - function _introduction_, to reuse the vocabulary we introduced when working on bindings.

As we've seen, we really want a function to act as a more generic `let` expression, one in which the binding's value is going to be specified later. A function, then, is like [a `let`](./bindings.html#binding-introduction) without a value, which tells us it must be composed of:
- a name to which a value will later be bound. This is traditionally called the function's _parameter_.
- a _body_, the block of code in which the parameter will be in scope.

We'll use the following syntax in our examples:

```ocaml
[parameter] -> [body]
```

The `in` part of our previous let binding would thus be expressed as:

```ocaml
x -> x + 2
```

That is, the function which, given a number, adds `2` to it.

### Function elimination

Since we have function _introduction_, we'll need function _elimination_ - more commonly known as _application_ - the equivalent of setting the value part of a `let` expression and interpreting its body. You can think of it that way:
- a `let` expression needs a name, value and body to be fully interpreted.
- a function contains a name and a body, so we only need to fill in the value part.

The syntax we'll use for that is relatively standard in the ML family of languages:

```ocaml
[function] [argument]
```

Where:
- `[function]` is the function to apply.
- `[argument]` is the value we'll bind the function's parameter to.

You'll note a slight lexical subtlety: I've used both _parameter_ and _argument_ to describe "what's passed to a function". There is a distinction: I'll call a parameter the name of the value passed to a function, and argument the actual value. Which is why we'll talk of parameters for function introduction and arguments for function elimination.


### Naming functions

Now that we have syntax for it, we can start rewriting `let` expressions as functions. To take our simple example from earlier:

```ocaml
let x = 1 in
  x + 2
```

This can be thought of as a function introduction followed by its immediate application to `1`, or:


```ocaml
(x -> x + 2) 1
```

I'll readily agree that this is not as pleasant to read, but it does exactly the same thing: compute `x + 2` for `x = 1`.

One reason for which this might feel a little uncomfortable is that we're a lot more used to seeing functions as named things - typically `f`, or some variation of it. We would usually expect to declare `x -> x + 2`, name it `f`, and then call `f 1`.

Well, we just spent a rather [large article](./bindings.html) coming up with a way of naming things: bindings. It only seems reasonable to make use of all that hard work:

```ocaml
let f = x -> x + 2 in
  f 1
```

This binds our function to the name `f`, which is exactly what we wanted, but also has an interesting consequence: `let` expressions bind _values_ to names. We've bound a _function_ to the name `f`. Clearly, then, functions must be values for this to work - our language must be a functional programming language in the simplest sense of the term, a language in which functions are first class citizens.

### Interpreting a function

It's now time to start thinking about how we might interpret functions. We've made a point of treating them as more general `let` expression, so we can start from there. Applying a function, then:
- creates a new environment in which the $parameter$ is bound to the $attribute$.
- interprets the $body$ in that environment.

Taking our `(x -> x + 2) 1` example, we would:
* create environment $\\{x = 1\\}$.
* interpret `x + 2` in it.

Which yields `3`, as it should.

### Static scope

This seems perfectly reasonable, but there is an edge case to consider. What do you think this evaluates to?

```ocaml
let y = 1 in
  let f = x -> x + y in
    let y = 2 in
      f 3
```

Since we're doing static scoping, you probably expect this to evaluate to `4`: `f` is defined when the first `y` binding is in scope, so you'd expect `f` to be `x -> x + 1` and `f 3` to be `4`.

If we try interpreting it with our current rules however, we'll get `5` instead. Here are the steps to get there:
* the outermost `let` creates environment $e_1 = \\{y = 1\\}$.
* the middle `let` creates environment $e_2 = e_1[f \leftarrow (x \to x + y)]$.
* the innermost `let` creates environment $e_3 = e_2[y \leftarrow 2]$.

Interpreting `f 3` in $e_3$ shows the problem: we end up interpreting `3 + y` in an environment in which `y` is bound to `2`, which clearly yields `5`. The bindings referenced in the body of `f` end up being "overwritten" by deeper `let` expressions. We've broken static scoping. Again.

Our mistake is that we're using the wrong environment when interpreting `f 3`. We've been using $e_3$, in which `y` is bound to `2`, when we really wanted $e_1$, where `y` is bound to `1`. Or, more generally: we want to interpret functions in the environment in which they're _introduced_, not the one in which they're _applied_.

This tells us that functions are a little more complicated than a mere parameter and body: they must also keep track of their introduction environment.

The technical vocabulary for that (which I'll readily admit I've never fully understood) is that `f` _closes_ over its environment, and is thus called a _closure_.

## Operational semantics

Having built a solid intuition for functions, we need to formalize it before we can start on the fun bits, the actual coding.

### Function introduction

Let's first think about the term we need to add to our language for function introduction. Our syntax is `x -> x + 2`: the function's parameter and its body. It seems reasonable, then, to start working from:

\begin{prooftree}
  \AXC{$e \vdash \texttt{Fun}\ param\ body\ \Downarrow\ ???$}
\end{prooftree}


We have seen that functions were values. Function introduction, then, is merely the creation of such a value. We've also seen that a function value must be composed of its parameter and body, and, critically, the function's introduction environment. This gives us the relatively straightforward rule for function introduction, $\texttt{Fun}$:

\begin{prooftree}
  \AXC{$e \vdash \texttt{Fun}\ param\ body\ \Downarrow \texttt{Value.Fun}\ param\ body\ e$}
\end{prooftree}

And that's really all we need: no antecedent, just a conclusion. We call this kind of inference rule an _axiom_.

Note that this axiom implies a new type of value, $\texttt{Value.Fun}$, which we'll need to write when we start coding.

### Function elimination

Function elimination, which we'll call by the more common name $\texttt{Apply}$, looks like this:

```ocaml
f 1
```

That is, a function and its argument. This gives us the shape of our conclusion:

\begin{prooftree}
  \AXC{$e \vdash \texttt{Apply}\ fun\ arg\ \Downarrow\ ???$}
\end{prooftree}

Our first step should be to make sure that $fun$ is, in fact, a function, which we can only do by interpreting it (well yes, we are in fact only checking types at runtime, which I hope irritates you as much as it does me). The only environment in which it makes sense to interpret $fun$ is $e$:

\begin{prooftree}
  \AXC{$e \vdash fun ⇓ \texttt{Value.Fun}\ param\ body\ e'$}
  \UIC{$e \vdash \texttt{Apply}\ fun\ arg\ \Downarrow v_2$}
\end{prooftree}

We'll then want to bind the function's parameter to its argument so we can interpret its body - but in order to do that, we must know what $arg$ evaluates to (again, in $e$, for the same reason) to get the actual value:

\begin{prooftree}
  \AXC{$e \vdash fun ⇓ \texttt{Value.Fun}\ param\ body\ e'$}
  \AXC{$e \vdash arg \Downarrow v_1$}
  \BIC{$e \vdash \texttt{Apply}\ fun\ arg\ \Downarrow v_2$}
\end{prooftree}

All we have left to do is interpret $body$  - but there's a crucial subtlety here: what environment should we do this in?

We've seen that a function must be evaluated in the environment in which it was _introduced_ - $e'$ in our rule. But that's not the whole story, is it. We must not forget to bind the function's argument to its parameter, as that is rather the entire point of the whole thing.

Putting all this together, we can write a complete rule, by far the more complex we've seen so far:

\begin{prooftree}
  \AXC{$e \vdash fun ⇓ \texttt{Value.Fun}\ param\ body\ e'$}
  \AXC{$e \vdash arg \Downarrow v_1$}
  \AXC{$e'[param \leftarrow v_1] \vdash body \Downarrow v₂$}
  \TIC{$e \vdash \texttt{Apply}\ fun\ arg\ \Downarrow v_2$}
\end{prooftree}


## Implementing functions
### Functions as values

Functions being a new kind of value, we need to add a new variant to `Value`.

We can derive it from the operational semantics of function introduction:
\begin{prooftree}
  \AXC{$e \vdash \texttt{Fun}\ param\ body\ \Downarrow \texttt{Value.Fun}\ param\ body\ e$}
\end{prooftree}

A function is composed of its parameter, its body, and the environment in which it was declared:

```scala
case Fun(param: String, body: Expr, env: Env)
```

### Updating the AST

Updating the AST is, as before, done by looking at the operational semantics of our new terms to see what they're made out of.

Let's start with function introduction:

\begin{prooftree}
  \AXC{$e \vdash \texttt{Fun}\ param\ body\ \Downarrow \texttt{Value.Fun}\ param\ body\ e$}
\end{prooftree}

This tells us that our new variant for $\texttt{Fun}$ must hold the parameter name and function body:

<a name="fun"/>
```scala
case Fun(param: String, body: Expr)
```

Our other new term, function application, is defined as follows:
\begin{prooftree}
  \AXC{$e \vdash fun ⇓ \texttt{Value.Fun}\ param\ body\ e'$}
  \AXC{$e \vdash arg \Downarrow v_1$}
  \AXC{$e'[param \leftarrow v_1] \vdash body \Downarrow v₂$}
  \TIC{$e \vdash \texttt{Apply}\ fun\ arg\ \Downarrow v_2$}
\end{prooftree}

Which makes it clear that our new variant, `Apply`, must be composed of a function to apply and the argument to apply it on:

<a name="apply"/>
```scala
case Apply(fun: Expr, arg: Expr)
```

### Function introduction

We can now get to the fun bit of translating our operational semantics to code. We'll start from function introduction, which is essentially a copy/paste job from the semantics.

Taking $\texttt{Fun}$'s semantics:
\begin{prooftree}
  \AXC{$e \vdash \texttt{Fun}\ param\ body\ \Downarrow \texttt{Value.Fun}\ param\ body\ e$}
\end{prooftree}

We very easily get the Scala implementation:

<a name="runFun"/>
```scala
def runFun(param: String, body: Expr, e: Env) =
  Value.Fun(param, body, e) // e |- Fun param body ⇓ Value.Fun param body e
```

### Function Elimination

We can finally tackle `Apply`, whose operational semantics are:

\begin{prooftree}
  \AXC{$e \vdash fun ⇓ \texttt{Value.Fun}\ param\ body\ e'$}
  \AXC{$e \vdash arg \Downarrow v_1$}
  \AXC{$e'[param \leftarrow v_1] \vdash body \Downarrow v₂$}
  \TIC{$e \vdash \texttt{Apply}\ fun\ arg\ \Downarrow v_2$}
\end{prooftree}

The translation to code is, again, very simple:

<a name="runApply"/>
```scala
def runApply(fun: Expr, arg: Expr, e: Env) =
  interpret(fun, e) match
    case Value.Fun(param, body, eʹ) =>            // e |- fun ⇓ Value.Fun param body eʹ
      val v1 = interpret(arg, e)                  // e |- arg ⇓ v₁
      val v2 = interpret(body, eʹ.bind(param, v1))// eʹ[param <- v₁] |- body ⇓ v₂
      v2                                          // e |- Apply fun arg ⇓ v₂

    case _ => typeError("apply")
```

Do note how we're erroring out on any value of `fun` that is not a function. That's really how we code the fact that operational semantics only describe the success cases: anything not "caught" by a rule is by definition an error.

## Testing our implementation

In order to test our implementation, we'll take our previous example - the one that showed how a naive implementation would fail to maintain static scoping:

```ocaml
let y = 1 in
  let f = x -> x + y in
    let y = 2 in
      f 3
```

I'll write the AST for this out of sheer bullheadedness, but you really shouldn't feel like you to have to read this mess:

```scala
val expr = Let(
  name  = "y",
  value = Num(1),
  body = Let(
    name = "f",
    value = Fun(
      param = "x",
      body  = Add(Ref("x"), Ref("y"))
    ),
    body = Let(
      name = "y",
      value = Num(2),
      body = Apply(Ref("f"), Num(3))
    )
  )
)
```

Well, that wasn't very pleasant. But we can now confirm our implementation yields `4`, which gives us some confidence it's working as expected:

```scala
interpret(expr, Env.empty)
// val res: Value = Num(4)
```

## Functions with multiple parameters

You might have noticed. In this entire article, we only ever worked with unary functions - functions that take a single parameter. And you might rightfully think that this was a lot of work for a very partial feature. After all, it's very easy to think of dozens of functions that take more than one parameter - addition, for example.

The good news is, while it was indeed a lot of work, the feature is not at all partial.

An `add` function would take two parameters and return their sum. In theory, then, this is something we can't express in our language.

Now, allow your mind to shift a little. What if instead, `add` was a function that took a single parameter - call it `lhs`, returned a function that took a single parameter - call it `rhs`, and returned the sum of `lhs` and `rhs`? Given `add` and two integers, we could get their sum by applying `add` to the first, and the resulting function to the second. Here's how to write this in our language:

```ocaml
let add = lhs -> rhs -> lhs + rhs in
  add 1 2
```

That's a perfectly valid expression (feel absolutely free to write the AST value for it and confirm!), and `add` behaves, for all intents and purposes, exactly like a function with two parameters. This process of turning a function that takes _n_ parameters and turning it into a chain of _n_ functions is called _[currying](https://en.wikipedia.org/wiki/Currying)_.

## Should we drop `Let` ?

Our language now has full support for functions - which we can see as a generalised form of bindings. We _could_ decide to drop support for $\texttt{Let}$, at least in the AST: a hypothetical parser could support `let` _syntax_, but map it to function introduction followed by immediate application.

On the one hand, that would make for a leaner AST, and thus less code to write to interpret it.

On the other hand, it's sometimes useful to keep specialised terms like this in the AST: since their semantics are simpler, it allows us to write more optimal code for that specific use case.

I'll be keeping `Let` in the rest of this series, but you should feel free to experiment with dropping it.

## Where to go from there?

At this point, we have a fairly complete programming language: bindings, conditionals, functions... but we're still lacking a basic building block: loops, the ability to repeat an action multiple times. This is what we'll tackle in the next part of this series.
