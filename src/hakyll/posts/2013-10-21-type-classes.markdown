---
title: Type classes
tags: scala
---

_Type classes_ were an entirely new concept to me when I first discovered them in Scala. Now that (I think) I understand
them, however, they completely changed the way I think about code, inheritance and modularity.

<!--more-->

## Purpose

Type classes are a form of polymorphism used to describe a set of features a class can have, without implementing them
directly in the class. Where subtype polymorphism (inheritance) describes an _is a_ relation, type classes describe
a _can be used as_ one.

This is a bit abstract, so let's take a concrete example. Say that you're using an external library that exposes a
`Person` class, implemented as follows:

```scala
final case class Person(first: String, last: String) {
  override def toString = "%s %s" format (first, last)
}
```

Your application holds a `List[Person]` instance, and needs to sort it alphabetically by last name - for printing
purposes, say. The usual OO solution is to have `Person` extend
[Ordered](http://www.scala-lang.org/api/current/index.html#scala.math.Ordered), but in our case, the library author
didn't think of doing that.

You still have a few options, such as creating an ordered wrapper for `Person`:
```scala
implicit class OrderedPerson(val wrapped: Person) extends AnyVal with Ordered[OrderedPerson] {
  override def compare(that: OrderedPerson): Int = wrapped.last.compareTo(that.wrapped.last)
}
```

That's still not entirely satisfactory, however: a `List[Person]` is not a `List[OrderedPerson]`, and sorting your list
still requires a bit of legwork:
```scala
list.map(new OrderedPerson(_)).sorted.map(_.wrapped)
```

It's not a huge amount of work, but you still need to transform every single entry from a `Person` to an `OrderedPerson`
and back. I also think that having to do it explicitly prevents the Scala compiler from the usual `AnyVal` inlining
optimisations, but might be mistaken.

The problem becomes a bit worse if you need to support multiple sort orders - reverse alphabetical order, say, or
alphabetical on the first name rather than the last one: in addition of having to implement a wrapper class for
each of these sort orders, you need to change the way your list is transformed up to and back from each.

The other solution is to use the [Ordering](http://www.scala-lang.org/api/current/index.html#scala.math.Ordering)
trait as follows:

```scala
implicit object LastNameOrdering extends Ordering[Person] {
  override def compare(a: Person, b: Person): Int = a.last.compareTo(b.last)
}
```

Since `List.sorted` takes an `Ordering` parameter, you can now sort your list as follows:
```scala
list.sorted(LastNameOrdering)
```

Better yet, since both this parameter and `LastNameOrdering` are declared implicit, you can simply bring
`LastNameOrdering` in scope and write:
```scala
list.sorted
```

Supporting multiple sort orders is done by having an implementation of `Ordering[Person]` for each and passing the
correct one to `list.sorted`, either implicitly or explicitly.

`Ordering` is an example of type class: `Person` is not ordered, but it can be used as something that has an order,
and this is materialized by the `LastNameOrdering` type class instance.

It's also important to note that, using this mechanism, we've just augmented `Person`, a final class, with features it
did not have to begin with, and we've do so without modifying or recompiling it, or without wrapping it into adapter
classes.

Another important insight is that thanks to this mechanism, as long as something can conceivably be ordered, we'll be
able to sort a list of it. The sorting problem is dealt with once and for all, and for all possible types of data.


## Writing a type class

We now have a better understanding of what a type class is. Implementing one requires surprisingly little code and,
thanks to Scala's support of implicit parameters, can be made all but invisible to callers.

Let's say that our application requires a facility for printing `Person` to `stdout`. A naive first implementation could
be:

```scala
object Printer {
  def print(p: Person) = println(p)
}
```

This works, but is very limiting:

* the only supported output format is that of `toString`, and we'd need to write adapter classes
  for each format we want to add (JSON, say, or locale dependant formats).
* it only works for `Person` - what if we have another `Company` class that we'd like to print to stdout as well? Do we
  need to write an entirely different printing facility for that?


This is were type classes really shine. Instead of letting the object being printed decide how to format itself, we
create a trait and delegate that responsability to it:

```scala
// Used solely for the purpose of formatting instances of A.
trait Show[A] {
  def show(a: A): String
}

object Printer {
  // Now accepts two parameters: an object to print, and an object that knows how to format it.
  def print[A](a: A, f: Show[A]) = println(f.show(a))
}

// Person specific formatter.
object PersonShow extends Show[Person] {
  override def show(a: Person) = a.last
}

// We've now entirely de-coupled Person and its formatting mechanism.
Printer.print(new Person("Robert", "Smith"), PersonShow)
```

This is nice but a bit verbose: we still need to explicitly pass `PersonShow` around. As usual, Scala has mechanisms to
reduce the verbosity: implicit parameters.

```scala
object Printer {
  // The formatter is now an implicit parameter.
  def print[A](a: A)(implicit f: Show[A]) = println(f.show(a))
}

// Declares an implicit Show[Person] in scope.
implicit object PersonShow extends Show[Person] {
  override def show(a: Person) = a.last
}

// We can now omit the formatter entirely.
Printer.print(new Person("Robert", "Smith"))
```

From Scala 2.8 onwards, the same can be achieved through context bounds:
```scala
object Printer {
  // [A: Show] should be read as "A such that there exists an implicit Show[A] in scope"
  def print[A: Show](a: A) = println(implicitly[Show[A]].show(a))
}
```

Not only have we added a new formatting feature to `Person` without modifying its source code or extending it, but
we've also done it for all possible classes. Nothing in our implementation ties us to `Person`: adding support for, say,
dates, is simply done by writing a `Show` implementation for `Date`.

```scala
import java.util.Date

// Formats dates as legal ISO 8601 strings.
implicit object Show extends Show[Date] {
  // For demonstration purposes only, do *not* duplicate this: SimpleDateFormat is not thread safe.
  private val formatter = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssz")
  override def show(date: Date) = formatter.format(date)
}

// Since DateShow is both implicit and in scope, there's no need to pass it explicitly.
Printer.print(new Date())
```
