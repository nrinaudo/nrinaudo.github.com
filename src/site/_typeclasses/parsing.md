---
title: CSV parsing
layout: article
sequence: 1
---

We'll first focus on parsing CSV data - that is, turning raw CSV data into an in-memory representation we can manipulate. Not quite a directly useful domain type, but at least something we can work with. This is traditionally known as an abstract syntax tree (AST).

## CSV data

Here's what typical CSV data looks like:

```csv
1,2,3
4,5,6
7,8,9
```

And here's how we'll be representing it for the rest of this article:

```scala
type Cell = String
type Row  = List[Cell]
type Csv  = List[Row]
```

Fairly straightforward, a complete CSV file is a list of rows, a CSV row is a list of cells, and a cell is a string.

## Parsing CSV

Parsing CSV, then, is the act of turning raw CSV data into a value of type `Csv`.

We can achieve that by splitting on line breaks, then on commas:

```scala
def parseCsv(data: String): Csv =
  data.
    split("\n").toList.
    map(_.split(",").toList)
```

Note that this parser is not at all RFC compliant and does not handle any of the edge cases that make CSV such an... interesting... format to deal with. Nor do we deal with the possibility of invalid input. Handling these cleanly would require a fair amount of code that'd obscure the points I'm trying to make.

Now that we have a CSV parser, let's declare some data to feed it:

```scala
val input = """1,2,3
              |4,5,6
              |7,8,9"""
```

Running our parser on it behaves exactly as expected:

```scala
parseCsv(input)
// res0: Csv = List(List(1, 2, 3), List(4, 5, 6), List(7, 8, 9))
```

And, yes, this is what we set out to do; we got a `Csv` by parsing raw CSV data. It's still slightly disappointing though, as this particular input clearly wants to be interpreted as a `List[List[Int]]`.

That's the next step: decoding the CSV into more directly useful types.
