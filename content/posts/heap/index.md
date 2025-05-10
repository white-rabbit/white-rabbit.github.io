---
title: "What I didn't know about the binary heap"
date: 2023-12-30T00:19:08+01:00
draft: true
tags: ["data structures", "algorithms", "time complexity"]
categories: ["Data structures"]
---

# Overview
Binary heap is a tree-based data structure that
is used in such a widely used containers like priority queues.

From a usage point of view, it is usually sufficient to know
only that the maximum (or minimum) element is located at
the top of the heap. And it is obvious that the insert operation
complexity does not exceed the logarithm of the heap size
(because that is the height of a binary tree).

The data structure is pretty simple in terms of implementation and really
compact in memory because there is no need to store edges explicitly.
Moreover the heap is usually represented as a one dimensional array which
can be dynamic or a fixed size array depending on whether the max elements
count is known or not, so it is predictable in terms dynamic memory allocations.

It is interesting that C++ heap is implemented not as an independed container
but instead as a bunch of functions that operates with
the provided iterators. Formally it is not guaranteed that the C++ heap functions
from algorithm library indeed operate with the binary heap but usually it is.

C++ heap from the algorithm library is usually a binary heap
(keep mind it is not guaranteed though) and the interesting thing 

# Idea

# Implementation

# Complexity


Once I had to make some custom structure based on the binary heap.
It was impossible to use the standard implementation in this particular
case so after impleme

Before implementation, I frivolously went to the page dedicated to heaps
(they turn out to be different) on Wikipedia, where I came across a convenient table, 
rom which the obvious thing followed - the computational complexity of inserting
an element into a heap is proportional to the logarithm of the number of elements in it:

{{<figure class="default" src="/images/heaps_table.png" alt="Computational complexity for different heaps (from Wikipedia)">}}
