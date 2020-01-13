![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/resolv.svg)](https://forge.puppetlabs.com/simp/resolv)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/resolv.svg)](https://forge.puppetlabs.com/simp/resolv)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-resolv.svg)](https://travis-ci.org/simp/pupmod-simp-resolv)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with resolv](#setup)
    * [What resolv affects](#what-resolv-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with resolv](#beginning-with-resolv)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
    * [Acceptance Tests - Beaker env variables](#acceptance-tests)


## Description

This module sets up DNS client config, including `/etc/resolv.conf` and `/etc/host.conf`.


### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our [bug tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will be managed from the Puppet server.


## Setup


### What resolv affects

  * `/etc/resolv.conf`
  * `/etc/host.conf`


### Beginning with resolv

Include the class on any systems you want to manage.


## Usage

Include the class from hiera:

```yaml
---
classes:
  - ::resolv
```

File contents can be tweaked by adding more hieradata:

```
---
resolv::rotate: false
resolv::host_conf::multi: true
```

## Reference

Please refer to the [REFERENCE.md](./REFERENCE.md).

## Limitations

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux and compatible distributions, such as CentOS. Please see the [`metadata.json` file](./metadata.json) for the most up-to-date list of supported operating systems, Puppet versions, and module dependencies.


## Development

Please read our [Contribution Guide] (https://simp.readthedocs.io/en/stable/contributors_guide/index.html).
