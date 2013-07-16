---
layout: post
title: "Timer Actor"
date: 2013-06-10 11:49
comments: true
categories: scala actor
---
Dear future self,

While attempting to work with [Scala Actors](http://www.scala-lang.org/api/current/index.html#scala.actors.Actor), I
discovered that there wasn't a simple timer implementation (or at least that I could not find it).

After tinkering a bit, this is what I came up with.
<!-- more -->

```scala
import scala.actors._
import scala.actors.Actor._
import scala.actors.scheduler.DaemonScheduler

// Simple timer that will send Timer.WakeUp to the target actor every timeout milliseconds.
class Timer(val timeout: Long, val dest: Actor) extends Actor {
  import Timer.WakeUp

  // Might as well make it into a daemon. This probably doesn't serve much of a purpose: this implementation is
  // configured to die as soon as its target dies anyway.
  override def scheduler = DaemonScheduler

  def act {
    // Configures the timer to die as soon as its destination does.
    link(dest)

    // Somewhat arbitrary: I want the destination actor to be notified as soon as the timer is scheduled.
    // A more flexible version would accept both a period and a delay before starting.
    dest ! WakeUp

    // Note that it's crucial not to listen to any other message here: each handled message will reset the timer and
    // break the periodicity.
    loop {
      reactWithin(timeout) {
        case TIMEOUT => dest ! WakeUp
      }
    }
  }
}

object Timer {
  // Message sent to target actors to wake them up.
  val WakeUp = 'WakeUp

  // Convenience method to create and start a timer in a single call.
  def apply(timeout: Long, dest: Actor) = new Timer(timeout, dest).start
}


// Test code: starts an actor and prints the number of milliseconds since it's been started every time it's woken up.
Timer(1000, actor {
  val time = System.currentTimeMillis
  loop {
    react {
      case Timer.WakeUp => println("Woken up at %d".format(System.currentTimeMillis - time))
    }
  }
})
```
