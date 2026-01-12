---
title:  Reporting errors
layout: article
series: kantan_tests
code:   https://github.com/nrinaudo/kantan.tests/blob/main/src/main/scala/Log.scala
date:   20260113
---

In our last article, we enriched tests with the ability to fail with useful error messages. And while this is a significant improvement over simple booleans, I would argue it's not quite enough yet.

To convince ourselves of this, let's take the traditional example of a failing property, a poorly implemented test for `List.reverse`:

```scala
test("list reverse"):
  val xs = Rand.listOfN(Rand.int(100), Rand.lowerAscii)
  val ys = Rand.listOfN(Rand.int(100), Rand.lowerAscii)
  
  val lhs = (xs ++ ys).reverse
  val rhs = xs.reverse ++ ys.reverse

  assert(lhs == rhs, s"$lhs was not equal to $rhs")
```

This fails with:

```
list reverse: failure
Error: List(o, u, l) was not equal to List(u, l, o)
```

The mistake, of course, is that `rhs` should be `ys.reverse ++ xs.reverse`, but this isn't terribly important. What matters is that our test fails, and we're told _why_, but not on _what input_. This is a little critical in the context of generative tests, which have a tendency to unearth weird, annoying edge cases that we hadn't considered and need to see and be able to reproduce.

And yes, you may argue that we could update the assertion message to include this information, but it's not quite the same. I want a generic way of describing failing inputs that could be used by, for example, a fancy test report generator to produce a well laid-out PDF with inputs and their associated values in some sort of table. Something like this:

| Name | Value        |
|------|--------------|
| `xs` | `List(o)`    |
| `ys` | `List(l, u)` |


## The `Log` capability

What we really want is the ability to log inputs somehow. We know how to do this by now: with a dedicated capability. We'll call it `Log`, and the general idea should not be too surprising: tests will rely on it to log their inputs, and test runners will gain access to these logs through a bespoke handler.

The capability itself is straightforward:

```scala
import caps.*

trait Log extends SharedCapability:
  def logInput(name: String, value: String): Unit
```

We could add other primitive operations - free-form logging would be interesting, for example - but it would just make this article noisier without any clear pedagogical interest.

Now that the capability is defined, we need to give users tools to interact with it. After playing with different styles, my favourite one is very similar to what Hedgehog does and looks like this:

```scala
val name = Rand.identifier.logAs("Name")
```

I like that you can declare, initialise and log the input in one fell swoop, with little syntactic overhead.

This is easy enough to implement. Since `logAs` can be called on any value, it must be an extension method (declared in `Log`):
```scala
extension [A](a: A)
  def logAs(name: String): A =
    logInput(name, a.toString)
    a
```

I'm a little bothered by the use of `toString` here as it can have debatably useful behaviours - have you tried printing a function lately? - but should it become a problem, a simple pretty-printing type class would do the trick.

## A handler for `Log`

The way we want to handle `Log` is simple: store all declared inputs and their values, and expose them once the handler is spent. We've already done something very much like this with [Rand.tracking](./properties.html#mutable-handlers), and will apply the lessons we learned there:
- the handler will rely on a local mutable state to keep track of inputs.
- the final, immutable result will be exposed in the result of the prompt.

First, we'll need a type to bundle the result of a computation with the corresponding inputs, which we'll put in the companion object of `Log`:
```scala
case class Recorded[A](value: A, inputs: Map[String, String])
```

I would probably use an _opaque type_ rather than a plain `Map` in production code, but this is good enough for now.

Using `Log.Recorded` is not too difficult, as it's basically the same thing we've done with [`Rand.Tracked`](./properties.html#Rand.Tracked). We merely need to declare the following prompt in `Log`'s companion object:
```scala
def apply[A](body: Log ?=> A): Log.Recorded[A] =
  val inputs = MutableMap.empty[String, String]

  given Log = (name, value) => inputs += (name -> value)

  Log.Recorded(body, inputs.toMap)
```

## Adapting the test runner

We now have the everything we need to log test inputs - a capability, useful operations and a prompt. In order for tests to take advantage of this, however, there's still a little bit of work left.

First, of course, we must add `Log` to the type of tests: `(Assert, Log, Rand) ?=> Unit`. And if you're wondering, yes, the capabilities are intentionally ordered alphabetically. Capability order doesn't particularly matter to the compiler, but at least this way I have a reasonable shot at giving tests a consistent type. I am a little obsessive about these things, yes.

Running a test now needs to provide a `Log` handler:

```scala
def runTest(
    body: (Assert, Log, Rand) ?=> Unit
): Rand.Tracked[Log.Recorded[AssertionResult]] =
  Rand:
    Rand.tracking:
      Log:
        Assert:
          body
```

Note how this changes the return type. Things get a little nested, which I'm not entirely happy with but not quite unhappy enough to do something about yet.

Before we update the `test` function, I want to take the opportunity to tidy things up a little. We now have lots of information to return: whether or not a failing test case was found, the corresponding error message and inputs, and why not? the test's description and number of times it was successfully evaluated. That's enough data to warrant a dedicated type:

```scala
case class FailedTestCase(msg: String, inputs: Map[String, String])

case class TestResult(
    desc        : String,
    successCount: Int,
    testCase    : Option[FailedTestCase]
)
```

This allows us to clean `test` up a little, which is a piece of luck because that pattern match is getting quite close to the limit of what I consider acceptably readable with these nested patterns:

```scala
def test(desc: String)(body: (Assert, Log, Rand) ?=> Unit) =

  def loop(successCount: Int): TestResult =
    runTest(body) match
      case Rand.Tracked(Log.Recorded(AssertionResult.Success, _), isGenerative) =>
        if isGenerative && successCount < 100
          then loop(successCount + 1)
          else TestResult(desc, successCount, None)

      case Rand.Tracked(Log.Recorded(AssertionResult.Failure(msg), inputs), _) =>
        TestResult(desc, successCount, Some(FailedTestCase(msg, inputs)))

  report(loop(0))
```

And finally, the reason we did all this work: we can update `report` to display all this new useful information:

```scala
def report(result: TestResult) =
  result match
    case TestResult(desc, successCount, None) =>
      println(s"$desc: success ($successCount successfull attemps)")

    case TestResult(desc, successCount, Some(FailedTestCase(msg, inputs))) =>
      println(s"$desc: failure ($successCount successfull attempts)")
      println(s"Error: $msg")

      if (inputs.nonEmpty)
        println("Inputs:")
        inputs.foreach:
          case (name, value) => println(s"  - $name: $value")
```

We could make this extra nice by using fancy ANSI colours, with successful tests in green and failing ones in red. It's not actually all that hard - the clean way of doing it would be to declare a `Console` capability, but I'll leave this as an exercise to the reader.


## Running the test

Everything is now correctly set up. We can rewrite our _list reverse_ test to use `logAs`:

```scala
test("list reverse"):
  val xs = Rand
    .listOfN(Rand.int(100), Rand.lowerAscii)
    .logAs("xs")
  val ys = Rand
    .listOfN(Rand.int(100), Rand.lowerAscii)
    .logAs("ys")

  val lhs = (xs ++ ys).reverse
  val rhs = xs.reverse ++ ys.reverse

  assert(lhs == rhs, s"$lhs was not equal to $rhs")
```

As before, we almost immediately get an error, but a much more directly useful one:

```
list reverse: failure (2 successfull attempts)
Error: List(o, u, l) was not equal to List(u, l, o)
Inputs:
  - ys: List(o)
  - xs: List(l, u)
```

I find this error message quite acceptable. We know what test failed, why, and on what input. Essentially everything we need to debug and fix the problem. Of course, we could go one step further and provide some way of re-running the exact same test with the same inputs, and we eventually will, but there are a few more urgent features we'll need to write before that.

## Conclusion

Our test library is becoming quite useful. We can run tests, generative or otherwise, expressed in a simple and comfortable assertion DSL, and report errors with all the information we might need to understand what went wrong.

Except. If you've used PBT libraries before, you're probably, correctly, assuming I cheated a bit. That failing test case we identified? Never happened. What I got instead was two really long lists of characters for `xs` and `ys`, long enough that the actual problem was hidden in the noise and the report essentially useless. We'll need to do something about that.
