---
title: Generalised folds
layout: article
sequence: 4
---

We've generalised structural recursion, but for `List` only. Let's now tackle the task of generalising `fold` - generalising generalised structural recursion, as it were.

## Generalised folds

This is our current `fold` implementation:

```scala
def fold[A](
  base: A,
  step: (Int, A) => A
): List => A = {

  def loop(state: List): A =
    state match {
      case Cons(head, tail) => step(head, loop(tail))
      case Nil              => base
    }

  loop
}
```

Our task, then, is to try and remove everything that's directly linked to `List` from that code.

## Abstracting over structure

Let's first look at the part that works specifically on the structure of a list:

<span class="figure">
![Hard-coded structure](./img/cata-1-hl-1.svg)
</span>

This takes a `List` and follows its structure to get a `Cons` or `Nil`, but an alternative way of looking at that is: we're either getting a `head` and a `tail`... or we're not. And Scala has a type meant to represent this potential absence of data: `Option`.

Using `Option` instead of `List` is not going to solve our problem - an optional `head` and `tail` is still very much a `List`. But it's at least a step in the right direction: we're moving away from `List` and towards a more generic type.

Of course, in order to work with an optional `head` and `tail`, we need to be able to turn a list into one. This is commonly known as a projection, which in our case is a straightforward pattern match: `Cons` is mapped to `Some` and `Nil` to `None`.

```scala
val project: List => Option[(Int, List)] = {
  case Cons(head, tail) => Some((head, tail))
  case Nil              => None
}
```

This allows us to update `fold` to take a projection function and remove direct references to the structure of the list:

```scala
def fold[A](
  base   : A,
  step   : (Int, A) => A,
  project: List => Option[(Int, List)]
): List => A = {

  def loop(state: List): A =
    project(state) match {
      case Some((head, tail)) => step(head, loop(tail))
      case None               => base
    }

  loop
}
```

This does, however, make our graphical view of `fold`'s behaviour a bit more complicated:

<span class="figure">
![Projection](./img/cata-2-hl-1.svg)
</span>

A word of warning: things are going to get quite a bit worse before they get better. This diagram is going to keep growing for a bit, but if you bear with me, it *will* get a lot better.

Eventually.


## Simplifying base and step

When you introduce a new type, it's always a good idea to check whether it appears elsewhere. If it does, you might be on the right track to finding common structure which, with any luck, you'll be able to abstract over.

And, in our case, option of `head` and `tail` does appear again, albeit in a slightly less obvious way:


<span class="figure">
![Projection](./img/cata-2-hl-2.svg)
</span>

`step` takes a `head` and a `tail`, and `base` takes nothing - we could sort of merge them together to get a function that takes an optional `head` and `tail`.

Let's write this compound function. We'll name it `op` because I'm really dreadful at naming things, and to follow the common sense approach of _give it a crap name until you know what it actually does_:


```scala
val op: Option[(Int, String)] => String = {
  case Some((head, tailResult)) => step(head, tailResult)
  case None                     => base
}
```

If you remember, we're still working with `mkString`: our general `fold` is called with concrete parameters that turn it into a function that computes the textual representation of a list. Within this context:
* `step` is the concatenation of the textual representations of `head` and `tail`, separated by `" :: "`.
* `base` is simply `"nil"`.

```scala
val op: Option[(Int, String)] => String = {
  case Some((head, tailResult)) => head + " :: " + tailResult
  case None                     => "nil"
}
```

This allows us to rewrite `fold` to take `op` instead of `base` and `step`:

```scala
def fold[A](
  op     : Option[(Int, A)] => A,
  project: List => Option[(Int, List)]
): List => A = {

  def loop(state: List): A =
    project(state) match {
      case Some((head, tail)) => op(Some((head, loop(tail))))
      case None               => op(None)
    }

  loop
}
```

And of course, everything still behaves exactly as it did before:

```scala
fold(op, project)(ints)
// res12: String = 3 :: 2 :: 1 :: nil
```

But the resulting diagram is slightly disappointing:

<span class="figure">
![Op, step 1](./img/cata-3-hl-1.svg)
</span>

The fact that `op` appears twice is a little bit unpleasant.

We can however easily fix that by realising that `op` appears on the right hand side of all branches of the pattern match, which allows us to move it outside of the pattern match:

```scala
def fold[A](
  op     : Option[(Int, A)] => A,
  project: List => Option[(Int, List)]
): List => A = {

  def loop(state: List): A =
    op(project(state) match {
      case Some((head, tail)) => Some((head, loop(tail)))
      case None               => None
    })

  loop
}
```

This yields the following diagram, which is a bit busier but makes the presence of our optional `head` and `tail` explicit:

<span class="figure">
![Op, step 2](./img/cata-4-hl-1.svg)
</span>

## Intermediate representation

Let's take a little time to think about that optional `head` and `tail`. I've been saying `tail` in a bit of a hand-wavy fashion, but that's not quite correct, is it?

<span class="figure">
![Option of head, tail](./img/cata-4-hl-2.svg)
</span>

On the left-hand side, we do have the tail of a list. But on the right-hand side, we have an `A`. This is not the tail of a list anymore, so what does it represent?

It helps to think of `fold` as a mechanism for finding the solution to a problem, where the problem itself is the input `List`.

`mkString`, for example, finds the solution to _what is the textual representation of this list?_. It goes from a `List`, the problem *before* it's been solved, to a `String`, the problem *after* it's been solved (also known as the solution).

And if you think about it in that light, that optional `head` and `tail` is a very concrete representation of structural recursion. Take `Option[(Int, List)]`. This contains:
- the smallest possible problem: `None`, the empty list.
- a larger problem, `Some`, decomposed into a smaller problem, `tail`, and additional information, `head`.

But `Option[(Int, A)]` is slightly different: in the `Some` case, the `tail` isn't the smaller problem anymore but its solution - the textual representation of your list, say. And this is extremely convenient! You're asked to solve your problem by being provided with:
- the smallest possible problem: `None`, the empty list.
- a larger problem, decomposed into *the solution to a smaller problem* and additional information, `head`.

This optional `head` and `tail` is an extremely interesting type, because it allows us to represent intermediate steps of our `fold`. So interesting, in fact, that we'll give it a name: `ListF`.

```scala
type ListF[A] = Option[(Int, A)]
```

There's a concrete reason for that unpleasant name. The `List` part is obvious: `ListF` has something to do with lists, so let's stick that in there. I will however not explain the `F` yet to avoid spoiling an intuition I'm hoping to build up to.

We use `ListF` to represent different steps of our `fold`.

First, the decomposition of a problem into the basic components of structural recursion, which we get through `project`:

```scala
val project: List => ListF[List] = {
  case Cons(head, tail) => Some((head, tail))
  case Nil              => None
}
```

`ListF`'s type parameter is `List`: the type of the problem before it's been solved.

But then, `ListF` also represents the decomposition of a problem into additional information and *the solution* of a smaller problem. And we can go from that to a solution of the complete problem through `op`:

```scala
val op: ListF[String] => String = {
  case Some((head, tailResult)) => head + " :: " + tailResult
  case None                     => "nil"
}
```

`ListF`'s type parameter is `String`: the type of the problem after it's been solved.

Now that we have that versatile `ListF` type, we should update `fold` to use that instead of option of `head` and `tail`:

```scala
def fold[A](
  op     : ListF[A] => A,
  project: List => ListF[List]
): List => A = {

  def loop(state: List): A =
    op(project(state) match {
      case Some((head, tail)) => Some((head, loop(tail)))
      case None               => None
    })

  loop
}
```

Which is a first step towards making our diagram slightly less noisy:

<span class="figure">
![ListF of tail](./img/cata-5-hl-1.svg)
</span>

## Generalising recursion

Now that we've done all that, I'd like you to take a look at the following part of the diagram:

<span class="figure">
![Does this look familiar?](./img/cata-5-hl-2.svg)
</span>

Does it look in any way familiar? You go from a `ListF[List]` to a `ListF[A]` by applying a mess of code that essentially boils down to `loop` - a function from `List` to `A`.

Let's see if we can make the intuition more obvious by taking the pattern match out of `loop` and into a helper function that we'll call `go` because I'm running out of names:

```scala
def fold[A](
  op     : ListF[A] => A,
  project: List => ListF[List]
): List => A = {

  def loop(state: List): A =
    op(go(project(state)))

  def go(state: ListF[List]): ListF[A] =
    state match {
      case Some((head, tail)) => Some((head, loop(tail)))
      case None               => None
    }

  loop
}
```

`go` is a function that goes from a `ListF[List]` to a `ListF[A]` by basically applying `loop`, a function from `List` to `A`.

But let's make it even more obvious by taking `loop` out of the equation and making it a parameter to `go`:

```scala
def fold[A](
  op     : ListF[A] => A,
  project: List => ListF[List]
): List => A = {

  def loop(state: List): A =
    op(go(project(state), loop))

  def go(state: ListF[List], f: List => A): ListF[A] =
    state match {
      case Some((head, tail)) => Some((head, f(tail)))
      case None               => None
    }

  loop
}
```

`go` takes a `ListF[List]`, a function from `List` to `A` and returns a `ListF[A]`.

And that's `map`! It's a function that you'll find all over the place. Given an `Option[A]` and an `A => B`, `map` gives you an `Option[B]`. Given a `Future[A]` and an `A => B`, `map` gives you a `Future[B]`. It works with `List`, `Try`... just about everything.

It's such a recurring pattern that it's commonly abstracted behind something called a functor, which is not the friendliest name but really just means _something that has a sane `map` implementation_.

This is a crucial step forward, because if we can express our requirements for `ListF` in terms of functor, maybe we can finally abstract away the structure of `List`!

Oh, and yes, this is where the `F` in `ListF` comes from, because that notion of functor is a critical part of what makes `ListF` useful.

## Functor

There are many ways we could encode functor - I toyed with using subtyping here, which would work perfectly, but decided that I didn't want to finish ruining whatever reputation I might have, so let's go with the traditional, boring approach: _type classes_.

You don't really need to know about type classes to follow, but you can learn more about them [here](../typeclasses) should you want to.

To declare a `Functor` type class, we merely need a `Functor` trait with an abstract `map` method:

```scala
trait Functor[F[_]] {
  def map[A, B](fa: F[A], f: A => B): F[B]
}
```

Now that the type class is defined, we need to provide an instance of that trait for our specific `ListF` type:

```scala
implicit val listFFunctor = new Functor[ListF] {
  override def map[A, B](list: ListF[A], f: A => B) =
    list match {
      case Some((head, tail)) => Some((head, f(tail)))
      case None               => None
    }
}
```

Note how the body of `map` is exactly the body of `go` in our current `fold` implementation:
- if we have a `head` and a `tail`, apply the specified function to the `tail`.
- otherwise, do nothing.

Next is a little bit of syntactic glue to make the rest of the code easier to read: a `map` function that, given an `F[A]`, an `A => B` and a `Functor[F]`, puts everything together and allows us to ignore tedious implementation details.

```scala
def map[F[_], A, B](
  fa     : F[A],
  f      : A => B
)(implicit
  functor: Functor[F]
): F[B] =
  functor.map(fa, f)
```

Right, with that out of the way, we can now rewrite `fold` to use `map` instead of `go`:

```scala
def fold[A](
  op     : ListF[A] => A,
  project: List => ListF[List]
): List => A = {

  def loop(state: List): A =
    op(map(project(state), loop))

  loop
}
```

Which simplifies our diagram quite a bit:

<span class="figure">
![Functor included](./img/cata-6-hl-1.svg)
</span>

Now, people that are already familiar with functors are probably also aware that the polymorphic list, `List[A]`, has a functor instance: given a `List[A]` and an `A => B`, you can get a `List[B]`.

It's important to realise that the functor instances for `List` and `ListF` are not the same thing. This is often a source of confusion, but it makes sense when you think about it: they do not work on the same things at all. The `A` of `List[A]` and in `ListF[A]` are completely different things.

In `List[A]`, `A` is the type of the values contained by the list. `List[Int]`, for example, represents a list of integers.

In `ListF[A]`, `A` is the type of the value we use to represent the tail of a list. `ListF[List]` is a direct representation of a `List`: a head and a tail. `ListF[Int]` is the representation of a list after we've turned its tail into an int, for example by computing its product.


## Abstracting over `ListF`

We're not quite done yet: `fold` still relies on `ListF`, which is strongly tied to the structure of a list.

<span class="figure">
![ListF](./img/cata-6-hl-2.svg)
</span>

If we look at the code though, the only thing we actually need to know about `ListF` is that we can call `map` on it - that it has a `Functor` instance. This allows us to rewrite `fold` in a way that works for any type constructor `F` that has a `Functor` instance:

```scala
def fold[F[_]: Functor, A](
  op     : F[A] => A,
  project: List => F[List]
): List => A = {

  def loop(state: List): A =
    op(map(project(state), loop))

  loop
}
```

This gives us `ListF`-free implementation:

<span class="figure">
![Generalised ListF](./img/cata-7-hl-1.svg)
</span>

## Abstracting over `List`

Finally, the last step is abstracting over `List`, which is still the input type of our generic `fold`:

<span class="figure">
![List](./img/cata-7-hl-2.svg)
</span>

That turns out to be much simpler than we might have though: we never actually use the fact that we're working with a `List`. All we need to know about that type is that we can provide a valid `project` for it. This allows us to turn `List` into a type parameter:

```scala
def fold[F[_]: Functor, A, B](
  op     : F[A] => A,
  project: B => F[B]
): B => A = {

  def loop(state: B): A =
    op(map(project(state), loop))

  loop
}
```

Which gives us a `List`-free implementation:

<span class="figure">
![Generalised List](./img/cata-8-hl-1.svg)
</span>

## Naming things

Now that we have a fully generic implementation that we're happy with, we need to start thinking about names. The generic fold has kind of a scary name: `catamorphism`, often simplified to `cata`:

```scala
def cata[F[_]: Functor, A, B](
  op     : F[A] => A,
  project: B => F[B]
): B => A = {

  def loop(state: B): A =
    op(map(project(state), loop))

  loop
}
```

While the name is intimidating, it's meaning is quite clear once you think about it. `cata` means _I know ancient greek_, `morphism` means _I know category theory_, which gives us `catamorphism` - _I know more than you do_.

And, of course, `op` has a proper, functional name. It's called, like just about everything else in functional programming, an _algebra_ (well, an F-Algebra, to be specific).

```scala
def cata[F[_]: Functor, A, B](
  algebra: F[A] => A,
  project: B => F[B]
): B => A = {

  def loop(state: B): A =
    algebra(map(project(state), loop))

  loop
}
```

`F` also has a more official name: _pattern functor_, or _base functor_, depending on the papers you read.

We've seen that the pattern functor could be thought of as a representation of intermediate steps in a structural recursion (or in any recursive algorithm, really): the decomposition of a problem, before and after solving its sub-problems.

Having named everything, we get this final representation of a catamorphism:

<span class="figure">
![Catamorphism](./img/cata-9.svg)
</span>

## `product` as a cata

Before finishing our study of catamorphisms: we said that they were generalised structural recursion. If they're generalised, surely we should be able to write another structural recursion problem, `product`, as a catamorphism:

```scala
val productAlgebra: ListF[Int] => Int = {
  case Some((head, tailProduct)) => head * tailProduct
  case None                      => 1
}

val product: List => Int =
  cata(productAlgebra, project)
```

And, yes, this yields the expected result:

```scala
product(ints)
// res19: Int = 6
```

## Key takeaways

We've seen that catamorphisms are far less complicated than their names make them out to be: a relatively straightforward refactoring away from familiar folds. And they would, in theory, allow us to write structural recursion algorithms on any type that can be projected into a pattern functor.

It's a bit of a shame that the only type we've seen that work on is `List`, then, isn't it?
