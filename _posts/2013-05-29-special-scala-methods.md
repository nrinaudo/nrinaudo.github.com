---
title: Special Scala methods
tags: scala
---

Scala has a number of methods for which it defines special syntactic sugar. Some are well known, such as `apply` or
`update`, but the interraction of `+` and `+=` is somewhat less famous. This post details the special methods I know
about.

<!--more-->
## Apply

The `apply` method is special in that it allows instances of classes that have it to be treated as functions and
applied directly.

For example:

```scala
object ApplyDemo {
  def apply(a: Int, b: String) = b * a
}

// The following calls are strictly equivalent:
ApplyDemo.apply(5, "ha")
ApplyDemo(5, "ha")
```

This is typically used with [functions](http://www.scala-lang.org/api/current/#scala.Function1), where the name probably
originated from: you apply a function to its parameter list and get a result.

Another use is for data structures, such as
[lists](http://www.scala-lang.org/api/current/#scala.collection.List) (retrieve element at index `i`) or
[maps](http://www.scala-lang.org/api/current/#scala.collection.Map) (retrieve value for key `k`).

While really rather nice, the `apply` method can sometimes have unexpected side-effects if one is not careful, as in the
(somewhat contrived) following example:

```scala
object ApplyDemo2 {
  def list: List[Int] = List(1, 2, 3)
  def list(index: Int): Int = index * 4
}
```

The following line is ambiguous and will be refused by the compiler. Are we calling:

* apply(index: Int) on an instance of List?
* list(index: Int) on object ApplyDemo2?

```scala
ApplyDemo2.list(1)
```


## Update

The `update` method, when it has exactly two parameters, can be written in "array modification" notation:

```scala
object UpdateDemo {
  def update(i: Int, v: String): String = v
}
```

The following calls are strictly equivalent:

```scala
scala> UpdateDemo.update(0, "poney")
res4: String = poney

scala> UpdateDemo(0) = "poney"
res5: String = poney
```

This is convenient when creating data structures, especially when coupled with `apply`, as it allows you to write very
natural-looking code. This is what the [Map](http://www.scala-lang.org/api/current/#scala.collection.Map) class does,
for example.


### Return value

The return value of `update` can be whatever you wish, but there's not very many acceptable choices:

* `this` (for fluent coding)
* the second parameter's value (to be coherent with `=`)
* `Unit`

I don't believe there's a general rule there but most of the code I've seen uses the third alternative (`Unit`), and I
find that this is what makes the most sense.


### Update and set

Scala has special handling for the `+=`, `-=`, `*=` and `/=` operators: when used on a variable (a `var`, not a `val`)
that doesn't define it explicitely but does define the corresponding operator (`+`, `-`, `*`, `/`), they will be
replaced by a call to the corresponding operator followed by an affectation to the variable.

For example, with `+=`:

```scala
case class PlusEq(var value: Int = 0) {
  def +(inc: Int): PlusEq = PlusEq(value + inc)
}

var p = PlusEq()
```

The following calls are equivalent, except in their return values (`+=` returns `Unit`):

```scala
scala> p += 10

scala> p = p.+(10)
p: PlusEq = PlusEq(20)
```


## Unary operators

Scala has special support for the `+`, `-`, `!` and `~` unary operators, allowing developers to write code such as
`-v + !c`.

Implementing one of these operators is done by defining the correspoding `unary_` method: `unary_+`, `unary_-`,
`unary_!` and `unary_~`.

For example:

```scala
object UnaryDemo {
  def unary_+ = 4
  def unary_- = -4
  def unary_! = false
  def unary_~ = "~"
}
```

This allows us to write:

```scala
scala> +UnaryDemo
res7: Int = 4

scala> -UnaryDemo
res8: Int = -4

scala> !UnaryDemo
res9: Boolean = false

scala> ~UnaryDemo
res10: String = ~
```



## Field wrappers

Finally, Scala allows you to write methods that wrap, or simulate, an existing field:

```scala
object FieldDemo {
  private var _x = 0

  def x = _x
  def x_=(i: Int) = _x = i
}
```

FieldDemo can now be used as:

```scala
scala> FieldDemo.x = 10
FieldDemo.x: Int = 10

scala> FieldDemo.x
res11: Int = 10
```

This can be useful in classes that used to expose a mutable field but that, for one reason or another, had to add logic
when it was being modified.

Say, for example, that you start off with:

```scala
object FieldDemo {
  var x = 0
}
```

It has later become crucial to log something whenever `x` is modified. `x_=` allows us to do so without changing
`FieldDemo`'s interface:

```scala
object FieldDemo {
  private var _x = 0

  def x = _x
  def x_=(i: Int) = {
    println("x is set to " + i)
    _x = i
  }
}
```

Code that used the older version of `FieldDemo` will still compile against this one, even though under the hood, a method
is being called rather than a field being set.
