---
layout: post
title: "Always use the tailrec annotation"
date: 2013-11-05 14:29
comments: true
categories: best-practice scala
---
Deaf future self,

I’ve been asked a few times why I try to systematically use the `@scala.annotation.tailrec` annotation - surely I’m smart
enough to know when my code is tail-recursive?

<!-- more -->

The simple answer is that you cannot always know or remember all the reasons why the compiler might refuse to optimise
your code for tail-recursion - or at least realise that your code exhibits such symptoms.

A simple example I discovered recently is overridable methods. The following code shows a method that looks fairly
tail-recursive (even if singularly useless) at a glance, but really isn’t:

```scala
class Demo {
  def countDown(i: Int): Int =
    if(i == 0) 0
    else       countDown(i - 1)
}

// Causes a StackOverflowError
new Demo().countDown(Int.MaxValue)
```

Adding the `@scala.annotation.tailrec` annotation allows the compiler to warn me of the issue before my code blows up in
production: `error: could not optimize @tailrec annotated method countDown: it is neither private nor final so can be
overridden.`

It also provides enough of a hint to work out an acceptable solution:
```scala
class Demo {
  def countDown(i: Int): Int = {
    @scala.annotation.tailrec
    def run(i: Int): Int =
      if(i == 0) 0
      else       run(i - 1)
    run(i)
  }
}

// Runs all the way to the end.
new Demo().countDown(Int.MaxValue)
```

Having the recursive code in a nested function ensures that it cannot be overridden, which allows the compiler to
optimise it for tail-recursion. `countDown` is now safe to call, but I’d never even realised there was a potential issue
without the `tailrec` annotation.
