---
title: "Reinventing the wheel"
date: 2025-05-05T19:04:25+02:00
draft: false
tags: ["graphics", "physics", "simulation"]
categories: ["Numeric simulation"]
author: savegor
---

Many years ago I did a nice exercise: implemented a simple wheel physics simulator.
I remember it was unexpectedly satisfying to see such a simple thing working!
There is a genuine magic when you form a small reality from a dozen numbers...

{{<figure class="default" src="/images/wheel_preview.png" alt="Reinventing the wheel.">}}

Long story short, I spent an evening or two (or more) recreating that project.
I obviously wanted to implement it in Rust
(learning a new language should work this way, right?).


As it is impossible to find a non blazingly fast engine in Rust, I had no choice
but use the famous [Bevy](https://bevyengine.org/)! The engine was surprisingly easy
to start and experiment with! So, after I implemented the basic mechanics I couldn't stop that easy :sweat_smile:.

I added sparks and even enabled the bloom postscreen effect (just because I can :sunglasses:).
It was also quite easy to get the WASM based canvas and embed it below.

{{< wheel_sim id="./reinventing_the_wheel.js">}}

Github repository is [here](https://github.com/white-rabbit/wheel-sim).
