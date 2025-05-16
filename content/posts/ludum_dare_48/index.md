---
title: "Ludum Dare 48"
date: 2020-09-01
summary: One more three-day game. This time, it is called "Disposal"!
draft: false
author: savegor
cardimage: ludum_dare_48.png
---

Once more, I joined forces with UNSTOPPABLE [General Arcade](https://generalarcade.com/)
to make a video game in three days!

For Ludum Dare 48, the topic was "Deeper and deeper", so yeah, the game mechanics
should have been definitely deeper this time!

I don't remember exactly how we came up with this idea:
- a guy is trying to escape from a poisonous liquid;
- the liquid follows the communicating vessels law;
- the only way to escape is to dig deeper and deeper, underground.

But we needed a fast pixel water physics simulator that follows the communicating
vessels law. We didn't find anything appropriate in Unity, so we made one!

Technically, the programmers' team split into two parts, the one I was in worked
on the ~~water~~ poisonous liquid engine and the second part did the rest.
(The Creative Department worked hard on the art).

For a moment we thought that it would be enough to make a cellular automation,
but it obviously doesn't work with communicating vessels!
Luckily the simulation logic can be still quite simple:
- find the strong connectivity components;
- for each of the components determine the **upper** pixels,
  that can propagate (sorry, Physicists!) somewhere **below**;
- determine places where the ~~water~~ poisonous liquid should propagate;
- teleport the pixels;
- repeat;


All of this can be done in a single [Bread-First-Search](https://en.wikipedia.org/wiki/Breadth-first_search)
(I am guilty of using [Depth-First-Search](https://en.wikipedia.org/wiki/Depth-first_search)
in the initial prototype, which is a bad idea as you can easily run out of stack!).
So, know what? The algorithm is linear in terms of the ~~water~~ poisonous liquid pixels number!


It was also surprisingly easy to integrate the engine into [Unity](https://unity.com/) and we even
had time to polish some rough edges!

And, here it is.

**Disposal**

{{< figure src="/ludum_dare_48/ld_48_gameplay.jpg" title="Gameplay" >}}

The WebGL based version of the game is available [here](https://krotos139.itch.io/disposal),
thanks [krotos139](https://github.com/krotos139)!

The project [Ludum Dare web page](https://ldjam.com/events/ludum-dare/48/disposal).
