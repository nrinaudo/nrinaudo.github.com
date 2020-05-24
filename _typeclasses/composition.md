---
title: Implicit composition
layout: article
sequence: 4
---

We've learned that type classes could be considered simple syntactic sugar over explicit dictionary passing. And while this is true, it's important to realise quite how *nice* that syntactic sugar is.

## Heterogenous types

Consider the following CSV data:

```csv
1997,Ford
2000,Mercury
```

The first cell of each row is an `Int`, the second one a `String` - we'd probably like the whole thing decoded as a `List[(Int, String)]`.

This is unfortunately not something we can do yet: our current mechanism is cell-based, not row-based. But we can try applying the technique we used for cells to rows.

## `RowDecoder` type class

`RowDecoder` is to `Row` what `CellDecoder` was to `Cell`: a function from `Row` to `A` in all but type.

```scala
trait RowDecoder[A] {
  def decode(row: Row): A
}
```

As before, we'll be writing a lot of them and could use some creation helpers:

```scala
object RowDecoder {
  def from[A](
    f: Row => A
  ) = new RowDecoder[A] {
    override def decode(row: Row) = f(row)
  }
}
```

`decodeCsv` currently works with cells, we need to update it to deal with rows. This is fairly straightforward: instead of mapping into each row, then cell and applying a `CellDecoder`, we'll simply map into each row and apply a `RowDecoder`.

```scala
def decodeCsv[A](input: String)
                (implicit da: RowDecoder[A]): List[A] =
  parseCsv(input).
    map(da.decode)
```

All we need now is a `RowDecoder` of the appropriate type and we should be sorted.

## `(Int, String)` decoder

Let's start with an obvious implementation:

```scala
implicit val tupleDecoder = RowDecoder.from[(Int, String)] {
  row => (
    row(0).toInt,
    row(1)
  )
}
```

This ought to work, but is clearly unsatisfactory. We've just spent a fair amount of time designing a way of decoding cells to arbitrary types, but we're back to doing it manually.

We can improve on that by calling our existing decoders explicitly:

```scala
implicit val tupleDecoder = RowDecoder.from[(Int, String)] {
  row => (
    intCellDecoder.decode(row(0)),
    stringCellDecoder.decode(row(1))
  )
}
```

And, yes, this is an improvement, but it's still be far better if we could pass `intCellDecoder` and `stringCellDecoder` as parameters. Unfortunately, `tupleDecoder` is a `val`, and these famously don't take parameters.

What we'd like to do is to turn it into a `def`, but we're not yet sure how that works with implicit resolution.

## Implicit resolution, revisited

> When the compiler looks for an implicit value of type `A` and finds an implicit function that returns an `A` that it can call, it will use its return value.

This is almost clear, although that _that it can call_ bit seems a little mysterious. It means that one of the following must be true:
* the function has no parameter.
* all of the function's parameters are implicit, and they are satisfied (read: have a corresponding implicit value in scope).

To illustrate this, take the following code:

```scala
implicit val defaultDouble: Double = 3.0

implicit def getFloat(implicit d: Double): Float = d.toFloat

def printFloat(implicit f: Float): Unit = println(f)
```

The key points are that `printFloat` takes an implicit `Float`, and `getFloat` is an implicit function that returns one provided there's an implicit `Double` in scope.


Now, let's try to call `printFloat` without arguments:

```scala
printFloat
```

It takes an implicit `Float`, and the compiler will find `getFloat` as a possible candidate:

```scala
printFloat(getFloat)
```

`getFloat` takes an implicit `Double` though. Luckily, there's one in scope: `defaultDouble`:

```scala
printFloat(getFloat(defaultDouble))
// 3.0
```

Which is strictly equivalent to:

```scala
printFloat
// 3.0
```

## `(Int, String)` decoder

Now that we know that we can define implicit functions and that, if their parameters are implicit and satisfied, the compiler will work the whole thing out for us, we can rewrite `tupleDecoder` to benefit from that:

```scala
implicit def tupleDecoder(
    implicit da: CellDecoder[Int],
             db: CellDecoder[String]
  ) = RowDecoder.from[(Int, String)] {
  row => (
    da.decode(row(0)),
    db.decode(row(1))
  )
}
```

`tupleDecoder` now takes two implicit parameters, a `CellDecoder[Int]` and a `CellDecoder[String]`.

## `(A, B)` decoder

As before though, we don't actually need to know about the actual types we're decoding to - they could be anything, provided they have `CellDecoder` instances. We can rewrite `tupleDecoder` to take type parameters instead:

```scala
implicit def tupleDecoder[A, B](
    implicit da: CellDecoder[A],
             db: CellDecoder[B]
  ) = RowDecoder.from[(A, B)] {
  row => (
    da.decode(row(0)),
    db.decode(row(1))
  )
}
```

And this is mildly magical: given an `A` and `B` that both have a `CellDecoder`, we can provide a `Rowdecoder[(A, B)]`. That's a lot of code we'll never have to write.

## Heterogenous types

Now that we're satisfied with our `tupleDecoder` implementation, we can try it out. Here's the data that started this whole thing as a Scala value:

```scala
val input = """1997,Ford
              |2000,Mercury"""
```

And if we attempt to decode it as a list of `(Int, String)`, it'll work out exactly as hoped:

```scala
decodeCsv[(Int, String)](input)
// res0: List[(Int, String)] = List((1997,Ford), (2000,Mercury))
```

The compiler does a fair amount of work for us here. First, it'll look for an implicit `RowDecoder[(Int, String)]` and realise that `tupleDecoder` might work out:

```scala
decodeCsv[(Int, String)](input)(tupleDecoder[Int, String])
```

`tupleDecoder` takes two implicit arguments, however: cell decoders of `Int` and `String`. We've declared implicit values for these types, which allows the compiler to rewrite our initial code as:

```scala
decodeCsv[(Int, String)](input)(tupleDecoder[Int, String](
  intCellDecoder,
  stringCellDecoder
))
// res1: List[(Int, String)] = List((1997,Ford), (2000,Mercury))
```

## Collections of values

Attentive readers will have realised we've lost a feature along the way: we used to be able to decode the following CSV data into a `List[List[Int]]`.

```csv
1,2,3
4,5,6
7,8,9
```

We can't really do that anymore, however - `decodeCsv` has changed and we'd need a `RowDecoder` for lists.

Fortunately, this is relatively easy to write:

```scala
implicit def listDecoder[A](
  implicit da: CellDecoder[A]
) =  RowDecoder.from[List[A]] { row =>
  row.map(da.decode)
}
```

Given an `A` that has a `CellDecoder`, we can provide a `RowDecoder[List[A]]` by mapping into each cell and applying the decoder.

And, given the following input:

```scala
val input = """1,2,3
              |4,5,6
              |7,8,9"""
```

We can now call `decodeCsv` with a `List[Int]` type argument and gets the expected output:

```scala
decodeCsv[List[Int]](input)
// res2: List[List[Int]] = List(List(1, 2, 3), List(4, 5, 6), List(7, 8, 9))
```

This is because, again, the compiler does a lot of work for us. First, it'll look for a `RowDecoder[List[Int]]` and realise that `listDecoder` might be a match:

```scala
decodeCsv[List[Int]](input)(listDecoder[Int])
```

This still needs a `CellDecoder[Int]`, but we've provided that. This allows the compiler to turn our initial code into:

```scala
decodeCsv[List[Int]](input)(listDecoder[Int](
  intCellDecoder
))
// res3: List[List[Int]] = List(List(1, 2, 3), List(4, 5, 6), List(7, 8, 9))
```

## Optional cells

We can go further. Take the following CSV file:

```csv
1997,Ford
 ,Mercury
```

It's a bit problematic: the first cell of each row is sometimes an int, sometimes empty. This is something that we'd love to decode as an `Option[Int]`.

And, of course, this is entirely possible:

```scala
implicit def optionCellDecoder[A](
  implicit da: CellDecoder[A]
) = CellDecoder.from[Option[A]] { cell =>
  if(cell.trim.isEmpty) None
  else                  Some(da.decode(cell))
}
```

Given an `A` that has a `CellDecoder`, we can provide a `CellDecoder[Option[A]]` by checking if a cell is empty:
* if it is, return `None`.
* if it's not, decode it and stick the result in a `Some`.

Here's our input as a Scala value:

```scala
val input = """1997,Ford
              | ,Mercury"""
```

`decodeCsv` will now be perfectly happy to decode it as a list of `(Option[Int], String)`:

```scala
decodeCsv[(Option[Int], String)](input)
// res4: List[(Option[Int], String)] = List((Some(1997),Ford), (None,Mercury))
```

The compiler goes through a few steps to work that one out for us. First, it'll need a `RowDecoder[(Option[Int], String)]` and stumble on `tupleDecoder`:

```scala
decodeCsv[(Option[Int], String)](input)(
  tupleDecoder[Option[Int], String]
)
```

`tupleDecoder` expects a `CellDecoder[Option[Int]]` and a `CellDecoder[String]`, which the compiler can find:

```scala
decodeCsv[(Option[Int], String)](input)(
  tupleDecoder[Option[Int], String](
    optionCellDecoder[Int],
    stringCellDecoder
))
```

Finally, `optionCellDecoder` needs a `CellDecoder[Int]`, which we have provided, allowing the compiler to turn our initial code in the rather more verbose:

```scala
decodeCsv[(Option[Int], String)](input)(
  tupleDecoder[Option[Int], String](
    optionCellDecoder[Int](intCellDecoder),
    stringCellDecoder
))
// res5: List[(Option[Int], String)] = List((Some(1997),Ford), (None,Mercury))
```

## Cells with multiple types

We can go further yet! Look at the following CSV file:

```scala
1997,Ford
true,Mercury
```

The first cell of the first row is sometimes an int, sometimes a boolean. This would typically be decoded as an `Either[Int, Boolean]`.

This is absolutely something we can support:

```scala
implicit def eitherCellDecoder[A, B](
  implicit da: CellDecoder[A],
           db: CellDecoder[B]
) = CellDecoder.from[Either[A, B]] { cell =>
    try { Left(da.decode(cell)) }
    catch {
      case _: Throwable => Right(db.decode(cell))
    }
  }
```

Given an `A` and a `B`, both with `CellDecoder` instances, we can provide a `CellDecoder[Either[A, B]]`, by:
* attempting to decode a cell as an `A` and sticking the result into a `Left`.
* if that failed, decoding the cell as a `B` and putting it into a `Right`.

Here's our input as a Scala value:

```scala
val input = """1997,Ford
              |true,Mercury"""
```

We can now easily decode it as a list of `(Either[Int, Boolean], String)` and get the expected output:

```scala
decodeCsv[(Either[Int, Boolean], String)](input)
// res6: List[(Either[Int,Boolean], String)] = List((Left(1997),Ford), (Right(true),Mercury))
```

As usual, the compiler is quite busy on our behalf. It'll first need a `RowDecoder[(Either[Int, Boolean], String)]` and find `tupleDecoder`:

```scala
decodeCsv[(Either[Int, Boolean], String)](input)(
  tupleDecoder[Either[Int, Boolean], String]
)
```

This requires a `CellDecoder[Either[Int, Boolean]]` and a `CellDecoder[String]`, which we have provided instances for:

```scala
decodeCsv[(Either[Int, Boolean], String)](input)(
  tupleDecoder[Either[Int, Boolean], String](
    eitherCellDecoder[Int, Boolean],
    stringCellDecoder
))
```

`eitherCellDecoder` still needs a `CellDecoder[Int]` and a `CellDecoder[Boolean]`, but we've provided instances for these as well, and the compiler can desugar our initial code to:

```scala
decodeCsv[(Either[Int, Boolean], String)](input)(
  tupleDecoder[Either[Int, Boolean], String](
    eitherCellDecoder[Int, Boolean](
      intCellDecoder,
      booleanCellDecoder
    ),
    stringCellDecoder
))
// res7: List[(Either[Int,Boolean], String)] = List((Left(1997),Ford), (Right(true),Mercury))
```

## Going nuts

Finally, we can go a bit nuts just for the hell of it.

The following CSV file might look innocent, but is a bit of a nightmare:

```csv
1997,Ford
true,Mercury
2007,
```

The first cell is of type `Either[Int, Boolean]`. The second one is an `Option[String]`. And we've also decided to decode each row as a `List[Either[Either[Int, Boolean], Option[String]]]` rather than a tuple, because the pain is so nice.

The good news is, we have nothing to do. We've already provided all the instances we needed.

Take our input as a Scala value:

```scala
val input = """1997,Ford
              |true,Mercury
              |2007, """
```

We can just request for it to be decoded as... whatever that type I just wrote was:

```scala
decodeCsv[List[Either[Either[Int, Boolean], Option[String]]]](
  input
)
// res8: List[List[Either[Either[Int,Boolean],Option[String]]]] = List(List(Left(Left(1997)), Right(Some(Ford))), List(Left(Right(true)), Right(Some(Mercury))), List(Left(Left(2007)), Right(None)))
```

I'll spare you and not go through the various desugaring steps. Here's what the compiler eventually comes up with:

```scala
decodeCsv[List[Either[Either[Int, Boolean], Option[String]]]](
  input
)(
  listDecoder[Either[Either[Int, Boolean], Option[String]]](
    eitherCellDecoder[Either[Int, Boolean], Option[String]](
      eitherCellDecoder[Int, Boolean](
        intCellDecoder,
        booleanCellDecoder
      ),
      optionCellDecoder[String](stringCellDecoder)
    )
  )
)
// res9: List[List[Either[Either[Int,Boolean],Option[String]]]] = List(List(Left(Left(1997)), Right(Some(Ford))), List(Left(Right(true)), Right(Some(Mercury))), List(Left(Left(2007)), Right(None)))
```

That's quite a lot of code we didn't have to write, which is my favourite kind of code. I don't know if you attempted to read it, but I had to *write* it and am rather looking forward not doing so ever again.

## Key takeaways

The main thing we've learned here is that, yes, type classes are "merely" syntactic sugar for explicit dictionary passing. I've been careful to show both the pretty and desugared versions every step of the way.

But what incredibly nice syntactic sugar they are! the way they compose implicitly to generate arbitrarily complex instances so that *we don't have to* is one of the defining aspects of type classes.
