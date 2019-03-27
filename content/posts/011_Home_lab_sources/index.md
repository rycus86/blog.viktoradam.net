---
title: Home Lab - Open sourcing the stacks
date: 2018-03-15T08:59:27.000Z
slug: home-lab-open-sourcing-the-stacks
disqusId: ghost-5aa98c4a650fff0001d1809f
tags:
  - Home Lab
  - CI/CD
  - Docker
  - Swarm
authors:
  - viktor
metaDescription: >
  The final post in the series describes the various Swarm stacks I now have in GitHub, and explains the workflows for updating them using webhooks.
---

The final post in the series describes the various Swarm stacks I now have in GitHub, and explains the workflows around them.

<!--more-->

## Motivation

Until recently, I had a single Swarm stack for all my services in a private [BitBucket](https://bitbucket.org) repository, also containing some of the configuration files for them. I also had sensitive configuration files and secrets at *known locations* on disk, and mounted into the containers that needed them from there. This was working OK for the most part, though some services needed a manual *forced* update, when their config has changed. It was also getting hard to manage a single YAML file with *~700* lines, so I decided, it's time to change things a little bit.

I wanted to make my stack YAML files public, so they could serve as examples for anyone interested. I started splitting the single private repo up to [individual GitHub repositories](https://github.com/rycus86?tab=repositories&q=home-stack), where the services are grouped by their different functions in my home lab. Each of them also contains all the necessary configuration for the services within, to make updates easy when any of them changes, thanks to a recently added Docker feature I [wrote about](https://blog.viktoradam.net/2018/02/28/swarm-secrets-made-easy/) previously.

Let's have a look at the stacks to see their services and what they do!

### Web stack

![Web stack](https://github.com/rycus86/home-stack-web/raw/master/stack.png)

The [home-stack-web stack](https://github.com/rycus86/home-stack-web) is the main entrypoint from external networks. A service, running the [Nginx](https://www.nginx.com/) [image](https://hub.docker.com/r/_/nginx/) is listening on port 443 for HTTPS connections, and all external HTTPS traffic will go through its instances. This then connects to the other services on an overlay network, called `web`, usually on HTTP.

> Note, that all the other services listen only within the overlay network, they are not (and not need to be) accessible from external networks.

The service uses Swarm configs and secrets for the main Nginx configuration file and for basic authentication configuration, respectively. It also uses a shared volume for the runtime configuration file, where all the upstream servers and the routing rules are defined. This is being kept up-to-date by a pair of [docker-pygen](https://github.com/rycus86/docker-pygen) manager/worker services. These react to events from the Docker engine, regenerate the configuration file, then signal the running instances to get it reloaded. I have written a [blog post](https://blog.viktoradam.net/2018/01/20/home-lab-part4-auto-configuration/) about this in more detail, if you're interested. The template for the config generation is also kept in a Swarm config, so the PyGen services can be restarted when it changes.

> The manager service needs to have access to the Docker Swarm APIs, and because of this, it needs to run on a manager node. This is super easy to do with the `node.role == manager` placement constraint.

The tasks started from the Nginx service also have appropriate labels for the [domain automation](https://github.com/rycus86/domain-automation) service to find and signal when the SSL certificates used have been renewed *automatically*, using [Let's Encrypt](https://letsencrypt.org/) as the provider. The certificate files are stored on a shared volume, so it can easily pick them up from there.

All other services in the `web` stack accept HTTP connections, as described above. These services include this [Ghost blog](https://ghost.org/), my [demo site](https://github.com/rycus86/demo-site), plus a few other [Flask apps](https://blog.viktoradam.net/2017/12/16/python-microservices-with-flask/) for REST endpoints. They all include service labels for routing information, `routing-host` for the domain name I want to expose them on, and the `routing-port` label for the internal port Nginx can connect to them. Some of them also use Swarm secrets for various settings, like API keys for external services. Most of them are attached to the `monitoring` overlay network too, so that Prometheus can also connect to them to scrape their metrics. *(see below)*

| | |
| ------ | ------ |
| Stack | https://github.com/rycus86/home-stack-web/blob/master/stack.yml |
| Config | https://github.com/rycus86/home-stack-web/tree/master/config |

### Monitoring

![Monitoring stack](https://github.com/rycus86/home-stack-monitoring/raw/master/stack.png)

At the heart of this stack, there is a [Prometheus](https://prometheus.io/) instance running, that scrapes other services, and collects their metrics. Its configuration is kept up-to-date by another set of PyGen services, the configuration file being stored on a shared volume again. The other services only need to be on the `monitoring` network, and define the `prometheus-job` and `prometheus-port` service labels to get automatically registered. I have another [blog post](https://blog.viktoradam.net/2018/02/06/home-lab-part5-monitoring-madness/#monitoring) describing this in more detail.

Beside the application-level metrics, *physical* node metrics are coming from a [Prometheus node exporter](https://github.com/prometheus/node_exporter) instance: CPU, memory and disk usage, for example. I'm also collecting container-level metrics, using [Telegraf](https://github.com/influxdata/telegraf), that gives a more detailed view on how much CPU, memory or network bandwidth do the individual containers use. Both of these are running as *global* services, meaning they will get an instance scheduled to each node in the Swarm cluster.

All these metrics are then visualized by a [Grafana](https://grafana.com/) instance, that provides beautiful dashboards, with the data provided by querying Prometheus. The main Grafana configuration is also coming from a Swarm secret, stored in an encrypted file inside the same GitHub repository. *(more on this later)*

The stack also includes a [Portainer](https://portainer.io/) instance to have a quick view of the state of the containers and services. This service does not connect to the `web` network, since I don't want it publicly available, instead it publishes a port on the Swarm *ingress* network. This allows me to access it from local network at home, without exposing it on the internet.

| | |
| ------ | ------ |
| Stack | https://github.com/rycus86/home-stack-monitoring/blob/master/stack.yml |
| Config | https://github.com/rycus86/home-stack-monitoring/tree/master/config |

### Logging

![Logging stack](https://github.com/rycus86/home-stack-logging/raw/master/stack.png)

As described in a [previous post](https://blog.viktoradam.net/2018/02/06/home-lab-part5-monitoring-madness/#logging), this stack contains an [Elasticsearch](https://www.elastic.co/products/elasticsearch) instance for log storage and querying, [Kibana](https://www.elastic.co/products/kibana) for visualization, and [Fluentd](https://www.fluentd.org/) for log collection and forwarding.

The Fluentd instance publishes its port onto the *ingress* network, and (almost) all services will use the `fluentd` Docker logging driver to send their logs to it. The reason for this is that the logs are sent from the Docker engine, on the physical network, rather then on an internal overlay network. Each service defines a logging `tag` for itself, so their logs can be easily found in Kibana later.

The logging-related services themselves, plus a few other *chatty* ones, don't use Fluentd. They kept the default `json-file` log driver, with some configuration for log rotation to avoid generating huge files on the backing nodes' disks.

All the Elasticsearch and Fluentd configuration files are kept in files [in the GitHub repo](https://github.com/rycus86/home-stack-logging/tree/master/config), and they are then used as the data for the Swarm configs generated for their services. 

| | |
| ------ | ------ |
| Stack | https://github.com/rycus86/home-stack-logging/blob/master/stack.yml |
| Config | https://github.com/rycus86/home-stack-logging/tree/master/config |

### Webhooks

![Webhook stack](https://github.com/rycus86/home-stack-webhooks/raw/master/stack.png)

All the updates to all my Swarm stacks are managed by webhooks, processed using my [webhook Proxy](https://github.com/rycus86/webhook-proxy) app. You can find some information on how in a [previous post](https://blog.viktoradam.net/2018/01/13/home-lab-part3-swarm-cluster/#updatingstacks), though it's fairly straightforward.

There are two services of the same app. The externally available `receiver` takes the incoming webhooks as HTTP requests through Nginx, validates it, then forwards it to the internal `updater` instance. Only the first one needs to be on the `web` network, so that Nginx can talk to it, the other one is only accessible from the stack's default overlay network. This way, the instance that has access to the Docker daemon and sensitive information, like SSH keys for GitHub, is not directly exposed to external networks.

The `receiver` service deals with two types of webhooks. The first one accepts webhooks from Docker Hub, when an image has been pushed there. Most of my images are built on [Travis CI](https://travis-ci.org/), the CPU architecture-specific images pushed first, followed by the multi-arch manifest at the end, which is the one I want to process here. After validation, the request is passed to the internal `updater` instance, that pulls the new image, finds matching services running with a previous version of the same image, and updates them with the new one just received.

The other type of webhook comes from either GitHub or BitBucket from a repository containing one of the stacks. In case of GitHub, the request signature is verified first, using Swarm secrets. If everything looks good, the internal webhook processor will:

1. Create the root directory for the stack if it does not exist yet
2. Pull the repository's content into this directory, and decrypt files if needed
3. Ensures that all external Swarm networks referenced in the YAML file exist
4. Executes the `docker stack deploy` command

The last step will create all the Swarm secrets and configs, and updates (or creates) all the services in the stack.

| | |
| ------ | ------ |
| Stack | https://github.com/rycus86/home-stack-web/blob/master/stack.yml |
| Config | https://github.com/rycus86/home-stack-web/tree/master/config |

### Other stacks

![Docker stack](https://github.com/rycus86/home-stack-docker/raw/master/stack.png)

I have a few other, smaller stacks in my home lab. One of them houses a private [Docker Registry](https://github.com/docker/distribution), where I keep my images I don't necessarily want in Docker Hub. This service is somewhat special from a routing perspective. It does it's own basic authentication, and it accepts HTTPS connections only on the internal overlay network, coming from Nginx. This minor deviation is handled by the Nginx template, using a boolean flag from the `routing-on-https` service label.

![DNS stack](https://github.com/rycus86/home-stack-dns/raw/master/stack.png)

There is also another small stack, looking after my DNS and SSL maintenance I wrote about in a [previous post](https://blog.viktoradam.net/2018/02/17/auto-dns-and-ssl-management/). The service for the [domain-automation](https://github.com/rycus86/domain-automation) app uses quite a few Swarm secrets, mainly for access keys to various external services, like [Slack](https://slack.com/) for example. This stack is one where the service defined in it is not connected to the `web` network, as the application doesn't provide an HTTP endpoint *(externally)*. It is connected though to the `monitoring` network, so Prometheus is able scrape its metrics, like it does with services in any other stacks.

| | |
| ------ | ------ |
| Stack | https://github.com/rycus86/home-stack-docker/blob/master/stack.yml |
|   | https://github.com/rycus86/home-stack-dns/blob/master/stack.yml |
| Config | https://github.com/rycus86/home-stack-docker/tree/master/config |
|   | https://github.com/rycus86/home-stack-dns/tree/master/config |

## Sensitive configuration

I have mentioned secrets a few times. All the files that hold their data live in public GitHub repositories, but encrypted using [git-crypt](https://github.com/AGWA/git-crypt). It is super easy to set it up.

```shell
$ apt-get install git-crypt
...

$ git-crypt init
Generating key...

$ cat .gitattributes
*.conf filter=git-crypt diff=git-crypt

$ git-crypt status
not encrypted: .gitattributes
not encrypted: .gitignore
not encrypted: README.md
    encrypted: config/grafana.conf
not encrypted: config/prometheus.pygen.template.yml
not encrypted: config/telegraf.config
not encrypted: stack.png
not encrypted: stack.puml
not encrypted: stack.yml
```

Once set up, *git-crypt* will transparently encrypt and decrypt files when needed, so a `git diff` for example would work as usual, not comparing the encrypted bytes of different version of a file. When the repository is cloned somewhere else, another machine perhaps, the encrypted files can be unlocked with a simple `git-crypt unlock [key-file]`. For more information check out the [documentation](https://www.agwa.name/projects/git-crypt/).

## Swarm networks

Docker Swarm puts services in a *single* stack on an automatically generated overlay network. This is great, because the services in it can freely talk to each other, even using the service names as hostnames, thanks to the internal DNS resolver provided. Breaking up my large single stack into multiple, smaller, individual ones did pose a challenge though. Where services could previously access another one in the stack, through the `default` network, now need to be on another shared network. This is where *external* networks come to the rescue!

```yaml
version: '3.5'
services:
  ...
networks:
  shared:
    name: cross-stack
    external: true
```

The snippet above tells Docker, that there is an external network, called `cross-stack`, exists already outside of the Swarm stack, and *not managed* by it. Individual services in this stack then can declare, that they need to be on that network as well. We just need to make sure it exists prior to executing the `docker stack deploy` command. This is why my webhook processor pipeline includes a [step](https://github.com/rycus86/home-stack-webhooks/blob/master/config/updater.yml#L110) to prepare them.

While I was moving the services out of the single stack and into the new, smaller stack, I had updated the original stack to include an external `legacy` network, and added the necessary services, like Nginx and Prometheus, on it. This way, the services in the new stacks had to be placed on this extra network as well temporarily, so that routing from Nginx could still work to their endpoints, for example. Once the migration was completed, I could simply roll out another update to remove the `legacy` network from each stack's YAML file.

## Final words

I am hoping that these stacks can now serve as an example to anyone who stumbles upon them in GitHub. If you're interested in learning more about the setup in my home lab, check out the previous posts in the series:

1. [Home Lab - Overview](https://blog.viktoradam.net/2018/01/03/home-lab-part1-overview/)
2. [Home Lab - Setting up for Docker](https://blog.viktoradam.net/2018/01/05/home-lab-part-2-docker-setup/)
3. [Home Lab - Swarming servers](https://blog.viktoradam.net/2018/01/13/home-lab-part3-swarm-cluster/)
4. [Home Lab - Configuring the cattle](https://blog.viktoradam.net/2018/01/20/home-lab-part4-auto-configuration/)
5. [Home Lab - Monitoring madness](https://blog.viktoradam.net/2018/02/06/home-lab-part5-monitoring-madness/)
6. *Home Lab - Open sourcing the stacks*
