---
title: Purely functional heaps
tags: scala, haskell
---

Heaps are another simple data structure that can easily be implemented as type classes. Just as with sets, this first
post will explain what a heap is and how to define it, while later ones will show actual implementations.

<!--more-->

## Abstract definition of a Heap
There seems to be some confusion as to what exactly constitutes a heap.

According to some sources (such as [Wikipedia](http://en.wikipedia.org/wiki/Heap_(data_structure))), a heap is tree-like
structure that satisfies the _heap property_, which states that the value at each node is not greater than the value of
its descendants.

Others, such as Chris Okasaki, define a heap as synonymous to a priority queue, an abstract data structure that provides
primitives for acccess to and removal of its element with the smallest value (or lowest priority).

Within the context of this post, we'll use a somewhat custom-made definition that, while possibly not correct, seems
like an acceptable compromise.

A heap, then, is an abstract data type that supports the following operations:

* `isEmpty`: checks whether the heap is empty.
* `insert`: inserts an element in the heap.
* `findMin`: finds the minimum value in the heap.
* `deleteMin`: returns a new heap that does not contain the previous one's minimum element.

Within this context, the Wikipedia definition describes _heap-ordered trees_, a family of concrete implementations of
the heap abstrat data type (such as splay heap, leftist heap, binomial heap...).

Note that, technically, this is the definition of a min-heap, not a generic heap. Since we'll be working with
customisable orderings, however, this isn't much an issue: turning a min-heap into a max-heap is as simple as inverting
the ordering.


## Scala definition
As usual, we start with the behaviour of heap-like data structures:
```scala
import scala.language.higherKinds

trait HeapLike[Impl[_]] {
  def isEmpty[A](a: Impl[A])      : Boolean
  def insert[A](a: A, as: Impl[A]): Impl[A]
  def findMin[A](a: Impl[A])      : Option[A]
  def deleteMin[A](a: Impl[A])    : Impl[A]
}
```

We could technically require an `Ordering` instance of `A` for all these methods, but it's not strictly required nor
really useful: `HeapLike` does not contain any code that actually needs its elements to be ordered.

That done, we can define the `Heap` trait for data structures that are actual heaps:
```scala
trait Heap[A] {
  def isEmpty     : Boolean
  def insert(a: A): Heap[A]
  def findMin     : Option[A]
  def deleteMin() : Heap[A]
}
```
And finally, the implicit conversion from `HeapLike` to `Heap`:
```scala
implicit class Wrapped[A, Impl[_]](val heap: Impl[A])(implicit heapLike: HeapLike[Impl]) extends Heap[A] {
  override def isEmpty      = heapLike.isEmpty(heap)
  override def insert(a: A) = new Wrapped(heapLike.insert(a, heap))
  override def findMin      = heapLike.findMin(heap)
  override def deleteMin()  = new Wrapped(heapLike.deleteMin(heap))
}
```


## Haskell definition
As often seems to be the case, the Haskell definition is quite a bit shorter:
```haskell
import GHC.Prim

class Heap h where
  -- Constraint that elements of h must respect.
  type HeapEntry h a :: Constraint
  type HeapEntry h a = ()

  empty     :: HeapEntry h a => h a
  isEmpty   :: h a -> Bool
  findMin   :: h a -> Maybe a
  deleteMin :: h a -> h a
  insert    :: HeapEntry h a => h a -> a -> h a
```

The only tricky part is our dynamic constraint on the values contained by the heap, which allows implementations
to set their own custom constraints - `Ord`, say, or `Numeric`.

Note where this constraint is actually applied:

* `insert`, since it receives an instance of `a`.
* `empty`, to prevent instances of `Heap` from being created for types not supported by the underlying implementation.

Finally, we've added a the `empty` method to conform with Purely Functional Data Structure's implementation.
