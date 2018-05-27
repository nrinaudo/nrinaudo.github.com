---
title: Default values in Bash Scripting
tags: bash
---
I regularly have to write small bash scripts to wrap around the various tools I create and need to run in batches. Bash
scripting is an absolute nightmare to me - I find the syntax makes very little sense, and the fact that the presence
or absence of whitespace around operators changes their meaning just seems unholy.

The most common issue I have is defining default values for command line arguments that were not specified.


<!--more-->

I don't pretend to understand precisely how or why this works, nor, to be honest, do I really want to, but this is how
you do it:

```bash
#! /bin/bash
HOST=$1
: ${HOST:="localhost"}
echo $HOST
```

Executing the scripts then yields:

```bash
nicolasrinaudo:~/scripts ./script.sh 212.128.0.1
212.128.0.1
nicolasrinaudo:~/scripts ./script.sh
localhost
```
