# Concourse in a box

Table of content
----------------
- **[Introduction](#introduction)**
- **[Requirements](#requirements)**
- **[Usage](#usage)**
  + [_up_](#up)
  + [_rm_](#rm)
  + [_restart_](#restart)
- **[Links](#links)**
- **[License](#license)**

Introduction
------------
The `Concourse in a box` project goal is to instantiate a local Concourse CI cluster and blog site for personal needs. I run it on Mac OS 10.12.6, but code can be easily tweaked to run on Linux. YMMV. Feel free to fork and modify to fit your needs.

Requirements
------------
- MacOS, 8 GB RAM, 16 GB recommended.
- 5 GB of free disk space, 20 GB or more recommended until Docker fixes the qcow2 disk space eater [bug](https://github.com/docker/for-mac/issues/371).
- https://github.com/xenolf/lego/releases (it will be installed if missing).

Usage
-----
### up
Run `./ci --help` for command help.

The `./ci up` command instantiates a docker based Concourse CI cluster and associated services on the local computer. Each cluster service runs in its own container. Cluster features:
  - one Concourse web node
  - one Concourse worker
  - a private Docker registry
  - an Nginx reverse proxy server
  - a Postgress database
  - a ghost blog service

It also generates all internal certificates and passwords. In the end it logs in the current user into the docker registry and setup command line access to the concourse cluster using the `fly` target `.`.

### rm
The `./ci rm` command will teardown the Concourse CI cluster. This performs a `docker-compose down` to stop all related running containers then wipe out the cluster persistent state data form `./deployments`, i.e. Concourse database, credentials and Docker registry image content.

### restart
The `./ci restart` command performs a warm cluster restart. The `docker-compose.yml` and other config files like `nginx.conf` will be regenerated before the cluster is started again. The cluster state and credentials are otherwise preserved.

Links
-----
- [Source code repository](https://github.com/dcarastan/concourse-docker)
- [Concourse home page](https://concourse.ci/)
- [Lego](https://github.com/xenolf/lego/releases)

Follow me on [LinkedIn](https://www.linkedin.com/in/dcarastan/) [Twitter](https://twitter.com/dcarastan).

License
-------
The MIT License (MIT)

Copyright © 2017 Doru Carastan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
