---
title: Gating on README updates
date: 2018-05-08T07:39:45.000Z
slug: gating-on-readme-updates
disqusId: ghost-5aee25f70d55d100019f710d
image: /images/posts/2018/05/gating-readmes-min.jpg
tags:
  - Testing
  - Programming
  - Open-Source
authors:
  - viktor
metaTitle: >
  Gating on README updates, or how to test for missed documentation
metaDescription: >
  Maybe you also often forget to update your READMEs as new features get added? How can we avoid this? Add unit tests for it, and make your build fail!
---

If you're like me, you perhaps also often forget to update your README files in the heat of coding up the latest features in your projects. How can we make sure that it happens in a timely manner? Add unit tests for it, and make your build fail!

<!--more-->

## Motivation

I struggle a lot with this on my projects. I work hard on implementing some new functionality, write the tests for it, then start fighting with the build issues on Travis. Somewhere in this process, I should add a sentence or a paragraph on the new feature to the README, but it's easy to miss it. When I finally do remember to do it, I just add a task for it to my Trello board, then either get around to do it eventually, or it slowly wastes away in the *TODO* column, virtually every new idea coming on the board in front of it.

I have a few projects that need to deal with configuration files, and new functionality usually involves supporting new properties in the config. Without the need for a full-blown documentation site, or even a Wiki, I tend to just list out all these in the project README, along with some explanation, default values, maybe examples. I also sometimes include the command line help output the app produces. Most argument parsers allow you to define help strings with the recognized options, like [argparse](https://docs.python.org/3/library/argparse.html) in Python or [flag](https://golang.org/pkg/flag/) in Go, so it makes sense to reuse their nicely formatted output.

Similarly to the help string, I thought it would be nice to generate a documentation block based on the configuration options *currently* supported by the project, so I decided to look into this. Once you can generate these outputs, it's much easier to just copy-paste it in the right place in the README. But wait, there's more! If you did this much, you can also check, programmatically, if you have actually put the updated output in the documentation.

Let me walk you through a simple implementation I use on a new app I'm working on.

## Command line usage

Let's say you have an application that supports some command line flags. In the example I'm going to talk about here, I just use the simplest, the `flag` package of Go.

```go
package config

import (
	"flag"
)

var (
	pids, volumes, logs, pull bool
)

type Configuration struct {
	SharePids    bool
	ShareVolumes bool
	StreamLogs   bool
	AlwaysPull   bool
}

func init() {
	flag.BoolVar(&pids, "pids", true, "Enable (default) or disable PID sharing")
	flag.BoolVar(&volumes, "volumes", true, "Enable (default) or disable volume sharing")
	flag.BoolVar(&logs, "logs", false, "Stream logs from the components")
	flag.BoolVar(&pull, "pull", false, "Always pull the images for the components when starting")
}

func Parse() *Configuration {
	flag.Parse()

	return &Configuration{
		SharePids:    pids,
		ShareVolumes: volumes,
		StreamLogs:   logs,
		AlwaysPull:   pull,
	}
}
```

Simple enough. We set up 4 boolean flags, so we can parse them later in the `Parse()` function. The usage string for the above looks like this:

```text
Usage of /podlike:
  -logs
    	Stream logs from the components
  -pids
    	Enable (default) or disable PID sharing (default true)
  -pull
    	Always pull the images for the components when starting
  -volumes
    	Enable (default) or disable volume sharing (default true)
```

We know the input now, and we also know what we need present in the README. The test below gets the *actual* application code to generate this output string, reads the README file, then simply checks if the usage text is in there.

```go
package config

import (
	"flag"
	"fmt"
	"io/ioutil"
	"strings"
	"testing"
)

func TestReadmeIsUpToDate(t *testing.T) {
	flag.CommandLine = flag.NewFlagSet("/podlike", flag.ContinueOnError)
	setupVariables()

	output := strOutput{}

	flag.CommandLine.SetOutput(&output)
	flag.CommandLine.Usage()

	readmeData, err := ioutil.ReadFile("../README.md")
	if err != nil {
		t.Fatal(err)
	}

	if !strings.Contains(string(readmeData), output.Text) {
		t.Error("The command like usage is not found in the README")
		fmt.Println(output.Text)
	}
}

type strOutput struct {
	Text string
}

func (s *strOutput) Write(p []byte) (n int, err error) {
	s.Text += string(p)
	return len(p), nil
}
```

When a new command line flag is added, or the usage string changes for an existing one, this simple test will make sure that the build fails, if the README was not updated with the change.

## Configuration properties

This one was a bit trickier to implement, but it probably has more value as well. The configuration for this application accepts a subset of the properties that a [Compose file](https://docs.docker.com/compose/compose-file/compose-file-v2/) supports. The Compose file has a [JSON schema](https://github.com/docker/compose/blob/master/compose/config/config_schema_v2.4.json) that describes the possible properties, and their nested properties, if any. I want to have a section in the README, that lists out all of them, that the application does __not__ support, for the moment anyway. This also makes it easy to update support for a newer version of the schema, and review what new properties the app should now handle, or document the reason why it doesn't. During development, it is a good guide too, to know what is left to implement.

So, the test reads the JSON schema into a `map`, iterates through the properties, nested or otherwise, and builds up a YAML text with every one of them in it. It wouldn't actually be a valid configuration, because of the values, but I don't really need it to be. I just want to check if there are any parsing errors due to missing fields in the Go `struct` the application uses.

```go
package engine

import (
	"encoding/json"
	"fmt"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"regexp"
	"sort"
	"testing"
)

func TestSchema(t *testing.T) {
	// read the JSON schema
	schemaData, err := ioutil.ReadFile("../testdata/config_schema_v2.4.json")
	if err != nil {
		t.Fatal(err)
	}

	var schema map[string]interface{}

	// convert the schema into a map
	if err := json.Unmarshal(schemaData, &schema); err != nil {
		t.Fatal(err)
	}

	allDefinitions := schema["definitions"].(map[string]interface{})
	serviceDefinition := allDefinitions["service"].(map[string]interface{})
	serviceProperties := serviceDefinition["properties"].(map[string]interface{})

	// the target YAML text
	testProperties := "image: testing\n"

	// go through the properties, and their nested properties, etc.
	iterProperties(serviceProperties, allDefinitions, "", &testProperties)

	// at this point, we have the YAML text with all the possible properties in it
	// let's try to convert it into our internal representation
	err = yaml.UnmarshalStrict([]byte(testProperties), &Component{})

	if err != nil {
		yamlErrors := err.(*yaml.TypeError).Errors

		unsupported := make([]string, 0, len(yamlErrors))

		// collect the errors as unsupported options
		for _, e := range yamlErrors {
			unsupported = append(unsupported, e)
		}

		sort.Sort(sort.StringSlice(unsupported))

		// build up the documentation we expect
		expectedDescription := "## Unsupported properties\n\n"
		// and also build it as a regular expression
		expectedPattern := expectedDescription

		for _, key := range unsupported {
			expectedDescription += "- `" + key + "`\n"
			expectedPattern += "- `" + key + "`.*\n"
		}

		// now read the actual README file in its current state
		readmeData, err := ioutil.ReadFile("../README.md")
		if err != nil {
			t.Fatal(err)
		}

		readme := string(readmeData)

		// and finally check the expected section is in there
		if !regexp.MustCompile(expectedPattern).MatchString(readme) {
			t.Error("The list of unsupported properties is not found in the README")

			// print the expected text for an easy copy-paste
			fmt.Println(expectedDescription)
		}
	} else {
		// we don't expect to support all the possible options
		// due to the nature of the app (some are known to be unsupported)
		t.Fatal("The YAML unmarshalling is expected to fail")
	}
}

// not relevant implementation detail for this post
func iterProperties(...) {
  ...
}
```

OK, this was a bit long, but I tried to add some comments at each of the important steps. In the end, we get a copy-paste ready output, if the documentation is missing. The test also allows for changing the output, for example to include some details or comments for each of the properties. If you're interested, you can see it in the project's [README](https://github.com/rycus86/podlike/blob/master/README.md#unsupported-properties).

Having these tests in place, your build will simply fail on your favorite CI system, which runs your builds and checks anyway, so you'll know pretty soon if you missed an important documentation update. To further shorten the feedback loop, you could also set up a Git pre-commit hook, and run these tests there, along with your other lints, so you'd learn about this missing step even before committing the latest changes.

## Conclusion

These gates might not be as exciting *technically*, than failing on memory leaks automatically, or drops in code quality or test coverage. I still think they can be a nice aid during development, to help not losing focus of important but not absolutely necessary changes. Keeping your README up to date should benefit anyone interested in finding out more, or getting help with your project, so it is well worth it.

Let me know if you have any comments, observations or thoughts about all this! Thank you!
