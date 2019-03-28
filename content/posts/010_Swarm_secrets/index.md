---
title: Swarm secrets made easy
date: 2018-02-28T21:13:55.000Z
slug: swarm-secrets-made-easy
disqusId: ghost-5a9714fe811680000147e4e5
tags:
  - Docker
  - Swarm
  - Automation
authors:
  - viktor
metaTitle: >
  Docker Swarm secret management made easy
metaDescription: >
  A recent Docker update came with an important change for service secrets, that enables an easier way to manage and update them when deploying Swarm stacks.
---

A recent Docker update came with a small but important change for service secrets and configs, that enables a much easier way to manage and update them when deploying Swarm stacks.

<!--more-->

*TL;DR* This post describes an automated way to create and update secrets or configs, when they are managed through a Composefile, and are deployed as a stack, along with the services using them. To avoid repeating *"secrets and configs"* all over the post, I'm going to talk about secrets, but the same thing applies to configs as well.

## Updating secrets the hard way

Docker Swarm [secrets](https://docs.docker.com/engine/swarm/secrets/) (and [configs](https://docs.docker.com/engine/swarm/configs/)) are immutable, which means, once created, their content cannot be changed. If you want to update the data they hold, you need to create them under a new name, and update the services using them to forget about the old secret, and reference the new one instead. Let's look at an example of how we could do it from the command line, without stacks first.

```shell
$ cat nginx.conf | docker secret create nginx-config-v1 -
ffrkdpnaw7jkrxmhyjfr4a275
$ docker secret ls
ID                          NAME                CREATED             UPDATED
ffrkdpnaw7jkrxmhyjfr4a275   nginx-config-v1     5 seconds ago       5 seconds ago
```

Our first secret is now created and is ready to use with services. Let's start one.

```shell
$ docker service create --detach=true --name server --secret source=nginx-config-v1,target=/etc/nginx/conf.d/default.conf,mode=0400 nginx:1.13.7
wlk2axginrhjb7vtkhovk2e12
$ docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE               PORTS
wlk2axginrhj        server              replicated          1/1                 nginx:1.13.7
$ docker service inspect server
[
    {
        "ID": "wlk2axginrhjb7vtkhovk2e12",
        "Version": {
            "Index": 84
        },
        "CreatedAt": "2018-02-26T07:17:43.36393357Z",
        "UpdatedAt": "2018-02-26T07:17:43.36393357Z",
        "Spec": {
            "Name": "server",
            "Labels": {},
            "TaskTemplate": {
                "ContainerSpec": {
                    "Image": "nginx:1.13.7",
                    "StopGracePeriod": 10000000000,
                    "DNSConfig": {},
                    "Secrets": [
                        {
                            "File": {
                                "Name": "/etc/nginx/conf.d/default.conf",
                                "UID": "0",
                                "GID": "0",
                                "Mode": 256
                            },
                            "SecretID": "ffrkdpnaw7jkrxmhyjfr4a275",
                            "SecretName": "nginx-config-v1"
                        }
                    ]
                },
                ...
```

You can see it from the `docker inspect` output, that the secret was successfully declared to be loaded at `/etc/nginx/conf.d/default.conf` inside the container. The mode `256` might look a little strange, that's actually `o400` in decimal, but let's double-check:

```shell
$ docker exec -it server.1.zog0eqk9oluux9q68ez54f2kx ls -l /etc/nginx/conf.d/default.conf
-r-------- 1 root root 21 Feb 26 07:33 /etc/nginx/conf.d/default.conf
```

*All good there!* OK, so let's update our configuration file now! As stated above, our only option is to create a new secret, and update the service with its reference.

```shell
$ cat nginx.conf | docker secret create nginx-config-v2 -
wnddsd2lm6kojlgcprhm1jkem
$ docker secret ls
ID                          NAME                CREATED             UPDATED
ffrkdpnaw7jkrxmhyjfr4a275   nginx-config-v1     24 minutes ago      24 minutes ago
wnddsd2lm6kojlgcprhm1jkem   nginx-config-v2     6 seconds ago       6 seconds ago
$ docker service update server --secret-rm nginx-config-v1 --secret-add source=nginx-config-v2,target=/etc/nginx/conf.d/default.conf,mode=0400 --update-order start-first --detach=true
server
$ docker service ps server
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
iyu33g3zibr3        server.1            nginx:1.13.7        moby                Running             Running 14 seconds ago
zog0eqk9oluu         \_ server.1        nginx:1.13.7        moby                Shutdown            Shutdown 11 seconds ago
$ docker service inspect server
[
    {
        "ID": "a9o72ncgj09ndph64my1dtkxf",
        "Version": {
            "Index": 1584
        },
        "CreatedAt": "2018-02-26T07:33:53.376179313Z",
        "UpdatedAt": "2018-02-26T07:40:28.712701204Z",
        "Spec": {
            "Name": "server",
            "Labels": {},
            "TaskTemplate": {
                "ContainerSpec": {
                    "Image": "nginx:1.13.7",
                    "Args": [
                        "sh"
                    ],
                    "TTY": true,
                    "StopGracePeriod": 10000000000,
                    "DNSConfig": {},
                    "Secrets": [
                        {
                            "File": {
                                "Name": "/etc/nginx/conf.d/default.conf",
                                "UID": "0",
                                "GID": "0",
                                "Mode": 256
                            },
                            "SecretID": "wnddsd2lm6kojlgcprhm1jkem",
                            "SecretName": "nginx-config-v2"
                        }
                    ]
                },
                ...
        "PreviousSpec": {
            "Name": "server",
            "Labels": {},
            "TaskTemplate": {
                "ContainerSpec": {
                    "Image": "nginx:1.13.7",
                    "Args": [
                        "sh"
                    ],
                    "TTY": true,
                    "DNSConfig": {},
                    "Secrets": [
                        {
                            "File": {
                                "Name": "/etc/nginx/conf.d/default.conf",
                                "UID": "0",
                                "GID": "0",
                                "Mode": 256
                            },
                            "SecretID": "ffrkdpnaw7jkrxmhyjfr4a275",
                            "SecretName": "nginx-config-v1"
                        }
                    ]
                },
                ...
```

We can see now, that the new service `Spec` refers to the `nginx-config-v2` secret. In case the update fails, Swarm could roll back to the previous version of the service definition, described in the `PreviousSpec` section, which still refers to the previous `nginx-config-v1` secret. This is one of the main reasons for immutable secrets.

> If we would update the secret itself, we would lose the previous content to rollback to.

Before moving on to the next section, let's clean up after ourselves.

```shell
$ docker service rm server
server
$ docker secret rm nginx-config-v1 nginx-config-v2
nginx-config-v1
nginx-config-v2
```

## Secrets in stacks

Let's look at a *less interactive* example for declaring our secret and the service that uses it. The sample above would roughly translate to this [Composefile](https://docs.docker.com/compose/compose-file/):

```yaml
version: '3.4'
services:

  server:
    image: nginx:1.13.7
    secrets:
      - source: nginx-config
        target: /etc/nginx/conf.d/default.conf
        mode: 0400

secrets:
  nginx-config:
    file: ./nginx.conf
```

To start the service, we're going to deploy this as a Swarm stack.

```shell
$ ls
nginx.conf    stack.yml
$ docker stack deploy -c stack.yml sample
Creating network sample_default
Creating service sample_server
$ docker secret ls
ID                          NAME                  CREATED              UPDATED
t6nxubtysp8912tu6wql96tbr   sample_nginx-config   About a minute ago   About a minute ago
$ docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE               PORTS
a4iyi0j4nr39        sample_server       replicated          1/1                 nginx:1.13.7
$ docker service inspect sample_server
[
    {
        "ID": "a4iyi0j4nr399x51mea9qrzdv",
        "Version": {
            "Index": 1592
        },
        "CreatedAt": "2018-02-26T07:51:41.65482285Z",
        "UpdatedAt": "2018-02-26T07:51:41.656180056Z",
        "Spec": {
            "Name": "sample_server",
            "Labels": {
                "com.docker.stack.image": "nginx:1.13.7",
                "com.docker.stack.namespace": "sample"
            },
            "TaskTemplate": {
                "ContainerSpec": {
                    "Image": "nginx:1.13.7",
                    "Labels": {
                        "com.docker.stack.namespace": "sample"
                    },
                    "Privileges": {
                        "CredentialSpec": null,
                        "SELinuxContext": null
                    },
                    "StopGracePeriod": 10000000000,
                    "DNSConfig": {},
                    "Secrets": [
                        {
                            "File": {
                                "Name": "/etc/nginx/conf.d/default.conf",
                                "UID": "0",
                                "GID": "0",
                                "Mode": 256
                            },
                            "SecretID": "t6nxubtysp8912tu6wql96tbr",
                            "SecretName": "sample_nginx-config"
                        }
                    ]
                },
                ...
```

This looks very similar to what we've seen before, our secret just got prefixed with the stack *namespace*, and has become `sample_nginx-config`. OK, *great*, but how can we update our configuration file now?

```shell
$ echo '# changed' >> nginx.conf
$ docker stack deploy -c stack.yml sample
failed to update secret sample_nginx-config: Error response from daemon: rpc error: code = InvalidArgument desc = only updates to Labels are allowed
```

So, *that* didn't work. We'll need to update the secret name.

```yaml
version: '3.4'
services:

  server:
    image: nginx:1.13.7
    secrets:
      - source: nginx-config-v2
        target: /etc/nginx/conf.d/default.conf
        mode: 0400

secrets:
  nginx-config-v2:
    file: ./nginx.conf
```

Well, we didn't gain much, compared two the initial example above. We now have to update the secret's name in two places. At least, you can deploy the changes now.

```shell
$ docker stack deploy -c stack.yml sample
Updating service sample_server (id: a4iyi0j4nr399x51mea9qrzdv)
$ docker service inspect sample_server
[
    {
        "ID": "a4iyi0j4nr399x51mea9qrzdv",
        "Version": {
            "Index": 24057
        },
        "CreatedAt": "2018-02-26T07:51:41.65482285Z",
        "UpdatedAt": "2018-02-26T14:10:43.921512677Z",
        "Spec": {
            "Name": "sample_server",
            "Labels": {
                "com.docker.stack.image": "nginx:1.13.7",
                "com.docker.stack.namespace": "sample"
            },
            "TaskTemplate": {
                "ContainerSpec": {
                    "Image": "nginx:1.13.7",
                    "Labels": {
                        "com.docker.stack.namespace": "sample"
                    },
                    "Privileges": {
                        "CredentialSpec": null,
                        "SELinuxContext": null
                    },
                    "StopGracePeriod": 10000000000,
                    "DNSConfig": {},
                    "Secrets": [
                        {
                            "File": {
                                "Name": "/etc/nginx/conf.d/default.conf",
                                "UID": "0",
                                "GID": "0",
                                "Mode": 256
                            },
                            "SecretID": "ux7vducroe1nm26re6mwa2o30",
                            "SecretName": "sample_nginx-config-v2"
                        }
                    ]
                },
                ...
```

What *can* we do, then?

## Secret names to the rescue

Thankfully for us, [version 3.5](https://docs.docker.com/compose/compose-file/compose-versioning/#version-35) of the Composefile schema has added the ability to define a [name for a secret](https://docs.docker.com/compose/compose-file/#secrets-configuration-reference) (or [config](https://docs.docker.com/compose/compose-file/#configs-configuration-reference)), that is different from its key in the *YAML* file. What is even better, is that this name also supports variable substitutions! *Yay!* Using a specific name for the secret will get Docker to create it with that exact name, without prefixing it with the stack namespace, or otherwise modified. Going back to the original Composefile, we only need to update the version to `3.5`, and define a name for the secret.

> You'll also have to be on Docker version `17.12.0` or higher.

```yaml
version: '3.5'
services:

  server:
    image: nginx:1.13.7
    secrets:
      - source: nginx-config
        target: /etc/nginx/conf.d/default.conf
        mode: 0400

secrets:
  nginx-config:
    file: ./nginx.conf
    name: nginx-config-v${CONF_VERSION}
```

Let's try deploying this stack again, and declare the configuration version as `3`.

```shell
$ CONF_VERSION=3 docker stack deploy -c stack.yml sample
Creating secret nginx-config-v3
Updating service sample_server (id: lvgug0p3fjgwu9elr9g947ecf)
$ docker secret ls
ID                          NAME                DRIVER              CREATED             UPDATED
v5iiguro7f868daznnesf02s8   nginx-config-v3                         40 seconds ago      40 seconds ago
$ docker service inspect sample_server
[
    {
        "ID": "lvgug0p3fjgwu9elr9g947ecf",
        "Version": {
            "Index": 660
        },
        "CreatedAt": "2018-02-28T20:16:46.444153797Z",
        "UpdatedAt": "2018-02-28T20:22:18.535445873Z",
        "Spec": {
            "Name": "sample_server",
            "Labels": {
                "com.docker.stack.image": "nginx:1.13.7",
                "com.docker.stack.namespace": "sample"
            },
            "TaskTemplate": {
                "ContainerSpec": {
                    "Image": "nginx:1.13.7@sha256:edc8182581fdaa985a39b3021836aa09a69f9b966d1a0ff2f338be6f2fbfe238",
                    "Labels": {
                        "com.docker.stack.namespace": "sample"
                    },
                    "Privileges": {
                        "CredentialSpec": null,
                        "SELinuxContext": null
                    },
                    "StopGracePeriod": 10000000000,
                    "DNSConfig": {},
                    "Secrets": [
                        {
                            "File": {
                                "Name": "/etc/nginx/conf.d/default.conf",
                                "UID": "0",
                                "GID": "0",
                                "Mode": 256
                            },
                            "SecretID": "v5iiguro7f868daznnesf02s8",
                            "SecretName": "nginx-config-v3"
                        }
                    ],
                    "Isolation": "default"
                },
                ...
$ echo '# changes' >> nginx.conf
$ CONF_VERSION=4 docker stack deploy -c stack.yml sample
Creating secret nginx-config-v4
Updating service sample_server (id: lvgug0p3fjgwu9elr9g947ecf)
$ docker secret ls
ID                          NAME                DRIVER              CREATED             UPDATED
v5iiguro7f868daznnesf02s8   nginx-config-v3                         2 minutes ago       2 minutes ago
f9fr4teephu3w7axpbv0yueuv   nginx-config-v4                         19 seconds ago      19 seconds ago
```

*Great!* The update worked this time. The *key* of the secret in the top-level mapping has to match the reference in the service configuration, but the name can be different. It's up to us now, how we define the value of the variable, *anything* goes.

```shell
$ CONF_VERSION="Not so fast!" docker stack deploy -c stack.yml sample
Creating secret nginx-config-vNot so fast!
failed to create secret nginx-config-vNot so fast!: Error response from daemon: rpc error: code = InvalidArgument desc = invalid name, only 64 [a-zA-Z0-9-_.] characters allowed, and the start and end character must be [a-zA-Z0-9]
```

*OK... within reason.*

I chose to take the *MD5* checksum of the source file, and use it as a suffix on the secret names. With `bash`, it could go something like this:

```shell
$ CONF_VERSION=$(md5sum nginx.conf | tr ' ' '\n' | head -1)
$ echo "${CONF_VERSION}"
0a49b7ca11ea768b5510e6ce146c5c23
$ docker stack deploy -c stack.yml sample
...
```

I use my [webhook-proxy app](https://github.com/rycus86/webhook-proxy) to execute a series of actions in response to an incoming webhook. One of the webhooks is from GitHub, when I push to a repo that has a stack *YAML*, defining some of the services in my [Home Lab](https://blog.viktoradam.net/tag/home-lab/). The app is written in Python, and it supports extending the pipelines with custom actions, imported from external Python files. One of the steps *(actions)* is responsible for preparing the environment variables for all the secrets and configs defined in the *YAML* file, before executing the `docker stack deploy` command *(which is [running in a container](https://github.com/rycus86/blog-content/blob/master/tutorials/010_Swarm_secrets/webhook_helper.py#L116), with just enough installed in it to do so)*. The relevant Python code looks like this below.

```python
import os
import re
import yaml
import hashlib

def iter_environment_variables(yaml_file, working_dir):
    if 'secrets' not in yaml_file:
        return

    for key, config in yaml_file['secrets'].items():
        path = config.get('file')
        if not path:
            continue

        path = os.path.join(working_dir, path)
        if os.path.exists(path):
            with open(path, 'rb') as secret_file:
                version = hashlib.md5(secret_file.read()).hexdigest()

            variable = os.path.basename(path).upper()
            variable, _ = re.subn('[^A-Z0-9_]', '_', variable)

            yield variable, version
            
if __name__ == '__main__':
    with open('stack.yml') as stack_yml:
        parsed = yaml.load(stack_yml.read())
        
    for key, value in iter_environment_variables(parsed, '.'):
        print('%s=%s' % (key, value))
```

The code basically parses the *YAML*, iterates through the top-level `secrets` dictionary, and for each element, takes the filename converted into all-uppercase with underscores, which will be the name of the environment variable to be set to the *MD5* hash of the target file. So, something like this:

```yaml
version: '3.5'
services:

  app:
    image: my/app:latest
    secrets:
      - source: app-config
        target: /var/secrets/app.config
      - source: app-log-config
        target: /var/secrets/logging.config
        
secrets:
  app-config:
    file: ./app.config.txt
    name: app-config-${APP_CONFIG_TXT}
  app-log-config:
    file: ./app.logs.xml
    name: app-log-config-${APP_LOGS_XML}
``` 

We can then invoke the stack deploy command, passing in these variables.

```python
secret_versions = {
    key: value
    for key, value in iter_environment_variables(stack_yaml, work_dir)
}
# set the variables for a child process
subprocess.call(['docker', 'stack', 'deploy', '-c', 'stack.yml'], env=secret_versions)
# or set the variables for a new docker container
docker.from_env().containers.run(
    image='deploy-image',
    command='docker stack deploy -c /var/tmp/stack.yml',
    environment=secret_versions,
    volumes=['./stack.yml:/var/tmp/stack.yml'],
    remove=True)
```

This way, the name of the secret should only change, when its content changes, avoiding unnecessary service updates, but *more importantly*, eliminating manual updates to the stack *YAML* files in multiple places. *Hooray!*

Hope this will help you as much as it has helped me!

*Big thanks to [@ilyasotkov](https://github.com/ilyasotkov) for this awesome [contribution](https://github.com/docker/cli/pull/668)!*
