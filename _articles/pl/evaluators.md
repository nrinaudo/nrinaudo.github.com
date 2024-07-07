---
title: Evaluating source code
layout: article
series: pl
date:   20240614
---

This is mostly going to paraphrase [Programming Languages: Application and Interpretation](https://www.plai.org/), as I found the introduction of that book very good and motivating.

## Writing a language

The first question we should ask ourselves is, what does it mean to write a programming language?

Well, it must mean to write some sort of program. This program must work on source code, and... do something to it. Here are some common things one might wish do with source code:
- shuffle bits of it around, perhaps to unify the way it's formatted to an agreed upon set of standards. We call this _formatting_ source code (this is a very good idea and should be part of your CI).
- rewrite chunks that can be simplified, for example by computing anything that can be computed before actually running the code. We call this _optimizing_ source code.
- simulate its execution to produce whatever output running the code would. We call this _interpreting_ source code.
- turn it into valid source code for a different programming language. We call this _compiling_ source code (bear in mind that the different programming language might very well be machine language).

Notice how all of these have a common shape: take source code as input, and produce a value (more source code, the result of running the program, ...). All these things are _evaluators_ for our language.

We'll hopefully play with all of these before we're done, but our focus will, at least initially, be on interpreters.

## The substitution model
### Our first program
Let us write a very simple program, and see how we would interpret it:

```ocaml
fun f x = x + 1
f 2
```

This defines a function that takes an `x` and adds `1` to it, and then calls it with an argument of `2`.


I find it easier to think of this as two distinct kinds of information:
- the function definition (`fun f...`) is _knowledge_ that we have.
- the function application (`f 2`) is our _target_, what we're trying to compute.

I like to represent this as a table, as it feels clear and readable:

| Target | Knowledge     |
|--------|---------------|
| `f 2`  | `f x = x + 1` |


Presented like this, we can see that a natural way of interpreting `f 2` would be to use whatever knowledge we have to simplify it, until it can no longer be simplified.

Here, for example:

| Target  | Knowledge     | Action                      |
|---------|---------------|-----------------------------|
| `f 2`   | `f x = x + 1` | Substitute `f` with `x + 1` |
| `x + 1` | `x = 2`       | Substitute `x` with `2`     |
| `2 + 1` |               | Simplify `2 + 1`            |
| `3`     |               | _N/A_                       |

Note how, by convention, I remove things from the _Knowledge_ column when they're no longer needed. It does not mean the the knowledge has disappeared, but it does make these tables a lot easier to read.

This model is nice and clear, but can lead to ambiguities.

### Innermost or outermost first?

Take the following program:

```ocaml
fun f x = x + 1
fun g y = f (y + 3)
g 2
```

We can start our substitution process easily enough:

| Target      | Knowledge                           | Action                          |
|-------------|-------------------------------------|---------------------------------|
| `g 2`       | `f x = x + 1`<br/>`g y = f (y + 3)` | Substitute `g` with `f (y + 3)` |
| `f (y + 3)` | `f x = x + 1`<br/>`y = 2`           | _???_                           |

But we must stop here, because it's not clear what our next step should be. Do you see it?

We could do one of:
- substitute `f` with its definition.
- substitute `y` with its definition.

This doesn't necessarily feel like an important decision - surely both these strategies yield `6`?

Well, they do. But this can still have a large impact - including, but not limited to, on performance.

Take the following program:

```ocaml
fun f x = x + x
fun g y = f (y + 3)
g 2
```

Let's first run through it using an _innermost first_ substitution strategy - that is, we always simplify the parameters of a function before substituting the function for its body.

| Target      | Knowledge                           | Action                          |
|-------------|-------------------------------------|---------------------------------|
| `g 2`       | `f x = x + x`<br/>`g y = f (y + 3)` | Substitute `g` with `f (y + 3)` |
| `f (y + 3)` | `f x = x + x`<br/>`y = 2`           | Substitute `y` with `2`         |
| `f (2 + 3)` | `f x = x + x`                       | Simplify `2 + 3`                |
| `f 5`       | `f x = x + x`                       | Substitute `f` with `x + x`     |
| `x + x`     | `x = 5`                             | Substitute `x` with `5`         |
| `5 + 5`     |                                     | Simplify `5 + 5`                |
| `10`        |                                     | _N/A_                           |

You can see that with this approach, we only compute `2 + 3` once, before replacing `f`. Had we made a different choice though and used an _outermost first_ substitution strategy:

| Target          | Knowledge                           | Action                          |
|-----------------|-------------------------------------|---------------------------------|
| `g 2`           | `f x = x + x`<br/>`g y = f (y + 3)` | Substitute `g` with `f (y + 3)` |
| `f (y + 3)`     | `f x = x + x`<br/>`y = 2`           | Substitute `f` with `x + x`     |
| `x + x`         | `y = 2`<br/>`x = y + 3`             | Substitute `x` with `y + 3`     |
| `y + 3 + y + 3` | `y = 2`                             | Substitute `y` with `2`         |
| `2 + 3 + 2 + 3` |                                     | Simplify `2 + 3`                |
| `5 + 2 + 3`     |                                     | Simplify `5 + 2`                |
| `7 + 3`         |                                     | Simplify `7 + 3`                |
| `10`            |                                     | _N/A_                           |

This has one more step than the previous one, because we had to compute `2 + 3` twice. This substitution strategy can, in some cases, end up being more computationally expensive (at least when applied naively).

The reverse is true, too. Imagine the following program:

```ocaml
fun f x y z = if x then y else z
fun g x' y'  = f x' (y' + 1) (y' + 2)
g true 3
```

Let's not run through the whole substitution explicitly, although you should feel absolutely free to do it on a piece of paper. The point is:
- if we substitute outermost first, `y' + 2` is never needed (it's the `else` branch of an `if` statement whose predicate is always `true`), and thus never computed.
- if we substitute innermost first, `y' + 2` will be computed (parameters to functions are always computed before applying the function), even though we never actually need it.

In that scenario, innermost first is more expensive than outermost first.

This rather long section is meant to illustrate the following point: innermost or outermost first is an important choice with far reaching consequences. It's a common enough topic that we have words for this:
- outermost is called _lazy evaluation_: we delay computing things until we know we actually need them.
- innermost is called _eager evaluation_: we compute things as soon as we can.

We'll be using eager evaluation, mostly because it's the way most languages go, and because it's a more intuitive substitution strategy.

## Where does that leave us?

We now have a relatively clear model of how to interpret code: use whatever knowledge we can to simplify it, step by step, until we can no longer substitute anything. At this point, we'll consider the code fully interpreted.

Our next step is going to be to try and implement such a substitution mechanism.
