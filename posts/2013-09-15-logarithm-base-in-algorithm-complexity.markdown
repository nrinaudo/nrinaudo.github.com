---
title: Logarithm base in algorithm complexity
---
I was reading up on algorithm complexity and found the following statement: within the context of algorithm complexity,
the base of a logarithm is irrelevant.

This was not demonstrated in any way and the reader was obviously expected to accept this as obvious - which is the
case, unless your maths are as rusty as mine.

<!--more-->



## Constants in algorithm complexity

The first step to enlightenment is to remember that constants are considered irrelevant when expressing an algorithm's
complexity: $O(2N)$ is always written $O(N)$.

With that in mind, we "only" need to prove that logarithms with different bases are linked together by a constant:

$\forall i,j \, \exists c_{ij} \mid \forall x \, log_i(x) = c_{ij} * log_j(x)$



## Linking two logarithms with different bases

In order to find this $c_{ij}$ constant, let's start from the definition of a logarithm:

$y = log_i(x) \Leftrightarrow x = i^y \Leftrightarrow log_j(x) = log_j(i^y) \Leftrightarrow log_j(x) = y * log_j(i)$

Replacing $y$ by its actual value, we get:
$$log_j(x) = log_i(x) * log_j(i)$$

Which allows us to state what we set out to prove:
$$\forall i,j,x \, log_j(x) = log_j(i) * log_j(x)$$

That is, since there always exists a known constant that links two logarithms in different bases, and constants should
be ignored when expressing an algorithm's complexity, then the base of a logarithm is irrelevant within the context of
algorithm complexity.
