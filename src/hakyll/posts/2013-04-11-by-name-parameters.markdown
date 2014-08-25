---
title: By-name parameters
tags: scala
---
_By-name parameters_, or _pass by name_, is a parameter evaluation strategy, just like _pass by value_ or
_pass by address_, that allows for lazy evaluation of a function's parameters - with a somewhat tricky twist.



<!--more-->



## Motivation

Lazy evaluation is a simple concept: an expression's value is not computed until it's actually needed. There are many
applications to this, but I'll just take a simple example and run with it here: conditional execution.

Take the `or` function, implemented as follows:
```scala
def or(a: Boolean, b: Boolean) =
  if(a) a
  else  b
```

You can see that if `a = true`, `b`'s value is ignored - evaluating it is a waste of CPU cycles. It doesn't look like a
big deal, but let's look at the following code:
```scala
// Checking whether the user is logged is cheap and can be done instantly.
def isUserLogged(name: String) = true

// Checking whether a user is valid requires database queries and is expensive, sleep 10s.
def isUserValid(name: String, password: String)  = {
  Thread.sleep(10000)
  true
}

// Accepts a user if it's either already logged or valid.
def acceptUser(name: String, password: String) =
  or(isUserLogged(name), isUserValid(name, password))

// This takes 10 seconds to run.
println(acceptUser("j.smith", "poney"))
```

The `acceptUser` function takes a user's name and password and evaluates to `true` if the corresponding user is either
already logged in or valid.

In the current implementation, both `isUserLogged` and `isUserValid` will be evaluated, which is a shame: `isUserValid`
is expensive (a whole 10 seconds!) and not necessary at all since `isUserLogged` will evaluate to `true`.

Lazy evaluation would allow us to bypass `isUserValid` entirely and return `true` immediately.



## Naive implementation: higher-order functions

Scala unfortunately does not ([yet](https://issues.scala-lang.org/browse/SI-240)) support lazy parameter evaluation,
which means that we have to hack something together with the tools at our disposal - and in Scala, that's often
function composition.

We want the `b` parameter of our `or` function to only be evaluated if `a` is `false` - the simplest way of doing
that is rewriting `or` so that `b` is a function that evaluates to a `Boolean`:
```scala
def or(a: Boolean, b: () => Boolean): Boolean =
  if(a) a
  else  b()
```

Note how `b` is now of type `() => Boolean` rather than simply `Boolean`.

We could modify `a` the same way, but that would serve little practical purpose: it will always be evaluated and we
gain nothing by delaying the inevitable.

Now that `or`'s signature has changed, we need to modify `acceptUser` accordingly:
```scala
def acceptUser(name: String, password: String) =
  or(isUserLogged(name), () => isUserValid(name, password))
```

Running our code, it behaves as expected: `isUserValid` is not called and `acceptUser` evaluated instantly.



## Better implementation: by-name parameters

While we achieved exactly what we set out to do, the result is still somewhat unsatisfactory: the `() =>` bits that
we had to add to our code make it harder to read and do not bring anything to our understanding of what it actually
does - they're boilerplate.

One of the things to enjoy about Scala is its absolute hatred for boilerplate, and this case is no exception: we
can use _by-name parameters_ to simplify our code without loosing functionality.

A by-name parameter is a special syntax that tells the compiler that the parameter should be wrapped in a 0-arg
function:
```scala
def or(a: Boolean, b: => Boolean): Boolean =
  if(a) a
  else  b
```
`b` is now declared with the special `: => Boolean` type, and is treated as a variable rather than a function in the
rest of the code.

We need to change our `acceptUser` function back:
```scala
def acceptUser(name: String, password: String) =
  or(isUserLogged(name), isUserValid(name, password))
```

This code is, in my opinion, much clearer and easy to understand: `acceptUser` declares what it does without a need
for specific syntax, and the body of `or` is trivial.

Running it yields the expected behaviour: `isUserValid` is not called and `acceptUser` evaluated instantly.



## Pitfall: not actually a lazy parameter

The tricky bit with by-name parameters is that they're not actually lazy, but a function that is evaluated _each time_
the value of the parameter is needed.

Let's change our `or` method code to add logging:
```scala
def or(a: Boolean, b: => Boolean): Boolean =
  if(a) a
  else  {
    println("a evaluated to false, b is " + b)
    b
  }
```

Whenever `a` evaluates to `false`, `b` will be evaluated _twice_. To convince ourselves, let's run the following code:
```scala
def verboseB = {
  println("evaluating b")
  true
}

or(false, verboseB)
```

And this will indeed print `evaluating b` twice.

Should this be an issue however, it can be worked around fairly easily by modifying the code as follows:
```scala
def or(a: Boolean, b: => Boolean): Boolean = {
  lazy val actualB = b
  if(a) a
  else  {
    println("a evaluated to false, b is " + actualB)
    actualB
  }
}
```

* `b` is a function that evaluates to a `Boolean`.
* `actualB` is a lazy variable that will evaluate `b` once and return the same value on any subsequent call.

Note that while the workaround exists, it's not terribly elegant and requires a fair amount of boilerplate code. Lazy
parameters would be a preferable solution, if and when they are implemented.
