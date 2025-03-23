---
title  : Encoding the environment in the AST
layout : article
series : pl
date   : 20250203
enabled: false
---

We've taken our typed AST quite far. It's possible to produce instances of it automatically from an untyped AST, and to interpret them in a way that is safer and more convenient than before. But it still has one glaring flaw: as soon as a term involves the environment in some way, it becomes unsafe.

We're now going to address that flaw by figuring out how to encode the environment in `TypedExpr`.

## Type level stacks

If you remember the way we think about the environment, it's pretty much a stack. We have a set of bindings, and whenever a new one is encountered, it's plonked on top of them, and popped off as soon as the binding goes out of scope. The type of the environment, then, is really just a stack.

Not just any old stack though: we want a heterogeneous stack. One in which elements might have different types, and which allows us to keep track of which is which. In Scala, that type is `Tuple`.

## Location in the stack

```scala
enum Elem[X, XS <: NonEmptyTuple]:
  case Here[X, XS <: Tuple]()                              extends Elem[X, X *: XS]
  case There[H, X, XS <: NonEmptyTuple](elem: Elem[X, XS]) extends Elem[X, H *: XS]
```

## Where to go from here?
