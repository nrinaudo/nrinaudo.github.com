---
---

# kantan.csv

[kantan.csv](https://nrinaudo.github.io/kantan.csv/) is a CSV library meant to help with extracting useful values from
CSV data.

This is probably the most popular of all my libraries, and is also the one I use and maintain the most.

# kantan.xpath

[kantan.xpath](https://nrinaudo.github.io/kantan.xpath/) is a library designed to let developers get useful types
out of XPath queries.

This was initially created because I needed to do some scraping and grew frustrated with how inadequate Scala tools
available at the time were.

# kantan.regex

[kantan.regex](https://nrinaudo.github.io/kantan.regex/) is regular expression library whose sole purpose is to turn
matches into useful values.

This is actually a side-effect of [kantan.xpath](https://nrinaudo.github.io/kantan.xpath/): too often, scraping involves
evaluating regular expressions against the content of XML nodes, and [kantan.xpath](https://nrinaudo.github.io/kantan.xpath/)
only did half the job.

# kantan.codecs

[kantan.codecs](https://nrinaudo.github.io/kantan.codecs/) is the core of all other kantan projects - that's where all
the logic for encoding and decoding is.

Other kantan libraries essentially depend on that, declare specialised versions of the decoding typeclasses and inherit
external libraries support.
