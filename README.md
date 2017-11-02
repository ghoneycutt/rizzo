# Rizzo

Rizzo is a heavily customized Vagrant configuration and work flow with a
role based focus. It is meant to make working with Vagrant easier and
purpose built for layered Puppet control repositories.

Rizzo loads a personal configuration file, `~/.rizzo.json` by default, which
lists one or more control repositories.  Rizzo then looks for and loads a
`.rizzo.json` configuration file located at the root of the top level control
repository.  The top level control repository is the first listed in
the array of control repositories in the personal configuration file.

There should be at least one node for every role that is managed by a
control repo. This information is stored in `.rizzo.json` under the
control repo. This makes it apparent what roles are available and aids
in functional testing.

Each control repo must have a directory under it named `modules`. It is
up to you to populate this, so it works with the common tools such as
librarian-puppet-simple, librarian-puppet and r10k, without being
dependent on them.

Rizzo is named after Rizzo the Rat.

# Compatibility

Tested to work with ruby versions associated with Puppet, see
`.travis.yml`, on OSX and Windows 2012R2.

# Installation

Add the rizzo gem to your control repository `Gemfile`.  For example, in
`puppetdata`:

```diff
diff --git a/Gemfile b/Gemfile
index 572f681..5c2f3b0 100644
--- a/Gemfile
+++ b/Gemfile
@@ -20,6 +20,7 @@ gem 'puppet-lint-undef_in_function-check'
 gem 'puppet-lint-unquoted_string-check'
 gem 'puppet-lint-variable_contains_upcase'
 gem 'puppet-syntax'
+gem 'rzo'

 gem 'serverspec', :require => false
 gem 'vagrant-wrapper', :require => false
```

Then update the bundle with:

```shell
bundle install --path .bundle/gems/
bundle update rzo
```

Interact with rizzo using:

```shell
bundle exec rizzo --help
usage: rizzo [GLOBAL OPTIONS] SUBCOMMAND [ARGS]
Sub Commands:

  config       Print out the combined rizzo json config
  generate     Initialize Vagrantfile in top control repo

Global options: (Note, command line arguments supersede ENV vars in {}'s)
  -l, --logto=<s>     Log file to write to or keywords STDOUT, STDERR {RZO_LOGTO} (default: STDERR)
  -s, --syslog        Log to syslog
  -v, --verbose       Set log level to INFO
  -d, --debug         Set log level to DEBUG
  -c, --config=<s>    Rizzo config file {RZO_CONFIG} (default: ~/.rizzo.json)
  -e, --version       Print version and exit
  -h, --help          Show this message
```

Once rizzo is installed, setup your configuration file, `~/.rizzo.json`, then
use `bundle exec rizzo generate` to write the `Vagrantfile` in your control
repo.

# Dependencies

1. **vagrant-vbguest gem** See
   [https://github.com/dotless-de/vagrant-vbguest](https://github.com/dotless-de/vagrant-vbguest)

    `vagrant plugin install vagrant-vbguest`

1. **vagrant-proxyconf gem** This is optional. When used, if you have proxy
  settings set in your environment, they will be transferred to the
  guest. See
  [http://tmatilai.github.io/vagrant-proxyconf/](http://tmatilai.github.io/vagrant-proxyconf/)

    `vagrant plugin install vagrant-proxyconf`

# Setup

## `~/.rizzo.json`

The personal configuration file is loaded first, from `~/.rizzo.json` by default.
The global `--config` option allows the end user to specific a different path to
the personal configuration file.

Using this example, change the paths to your git repos:

```json
{
  "defaults": {
    "bootstrap_repo_path": "/Users/gh/git/bootstrap"
  },
  "control_repos": [
    "/Users/gh/git/puppet-control-myteam",
    "/Users/gh/git/puppetdata",
    "/Users/gh/git/puppet-modules"
  ],
  "puppetmaster": {
    "name": "infra-puppetca",
    "modulepath": [
      "./modules",
      "./puppetdata/modules",
      "./ghoneycutt/modules"
    ],
    "synced_folders": {
      "/repos/puppetdata": {
        "local": "/Users/gh/git/puppetdata",
        "owner": "root",
        "group": "root"
      },
      "/repos/ghoneycutt": {
        "local": "/Users/gh/git/puppet-modules",
        "owner": "root",
        "group": "root"
      }
    }
  }
}
```

Once you have a personal config file, `~/.rizzo.json`, change directories to
your top level control repository and generate your `Vagrantfile`:

```shell
cd ~/git/puppet-control-myteam
bundle exec rizzo generate
```

Expected output:

```
Wrote vagrant config to Vagrantfile
```

Once the `Vagrantfile` has been generated, interact with the roles using `vagrant status`.

```shell
vagrant status
```
```
Current machine states:

infra-puppetfourca        not created (virtualbox)
infra-puppetfour          not created (virtualbox)
infra-test                not created (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
```

## Configuration Specification

### defaults

The defaults hash is merged with each node entries hash. Put user
specific entries in the personal configuration file at `~/.rizzo.json` and
control repo specific entries in `${PATH_TO_CONTROL_REPO}/.rizzo.json`.

### control_repos

The control_repos array is a list of control repos. Rizzo takes the
approach that control repos are layered. The ordering should match your
`puppetmaster['modulepath']` array. The first control repo with a
`.rizzo.json` in it will have that Rizzo config used.

### puppetmaster

This hash is for your puppet master and is specific to that purpose.

#### name

If the name of the node matches puppetmaster['name'] then that node will
be treated as a puppetmaster. This will add the synced folders which map
to your control repos. This allows you to edit code locally using your
favorite editor and have it immediately available within the
puppetmaster.

#### modulepath

An array to describe the modulepath that is used in the puppetmaster's
environment.conf. This file is available in the `bootstrap_guest_path`
for use with your bootstrap script.

#### synced_folders

Hash of hashes for directories that are made available to the guest. The
key for the hash is the directory under the guest and its keys are
local, which is the path on the host and owner and group which are the
owner and group permissions the directory will be mounted with on the
guest.

## `controlrepo/.rizzo.json`

```json
{
  "defaults": {
    "bootstrap_script_path": "bootstrap_puppet4.sh",
    "bootstrap_script_args": "-l -f `hostname -f`",
    "bootstrap_guest_path": "/tmp/bootstrap",
    "boot_timeout": "500",
    "box": "centos7.box",
    "box_url": "https://vagrantboxes/centos7.box",
    "box_download_checksum": "3764a2c4ae3829aa4b50971e216c3a03736aafb2",
    "box_download_checksum_type": "sha1",
    "memory": "1024",
    "netmask": "255.255.255.0",
    "update_packages": true,
    "update_packages_command": "yum -y update",
    "shutdown": true,
    "shutdown_command": "/sbin/shutdown -h now"
  },
  "nodes": [
    {
      "name": "infra-puppetca",
      "hostname": "infra-puppetca1.example.org",
      "forwarded_ports": [
        {
          "guest": "8140",
          "host": "8140"
        }
      ],
      "ip": "172.16.100.5",
      "memory": "2048"
    },
    {
      "name": "infra-puppet",
      "hostname": "infra-puppet1.example.org",
      "ip": "172.16.100.6",
      "memory": "2048"
    },
    {
      "name": "www-api",
      "hostname": "www-api1.example.org",
      "ip": "172.16.100.7"
    }
  ]
}
```

### defaults

This hash is merged with each node entry.

### nodes

A list of node entries.

#### name

Name of the node entry. This is what it will be referred to by Vagrant.

#### hostname

The FQDN (fully qualified domain name).

#### forwarded_ports

An optional array of hashes with the key guest and value is the port on
the guest and the key host and the value is the port on the host. Rizzo
will check and fail if you use duplicate host ports, as they must be
unique.

#### ip

IP address.

#### netmask

Netmask.

#### memory

Amount of memory. This should be specified in MB without any unit
signifier.

#### bootstrap_repo_path

The path on the host to your bootstrap repo.

#### bootstrap_guest_path

The path on the guest where the `bootstrap_repo_path` will be mounted.

#### bootstrap_script_path

Path of script to be used to bootstrap a system. This is relative to
`bootstrap_guest_path`.

#### bootstrap_script_args

Any arguments to pass to `bootstrap_script_path`.

#### boot_timeout

Optional parameter that sets the amount of time is seconds that Vagrant waits for
a node to become available via ssh before it fails.  Default is 300 seconds.

#### box

Name of the Vagrant box.

#### box_url

URL to the Vagrant box.

#### box_download_checksum

Checksum of the Vagrant box.

#### box_download_checksum_type

Type of checksum used in `box_download_checksum`.

#### update_packages

Boolean to determine if packages should be updated.

#### update_packages_command

Command to update the packages.

#### shutdown

Boolean to determine if the system should be shutdown after being
provisioned. This is useful because Rizzo uses
[vagrant-vbguest](https://github.com/dotless-de/vagrant-vbguest) which
will check the version of the VirtualBox Guest Additions you have with
that of the guest VM. If they differ, it will recompile on the guest. If
the system is not shutdown and just rebooted, then on the next boot the
guest additions will not work. Instead the system must be brought up
with `vagrant up node_name` which will activate the vbguest plugin and
ensure the guest additions are working.

#### shutdown_command

The command used to shutdown the system.
