---
layout: post
title: "Default values in Bash Scripting"
date: 2013-06-04 09:47
comments: true
categories: bash
---
Dear futur self,

I regularly have to write small bash scripts to wrap the various tools I create and have to run in batches. Bash
scripting is a nightmare to me - almost as bad as using `tar` without looking at the help - and I always stumble on
the same problems.

Not today, though. Today, I spent 15 minutes looking for the syntax of default values for shell variables for the last
time.

<!-- more -->

The syntax is, to my untrained eyes, obscure and as unhelpful as possible, but this is how it works:

```bash script.sh
#! /bin/bash
HOST=$1
: ${HOST:="localhost"}
echo $HOST
```

Executing `script.sh` then yields:
```bash
nicolasrinaudo:~/scripts ./script.sh 212.128.0.1
212.128.0.1
nicolasrinaudo:~/scripts ./script.sh
localhost
```
