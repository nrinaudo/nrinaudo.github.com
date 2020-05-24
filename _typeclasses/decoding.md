---
title: CSV decoding
layout: article
sequence: 2
---

Now that we know how to _parse_ CSV (go from a `String` to a `Csv`), we need to work on _decoding_ it: turning a `Csv` into a domain type we can more easily work with.

## Decoding to `Int`

The data we're working with is the following, something that clearly wants to be interpreted as a `List[List[Int]]`:

```scala
val input = """1,2,3
              |4,5,6
              |7,8,9"""
```

We can do so naively, by first parsing the input, then mapping into each row, then into each cell, and turning that into an `Int`:

```scala
parseCsv(input).
  map(_.map(_.toInt))
// res0: List[List[Int]] = List(List(1, 2, 3), List(4, 5, 6), List(7, 8, 9))
```

This works, but does not yet feel like a finished solution. We don't want to have to remember how CSV data is structured internally, it'd be much nicer if we could abstract over that.

A good strategy for this kind of situation is to put our code inside of a function, parameterise everything we can, and see whether a pattern emerges. This is what we'll do here:

```scala
def decodeCsv(
  input: String
): List[List[Int]] =
  parseCsv(input).
    map(_.map(_.toInt))
```

That's a good start, we've turned the input into a parameter. But there's nothing stopping us from doing the same thing to our decoding function:

```scala
def decodeCsv(
  input     : String,
  decodeCell: Cell => Int
): List[List[Int]] =
  parseCsv(input).
    map(_.map(decodeCell))
```

We're getting somewhere - I don't think there's anything left at the term level we can turn into a parameter.

But if we pay attention to the body of `decodeCsv`, we never actually use the fact that we're decoding to an `Int`. We're decoding to *something*, certainly, but we really don't need to know what. That bit is delegated entirely to `decodeCell`.

## Generic decoding

Since we don't need to know what we're decoding to, we can turn that into a type parameter:

```scala
def decodeCsv[A](
  input     : String,
  decodeCell: Cell => A
): List[List[A]] =
  parseCsv(input).
    map(_.map(decodeCell))
```

And the result is really quite nice: provided we have a cell decoding function, we can decode our input into a list of list of whatever type we want.

`Int`s, for example:

```scala
decodeCsv(input, _.toInt)
// res1: List[List[Int]] = List(List(1, 2, 3), List(4, 5, 6), List(7, 8, 9))
```

But also `Float`s:

```scala
decodeCsv(input, _.toFloat)
// res2: List[List[Float]] = List(List(1.0, 2.0, 3.0), List(4.0, 5.0, 6.0), List(7.0, 8.0, 9.0))
```

We've already done something rather convenient: abstracted over the structure of CSV data. Consumers of our library don't really need to think about how CSV is stored in memory, and can focus on what output type they want.

Well. That's only partly true. They also have to know how to turn a cell into that type. Wouldn't it be nice if we could provide default implementations for reasonable types and only require consumers to specify their desired output type, leaving the compiler to work the rest out?

Fortunately, Scala has a feature that allows us to do just that: implicits.

## Implicit resolution

I realise implicit resolution is something that can seem confusing or daunting for beginners, but it can be explained in an acceptably straightforward manner.

> When a function has a parameter of type `A`, and that parameter is marked as `implicit`, and there exists a value of type `A` marked as `implicit` in scope, then the compiler will use that value if the parameter is unspecified.

Let's take this step by step.

In the following code, `printInt` takes an implicit `Int`:

```scala
implicit val defaultInt: Int = 2

def printInt(implicit i: Int): Unit = println(i)
```

We can write:

```scala
printInt
```

This will cause the compiler to look for an implicit `Int` and find `defaultInt` - allowing it to assume we meant to pass `defaultInt` all along and generate the following code:

```scala
printInt(defaultInt)
// 2
```

## Decoding with implicits

This means that if we mark our decoding function as implicit, and provide implicit values for the common cases, we'll be able to simplify our call-site API quite a bit:

```scala
def decodeCsv[A]
  (input: String)
  (implicit decodeCell: Cell => A)
 : List[List[A]] =
  parseCsv(input).
    map(_.map(decodeCell))
```

Here's a reasonable default implementation for `Int` decoding:

```scala
implicit val strToInt: Cell => Int =
  Integer.parseInt
```

And now, asking `decodeCsv` to interpret cells as `Int`s works exactly as desired:

```scala
decodeCsv[Int](input)
// res3: List[List[Int]] = List(List(1, 2, 3), List(4, 5, 6), List(7, 8, 9))
```

Which is strictly equivalent to the following code:

```scala
decodeCsv[Int](input)(strToInt)
// res4: List[List[Int]] = List(List(1, 2, 3), List(4, 5, 6), List(7, 8, 9))
```

Of course, if you're at least a little bit familiar with implicit resolution, you might be aware that we've done slightly more than we intended...

## The dangers of implicits

The implicit resolution mechanism has the following wrinkle:

> When the compiler finds a type `A` where it expects a type `B`, but there exists an implicit `A => B` in scope, it will be applied silently.

In the following code, `add1` takes an `Int`. There also happens to be an implicit `String => Int` in scope:

```scala
implicit val strToInt: String => Int =
  Integer.parseInt

def add1(i: Int): Int = i + 1
```

Which means that we can call `add1` with a `String`:

```scala
add1("123")
```

It's strictly equivalent to explicitly applying our `strToInt` function:

```scala
add1(strToInt("123"))
// res6: Int = 124
```

Whether or not this is a good design choice is up for debate - and is, indeed, hotly debated - but is a bit irrelevant here. We didn't mean to provide an implicit conversion from `Cell` to `Int`, yet we have. It'd be better if we avoided that unfortunate side effect.

Since the entire implicit conversion mechanism is triggered by our decoding function being of type `Function`, we can sidestep the entire thing by using a different type.


## Decoder type

Meet `CellDecoder`, which is basically a function but, importantly, not of *type* `Function`:

```scala
trait CellDecoder[A] {
  def decode(cell: Cell): A
}
```

If we have an instance of `CellDecoder` for a given `A`, we know how to decode a cell into an `A`.

We'll be creating a fair amount of these, so we'll need some creation helpers to reduce boilerplate:

```scala
object CellDecoder {
  def from[A](
    f: Cell => A
  ) = new CellDecoder[A] {
    override def decode(cell: Cell) = f(cell)
  }
}
```

Armed with these tools, we can now declare a bunch of implicit decoders:

```scala
implicit val intCellDecoder: CellDecoder[Int] =
  CellDecoder.from(_.toInt)

implicit val floatCellDecoder: CellDecoder[Float] =
  CellDecoder.from(_.toFloat)

implicit val stringCellDecoder: CellDecoder[String] =
  CellDecoder.from(identity)

implicit val booleanCellDecoder: CellDecoder[Boolean] =
  CellDecoder.from(_.toBoolean)
```

## Implicit decoder

`decodeCsv` needs to be updated to use an implicit `CellDecoder[A]` rather than a `Cell => A`:

```scala
def decodeCsv[A]
  (input: String)
  (implicit da: CellDecoder[A])
 : List[List[A]] =
  parseCsv(input).
    map(_.map(da.decode))
```

This allows us to write:

```scala
decodeCsv[Int](input)
```

The compiler will realise that it needs an implicit `CellDecoder[Int]`, locate one, and generate the following code:

```scala
decodeCsv[Int](input)(intCellDecoder)
// res7: List[List[Int]] = List(List(1, 2, 3), List(4, 5, 6), List(7, 8, 9))
```

This will of course work for any type we've provided an implicit instance of `CellDecoder` for. `Float`, for example:

```scala
decodeCsv[Float](input)
```

This desugars to the following code:

```scala
decodeCsv[Float](input)(floatCellDecoder)
// res8: List[List[Float]] = List(List(1.0, 2.0, 3.0), List(4.0, 5.0, 6.0), List(7.0, 8.0, 9.0))
```

## Key takeaways

We've now spent a fair amount of time making `decodeCsv` polymorphic - that is, a common interface to many different types.

We've done so by using, first, parametric polymorphism: `CellDecoder` takes a type parameter, `decodeCsv` does as well, and if they match, you can use the former with the latter.

We've also used implicit resolution to automate some code generation.

This pattern is known as a type class. There's a bit more to it than that - properties that we can derive from what we've just built, and we will, a bit later.

But first, I'd like to take a little detour: type classes are considered to be a "function programming tool". They were invented for Haskell, and are mostly used in languages that bill themselves as functional. Could we not achieve the same result with an OOP language?
