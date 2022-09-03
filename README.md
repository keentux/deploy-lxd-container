# Deploy container

This project aims to deploy easily a cluster of **lxd** container.

## Dependances

Need tools **lxd** and **jq** to run.

## Run it

```bash
$ ./deploy-container.sh  --help
[INFO] Running script on distro Ubuntu
./deploy-container.sh [-c | --config] [ -h | --help ]

- config: Path to the config file
- force: force the installation or removing process

example:
    ./deploy-container.sh --config=./test.json --force
```

## JSON config file

```json
{
    "containers": [
        {
            "name": "container-tumbleweed",
            "distro":"opensuse",
            "release":"tumbleweed",
            "arch":"amd64",
            "storage": "default",
            "packages": [
                "openssh"
            ],
            "mounts":[
                {
                    "uid": "uid-of-the-mount",
                    "from": "/path/to/folder/to/mount",
                    "to": "/path/to/mounted/folder"
                }
            ],
            "commands": [
                "03_start_ssh",
                "05_create_user"
            ]
        }
    ]
}
```

* **containers**: list of containers to deploy
  * **name**: cintaienr instance name, should be unique !
  * **distro**: container OS Distribution
  * **release**: container OS Release
  * **arh**: container OS Architecture
  * **storage**: lxc storage to use (default: default)
  * **packages**: list of packages to insstall
  * **mounts**: list of mount device JSON
    * **uid**: uid of the device
    * **from**: folder to mount in the container
    * **to**:folder to create in the container
  * **commands**: List of scripts to execute in the container deployed

For list of potential container images see: <https://uk.lxd.images.canonical.com/>

## Extra commands

Extra commands can be run thanks scipts from the folder `./tasks.d`.
Example:

* `03_start_ssh` -> start sshd service if openssh is installed
* `05_create_use` -> Create the devel user

### Custom scripts

For execute customs command in container, you will need to write a script with commands list as below:

```sh
lxc exec ${1} -- $custom_cmd_1
lxc exec ${1} -- $custom_cmd_2
```

And put the script in the folder `tasks.d/`

* `$1` -> container instance name
* `$2` -> container distribution
