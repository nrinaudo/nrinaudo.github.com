---
title: Type variance
tags: scala
---
Type variance is a subject that I've long found confusing and counter-intuitive. Attempting to use the semi-mystical
`[+A]` or `[-A]` type annotations would, more often than not, yield an obscure
`covariant type A occurs in contravariant position in type A...` compilation error.

I've finally decided to bite the bullet and make sense of it all. This post is what I came up with after hacking at /
reading on type variance until I decided I had it as figured out as I was likely to for the time being.


<!--more-->


## Type variance

Type variance is in itself a fairly simple concept: classes who process or store values often do not need to know the
exact type of these values, or only need them to follow a known set of constraints.

For example, a `List` doesn't really need to know what it stores - it'll behave exactly the same way whether it contains
instances of `Int` or `String`.

One simple way of writing the `List` class to reflect this is to have it store instances of `AnyRef`, but that would be
at the cost of type safety: since there is no constraint on the stored elements, there's nothing to prevent a `List`
from storing instances of both `Int` and `String`.

Parametric polymorphism allows you to turn the type of elements contained by `List` into a parameter, through the
following syntax:

```scala
// A is the type manipulated by List.
trait List[A] {
  // A can be referenced in List's body.
  def append(a: A): List[A]
}
```

This declares a `List` trait that contains elements of type `A`, to be defined at declaration time. There's what I feel
is an unfortunate wealth of vocabulary to describe this:

* `List` is _generic_ (it doesn't work with a _specific_ type).
* `List` is a type constructor (it accepts a parameter and defines a new type depending on this parameter's value).
* `List` varies on `A`.

Using the previous declaration of `List`, it becomes possible to write code that is both generic and type safe:

```scala
val li: List[Int] = new List[Int] { override def append(i: Int) = this }
```

This works fine: `1` is an `Int` and thus a legal parameter for `append`.

```scala
li.append(1)
```

This, however, fails: passing a `String` value to `append` is not legal.

```scala
li.append("foobar")
```

Note that you might sometimes want to have a list of elements of any type - this is easily achieved by declaring it
as `List[AnyRef]`.

Type variance describes how the relation between instances of `List` vary with the value of their type parameter.
I'll explore these in the rest of this post, using the following traditionnal class hierarchy for illustration:

```scala
// A Mammal has a name.
class Mammal(val name: String)

// A Dog is a Mammal that can bark.
class Dog(name: String) extends Mammal(name) {
  def bark(): Unit = println("bark!")
}

// A Cat is a Mammal that purrs.
class Cat(name: String) extends Mammal(name) {
  def purr(): Unit = println("purrrr")
}
```


## Invariance

By default, generic classes are _invariant_ on their parameter(s): whatever the relation between `A` and `B`, there
won't be any particular relationship between `List[A]` and `List[B]` - `B` could, for example, be a subclass of
`A`, but this would have no bearing on how `List[B]` relates to `List[A]`.

`List` is a nice example in that it's a well known structure that's easy to reason about, but it's a bit cumbersome
when I wish to write actual code. Let's declare a simple `Wrapper` class, _invariant_ in `A`:

```scala
case class Wrapper[A](val a: A) {
  // Retrieves the wrapped value.
  def apply() = a
}
```

Since `Wrapper` is _invariant_ on its parameter, there is no relation between `Wrapper[Dog]` and `Wrapper[Mammal]`.


This does not compile: a `Wrapper[Mammal]` is not a value of type `Wrapper[Dog]`.

```scala
val wd: Wrapper[Dog] = Wrapper(new Mammal("Flipper"))
```

This does not either: a `Wrapper[Dog]` is not a value of type `Wrapper[Mammal]`.

```scala
val wm: Wrapper[Mammal] = Wrapper[Dog](new Dog("Lassie"))
```

That last one is a bit of a shame, though: since a `Dog` is a `Mammal`, surely a `Wrapper[Dog]` should be a
`Wrapper[Mammal]` as well? Which smoothly leads us into our next section, _covariance_.



## Covariance

Saying that a class `C` is _covariant_ on its parameter is saying that if `A` extends `B`, then `C[A]` extends `C[B]`.

In Scala, making a class _covariant_ on its parameter is achieved with the `+` modifier, as in the following example:

```scala
case class Wrapper[+A](val a: A) {
  def apply(): A = a
}
```

With `Wrapper` thus modified, our previous example works as expected.

This still does not compile: `Wrapper[Mammal]` is not an instance of `Wrapper[Dog]`.

```scala
val wd: Wrapper[Dog] = Wrapper(new Mammal("Flipper"))
```

This, however, now compiles: `Wrapper` is covariant on its type parameter, which makes a `Wrapper[Dog]` a value of type
`Wrapper[Mammal]`.

```scala
val wm: Wrapper[Mammal] = Wrapper[Dog](new Dog("Lassie"))
```



## Contravariance

_Contravariance_ is the exact opposite of _covariance_: saying that a class `C` is _contravariant_ on its parameter is
saying that if `A` extends `B`, then `C[B]` extends `C[A]`.

In scala, making a class _contravariant_ on its parameter is achieved with the `-` modifier, as in the following
example:

```scala
trait Printer[-A] {
  // Prints its argument.
  def apply(a: A): Unit
}
```

This is a bit counter intuitive, but makes sense in the case of classes used to _process_ rather than _store_ others:

```scala
// Note how this calls a method defined in Dog but not in Mammal.
class DogPrinter extends Printer[Dog] {
  override def apply(a: Dog): Unit = {
    println(a)
    a.bark()
  }
}

// Since Printer is contravariant, an instance of MammalPrinter is a valid instance of Printer[Dog].
class MammalPrinter extends Printer[Mammal] {
  override def apply(a: Mammal): Unit = {
    println(a)
  }
}
```

Since a `Printer[Mammal]` is a valid value of type `Printer[Dog]`, the following is fine:

```scala
// Compiles: a Printer[Mammal] is a valid Printer[Dog].
val wd: Printer[Dog] = new MammalPrinter()
```

On the other hand, a `Printer[Dog]` is not a valid `Printer[Mammal]`, and the following will fail to compile:

```scala
val wm: Printer[Mammal] = new DogPrinter()
```

If unsure why, consider what happens when DogPrinter calls the bark() method on an instance of Mammal.



## Function variance

Before explaining the compilation errors mentionned in the introduction of this post, we must take a closer look at
functions and how they vary on their parameters and return types.

In Scala, functions are instances. A unary function, for example, is an instance of `Function1[-T, +R]`, where `T` is
the type of the function's parameter and `R` that of its return value.

It's critical to understand why `Function1` is _contravariant_ on its parameter type and _covariant_ on its return
type: most of the complexity of type variance comes from that simple fact.


### Parameter type

The `Printer` trait we defined previously fulfills all the requirements of a unary function. We can in fact have it
extend `Function1[A, Unit]` without changing anything else in our previous code:

```scala
trait Printer[-A] extends Function1[A, Unit] {
  def apply(a: A): Unit
}
```

It wouldn't be possible for `Printer` to be covariant on `A`: it would mean that a `Printer[Dog]` would be a
`Printer[Mammal]`, which would allow us to apply `Dog` specific code to a `Mammal` - say, call the `bark` method on
an instance of `Cat`.

This is a general rule: functions are always contravariant on their parameter types.

### Return type

Just like `Printer` fulfilled the contract of a `Function1[A, Unit]`, `Wrapper` fulfills that of a `Function0[A]`:

```scala
case class Wrapper[+A](val a: A) extends Function0[A] {
  override def apply(): A = a
}
```

`Wrapper` could not possibly be contravariant on `A`: it would mean that a `Wrapper[Mammal]` would be a valid
`Wrapper[Dog]`, which would mean that a valid `Wrapper[Dog]` could return instances of `Cat`.

Just as before, this is a general rule: functions are always covariant on their return values.


## Explanation of the compilation errors

### Covariant in contravariant position
We now have all the necessary keys to understand the dreaded
`covariant type A occurs in contravariant position in type A...` error message.

Let's first modify our `Wrapper` class to cause the issue:

```scala
case class Wrapper[+A](val a: A) {
  def apply(): A = a

  // This method will cause a compilation error message.
  def set(va: A): Wrapper[A] = Wrapper(va)
}
```

Armed with our newfound type variance knowledge, this isn't actually so hard to understand: `Wrapper` is _covariant_ on
`A` while `set` is _contravariant_ on `A` (its parameter type).

Luckily, Scala provides an easy work around through lower type bounds:

```scala
case class Wrapper[+A](val a: A) {
  def apply(): A = a

  // Notice how the signature has changed.
  def set[B >: A](vb: B): Wrapper[B] = Wrapper(vb)
}
```

The `[B >: A]` bit is telling Scala that a local type `B` has been declared, and that `B` must always be a superclass
of `A`.

With that modification, `set` is no longer _covariant_ on `A`, but _contravariant_ on `B`, where `B` is an instance of
`A` or something more general.

This is all a bit theoretical, so let's take a concrete example. Let's pretend that the Scala compiler accepts the
following code:

```scala
case class Wrapper[+A](val a: A) {
  def apply(): A = a
  def set(va: A): Wrapper[A] = Wrapper(va)
}
```

If this were to be considered correct, we'd be able to write the following:

```scala
class BorkedWrapper(i: Dog) extends Wrapper[Dog](i) {
  override def set(vd: Dog): Wrapper[Dog] = {
    // Pay attention to the fact that we're calling bark(), that's the important bit.
    vd.bark()
    new BorkedWrapper(vd)
  }
}

// Wrapper is covariant on A, and Dog is a subtype of Mammal: an instance of Wrapper[Dog] is a legal instance of
// Wrapper[Mammal]. The following line is perfectly legal.
val wd: Wrapper[Mammal] = new BorkedWrapper(new Dog("Lassie"))

// A `Cat` is a legal instance of `Mammal`, there's nothing wrong with setting one to a Wrapper[Mammal]
wd.set(new Cat("Duchess"))
```

Scala just let us write code that calls the `bark` method of `Cat`, which is obviously impossible - that's where the
compilation error comes from. If were, however, to use lower type bounds, we'd find we can't provoque such a scenario
anymore:

```scala
case class Wrapper[+A](val a: A) {
  def apply(): A = a
  def set[B >: A](vb: B): Wrapper[B] = Wrapper(vb)
}

// This class doesn't compile anymore: the set method doesn't actually overwrite Wrapper's, since they don't share
// parameter types. As an aside, that's as perfect an example of the benefit of explicitely writing override as I'm
// likely to find: not using it here would allow the code to compile, and figuring out that we're actually declaring
// two different set methods might take a while.
class BorkedWrapper(i: Dog) extends Wrapper[Dog](i) {
  override def set(vd: Dog): Wrapper[Dog] = {
    vd.bark()
    new BorkedWrapper(vd)
  }
}

// This doesn't compile either:
// - B doesn't have a bark method
// - new DogWrapper(vb) is not legal, since vb is not necessarily an instance of Dog.
class DogWrapper(d: Dog) extends Wrapper[Dog](d) {
  override def set[B >: Dog](vb: B): Wrapper[B] = {
    vb.bark()
    new DogWrapper(vb)
  }
}

val wd: Wrapper[Dog] = Wrapper(new Dog("Lassie"))

// This is now legal: Mammal is a superclass of Dog, so it can be passed to set.
// Note that the returned value is no longer an instance of Wrapper[Dog] but of Wrapper[Mammal].
val wm: Wrapper[Mammal] = wd.set(new Cat("Duchess"))
```


### Contravariant in covariant position

There is of course a symmetrical issue for _contravariance_, which can be seen with the following code:

```scala
trait Printer[-A] {
   def apply(a: A): A
}
```

This causes the following compilation error:
`error: contravariant type A occurs in covariant position in type (a: A)A of method apply`.

Now that we have a good understanding of _contravariance_, _covariance_ and how a function varies, this actually makes
sense: `Printer` is _contravariant_ on `A` while `apply` is _covariant_ on it (since `A` is its return value).

We fix this the same way we did before, with type bounds - although this time we use an upper bound:

```scala
trait Printer[-A] {
   def apply[B <: A](b: B): B
}
```

I'd love to give a concrete example here, but I've failed to find a convincing one so far. I'll update this post if I
ever do.



## Mutable types and variance

A last note about type variance: _contravariance_ and _covariance_ only work with immutable structures. Mutable ones
can be _invariant_, but they cannot be made anything else.

As a demonstration, let's try to make `Wrapper` mutable:

```scala
case class Wrapper[+A](private var a: A) {
  def get: A = a

  // This won't work: a is an instance of A and cannot be used to store instances of B, since
  // B is necessarily a superclass of A.
  // The only way for this to work is to force B to be the same as A - which means making
  // Wrapper invariant.
  def set[B >: A](vb: B): Unit = a = vb
}
```
