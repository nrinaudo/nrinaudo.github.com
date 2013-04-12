---
layout: post
title: "Overridable methods in constructors"
date: 2013-04-05 16:06
comments: true
categories: java best-practice
---
Dear future self,

A code quality issue that you seem to be particularly prone to is [calling an overridable method within a constructor](http://pmd.sourceforge.net/pmd-4.3.0/rules/design.html#ConstructorCallsOverridableMethod). Whenever one of your various code quality metrics tools spits out a warning about this practice, you get a bit annoyed and need to be convinced it's a bad idea all over again. Come read this next time, it'll be quicker.

<!-- more -->

Overridable methods in a constructor are a bad idea because of a very simple fact: a class' parent's constructor is always called before the class' constructor is executed. When not called explicitely, the compiler will add an implicit call to the parent's default constructor.

Most Java developers understand that, and I know *you* do, but a fair amount of us still get caught unawares by the implications.

Let's take a concrete example. The following class looks very simple and harmless:
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

However, it turns out to be a nasty trap, sprung by the following code:
``` java
public class Child extends Parent {
    // Both private and final: most sane people will assume its value cannot change.
    private final String field;

    // The first thing we do is set "field"'s value.
    public Child(String value) {
        field = value;
    }

    public void demonstrate() {
        System.out.println(field);
    }

    public static void main(String... args) {
        // You'd expect this to result in "Hello, World!" being printed to stdout.
        new Child("Hello, World!");
    }
}
```

This is fairly straightforward, but the result isn't what one would expect: it prints `null` to stdout rather than `Hello, World!`.

If you think about it, that's actually logical: `Parent`'s constructor is called before `Child`'s is, which means that `demonstrate()` is called before `field`'s value is set.

It's only obvious because we have access to `Parent`'s source code and we know what to look for, however. One of the symptoms is that an immutable field has a different value from the one we clearly assigned it - I know I'd be tempted to blame the compiler, since this is clearly impossible.
