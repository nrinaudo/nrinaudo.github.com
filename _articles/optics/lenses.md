---
title: Lenses
layout: article
series: optics
sequence: 2
---

Imagine that we have the following service:

```scala
val service = MlService(
  Login("jsmith", "Tr0ub4dor&3"),
  Classifier("news20", 20)
)
```

Our task is to change the classifier name: there's a convention that classifier names should be all upper case, because we feel it makes for better pretty printing.

In terms of diagram, we're going to need to go through the following path:

<span class="figure">
![Classifier](/img/optics/service-name.svg)
</span>

With an imperative language, such as Java, this would be fairly straightforward:

```java
service.classifier.name = "NEWS20"
```

Granted, this is slightly distasteful - mutability is something we've learned was a code smell. But you have to admit the intent of the code is perfectly clear, especially when contrasted with the way we'd do it in Scala:

```scala
service.copy(
  classifier = service.classifier.copy(
    name = "NEWS20"
  )
)
```

There's a lot of boilerplate there, a lot of code that obscures our intent. Slightly upsetting: as functional programmers, we're used to working with abstractions that have proven laws and properties that we can rely on to trim a lot of fat and write terse, expressive code. That's clearly not the case there.

Let's see what we can do about that.

## Generic setter type

Our first attempt will be to write an abstract setter type that we can use to reach within a data structure and modify one of its values:

```scala
trait Setter[S, A] {
  def set(a: A)(s: S): S
}
```

Nowadays, I'll tend to use full words for type parameters, but in this instance I feel it's important to use the same, one letter names found in all the optics literature.

The `S` (for _state_) type parameter represents the type of the data structure we want to modify. That'd be `MlService` in our scenario, since we're trying to reach inside of it and set the name of its classifier.

`A` is the type of the nested value we want to modify - `String`, in our case, since that's the type of a classifier name.

The important part of our setter is the `set` method which, given an `S` and an `A`, will reach inside of the former to set the latter.

This is how we'd use it:

```scala
val nameSetter: Setter[MlService, String] = ???

val updated: MlService =
  nameSetter.set("NEWS20")(service)
// res1: MlService = MlService(Login(jsmith,Tr0ub4dor&3),Classifier(NEWS20,20))
```

Given an `MlService`, this sets its classifier name to `"NEWS20"`.

This is slightly disappointing, though: our task is not to set the classifier name to a known value, but to retrieve the current value, transform it and update `MlService` with it.

We'll need a `get` combinator to be able to do this:

```scala
trait Setter[S, A] {
  def set(a: A)(s: S): S
  def get(s: S): A
}
```

Given an `MlService`, `get` returns its classifier name. It' fairly straightforward to use:

```scala
val classifierName: String =
  nameSetter.get(service)
// res2: String = "news20"
```

We can now combine `get` and `set` to get write a `modify` combinator:

```scala
trait Setter[S, A] {
  def set(a: A)(s: S): S
  def get(s: S): A

  def modify(f: A => A)(s: S): S = set(f(get(s)))(s)
}
```

Fairly straightforward: instead of taking the target value for `A`, `modify` takes a function from the old `A` to the new one.

In our case, we'd use it as follows:

```scala
val updated: MlService =
  nameSetter.modify(_.toUpperCase)(service)
// res3: MlService = MlService(Login(jsmith,Tr0ub4dor&3),Classifier(NEWS20,20))
```

This looks a lot like what we set out to do. There's a small problem though - I've done far too much Java to feel comfortable with a `Setter` exposing a `get` method.

We'll need a better name for that - a proper FP name; ideally, one that's both pedantic and makes no sense unless you already know why it's called that way.

We're trying to concentrate on a specific part of a data structure - to focus on it, as it were. If you think about it in an admittedly rather twisted way, that could conceivably be called a _lens_.

## Lens

Here's our final type:

```scala
trait Lens[S, A] {
  def set(a: A)(s: S): S
  def get(s: S): A

  def modify(f: A => A)(s: S): S = set(f(get(s)))(s)
}
```

We'll need to create a bunch of them, so let's give ourselves a creation helper:

```scala
object Lens {
  def apply[S, A](
    setter: (A, S) => S,
    getter: S      => A
  ) = new Lens[S, A] {
    override def set(a: A)(s: S) = setter(a, s)
    override def get(s: S)       = getter(s)
  }
}
```

Our `apply` method takes a function for the setter, another for the getter, and sticks them into a `Lens`. That's a fairly common pattern for abstract type instance creation.

I'd like to give names to these setter and getter types. Naming things:
* makes them easier to think about by reducing the cognitive load.
* makes it clear they're important; why bother naming something that's not?

There's a connection we'll need to make later, and having these names should help us see it:

```scala
type Set[S, A] = (A, S) => S

type Get[S, A] = S => A
```

Updating the `Lens` companion object with these, we get:

```scala
object Lens {
  def apply[S, A](
    setter: Set[S, A],
    getter: Get[S, A]
  ) = new Lens[S, A] {
    override def set(a: A)(s: S) = setter(a, s)
    override def get(s: S)       = getter(s)
  }
}
```

## Service → Classifier name

Equipped with `Lens` and its creation helper, we can now tackle what we originally set out to do: modify the classifier name of a service. That is, go through the following path:

<span class="figure">
![Classifier](/img/optics/service-name.svg)
</span>

Looking at this diagram, we get the definite impression that we should be doing that in two steps:
* go from an `MlService` through `classifier` to a value of type `Classifier`.
* go from a `Classifier` through `name`  to a value of type `String.`

Let's follow that intuition.

### Service → Classifier

Going from an `MlService` to a `Classifier` is a single step in our diagram:

<span class="figure">
![Classifier](/img/optics/service-classifier.svg)
</span>

We can create the corresponding `Lens` fairly easily with the tools we've written thus far:

```scala
val serviceClassifier = Lens[MlService, Classifier](
  setter = (a, s) => s.copy(classifier = a),
  getter = s      => s.classifier
)
```

Our setter is a wrapper for the copy constructor, and our getter for a direct field access.

### Classifier → name

Similarly, going from a `Classifier` to its `name` is a single step in our diagram:

<span class="figure">
![Classifier](/img/optics/classifier-name.svg)
</span>

And the lens is implemented in a suspiciously familiar way:

```scala
val classifierName = Lens[Classifier, String](
  setter = (a, s) => s.copy(name = a),
  getter = s      => s.name
)
```

In fact, these two implementations are so similar that you'd be forgiven for thinking there should be a way to generate them automatically. And yes, of course there is, we'll take a look at that later when we go through a quick ecosystem overview.

## Composing lenses

Now that we have lenses for all elements of the path we're trying to go through, we can plug them together and finally upper-case our classifier name:

```scala
serviceClassifier.modify(classifierName.set("NEWS20"))(service)
// res4: MlService = MlService(Login(jsmith,Tr0ub4dor&3),Classifier(NEWS20,20))
```

And that is frankly very disappointing. We've gone through a lot of trouble to write this, and it's arguably not an improvement on what we started with. I *wrote* this and I can barely read it.

When faced with this kind of situation, I usually try to stick the code in a function, parameterise everything I can and see whether a pattern emerges. Let's try that here:

```scala
def setName(name: String, service: MlService) =
  serviceClassifier.modify(classifierName.set(name))(service)
```

That's the same as what we had before, but our `name` and `service` values are now parameters.

What about the lenses though, do they really need to be hard-coded?


```scala
def setName(
    serviceClassifier: Lens[MlService, Classifier],
    nameClassifier   : Lens[Classifier, String]
  )
  (name: String, service: MlService): MlService =
    serviceClassifier.modify(nameClassifier.set(name))(service)
```

If you look at the body of `setName`, it doesn't use the fact that our types are `MlService`, `Classifier` and `String` - it only cares that the lenses commute. That is, that the first one goes to the type the second one begins from.

We can use that to make things more parametric (and rename `setName`, since we're now setting *something*, not necessarily a name):

```scala
def setter[S, A, B](
    l1: Lens[S, A],
    l2: Lens[A, B]
  )
  (b: B, s: S): S =
    l1.modify(l2.set(b))(s)
```

And, if you squint a bit, something interesting should have emerged. Look at that `(b: B, s: S): S` part; doesn't it look familiar? Remember when I said we were giving names to a couple of types to help see a pattern later?

That's a `Set[S, B]`:


```scala
def setter[S, A, B](
    l1: Lens[S, A],
    l2: Lens[A, B]
  )
  : Set[S, B] = (b, s) =>
    l1.modify(l2.set(b))(s)
```

Given a `Lens[S, A]` and a `Lens[A, B]`, we can create the first half of a `Lens[S, B]`. This is interesting. Can we go further? Can we create the second part, the `Get[S, B]`?

Of course we can, with very little work:

```scala
def getter[S, A, B](
    l1: Lens[S, A],
    l2: Lens[A, B]
  )
  : Get[S, B] = s =>
    l2.get(l1.get(s))
```

And *that* is great news. Given a `Lens[S, A]` and a `Lens[A, B]`, we can create a `Lens[S, B]`. Lenses compose!

```scala
def composeLL[S, A, B](
    l1: Lens[S, A],
    l2: Lens[A, B]
  ) = Lens[S, B](
    setter(l1, l2),
    getter(l1, l2)
  )
```

## Service → Classifier → name

Now that we have lenses for all steps of our path and a way to compose them, we should be able to create a lens from `MlService` to `Classifier.name`:

  <span class="figure">
![Classifier](/img/optics/service-name.svg)
</span>

The code is a direct application of what we've done so far:

```scala
val serviceClassifierName = composeLL(
  serviceClassifier,
  classifierName
)
```

And we can now easily modify our service's classifier name:

```scala
serviceClassifierName.modify(_.toUpperCase)(service)
// res5: MlService = MlService(Login(jsmith,Tr0ub4dor&3),Classifier(NEWS20,20))
```

And I feel that it's hard to disagree that we've clearly improved on the initial situation quite a bit. Maybe not a clear win over the imperative syntax - if you're more used to dot-notation than to function application this is still a little awkward to parse - but a major step forward nevertheless.

## Key takeaway

We've created `Lens`, a tool that allows us to focus on specific parts of a product type.

We've also seen that the idiomatic way of working with nested product types was to create the smallest possible lenses and composing them.

How do we deal with *sum* types, however?
