---
title: Repeating actions
layout: article
series: pl
date:   20240713
code:   https://github.com/nrinaudo/programming_a_language/tree/main/untyped/src/main/scala/package.scala
---

One thing our language still lacks is the ability to repeat an action multiple times. This is typically necessary to compute things over ranges of numbers (or lists or queues or...). Most languages achieve this using dedicated constructs called _loops_.

## Loops

One could, for example, wish to sum all numbers in a given range, which you'll often see implemented using a `for` loop.

### `for` loops
A `for` loop typically works by iterating over a range of numbers, and:
- keeping track of the current iteration with an iterating variable (traditionally called `i`).
- accumulating the result of each iteration in an accumulating variable (traditionally called `acc`).

There are variations (you could, for example, vary the size of the increment, range over an ordered collection rather than numbers, ...), but they're all syntactic sugar for that basic schema.

Adding all numbers in a given range could be written using the following loop:

```ocaml
let sumFor = lower -> upper ->
    var acc = 0
    for i = lower to upper do
      acc = acc + i
    acc
  in sumFor 1 10
```

There are two things I'm not a big fan of here, though.

First, `for` loops do not give us a way of doing anything with the result of each iteration. Unless, that is, our language supports mutability, which I've had to use in the above code to modify the accumulator. Mutability is not inherently bad, but it's also a large source of complexity and I would rather avoid having to support it until there really is no other choice.

Second, `for` loops are quite limited: you need to know how many times you want to repeat the computation. It would be nicer to work with loops that don't have this limitation.

### `while` loops
That's exactly what `while` loops are for. They're a more generic form of `for` loops, in that rather than maintaining an incrementing variable for you, they'll simply evaluate a predicate on each iteration and keep looping until that evaluates to `false`. `for` loops are a specific kind of `while` loop in which the predicate is _have I ran the expected number of iterations_.

The good news is that, you can turn any `for` loop into a more generic `while` mechanically. The principle is simple:
- maintain your own iterating variable by initialising it to the range's lower bound and incrementing it by one on each iteration.
- break out of the loop as soon as the iterating variable goes over the range's upper bound.

The previous `sumFor` function can trivially be transformed to use a `while` loop by following this process:

```ocaml
let sumWhile = lower -> upper ->
    var acc = 0
    var i   = lower
    while i < upper do
      acc = acc + i
      i   = i + 1
    acc
  in sumWhile 1 10
```

We could conceivably write code to do that for us on any `for` loop (we won't, though, that sounds like more work than I'm ready to put into it). We could, then:
- have support for `for` loops in the _syntax_ of our language, something that a parser would need to understand.
- transform them into `while` loops when parsing, so that our AST need only support `while`.

That is, we could treat `for` loops as syntactic sugar for `while` loops

But they still have the annoying limitation of requiring mutability. If that's not clear, think about it this way: the only way of breaking out of a `while` is for its predicate to suddenly start evaluating to `false` when it used to evaluate to `true`. How could you achieve that without mutating something?

Luckily, we can also work around that.

### Recursion

Here's another way you can think of `sumWhile`: for each iteration, `i` and `acc` act as input, and `acc + i` as output.

By following this thought to its logical conclusion, you can rewrite the body of our `while` loop as a function taking `acc` and `i` for input, and then calling _itself_ until the predicate evaluates to `false`. We don't have to mutate the values of `i` and `acc` any longer, just pass new values to each call.

This is what it would look like:

```ocaml
let sumRec = lower -> upper ->
    (* `acc` and `i` are parameters *)
    let go = acc -> i ->
      (* If the predicate is not falsified, "loop" after updating `acc` and `i`. *)
      if i < upper then go (acc + i) (i + 1)
      (* Otherwise, we're done *)
      else acc

    (* `acc` is initialised to `0`, `i` to the first element in the range. *)
    in go 0 lower
  in sumRec 1 10
```

This is equivalent to `sumWhile`, but does not require mutability. It does, however, need for our language to allow functions to call themselves - to support _recursive functions_.

This transformation can be made as automatic as the one from `for` to `while` loops. Which means that if we support recursive functions, we could add `for` and `while` to our syntax, but rewrite them to recursive function calls in the AST, essentially having our cake and eating it, too.

Before we move on, however, and now that we have decided to add support for recursive functions, I really must give a more reasonable implementation of `sum`:

```ocaml
let sum = lower -> upper ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10
```

I find this kind of code lovely. Rather than being very prescriptive of the process to follow to find the solution, it looks much more like a description of the problem itself:
- if the range is empty, then its sum is 0.
- otherwise, it's the addition of the first element in the range and the sum of the remaining ones.

## Do we already support recursion?

You might be tempted to think we already support recursive functions - after all, we already support bindings and functions, which appear to be all that `sum` needs to work. Well, that, and some way of comparing `lower` and `upper`, but that bit really isn't all that hard to add.

### Supporting `Gt`

This is nothing we haven't done before, so let's go through it quickly. First, the operational semantics, which are rather self-explanatory:

\begin{prooftree}
  \AXC{$e \vdash lhs ⇓ \texttt{Value.Num}\  v1$}
  \AXC{$e \vdash rhs ⇓ \texttt{Value.Num}\  v2$}
  \BIC{$e \vdash \texttt{Gt}\ lhs\ rhs\ \Downarrow \texttt{Value.Bool} (v1 > v_2)$}
\end{prooftree}

This tells us we need to add the following variant to our AST:

<a name="gt"/>
```scala
case Gt(lhs: Expr, rhs: Expr)
```

Interpretation of $\texttt{Gt}$ is very similar to how we handle $\texttt{Add}$, and can be derived painlessly from the operational semantics:

<a name="runGt"/>
```scala
def runGt(lhs: Expr, rhs: Expr, e: Env) =
  (interpret(lhs, e), interpret(rhs, e)) match
    case (Value.Num(v1), Value.Num(v2)) => Value.Bool(v1 > v2)
    case _                              => typeError("gt")
```

And that's really all there is to supporting $\texttt{Gt}$. I did say it was going to be simple.

### Testing `sum`

Right. We have everything we need to write `sum`, which will _not_ be fun but not particularly hard either.

```scala
val sum = Let(
  name  = "sum",
  value = Fun(
    param = "lower",
    body  = Fun(
      param = "upper",
      body  = Cond(
        pred = Gt(Ref("lower"), Ref("upper")),
        onT  = Num(0),
        onF  = Add(
          lhs = Ref("lower"),
          rhs = Apply(
            fun = Apply(Ref("sum"), Add(Ref("lower"), Num(1))),
            arg = Ref("upper"))
        )
      )
    )
  ),
  body = Apply(Apply(Ref("sum"), Num(1)), Num(10))
)
```

In theory, then, we should be able to interpret that directly. If you haven't guessed by now that it was going to blow up in our faces, I would suggest a small break and maybe a cup of coffee.

```scala
interpret(sum, Env.empty)
// java.lang.RuntimeException: Unbound variable: sum
```

So, no, apparently, we do not have everything we need. At some point, someone tries to access the value referenced by `sum`, in an environment where no value is bound to it.

## Intuition

Let's think things through a little. Recall the operational semantics of $\texttt{Let}$:

\begin{prooftree}
  \AXC{$e \vdash value \Downarrow v_1$}
  \AXC{$e[name \leftarrow v_1] \vdash body \Downarrow v_2$}
  \BIC{$e \vdash \texttt{Let}\ name\ value\ body \Downarrow v_2$}
\end{prooftree}

This makes it clear that $value$ is interpreted in $e$, but that $name$ is only bound in $e[name \leftarrow v_1]$.

Now look at the code of `sum`:

```ocaml
let sum = lower -> upper ->
    if lower > upper then 0
    else lower + (sum (lower + 1) upper)
  in sum 1 10
```

$name$, which here is `sum`, appears in $value$ - which is interpreted in $e$ and not $e[name \leftarrow v_1]$. No wonder it's not working!

This feels like a complicated problem to solve, doesn't it? In order to evaluate `sum`'s body, we need to have evaluated `sum`'s body. Something will have to give.

### `let rec`

What we'll need, then, is a new term in our language, a new kind of `let` expression in which $value$ is interpreted in an environment in which it's bound to $name$. This is traditionally called `let rec`.

The way around `let`'s problem is to realize that $value$ here is a function introduction, $\texttt{Fun}$, whose semantics are:

\begin{prooftree}
  \AXC{$e \vdash \texttt{Fun}\ param\ body\ \Downarrow \texttt{Value.Fun}\ param\ body\ e$}
\end{prooftree}

We are storing the environment in which the function is introduced, but _not_ actually using it! This will only happen later, at application time.

In our case, it means the environment will be captured when creating the function, before binding it to the name `sum`, but not used before application in the body of the `let` expression. Or, put another way, we go through the following steps:
1. Capture the environment in which the function is defined (when producing a function value).
2. Bind that value to the name `sum` (to produce the environment in which the body of the `let` expression will be interpreted).
3. Use the environment in which `sum` was defined (when applying the function).

We can see that in step 2, we hold both the value of `sum` and the environment in which it must be bound, and that the latter won't be queried until step 3. That's our window of opportunity! The trick, then, is to add a new step between 2 and 3 in which we update the environment with the necessary binding.

Note that yes, I have in fact just said that we'll be relying on mutable state. It's important to realise that this is not quite the same thing as adding mutability _to the language_: it's merely an implementation detail of the language's _interpreter_.

### Avoiding dynamic scoping

There's a pretty serious flaw in our intuition, however. What do you think the following code should evaluate to?

```ocaml
let x = 1 in
  (let rec x = 2 in 3) + x
```

Hopefully it's pretty clear this is a complicated way of saying `4`. But if we follow our intuition for the way `let rec` works, we get:
- the `let` expression creates $e = \\{x = 1\\}$.
- the `let rec` expression mutates it to $\\{x = 2\\}$ - we'll write this $e[x \coloneqq 2]$.
- the `x` reference is interpreted in $e$, in which `2` is bound to it.

An existing binding was changed by a later `let` expression - dynamic scoping certainly has a way of sneaking up on us when we're not paying attention, doesn't it.

This is why I'm so reluctant to support mutability - it's a very powerful tool, but one that is deceptively easy to get subtly wrong.

What we want to do, then, is to work with a _different_ environment. We do not want to update $e$, but to create a new one we can mutate to our heart's content without impacting $e$. With that, the previous code would run as follows:
- the `let` expression creates $e_1 = \\{x = 1\\}$.
- the `let rec` expression creates a new environment $e_2$ with the same bindings as $e_1$.
- it then updates it in place: $e_2[x \coloneqq 2]$.
- the `x` reference is interpreted in $e_1$, in which it correctly maps to `1`.

And this would lead to the expected result of `4`.

This is _the_ critical realisation about recursive bindings: their value must be interpreted in a distinct environment, one which we're free to mutate without impacting the rest of the program.

## Operational semantics

As usual, let's start with the shape of our problem. $\texttt{LetRec}$ contains exactly the same element as $\texttt{Let}$, it simply has different semantics, so we'll want something like:

\begin{prooftree}
  \AXC{$e \vdash \texttt{LetRec}\ name\ value\ body \Downarrow\ ???$}
\end{prooftree}

We're doing eager evaluation, so the first thing we need to do is evaluate $value$ - but as we've seen, the entire thing hinges on what environment we do that in. We said we wanted a new environment which contained the same bindings as $e$. Instinctively, we could achieve that by creating a new primitive that clones an existing environment - and that would work! but the literature seems to agree on a different approach, presumably to reduce the number of necessary primitives (if you know of a better reason, I would be very keen to hear it!)

See, we already know how to create a new environment from an existing one: by adding a new binding to it. Of course, we don't have a value available yet, but we've seen that this wasn't actually a problem: that value will only be needed in $body$, so as long as we make sure to update the binding to the right value before interpreting $body$, we can initialise it to anything. We'll use $\bullet$ to express that notion of _I don't actually care what value this is_.

Since we'll need to update the newly created environment, we must also give it a name to be able to reference it later. Let's use $e'$, which gives us:

\begin{prooftree}
  \AXC{$e' = e[name \leftarrow \bullet]; e' \vdash value \Downarrow v_1$}
  \UIC{$e \vdash \texttt{LetRec}\ name\ value\ body \Downarrow v_2$}
\end{prooftree}

You might think that $e$ and $e'$ containing the exact same bindings, we could use one or the other here, but it's crucially important to use $e'$. It will be captured by the function declared in $value$, which is why mutating $e'$ later will be seen by it.

We're now ready to interpret $body$, but we must not forget that it must be done in $e'$ _after_ it's been mutated to bind $v_1$ to $name$.
This gives us the final operational semantic:

\begin{prooftree}
  \AXC{$e' = e[name \leftarrow \bullet]; e' \vdash value \Downarrow v_1$}
  \AXC{$e'[name \coloneqq v_1]; e' \vdash body \Downarrow v_2$}
  \BIC{$e \vdash \texttt{LetRec}\ name\ value\ body \Downarrow v_2$}
\end{prooftree}

## Implementing recursion

### Updating the AST

We've only really declared a new primitive here: `let rec`, used to introduce recursive functions. These are, once introduced, regular functions, applied exactly like all others, so we don't need a special elimination form for them.

As we've said, a `let rec` expression is very similar to a `let` one, and what few differences exist are only observed during interpretation. We can then basically clone and rename the `Let` variant:

<a name="letRec"/>
```scala
case LetRec(name: String, value: Expr, body: Expr)
```

We now have everything we need to represent `sum`. Exactly what we had before, except we need to replace `Let` with `LetRec`:

<a name="sum"/>
```scala
val sum = LetRec(
  name  = "sum",
  value = Fun(
    param = "lower",
    body  = Fun(
      param = "upper",
      body  = Cond(
        pred = Gt(Ref("lower"), Ref("upper")),
        onT  = Num(0),
        onF  = Add(
          lhs = Ref("lower"),
          rhs = Apply(
            fun = Apply(Ref("sum"), Add(Ref("lower"), Num(1))),
            arg = Ref("upper"))
        )
      )
    )
  ),
  body = Apply(Apply(Ref("sum"), Num(1)), Num(10))
)
```


"All" we have to do now is interpret it. Famous last words.

### Making the environment mutable

In order for $\texttt{LetRec}$ to work, we've seen that we needed to be able to update the value of a binding in place - the $e[name \coloneqq value]$ operation.

This is relatively easy to support. First, we must make bindings mutable, which is as simple as adding a well placed `var` keyword:

```scala
case class Binding(name: String, var value: Value)
```

We then need to provide a way to find and modify an existing binding, which we'll do with a new `set` method in `Env`:

<a name="set"/>
```scala
// e[name := value]
def set(name: String, value: Value) =
  env.find(_.name == name)
     .foreach(_.value = value)
```

### Making the environment nullable

If you remember the semantics of $\texttt{LetRec}$, there is one last bit we need to add support for in the environment: $\bullet$.

We're using it to say _I don't actually have a value yet_, which is all very good until you actually have to implement it. Scala is one of these languages that has a perfect representation for this, however: `null`! Yes, I am in fact talking of using both mutability and nullability in the same bit of code, which flies in the face of accepted wisdom but just happens to be the right tool for the job here.

Fortunately, Scala goes some way towards making `null` more palatable, as it forces you to make it explicit in your types (provided you're using the [right compiler options](https://docs.scala-lang.org/scala3/reference/experimental/explicit-nulls.html)).

Here's how we need to update `Binding` for it to have a nullable value:

<a name="binding"/>
```scala
case class Binding(name: String, var value: Value | Null)
```

This has a few repercussions. First, the $e[name \leftarrow \bullet]$ tells us that `bind` must be updated to accommodate for `null`:

```scala
def bind(name: String, value: Value | Null) =
  Env(Env.Binding(name, value) :: env)
```

And of course, we must make sure to fail when looking up a name bound to a `null` value, as this signifies that the name is not actually bound to anything as surely as if it wasn't in our environment at all.

```scala
def lookup(name: String) =
  env
    .find(_.name == name)
    .flatMap(binding => Option.fromNullable(binding.value))
    .getOrElse(sys.error(s"Missing binding: $name"))
```

### Updating the interpreter

Our environment is now fully ready to support $\texttt{LetRec}$. We merely need to translate the operational semantics into the corresponding code.

The semantics we agreed on are:

\begin{prooftree}
  \AXC{$e' = e[name \leftarrow \bullet]; e' \vdash value \Downarrow v_1$}
  \AXC{$e'[name \coloneqq v_1]; e' \vdash body \Downarrow v_2$}
  \BIC{$e \vdash \texttt{LetRec}\ name\ value\ body \Downarrow v_2$}
\end{prooftree}

And now that our environment is both nullable and mutable, they are easy enough to translate into code:

<a name="runLetRec"/>
```scala
def runLetRec(name: String, value: Expr, body: Expr, e: Env) =
  val eʹ = e.bind(name, null)   // eʹ = e[name <- ●]
  val v1 = interpret(value, eʹ) // eʹ |- value ⇓ v₁

  eʹ.set(name, v1)              // eʹ[name := v₁]
  val v2 = interpret(body, eʹ)  // eʹ |- body ⇓ v₂

  v2                            // e |- LetRec name value body ⇓ v₂
```

All that remains is for us to confirm our implementation is correct by interpreting `sum`, the program we declared earlier that computes the sum of all numbers between 1 and 10, and observing that it returns the right result:

```scala
interpret(sum, Env.empty)
// val res: Value = Num(55)
```


## Should we drop `Let` (again)?

Since `let rec` seems to offer the same tools as `let`, but also supports recursive definitions, do we need `let` at all? Could we just update it to use `let rec`'s semantics, and use that all the time instead?

On the one hand, yes, we could. On the other, `let` does have one property that `let rec` does not. Consider the following code:

```ocaml
let x = 1 in
  let x = x + 2 in
    x
```

With normal `let` semantics, this interprets to `3`, which is what your intuition should tell you is right. If `let` had the same semantics as `let rec`, however, we could not create a binding by reusing the value referenced to by a previous binding of the same name - the very purpose of `let rec` is to make these two the same.

Whether or not this kind of shadowing is desirable seems to be more of a matter of opinion than fact. From what I understand, it's considered a terrible sin by the Scala community, but excellent practice in the Rust one. Since it's not a clearly undesirable thing, we should probably keep it. Just in case, you understand.


## Where to go from here?

Our language now has all the basic building blocks one might need - the theory goes that every interesting program can now be written using `Expr`. It might require a lot of work, and we might want to enrich our language to provide more facilities out of the box, but it's possible.

One thing we might want to look into, before moving on to more high-level features, is something I find slightly distasteful: it's perfectly possible to write programs that make no sense, and not find out about it until we interpret them. We can, for example, write code that adds a number to a boolean.

We will start looking into techniques to confirm that a program makes sense before interpreting it in the next part of this series.
