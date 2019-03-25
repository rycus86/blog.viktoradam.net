---
draft: true
title: "Netlify + Hugo"
date: 2019-03-30T00:00:00Z
slug: netlify-hugo
image: /images/posts/2019/03/netlify-hugo-cover.jpg
tags:
  - Automation
  - Home Lab
  - Golang
authors:
  - viktor
metaTitle: >
  Moving to Hugo static site generation hosted on Netlify
metaDescription: >
  Leaving the Ghost blog engine for the amazing Hugo plus Netlify duo, or: static site generators FTW! 
---

Migrating this blog from a self-hosted Ghost instance to a new CDN that also builds your site &ndash; for free.

<!--more-->

In my [last blog post](https://blog.viktoradam.net/2018/08/30/moving-home/), I wrote about migrating some of my self-hosted apps to [AWS free tier](https://aws.amazon.com/free/) services as I was getting ready to move from the UK to Australia. I had some time now to get things in order, so I could start preparing for when the free tier expires.

## Moving from AWS

AWS is *pretty great*. I think, if the free [EC2 instance](https://aws.amazon.com/ec2/) wouldn't expire, I would probably have left my things running on it for another little while. I have a [Ghost](https://ghost.org/) blog engine running there, a [Prometheus](https://prometheus.io/) and a [Grafana](https://grafana.com/) instance for monitoring, plus a few hand-made services to pull my [GitHub stats](https://github.com/rycus86/github-prometheus-exporter) and [watch for new releases](https://github.com/rycus86/release-watcher). All in all, happily ticking away with *300 MB* memory left and less than *25%* of the disk space in use. After the free tier ends, this would cost about $10 a month, which is not bad, it's just $10 more than I'm willing to pay for this at the moment.

At first, I thought I just move stuff back onto my own servers and host them there like I did back in the UK. I had a few [Raspberry Pi](https://www.raspberrypi.org/) devices set up and started a couple of containers on them to test the connection. This did not go so well...

> As it turns out, Australian home internet is not at the same level of speed yet as it was in the UK.

I mean, it's OK for streaming *Netflix* and browsing the web and such, not so much for serving content to the internet. Speed tests came back a bit low, so I thought I'll try and measure it for a few days, see if it has better days and worse.

> TODO screenshot of Grafana dashboard 

This dashboard shows a [small Python app](https://github.com/rycus86/speedcheck) measuring the upload speed from *Sydney, Australia* to the EC2 instance running somewhere in `us-west-1`. You can see that it averages around *900 kB/s*, which - again - is not so bad for a home internet, but it can cost precious milliseconds for uncached requests. It was time to look for alternatives I wanted to try for a while now.

## Netlify

I wanted to give [Netlify](https://www.netlify.com/) a try ever since I've heard about them from the amazing [@jessfraz](https://github.com/jessfraz):

{{% embed-tweet tweet-id="738658433172283394" %}} 
<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">moved my blog to <a href="https://twitter.com/Netlify?ref_src=twsrc%5Etfw">@Netlify</a> in literally 3 minutes, so now <a href="https://twitter.com/calavera?ref_src=twsrc%5Etfw">@calavera</a> has to worry about it now &amp; not me... so this makes me <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> right?</p>&mdash; jessie frazelle 👩🏼‍🚀 (@jessfraz) <a href="https://twitter.com/jessfraz/status/738658433172283394?ref_src=twsrc%5Etfw">June 3, 2016</a></blockquote>
{{% /embed-tweet %}}

OK, that sounds really good, but what is this all about? As I quickly learned, it's basically a CDN that can also generate your static site. *Or so I thought...* It turns out, Netlify [Application Delivery Network](https://www.netlify.com/features/adn/) is so much more than this and is just plain awesome! As they put it on their site:

> Distributed just like a CDN, but with advanced functionality for publishing entire sites and applications. Automate builds to prerender content and deploy worldwide to every major cloud provider—including staging, rollbacks, and even A/B testing.

![Take my money](/images/posts/2019/03/take-my-money.jpg)

... TODO: features, setup, etc.
... TODO: ## Hugo
