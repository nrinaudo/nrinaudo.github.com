---
title:  Working with partial values
layout: article
date:   20230521
---

A few years ago, we had to solve a relatively simple problem, but one that proved surprisingly divisive. One of my coworkers hated my solution so much that he quit shortly after.

It's a problem that I find interesting because it encapsulates the essence of functional programming - programming with functions - and its solution is obvious in hindsight. Nobody I ever asked this has ever found what I consider the optimal answer unaided, however.

## Description

The problem goes like this. Your system handles documents. For simplicity's sake, we'll say that a document is composed of two fields:
- its content, a `String`.
- its creation date, a `ZonedDateTime`.

The actual documents in my problem were far more complex, but this is sufficient for our purposes. This leads to the following, rather natural implementation:

```scala
case class Document(content: String, creationDate: ZonedDateTime)
```

These documents can be fed to your platform through a web API, as JSON document. Here's a possible valid submission:
```json
{
  "content":      "Lorem ipsum dolor sit amet",
  "creationDate": "2022-05-22T21:25:00Z"
}
```

The tricky bit is that `creationDate` is optional in the JSON. When absent, it must default to `ZonedDateTime.now()`. This is a valid JSON document:
```json
{
  "content": "Lorem ipsum dolor sit amet"
}
```

The problem, then, is how to model this default value constraint. I would suggest you try it for yourself before reading further - it's more subtle that you're probably thinking.


## Naive approach

The approach most people immediately go for is to make the `creationDate` optional:

```scala
case class Document(content: String, creationDate: Option[ZonedDateTime])
```

I believe this approach is driven by the habit that people got into of never writing JSON codecs by hand, to the point that the notion doesn't even occur to them. Since the JSON has an optional `creationDate` field, and since the in-memory representation must be an exact match for the JSON one, then clearly, `Document` must have an optional `creationDate`.

I think it's a very bad solution though, because by specification, `creationDate` is *not* optional. It is in the JSON, sure, but a document will always have the field set - either to what was in the JSON, or to `ZonedDateTime.now()`.

By flagging `creationDate` as optional in `Document`, we force every single one of our users to deal with the `None` case, knowing full well that this is an illegal state. We've made illegal state representable, and everybody's life is slightly worse for it.

## Default value in the decoder

Another approach, slightly less common but that still comes up often enough, is to have the JSON decoder implement the default value logic.

With this approach, `Document` does not need to be modified, we can keep our original implementation:

```scala
case class Document(content: String, creationDate: ZonedDateTime)
```

The decoder, however, must treat `creationDate` as optional and replace it with `ZonedDateTime.now()` when absent:

```scala
given decoder: Decoder[Document] = cursor =>
  for
    content      <- cursor.get[String]("content")
    creationDate <- cursor.get[Option[ZonedDateTime]]("creationDate")
  yield Document(content, creationDate.getOrElse(ZonedDateTime.now()))
```

This is, in my opinion, better (consumers of `Document` no longer have to deal with non-optional optional fields), but not perfect: our decoder uses global mutable state. Think about it for a second if it's not obvious, it's an important realization to make if you can.

We're relying on the current time - this is both very global (everybody has access to it) and very mutable (time changes *all the time*, that's basically what time is). Global mutable state is best avoided when possible, one reason (but not the only one!) being that it makes testing cumbersome. It's very hard to write a _given this input, I expect this output_ test when it's impossible to predict the value of one of the fields.

So, better, but still not perfect.

## Incomplete documents

A few people come up with the following idea: if the JSON does not contain a `creationDate` field, then the document is incomplete. Why not create a type to represent that state?

There are a few variations of this solution.

Most people who work with me know how unreasonably fond I am of algebraic data types, and will thus assume the solution must use some sort of sum type. This leads to the reasonable idea that a document is either complete or incomplete:

```scala
enum Document:
  case Complete(content: String, creationDate: ZonedDateTime)
  case Incomplete(content: String)
```

It's then pretty straightforward to write a decoder for that - we can still decode `creationDate` as optional and, if absent, return a `Document.Incomplete`.

```scala
given decoder: Decoder[Document] = cursor =>
  for
    content      <- cursor.get[String]("content")
    creationDate <- cursor.get[Option[ZonedDateTime]]("creationDate")
  yield creationDate match
    case Some(date) => Document.Complete(content, date)
    case None       => Document.Incomplete(content)
```

While this works, it's not very different from our first, naive implementation. There is no real difference between this `Document` and the one with an optional `creationDate`, both force developers to handle the empty case which is, by specification, impossible. We *could*, instead, manipulate `Document.Complete` everywhere, but that's a little bit weird - why make a public distinction between complete and incomplete documents when incomplete documents must not exist outside of the JSON world?

## Distinct JSON and business types

At this point, some developers will realise that you're allowed to decode a type that is not `Document`, transform the result into one, and pass that to the rest of the system. A simple example of that idea is to use something similar to our first, naive implementation:

```scala
case class SubmissionDocument(content: String, creationDate: Option[ZonedDateTime])
```

Shapeless fans will be delighted to read that they can avoid a bit of code by auto-deriving a `Decoder[SubmissionDocument]`. Turning that into a `Document` is then trivial:

```scala
def toDocument(doc: SubmissionDocument): Document =
  doc.creationDate match
    case Some(date) => Document(doc.content, date)
    case None       => Document(doc.content, ZonedDateTime.now())
```

The keen eyed reader will realise that this still relies on global mutable state. We can solve that easily enough by taking a default date as a parameter, and ignoring it if we already have one:

```scala
def toDocument(doc: SubmissionDocument, defaultDate: => ZonedDateTime): Document =
  doc.creationDate match
    case Some(date) => Document(doc.content, date)
    case None       => Document(doc.content, defaultDate)
```

To make this a little more pleasant to use, and since Scala is first and foremost an OOP language, we can tie everything neatly together in a method:


```scala
case class SubmissionDocument(content: String, creationDate: Option[ZonedDateTime]):
  def toDocument(defaultDate: => ZonedDateType): Document =
    creationDate match
      case Some(date) => Document(content, date)
      case None       => Document(content, defaultDate)
```


This is *almost* the solution I want, but not quite yet.

## My preferred solution

What we've done, really, is write a type that says _if you give me a date, I will return a `Document`_. Can you think of a standard type that expresses this exact idea?

That's right, a function. `ZonedDateTime => Document` is exactly something that, given a date, will return a document. It's, weirdly, not something anybody I've asked to solve this problem has ever come up with. Weirdly, because what is functional programming if it's not working with functions as values? Why, then, is the idea of using a function as a value so hard to come up with in this context?

Implementing this is extremely easy. No need to write an intermediate `SubmissionDocument` type, as this is exactly `ZonedDateTime => Document`. We merely need to write a decoder:

```scala
given decoder: Decoder[ZonedDateTime => Document] = cursor =>
  for
    content      <- cursor.get[String]("content")
    creationDate <- cursor.get[Option[ZonedDateTime]]("creationDate")
  yield creationDate match
    case Some(date) => (_   : ZonedDateTime) => Document(content, date)
    case None       => (date: ZonedDateTime) => Document(content, date)
```

Note that you can of course do both the previous solution and this one at the same time, by having `SubmissionDocument` extend `ZonedDateTime => Document` (and renaming `toDocument` `apply`). It could be argued to be the best of both worlds, depending on your stance on auto-derivation of JSON codecs.

## Conclusion

Decoding to functions is (apparently!) not something intuitive, but very useful, and applicable to many other scenarios. It might seem obvious, but: whenever you find yourself working with partial values - values that need a little more data to produce a value of the type you need - think of functions.

This advise can be made more general, too: when in doubt, think of functions. You are, after all, doing functional programming.
