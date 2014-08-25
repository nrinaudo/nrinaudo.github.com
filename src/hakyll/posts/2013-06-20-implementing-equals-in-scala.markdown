---
title: Implementing equals in Scala
tags: scala
---
Writing proper `equals` methods in Java is
[a bit of a pain](http://stackoverflow.com/questions/27581/overriding-equals-and-hashcode-in-java). Turns out, Scala
is slightly better but still somewhat cumbersome. It's mostly a matter of remembering all the rules.

<!--more-->

## Basic implementation
Pattern matching makes a basic implementation of `equals` rather easy to read and write:
```scala
class Point2d(val x: Int, val y: Int) {
  override def equals(other: Any) = other match {
    // Any instance of Point2d with the same x and y as the current instance is equal to it.
    case o: Point2d => o.x == x && o.y == y
    // Anything else isn't.
    case _          => false
  }
}
```

## hashCode
Exactly as in Java, overriding `equals` should always be accompanied by an equivalent implementation of `hashCode`.

Nothing tricky there, although the convention is slightly different than in Java: Scala uses the 41 magic number where
Java uses 31.
```scala
class Point2d(val x: Int, val y: Int) {
  override def hashCode() = 41 * (41 + x) + y

  override def equals(other: Any) = other match {
    case o: Point2d => o.x == x && o.y == y
    case _          => false
  }
}
```

## canEqual
This is where Scala becomes more cumbersome (yet more powerful) than Java.

A proper `equals` method should be reflexive, which means that `x == y` implies that `y == x`. Common Java wisdom has
it that to enforce this, instances of a subclass cannot be equal to instances of their parent class.

Say, for example, that we created a `Point3d` class with a `z` coordinate. Instances of `Point3d` cannot be equal to
instances of `Point2d`, which means that instances of `Point2d` cannot be equal to instances of `Point3d`.

This restriction can be a bit too strict: sometimes, a class subclasses another without changing the meaning of
instance equality. In order to deal with this cases, Scala uses the `Equals` trait:
```scala
class Point2d(val x: Int, val y: Int) extends Equals {
  override def hashCode() = 41 * (41 + x) + y

  // Anything that is an instance of `Point2d` can be equal to it.
  def canEqual(that: Any) = that.isInstanceOf[Point2d]

  override def equals(other: Any) = other match {
    // Note the call to canEqual which makes sure that other is ok to be compared with this.
    // In our example, other would be an instance of Point3d and would refuse the comparison.
    case o: Point2d => (o canEqual this) && o.x == x && o.y == y
    case _          => false
  }
}

class CustomPoint(x: Int, y: Int) extends Point2d(x, y) {
  // custom code.
}

// CustomPoint doesn't override canEqual, which means that it's perfectly possible for an instance of Point2d and
// CustomPoint to be equal. And Indeed:

// Prints true
println(new Point2d(1, 2) == new CustomPoint(1, 2))
// Prints true
println(new CustomPoint(1, 2) == new Point2d(1, 2))


// Point3d adds a new field, which makes it impossible for an instance of Point2d and Point3d to be equal.
class Point3d(x: Int, y: Int, val z: Int) extends Point2d(x, y) {
  override def hashCode() = 41 * (41 + super.hashCode) + z

  // This will cause the equals method of Point2d to return false.
  override def canEqual(that: Any) = that.isInstanceOf[Point3d]

  override def equals(other: Any) = other match {
    case o:Point3d => (o canEqual this) && z == o.z && super.equals(o)
    case _         => false
  }
}

// Point3d overrides canEqual, which makes it impossible for it to be equal to instances of Point2d. And indeed:

// Prints false
println(new Point2d(1, 2) == new Point3d(1, 2, 3))
// Prints false
println(new Point3d(1, 2, 3) == new Point2d(1, 2))
```

## Miscellaneous
There are a few other things to keep in mind when implementing `equals`. I won't dwell on them though, they're exactly
the same as in Java:

* avoid using mutable fields in `equals` and `hashCode`.
* if `a == b`, then `a.hashCode == b.hashCode` (but the opposite doesn't need to, and often cannot, be true).
