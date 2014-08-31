---
title: Purely functional sets
tags: scala, haskell
---

I [previously talked](2014-08-11-collections-as-typeclasses.html) about implementing collections as type classes, using
`Stack` as an example. This post shows the basic contract for a purely functional `Set`, with actual implementation
examples to follow.

<!--more-->

## Abstract definition of a Set
A set is a fairly simple abstract data structure: all it does is store unique values. The way these values are stored
is unspecified - in particular, there is no constraint on their order, or even on whether that order is stable. In their
rawest forms, sets do not even need to offer a way to iterate over their values.

Their interest lies in the unicity constraint: a value can never be present more than once in a given set. Or, to put
it in more mathy terms: the value insertion operation is idempotent. That is, there is no difference between calling it
once or many times for the same value.

The core operations that a set must support are:

* `isEmpty`: checks whether the set is empty.
* `insert`: inserts a value in the set.
* `contains`: checks whether a value is contained in the set.

Note that since we're talking about a purely functional set, it must be immutable - that is, calling `insert` on a set
`S` must not modify it, but return a copy of `S` that also contains the new value.



## Scala definition
In a previous post, I've shown how to define [collections as type classes](2014-08-11-collections-as-typeclasses.html).
We'll do the exact same thing here.

First, we need to define the behaviour of set-like data structures:
```scala
import scala.language.higherKinds

trait SetLike[Impl[_]] {
  def isEmpty[A](as: Impl[A])       : Boolean
  def insert[A](a: A, as: Impl[A])  : Impl[A]
  def contains[A](a: A, as: Impl[A]): Boolean
}
```

Note that since sets require their values to be unique, we must be able to compare them. We could have sneaked in an
`Eq` type constraint here, but since it's not strictly necessary, we can let implementations deal with this - especially
since some, such as binary search trees, require something more than simple equality.


That done, we need to define the `Set` trait, for data structures that are actual sets:
```scala
trait Set[A] extends (A => Boolean) {
  def isEmpty       : Boolean
  def insert(a: A)  : Set[A]
  def contains(a: A): Boolean

  // Technically, we can consider a set to be a predicate: it's a function that takes one parameter and returns a
  // boolean value.
  override def apply(a: A): Boolean = contains(a)
}
```

Finally, we must write an implicit conversion from set-like things to actual sets:
```scala
implicit class Wrapped[A, Impl[_]](val set: Impl[A])(implicit setLike: SetLike[Impl]) extends Set[A] {
  override def isEmpty        = setLike.isEmpty(set)
  override def insert(a: A)   = new Wrapped(setLike.insert(a, set))
  override def contains(a: A) = setLike.contains(a, set)
}
```

Note that instead of using a context bound when declaring `Impl`, we've, err, explicitly declared the implicit
parameter. Both are strictly equivalent, and since use `setLike` quite a bit in the implementation, it's more convenient
than having to use `implicitly[SetLike]` everywhere.


## Haskell definition
The definition of a Haskell set is quite a bit simpler than in Scala:

```haskell
import GHC.Prim

class Set s where
  -- Constraints on elements that s can contains.
  -- None by default.
  type SetEntry s a :: Constraint
  type SetEntry s a = ()

  empty    :: SetEntry s a => s a
  isEmpty  :: s a -> Bool
  insert   :: SetEntry s a => s a -> a -> s a
  contains :: s a -> a -> Bool
```

The tricky bit here is the `SetEntry` type constraint: it allows us to let instances of `Set` impose constraints on
the data they contain. Binary search trees, for example, require ordered data, but this constraint is not applicable
to all possible `Set` implementations.

Note that we've also added an `empty` method, used to create empty sets. This is probably not strictly necessary, but
that's how Chris Okasaki implements it - odds are good it's the smart thing to do.

This code requires the `TypeFamilies` and `ConstraintKinds` flags to compile.
