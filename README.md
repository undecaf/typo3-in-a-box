# TYPO3 in a box ‒ a versatile TYPO3 8.7/9.5/10.1 image

[![Build Status](https://travis-ci.com/undecaf/typo3-in-a-box.svg?branch=master)](https://travis-ci.com/undecaf/typo3-in-a-box)
[![Latest release](https://img.shields.io/github/release/undecaf/typo3-in-a-box.svg)](https://github.com/undecaf/typo3-in-a-box)
![Image Size](https://img.shields.io/microbadger/image-size/undecaf/typo3-in-a-box/latest.svg)

This project provides a ready-to-run and extensive
[TYPO3](https://typo3.org/)&nbsp;8.7/9.5/10.1 installation as a single container image.
It is widely configurable, and thus it addresses TYPO3 editors and administrators
as well as integrators and extension developers. Builds of the TYPO3 development
branches are available, too.

The image is based on [Alpine Linux](https://alpinelinux.org/), comes
with up-to-date versions of [Apache](https://httpd.apache.org/),
[PHP](https://php.net/) and [ImageMagick](https://www.imagemagick.org/) 
and has [SQLite](https://www.sqlite.org/), [MariaDB](https://mariadb.org/) and
[PostgreSQL](https://www.postgresql.org/) built in.
It is available at [Docker Hub](https://hub.docker.com/r/undecaf/typo3-in-a-box),
uses well below 500&nbsp;MB disk space and can run in
[Docker](https://www.docker.com/) and [Podman](https://podman.io/).
No additional container is required, and only a browser is needed
at the host to get going.


Setting up and managing usage scenarios is simplified by a
[shell script](#t3-shell-script-reference) for Linux and macOS.

TYPO3 directories can be 
[mapped from the container to the host](#using-an-ide).
You can use your favorite IDE at the host to
[develop for TYPO3](#developing-for-typo3) in the container without having to
fiddle with host permissions.

[Secure connections](#https-connections),
[logging](#logging),
[Composer Mode](https://getcomposer.org/#Composer_Mode),
[remote debugging with XDebug](#debugging-with-xdebug) and
[database access](#accessing-the-typo3-database) are supported.
Your personal extension directories can be
[excluded from updates made by Composer](#preventing-composer-from-overwriting-your-changes).


## Overview

![Parts of this project in a block diagram: container for TYPO3, shell script, browser and IDE](https://undecaf.github.io/typo3-in-a-box/img/overview.png)


## Contents

-   [Running TYPO3](#running-typo3)
    -   [Quick start](#quick-start)
    -   [`t3` shell script](#t3-shell-script)
    -   [Quick start with `t3`](#quick-start-with-t3)
    -   [MariaDB and PostgreSQL](#mariadb-and-postgresql)
    -   [HTTPS connections](#https-connections)
    -   [Logging](#logging)
-   [Developing for TYPO3](#developing-for-typo3)
    -   [Using an IDE](#using-an-ide)
    -   [Setting the container environment](#setting-the-container-environment)
    -   [Composer](#composer)
    -   [Debugging with XDebug](#debugging-with-xdebug)
    -   [Accessing the TYPO3 database](#accessing-the-typo3-database)
-   [Managing multiple TYPO3 instances](#managing-multiple-typo3-instances)
-   [`t3` shell script reference](#t3-shell-script-reference)
    -   [Getting help](#getting-help)
    -   [Common options](#common-options)
    -   [`t3 run`](#t3-run)
    -   [`t3 stop`](#t3-stop)
    -   [`t3 logs`](#t3-logs)
    -   [`t3 env`](#t3-env)
    -   [`t3 composer`](#t3-composer)
    -   [`t3 shell`](#t3-shell)
    -   [`t3 mount`](#t3-mount)
    -   [`t3 unmount`](#t3-unmount)
    -   [Options](#options)
    -   [Host environment variables](#host-environment-variables)
    -   [Container environment variables](#container-environment-variables)
-   [Credits to ...](#credits-to-)
-   [Licenses](#licenses)


## Running TYPO3

### Quick start

To start the latest TYPO3 version with an SQLite database in a container,
enter this command:

```bash
$ docker run \
    -v typo3-root:/var/www/localhost \
    -v typo3-data:/var/lib/typo3 \
    -p 127.0.0.1:8080:80 \
    undecaf/typo3-in-a-box
```

If you prefer
[working rootless](https://de.slideshare.net/AkihiroSuda/rootless-containers)
with [Podman](https://podman.io/) then substitute `podman` for `docker`.

Next, browse to [`http://localhost:8080`](). This starts the TYPO3 installation wizard. 
When asked to select a database, choose `Manually configured SQLite connection` and
continue through the remaining dialogs to the TYPO3 login dialog.

Volumes `typo3-root` and `typo3-data` now persist the state of the TYPO3 instance
across container lifecycles.


#### Online documentation

In order to view the version of this README file that matches the version of
the running TYPO3 instance, browse to [`http://localhost:8080/readme.html`](http://localhost:8080/readme.html).

---

### `t3` shell script

Scenarios that are more lifelike will likely require complex Docker or Podman command lines.

In order to simplify usage, the
[`t3` shell script](https://raw.githubusercontent.com/undecaf/typo3-in-a-box/master/t3)
has been provided for Linux and macOS.
It enables you to:
-   configure and run a TYPO3 container;
-   stop this container and optionally remove it;
-   mount the TYPO3 root volume at a working directory at the host;
-   access the databases from the host; 
-   modify the TYPO3 environment even while the container is running;
-   run Composer within the TYPO3 container;
-   and it provides defaults for all options to let you get started quickly.

See the [`t3` reference](#t3-shell-script-reference) for a complete description.


#### Installing `t3`

This script is
[avaliable for download here](https://raw.githubusercontent.com/undecaf/typo3-in-a-box/master/t3).
It should be saved to a directory which is part of the search path, e.g.
`/usr/local/bin`, and it must be made executable, e.g.

```bash
$ sudo chmod 755 /usr/local/bin/t3
```

---

### Quick start with `t3`

To run a TYPO3 container [as in the example above](#quick-start) with `t3`,
simply type:

```bash
$ t3 run   # abbreviated: t3 r
```

`t3` chooses between [Docker](https://www.docker.com/) and 
[Podman](https://podman.io/) engines
automatically, depending on which one is installed. If both are, Podman in
[rootless mode](https://opensource.com/article/19/2/how-does-rootless-podman-work)
will be preferred.

To stop and remove the container, enter

```bash
$ t3 stop -R
```

State is preserved in volumes `typo3-root` and `typo3-data` so that a subsequent
`t3 run` command will resume from where you left off.

---

### MariaDB and PostgreSQL

MariaDB or PostgreSQL is optional for TYPO3&nbsp;9.5+ but is required for TYPO3&nbsp;8.7.

The following example starts TYPO3 and a MariaDB server in the same container,
preserving state in volumes `typo3-root` and `typo3-data` and exposing TYPO3 and 
MariaDB on ports `127.0.0.1:8080` and `127.0.0.1:3306`, respectively:

```bash
$ t3 run -D maria
```

To use PostgreSQL as the TYPO3 database and have it exposed on `127.0.0.1:5432`,
replace `-D maria` with `-D postgres`.

More [`t3 run` options ](#t3-run) are available to configure the container
according to your needs.

Enter

```bash
$ t3 stop
```

to stop the container. If you wish to have the stopped container removed, too,
type `t3 stop -R` instead.


#### Database credentials

Database credentials can be defined by [host environment variables](#host-environment-variables)
`T3_DB_NAME`, `T3_DB_USER`, `T3_DB_PW` and `T3_DB_ROOT_PW`. If not set then the database name, user and password all default to `t3` and `T3_DB_ROOT_PW` defaults
to `toor`.

---

### HTTPS connections

By default, TYPO3 is served both at `http://127.0.0.1:8080` and at
`https://127.0.0.1:8443` at the host. A self-signed certificate is used for HTTPS.

[`t3 run` options ](#t3-run) can be used to change the port mapping and to specify
a custom SSL certificate.

---

### Logging

Events at startup and during operation of Apache, PHP, MariaDB and 
PostgreSQL are logged in `syslog` format. These logs are captured
by the container engine and can be viewed at the host:

```bash
$ t3 logs
Sep 20 07:02:45 typo3 syslog.info syslogd started: BusyBox v1.30.1
Sep 20 07:02:45 typo3 local0.info root: TYPO3 10.0, container image tags: 10.0-latest (built on Fri, 20 Sep 2019 07:02:43 +0000)
Sep 20 07:02:45 typo3 local0.info root: Alpine Linux 3.10.2
Sep 20 07:02:45 typo3 local0.info root: Server version: Apache/2.4.41 (Unix) Server built:   Aug 20 2019 08:54:21
Sep 20 07:02:45 typo3 local0.info root: PHP 7.3.9 (cli) (built: Aug 30 2019 00:12:57) ( NTS ) Copyright (c) 1997-2018 The PHP Group Zend Engine v3.3.9, Copyright (c) 1998-2018 Zend Technologies
  ...
Sep 20 08:56:56 typo3 local1.notice httpd: 10.0.2.2 "GET /typo3/install.php HTTP/1.1" 200 1155
Sep 20 08:56:56 typo3 local1.notice httpd: 10.0.2.2 "GET /typo3/sysext/backend/Resources/Public/Css/backend.css?b0cad3b70147b08404c246aecb97120be7a854d2 HTTP/1.1" 200 305919
Sep 20 08:56:56 typo3 local1.notice httpd: 10.0.2.2 "GET /typo3/sysext/install/Resources/Public/JavaScript/RequireJSConfig.js?b0cad3b70147b08404c246aecb97120be7a854d2 HTTP/1.1" 200 901
  ...
```

For a live view, add option&nbsp;`-f` (press `Ctrl-C` to close 
that view). There are more [`t3 logs` options](#t3-logs) that 
let you control the amount of information that is shown.

---

## Developing for TYPO3

This section addresses mainly integrators and extension developers.
It describes how to use this TYPO3 image for developing or customizing
TYPO3 extensions or for otherwise altering the source code of your TYPO3
installation.


### Using an IDE

In order to work on your TYPO3 installation in an IDE, the TYPO3 root directory 
needs to be exposed to a working directory at the host where the current user has 
sufficient (read and write) permissions. This is usually not the case at the container volume mount point.

`t3` uses the [bindfs](https://bindfs.org/) utility  (available for Debian-like and
macOS hosts) to solve this problem. See below for what is happening [behind the scenes](#behind-the-scenes).

First, [bindfs](https://bindfs.org/) needs to be installed from the repositories
of your system. For macOS, [osxfuse](https://osxfuse.github.io/) is required beforehand.

When starting TYPO3, specify the path of the desired working directory
(e.g. `~/ide-workspace/typo3-root`) as the `-v` option to `t3 run`,
i.e. in the simplest case

```bash
$ t3 run -v ~/ide-workspace/typo3-root
```

This will
-   start the container,
-   create a TYPO3 volume having the working directory basename
    (`typo3-root`) as its name,
-   make the TYPO3 volume content appear in the working directory
    (`~/ide-workspace/typo3-root`) as if it were owned by the current user.

Thus, the TYPO3 instance can now be edited in the IDE. File changes,
creates and deletes will be passed in both directions between working directory
and container with the current user's UID/GID mapped to container UIDs/GIDs.

Stopping the TYPO3 container will unmount the working directory automatically.

Working directories can be mounted and unmounted independenty of whether a container
is running or even exists, see [`t3 mount`](#t3-mount) and [`t3 unmount`](#t3-unmount).


#### Editing a stopped TYPO3 instance

Whenever there is a persistent TYPO3 volume, you can edit that TYPO3 instance
even if the container is not running or does not even exist. Just mount your 
working directory on top of the volume:

```bash
$ t3 mount ~/ide-workspace/typo3-root   # abbreviated: t3 m ...
```

As with [`t3 run -v`](#using-an-ide), the name of the volume is equal to the working
directory basename.

When you are finished, unmount your working directory again:

```bash
$ t3 unmount ~/ide-workspace/typo3-root   # abbreviated: t3 u ...
```


#### Behind the scenes

The TYPO3 root directory is accessible outside of the container at the volume mount
point of e.g. `typo3-root` which can be obtained by `inspect`ing
the container. The directory content, however, is owned by a system account and
cannot be edited by the current user, e.g.:

```bash
$ sudo ls -nA $(sudo docker volume inspect --format '{{.Mountpoint}}' typo3-root)

-rw-r--r--  1 100 101   1117 Mai  3 23:00 composer.json
-rw-r--r--  1 100 101 155056 Mai  3 23:01 composer.lock
drwxr-xr-x  6 100 101   4096 Mai  3 22:58 public
drwxrwsr-x  7 100 101   4096 Mai  3 23:02 var
drwxr-xr-x 15 100 101   4096 Mai  3 23:01 vendor
```

With Podman, the content is owned by one of the current user's sub-UIDs which 
leads to the same situation.

[bindfs](https://bindfs.org/) is a [FUSE](https://github.com/libfuse/libfuse#about)
filesystem that resolves this situation. It can provide a bind-mounted _view_ of
the files and directories in a volume with their UIDs and GIDs
mapped to your own UID and GID. This does not affect UIDs and GIDs seen by the
container.

---

### Setting the container environment

[Container environment variables](#container-environment-variables) control the
time zone and language inside the container, TYPO3 mode, PHP settings and 
Composer operation.

These variables can be set by `t3 run` option&nbsp;`--env`, e.g.

```bash
$ t3 run --env MODE=dev --env PHP_post_max_size=500K
```

Command `t3 env` can modify most settings also while the container is running,
e.g. in order to change the TYPO3 mode or to experiment with different `php.ini` settings:

```bash
$ t3 env MODE=xdebug PHP_post_max_size=1M
```

Container environment settings are lost when the container is removed.

---

### Composer

By default, the
[TYPO3 Extension Manager](https://docs.typo3.org/m/typo3/tutorial-getting-started/master/en-us/ExtensionManager/Index.html)
is responsible for adding/removing extensions.

In [Composer Mode](https://getcomposer.org/#Composer_Mode), however,
command `t3 composer` lets you add/remove TYPO3 extensions. To have TYPO3 operate
in this mode, the `t3 run` option&nbsp;`-c on` must be specified.

`t3 composer` accepts Composer command line options and is equivalent to running
[Composer](https://getcomposer.org/) _inside the container_,
e.g.

```bash
$ t3 composer require bk2k/bootstrap-package   # abbreviated: t3 c ...
```

`t3 composer` and the `composer` script found in the container always act
on the TYPO3 root directory.
Neither Composer nor PHP have to be installed on the host.

[XDebug should be deactivated](#activate-xdebug-in-the-container) before 
running Composer because it might slow down Composer significantly.


#### Preventing Composer from overwriting your changes

If you are continuing development of an extension which is already available
from a repository, then running `t3 composer update` may overwrite your changes
with the (older) version of that extension from the repository.

In order to prevent this, set the 
[container environment variable](#container-environment-variables) 
`COMPOSER_EXCLUDE` to a colon-separated list of _subdirectories_ of 
`/var/www/localhost` which are to be excluded from changes made by Composer, e.g.

```bash
$ t3 env COMPOSER_EXCLUDE=public/typo3conf/ext/myt3ext
```

---

### Debugging with XDebug

#### Set up your IDE for XDebug

-   PhpStorm et al.: [Debugging within a PHP Docker Container using IDEA/PhpStorm and Xdebug: Configure IntelliJ IDEA Ultimate or PhpStorm](https://phauer.com/2017/debug-php-docker-container-idea-phpstorm/#configure-intellij-idea-ultimate-or-phpstorm)
-   VSCode: install 
    [PHP Debug](https://github.com/felixfbecker/vscode-php-debug),
    add the following configuration to your `launch.json` file
    and start debugging with this configuration. If necessary, replace
    `typo3-root` with the actual [bindfs mount point](#using-an-ide) of
    the TYPO3 volume:

    ```json
    {
        "name": "Listen for XDebug from container",
        "type": "php",
        "request": "launch",
        "port": 9000,
        "pathMappings": {
            "/var/www/localhost": "${workspaceRoot}/typo3-root"
        }
    }
    ```


#### Install browser debugging plugins

Although not strictly required, debugging plugins make starting
a XDebug session more convenient.
[Browser Debugging Extensions](https://www.jetbrains.com/help/phpstorm/browser-debugging-extensions.html#Browser_Debugging_Extensions.xml)
lists recommended plugins for various browsers.


#### Activate XDebug in the container

Unless the container was started already with `--env MODE=xdebug` or
[host environment variable](#host-environment-variables) `T3_MODE=xdebug`,
this mode needs to be activated now:

```bash
$ t3 env MODE=xdebug
```

Now everything is ready to start a XDebug session.

---

### Accessing the TYPO3 database

#### SQLite

A host directory needs to be mounted at the _database volume_ as
[described above](#using-an-ide).
Point your database client at the file `cms-*.sqlite` in that directory.
This is the TYPO3 SQLite database. The actual filename contains a random part.


#### MariaDB and PostgreSQL

Unless configured differently by `t3 run` option&nbsp;`-P` or
[host environment variable](#host-environment-variables) `T3_DB_PORT`,
MariaDB is accessible at `127.0.0.1:3306` and PostgreSQL at `127.0.0.1:5432`.

The [database credentials](#database-credentials) are defined by host
environment variables.

---

## Managing multiple TYPO3 instances

To have multiple TYPO3 instances coexist, each instance must have
-   a unique container name (`t3 run` option&nbsp;`-n`), and
-   unique volume names or [work directories](#using-an-ide) (`t3 run` options `-v` 
    and `-V`).

If you wish to _run_ multiple TYPO3 instances simultaneously then each instance must
be mapped also to unique host ports (`t3 run` options `-p` and `-P`).
[Debugging](#debugging-with-xdebug) is possible in one instance at a time only.

Each `t3 stop`, `t3 composer` and `t3 env` command must be given an 
`-n` option to specify which TYPO3 instance should be targeted.


#### Suggested implementation

For each TYPO3 instance, create a configuration script which `export`s all required
options as [host environment variables](#host-environment-variables), e.g. 
`my-t3-conf`:

```bash
export T3_NAME=my-t3
export T3_ROOT=t3-root
export T3_PORTS=127.0.0.1:8181,127.0.0.1:9443
  ⁝
```

`source` the appropriate configuration script before issuing each `t3` command
and omit all options from the command, e.g.

```bash
$ source my-t3-conf && t3 run
  ⁝
$ source my-t3-conf && t3 stop
```

---

## `t3` shell script reference

`t3` is a shell script for Linux and macOS for managing containerized TYPO3 instances.

`t3` command lines contain a command verb (what to do) and may contain options
(how to do it) and arguments (with what to do it):

```bash
$ t3 COMMAND [option]... [argument]...
```

The `t3` script is
[available for download here](https://raw.githubusercontent.com/undecaf/typo3-in-a-box/master/t3).
In order to view the version of this document that matches a running TYPO3 instance, 
point your browser to [`http://localhost:8080/readme.html`](http://localhost:8080/readme.html).

Commands are described below. Each command can be abbreviated to an unambiguous
verb, such as:

```bash
$ t3 r ...    # abbreviation for 't3 run ...'
$ t3 st ...   # abbreviation for 't3 stop ...'
$ t3 c ...    # abbreviation for 't3 composer ...'
```

---

### Getting help

This displays a list of available commands:

```bash
$ t3 -h
```

Getting help for a particular command:

```bash
$ t3 COMMAND -h
```

---

### Common options

These options are applicable to (almost) all commands (details in the
[options table](#options)).

__Container engine:__
if you have both [Docker](https://www.docker.com/) and [Podman](https://podman.io/)
installed then option&nbsp;`-e` lets you choose between `docker` and `podman`.
By default, Podman will be preferred if it is installed.

Exporting [host environment variable](#host-environment-variables) `T3_ENGINE`
relieves you from repeating that option for each `t3` command.

__Container name:__ a TYPO3 container with this name is created by `t3 run`. Other
commands for that TYPO3 instance have to reference the container by name.

The name defaults to `typo3`; option&nbsp;`-n` (host environment variable 
`T3_NAME`) let you specify a different name.

__Show Docker/Podman commands and output:__
If option&nbsp;`-d` is present (or `T3_DEBUG` is non-empty) then Docker/Podman commands and output appear at the console. Otherwise, only `stderr` is displayed.

_Warning_: your database credentials will be visible if this option is set for `t3 run`.

---

### `t3 run`

Configures and runs a TYPO3 container:

```bash
$ t3 run [option]... [--] [Docker/Podman 'create' option]...
```

__TYPO3:__
by default, the latest image built for the most recent TYPO3 version
([`docker.io/undecaf/typo3-in-a-box`](https://hub.docker.com/r/undecaf/typo3-in-a-box))
is started. 
Option&nbsp;`-T` (or `T3_TAG`) selects a particular TYPO3 version and build by one of the
[available tags](https://hub.docker.com/r/undecaf/typo3-in-a-box/tags).
Use option&nbsp;`-u` (or `T3_PULL`) if you wish to pull an up-to-date version 
of that image from the repository.

__Server:__
TYPO3 is served at `http://127.0.0.1:8080` and  `https://127.0.0.1:8443` by default.
Option&nbsp;`-p` (or `T3_PORTS`) lets you choose different host interfaces and/or ports.

A self-signed certificate is provided automatically. To use a custom
certificate for HTTPS, specify the private key file and the certificate file with
option&nbsp;`-k` (or `T3_CERTFILES`). Both files must be in
[PEM format](https://serverfault.com/questions/9708/what-is-a-pem-file-and-how-does-it-differ-from-other-openssl-generated-key-file).


__TYPO3 volume and work directory:__
The TYPO3 instance is saved in a persistent volume named `typo3-root`.
A different name can be assigned by option&nbsp;`-v` (or `T3_ROOT`). That name _must
not_ contain a `/`.

The TYPO3 volume can be made available for editing in a working directory at the host:
just specify the _working directory path_ (it _must_ contain a `/`) for option&nbsp;`-v` (or `T3_ROOT`).
This will have the following effects:

1.  The working directory basename becomes the TYPO3 volume name.
1.  The TYPO3 volume content appears in the working directory as if it were owned
    by the current user.
1.  File changes, creates and deletes will be passed in both directions between 
    working directory and container, with the current user's UID/GID mapped to container UIDs/GIDs.

Please note: using working directories requires the [bindfs](https://bindfs.org/)
(available for Debian-like and macOS hosts) utility to be installed from the repositories of your system.
For macOS, [osxfuse](https://osxfuse.github.io/) is needed beforehand.

__Database:__ by default, the SQLite instance of the TYPO3 image is used (works only
with TYPO3&nbsp;V9.5+). Option&nbsp;`-D` (or `T3_DB_TYPE`) lets
you use the built-in `mariadb` or `postgresql` servers.

In any case, database state is saved in a persistent volume named `typo3-data`.
Option&nbsp;`-V` (or `T3_DB_DATA`) sets a different volume name. The SQLite database
can be accessed from the host if a _directory path_ (containing a `/`) is
specified as described above for the TYPO3 volume.

MariaDB and PostgreSQL databases are published to the host at `127.0.0.1:3306` and 
`127.0.0.1:5432` by default. Use the `-P` option (or `T3_DB_PORT`) to set a different
host interface and/or port.

A new database is created whenever a database volume is used for the first time.
MariaDB and PostgreSQL database name and credentials are determined by host environment variables
`T3_DB_NAME`, `T3_DB_USER`, `T3_DB_PW` and `T3_DB_ROOT_PW`. If not set then they
all default to `t3` except for `T3_DB_ROOT_PW` which defaults to `toor`.

__Composer Mode:__
to have TYPO3 operate in [Composer Mode](https://getcomposer.org/#Composer_Mode),
option&nbsp;`-c` must be present (or `T3_COMPOSER_MODE` must be non-empty).
In this mode, [`t3 composer`](#t3-composer) lets you add/remove TYPO3 extensions.

By default, Composer Mode is off and extensions are added/removed by the
[TYPO3 Extension Manager](https://docs.typo3.org/m/typo3/tutorial-getting-started/master/en-us/ExtensionManager/Index.html).

__Container environment variables:__
control the time zone and language inside the container, TYPO3 mode, PHP settings
and Composer operation; see [this table](#container-environment-variables)
for details.

Use option&nbsp;`--env NAME=VALUE` or the corresponding
[host environment variable](#host-environment-variables) to assign an initial value to a container environment variable; `--env` takes precedence. This option may
appear multiple times.

The container environment can be changed at runtime by command [`t3 env`](#t3-env).

__Logging:__
option&nbsp;`-l` (or `T3_LOGS` not empty) shows the
[log output of the TYPO3 container](#t3-logs) live at the console (`Ctrl-C` stops
the live view). Add option&nbsp;`-t` (or `T3_TIMESTAMPS` not empty) to show 
container timestamps, too.

__Extra options to be passed to the Docker/Podman `create` command:__
must be placed at the end of the command line and should be separated from `t3`
options by `--`.

---

### `t3 stop`

Stops a TYPO3 container if it is running and optionally removes it:

```bash
$ t3 stop [option]...
```

`t3 stop` will unmount the container's working directories mounted by
[`t3 run`](#t3-run) or by [`t3 mount`](#t3-mount).

__Remove stopped container:__
add option&nbsp;`-R` if the TYPO3 container should be removed after being stopped.
This can also be used to remove a container that is not running.

Please note: `t3` never removes _volumes_.
You have to use `docker/podman volume rm` to do that.

---

### `t3 logs`

Displays the log output of a running TYPO3 container:

```bash
$ t3 logs [option]...
```

__Live view:__
to display log messages at the console in real time, add option&nbsp;`-t` 
(or `T3_FOLLOW` not empty). `Ctrl-C` terminates this mode.

__Latest log lines:__
option&nbsp;`-l LINES` (`T3_LINES=LINES`) shows only that many lines fom the end
of the log, or all lines if 0.

__Timestamps:__
the container engine adds its own timestamp to each log line. By default, these
timestamps are not shown. Option&nbsp;`-t` (or `T3_TIMESTAMPS` not empty) makes them
visible.

To shows only log lines since a timestamp, specify `-s TIMESTAMP`
(or set `T3_SINCE=TIMESTAMP`). `TIMESTAMP` can be
a [Unix timestamp](https://stackoverflow.com/questions/20822821/what-is-a-unix-timestamp-and-why-use-it#20823376),
a [date formatted timestamp](https://www.w3.org/TR/NOTE-datetime),
or a [Go duration string](https://golang.org/pkg/time/#ParseDuration) (e.g. `10m`, `1h30m`) 
computed relative to the client machine's time.

---

### `t3 env`

Modifies the environment of a running TYPO3 container by setting
[container environment variables](#container-environment-variables):

```bash
$ t3 env [option]... [NAME=VALUE]...
```

If no `NAME=VALUE` pairs were specified then this command shows the current
enrivonment.

__Container environment variables:__
control the time zone and language inside the container, TYPO3 mode, PHP settings and Composer operation; see [this table](#container-environment-variables) for details.

Use option&nbsp;`NAME=VALUE` to assign a value to a container environment variable.
This option may appear multiple times.

Initial values can be assigned by command [`t3 run`](#t3-run).

---

### `t3 composer`

This command is applicable only in
[Composer Mode](https://getcomposer.org/#Composer_Mode) (see option&nbsp;[`-c`](#options)
and host environment variable [`T3_COMPOSER_MODE`](#host-environment-variables)).
It executes a [Composer](https://getcomposer.org/) command inside a running
TYPO3 container:

```bash
$ t3 composer [option]... COMPOSER_CMD [Composer option]...
```

__Composer command:__
the rest of the [Composer command line](https://getcomposer.org/doc/03-cli.md).
Composer is run in the context of the TYPO3 installation root in the container
(`/var/www/localhost`), i.e. the root of the TYPO3 volume.

In order to keep Composer from overwriting changes you made in your working
directory, set the container environment variable
[`COMPOSER_EXCLUDE`](#container-environment-variables)
to a colon-separated list of _subdirectories_ of 
`/var/www/localhost` which are to be excluded from changes made by Composer.

---

### `t3 shell`

Opens an interactive Bash shell in a running TYPO3 container:

```bash
$ t3 shell [option]... [--] [shell option]...
```

Type `exit` in order to close the shell.

__Shell options:__
any remaining options are passed to the shell. This could be used to run
arbitrary commands or scripts in the container.

---

### `t3 mount`

Mounts one or more working directories to container volumes so that
the volumes appear to be owned by and can be managed by the current user:

```bash
$ t3 mount [option] WORK_DIR...
```

The directories must be given as paths (containing `/`). The basenames
are used as volume names.

This command is equivalent to [`t3 run`](#t3-run) options `-v` or `-V`
plus a working directory path except that the container does not need to be running
(it does not even have to exist).

This command will ask for `sudo` authorization unless there are cached credentials.

__Container engine:__
the same engine as for the corresponding `t3 run` command.
Use option&nbsp;`-e` (or `T3_ENGINE`) if necessary.

__TYPO3 working directory, database directory:__
a _directory path_ is required (it _must_ contain a `/`).
The directory basename is taken as the volume name, and the directory
is bind-mounted at that volume.

---

### `t3 unmount`

Unmounts one or more working directories from their container volumes:

```bash
$ t3 unmount [option] WORK_DIR
```

This command will ask for `sudo` authorization unless there are cached credentials.

__Container engine:__
the same engine as for the corresponding `t3 run` command.
Use option&nbsp;`-e` (or `T3_ENGINE`) if necessary.

__TYPO3 working directory, database directory:__
specify the _working directory path_ to unmount. This is what is done automatically 
by [`t3 stop`](#t3-stop).

---

### Options

The following table shows which options are applicable to each command. It also
indicates which [host environment variable](#host-environment-variables)
contains the default value for each option and which default value is used if
that environment variable is not set.

| Option | Commands | Description |
|--------|----------|-------------|
| `--engine=ENGINE`<br>`-e ENGINE` | all | Container engine to use: `docker`, `podman` (can be) abbreviated, or an _absolute path_ to the engine executable.<br>Default:  `$T3_ENGINE`, or `podman` if installed, else `docker`. |
| `-h`<br>`--help` | all | Displays a list of commands, or help for the specified command. |
| `--name=NAME`<br>`-n NAME` | `run`<br>`stop`<br>`composer`<br>`shell`<br>`env` | Container name.<br>Default: `$T3_NAME`, or `typo3`. |
| `--debug`<br>`-d` | `run`<br>`stop`<br>`composer`<br>`shell`<br>`env` | If this option is present then Docker/Podman commands and output appear at the console. Otherwise only `stderr` is displayed.<br>_Warning:_ your database credentials will be visible at the console if this option is set for `t3 run`.<br>Default: `$T3_DEBUG`, or not set. |
| `--hostname=HOSTNAME`<br>`-H HOSTNAME` | `run` | Hostname assigned to the TYPO3 container and to Apache `ServerName` and `ServerAdmin`.<br>Default: `$T3_HOSTNAME`, or `typo3.$(hostname)`. |
| `--tag=TAG`<br>`-T TAG` | `run` | Tag of image to run, consisting of TYPO3 version and build version, e.g. `8.7-1.3` or `9.5-latest`.<br>Default: `$T3_TAG`, or `latest`, i.e. the latest build for the most recent TYPO3 version. |
| `--pull`<br>`-u` | `run` | Pulls an up-to-date version of the image from the repository before running it.<br>Default: `$T3_PULL`, or not set. |
| `--composer-mode`<br>`-c` | `run` | If this option is present then Composer is responsible for installing/removing TYPO3 extensions. Otherwise, this is handled by the TYPO3 Extension Manager.<br>Default: `$T3_COMPOSER_MODE`, or not set. |
| `--typo3-root=VOLUME`<br>`-v VOLUME` | `run` | Either a volume name to be mapped to the TYPO3 root directory inside the container, or a working directory path (containing a `/`).<br>In the latter case, the directory basename is used as the volume name, and the directory is bind-mounted at that volume. Thus, volume content appears to be owned by the current user.<br>__Podman users please note:__ working directories require at least Podman&nbsp;v1.4.3.<br>Default: `$T3_ROOT`, or `typo3-root`. |
| `--typo3-ports=HTTP,HTTPS`<br>`-p HTTP,HTTPS` | `run` | Host interfaces (optional) and ports where to publish the TYPO3 HTTP port and the TYPO3 HTTPS port. If one of the mappings is omitted then the respective port will not be published. A leading comma is required if the HTTP part is omitted, e.g. `,127.0.0.1:8443`.<br>Default: `$T3_PORTS`, or `127.0.0.1:8080,127.0.0.1:8443`. |
| `--certfiles=PRIVATE-KEY,CERT`<br>`-k PRIVATE-KEY,CERT` | `run` | Private key file and certificate file for HTTPS, in PEM format and located at the host. If not specified then a self-signed certificate will be used for HTTPS connections.<br>Default: `$T3_CERTFILES`, or not set. |
| `--db-type=TYPE`<br>`-D TYPE` | `run`| Type of database to use: `sqlite` or empty for SQLite, `mariadb` for MariaDB or `postgresql` for PostgreSQL (can be abbreviated).<br>Default: `$T3_DB_TYPE`, or `sqlite`. |
| `--db-vol=VOLUME`<br>`-V VOLUME` | `run` | Database volume name or working directory path (see `--typo3-root`).<br>Defaults: `$T3_DB_DATA`, or `typo3-data`. |
| `--db-port=PORT`<br>`-P PORT` | `run` | Host interface (optional) and port where to publish the database port; requires option&nbsp;`--db-type`.<br> Defaults: `$T3_DB_PORT`, or `127.0.0.1:3306` for MariaDB and `127.0.0.1:5432` for PostgreSQL. |
| `--env NAME=VALUE` | `run` | Sets the (initial) value of a [container environment variable](#container-environment-variables), eventually overriding the corresponding [host environment variable](#host-environment-variables). Most variables can be changed afterwards by `t3 env`.<br>This option may appear multiple times. |
| `--logs`<br>`-l` | `run` | Streams the log output of the new TYPO3 instance to the console until `Ctrl-C` is typed.<br>Default: `$T3_LOGS`, or not set. |
| `--timestamps`<br>`-t` | `run`<br>`logs` | Shows timestamps in the log output.<br>Default: `$T3_TIMESTAMPS`, or not set. |
| `--since=TIMESTAMP`<br>`-s TIMESTAMP` | `logs` | Shows only log lines since `TIMESTAMP`. This can be a [Unix timestamp](https://stackoverflow.com/questions/20822821/what-is-a-unix-timestamp-and-why-use-it#20823376), a [date formatted timestamp](https://www.w3.org/TR/NOTE-datetime), or a [Go duration string](https://golang.org/pkg/time/#ParseDuration) (e.g. `10m`, `1h30m`) computed relative to the client machine's time.<br>Default: `$T3_SINCE`, or not set. |
| `--follow`<br>`-f` | `logs` | Streams the log output to the console until `Ctrl-C` is typed.<br>Default: `$T3_FOLLOW`, or not set. |
| `--tail=LINES`<br>`-l LINES` | `logs` | Shows only that many lines from the end of the log, or all lines if 0.<br>Default: `$T3_TAIL`, or not set. |
| `--rm`<br>`-R` | `stop` | Causes the TYPO3 container to be removed after being stopped. |

---

### Host environment variables

If `export`ed to the host shell, theses variables set custom default values
for [options](#options) and
[container environment variables](#container-environment-variables). In this way,
they can provide a consistent environment for all `t3` commands of a particular TYPO3 instance.


| Name | Description | Built-in default |
|------|-------------|------------------|
| `T3_ENGINE` | Container engine to use: `docker`, `podman` (can be) abbreviated, or an _absolute path_ to the engine executable. | `podman` if installed, else `docker` |
| `T3_NAME` | Container name. | `typo3` |
| `T3_DEBUG` | If non-empty then Docker/Podman commands and output appear at the console. Otherwise only `stderr` is displayed.<br>_Warning:_ your database credentials will be visible at the console if this option is set for `t3 run`. | empty |
| `T3_HOSTNAME` | Hostname assigned to the TYPO3 container and to Apache `ServerName` and `ServerAdmin`. | `typo3.$(hostname)` |
| `T3_TAG` | Tag of image to run, consisting of TYPO3 version and build version, e.g. `8.7-1.3` or `9.5-latest`. | `latest` |
| `T3_PULL` | If non-empty then an up-to-date version of the image is pulled from the repository before running it. | empty |
| `T3_COMPOSER_MODE` | If non-empty then Composer is responsible for installing/removing TYPO3 extensions. Otherwise, this is handled by the TYPO3 Extension Manager. | empty |
| `T3_ROOT` | Either a volume name to be mapped to the TYPO3 root directory inside the container, or a working directory path (containing a `/`).<br>In the latter case, the directory basename is used as the volume name, and the directory is bind-mounted at that volume. Thus, volume content appears to be owned by the current user.<br>__Podman users please note:__ working directories require at least Podman&nbsp;v1.4.3. | `typo3-root` |
| `T3_PORTS` | Host interfaces (optional) and ports where to publish the TYPO3 HTTP port and the TYPO3 HTTPS port. If one of the parts is omitted then the respective port will not be published. A leading comma is required if the HTTP part is omitted, e.g. `,127.0.0.1:8443`. | `127.0.0.1:8080,`<br>`127.0.0.1:8443` |
| `T3_CERTFILES` | Private key file and certificate file for HTTPS, in PEM format and located at the host. If not specified then a self-signed certificate will be used for HTTPS connections. | empty |
| `T3_DB_TYPE` | Type of database to use: `sqlite` or empty for SQLite, `mariadb` for MariaDB or `postgresql` for PostgreSQL (can be abbreviated). | `sqlite` |
| `T3_DB_DATA`| Database volume name or working directory path (see `T3_ROOT`). | `typo3-data` |
| `T3_DB_PORT` | Host interface (optional) and port where to publish the database port; effective only for MariaDB and PostgreSQL. | `127.0.0.1:3306`, or<br>`127.0.0.1:5432` |
| `T3_DB_NAME` | Name of the TYPO3 database that is created automatically by `t3 run`; effective only for MariaDB and PostgreSQL. | `t3` |
| `T3_DB_USER` | Name of the TYPO3 database owner; effective only for MariaDB and PostgreSQL. | `t3` |
| `T3_DB_PW` | Password of the TYPO3 database; effective only for MariaDB and PostgreSQL. | `t3` |
| `T3_DB_ROOT_PW` | Password of the MariaDB root user; effective only for MariaDB and PostgreSQL. | `toor` |
| `T3_LOGS` | If non-empty then the log output of a new TYPO3 instance is being streamed to the console until `Ctrl-C` is typed. | empty |
| `T3_TIMESTAMPS` | Shows timestamps in the log output if non-empty. | empty |
| `T3_SINCE` | Shows only log lines since `$T3_SINCE`. This can be a [Unix timestamp](https://stackoverflow.com/questions/20822821/what-is-a-unix-timestamp-and-why-use-it#20823376), a [date formatted timestamp](https://www.w3.org/TR/NOTE-datetime), or a [Go duration string](https://golang.org/pkg/time/#ParseDuration) (e.g. `10m`, `1h30m`) computed relative to the client machine's time. | empty |
| `T3_FOLLOW` | If non-empty then the log output is being streamed to the console until `Ctrl-C` is typed. | empty |
| `T3_TIMEZONE`<br>`T3_LANG`<br>`T3_MODE`<br>`T3_COMPOSER_EXCLUDE`<br>`T3_PHP_...` | Initial values for [container environment variables](#container-environment-variables) `TIMEZONE`, `LANG`, `MODE`, `COMPOSER_EXCLUDE` and `PHP_...`. | empty |

---

### Container environment variables

These variables can get their initial values from 
[host environment variables](#host-environment-variables) or 
from the `t3 run --env` option; the `--env` option takes precedence.

Except for `TIMEZONE` and `LANG`, these variables can be set or changed at runtime by
the `t3 env` command.

| Name | Description | Built-in default |
|------|-------------|------------------|
| `TIMEZONE` | Sets the TYPO3 container timezone (e.g. `Europe/Vienna`). |Timezone of your current location, or else UTC. |
| `LANG` | Sets the language used for PostgreSQL collation and sorting. | `C.UTF-8` |
| `MODE`| <dl><dt>`prod`</dt><dd>selects production mode: TYPO3 operating in „Production Mode“, no Apache/PHP signature headers, PHP settings as per     [`php.ini-production`](https://github.com/php/php-src/blob/master/php.ini-production)</dd><dt>`dev`</dt><dd>selects development mode: TYPO3 in „Development Mode“, verbose Apache/PHP signature headers, PHP settings as recommended by [`php.ini-development`](https://github.com/php/php-src/blob/master/php.ini-development)</dd><dt>`xdebug`</dt><dd>selects development mode as above and also enables [XDebug](https://xdebug.org/)</dd></dl> | `prod` |
| `COMPOSER_EXCLUDE` | Colon-separated list of _subdirectories_ of `/var/www/localhost` which are to be excluded from the effects of [Composer operations](#composer).<br>This is intended e.g. to protect the current version of an extension you are developing from being overwritten by an older version stored in a repository.<br>These directories need to exist only by the time Composer is invoked. | empty |
| `PHP_...` | Environment variables prefixed with `PHP_` become `php.ini` settings with the prefix removed, e.g. `--env PHP_post_max_size=5M` becomes `post_max_size=5M`. These settings override prior settings and `MODE`. | none |

---

## Credits to ...

-   [Docker, Inc.](https://www.docker.com/) for their Open Source Docker
    implementation and the excellent documentation
-   the people at [Red Hat](https://www.redhat.com/) developing
    [Podman](https://podman.io/) with dedication
-   [Yoba Systems](https://github.com/yobasystems) whose Alpine database containers
    I used as templates
-   the [Alpine Linux](https://alpinelinux.org/), [TYPO3](https://typo3.org/),
    [MariaDB](https://mariadb.org/) and [PostgreSQL](https://www.postgresql.org/)
    communities
-   Derick Rethans for [Xdebug](https://xdebug.org/)
-   Martin Pärtel for [bindfs](https://bindfs.org/) and the makers of
    [osxfuse](https://github.com/osxfuse/osxfuse)
-   ... and to all the people unknown to me whose work this project is based on


## Licenses

Scripts in this repository are licensed under the GPL&nbsp;3.0.

This document is licensed under the Creative Commons license CC&nbsp;BY-SA&nbsp;3.0.

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image
complies with any relevant licenses for all software contained within.
More information on this subject may be found in
[this discussion](https://opensource.stackexchange.com/questions/7013/license-for-docker-images#answer-7015).
