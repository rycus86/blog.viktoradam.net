---
title: Home Lab - Overview
date: 2018-01-03T21:25:31.000Z
slug: home-lab-part1-overview
disqusId: ghost-5a4d4255dbecdc0001ebb9c3
image: /images/posts/2018/01/home-lab-min.jpg
tags:
  - Home Lab
  - Docker
  - Microservices
  - Monitoring
authors:
  - viktor
metaTitle: >
  Home Lab - Overview (part 1)
metaDescription: >
  This post is the first in a series explaining the setup I use to run my websites and their related services at home on cheap hardware using containers.
---

This post is the first in a series explaining the setup I use to run my websites and their related services at home on cheap hardware using containers.

<!--more-->

## Background

I spend a lot of time working on my home lab, *perhaps too much*, but I enjoy it a lot. I always wanted to have some public-facing websites and endpoints I can play with or share with everyone. I also wanted being able to update these as easily as possible, meaning that after finishing with coding up a new change I don't want to spend a lot of time getting the application deployed manually. I also didn't want to spend a lot of money on something I'm working on in my free time.

To list out my *"requirements"* for the home lab:

- Update automatically on code changes
- Update automatically on configuration changes
- Be easy to scale and expand
- Be cheap

I have started off with a single [Pine64](https://www.pine64.org/?page_id=1194) server having 2 GB memory in total, running maybe 4 or 5 containers. As of this writing, the stack now has 3 servers, hosting over 30 containers... *Yes, it blew up a little.*

> You can see it in action at [demo.viktoradam.net](https://demo.viktoradam.net) if you're interested in the result. To be clear, this [Ghost](https://ghost.org/) blog is running on it as well.

## Physical servers

The current setup has 2 [Pine64](https://www.pine64.org/?page_id=1194) instances and a [Rock64](https://www.pine64.org/?page_id=7147) from the same manufacturer. They are all 64-bit ARM servers around the size of a [Raspberry Pi](https://www.raspberrypi.org/). In total, I now have 12 CPU cores with 7 GB of memory to host all the services I'm running. They are great little computers for around $15-45 per instance depending on available memory.

You can run a few different flavors of Linux on them. I've opted to use [Armbian](https://www.armbian.com/) that gives me a Ubuntu derivative. This is particularly important for Docker, which only has official support for a few of them on the *arm64/aarch64* architecture, Ubuntu being one of those. This means that installing and upgrading Docker is as simple as:

```shell
$ curl -fsSL get.docker.com | sudo sh
```

The performance seems OK for the applications I'm using them for. When available memory starts getting a bit low, I can just order one more instance and add it to the cluster. Last time it took about 30 minutes including downloading the base image and writing it to an SD card.

## Clustering

I want my services to use all of the available servers. I don't particularly care about maximizing the usage on them, only that the applications are distributed across them in a sensible manner. I also wanted to avoid hard-coding IP addresses for service endpoints and pinning them to specific servers to keep things dynamic and portable. For this use case, [Docker](https://www.docker.com) and [Swarm](https://docs.docker.com/engine/swarm/) [stacks](https://docs.docker.com/engine/reference/commandline/stack/) are doing an awesome job!

Having everything packaged as Docker images and running them as containers makes the applications portable. I even build them for multiple processor architectures (`amd64`, `arm` and `arm64`), so I can run them on a Raspberry Pi or an x86 NUC in the future, if I decide to. Docker also gives me a unified way of deploying applications regardless of what programming language are they in or what dependencies do they need.

Docker Swarm takes care of the clustering logic. One node is the *leader* and joining new nodes is as easy as:

```shell
$ docker swarm join --token SWMTKN-1-abcd-efgh 192.168.1.1:2377
```

All applications are running as Swarm services described in a YAML file. This allows me to define their runtime properties, configuration as environment variables and other metadata as labels in a single place. Adding a new application is as easy as defining its name, image and settings in this file and deploying the stack again. The actual deployment is automated and related services, like reverse proxies and monitoring, are automatically reconfigured.

> Watch out for more on Docker and related automation around it in an upcoming part of this series!

This all means that whenever I update the stack or the applications in it, everything gets taken care of automatically after a `git push`. *Pretty cool?*

## HTTP access

Some of the services are externally accessible from the internet. I use the fantastic [Nginx](https://www.nginx.com/) to handle routing requests to the right application for me. With Docker though, containers come and go all the time and they can get new IP addresses every time on the internal *overlay* network. I use my [docker-pygen](https://github.com/rycus86/docker-pygen) tool to listen for events from the Docker engine and reconfigure the Nginx instance whenever its configuration needs updating with new upstream targets. The configuration template doesn't only deal with IP addresses. Through Docker service labels, I can change various settings away from the default for selected services, basic authentication or maximum allowed upload size for example. I can address the individual services through either a different [URI](https://en.wikipedia.org/wiki/Uniform_Resource_Identifier) prefix or a different subdomain.

I want my services to expose secure endpoints, so HTTP access on port 80 is basically a redirect to HTTPS. I get the SSL certificates for my subdomains from the awesome [Let's Encrypt](https://letsencrypt.org/), whose mission is to secure the internet for everyone and to this end they provide trusted certificates, valid for 3 months. Fetching and renewing them can be (and should be) fully automated with their [certbot](https://certbot.eff.org/) tool.

My servers are not super powerful, so I've done *some* work to get the endpoints to respond faster. I wanted [HTTP/2](https://en.wikipedia.org/wiki/HTTP/2) access to them, which is not part of the open-source version of Nginx unfortunately. I also wanted to add caching, that is possible with Nginx very easily, but I've found a free alternative to do both (and way more) for me. [Cloudflare](https://www.cloudflare.com/) is a global [CDN](https://en.wikipedia.org/wiki/Content_delivery_network) with a sensible free plan, *how nice of them?*. It provides caching and HTTP/2 as mentioned, their own SSL certificates with origin access being either HTTP or HTTPS, threat prevention, on-the-fly JavaScript, CSS and HTML minification and a lot more. Using a global CDN also means fetching (cached) content should be fast in locations distant from my servers.

## Monitoring

Monitoring my services ad-hoc with SSH access to the box and tailing Docker logs worked OK for a short while, but with the increasing number of them, it started to make sense to add proper tools to do this for me. My Twitter timeline was full with posts about shiny new systems from the [CNCF landscape](https://github.com/cncf/landscape), which got me excited about them, so I went for those mainly. Metrics are collected using [Prometheus](https://prometheus.io/) from the [Flask](http://flask.pocoo.org/) applications (using [my exporter](https://github.com/rycus86/prometheus_flask_exporter)) but also from a few other services that expose compatible metrics natively, the Docker engine or Prometheus itself for example. Host-level metrics, like CPU load, available memory or free disk, are exposed with the [Node exporter](https://github.com/prometheus/node_exporter) by Prometheus. It works very well, even on my resource-constrained servers, since the [v2.0 update](https://coreos.com/blog/prometheus-2.0-storage-layer-optimization) at least. I can also visualize the metrics using the super [Grafana](https://grafana.com/) visualization platform. You can check it out too at [metrics.viktoradam.net](https://metrics.viktoradam.net/). For one-off checks from the local network, I can have a look at the dashboards from [Portainer](https://portainer.io/), which also allows controlling the stack, starting and stopping containers or removing dangling images for example.

Logs are collected with an *almost-ELK* stack. I use [Fluentd](https://www.fluentd.org/) as a log driver for the containers, sending the logs into an [Elasticsearch](https://www.elastic.co/products/elasticsearch) instance and visualization is done by [Kibana](https://www.elastic.co/products/kibana). The reason for switching out [Logstash](https://www.elastic.co/products/logstash) to Fluentd was partially owing to the fact that it needs slightly more memory to run, which seems to be the most limiting factor in my setup.

I have external monitoring of the publicly accessible bits as well from [Uptime Robot](https://uptimerobot.com/). It works brilliantly and with their free plan you can have 50 endpoints monitored using HTTP requests or pings for example. They can even host a public page for you on (or off) your custom domain, like [status.viktoradam.net](https://status.viktoradam.net) - *plain awesome!* By default you get emails when something goes down and comes back up, but there are many other options as well, [Slack](https://slack.com/) notifications being my favorite right now.

## CI / CD

I will do a detailed post on the internals of getting my changes deployed automatically without manual intervention, because I think it is very interesting, even though I'm always looking for better ways of doing it. In a nutshell what happens is, every application is built on [Travis](https://travis-ci.org/) as Docker images for the 3 CPU architectures mentioned above and they are uploaded to [Docker Hub](https://hub.docker.com/) or my [private registry](https://docs.docker.com/registry/deploying/). This sets off some webhooks, which are mainly ignored by [my webhook processors](https://github.com/rycus86/webhook-proxy), waiting for the event about pushing the [multi-arch manifest](https://blog.docker.com/2017/11/multi-arch-all-the-things/). This is also done from Travis using [Phil Estes'](https://twitter.com/estesp) awesome [manifest-tool](https://github.com/estesp/manifest-tool).

When the final webhook arrives, the Docker images are all ready and uploaded to Docker Hub and the manifest points to the actual image for the target CPU architecture, which is `arm64` for my servers. The webhook receiver then pulls this image (using the `latest` tag, easily) and asks Docker to update the related service or services. From this point onwards, it's all up to Docker to schedule the update and restart of the applications and it's working great so far.

## Final words

Hopefully this overview has piqued your interest on some of the topics and got you excited to get started on your own home lab!

See all the related posts under the [Home Lab](https://blog.viktoradam.net/tag/home-lab/) section.

So far, the series has these parts ready:

1. *Home Lab - Overview*
2. [Home Lab - Setting up for Docker](https://blog.viktoradam.net/2018/01/05/home-lab-part-2-docker-setup/)
3. [Home Lab - Swarming servers](https://blog.viktoradam.net/2018/01/13/home-lab-part3-swarm-cluster/)
4. [Home Lab - Configuring the cattle](https://blog.viktoradam.net/2018/01/20/home-lab-part4-auto-configuration/)
5. [Home Lab - Monitoring madness](https://blog.viktoradam.net/2018/02/06/home-lab-part5-monitoring-madness/)
6. [Home Lab - Open sourcing the stacks](https://blog.viktoradam.net/2018/03/15/home-lab-open-sourcing-the-stacks/)
