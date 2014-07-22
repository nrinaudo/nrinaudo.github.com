---
title: Type classes
tags: scala
---

_Type classes_ were an entirely new concept to me when I discovered them in Scala. Now that (I think) I understand them,
however, they completely changed the way I think about code, inheritance and modularity.

<!--more-->

## Purpose

Type classes are used to decorelate classes and their features, with the purpose of allowing developers to add
functionalities to, or offer multiple version of the same functionality for, a given class
*without modifying that class*.

Say, for example, that you're using an external library that exposes a `Person` class, implemented as follows:
```scala
final case class Person(first: String, last: String) {
  override def toString = "%s %s" format (first, last)
}
```

Your application holds a `List` of `Person` instances, and you'd like to sort them, say, alphabetically by family name.
At this point, if the external library hasn't already made `Person` sortable, you have very few options (short of
re-implementing your own sort, which we want to avoid).

The first one is to create an adapter that implements
[Ordered](http://www.scala-lang.org/api/current/index.html#scala.math.Ordered):

```scala
class OrderedPerson(val wrapped: Person) extends Ordered[OrderedPerson] {
  override def compare(that: OrderedPerson): Int = wrapped.last.compareTo(that.wrapped.last)

  override def toString = wrapped.toString
}
```

This works, but with a few flaws:

* you're not working with instances of `Person` anymore, and need to transform your objects back and forth (or have
  `OrderedPerson` extend `Person` and proxy every single method)
* implementing multiple sorting strategies (by first name, for example) is possible but requires a lot of legwork

The other solution is to use the [Ordering](http://www.scala-lang.org/api/current/index.html#scala.math.Ordering)
type class as follows:

```scala
implicit object LastNameOrdering extends Ordering[Person] {
  override def compare(a: Person, b: Person): Int = a.last.compareTo(b.last)
}
```

Since all Scala methods that sort objects accept an instance of `Ordering` (`List.sorted`, `Sorting.quickSort`...),
`LastNameOrdering` has just retrofitted `Person` with the ability to be sorted without actually modifying its code.
Implementing another sorting strategy is simply done by writing another implementation of `Ordering`. Additionally,
since all methods that expect an instance of `Ordering` declare it as an implicit parameter, and we've made
`LastNameOrdering` an implicit object, we don't even need to explicitly pass it around - as long as it's in scope, it
will be used automatically by the compiler.


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

* the only supported format is that implemented by the `toString` method, and we'd need to write adapter classes for
  each format we want to add
* it only works for `Person` - what if we have another `Company` class that we'd like to print to stdout as well? Do we
  need to write an entirely different printing facility for that?


This is were type classes really shine. Instead of letting the object being printed decide how to format itself, we
create a trait and delegate that responsability to it:

```scala
// Used solely for the purpose of formatting instances of A.
trait Formatter[A] {
  def format(a: A): String
}

object Printer {
  // Now accepts two parameters: an object to print, and an object that knows how to format it.
  def print[A](a: A, f: Formatter[A]) = println(f.format(a))
}

// Person specific formatter.
object PersonFormatter extends Formatter[Person] {
  override def format(a: Person) = a.last
}

// We've now entirely de-coupled Person and its formatting mechanism.
Printer.print(new Person("Robert", "Smith"), PersonFormatter)
```

This is nice but a bit verbose. As usual, Scala has mechanism to reduce the verbosity: implicit parameters.

```scala
object Printer {
  // The formatter is now an implicit parameter.
  def print[A](a: A)(implicit f: Formatter[A]) = println(f.format(a))
}

// Declares an implicit Formatter[Person] in scope.
implicit object PersonFormatter extends Formatter[Person] {
  override def format(a: Person) = a.last
}

// We can now omit the formatter entirely.
Printer.print(new Person("Robert", "Smith"))
```

From Scala 2.8 onwards, the same can be achieved through context bounds:
```scala
object Printer {
  // [A: Formatter] should be read as "class that has an associated implicit Formatter".
  def print[A: Formatter](a: A) = println(implicitly[Formatter[A]].format(a))
}
```

Not only have we added a new formatting feature to `Person` without modifying its source code or extending it, but
we've also done it for all possible classes. Nothing in our implementation ties us to `Person`: adding support for, say,
dates, is simply done by writing a `Formatter` implementation for `Date`.

```scala
import java.util.Date

// Formats dates as legal ISO 8601 strings.
implicit object DateFormatter extends Formatter[Date] {
  private val formatter = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssz")
  override def format(date: Date) = formatter.format(date)
}

// Since DateFormatter is both implicit and in scope, there's no need to pass it explicitly.
Printer.print(new Date())
```


## Type safety

Another advantage of type classes is that, since they're validated at compile time, they're inherently safe. Subtype
polymorphism is mostly safe, but must rely on trust in some cases. The following (contrived) example compiles, but fails
at runtime:

```scala
def print(a: Any) = println(a.asInstanceOf[Person].first)

print(new java.util.Date())
```

Such a situation is not possible with type classes, where all types are know to and validated by the compiler.
