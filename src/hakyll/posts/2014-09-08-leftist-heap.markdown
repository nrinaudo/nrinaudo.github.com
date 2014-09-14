---
title: Leftist Heaps
tags: purely functional data structures, scala, haskell
---

Leftist heaps are relatively easy to implement as purely functional data structures, and are a good default
implementation for our [heap](/posts/2014-08-31-purely-functional-heaps.html) typeclass.

<!--more-->

## Overview
Structurally, a leftist heap is a _min tree_ where each node is marked with a _rank_ value.

We'll get into precisely what these mean and the interesting properties they bring, but first, let's try to develop
an intuition for what a leftist heap is.

A leftist heap, then, is a purposefully unbalanced binary tree (leaning to the left, hence the name) that keeps its
smallest value at the top and has an inexpensive merge operation. It looks something like this:

![Fig. 1: A leftist heap](/images/leftist-heaps/leftist-heap.svg)

As you can see, there is no apparent order to these values - there is no easy logic such as smaller values going to left
as in binary search trees, for example. We can see, however, that the smallest value of each subtree is always in its
root (that's essentially what being a min tree means).

The rest appears to be chaos - `8`, for example, is found at different depths of the tree, with different parents. The
`rank` function is what drives this chaos.

And that's it, really. Merging two leftist heaps is the most complex operation, and it can be seen as a merge-sort
of the right spline of both trees (more on that later). Once you know how to merge two trees, you're essentially done,
as most other primitives can be derived from that.

Let's now discuss what a _min tree_ is, and how to pick a _rank_ function, in more details.


### Min tree
A _min tree_ is one such that:
$$\forall n, value(n_{left}) \geq value(n) \land value(n_{right}) \geq value(n)$$

Or, in plain english: the value of each node is no greater than that of its descendants.

For example:

![Fig. 2: Min tree](/images/leftist-heaps/min-tree.svg)

This property is interesting for heaps in that it makes it trivial to find the minimum value: it's always at the root
of the tree. This affords us a guaranteed `O(1)` `findMin` operation.

We often refer to such as trees as _heap-ordered_.



### Rank function
The _rank_ function must obey the following laws:

$\forall n:leaf(n), rank(n) = 0$
$$\forall n:\neg leaf(n), rank(n_{left}) \geq rank(n_{right})$$

In plain english: the rank of any left child is no smaller than that its right sibling. This is also known as the
_leftist property_.

Different `rank` functions define different types of leftist heaps, but do not change the underlying algorithms.


### Height-biased leftist heap
A common definition of `rank` is the length of the shortest path from a node to a leaf, and defined as:
$$\forall n:\neg leaf(n),rank(n) = min(rank(n_{left}), rank(n_{right})) + 1$$

This creates a height-biased leftist heap. The following graph shows the `rank` value for all nodes:

![Fig. 3: Height-biased leftist heap](/images/leftist-heaps/height-biased.svg)

All leafs have a rank of 0. For all other nodes, notice that the rank value is exactly equal to the length of the right
spline of the subtree defined by a node. The root of the whole tree, for example, has a value of `2`, which is the
number of nodes from it (included) to the closest leaf.


### Weight-biased leftist heap
Another definition of `rank` is the number of nodes contained in the subtree with a given node as a root, and defined
as:
$$\forall n:\neg leaf(n),rank(n) = rank(n_{left}) + rank(n_{right}) + 1$$

This creates a weight-biased leftist heap. The following graph shows the `rank` value for all nodes:

![Fig. 4: Weight-biased leftist heap](/images/leftist-heaps/weight-biased.svg)

All leafs have a rank of 0, as per definition of `rank`. All other nodes have a rank equal to the number of non-leaf
nodes below them (included). For example, the root has a rank of `9` because the tree contains exactly `9` non-leaf
(white) nodes.



## Key operation: merging

First, a quick point of vocabulary. Depending on the author, this operation is either referred to as _merging_ or
_melding_. These two terms are not, in fact, interchangeable:

* _melding_ is a destructive operation. Once two heaps have been melded, both are lost and only the result remains.
* _merging_ produces a new heap without modifying the two original ones.

In our case, since we're dealing with purely functional data structures, we need to merge trees, not meld them.

Merging leftist heaps looks more complicated than it really is. We'll take a step-by-step example soon, but the general
principle is that merging two leftist heaps is done by merging their right splines as you would two sorted lists, and
flipping left and right descendants as required by the `rank` function.

Keeping that in mind, let's take a concrete example.

![Step 1](/images/leftist-heaps/merging-step1.svg)

Let's consider both heaps' right splines as sorted list. The first one is `[4, 8]`, the second one `[3, 6]`.

Merging these two lists is done by taking their respective heads, comparing them and taking the smallest one as the
head of our new list.

In leftist heaps terms, this means that we'll create a new tree whose root is `3` (the smallest of the two roots) and
whose descendants are:

* `3`'s left descendant.
* the result of merging `3`'s right descendant with the tree whose root is `4`.

We can't yet decide which one goes on the left and which one on the right: this requires comparing both trees' ranks,
and one of them isn't known yet.

Note that we said _create a new tree_. This is important, and is the key difference between merging and melding: rather
than modifying `3`'s descendants, we create an entirely new tree and reuse as much of the structure of the previous
one's as we can (in this case, the left descendant, which we know won't be modified).

![Step 2](/images/leftist-heaps/merging-step2.svg)

We're now merging the trees whose roots (`4` and `6`) are marked in the graph. Since `4` is smaller than `6`, the result
is a new tree with a value of `4` and whose descendants are:

* `4`'s left descendant.
* the result of merging `4`'s right descendant with the tree whose root is `6`.

![Step 3](/images/leftist-heaps/merging-step3.svg)

We're applying the same algorithm again, merging the `6` and `8` trees. This results in a single tree with the smallest
value at its root.

Since neither `6` nor `8` have descendants, we've reached the bottom case of our recursion and can start "climbing" back
up. Since all trees are now known, we also know their ranks and can start flipping descendants as necessary.

![Step 4](/images/leftist-heaps/merging-step4.svg)

The tree whose root is `4` is now complete and obeys the leftist property (whether we're working with weight- or
height-biased leftist heaps).

`4`'s rank is now known, and we can decide whether it should be the left or right descendant of `3`.

![Step 5](/images/leftist-heaps/merging-step5.svg)

Since `4`'s rank is higher (whether we're working with weight- or height-biased leftist heaps), it becomes `3`'s
left descendant, and `5` its right one.

At this point, we've succesfully merged both leftist heaps into a new one where all invariants are respected:

* the smallest value is always at the root (heap order).
* the highest rank values are always on the left (leftist property).



## Heap operations
As we've seen [previously](/posts/2014-08-31-purely-functional-heaps.html), the key heap operations are:

* `isEmpty`
* `findMin`
* `insert`
* `deleteMin`

Now that we understand the properties of a leftist heap and how to merge them, these operations are fairly simple to
implement.


### isEmpty
Just as with [binary search trees](/posts/2014-08-31-binary-search-tree-as-set.html), this operation is trivial: leafs
are empty, all other nodes aren't.

Note that, in this post as before, _leaf_ is used in the extended representation sense and represents the end of branch.


### findMin
Since leftist heaps are _heap-ordered_, finding the minimum value is simply achieved through returning the value found
at the tree's root.


### insert
Value insertion can easily be implemented in terms of `merge`: adding a value to a leftist heap is done by merging the
heap with another that has a single node with the desired value.


### deleteMin
Since leftist heaps are _heap-ordered_, deleting the minimum value is done by removing the tree's root, after which we
can simply merge its left and right descendants.


## Scala implementation
### LeftistHeap
We'll implement leftist heaps as an algebraic data type. As usual, we start with the root trait:

```scala
sealed trait LeftistHeap[A] {
  def rank                     : Int
  def isEmpty                  : Boolean
  def merge(as: LeftistHeap[A]): LeftistHeap[A]
  def insert(a: A)             : LeftistHeap[A]
  def deleteMin()              : LeftistHeap[A]
  def findMin                  : Option[A]

  def +(a: A): LeftistHeap[A] = insert(a)
  def nonEmpty = !isEmpty
}
```

As we did with [binary search trees](/posts/2014-08-31-binary-search-tree-as-set.html), `A` is not marked as requiring
an implicit `Ordering` in scope. Concrete implementations will deal with that.



### Leaf
`Leaf` represents the end of a branch, *after* the last value. As noted before, this is not the standard definition of
a leaf, but the one used in the extended representation of a tree.

Leafs are trivial to implement:

```scala
case class Leaf[A: Ordering]() extends LeftistHeap[A] {
  override val rank                      = 0
  override val isEmpty                   = true
  override def merge(as: LeftistHeap[A]) = as
  override def insert(a: A)              = Node(a, 1, this, this)
  override def deleteMin()               = throw new UnsupportedOperationException("Leaf.deleteMin")
  override val findMin                   = None
}
```


### Node
Nodes are slightly more complicated to implement than `Leaf`:

```scala
case class Node[A](value: A, rank: Int, left: LeftistHeap[A], right: LeftistHeap[A])(implicit ord: Ordering[A])
  extends LeftistHeap[A] {
  private def sortRank(a: A, d1: LeftistHeap[A], d2: LeftistHeap[A]): LeftistHeap[A] =
    if(d1.rank > d2.rank) Node(a, d1.rank + 1, d1, d2)
    else                  Node(a, d2.rank + 1, d2, d1)

  override val isEmpty = false

  override def merge(as: LeftistHeap[A]) = as match {
    case Leaf()                         => this
    case Node(value2, _, left2, right2) =>
      if(ord.lt(value, value2)) sortRank(value,  left,  right.merge(as))
      else                      sortRank(value2, left2, this.merge(right2))
  }

  override def insert(a: A) = merge(Node(a, 1, Leaf(), Leaf()))
  override def deleteMin() = left.merge(right)
  override def findMin = Some(value)
  }
```

A lot of this is a direct translation of the algorithms we wrote before and is not really worth discussing -
for example, the `deleteMin` implementation is beautifully simple and requires no explanation.

The tricky bit is the `merge` method and is interesting to look into as it explicitly states something that I struggled
with explaining before: how to choose which sub-tree goes to the left and which goes to the right when merging along
the right spline.

Attentive readers will also notice that we've hard-coded the `rank` function in this implementation: we're using a
height-biased leftist heap.


### Heap instance
Now that we have a working leftist heap, we can write the corresponding `HeapLike` instance. This proves particularly
unchallenging, since a leftist heap already is a heap:

```scala
implicit object AsHeap extends HeapLike[LeftistHeap] {
  override def isEmpty[A](a: LeftistHeap[A])         = a.isEmpty
  def merge[A](a: LeftistHeap[A], b: LeftistHeap[A]) = a.merge(b)
  override def insert[A](a: A, as: LeftistHeap[A])   = as.insert(a)
  override def findMin[A](a: LeftistHeap[A])         = a.findMin
  override def deleteMin[A](a: LeftistHeap[A])       = a.deleteMin()
}
```


## Haskell implementation
### LeftistHeap
As with Scala, we start by declaring a `LeftistHeap` algebraic data type, as well as the various basic functions we
need for interacting with it:
```haskell
data LeftistHeap a = Ord a => Node a Int (LeftistHeap a) (LeftistHeap a)
                   | Ord a => Leaf

-- Creates a leftist tree containing the specified element.
singleton :: Ord a => a -> LeftistHeap a
singleton a = Node a 1 Leaf Leaf

-- Extracts the rank of a leftist tree
rank :: LeftistHeap a -> Int
rank Leaf           = 0
rank (Node _ r _ _) = r

-- Merges two leftist trees together.
merge :: (Ord a) => LeftistHeap a -> LeftistHeap a -> LeftistHeap a
merge Leaf t    = t
merge t    Leaf = t
merge t1@(Node a1 _ l1 r1) t2@(Node a2 _ l2 r2)
  | a1 < a2   = sortRank a1 l1 (merge r1 t2)
  | otherwise = sortRank a2 (merge t1 l2) r2

-- Creates a leftist tree with the specified value and left and right children.
sortRank :: Ord a => a -> LeftistHeap a -> LeftistHeap a -> LeftistHeap a
sortRank a l r = if   rank l > rank r
            then Node a (rank l + 1) l r
            else Node a (rank r + 1) r l
```

Note how, aside from pure syntax, the largest difference between this and the Scala implementation is how code is
"grouped" together: Haskell groups it by functionality, and Scala by type.

To be more explicit: in Haskell, one defines the function and all its possible implementation at declaration time. For
example, we define `rank`'s behaviour for both leafs and nodes at the same point in our code. In Scala, we have an
implementation for leafs and one for nodes.


### Heap instance
Having written a leftist heap with the bare minimum functionalities, we can now write a `Heap` instance for it:
```haskell
instance Heap LeftistHeap where
  type HeapEntry LeftistHeap a = Ord a

  empty = Leaf

  isEmpty Leaf = True
  isEmpty _    = False

  insert p a = merge p (singleton a)

  findMin Leaf           = Nothing
  findMin (Node a _ _ _) = Just a

  deleteMin Leaf           = error "Leaf.deleteMin"
  deleteMin (Node _ _ l r) = merge l r
```
