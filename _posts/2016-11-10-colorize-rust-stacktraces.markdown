---
layout: post
title: "Colorize Rust <span class='no-wrap'>Stack Traces</span>"
feature-img: "assets/img/colorcargo.webp"
thumbnail: "assets/img/colorcargo.webp"
date: 2016-11-10 16:34:00 +0300
categories: rust stacktrace debug
nostr:
  comments: naddr1qqxnzd3cxqmrzv3exgmr2wfeqgsxu35yyt0mwjjh8pcz4zprhxegz69t4wr9t74vk6zne58wzh0waycrqsqqqa28pjfdhz
  #comments: note1ry94a0z0aq93dyx56e2lyrjr2yqh4sj2hp3ae2ucnk3rk7t6l53sk5k4ps
---

After getting tired of looking at particular places of Rust stack traces I've written
[this little script](https://github.com/alopatindev/colorcargo) to

- highlight the most interesting parts
- (optionally) remove some boring lines
