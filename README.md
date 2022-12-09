# README for dataplane-standalone-poc

## Machine setup

This is tested on Fedora 37. It's containerised and any Red Hat-like system
with a fully-working Podman installation should work equally well.

The `target_core_user` kernel module must be installed.

```sh
$ sudo dnf -y install podman-*
$ mkdir -p ~/git
```

## Grab the poc runner

```sh
$ cd ~/git
$ git clone https://github.com/andrelucas/dataplane-standalone-poc.git dps
$ cd dps
```

## Copy necessary files

```sh
$ cp PATH/TO/ca.{crt,key} cat/
$ cp PATH/TO/staging.tgz .
```

## Build and run

This will take a while, as it will download a fairly big Docker image, and
then build the test environment.

```sh
$ make up
```
