---
layout: post
title: "How To Learn Algorithms"
feature-img: "assets/img/algorithms-word-cloud.webp"
thumbnail: "assets/img/algorithms-word-cloud.webp"
date: 2017-05-25 08:00:00 +0300
tags: [algorithms, learning, courses, computer science, software engineering, interview]
lang-ru-uri: "/ru/how-to-learn-algorithms/"
---

I want to share some ideas about the particular topic: how to **learn** (**improve** or **refresh knowledge** about) Algorithms and Data Structures.

## Why?
Many beginners don't understand the purpose of this discipline.

You already have those fundamental algorithms in your standard library, so you will **likely never need to implement them** in real projects, right?

Yes, but this is actually not the point of learning algorithms at all.
<!--more-->

{% include quote.html text="Algorithms Courses are Not About Concrete Fundamental Algorithms" %}

In my opinion, they are all about **general design techniques** that help you build **any algorithm** in general, not just fundamental ones.

Fundamental algorithms and data structures are mostly used **as reference** for the techniques application.

## Recommended Prerequisites for Learning
- **basic math** skills
    - basic discrete math understanding
        - familiarity with **graphs terminology**
        - **perfect binary tree properties** (particularly relations between height, number of nodes and number of leaves)
        - basics of **combinatorics and probability** theory would be handy too
    - basic calculus (**limits** and **sums**)
    - **theorems proving** techniques (by contradiction and induction)
- **structured and procedural programming** paradigms experience
- **certain coding skills** in a particular programming language
    - you can pick any programming language that focuses on imperative programming: Python, Java, C, etc.
    - basically, learn it until you feel comfortable with it (e.g. you're not annoyed with compiler/interpreter errors)
- understanding **basic idea behind TDD** and ability to write simple `assert`ions in your language
    - this will save you plenty of time, I promise!
- ability to **distinguish iterative, recursive and tail-recursive** functions
- ability to **convert recursive functions** to/from iterative ones

If you're not familiar with a few or most of these topics—don't worry anyway: you can either learn some of them quickly or you can try to find such algorithms courses that **don't focus on things you don't understand** at the moment.

I personally learned algorithms iteratively: the first encounter was when I had very poor math knowledge.
From time to time I was learning all algorithms all over again, diving deeper.

## Materials
I personally prefer watching [video courses](/ru/алгоритмы-и-структуры-данных-простыми-словами/#подборка-материалов) **at 1.5x—2x speed**.

But remember: there's no such thing as "the best Algorithms course" (or the best book or the best anything).
Please note that people are different, so particular materials and learning techniques that work fine for me won't necessary work fine for you.

When something is unclear you can always:
- find an **alternative explanation** at YouTube (or in a **blog post** or in a **book section**)
- google a particular forum discussion
    - just figure out **how would you ask a particular question**
    - it's very unlikely you've got a question that has never been asked before

![](/assets/img/input-example.webp)

## Algorithm for Learning Algorithms
This is how I do this:
1. Watch a video or read an article that shows you **a particular input example** and **what algorithm does** with this input.
2. Now try to do exactly **the same thing using pen and paper**. Try original input, try weird input, try empty input. **Make sure you do it the right way**.
3. Since you've tried several different inputs and processed them the right way—you've already learned the algorithm. Now you need to **express it with code**.

Three steps, it's that simple.

## Expected Result
What you really supposed be able to do after learning algorithms discipline (in the best case):
- design algorithms **using popular design paradigms**: Brute Force, Divide and Conquer, Dynamic Programming, Greedy Algorithms, Backtracking
- understand differences between asymptotic notations (O, Θ and Ω)
- **analyze time and space complexity** using different techniques
    - for recursive algorithms: by building and solving recurrence relations (using Master Theorem, Recursion Trees + Induction, etc.)
    - for iterative ones: by estimating number of possible iterations for each block of your code
    - applying amortized analysis when necessary
- prove correctness of algorithms
- reduce unknown problems to known P and NP problems
- build cache-efficient algorithms

Also you will **perform better in coding interviews**.

## Common Pitfalls
- trying to **memorize a particular algorithm** (rather than figuring out design ideas behind the algorithm)
- learning by **analyzing given (pseudo)code** (rather than visualizing examples of particular inputs using pen and paper and figuring out the algorithm by your own)
    - though many classical books, like CLRS, focus you on pseudocode by default
    - this pitfall leads to tricking your brain: it feels you understand the algorithm but you actually understand it partially; also you will likely forget the algorithm and ideas behind its design very quickly
    - **advice: check the code only if you weren't able to write a program by your own** or you want to improve your current solution
- iterative design preference rather than recursive (or vice versa)
    - thinking about problems recursively is a more natural way in many cases (DFS, MergeSort, etc.)
    - **advice: start with recursive solution** and convert it to iterative one only after making sure your implementation is correct
- trying to build cool-general-shiny-**reusable code from the beginning** (i.e. implementing sorting algorithm for generic types rather than integers, implementing a heap that can be used both as Min and Max heap, thinking too much about best identifier names, etc.)
    - if you do any of these then **you're actually procrastinating**
    - it's easy to lose focus on a real problem because of the procrastination
    - **advice: always start with very dumb naive design**
- **not testing your code** properly
    - obvious issue: you will think your implementation is correct
    - advice:
        - **start writing tests as soon as possible**, use original input from lecture first
        - write **tests based on random generator** if possible
        - unlike real production code, here you can **test everything you want**: testing any little helper function can save you a plenty of time

## Post-Learning
To test your algorithmic skills you can use services like [HackerRank](https://www.hackerrank.com) and [LeetCode](https://leetcode.com) or even practice [coding interviews](https://www.pramp.com/).

Good Luck!
