---
title: Strutural recursion
layout: article
series: recschemes
sequence: 2
---

Now that we have our recursive data type - the monomorphic list - we can start working with it. Intuitively, you can see that if we're working with recursive types, we're probably going to look at recursive algorithms.

There are different common strategies to manipulate recursive types, each meant to solve a specific kind of problem. The one we're going to concern ourselves with first, by far the most common, is structural recursion: a form of recursion where you let the structure of your type drive you.

## Product

We could, for example, compute the product of our list. Here's a naive implementation:

```scala
def product(
  values: List
): Int =
  values match {
    case Cons(head, tail) => head * product(tail)
    case Nil              => 1
  }
```

Purist will complain that, for large enough lists, this will cause runtime exceptions: this implementation is what we call stack unsafe, because each step in the recursion consumes a stack frame, and we'll eventually consume more than are available. There are solutions to this problem, but they can make the code a bit awkward, so for the sake of clarity, we'll pretend that problems of stack do not exist.

This function follows the structure of its input list:
- if we have a `Cons`, multiply the `head` by the product of the `tail`.
- if we have `Nil`, use the neutral element for product: `1`.

This eventually turns our list into `3 * 2 * 1 * 1`, which is exactly the result we were looking for:

```scala
product(ints)
// res0: Int = 6
```


And if you look at this from a higher perspective, what we're doing is:
- providing a solution to the smallest possible problem, the empty list.
- splitting larger problems into smaller chunks: a smaller list (the `tail`), and additional data (the `head`).

## String representation

This pattern comes up all the time. Imagine, for example, that you wanted to compute the string representation of a list.

```scala
def mkString(
  values: List
): String =
  values match {
    case Cons(head, tail) => head + " :: " + mkString(tail)
    case Nil              => "nil"
  }
```

We're doing exactly the same thing:
- the solution for `Nil` is `"nil"`.
- larger lists are split into their `head` and `tail`, and we concatenate their respective string representations, separated by `" :: "`.


## Key takeaways

These are the important parts of structural recursion:
- the smallest possible problem, which we must provide a solution to.
- larger problems, themselves composed of:
  - a smaller problem, which we assume we have a solution to.
  - additional information, which we use to update the solution to the smaller problem.

If these make you think of proof by induction, this is of course not at all a coincidence.

Since structural recursion is composed of a set of well-defined moving parts, our next task is going to be to abstract the common code away and allow coders to only worry about the interesting bits.
