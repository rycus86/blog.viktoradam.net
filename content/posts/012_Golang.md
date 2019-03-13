---
title: Go explore
date: 2018-04-26T08:30:47.000Z
slug: go-explore
disqusId: ghost-5ae0e1ed0d55d100019f7106
image: /images/posts/2018/04/golang-min.jpg
tags:
  - Golang
  - Programming
authors:
  - viktor
metaTitle: >
  Go explore - Playing with the Go language
metaDescription: >
  Tales of adventures in GoLand, one month in. A subjective look at the Go language, after having spent about a month using it, with zero previous experience.
---

Tales of adventures in GoLand, one month in.

<!--more-->

I always wanted to have a proper look at Golang, for quite a while now. I wanted to see what all the hype is about, and how could I use it in my [Home lab](https://blog.viktoradam.net/tag/home-lab/). I thought it might be a good fit there, given I run it on small, resource-constrained devices, so the smaller I can get my Docker images, the better. I was also hoping to shave off some of the overall CPU and memory usage by writing apps in Go, instead of Python or Java. Plus, learning a new programming language is fun!

> This post is a very subjective look at the Go language, after having spent about a month using it, with zero experience.

## Where to begin?

A good few years ago, I started learning Python by going through the official documentation on [docs.python.org](https://docs.python.org/), and I found it a good, comprehensive introduction to the basics of the core library. With Go, I took a similar approach. I went on [tour.golang.com](https://tour.golang.org/), to get a feel of what is common with other languages I know, what is different, or something that is unique to this language (for me at least).

Next, I needed some IDE to start playing with the language on my developer machines. I like [JetBrains](https://www.jetbrains.com/)' IDEs very much, and I have read some news about their [GoLand](https://www.jetbrains.com/go/) already, so it was time to have a look at it. I'm not a huge fan of installing SDKs, frameworks, libraries, IDEs, etc. on the host itself, because it's hard to keep it tidy, there are issues with updates and such, we're much better off dealing with these in a container you can easily throw away and start over. I quickly wrote a [Dockerfile](https://github.com/rycus86/docker-goland/blob/master/Dockerfile) for [rycus86/goland](https://hub.docker.com/r/rycus86/goland/), mostly based on what I already had for [PyCharm](https://hub.docker.com/r/rycus86/pycharm/) and [IntelliJ](https://hub.docker.com/r/rycus86/intellij-idea/), built the new image locally, and we were in business. I started with release candidates for *2018.1*, so I could use them for a few weeks, until the release finally came out, then I just bought the license straight away, by then I was convinced it's worth it. I use it like this at home:

```shell
$ cat /usr/local/bin/goland
#!/bin/bash
docker run --rm \
  --network=host \
  -e DISPLAY=${DISPLAY} \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v ~/.GoLand:/home/developer/.GoLand2018.1 \
  -v ~/.GoLand.java:/home/developer/.java \
  -v ~/Project/go:/home/developer/go \
  --security-opt=seccomp:unconfined \
  --name goland-$(head -c 4 /dev/urandom | xxd -p)-$(date +'%Y%m%d-%H%M%S') \
rycus86/goland:latest
```

I have an alternative dev environment prepared on my work MacBook I also use while travelling by train, this is based on the [golang:1.10](https://hub.docker.com/r/_/golang/) official image, with [vim](https://www.vim.org/) added on top, plus some utilities I often use, like *git*, *curl*, etc. This might feel a bit more difficult than using a visual IDE, but Go has wonderful and useful error messages, and you can always look up library types and functions by opening the sources that comes with the installation.

## First impressions

Installing a binary distribution of a specific Go release is not as trivial as I would like it to be. It's fine if you start with the official images, or maybe if you install it with a package manager, but otherwise you have to set up a few environment variables to have it working properly, which is not easy if you're looking at this for the first time. I'm pretty sure I still haven't got this part completely right.

Dependency management is... interesting. Gave `go get` a quick spin, probably not the right way though, then had a quick look what else is there, and settled on `dep` for now. It looks easy enough, and it just works most of the time. I have run into some issues with it already, so it may not be the final tool I end up with.

The Go syntax overall looks pretty good to me. Getting the hang of writing the type on the right side of the variable was easier than I expected, `var` and `const` makes sense, and `func` is fine too after all those `def`s. The `=`/`:=` thing is a bit annoying for now, but OK. The `for` loop felt a bit weird, but getting used to it now, and by this I mean, I can no longer write a syntactically correct one anymore in either Go, Python or Java on the first try... Is it maybe:

- `for (int idx = 0; idx < length; idx++) { }`
- `for (final X x : xs) { }` or
- `for x in xs:`
- `for idx, x in enumerate(xs):`
- `for key, value in d.items():` or perhaps
- `for _, x := range xs { }`
- `for key, value := range d { }` or...
- `for { }`

So yeah, who knows... Anyway, I had to realize, I didn't really miss pointers at all, I'd be perfectly happy passing everything as references instead of values. But enough of this complaining, there are loads of cool things I like about Go immediately.

Goroutines are awesome. You need something done *soon-ish*, does not need to block the current thread, and don't necessarily care about the result? Just `go whatEver()`! Channels are also pretty neat if you do need some results, or maybe need the items produced by the goroutine one-by-one. Sounds like a super-lightweight (code-wise at least) queue, that you can simply `ch <- add` items to, or `take := <-ch` them from it. And you get a `panic` if something goes wrong, instead of just losing threads forever at runtime due to a deadlock, if you build with `-race`.

Splitting up a package into multiple files is also nice, something that could come in handy in Python sometimes. `gofmt` is something that should come with every programming language. Code styles driven from a single, [central place](https://blog.golang.org/go-fmt-your-code) simply removes all ambiguity on how code should look like, and could save you countless hours of arguing over whitespace and indentation on pull requests. I also like that the error propagation is very explicit, much harder to reason about not handling them properly out of laziness.

Implementing interfaces is done in a pretty clever way, I think, somewhat similar to Python's implicit interface idea, but actually checked at build time. Function references can also come in handy, when you want to pass them around, and you can do so without implicit anonymous classes and such. The `init()` function smells a bit like magic, but still sort of makes sense and can come in handy.

The built-in HTTP client library is pretty nice, but the [HTTP server](https://golang.org/pkg/net/http/) library is plain awesome! It makes it so easy to quickly implement a web server, with HTTP/2 support, without having include a full-blown web framework unnecessarily.

```go
package main

import (
	"io"
	"net/http"
)

func ping(w http.ResponseWriter, r *http.Request) {
	io.WriteString(w, "Ping!")
}

func pong(w http.ResponseWriter, r *http.Request) {
	io.WriteString(w, "Pong!")
}

func main() {
	http.HandleFunc("/ping", ping)
	http.HandleFunc("/pong", pong)
	http.ListenAndServe(":8080", nil)
}
```

What's even better, is the [httptest](https://golang.org/pkg/net/http/httptest/) package, that allows you to spin up servers for your unit tests easily, it's brilliant! You also get all sorts of data encoding, like JSON, XML, etc. from the standard library, with a simple and easy API too.

## Personal favorites

One of the main reasons I finally decided to have a proper look at Go, is to see why it is so popular with containerized applications. Because it compiles into native code, you can embed the final application in a minimal Docker image easily. If you can also compile it into a static binary, you can even have an image that contains *only* the binary, but nothing else at all. It's awesome! All you need is a [parameter](https://golang.org/cmd/cgo/), `CGO_ENABLED=0`, when building the application, and for the packages you use to be able to compile statically too *(I'm a little sad about SQLite)*.

Cross-compilation is super-easy as well, so I don't need to use base images with *QEMU* baked in anymore. There also tools out there, like [xgo](https://github.com/karalabe/xgo), that cross-compile the code for you, for as many target platforms as you want.

> I do realize, that I could do the same with C/C++, but I don't miss not having automatic garbage collection...

Because there is no virtual machine or interpreter involved in running the actual application, the memory footprint is also smaller. This is important for me, since my target platform in the home lab is *arm64*, with devices only having 1/2/4 GB memory.

## Verdict

I think Go is pretty awesome, and it can be a great tool for me, I can squeeze lots of benefits out of it for the apps I'm playing with. I haven't done any large projects with it yet, but there are some [fairly](https://github.com/moby/moby) [big ones](https://github.com/prometheus/prometheus) [out there](https://github.com/influxdata/telegraf), so I don't think that would change my mind. I'm looking forward to doing much more Go coding in the future! :)
