---
title: Type classes in OOP?
layout: article
series: typeclasses
sequence: 3
---

We've seen what a type class was - a clever combination of parametric polymorphism and implicit resolution. Before we go further down that path though, I'd like to explore how we could achieve the same feature in a mainstream OOP language.

## Subclassing

Our goal is to make `decodeCsv` polymorphic, and the main vector for polymorphism in OOP is subclassing, so let's try that first.

We'll first need an interface for "types that can be decoded from cells":

```java
interface DecodableFromCell<A> {
    A decodeCell(String cell);
}
```

This will allow us to write `decodeCsv`. First, a quick disclaimer: I have not written Java in years and am a bit rusty. The following bit of code might look like I'm going out of my way to make it hard and unpleasant to read, but I really tried my best! Should you know of a way to write that in a neater fashion, please, drop me a line. I'd love to simplify it.

```java
public <A extends DecodableFromCell<A>>
    List<List<A>> decodeCsv(String csv) {

    Function<String, A> decode = ???;

    return parseCsv(csv)
        .stream()
        .map(row -> row
             .stream()
             .map(decode)
             .collect(Collectors.toList()))
        .collect(Collectors.toList());
    }
```

That's a lot of code to do what the same thing we wrote in Scala earlier: parse CSV into a list of list of strings, map into each row, then into each cell, and apply our decoding function.

Only... we don't actually have a decoding function to apply, do we? The only thing we have that resembles it is `A.decodeCell`. This has the right type signature, but is a method of `A`: we'd need a value of type `A` to be able to apply it, but we don't have one. The entire point of the exercise is to produce one.

This is an important distinction between type classes and subclassing. With type classes, behaviours (functions) and values are not coupled, you can have one without the other. With subclassing, the two are very tightly coupled: you cannot access behaviours without a value of the corresponding type.

That being said, maybe our initial idea of trying subclassing wasn't great. Our Scala implementation relied on passing `CellDecoder`, a dictionary of behaviours, to `decodeCsv`. We can try the same approach here.

## Explicit dictionary

Here's `CellDecoder` in Java. The differences with our Scala implementation are purely syntactic:

```java
interface CellDecoder<A> {
    A decode(String cell);
}
```

This allows us to update `decodeCsv` to take an explicit `CellDecoder`:

```java
public <A> List<List<A>>
    decodeCsv(String csv, CellDecoder<A> decoder) {
    Function<String, A> decode = cell -> decoder.decode(cell);
    return parseCsv(csv)
        .stream()
        .map(row -> row
             .stream()
             .map(decode)
             .collect(Collectors.toList()))
        .collect(Collectors.toList());
}
```

We now have a decoding function: `CellDecoder.decode`, which we can call by virtue of having a `Celldecoder` value.

Writing a `CellDecoder<Integer>` is straightforward:

```java
CellDecoder<Integer> intCellDecoder =
    cell -> Integer.parseInt(cell);
```

And we can now decode our raw CSV into a list of list of ints by passing `intCellDecoder` explicitly:

```java
decodeCsv("1,2,3\n4,5,6", intCellDecoder);
// [[1, 2, 3], [4, 5, 6]]
```

This is, in fact, a common Java pattern. You can see it, for example, with [`Comparator`]: an alternative to the subclassing-based [`Comparable`].

## Key takeaways

We've learned a key difference between subclassing and type classes:
* values and behaviours are tightly coupled in subclassing, and you can't have one without the other.
* values and behaviours are not coupled at all in type classes, making them at least a bit more flexible.

We've also come to the conclusion that we could pass dictionaries of behaviours around explicitly and achieve the same result as type classes - that they are, in a way, merely syntactic sugar.

[`Comparator`]:https://docs.oracle.com/javase/8/docs/api/java/util/Comparator.html
[`Comparable`]:https://docs.oracle.com/javase/8/docs/api/java/lang/Comparable.html
