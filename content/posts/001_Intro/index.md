---
title: In pursuit of automated continuous everything
date: 2017-12-14T21:08:26.000Z
slug: intro
disqusId: ghost-5a317ae8fbd30c00013c9706
tags:
  - Intro
authors:
  - viktor
metaDescription: >
  Blogging on open-source tools, containers, free hosted services, all kinds of DevOps trickery, automation with continuous integration and delivery.
---

*Alternative title:* What you can't do at work, try it at home!

<!--more-->

## Introduction

*Hi!*

I've decided to start this blog to tell you about all the cool things I'm working on in my free time.
Fair warning: it involves a lot of open-source tools, containers, free hosted services, all kinds of DevOps trickery, automation with continuous integration and delivery. If *none* of this interest you, I have bad news...

I'm planning to write about my experience setting up my [demo site](https://demo.viktoradam.net) using *(almost)* only free and open-source tools that I started working on with one ultimate goal.

> Fully-automated builds, deployments, configuration and monitoring.

In fact, it was a relatively simple two-step process:

1. Buy a domain name
2. Write a few [Flask](http://flask.pocoo.org/) applications and set up a CI/CD pipeline using [GitHub](https://github.com/) and [Travis](https://travis-ci.org), webhooks, a whole lot of [Docker](https://www.docker.com) containers and all the open-source tools one can find.

I suppose, I can break down *one* of those steps a bit further if you're interested.

## Background

I've always wanted to create something I could share with the world hoping that someone would stumble upon it and find it useful to give them ideas and inspiration for doing cool things I could learn from. What held me back before was having no easy and/or cheap way of hosting services and example implementations - that I knew of.

It has all changed when I read [Alex Ellis' blog](https://blog.alexellis.io/) about how easy (and not at all expensive) it is to have your own domain and self-host some applications on [cheap hardware](https://blog.alexellis.io/self-hosting-on-a-pi/). I went on to register `viktoradam.net` at [Namecheap](https://www.namecheap.com) with no concrete plans but ideas on how I would want my own pet project to look like.

Being able to point a nice-looking and easy-to-remember URL to a small Linux box running in my living room has opened a world of potentials for me. Suddenly, it became easy to get visible results quickly while experimenting with modern technologies I'm reading about in tech blogs and Twitter.

> All I knew at the beginning was that I want a website and I want to be able to update it with a simple `git push`.

## Current state

In a few weeks I managed to write my Python applications and set up the pipelines for delivering them to my devices. I quickly realized the fact that the more I get done the more ideas I get to keep hacking on. As I kept reading about all the awesome [CNCF](https://www.cncf.io/) projects and others, I became more and more enthusiastic to try new tools and gain some fresh experience in areas I'm not too familiar with, take reverse proxies, monitoring and DevOps for example.

I started with a simple setup using one [Pine64](https://www.pine64.org/?page_id=1194) ARM64 board I had lying around on a shelf with the continuous delivery being basically a `docker-compose pull && docker-compose up -d` on a *cron* schedule.

Once I managed to almost fully consume the 1GB memory of the server, I added another instance - with 2GB memory this time. I've put them in a [Docker Swarm](https://docs.docker.com/engine/swarm/) cluster and rewrote the pipelines to trigger updates using webhooks when new Docker images are pushed to [Docker Hub](https://hub.docker.com/) or configuration files change in a private Git repository.

After having more than a handful containers running at a time, I started looking into adding metrics to the servers and services to know what is going on with them. Recently, I've also set up a centralised logging stack to have an easy way of checking application logs without having to SSH into the boxes then jumping to another one once I realise the container is running over there.

I have learned a lot while doing these and I hope you'll enjoy reading about it!

