---
title:  Tests as assertions
layout: article
series: kantan_tests
code:   https://github.com/nrinaudo/kantan.tests/blob/main/src/main/scala/Assert.scala
date:   20260112
---

We previously defined tests as values of type `Rand ?-> Boolean`. This bothers me a little, because when you write tests that check more than one thing - and I often do - it forces you to combine results in a way that is often quite awkward.

For example, a test I've actually written in the past was to check that some web service would reject attempted creation of underage users with the right HTTP response - because, yes, a lot of modern IT apparently is about making HTTP requests, and what fun _that_ is.

Writing this test with our current tools would look like this:

```scala
test("creation rejects underage users"):
  val name = Rand.oneOf("George", "Françoise", "Kintaro")
  val age  = Rand.int(18)
  
  val result = createUser(name, age)
  
  result.httpCode == 400 &&
  result.contentType == "application/json" &&
  result.body.as[ErrorResponse].isRight
```

Given a random name, and an age between 0 and 18, I'd check the HTTP code, the `Content-Type` header and response entity body. Acceptable, but a bit of a letdown because of the limitations of using booleans:
- when the test fails, and it will, it doesn't tell you which of the 3 conditions wasn't respected.
- the 3 checks must be chained using `&&`, which I find a little uncomfortable.

## A better result type

It's fairly easy to define a better type than `Boolean` for the result of a property, and every tool I know does it: you simply need the failure case to contain an error message, plus whatever else you feel might be helpful:

```scala
enum Result:
  case Success
  case Failure(msg: String)
```

We mustn't forget results need to be combined - our example only uses `&&`, so that's what we'll implement, but we could easily support others.

`&&`, then, is a method on `Result` which yields a failure if either operand is a failure, or combines the two if they're both successes:
```scala
def &&(rhs: Result) =
  (this, rhs) match
    case (failure: Result.Failure, _) => failure
    case (_, failure: Result.Failure) => failure
    case _                            => Result.Success
```

Updating the type of a test from `Rand ?-> Boolean` to `Rand ?-> Result` gives us the information we need to write useful reports. But it's a little awkward to write tests using `Result`, isn't it? For example, the first of our three conditions:

```scala
if result.httpCode == 400 
   then Result.Success
   else Result.Failure(s"Unexpected HTTP code: ${result.httpCode}")
```

That `if / then / else` statement is really quite verbose, and we should write a helper function for it - there's a traditional name for such a helper: `assert`.

```scala
def assert(cond: Boolean, msg: String) =
  if cond
     then Result.Success
     else Result.Failure(msg)
```

We can now rewrite our entire test using assertions and clear error messages:

```scala
test("creation rejects underage users"):
  val name = Rand.oneOf("George", "Françoise", "Kintaro")
  val age  = Rand.int(18)
  
  val result = createUser(name, age)
  
  assert(
    result.httpCode == 400,
    s"Unexpected HTTP code: ${result.httpCode}"
  ) &&
  assert(
    result.contentType == "application/json",
    s"Unexpected Content-Type: ${result.contentType}"
  ) &&
  assert(
    result.body.as[ErrorResponse].isRight,
    "Failed to decode body"
  )
```

And while I'd argue this is clearly an improvement, it's still not great. Having to chain assertions this way isn't the most readable, and makes it a little uncomfortable to have intermediate steps - I could, for example, want to store the result of attempting to decode the response entity body, maybe to extract potential error messages. This would be a lot easier if assertions didn't need to be combined, but worked in a similar fashion to the one common in more imperative test frameworks: an assertion success is ignored, a failure short-circuits the test.

## Short-circuiting tests
### Assertion results

The first thing we'll do is get rid of `&&`, since we're not going to be combining assertions anymore.

We'll take the opportunity to rename our type to `AssertionResult`: `Result` is a very common, generic name, and I want to remove potential ambiguities:

```scala
enum AssertionResult:
  case Success
  case Failure(msg: String)
```

### Assertion-specific breaks

What we want to do is give test authors the ability to short-circuit tests - to say something like _abort here if a condition isn't met_. This is a topic I've covered extensively in [another article](../capabilities_flow.html), which you might want to read first if you prefer a slow buildup to the solution. 

The first thing we need is the "abort here" capability, which I'll call `Assert`:
```scala
import caps.*

sealed abstract class Assert extends SharedCapability
```

We'll use this as the `label` part of a `goto / label` construct: when given an `Assert`, you gain the ability to abort your computation and jump to wherever the `Assert` was created. It exposes no operation, because as we'll soon see we only need to be able to compare it to other `Assert`s, and this is built-in on the JVM.

We then need a way to jump out of a block of code, which, this being the JVM, is going to be an unchecked `Exception`. It needs to store an error message, as well as the label we're jumping to:

```scala
private case class AssertionFailure(label: Assert^{}, message: String) 
  extends Exception
```

The surprising capture set on `label: Assert^{}` is used to empty its default one of `{cap}`. It's a little technical, but `AssertionFailure` is an `Exception`, and these are (at the time of writing) [treated as non-capturing by the compiler](https://users.scala-lang.org/t/boundary-break-and-capture-checking/12036). Since `AssertionFailure` is non-capturing, it cannot hold any tracked value, and we must flag `label` as non-tracked for this to work. Which means `label` must have an empty capture set: `Assert^{}`.

Writing a `fail` operation then becomes relatively trivial: given an `Assert`, we merely throw an `AssertionFailure` storing it.

```scala
import scala.caps.unsafe.unsafeAssumePure

def fail(msg: String): Assert ?-> Nothing =
  handler ?=> throw AssertionFailure(handler.unsafeAssumePure, msg)
```

We're forced to perform a little black magic here with `unsafeAssumePure`. This is linked to the `Assert^{}` thing we talked about ealier: we must pass a non-capturing `Label` to `AssertionFailure`'s constructor, but all `Label`s are tracked by virtue of being subtypes of `SharedCapability`. This forces us to tell the compiler it's ok to stop tracking `handler` here. I looked for a cleaner solution, but... well, that's the one used by the Scala standard library, so I guess it's at least an acceptable one.

We have all the moving piece, and must now tie them together with a _prompt_. The general idea is very simple: since we know failure is denoted by an `AssertionFailure` wrapping whatever handler was used, we simply need to evaluate our effectful computation within a `try` block and catch all `AssertionFailure`s with the right label. If one is caught, we'll return a failure, otherwise a success.

The following implementation refines this a little by also catching non-`AssertionFailure` exceptions and treating them as failures. This is, to me, the right behaviour when running tests: unexpected exceptions should be treated as test failures, not crash out of the test suite.

```scala
object Assert:
  def apply(body: Assert ?=> Unit): AssertionResult =
    given label: Assert = new Assert {}
  
    try
      body
      AssertionResult.Success
    catch
      case AssertionFailure(`label`, msg) => AssertionResult.Failure(msg)
      case e: AssertionFailure            => throw e
      case e                              => AssertionResult.Failure(e.getMessage)
```

You'll also notice the decision to give effectul computations the type `Assert ?=> Unit`. We don't _need_ a return value, since it'll be ignored and replaced with an `AssertionResult`. I could have made this `Assert ?=> Any` or something similar, but I've been bitten by such things in the past, where I thought some block was expected to return `false` to signify failure and couldn't understand why that didn't work. I now prefer to rely on the compiler's ability to complain about discarded values to let users know they're not doing what they think they're doing.

We've now laid all the necessary groundwork for a very small, very simple `assert` implementation, which simply fails if its condition isn't met:

```scala
def assert(condition: Boolean, msg: String): Assert ?-> Unit =
  if condition
    then ()
    else fail(msg)
```

We could write a collection of such functions, and I probably should at some point in the actual library, but `fail` and `assert` are enough for our current purposes: rewriting our initial test in a way that is, to my eyes, more fluid and pleasant to read:

```scala
test("creation rejects underage users"):
  val name = Rand.oneOf("George", "Françoise", "Kintaro")
  val age  = Rand.int(18)
  
  val result = createUser(name, age)
  
  assert(
    result.httpCode == 400,
    s"Unexpected HTTP code: ${result.httpCode}"
  )
  
  assert(
    result.contentType == "application/json",
    s"Unexpected Content-Type: ${result.contentType}"
  )
  
  result.body.as[ErrorResponse] match
    case _: Right => ()
    case Left(error)_ => fail(s"Failed to decode body with $error")
```

I will readily admit that this is possibly a matter of taste more than facts. For all I love property based tests, I've merely used them for a few years to my literal decades of more imperative tests. This reads more like, I don't know, JUnit then it does QuickCheck, but that's the way I like it.

## Adapting the test runner

Our last task is to adapt the test runner: tests used to be of type `Rand ?-> Boolean`, and are now `(Assert, Rand) ?-> AssertionResult`, and this needs to be taken into account.

The first thing we need to do is update `runTest`, the function that, given a test, runs it. This is easy enough, all we have to do is execute the test within an `Assert` prompt:

```scala
def runTest(body: (Assert, Rand) ?=> AssertionResult): Rand.Tracked[AssertionResult] =
  Rand:
    Rand.tracking:
      Assert:
        body
```

We'll then want to write a function to report the results of a test which, for the moment, are represented as an `AssertionResult`:
```scala
def report(desc: String, result: AssertionResult) = 
  result match
    case AssertionResult.Success =>
      println(s"$desc: success")

    case AssertionResult.Failure(msg) =>
      println(s"$desc: failure")
      println(s"Error: $msg")
```

Our final task is `test`, which is also easy enough to update: it's really just a matter of following the type errors and replacing booleans with `AssertionResult`:

```scala
def test(desc: String)(body: (Assert, Rand) ?=> AssertionResult) =
  def loop(successCount: Int): AssertionResult =
    runTest(body) match
      case Rand.Tracked(AssertionResult.Success, isGenerative) =>
        if isGenerative && successCount < 100
          then loop(successCount + 1)
          else AssertionResult.Success

      case Rand.Tracked(failure, _) => failure

  report(desc, loop(100))
```


## Conclusion

We now have a somewhat barebone but workable test library: we can write tests (generative or not), run them, and have a comfortable assertion DSL.

And while our test reports are not a lot more useful than they used to be, they're not _great_ for generative tests: we have no idea what random input caused the failure! This is going to be our next step.
