---
title: Critical git commands
tags: bash
---
I have to do a lot of code reviewing as part of my job, and it's something that I both enjoy and dread - some reviews are pleasant, some are an absolute nightmare.
Surprisingly, I found this had very little to do with the quality of the code and was strongly correlated to the attention that had been put into providing a
simple, coherent

The difference, in most cases, is how much attention was paid to crafting the git history of the change to review. Single-commit reviews will often incorporate
completely unrelated changes in the same commit and impose a large cognitive burden on the reviewer - you need to keep track of the various purposes of what you're
reviewing and identify which is served by each code change.

I'll be honest - I absolutely used to just squash all my temporary commits into a single one, push that, and let the reviewer deal with it. But having spent a lot
of time *being* the reviewer, I changed my workflow entirely and make sure to only submit changes that are, if anything, too granular in their commits. I will,
for example, split a feature's implementation and its test in two separate commits. Or split the various steps needed for a single feature into separate commits.

The point is that the reviewer can then review commit by commit, and build up logically to the end-result, focusing on each step individually rather than on the
whole diff in one go - which he can still do, if he wants to, to make sure that the change makes sense as a whole and that there aren't any clear design flaws.

This has made reviews much faster and drastically reduced the amount of resentful glares I get in the office. It has also forced me to become a lot more comfortable
with editing the history of local changes before pushing them. The purpose of this post is to explain what I consider to be the bare minimum one must know in order
to be able to confidently craft their git history for review, and to do so with as little wasted time as possible.

<!--more-->

# Working on a feature

- checkout -b

# Adding files

- add
- rm
- add -i
- add -p

# Committing files

- commit
- commit --amend

# Fixing a previous commit

- rebase -i
- commit --amend --fixup
- rebase -i --autosquash

# Incorporating remote changes

- rebase
- rebase --onto
