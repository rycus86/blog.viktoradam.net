---
title: Python microservices with Flask
date: 2017-12-16T21:22:30.000Z
slug: python-microservices-with-flask
disqusId: ghost-5a343e727db9250001a68715
image: /images/posts/unsplash/flask-cover.jpg
tags:
  - Flask
  - Python
  - Microservices
authors:
  - viktor
metaDescription: >
  This is the story of why I chose to write my web applications in Python using the open-source Flask framework.
---

This is the story of why I chose to write my web applications in Python using the open-source Flask framework.

<!--more-->

## Background

I'm a long-time Java developer and I like Java a lot - it's very powerful. But I have to admit: I just __love__ Python!

The language itself is easy to learn, very good for experimenting, forces you to write nicely indented code and tries to get you to do things in a sensible common way instead of having to come up with new solutions to already solved problems. Being an interpreted language, it is very quick to get changes up and running even if the application itself might run slower than it would on other languages - which is a completely fair trade-off when you're looking to roll out new apps or services quickly.

The simplicity and ease of the language is nicely complemented with the awesome [Flask](http://flask.pocoo.org) microframework. It is an unopinionated library that has everything you need from it but nothing more.

> The "micro" in microframework means Flask aims to keep the core simple but extensible.

The framework gives you a very convenient way of defining endpoints, handling the request data and building the HTTP responses. It does have a templating engine built-in which is very easy to use but just as easy to replace it should you prefer another module for it.

Let's look at a small example!

```python
import time
from flask import Flask, request, jsonify

app = Flask(__name__)
users_seen = {}

@app.route('/')
def hello():
    user_agent = request.headers.get('User-Agent')
    return 'Hello! I see you are using %s' % user_agent

@app.route('/checkin/<user>', methods=['POST'])
def check_in(user):
    users_seen[user] = time.strftime('%Y-%m-%d')
    return jsonify(success=True, user=user)

@app.route('/last-seen/<user>')
def last_seen(user):
    if user in users_seen:
        return jsonify(user=user, date=users_seen[user])
    else:
        return jsonify(error='Who dis?', user=user), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

We have a web application running with 3 endpoints in 25 lines. It doesn't do anything fancy but it is still impressive. The `@app.route` decorator is responsible for mapping HTTP requests onto functions and their return values back to HTTP responses. The return value can be a tuple with the elements being `(content, status_code, headers)` but of course we get sensible defaults if we omit the last two. The `jsonify` function wraps our response `dict` (which is given as keyword arguments in the example) as a JSON response with the appropriate content type headers.

## Flask &hearts; Websites

Using the routing decorators, it's super easy to map your website's pages to various functions to render them. You'll most likely want to use templates to return the actual HTML content instead of building it as strings in the Python code. Flask ships with the fantastic [Jinja2](http://jinja.pocoo.org/) templating engine that makes this easy-breezy.

Let's assume we have a template for the content on our pages and one for the rest of the page including header and footer.

```html
<!-- layout.html -->
<html>
    <head>
        <title>Fancy website</title>
        <link rel="stylesheet" type="text/css"
              href="/assets/awesome-style.min.css"/>
    </head>
    <body>
        <div class="wrapper">
            <nav>
                <ul>
                    {% for page in pages %}
                    <li>
                        <a href="{{ page.href }}">{{ page.title }}</a>
                    </li>
                    {% endfor %}
                </ul>
            </nav>
            <main>
                {% include 'content.html' %}
            </main>
            <footer>
                <div class="left">2017</div>
            </footer>
        </div>
    </body>
</html>
```

The main layout will ensure the same CSS is loaded for every page rendered with this template and that they will include our standard navigation and footer. The area that is different across pages is included as a separate snippet.

```html
<!-- content.html -->
<div class="content">
    <h3>{{ heading|capitalize }}</h3>
    <div>
        {{ body_text|safe }}
    </div>
</div>
```

Jinja2 supports a wide range of [built-in filters](http://jinja.pocoo.org/docs/2.10/templates/#list-of-builtin-filters) like the `capitalize` and `safe` in the example. To make use of these templates we can have a handler function like the one below.

```python
from flask import Flask, render_template

app = Flask(__name__)

@app.route('/sample-page')
def sample_page():
    return render_template('layout.html',
        heading='Sample section',
        body_text='Very important<br/>message here!',
        pages=[
            dict(title='Home', href='/'),
            dict(title='About', href='/about')
        ]
    )
```

On my [demo site](https://demo.viktoradam.net), I'm using Markdown to render contents for the cards in the grid which is then inserted into their places by the templates. In this case, the `safe` filter is necessary to avoid Jinja2 stripping out the HTML tags from the text. Also notice that you can use dots to index values out of a dictionary - this is super convenient to use in practice!

*If you're interested about Flask and Jinja2, make sure to check out their extensive documentation!*

## Flask &hearts; Microservices

I found the framework very easy to work with for developing RESTful services working with JSON. The simplicity of both the framework and the language itself allows you to write small, concise request handler functions.

```python
@app.route('/item/<item_type>', methods=['POST', 'PUT'])
def update_item(item_type):
    is_update = request.method == 'PUT'
    result = engine.process(request.json, update=is_update)
    if result:
        return jsonify(result)
    else:
        return 'Nope :(', 400
```

You can also easily add extra request processing logic around your endpoints. For example, if you have one doing some expensive operation, you could memoize the results for some time instead of repeating it on every call.

```python
@app.route('/hard/work')
@cache.memoize(timeout=30 * 60)
def expensive_operation():
    return look_busy_while_doing_this()
```

There are plenty of Flask extensions available for [caching](https://pythonhosted.org/Flask-Cache/), managing [CORS](http://flask-cors.readthedocs.io/en/latest/api.html) headers or exposing [metrics](https://github.com/rycus86/prometheus_flask_exporter) for [Prometheus](https://prometheus.io/) for example and many-many more. Try your favorite search engine if you're looking for something that is not built into Flask. Don't worry if you don't find anything, it is super easy to write your own extension and wire it in.

Since it's so quick and easy to make changes to our existing application, it is important to make sure we know they will actually work.

## Testing

Writing tests for Flask applications couldn't be any easier. If you want, your full application with all its endpoints can be loaded and exercised with simple instructions.

If you have a module called `fancyapp` like this:

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/say/something')
def say_something():
    return 'Say something'

@app.route('/tell/something', methods=['POST'])
def tell_something():
    if 'message' in request.json:
        return jsonify(response='OK, got it',
                       message=request.json.get('message'))
    else:
        return 'Uh-oh', 400
```

We have two endpoints here with three possible outcomes - plus some oddities here and there. To keep things simple, let's test them with the `unittest` library that comes with Python by default.

```python
import unittest
import json
import fancyapp

class FlaskTest(unittest.TestCase):
    def setUp(self):
        fancyapp.app.testing = True
        self.client = fancyapp.app.test_client()
    
    def test_say_something(self):
        response = self.client.get('/say/something')
        
        self.assertEqual(response.status_code, 200)
        self.assertIn('text/html', response.content_type)
        self.assertEqual(response.charset, 'utf-8')

        content = response.data

        self.assertEqual(content, 'Say something')
    
    def test_tell_something_success(self):
        response = self.client.post(
            '/tell/something',
            data=json.dumps(dict(message='secret')),
            content_type='application/json'
        )
        
        self.assertEqual(response.status_code, 200)
        self.assertIn('application/json', response.content_type)

        result = json.loads(response.data)

        self.assertEqual(result.get('response'), 'OK, got it')
        self.assertEqual(result.get('message'), 'secret')
    
    def test_tell_something_fails(self):
        response = self.client.post(
            '/tell/something',
            data=json.dumps(dict(gossip='definitely not a message')),
            content_type='application/json'
        )
        
        self.assertEqual(response.status_code, 400)
```

*See how easy it is?*

If you want to execute tests against a running instance (not in testing mode), then you could use something like the `requests` module and invoke the endpoints using it. It has similar functions as the Flask test client but it is way more powerful. I use it in a couple of projects on the CI system to test my apps running in Docker containers with unit tests being executed on the build host.

## Notes on configuration

If you're planning to run your Flask applications in Docker containers, like I do, make sure every setting is configurable through environment variables or Docker configs/secrets. For example, Flask starts the server listening on `127.0.0.1` and port `5000` by default, but instead of hard-coding the settings that make sense to your environment *today*, make them configurable with sensible defaults - I tend to use this:

```python
app.run(host=os.environ.get('HTTP_HOST', '127.0.0.1'),
        port=int(os.environ.get('HTTP_PORT', '5000')))
```

If you want it to accept connections from any remote addresses, use `host='0.0.0.0'`. The `run` method accepts a lot more arguments and I'd like to mention two of those:

- `threaded` is a boolean that controls whether your application can handle multiple requests simultaneously and is `False` by default, so make sure it's enabled if it makes sense for your use-case
- `debug` is another boolean that enables the [debug mode](http://flask.pocoo.org/docs/0.12/quickstart/#debug-mode) on the application with live-reload and an interactive debugger - super helpful for local development but make sure it's off in production

When I host my Flask apps with Docker, I run them as a non-root user, so even if they get hacked somehow, the damage would be less significant (at least I hope so). A final Docker related note: the default shutdown signal for containers is `SIGTERM` which Flask does very little with by default. To get your apps to shut down quickly, specify the interrupt signal as stop signal. An easy way of doing so is adding `STOPSIGNAL SIGINT` to the Dockerfile.

## Build & pipelines

I use [Travis](https://travis-ci.org/) for continuous integration and to upload the application images to [Docker Hub](https://hub.docker.com/) which will in turn trigger the deployment to the servers. I also build and test some of the apps for multiple Python versions which is super easy with Travis. A typical build pipeline looks like this:

1. Installs the requirements with `pip install -r requirements.txt`
2. Executes the unit tests with coverage using something like `PYTHONPATH=src python -m coverage run --branch --source=src -m unittest discover -s tests -v`
3. Generates the coverage reports for humans (`python -m coverage report -m`) and for the code quality services (`python -m coverage xml`)
4. Builds Docker images and pushes them to Docker Hub

This is a somewhat simplified version of what is actually happening but I plan to expand on the bits that are left out here in future posts. After the image is uploaded to Docker Hub, a webhook is triggered from there that will eventually result in pulling it on the target servers and replacing/restarting the running instance with the newer version. When it's in place, an [Nginx](https://www.nginx.com/) reverse proxy is automatically reconfigured to allow traffic being routed to the new container hosting the latest and greatest version of the application.

Keep an eye out on this blog if you want to find out more about my continuous deployment process!
