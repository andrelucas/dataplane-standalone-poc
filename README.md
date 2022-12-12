# README for dataplane-standalone-poc

## Machine setup

This is tested on Fedora 37. It's containerised and any Red Hat-like system
with a fully-working Podman installation should work equally well.

We recommend SELinux not be in `Enforcing` mode. This is a limitation of the
container used here and not Ondat's data plane which works well in production
SELinux-enforcing environments.

The `target_core_user` module must be loaded into the running kernel.

Install podman, if not already present:

```sh
$ sudo dnf -y install podman-*
$ mkdir -p ~/git
```

## Get prerequisite files from Ondat

Ondat needs to provide:

| File(s) | Purpose |
| - | - |
| `ca.crt`, `ca.pem` | CA certificate and key for the remote Ondat cluster. |
| `staging.tgz` | Data plane build artifacts, will be copied into the container. |

## Grab the PoC runner

```sh
$ cd ~/git
$ git clone https://github.com/andrelucas/dataplane-standalone-poc.git dps
$ cd dps
```

## Copy necessary files

```sh
# Matching CA certificate and key.
$ cp PATH/TO/ca.{crt,key} ca/
# Dataplane artifact binaries.
$ cp PATH/TO/staging.tgz .
$ make stage-from-tarball
```

## Build and run

This will take a while the first time, as it will download a fairly big Docker
image, and then build the test environment.

```sh
# Kill any existing environment, create a new one, and log into the client
# container.
$ make up shell
```

If (and only if) you're not running SELinux in enforcing mode: To reassure yourself this is running correctly, you can do a brief environment
check. This will stop and start some services (references to the 'remote' here
aren't relevant to this PoC).

```sh
## Inside the client container. This won't work in SELinux in Enforcing mode.
# cd /test
# ./test_init

## Back to the original directory.
# cd /tools
```

## Connect to the remote drive

You need to know a few things about the remote volume:

| Variable | Description |
| - | - |
| `DEPLOYMENT_UUID` | The Ondat volume's current master deployment. |
| `REMOTE_NODE_IP` | The IP address on which we can connect to the master deployment's node container. |
| `SIZE_BYTES` | The Ondat volume's size in bytes. |

```sh
# Still logged in to the container via `make shell`, above. All these
# variables need to be filled in with appropriate values, none are optional.
$ export \
    DEPLOYMENT_UUID=... \
    REMOTE_NODE_IP=... \
    SIZE_BYTES=...

$ make poc-connect

# This will create a SCSI device on the local host system.

$ dmesg | tail -30
```

## Use the volume

```sh
# Back on the host.
$ sudo mount /var/lib/storageos/volumes/my_volume /mnt
$ ls -al /mnt
...

```

## Ondat internal steps

### Generate the staging tarball

We need to generate a tarball to give to the client.

```sh
$ cd git/data
$ make rshell
...
# scripts/build.sh --release --test --inttest --install
... time passes ...
# CTRL-D

$ cd test
$ make stage-to-tarball
# This leaves staging.tgz in test/.
```

### CA cert and key

The extraction procedure is internal-use only. We need `ca.crt` and `ca.key`
from the target cluster to operate correctly.
