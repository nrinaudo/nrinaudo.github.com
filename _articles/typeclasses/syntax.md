---
title: More syntactic sugar
layout: article
series: typeclasses
date:   20200606
---

As we've seen, type classes are a form of syntactic sugar. But they're important enough that Scala has a certain amount of syntax and idioms dedicated to them.

## Context bounds

The first, important bit of syntax that you're likely to encounter is _context bounds_.

The following code is considered too verbose - that implicit declaration really hurts readability, apparently:

```scala
def decodeCsv[A](input: String)
                (implicit da: RowDecoder[A]): List[A] =
  parseCsv(input).
    map(da.decode)
```

In order to fix that, Scala has introduced the `A: RowDecoder` notation, which means _a type parameter `A` and an implicit `RowDecoder[A]`_. It makes `decodeCsv`'s declaration much nicer to read:

```scala
def decodeCsv[A: RowDecoder](input: String): List[A] =
  parseCsv(input).
    map(implicitly[RowDecoder[A]].decode)
```

Its body, on the other hand... since `A: RowDecoder` tells us we have an implicit `RowDecoder[A]` in scope, but doesn't name it, we can refer to it directly and have to use [`implicitly`] to summon it.

This is thought unpleasant enough that a lot of type class based libraries have converged on an instance summoning idiom.

## Instance summoning

It's very common, even expected, nowadays, too see the following `apply` method in a type class' companion object:

```scala
object RowDecoder {
  def from[A](
    f: Row => A
  ) = new RowDecoder[A] {
    override def decode(row: Row) = f(row)
  }

  def apply[A](implicit da: RowDecoder[A]): RowDecoder[A] = da
}
```

It's role is simply to expect an implicit `RowDecoder[A]`... and return it. This allows us to rewrite `decodeCsv` as:

```scala
def decodeCsv[A: RowDecoder](input: String): List[A] =
  parseCsv(input).
    map(RowDecoder[A].decode)
```

I personally really enjoy that syntax - it might be the years of Java I've done, but it looks like a call to a static method, and its intent is fairly obvious.

## Extension methods

It's not good enough for everyone though, and a lot of type class based libraries also offer extension methods (often referred to as syntax or ops).

This is done through implicit conversion:

```scala
implicit class RowDecoderOps(row: Row) {
  def decodeRow[A: RowDecoder]: A =
    RowDecoder[A].decode(row)
}
```

This tells the compiler that, given a `Row` and a type `A` with an implicit `RowDecoder` in scope, it should consider that `Row` has a `decodeRow` method. The details of why this works out are not interesting - it's about to change completely with Scala 3 anyway.

This allows us to rewrite `decodeCsv` as follows:

```scala
def decodeCsv[A: RowDecoder](input: String): List[A] =
  parseCsv(input).
    map(_.decodeRow)
```

Which is undeniably terse, readable and understandable. It *can* be confusing when you look for the declaration of `decodeRow` in the scaladoc and can't find it on `Row`, but that's seen as a tooling problem rather than one with extension methods.

## Scala 3 extension methods

One slightly distasteful thing about extension methods is how you have to declare them in an entirely different type - it's usually considered good practice to declare things that go together, together.

Not a showstopper, certainly, but enough of a problem that Scala 3 decided to address it: in Scala 3, extension methods can be declared directly in the type class itself.

```scala
trait RowDecoder[A]:
  def decode(row: Row): A
  def (row: Row) decodeRow: A = decode(row)
```

That `decodeRow` method achieves exactly the same thing we did through `RowDecoderOps` in Scala 2, and is really quite nice: everything  you need to know to understand `RowDecoder` is declared in `RowDecoder`, with a minimum of ceremony and syntax.

## Key takeaways

The main purpose of this section was to show you some common bits of syntax and idioms that you're likely to encounter when reading type class based code.

But it does show that type classes are important enough that Scala has dedicated syntax for them, plans on having [quite a bit more](https://dotty.epfl.ch/docs/reference/contextual/typeclasses.html), and the community has converged on an idiomatic way of using them.

[`implicitly`]:https://www.scala-lang.org/api/current/scala/Predef$.html#implicitly[T](implicite:T):T
