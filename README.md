# Vagrant project for Mondrian Query Planner demo

This is nothing more than a simple proof of concept.  Not intended to be any sort of reference
for working code or features that will appear in the actual project.

The demo utilizes a custom branch of Mondrian that enables building a relational algebra context
plan out of simple MDX queries.

MySQL is still a dependency due to the queries that are fired off when the SchemaLoader runs.

The demo uses Apache Tajo as the execution engine.  Running off of a custom branch of Tajo
that enables passing in a JSON format context plan instead of a normal SQL query.

Tajo has a dependency on Apache Hadoop 2.2.0 which is installed in `/opt/hadoop-2.2.0`.

## Getting started

To build a fresh copy of the VM:

    $ git clone git@github.com:DEinspanjer/mondrian-queryplanner-demo.git
	$ cd mondrian-queryplanner-demo
    $ vagrant up
    
Alternatively, to just run a published build of the VM:
	TODO: package and upload to box
    $ vagrant box add mondrian-queryplanner-demo http://<path/to/file.box>
	$ vagrant up

To log in and begin working with the demo:

    $ vagrant ssh
    $ service mysql status
    $ cd /src/tajo-mondrian
	$ TODO: steps to run master and worker
	$ cd /src/mondrian-tajo
	$ TODO: steps to start Mondrian CmdRunner (or unit tests)


## Turning it off

To shut it all down:

	# To shut down the VM but leave it intact for later
    $ vagrant halt
	# To remove the VM (to enable rebuilding with fresh code, etc.
	$ vagrant destroy -f

