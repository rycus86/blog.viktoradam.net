---
title: Podlike templates
date: 2018-06-19T07:38:43.000Z
slug: podlike-templates
disqusId: ghost-5b1bc1ca9b017a0001d3403c
image: /images/posts/2018/06/podlike-templates-min.jpg
tags:
  - Podlike
  - Swarm
  - Docker
  - Automation
authors:
  - viktor
metaTitle: >
  Podlike templates for reusable components on Docker Swarm
metaDescription: >
  See a templated approach to define co-located and coupled containers as services on Docker Swarm mode, to make it easier to have "pods" without having Kubernetes.
---

We've seen now that we can run co-located and coupled services on Docker Swarm. This post shows you how to use templates to extend your services in a common way.

<!--more-->

If you haven't done so already, check out the [introduction post](https://blog.viktoradam.net/2018/05/14/podlike/) and the [examples](https://blog.viktoradam.net/2018/05/24/podlike-example-use-cases/) to see what [Podlike](https://github.com/rycus86/podlike) can be used for. In short, you can get a set of containers to always run on the same node in Docker Swarm mode as a task of a service. These containers will share a network namespace, so it makes it very easy to run [sidecars](https://docs.microsoft.com/en-us/azure/architecture/patterns/sidecar) for example. You can also share PID namespaces and volumes, that enables using different patterns for coupled applications.

## The problem

While I was working on the [demo examples](https://github.com/rycus86/podlike/tree/master/examples), one thing became clear to me. If you have homogeneous applications, and you always want to *decorate* them with the same components, then there can be an awful lot of duplication in the stack YAML pretty quickly. In the [biggest stack](https://github.com/rycus86/podlike/blob/master/examples/modernized/stack.yml), each of the applications we want to run in a [service mesh](https://www.thoughtworks.com/radar/techniques/service-mesh) is coupled with the same: a [Traefik](https://traefik.io/) reverse proxy, a [Consul](https://www.consul.io/) agent for service discovery support, a [Jaeger](https://www.jaegertracing.io/) agent for distributed tracing, and a [Fluent Bit](https://fluentbit.io/) instance for centralized logging.

The configuration is almost identical for each service, with the exception of service names and log file paths. Do we really have to duplicate their definitions then? Surely, there's a better way.

## Templates to the rescue

We have identified that the component configurations really only differ in a few variables, but the rest of it could easily be templated. Why not do exactly that then?

In version `0.3.x` of the app, I've added support for transforming a set of [Compose files](https://docs.docker.com/compose/compose-file/) into a single YAML, that changes the services you want into *"pods"*, while still being compatible with the format `docker stack deploy` expects. Actually, with the help of [extension fields](https://docs.docker.com/compose/compose-file/#extension-fields), you can decide whether you want to deploy the stack as-is, or the templated version with the coupled components in it. This could be useful, if you don't necessarily need all those extra bits for local development, but would want to have them on the target servers or environment.

> Top-level extension fields are supported on Compose schema version `3.4` and above.

You can have a *top-level* extension field, called `x-podlike`, that can define 4 types of templates for each individual service:

1. `pod` that generates the result Swarm service definition
2. `transformer` to generate the configuration for the main component
3. `templates` to produce any additional components
4. `copy` for generating the configuration for the files to copy into the component containers

Each of these can define one of more [templates](https://github.com/rycus86/podlike/blob/master/docs/Templates.md) to use, either inline, from local files, or fetched from an HTTP(s) URL. The templates need to produce YAML snippets using Go's [text/template package](https://golang.org/pkg/text/template/) to transform the original service definition plus any additional arguments into the new controller/components configuration. Let me show an example of how this looks like.

```yaml
version: '3.5'

x-podlike:
  # template the `site` service
  site:

    pod:
      # template for the controller
      inline:
        pod:
          # image will default to rycus86/podlike
          command: -logs
          ports:
            - 8080:80
          # the `/var/run/docker.sock` volume is also added by default

    transformer:
      # template for the main component
      inline: |
        app:
          environment: # override environment variables
            - HTTP_HOST=127.0.0.1
            - HTTP_PORT={{ .Args.InternalPort }}
          # the image will be copied over from the original service definition

    templates:
      inline:
        # add in a proxy component
        proxy:
          image: nginx:1.13.10
          volumes:
            - nginx-config:/etc/nginx/conf.d
          depends_on:
            config-writer:
              condition: service_healthy

        # write the Nginx config from an inline string for demo purposes
        # you'd probably either bake it in the image, or use a config or a volume
        config-writer:
          image: rycus86/write
          volumes:
            - nginx-config:/etc/nginx/conf.d
          environment:
            TARGET: /etc/nginx/conf.d/default.conf
            DATA: |
              proxy_cache_path  /tmp/nginx.cache  levels=1:2  keys_zone=cache:10m inactive=12h max_size=50m;

              server {
                  listen       80;
                  server_name  localhost;

                  # proxy all requests to the app on port 12000
                  location / {
                      proxy_pass   http://127.0.0.1:12000;

                      proxy_set_header       Host $$host;
                      proxy_cache            cache;
                      proxy_cache_valid      200 5m;
                      proxy_cache_use_stale  error timeout invalid_header updating
                                             http_500 http_502 http_503 http_504;
                  }
              }

    args:
      InternalPort: 12000

services:

  site:
    image: rycus86/demo-site
    environment:
      - HTTP_HOST=0.0.0.0
      - HTTP_PORT=5000
    ports:
      - 8080:5000

volumes:
  nginx-config:
```

This stack can be deployed either with `docker-compose` or into Swarm with `docker stack deploy`. In these cases, you get the original application on its own, listening for incoming requests on port `8080` externally. When you transform this template to use *podlike*, it will run an additional [Nginx](https://www.nginx.com/) container in the same network namespace as the app, and configures them so that Swarm routes to Nginx, and Nginx routes to the application on the loopback interface. The internal port its going to listen on now changes to a different one, as configured in the `args` section of the `x-podlike` extension.

I appreciate this doesn't look any better than manually defining the labels for the *podlike* controller, but consider how this would look like with shared templates, when we don't want to inline everything for demonstration purposes:

```yaml
version: '3.5'

x-podlike:
  site:
    pod: templates/pod-with-proxy.yml
    transformer: templates/flask-app.yml
    templates: templates/nginx-proxy.yml
    args:
      InternalPort: 12000

services:

  site:
    image: rycus86/demo-site
    environment:
      - HTTP_HOST=0.0.0.0
      - HTTP_PORT=5000
    ports:
      - 8080:5000

volumes:
  nginx-config:
```

OK, that looks a bit better. An additional benefit is that you can easily reuse the same templates for other services in the stack, by referring to the same files. If you have other stacks in different directories, you could still share templates between them by loading them from an HTTP address. And if you're all in with inline templates, check out the [templating docs](https://github.com/rycus86/podlike/blob/master/docs/Templates.md#using-yaml-anchors) on hints to avoid duplication with YAML anchors.

## Configuration

I tried to make the configuration *pretty* flexible, which means you can define things in a few various ways, whichever works best for you. I'm not going to go into details on everything here and now, but you can look at the [templating documentation](https://github.com/rycus86/podlike/blob/master/docs/Templates.md) to see what the options are. Let me just cover the basics and main bits here.

As shown above, the `x-podlike` configuration for each service can have the four template types, each of which can be a single item or a list of them, and all of them are optional. If there is more than one, the results will be merged together in the final output. Refer to the [docs](https://github.com/rycus86/podlike/blob/master/docs/Templates.md#template-merging) to see how the merging logic works. Each item can be given as a template file, an HTTP address for the `http` property, or a *string* with the `inline` key. Both the `file` and the `http` types also support an optional `fallback` configuration, in case loading the template fails with the main chosen method. If the `pod` section is missing, the *controller* is generated with a [default template](https://github.com/rycus86/podlike/blob/master/docs/Templates.md#controller-templates), and so does the [main component](https://github.com/rycus86/podlike/blob/master/docs/Templates.md#main-component-templates) if there are no `transformer` templates given. Both of them also get a lot of properties copied over from the original service definition, like labels, environment variables and such, see the full list in the [source file](https://github.com/rycus86/podlike/blob/master/pkg/template/merge.go) for the merging logic.

Each service can have its own `args` section for any sorts of arguments you can define as a valid YAML mapping, then those will be available for the templates as `{{ .Args.<Key> }}`. The top-level extension field can also have an `args` mapping, and the values from it will be merged with the per-service arguments. These values can be numbers, strings, lists, mappings, or whatever, you'll get them for template rendering in whichever way the Go [YAML package](https://github.com/go-yaml/yaml/tree/v2.2.1) I use can parse them.

Individual services can also have their own, `x-podlike` section for their own specific configuration. This makes more sense to me, though it's not yet supported in Compose files. Still, if you find this way is also more convenient for you, *Podlike* will strip it out from the result YAML. You do lose the ability to deploy the stack with Compose or with `docker stack deploy` directly, without running it through the template engine.

> Compose schema `3.7` and `2.4` [adds support](https://github.com/docker/cli/pull/1097) for extension fields on third level objects, which removes the issue above.

See a completely made-up example below that demonstrates all the possible options you have for configuring the *"pod"*.

```yaml
version: '3.5'

x-inline-templates:  # top-level extension for anchors

  - &proxy-component
    inline:
      proxy:  # the name of the component to add
        image: sample/proxy:0.1.1

  - &proxy-addon
    inline:
      pod:
        configs:
          - source: proxy-config
            target: /var/conf/proxy.conf

  - &proxy-copy
    inline: |
      proxy:  # the name of the component to copy to
        - /var/conf/proxy.conf:/etc/proxy/conf.d/default.conf

services:

  webapp:
    image: sample/webapp:0.12.3
    labels:
      com.samples.type: web
    x-podlike:  # custom configuration for this service
      pod:
        - template/from/file.yml
        - http://template.server.local/pod/addon.yml
        - *proxy-addon
      transformer:
        - file:
            path: maybe/cached/file.yml
            fallback:
              http:
                url: https://templates.local/transformer/web.yml
                insecure: true
        - http:
            url: http://template.server.local/transformer/addon.yml
            fallback:
              file:
                path: local/cached/template.yml
                fallback:
                  inline: |
                    main:
                      labels:
                        sensible: local.template
      templates:
        - *proxy-component
      copy:
        <<: *proxy-copy
      args:  # arguments for this service only
        Sample: Per-service argument
        AsList:
          - item1
          - item2
        AsMapping:
          Key: value

  backend:
    image: sample/backend:1.2.4
    environment:
      - HTTP_HOST=0.0.0.0
      - HTTP_PORT=8080
    ports:
      - 80:8080

x-podlike:
  backend:  # config for a specific service

    transformer:
      inline: |
        environment:
          - HTTP_HOST=127.0.0.1
          - HTTP_PORT=5000

    templates:
      http://template.server.local/transformer/sidecar.yml

    args:  # arguments for this service only
      Example: 42

  args:  # global arguments for every service in this stack
    Global:
      Values:
        - 21
        - 103
      Key: 'Test'
```

## Templates

As mentioned above, you can use Go's built-in [template package](https://golang.org/pkg/text/template/) to build the YAML templates. At the moment, you can use the `{{ .Service }}` key for the original service definition the [docker/cli](https://github.com/docker/cli/blob/master/cli/compose/types/types.go) package exports, plus the `{{ .Args }}` object with the arguments all merged together according to the rules above.

There are also a couple of helper functions available for the templates, that should hopefully make it easier to generate the configurations. Things like `empty` or `notEmpty` could help with some common tests I found myself using for some examples, `contains`, `startsWith` and `replace` to make it easier to work with strings, or `yaml` to easily convert an object into a valid YAML string.

> Check out the [documentation](https://github.com/rycus86/podlike/blob/master/docs/Templates.md#template-variables-and-functions) to get an up-to-date list of what is currently available.

## How to use this?

If you like long commands, or alternatively, dislike Shell scripts, you can use templating with the [Podlike container](https://hub.docker.com/r/rycus86/podlike/):

```shell
$ cat stack-templated.yml | docker run --rm -i rycus86/podlike | docker stack deploy -c - demo
```

This reads the stack YAML with the extra configuration from the standard input, then outputs the final YAML for the stack deploy command. If you're OK with Shell though, you can grab the [podtemplate](https://github.com/rycus86/podlike/tree/master/scripts) wrapper script, and either do this:

```shell
$ podtemplate stack-templated.yml | docker stack deploy -c - demo
```

Or this:

```shell
$ podtemplate deploy -c stack-templated demo
```

These take the stack file's directory, mount it into a *podlike* container, run the template generation, and optionally call the `docker` client binary to deploy the stack. This script *should be* compatible with both `bash` and Alpine's `ash`, but let me know if you find any issues with it on [GitHub](https://github.com/rycus86/podlike).

## What's next?

While I think this *should* all work OK, I have not actually tried it much yet, apart from some examples, and mostly with inline templates for demo purposes. I'm going to start changing some of the services in my [Home lab](https://blog.viktoradam.net/2018/03/15/home-lab-open-sourcing-the-stacks/) to run with sidecars, add a dedicated caching proxy in front of them, deal with service discovery in a different way, etc. Hopefully this will highlight some issues to resolve, and some missing features to add. If you try it yourself, let me know on GitHub or on Twitter or here if something is not right, and we can make it better quickly.

I also have a few things on my mind to support with the app, so hopefully there will be more features you can try soon. Of course, if you have any ideas you'd like to see in the controller, let me know! I have managed to get around the problem of sharing the Docker engine connection with the components now, so it's completely up to you if you want it or not. The Compose-style `depends_on` should also work now, and it makes sure the components start in a specific order. We all know we shouldn't need this, but then we all have those *not-so-container-friendly* apps that need some DNS address or a database connection to be available when they start... :)

Hope you give it a try, and let me know how it goes! Thank you!
