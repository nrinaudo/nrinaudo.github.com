---
title: "Concrete use case: ConfigPath"
layout: article
series: optics
date:   20200224
---

We've been focusing on optics as a way to navigate ADTs so far, but that was a bit of a simplification. In this last part, I'll show a possible use case (heavily inspired by circe's `JsonPath`) that doesn't actually use ADTs.

## Configuration structure

We'll be designing a library that allows us to deal with nested, json-like configuration files like:

```json
{
  "auth": {
    "user"    : "psmith",
    "password": "Tr0ub4dor&3"
  },
  "classifier": {
    "name"      : "news20",
    "classCount": 20
  }
}
```

A common way of representing such configuration data is as a tree like structure:

```scala
sealed trait Config

case class Value(
  value: String
) extends Config

case class Section(
  children: Map[String, Config]
) extends Config
```

A `Config` is either a `Value` (a raw value, as a `String`) or a `Section`, which maps key names to `Config` values. It's a recursive structure, since sections can contain other sections.

Our example configuration file would map directly to the following in-memory data structure:

```scala
val conf = Section(Map(
  "auth" -> Section(Map(
    "user"     -> Value("psmith"),
    "password" -> Value("Tr0ub4dor&3")
  )),
  "classifier" -> Section(Map(
    "name"       -> Value("news20"),
    "classCount" -> Value("20")
  ))
))
```

This is a convenient way of storing configuration, but accessing nested values can be awkward - you'd have to deal with the fact that:
* a key that you expect to be a `Section` might be a `Value`, or vice versa.
* a key that you expect to find doesn't exist.

This sounds a lot like the kind of problems the optics we've developed so far could alleviate. Note that `Map` isn't really an ADT though - `Config` is not an ADT but "simply" an immutable, nested data structure.

Let's see how far we get with the tools we've created.

## Configuration optics

First, the obvious prisms: splitting (diffracting, sorry, I've got to stay in theme) a `Config` in either a `Section` or a `Value`:

```scala
val section = Prism.fromPartial[Config, Section](
  setter = a => a,
  getter = { case a: Section => a }
)

val value = Prism.fromPartial[Config, Value](
  setter = a => a,
  getter = { case a: Value => a }
)
```

We then need some sort of way to explore sections. Given a key name, we want to be able to:

* retrieve the corresponding value, knowing it might not exist.
* set its associated value.

We wrote `Optional` to deal with this exact scenario, so let's see if we can write an `Optional` to explore sections:

```scala
def sectionChild(name: String) = Optional[Section, Config](
  setter = (a, s) => Section(s.children + (name -> a)),
  getter = s      => s.children.get(name)
)
```

Note that it's a bit different than what we're used to. Since key names are not hard-coded in `Section`, we need to access them as parameters: we don't have a generic `Optional[Section, Config]`, but a way of creating one for a given key name.

Armed with these optics, we can:
* go "down" one level from a given `Section` and get a `Config`.
* given a `Config`, turn it into either a `Section` or a `Value`.

This should let us represent paths in configuration tree: from the root of the tree, keep going down the sections you need and retrieve the final segment as a `Value`.

We're still lacking one part of the puzzle though: how would we represent the root of the configuration tree?

We need to be a little creative and write a sort of non-optional `Optional`: an `Optional` that points to itself and always succeeds:

```scala
val identityOpt = Optional[Config, Config](
  setter = (a, _) => a,
  getter = s      => Some(s)
)
```

## ConfigPath

Now that we have optics that allow us to explore the content of a `Config`, we can bundle them up in something that represents a path in our configuration tree:

```scala
case class ConfigPath(current: Optional[Config, Config]) {

  val asValue   = composeOP(current, value)
  val asSection = composeOP(current, section)

  def child(name: String) = ConfigPath(
    composeOO(
      asSection,
      sectionChild(name)
    )
  )
}
```

`ConfigPath` contains an `Optional[Config, Config]` that represents the path we've explored so far.

`child` allows us to build a more complex path: it takes its `name` parameter, assumes the current path points to a `Section`, and attempts to go one level down.

`asValue` and `asSection` allow us to transform whatever path we've built into a value or a section. `asValue` is typically the last thing we'll call, as it'll yield an `Optiona[Config, Value]` which will allow us to work directly with the value at the end of our path.

For example:

```scala
val classifierName: Optional[Config, Value] =
  ConfigPath(identityOpt)
    .child("classifier")
    .child("name")
    .asValue
```

We go from the root to `classifier` to `name`, and ask for that to be a value.

The purpose is clear enough, but the syntax not as pleasant as it could be. We can improve on that thanks to a bit of dark magic with Scala's `Dynamic`.

## Dynamic

`Dynamic` is a bit of an odd corner of Scala that gives us type safe syntax that looks a lot like dynamic code. It offers many tools, but the one we'll be focusing on is `selectDynamic`, which allows us to plug code when unknown members of a class are accessed.

Here's an example, where `UpCase` is a `Dynamic`:

```scala
import scala.language.dynamics

object UpCase extends Dynamic {
  def selectDynamic(missingMember: String): String =
    missingMember.toUpperCase
}
```

Any time a missing member is accessed, the compiler will transform that into a call to `selectDynamic` with that member's name as a parameter.

This allows us to write the following:

```scala
UpCase.bar
// res1: String = BAR
```

This is all type checked and verified, but it _does_ feel a little bit weird, doesn't it? The important thing is, `Dynamic` allows us to rewrite `ConfigPath` with a much nicer syntax.

## Dynamic ConfigPath

Knowing what we do now about `Dynamic`, we can rewrite `ConfigPath` to support `selectDynamic` instead of using `child`:

```scala
case class ConfigPath(
    current: Optional[Config, Config]
  ) extends Dynamic {

  val asValue   = composeOP(current, value)
  val asSection = composeOP(current, section)

  def selectDynamic(child: String) = ConfigPath(
    composeOO(
      asSection,
      sectionChild(child)
    )
  )
}
```

This makes for much nicer syntax:

```scala
val classifierName =
  ConfigPath(identityOpt)
    .classifier
    .name
    .asValue
```

This is *almost* good, but that `ConfigPath(identityOpt)` bit is clearly unpleasant. Let's give it a clear name:

```scala
val root = ConfigPath(identityOpt)
```

And we can now write configuration tree traversals with an extremely clear, readable syntax:

```scala
val classifierName=
  root
    .classifier
    .name
    .asValue
```

Thanks to the work we've just done, we can now easily access or modify a nested configuration value:

```scala
classifierName.get(conf)
// res2: Option[Value] = Some(Value(news20))
```

## Key takeaways

We've learned a few neat things (`Dynamic`, for example), but the main point of this section was to show that you don't *need* ADTs for optics to be useful. As soon as you have immutable nested data that you need to explore, you might be able to simplify your code quite a bit with optics.

Creating optics does seem to involve a fair amount of boilerplate, however - lens implementations, for example, all look the same except for actual value names. It feels like there should be some mechanisms for automating that.
