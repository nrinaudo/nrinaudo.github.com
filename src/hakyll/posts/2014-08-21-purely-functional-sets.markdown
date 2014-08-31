---
title: Purely functional sets
tags: scala, haskell
---

I [previously talked](2014-08-11-collections-as-typeclasses.html) about implementing collections as type classes, and
gave a simple example with `Stack`. This new post is very similar, but with sets and binary search trees.

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



### Scala definition
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


### Haskell definition
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


## Binary Search Trees as Sets

The simplest set implementation I know of is the binary search tree: a binary tree such that, for any given node `n`,
all the values to its left are smaller than `n` and all the values to its right are larger than `n`.


![Fig. 1: Simple binary search tree](/images/graphs/binarysearchtrees/simple.svg)

You can see in figure 1 that the nodes to the left of `8` are `5`, `6` and `3`, which are all smaller than `8`.
Similarly, the nodes to its right are `10`, `9` and `12`, which are all larger than `8`.

In the rest of this post, I'll use the term _leaf_ to mean a leaf in the
[extended representation](http://mathworld.wolfram.com/ExtendedBinaryTree.html) of the tree: a leaf does not contain a
value, but represents the end of a branch.

### "isEmpty" algorithm

Checking whether a binary search tree is empty is trivial: if the root is a leaf, then it's empty. Otherwise, it's not.


### "contains" algorithm

The algorithm for the `contains` operation is a straightforward recursion starting at the root of the tree:

* if the current node is a leaf, return `false`.
* otherwise, if the desired value is smaller than the current node's, look in the left sub-tree.
* otherwise, if the desired value is larger than the current node's, look in the right sub-tree.
* otherwise, return `true`.

Let's take a few examples and run the algorithm.

![Fig. 2: Looking for an existing value](/images/graphs/binarysearchtrees/contains9.svg)

Trying to find `9` yields the following steps:

* `9` is larger than `8`, explore the right sub-tree
* `9` is smaller than `10`, explore the left sub-tree
* we've found `9`.


![Fig. 3: Looking for a non-existing value](/images/graphs/binarysearchtrees/contains4.svg)

Trying to find `4` yields the following steps:

* `4` is smaller than `8`, explore the left sub-tree
* `4` is smaller than `5`, explore the left sub-tree
* `4` is larger than `3`, explore the right sub-tree
* we're at a leaf, the set does not contain `4`.


### "insert" algorithm
Modification of purely functional data structures can be tricky: it requires cloning the source structure and updating
it just enough to reflect the desired modifications, while at the same time re-using as much of it as possible.

Note that re-using parts of purely functional data structures is not unsafe: since they're immutable by definition,
it's not possible for modifications in one to be reflected in another.

Insertion in binary search trees is fairly straightforward: recursively look for the node in which the desired value
should be inserted, cloning all explored nodes along the way and re-using the sub-tree that is _not_ impacted by
the modification.

The only two special cases are leafs (in which case we found where to insert the value) or nodes that already contain
the value (in which case we do not in fact need to insert it and can abort).

This is more easily explained with a graph (blue nodes are created during insertion, black ones are the original tree):

![Fig. 4: Inserting a value](/images/graphs/binarysearchtrees/insert4.svg)

Figure 4 shows the result of inserting `4` in our example tree.

In our first recusive step, we find that `4` is smaller than `8`: we need to clone the current node and insert `4` in
its left sub-tree.

`4` is also smaller than `5`: we need to clone it and insert `4` in its left sub-tree.

`4` is larger than `3`: we need to clone it and insert `4` in its right sub-tree.

Finally, we've found a leaf and return a new node whose value is `4`.

The result is a new tree that re-uses as much of the source one as possible: `10` and all its descendants, as well as
`6` and all its descendants, are shared by the original and output trees.


## Scala implementation of a binary search tree

### BinarySearchTree
We'll implement binary search trees as an algebraic data type. In Scala, this means starting with a sealed trait to
define the common operations:

```scala
sealed trait BinarySearchTree[A] {
  def isEmpty       : Boolean
  def add(a: A)     : BinarySearchTree[A]
  def contains(a: A): Boolean
}
```

Note that both our `add` and `contains` algorithms require `A` to be ordered. Since we can only work with ordered data,
we'd like to state that constraint explicitely in the trait's type signature:

```scala
sealed trait BinarySearchTree[A: Ordering] {...}
```

This is, unfortunately, impossible: context bounds are compiled as implicit parameters, which means our previous code
would compile to a trait with a constructor expecting one implicit parameter:
```scala
sealed trait BinarySearchTree[A](implicit ord: Ordering[A]) {...}
```

Since Scala trait constructors cannot have parameters, the above code cannot compile.

We could also mark `add` and `contains` with an `Ordering` context bound, but that would come back and haunt us later
when we try to write a `SetLike` implementation. Take the signature of `SetLike`'s `insert` method, for example:

```scala
def insert[A](a: A, as: Impl[A]): Impl[A]
```

It does not expect an `Ordering[A]` as a parameter, either implicitly or explicitly - we would not have an ordering
to pass to `BinarySearchTree`'s `add` method and no way to get one.

### Leaf

Having written our algebraic data type's contract, we must implement its alternatives. Let's start with the simple one,
`Leaf`:

```scala
case class Leaf[A: Ordering]() extends BinarySearchTree[A] {
  // A leaf is always empty.
  override def isEmpty = true

  // A leaf never contains anything.
  override def contains(a: A) = false

  // Inserting a value in a leaf is always done by creating a new tree.
  override def add(a: A) = Node(a, this, this)
}
```

There are a few things to note in this implementation.

The first one is how neatly this implements the bottom cases of the recursive algorithms we defined for `insert` and
`contains` - a leaf never contains anything, and inserting a new value in a leaf is always done by creating a new node.

Another interesting point is that `Leaf` has a type constraint on `A`: there must be an implicit instance of
`Ordering[A]` in scope. The reason for this might not be immediately obvious, but it's required by `add`'s
implementation: we'll see later that `Node`'s constructor require an implicit `Ordering[A]`.

Finally, `Leaf` is a bit of a strange beast: it's a case class with no field, but not a case object. This is
sub-optimal, as it means that we'll have a new instance of `Leaf` for each leaf in our trees rather than a single
instance shared across all trees.

The reason for this implementation is that I'm more interested in the data structures themselves than Scala plumbing at
this point, and in order for `Leaf` to be a case object, I'd need `BinarySearchTree` to be covariant and `Leaf` to
be a `BinarySearchTree[Nothing]`. Adding covariance to the juggling I'm already doing with the type system will only
add confusion - I'm sure it's possible, and I'd absolutely do it if I thought my collection implementations had the
slightest chance of being used by anyone, but that's really not the purpose of this post.


### Node
We can finally implement the meat of our `BinarySearchTree`: `Node`.

```scala
case class Node[A](value: A, left: BinarySearchTree[A], right: BinarySearchTree[A])(implicit ord: Ordering[A])
  extends BinarySearchTree[A] {
  // A node is never empty.
  override def isEmpty = false

  override def add(a: A) =
    if(ord.lt(a, value))      copy(left  = left + a)
    else if(ord.gt(a, value)) copy(right = right + a)
    else                      this

  override def contains(a: A) =
    if(ord.lt(a, value))      left.contains(a)
    else if(ord.gt(a, value)) right.contains(a)
    else                      true
}
```

The first thing to point out in this implementation is that it can be optimised: both `add` and `contains` are
recursive, but neither of them is tail-recursive. That's fine for demonstration purposes, and makes the code quite a
bit more legible, but it'd probably be a desirable optimsation if `Node` were to be used in a production a
environment.

Note how clearly case classes allow us to express our cloning algorithm: the `copy` method makes it obvious that the
only difference between the current node and the one that is returned is the sub-tree in which we drill down.

On the other hand, I'm a bit annoyed that I couldn't find a sane way to use operators such as `<` and `>` rather than
the more verbose `ord.lt` and `ord.gt`. It feels like an obvious way to make the code clearer, but I just didn't manage
to get it to work.


### Implicit conversion to `Set`
In order for our `BinarySearchTree` to be usable as a `Set`, we still need to write the corresponding, trivial `SetLike`
implementation:

```scala
implicit object AsSet extends SetLike[BinarySearchTree] {
  override def isEmpty[A](as: BinarySearchTree[A])        = as.isEmpty
  override def insert[A](a: A, as: BinarySearchTree[A])   = as + a
  override def contains[A](a: A, as: BinarySearchTree[A]) = as.contains(a)
}
```

## Haskell implementation of a binary search tree
### BinarySearchTree
As with our Scala implementation, we'll define binary search trees as an algebraic data type:

```haskell
data BinarySearchTree a = Ord a => Node a (BinarySearchTree a) (BinarySearchTree a)
                        | Ord a => Leaf

```

Note that we'll need the `ExistentialQuantification` to be able to declare type constraints at the data constructor
level. This allows us to ensure that only values that can be ordered are added in our binary search trees, the same way
we did for the Scala implementation.



### Set implementation
Now that we have our data structure, we need to turn it into a valid `Set` implementation:

```haskell
instance Set BinarySearchTree where
  type SetEntry BinarySearchTree a = Ord a

  empty = Leaf

  isEmpty Leaf = True
  isEmpty _    = False

  contains Leaf _ = False
  contains (Node v l r) a
    | a < v     = contains l a
    | a > v     = contains r a
    | otherwise = True

  insert Leaf a = Node a Leaf Leaf
  insert s@(Node v l r) a
    | a < v = Node v (insert l a) r
    | a > v = Node v l (insert r a)
    | otherwise = s
```

In order for this to compile, we'll need a mess of compiler flags: `TypeFamilies`, `MultiParamTypeClasses` and
`FlexibleInstances`.

There really isn't anything special to say about this code, aside from noting how clear it is. Provided you can read
Haskell, this could almost be the specifications for our binary search tree algorithms.
