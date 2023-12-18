---
title: Conclusion
layout: article
series: free_monad
date:   20231128
---

Through this article, we have justified my friend's statement that _`Free` is merely the defunctionalisation of `Monad` in its most uncomfortable configuration_:
- it's a defunctionalisation of `Monad`, since it turns monadic functions into data (the `Flatten` and `Pure` constructors).
- it's specifically the most uncomfortable `Monad` configuration, the one defined through `flatten` and `pure` with a constraint on being a functor.

That told us _what_ `Free` is, but we've also seen _why_ we'd want to use it: `Free` allows you to take simple DSLs and compose them comfortably, provided you butcher their ideal implementation a bit by adding continuations.

You'll notice that these two things have rather important caveats: it's the _least comfortable_ version of `Monad`, and we have to _butcher things a bit_ to make it work. This should be a pretty good hint that we've not quite found our ideal solution.

The intuition for a better solution is: maybe these two problems are symptoms of the same underlying issue. Maybe if we fixed the `Functor` constraint, everything would fall pleasantly in place. And since we have created the free monad over a functor, maybe we should consider whether we can come up with the free monad over any type constructor?

One way of achieving that is to realise that if we had the free functor over a type constructor, we could then combine it with the free monad over a functor and get the free monad ofer a type constructor. And the free functor over a type constructor exists, the extremely intuitively named `Coyoneda`. So, mixing `Free` and `Coyoneda` and working from there should lead us to our solution - but it's very hard work. I _think_ it'll work, and have been told so by people who definitely know what they're talking about, but I didn't do it myself. I try to avoid hard work when I can get away with it.

The lazy solution is to realise that it might not be a coincidence that we've invented the free monad over _a functor_ by defunctionalising a configuration of `Monad` that had a `Functor` requirement. Maybe if we drop the `Functor` requirement in the latter, it would also drop from the former? Maybe if we defunctionalised the other `Monad` configuration, via `flatMap` and `pure`, we'd get the free monad over a type constructor?

Following through on that intuition will lead us, rather easily, to a construct called `Freer` - the free monad over a type constructor. Which, anecdotally, looks very much like what Typelevel implements in _cats_ (and called `Free`, presumably for a laugh) - probably a good sign that it's worth studying next!
