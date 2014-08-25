---
title: Overridable methods in constructors
tags: java
---
Calling an overridable method in a constructor is, or should be, widely known to be a bug in waiting. It's also a pattern
that is found much too often in production code. The purpose of this post is to explain *why* it's such a bad idea.

<!--more-->

The root of the problem lies in the fact that a class' parent's constructor is always called before its own constructor
is called, whether explicitly or implicitly.

That is, if class `A` extends class `B`, `A`'s constructor will *always* be called before `B`'s.

As a concrete example, the following class looks very simple and harmless:
``` java
public class Parent {
    public Parent() {
        demonstrate();
    }

    public void demonstrate() {
        // Left for sub-classes to override.
    }
}
```

The following subclass of `Parent`, however, behaves in a way that will take many by surprise, especially if they do
not have access to `Parent`'s sources code:
``` java
public class Child extends Parent {
    // Both private and final: most sane people will assume its value cannot change.
    private final String field;

    // The first thing we do is set "field"'s value.
    public Child(String value) {
        field = value;
    }

    public void demonstrate() {
        field.toLowerCase(); // or any code that access field.
    }

    @Override
    public String toString() {
        return field;
    }

    public static void main(String... args) {
        // You'd expect this to result in "Hello, World!" being printed to stdout.
        new Child("Hello, World!");
    }
}
```

Compiling and executing `Child` *should* print `Hello, World!`, but results in a `NullPointerException` instead.

It's fairly logical once it's been pointed out:

* `Parent`'s constructor is called before `Child`'s.
* since `Parent`'s constructor calls `demonstrate()`, this will happen before `Child`'s constructor executes.
* `demonstrate()` access `field`, which cannot possibly have a value yet as it's set in `Child`'s constructor.

While obvious once pointed out, this is exactly the kind of bug that can prove time consuming to fix: a
`private final` value that is always set to a non-`null` value cannot possibly be `null`, can it?
