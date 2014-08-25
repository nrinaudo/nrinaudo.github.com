---
title: Collections as type classes
tags: scala, haskell
---

I've been reading Chris Okasaki's [Purely Functional Data Structures](http://www.amazon.co.uk/gp/product/B00AKE1V04/ref=s9_simh_gw_p351_d3_i1?pf_rd_m=A3P5ROKL5A1OLE&pf_rd_s=center-2&pf_rd_r=02B6DPVTMCQXB84VAF5F&pf_rd_t=101&pf_rd_p=455344027&pf_rd_i=468294)
and implementing its various structures in Scala, which turns out to be surprisingly good fun.

I feel, however, that the object oriented approach taken by Scala for its collections is a bit constraining, and have
been experimenting with a type class based approach instead.



<!--more-->


## Rationale

Collection APIs are usually composed of various well known abstract data structures and their concrete implementations.

Abstract data structures do not define how things are implemented, but rather what operations they must support. A
`Stack`, for example, is an abstract data structure that supports:

* checking whether it's empty (`isEmpty`)
* adding a value at its top (`push`)
* reading the value at its top (`top`)
* removing its top (`pop`)

A variety of concrete data structures can support these operations - for the sake of argument, let's use the functional
list, with:

* `Stack.isEmpty` $\Leftrightarrow$ `List.isEmpty`
* `Stack.push` $\Leftrightarrow$ `List.::`
* `Stack.top` $\Leftrightarrow$ `List.head`
* `Stack.pop()` $\Leftrightarrow$ `List.tail`

There really is no reason to force `List` to be a `Stack` - stating that a list is a stack is not correct. It can be
used as one, certainly, but the essence of a list is not being a stack.

There is in fact so little reason to define a list as a stack that, while the Scala standard library defines both
data structures, there is no explicit relationship (that I could find) between the two.

On the other hand, as we've seen above, a list _can be used as_ a stack: we should be able to write a type class that
allows us to use arbitrary data structures, lists in particular, as stacks.



## Functional lists as "something like a stack"

We're trying to write a bridge between concrete data structures and `Stack`: a type class that allows us to use
arbitrary type as "something like a stack". I'll be referring to these as stack-like structures in the rest of this
post.

In order to write such a type-class, we need to venture in the dark corners of the Scala type system and use
higher-kinded types. This isn't the topic of this post, however, so just think of higher-kinded types as types of types,
just like higher-order functions are functions of functions.

Here's how one could go about writing the contract for stack-like structures:
```scala
import scala.language.higherKinds

trait StackLike[Impl[_]] {
  // Checks whether the stack is empty.
  def isEmpty[A](as: Impl[A]): Boolean

  // Pushes a value onto the stack.
  def push[A](a: A, as: Impl[A]): Impl[A]

  // Returns the top of the stack.
  def top[A](as: Impl[A]): A

  // Removes the top of the stack.
  def pop[A](as: Impl[A]): Impl[A]
}
```

Don't worry about the `Impl[_]` bit if you don't understand it, it's just Scala syntax for
"`Impl` is a type constructor". What `StackLike`'s type constraint is stating is that `StackLike` works on types that
"contain" other types, without locking these other types down. This allows to create a `StackLike` implementation
for `List`, for example, rather than for `List[Int]`.


Writing a `StackLike` implementation for `List` is straightforward:
```scala
implicit object ListStack extends StackLike[List] {
  override def isEmpty[A](as: List[A])    = as.isEmpty
  override def push[A](a: A, as: List[A]) = a :: as
  override def top[A](as: List[A])        = as.head
  override def pop[A](as: List[A])        = as.tail
}
```

We've now created a type class for stack-like things, and an instance of that type class for lists. Let's put it to use
by writing safe `top` function:
```scala
def safeTop[A, S[_]: StackLike](stack: S[A]): Option[A] = {
  val stackLike = implicitly[StackLike[S]]

  if(stackLike.isEmpty(stack)) None
  else                         Some(stackLike.top(stack))
}

// Some(1)
safeTop(List(1, 2, 3, 4, 5))

// None
safeTop(List())
```

Well, this works. It compiles and behaves as expected. It's just... it wasn't very pleasant to write, and probably isn't
very pleasant to read, either. The type constraint is nasty, and even though we're trying to write purely functional
code, Scala is also an object oriented language and I'd much rather write `stack.isEmpty` than
`stackLike.isEmpty(stack)`.



## Stack-like structures as Stacks

In order to write code such as `stack.isEmpty`, we first need to define a `Stack` trait. Here's a possible definition:
```scala
trait Stack[A] {
  // Checks whether the stack is empty.
  def isEmpty: Boolean

  // Pushes a value at the top of the stack.
  def push(a: A): Stack[A]

  // Returns the value at the top of the stack.
  def top: A

  // Removes the value at the top of the stack.
  def pop(): Stack[A]
}
```

We now have a trait that defines what a stack is, and another that allows us to treat arbitrary data structures as
stack-like ones. All we need is a simple way to go from one to the other, which sounds like a perfect job for
Scala's implicit conversion mechanism:

```scala
implicit class Wrapped[A, Impl[_] : StackLike](stack: Impl[A]) extends Stack[A] {
  private lazy val stackLike = implicitly[StackLike[Impl]]

  override def isEmpty    = stackLike.isEmpty(stack)
  override def push(a: A) = new Wrapped(stackLike.push(a, stack))
  override def top        = stackLike.top(stack)
  override def pop()      = new Wrapped(stackLike.pop(stack))
}
```

Having an implicit conversion from objects that have an implicit `StackLike` implementation to instances
of `Stack`, we can rewrite our `safeTop` function in a much more pleasant way:
```scala
def safeTop[A](stack: Stack[A]): Option[A] = {
  if(stack.isEmpty) None
  else              Some(stack.top)
}

// Some(1)
safeTop(List(1, 2, 3, 4, 5))

// None
safeTop(List())
```

The Scala compiler will realise that `safeTop(List(1, 2, 3, 4, 5))` does not type check: an instance of `List` is not
an instance of `Stack`. It'll then look into the various implicit conversions in scope to find if there's exactly one
that could allow it to transform a `List` into a `Stack`, and `Wrapped` looks like it might work. It just requires an
implicit `StackLike` implementation for `List` to be in scope, which there is: `ListStack`.

This allows us to pass instances of `List` where instances of `Stack` are expected, and for the Scala compiler to do all
the work of turning the former into the later for us.


## A Haskell stack

While I love Scala, and I'm turning into a big fan of type classes, I have to admit that Haskell does it rather better.
We do not need to go through the `StackLike` and implicit conversion mechanism, and can directly define `Stack` as a
type class:

```haskell
class Stack f where
  -- Returns an empty stack.
  empty :: f a

  -- Checks whether the stack is empty.
  isEmpty :: f a -> Bool

  -- Pushes an value onto the stack.
  push :: a -> f a -> f a

  -- Returns the top of the stack.
  top :: f a -> a

  -- Removes the top of the stack.
  pop :: f a -> f a
```

Note that, just as in Scala, `Stack` is a higher-kinded type: `f` is a type constructor, as is evident in the
`empty :: f a` type signature, for example.

Writing an instance of `Stack` for lists is straightforward:
```haskell
instance Stack [] where
  empty   = []
  isEmpty = null
  push    = (:)
  top     = head
  pop     = tail
```

And that's all we need. Provided `Stack` and the list instance of `Stack` are in scope, it's now perfectly legal to
pass a list wherever a stack is required. No implicit convertion, no `Wrapper` object to appease the type system.

This is how we'd write our `safeTop` function in Haskell:
```haskell
safeTop :: (Stack s) => s a -> Maybe a
safeTop s
  | isEmpty s = Nothing
  | otherwise = Just $ top s

-- Just 1
safeTop [1, 2, 3, 4, 5]

-- Nothing
safeTop []
```

The end result is pretty much the same, and `safeTop` is implemented as easily in Scala as it is in Haskell.

It seems possible to get the same result in both languages, but Scala required us to jump through quite a few more hoops
to get there. Do note, however, that even though we had to do more work in the *library* part of our implementation, the
problem is sorted once and for all and users of our `Stack` abstract data structure only ever have to worry about
writting an instance of `StackLike`, which is relatively straightforward.
