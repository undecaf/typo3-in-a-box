# TYPO3 in a box ‒ a versatile TYPO3 8.7/9.5/10.4 image

[![Build Status](https://travis-ci.com/undecaf/typo3-in-a-box.svg?branch=master)](https://travis-ci.com/undecaf/typo3-in-a-box)
[![Latest release](https://img.shields.io/github/release/undecaf/typo3-in-a-box.svg)](https://github.com/undecaf/typo3-in-a-box)
![Image Size](https://img.shields.io/endpoint?url=https%3A%2F%2Fdocker-size.modus-operandi.workers.dev%2Fundecaf%2Ftypo3-in-a-box%2Ftags%2Flatest)

This project provides a ready-to-run and extensive
[TYPO3](https://typo3.org/)&nbsp;8.7/9.5/10.4 installation as a single container image.
It is widely configurable, and thus it addresses TYPO3 editors and administrators
as well as integrators and extension developers. Builds of the TYPO3 development
branches are available, too.

The image is based on [Alpine Linux](https://alpinelinux.org/), comes
with up-to-date versions of [Apache](https://httpd.apache.org/),
[PHP](https://php.net/) and [ImageMagick](https://www.imagemagick.org/) 
and has [SQLite](https://www.sqlite.org/), [MariaDB](https://mariadb.org/) and
[PostgreSQL](https://www.postgresql.org/) built in to choose from.
It is available at [Docker Hub](https://hub.docker.com/r/undecaf/typo3-in-a-box),
uses well below 500&nbsp;MB disk space and can run in
[Docker](https://www.docker.com/) and [Podman](https://podman.io/).
No additional container is required, and only a browser is needed
at the host to get going.


Setting up and managing usage scenarios is simplified by a
[shell script](https://github.com/undecaf/typo3-in-a-box#t3-shell-script-reference) for Linux and macOS.

TYPO3 directories can be 
[mapped from the container to the host](https://github.com/undecaf/typo3-in-a-box#using-an-ide).
You can use your favorite IDE at the host to
[develop for TYPO3](https://github.com/undecaf/typo3-in-a-box#developing-for-typo3) in the container without having to
fiddle with host permissions.

[Secure connections](https://github.com/undecaf/typo3-in-a-box#https-connections),
[logging (also to an external syslog host)](https://github.com/undecaf/typo3-in-a-box#logging),
[Composer Mode](https://docs.typo3.org/m/typo3/guide-installation/master/en-us/ExtensionInstallation/Index.html#install-extension-with-composer),
[remote debugging with XDebug](https://github.com/undecaf/typo3-in-a-box#debugging-with-xdebug) and
[database access](https://github.com/undecaf/typo3-in-a-box#accessing-the-typo3-database) are supported.
Your personal extension directories can be
[excluded from updates made by Composer](https://github.com/undecaf/typo3-in-a-box#preventing-composer-from-overwriting-your-changes).


## Overview

![Parts of this project in a block diagram: container for TYPO3, shell script, browser and IDE](https://undecaf.github.io/typo3-in-a-box/img/overview.png)


## [Contents](https://github.com/undecaf/typo3-in-a-box#contents)

The size of the documentation exceeds the Docker Hub length limit of 25&nbsp;KB.
Please visit the [Git repository](https://github.com/undecaf/typo3-in-a-box#typo3-in-a-box--a-versatile-typo3-8795104-image) for an extensive description of this project.

-   [Running TYPO3](https://github.com/undecaf/typo3-in-a-box#running-typo3)
    -   [Quick start](https://github.com/undecaf/typo3-in-a-box#quick-start)
    -   [`t3` shell script](https://github.com/undecaf/typo3-in-a-box#t3-shell-script)
    -   [Quick start with `t3`](https://github.com/undecaf/typo3-in-a-box#quick-start-with-t3)
    -   [MariaDB and PostgreSQL](https://github.com/undecaf/typo3-in-a-box#mariadb-and-postgresql)
    -   [HTTPS connections](https://github.com/undecaf/typo3-in-a-box#https-connections)
    -   [Logging](https://github.com/undecaf/typo3-in-a-box#logging)
-   [Developing for TYPO3](https://github.com/undecaf/typo3-in-a-box#developing-for-typo3)
    -   [Using an IDE](https://github.com/undecaf/typo3-in-a-box#using-an-ide)
    -   [Setting the container environment](https://github.com/undecaf/typo3-in-a-box#setting-the-container-environment)
    -   [Composer](https://github.com/undecaf/typo3-in-a-box#composer)
    -   [Debugging with XDebug](https://github.com/undecaf/typo3-in-a-box#debugging-with-xdebug)
    -   [Accessing the TYPO3 database](https://github.com/undecaf/typo3-in-a-box#accessing-the-typo3-database)
-   [Managing multiple TYPO3 instances](https://github.com/undecaf/typo3-in-a-box#managing-multiple-typo3-instances)
-   [`t3` shell script reference](https://github.com/undecaf/typo3-in-a-box#t3-shell-script-reference)
    -   [Getting help](https://github.com/undecaf/typo3-in-a-box#getting-help)
    -   [Common options](https://github.com/undecaf/typo3-in-a-box#common-options)
    -   [`t3 run`](https://github.com/undecaf/typo3-in-a-box#t3-run)
    -   [`t3 stop`](https://github.com/undecaf/typo3-in-a-box#t3-stop)
    -   [`t3 logs`](https://github.com/undecaf/typo3-in-a-box#t3-logs)
    -   [`t3 env`](https://github.com/undecaf/typo3-in-a-box#t3-env)
    -   [`t3 composer`](https://github.com/undecaf/typo3-in-a-box#t3-composer)
    -   [`t3 shell`](https://github.com/undecaf/typo3-in-a-box#t3-shell)
    -   [Options](https://github.com/undecaf/typo3-in-a-box#options)
    -   [Host environment variables](https://github.com/undecaf/typo3-in-a-box#host-environment-variables)
    -   [Container environment variables](https://github.com/undecaf/typo3-in-a-box#container-environment-variables)
-   [Credits to ...](https://github.com/undecaf/typo3-in-a-box#credits-to-)
-   [Licenses](https://github.com/undecaf/typo3-in-a-box#licenses)


## [Available tags](https://hub.docker.com/r/undecaf/typo3-in-a-box/tags)

As their version numbers suggest, images in this repository should be 
considered still as unstable.

-   `latest`: most recent image of the most recent TYPO3 version 
    (currently [`10.4.3`](https://packagist.org/packages/typo3/cms#v10.4.3))
-   `8.7-latest`, `9.5-latest`, `10.4-latest`:  
    most recent image of the most recent TYPO3&nbsp;8.7/9.5/10.4
    revision (currently [`8.7.32`](https://packagist.org/packages/typo3/cms#v8.7.32),
    [`9.5.18`](https://packagist.org/packages/typo3/cms#v9.5.18) and
    [`10.4.3`](https://packagist.org/packages/typo3/cms#v10.4.3))
-   `8.7-dev`, `9.5-dev`, `10.4-dev`:  
    weekly builds of the most recent _development image_ of the most
    recent TYPO3&nbsp;8.7/9.5/10.4 _development version_ (currently
    [`8.7.x-dev`](https://packagist.org/packages/typo3/cms#dev-TYPO3_8-7),
    [`9.5.x-dev`](https://packagist.org/packages/typo3/cms#9.5.x-dev) and
    [`10.4.x-dev`](https://packagist.org/packages/typo3/cms#dev-master))
-   `8.7-x.y`, `9.5-x.y`, `10.4-x.y`:  
    image version `x.y` of those TYPO3&nbsp;8.7/9.5/10.4 revisions that were most
    recent at build time
