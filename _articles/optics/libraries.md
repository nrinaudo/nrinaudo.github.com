---
title: Libraries
layout: article
series: optics
sequence: 5
---

The Scala ecosystem has a surprisingly large number of optics implementations - especially given how little they seem to be used in practice.

I'll be focusing on 4 I find noteworthy here, but that's certainly not an exhaustive list. If your favourite library (or worse, the one you maintain!) is not here, that's not a judgement on its quality. I'm probably just not aware of it and would gladly hear about it.

## Scalaz

The first library we're going to talk about is, of course, [Scalaz]. It's always there, lurking around, being weird... and it's being particularly weird here.

First, for no reason I could discern, Scalaz doesn't have lenses. It has _lensu_. It doesn't really change anything, but it's just... weird.

Second, Scalaz has *nothing else*. No prism, no optional, no code gen... it's essentially what we've done so far, only not quite as feature rich.

I'd love to express the optics we've already done in an example, but the Scalaz implementation is just too limited - I can only do the service to classifier name lens:

```scala
import scalaz.Lens.lensu

val serviceClassifier = lensu[MlService, Classifier](
  (s, a) => s.copy(classifier = a),
  s      => s.classifier
)

val classifierName = lensu[Classifier, String](
  (s, a) => s.copy(name = a),
  s      => s.name
)

val serviceClassifierName = serviceClassifier andThen classifierName
```

The use site API is essentially the same as ours - not curried, but that's a minor detail:

```scala
classifierName.mod(_.toUpperCase, service)
// res0: MlService = MlService(Login(jsmith,Tr0ub4dor&3),Classifier(NEWS20,20))
```

The best that can be said about Scalaz's optics implementation is that it's there, really. If you already have Scalaz in your classpath, don't mind the boilerplate and don't need anything more than lenses (sorry, _lensu_), go for it. Otherwise, you should consider the alternatives.

## Shapeless

Obviously, the second implementation has got to be [shapeless], doesn't it. But this is one is actually really rather nice, with some fairly powerful auto-derivation features (it is shapeless, after all).

Take a look at the code needed to write the various optics we wrote so far:

```scala
import shapeless.lens

val serviceClassifierName = lens[MlService].classifier.name

val serviceUser = lens[MlService].auth.user
```

And this is, quite frankly, beautiful.

Of course, it's shapeless - if, for whatever reason, it doesn't find an implicit instance it's looking for, you're on your own. It might take you minutes to work it out - or days. And shapeless will not help you; as far as it's concerned, it's your problem, not this.

And it's also being a little bit weird. Shapeless provides lenses and prisms, not optionals. But what it calls prisms are, in fact, optionals. So it does have optionals, but it calls them prisms, and it doesn't have prisms. Or something. It's confusing.

This is not as big a deal as one might think - as we've seen earlier, you'll eventually find yourself working with optionals anyway, so you don't really lose functionality. You just get weird names - but at least it's not _lensu_.

The use site API is very similar to ours, except the parameters are in the other order:

```scala
classifierName.modify(service)(_.toUpperCase)
// res1: MlService = MlService(Login(jsmith,Tr0ub4dor&3),Classifier(NEWS20,20))

userName.set(service)("psmith")
// res2: MlService = MlService(Login(psmith,Tr0ub4dor&3),Classifier(news20,20))
```

All in all, shapeless is a pretty solid implementation, slightly weird but not overly so, and... well, it's shapeless, which is either desirable or a reason to run away screaming, depending on whom you ask.

## Quicklens

A pretty solid choice for optics is SoftwareMill's [quicklens]. By the author's own admission, it's designed to be practical rather than principled, which is why you end up not really manipulating lenses, prisms or optionals, but some more nebulous `Modify` abstraction. The end result is essentially the same though, as you can see in the following code sample:

```scala
import com.softwaremill.quicklens._

val classifierName = modify[MlService](_.classifier.name)

val userName = modify[MlService](_.auth.when[Login].user)
```

`classifierName` is, for all intents and purposes, a `Lens[MlService, String]`, and `userName` an `Optional[MlService, String]`.

Well, except for one thing. As far as I can tell, neither offers a way of retrieving the value at the end of the path. This is not a big deal for lenses - you can just use regular dot-notation to reach inside nested product types - but it might be problematic when working with optionals.

The use site API is very similar to ours:

```scala
classifierName.using(_.toUpperCase)(service)
// res5: MlService = MlService(Login(jsmith,Tr0ub4dor&3),Classifier(NEWS20,20))

userName.setTo("psmith")(service)
// res6: MlService = MlService(Login(psmith,Tr0ub4dor&3),Classifier(news20,20))
```

Aside from that odd getter quirk, the syntax is very lightweight and unobtrusive, and quicklens enjoys a generally very positive reputation.

## Monocle

Finally, you have [Monocle], what I consider to be the canonical optics library in the Scala ecosystem.

It supports all the optics we've talked about so far (plus a few more advanced ones), has auto-derivation of lenses, prisms and optionals, ... it's just that, at the time of writing, it could stand to be a little more terse:

```scala
import monocle.macros._

val serviceClassifierName = GenLens[MlService](_.classifier.name)

val serviceUser = GenLens[MlService](_.auth).
  composePrism(GenPrism[Auth, Login]).
  composeLens(GenLens[Login](_.user))
```

While it's much nicer than doing it by hand, this is not quite the beauty of the shapeless implementation. I've been told by [Julien Truffaut](https://twitter.com/JulienTruffaut/) (the library's author) that he was working on a new version with more advanced combination and derivation features, so there's good hope that things will improve quite a bit in the near future.

The use site API is exactly the same as ours, which is of course not at all a coincidence:

```scala
classifierName.modify(_.toUpperCase)(service)
// res3: MlService = MlService(Login(jsmith,Tr0ub4dor&3),Classifier(NEWS20,20))

userName.set("psmith")(service)
// res4: MlService = MlService(Login(psmith,Tr0ub4dor&3),Classifier(news20,20))
```

It's important to point out that Monocle supports more than just lenses, prisms and optionals. These other optics are out of scope for this article, but I can at least give you an intuition of what they're for.

If you think about it a certain way, lenses are 1-to-1 relationships: given a product type, a lens will always give you access to exactly one value.

Prisms and optionals, on the other hand, are 1-to-0-or-1 relationships: given a sum type, a prism will give you access to a single value - or none, if you're working with the "wrong" branch of the sum type.

Some optics will allow you to map 1-to-many relationships. A list, for instance, is an ADT that contains an unbounded number of values. What we've seen so far doesn't allow us to work with them, but there *are* optics that can.


## Key takeaways

We've seen three major libraries that offered optics implementations. You're very likely to have heard of all of them - scalaz because of all the drama and the others because they're actually useful.

If you have to chose an optics library for a new project, I'd go with either [quicklens] or [Monocle] - quicklens is great for the common, simple use cases (everything we've seen so far, really), while Monocle is a bit less fluid but covers more use cases.

[shapeless]:https://github.com/milessabin/shapeless
[scalaz]:https://github.com/scalaz/scalaz
[quicklens]:https://github.com/softwaremill/quicklens
[Monocle]:https://julien-truffaut.github.io/Monocle/
