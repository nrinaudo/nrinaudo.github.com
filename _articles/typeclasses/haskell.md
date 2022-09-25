---
title: But haskell though...
layout: article
series: typeclasses
date:   20200608
---

## Global instance uniqueness

Haskell reputedly has "proper" type classes, as opposed to the rest of the world, because of the law of global uniqueness: in Haskell, it's impossible to have more than one instance of a given type class for a given type.

Scala gleefully violates that law - it doesn't have global uniqueness, and barely even has *local* uniqueness since there are priority rules in place to resolve some such conflicts.

The argument is two-pronged. First, Haskell type class instances are globally unique, and Haskell invented type classes, so that's obviously the only possible way to have type classes. This side of the argument is not terribly useful - it boils down to _only Haskell has type classes because only Haskell can encode type classes the way Haskell encodes type classes_.

There is, however, a more useful argument to be made: non-unique instances can yield to invariant violations. The usual example is that of a set, implemented as a binary search tree. If you want to merge two sets, you have to be sure that they both use the same notion of ordering or you can find yourself with some very odd results.

In Haskell, that property is guaranteed by global instance uniqueness. You can't have two different instances of the `Ord` type class for a given type, period.

In Scala, you can absolutely find yourself working with different notions of order, and if you're not careful, you will end up with, say, sets containing duplicated elements.

## Not so unique...

The problem with this narrative, of course, is that it's just not true. Or, well, only kind of true, if you ignore real life.

Haskell, as [*specified*](https://www.haskell.org/onlinereport/haskell2010/haskellch4.html#x10-750004.3), explicitly states that global uniqueness must be enforced.

Haskell, as implemented by GHC (its most popular implementation), explicitly violates that rule, which can be demonstrated rather easily.

First, create a `Boolean` type, with two possible values: `T` and `F`.

```haskell
module Lib where

data Boolean = T | F deriving (Eq, Show)
```

Then, in a first module, provide an instance of `Ord Boolean` in which `T` is smaller than `F`.

Note that this is an orphan instance (it's not declared with `Ord` or `Boolean` but in its own module), which is frowned upon but absolutely legal.

```haskell
module Impl1 where

import Data.Set
import Lib

instance Ord Boolean where
  compare T T = EQ
  compare T F = LT
  compare F T = GT
  compare F F = EQ

ins :: Boolean -> Set Boolean -> Set Boolean
ins = insert
```

The `ins` function simply inserts a `Boolean` in an existing set by using our `Ord Boolean` instance.

Write a second module, essentially the same with two key differences:
* `T` is now greater than `F`.
* `ins'` is the same as `ins`, but with a different `Ord Boolean` instance.

```haskell
module Impl2 where

import Data.Set
import Lib

instance Ord Boolean where
  compare T T = EQ
  compare T F = GT
  compare F T = LT
  compare F F = EQ

ins' :: Boolean -> Set Boolean -> Set Boolean
ins' = insert
```

We can now import both modules in a main, and use both `ins` and `ins'` to insert various elements in a set. Note how we insert `T` twice.

```haskell
module Main where

import Data.Set
import Lib
import Impl1
import Impl2

test :: Set Boolean
test = ins' T $ ins T $ ins F $ empty

main :: IO ()
main = print test
```

Shockingly, this all compiles and runs, and yields the following output:

```haskell
-- wtf Haskell I trusted you
fromList [T,F,T]
```

We now have a set with a duplicated value, because GHC doesn't enforce the law of global uniqueness.

## But Scala though...

I wrote this entire, slightly trollish, bit because I got a bit tired of the _Scala doesn't have type classes_ argument. The point is not to compare both languages or to criticise Haskell.

Rather, the point is to allow me to say _I'm happy to consider that Scala doesn't have type classes, provided you agree that neither does GHC_.

Yes, I can be a petty man.
