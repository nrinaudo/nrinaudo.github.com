---
title:  Controlling the size of inputs
layout: article
series: kantan_tests
code:   https://github.com/nrinaudo/kantan.tests/blob/main/src/main/scala/Size.scala
date:   20260205
---

We ran into one of the main issues with generative testing in the previous article: random data tends to be very large and hard to work with. We saw this while running a [test](./logs.html#fixed-list-reverse) which (incorrectly) asserted that reversing the concatenation of two lists was equivalent to concatenating the reversed lists. Here's a typical output (one in which the random generator was on my side and actually yielded smallish lists):

<a name="bad-counter-example"/>
```
list reverse: failure (0 successfull attempts)
Error: List(x, o, r, y, j, a, d, h, w, h, k, j, j, u, e, g, i, j, w, y) 
       was not equal to 
       List(h, w, h, k, j, j, u, e, g, i, j, w, y, x, o, r, y, j, a, d)
Inputs:
  - ys: List(d, a, j, y, r, o, x)
  - xs: List(y, w, j, i, g, e, u, j, j, k, h, w, h)
```

This is a valid counter example, but not, I'd argue, a good one. Can _you_ get an intuition of what we did wrong while looking a it?


We'll spend a little time figuring out how to come up with counter examples that are both valid and good.

The first, perhaps sligthly obvious idea is to control the size of random data somehow, and to prioritise smaller test cases, at least to begin with. Most PBT libraries I know do this by equiping generators with a `size` property that can be used, for example, as the maximum length of a list or depth of a tree. This property can be queried and, importantly, modified for downstream generators: it's essentially mutable state. You'll never guess how I intend to implement that.

## The `Size` capability
### An intuitive implementation

We're going to write a relatively simple capability: the ability to query and update the current size. There is absolutely nothing suprising about this:

```scala
trait Size extends SharedCapability:
  def set(s: Int): Unit
  def get: Int
```

We'll of course also need basic effectful operations. To lean in the whole "this looks imperative but isn't", we'll use magic method names:

```scala
def size(using handler: Size): Int = 
  handler.get

// Magic name to allow `size = 3` syntax.
def size_=(s: Int)(using handler: Size): Unit = 
  handler.set(s)
```

These can be used as follows at call-site, which I think is quite nice (but will readily admit might be due to many years of working with a variety of very imperative languages):
```scala
Size.size = Size.size * 2
```

We also need a basic prompt, which honestly at this point all but writes itself:

```scala
def apply[A](initialSize: Int)(body: Size ?=> A): A =
  var size = initialSize

  given Size:
    override def set(s: Int) = size = s
    override def get = size

  body
```

This was all very straightforward and intuitive, but I'm honestly not yet sure this is the right implementation. I'll present another 2 candidates I've played with, but you should feel free to skip it entirely if you're not interested: the rest of the article will assume the above implementation.

### Alternative: `State`

`Size` can be thought of as a specialization of `State[A]`, the ability to query and update a state of type `A`. Why not replace `Size` with `State[Int]` and get something more powerful in the bargain?

Something like this:
```scala
trait State[A]:
  def get: A
  def set(a: A): Unit
```

My current conclusion is that I like having a specialized capability, with clear types and combinators. I much prefer, for example, writing `Size.size = 7` than `State.set(7)`. They're equivalent, but the former makes the intent quite a bit clearer.

And if we truly wanted to express `Size` in terms of `State`, this could easily be achieved with a dedicated prompt:

```scala
def fromState[A](body: Size ?=> A)(using handler: State[Int]): A =
  given Size:
    override def set(i: Int) = handler.set(i)
    override def get = handler.get

  body
```

I find this to be quite a fun way of handling this problem, and one that gets us the best of both worlds. But I'm not sure that design decision will stand the test of time.

### Alternative: dropping `set`

Another thing I've been pondering is whether we really need `set`. None of kantan.tests uses it, not really - what I really need is the ability to change the `size` for a sub-program, but restore it once that's done (typically to reduce the size of recursive data structures the deeper you go in the recursion).

Imagine, for example, generating random trees, where a tree is a value and a possibly empty list of children:
```scala
case class Tree[A](value: A, children: List[Tree[A]])
```

A naive generator of `Tree` would look like this:
```scala
def tree[A](body: => A)(using Rand, Size): Tree[A] =
  Tree(body, Rand.listOfN(Rand.int(Size.size), tree(body)))
```

But if you try to run that, you'll get absolutely massive trees (when not outright stack overflows): with a size of, say, 100, the odds of _all_ subtrees eventually generating empty lists of children are really not very good. The recursion will never bottom out.

This is easily fixed by reducing the size whenever you go deeper in the recursion:
<a name="tree-override"/>
```scala
def tree[A](body: => A)(using Rand, Size): Tree[A] =
  Size(Size.size / 2):
    Tree(body, Rand.listOfN(Rand.int(Size.size), tree(body)))
```

This way, you're all but guaranteed to bottom out reasonably quickly.

What's keeping me from this implementation is that it takes away the ability to compose and re-use handlers the way we did with [`Rand.tracking`](./properties.html#Rand.tracking), and I've come to appreciate how useful that was. To take a concrete example, imagine we want to log something whenever the size is accessed - possibly for debugging purposes. I probably should write a bespoke capability for this, but that'd be a little overkill for a simple example so we'll just use `println` for logging.

It would be straightforward to write a bespoke handler for this:

```scala
def logging[A](body: Size ?=> A)(using Size): A =

  // We need `handler` to not be implicit here to avoid ambiguity with 
  // the input handler.
  val handler = new Size:
    override def get =
      val current = Size.size
      println(s"Current size: $current")
      current

    override def set(s: Int) =
      Size.size = s

  body(using handler)
```

There's nothing new here, we're merely _adapting_ a "proper" `Size` handler to add logging.

But now run the following in your head:
```scala
Size(100):
  Size.logging:
    tree(Rand.int)
```

The first thing that happens in [`tree`](#tree-override) is discarding the current `Size` handler for a fresh, default one - one that doesn't do any logging. The log messages we expect will never be printed, causing untold confusion and, eventually, consternation. Not ideal when debugging.


Instead, I decided to implement another prompt, one that is maybe a little awkward:
```scala
def resize[A](newSize: Int)(body: Size ?=> A)(using Size): A =
  val oldSize = Size.size
  Size.size = newSize

  val result = body

  Size.size = oldSize
  result
```

I'm not the biggest fan of the implementation of `resize`, but at least it allows us to keep composing handlers. [`tree`](#tree-override) can then be painlessly rewritten as:
```scala
def tree[A](body: => A)(using Rand, Size): Tree[A] =
  Size.resize(Size.size / 2):
    Tree(body, Rand.listOf(tree(body)))
```

## Putting `Size` to work
### Using `Size` for random data generation

Now that we have a way of keeping track of the desired size, we can start writing size-dependent generators.

The most obvious one is generating a number between 0 and the configured size, which is very straightforward:
```scala
def size(using Rand, Size): Int = 
  Rand.int(Size.size)
```

This is typically useful when generating collections, one of the main use-cases for sized generator - and, if [you'll recall](./logs.html#running-the-test), exactly what we're struggling with:

<a name="Rand.listOf"/>
```scala
def listOf[A](content: => A)(using Rand, Size): List[A] =
  Rand.listOfN(Rand.size, content)
```

Note that our generators can sometimes depend on `Size` now, which means tests might end up needing it. We'll need to update their type to reflect this, as well as our test runner to provide it.

### Controlling the size of tests

Our goal was to control the size of generated test cases, which `Size` allows us to do. All we need is to update [`runTest`](./logs.html#runTest) to use this new ability, by:
- updating the type of a test to include a dependency on `Size`.
- taking the desired size for the test as a parameter.
- providing a `Size` handler to the test.

This is actually longer to write out in English than to code:

<a name="runTest"/>
```scala
def runTest(
    body: (Assert, Log, Rand, Size) ?=> Unit,
    size: Int
): Rand.Tracked[Log.Recorded[AssertionResult]] =
  Size(size):
    Rand:
      Rand.tracking:
        Log:
          Assert:
            body
```


We _also_ want a strategy of running tests in which we prioritize small test cases, and allow them to grow until we either find a counter example or run out of attempts. For the moment, we'll use a very naive strategy of starting from the smallest possible test (size 0), and incrementing that size by a fixed value for each attempt.

We'll hard-code the maximum size to 100 to begin with. Since we've also hard-coded the maximum number of attempts to 100, we get a nice increment of 1 per attempt.

Updating [`test`](./logs.html#test) is then merely a matter of keeping track of that size and passing it to [`runTest`](#runTest):

```scala
def test(desc: String)(body: (Assert, Log, Rand, Size) ?=> Unit) =
  def loop(successCount: Int, size: Int): TestResult =
    runTest(body, size) match
      case Rand.Tracked(Log.Recorded(AssertionResult.Success, _), isGenerative) =>
        if isGenerative && successCount < 100
          then loop(successCount + 1, size + 1)
          else TestResult(desc, successCount, None)

      case Rand.Tracked(Log.Recorded(AssertionResult.Failure(msg), inputs), _) =>
        TestResult(desc, successCount, Some(FailedTestCase(msg, inputs)))

  report(loop(0, 100))
```

### Rewriting our test

Everything is now in place. We can rewrite our [failing test](./logs.html#fixed-list-reverse) to rely on [`Rand.listOf`](#Rand.listOf) rather than [`Rand.listOfN`](./generators.html#Rand.listOfN):

```scala
test("list reverse"):
  val xs = Rand
    .listOf(Rand.lowerAscii)
    .logAs("xs")
  val ys = Rand
    .listOf(Rand.lowerAscii)
    .logAs("ys")

  val lhs = (xs ++ ys).reverse
  val rhs = xs.reverse ++ ys.reverse

  assert(lhs == rhs, s"$lhs was not equal to $rhs")
```

Remember that [`Rand.listOf`](#Rand.listOf) will respect the configured size, so we'll start from very small lists and, hopefully, find a much smaller counter example than we [initially did](#bad-counter-example).

I promise I didn't rerun the test multiple times or fudge with the RNG, this is genuinely the first thing our library found:

```
list reverse: failure (3 successfull attempts)
Error: List(k, u) was not equal to List(u, k)
Inputs:
  - ys: List(k)
  - xs: List(u)
```

These are the _smallest possible_ lists on which the test might fail. Controlling the size works spectacularly well, at least in scenarios such as this one where the test is easy to falsify. 

## Conclusion

We've seen how to control the size of generated test cases to increase our odds at finding _good_ counter examples rather than merely _valid_ ones. It involved a new capability, `Size`, the design space of which we explored. The rest was merely updating existing code to rely on `Size`, and the results were as good as we could hope.

Our next task will be to look at scenarios in which `Size` is not quite good enough, and how to improve things in such cases.
