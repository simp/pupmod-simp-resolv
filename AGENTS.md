# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-resolv` is a SIMP Puppet module that manages **client-side DNS
resolution** on Enterprise Linux systems. Its main class writes
`/etc/resolv.conf` (via an `augeas` resource driven by a custom lens) or, on
NetworkManager-managed hosts, writes a NetworkManager drop-in that hands DNS
off to `nmcli`. It can also opt the host out of DHCP-provided DNS
(`PEERDNS=no` in `/etc/sysconfig/network`) and, when the host is itself a
nameserver or a caching resolver, auto-configure the `named` module. A second
class, `resolv::host_conf`, manages `/etc/host.conf`.

The module has two modes for the same job (`manifests/init.pp:173-229`):

- **NetworkManager mode** (`$use_nmcli`, defaults to the
  `simplib__networkmanager.enabled` fact): DNS is rendered into
  `/etc/NetworkManager/conf.d/zz_10_simp_dns.conf` from the
  `resolv/etc/NetworkManager/conf.epp` template, and a HUP is sent to
  NetworkManager. In this mode NetworkManager is authoritative, so `--`
  "remove this option" entries are filtered out (`init.pp:178`).
- **Direct mode** (`present`, non-NetworkManager): `/etc/resolv.conf` is
  written and then edited in place with `augeas` using the module's own
  `resolv` lens (`lib/augeas/lenses/resolv.aug`), unless `$content` is supplied
  (in which case the raw content is written and augeas is skipped)
  (`init.pp:181-212`).

### Business logic

Two public classes; no defines. Neither class calls `assert_private()`, so
both are public API (consumers `include 'resolv'` / `include
'resolv::host_conf'`).

- **`resolv` (`manifests/init.pp:118-276`)** — the entry class. All parameters
  are typed (`init.pp:118-141`). Notable ones:
  - `$ensure` (`Enum['present','absent']`, default `'present'`) — when
    `'absent'`, the class does one thing: `file { '/etc/resolv.conf': ensure =>
    'absent' }` and skips all other file management (`init.pp:143-145`). The
    named/PEERDNS logic below the `if/else` still runs.
  - `$servers` (`init.pp:120`) — defaults from the seam
    `simplib::lookup('simp_options::dns::servers', 'default_value' => undef)`.
    Typed `Optional[Variant[Boolean[false], Array[Simplib::IP,0,3]]]` — at most
    **3** servers; `false` actively removes the option.
  - `$search` (`init.pp:121`) — defaults from
    `simplib::lookup('simp_options::dns::search', 'default_value' => undef)`.
  - `$use_nmcli` (`init.pp:133`) — defaults to
    `pick($facts.dig('simplib__networkmanager', 'enabled'), false)`; this fact
    (from `simp/simplib`) is what selects NetworkManager vs. direct mode.
  - `$content` (`init.pp:139`) — if set, its lines are stripped and joined and
    written verbatim to `/etc/resolv.conf`; augeas is bypassed
    (`init.pp:184-189,198`).
  - `$ignore_dhcp_dns` (`Boolean`, default `true`) — drives `PEERDNS`.

  Control flow and resources:
  - **Options assembly** (`init.pp:147-156`): `$_options` is built by mapping
    each toggle to either its option string or a `--`-prefixed removal token
    (`ndots`/`timeout`/`attempts` take a `false` => remove; `debug`/`rotate`/
    `no_check_names`/`inet6` take true/false/other), concatenated with
    `$extra_options`, then `sort(unique(...))`.
  - **Search assembly** (`init.pp:158-171`): merges `$search` with the
    (obsolete) `$resolv_domain` into `$_search`.
  - **NetworkManager branch** (`init.pp:173-180`): renders
    `resolv/etc/NetworkManager/conf.epp`, filtering out `--` options.
  - **Direct `present` branch** (`init.pp:181-213`): writes
    `/etc/resolv.conf` (mode `0644`) and, unless `$content`, renders
    `resolv/etc/resolv.conf.epp` into augeas `changes` against context
    `/files/etc/resolv.conf`, requiring the file.
  - **NetworkManager file + reload** (`init.pp:215-229`): guarded by the
    `simplib__networkmanager.enabled` fact (note: this is a *separate* check
    from `$use_nmcli`), writes the drop-in and notifies
    `exec { "${module_name}_restart_networkmanager" }` which runs
    `pkill -HUP NetworkManager` (`refreshonly`).
  - **named autoconf** (`init.pp:232-261`): only when `$servers` is an
    `Array[Simplib::IP]`. Determines `$_is_named_server` from `$named_server`,
    an already-declared `Class['named']`, or (`$named_autoconf` and
    `simplib::host_is_me($servers)`). If not a named server, caching is on, and
    the **first** server is `127.0.0.1` or `::1`, it sets up a caching resolver
    via `include 'named::caching'` plus
    `named::caching::forwarders` for the remaining servers — but **`fail()`s if
    `127.0.0.1` is the only entry** (`init.pp:245-247`). Otherwise, if it is a
    named server, `include 'named'`.
  - **PEERDNS** (`init.pp:263-275`): `simp_file_line { 'resolv_peerdns' }`
    (a `simp/simplib` type) sets `PEERDNS=no|yes` in
    `/etc/sysconfig/network` with `deconflict => true`.

- **`resolv::host_conf` (`manifests/host_conf.pp:12-37`)** — public class
  managing `/etc/host.conf` from `resolv/etc/host.conf.epp` with
  `$trim`/`$multi`/`$reorder`. `$spoof` is **defunct** (RH bug 1577265) and
  only emits `simplib::deprecation` when set (`host_conf.pp:31-36`).

### Gotchas / non-obvious details

- **`resolv` is NOT declared/`include`d by `resolv::host_conf`** and vice
  versa — they are independent public classes managing different files.
- **NetworkManager is selected two different ways.** `$use_nmcli` (which picks
  the render template) defaults to `simplib__networkmanager.enabled`, but the
  *drop-in file + HUP* block (`init.pp:215`) checks the fact **directly**, not
  `$use_nmcli`. If a user overrides `$use_nmcli => false` on a NetworkManager
  host, `$_nmcli_config_content` is set by the `present` branch to
  `"[main]\ndns=none\n"` (`init.pp:182`) and that is what gets written to the
  drop-in — i.e. DNS-via-NM is disabled but the drop-in is still managed.
- **At most 3 nameservers.** `$servers` is `Array[Simplib::IP,0,3]`
  (`init.pp:120`) — resolv.conf historically honors only three.
- **Caching-resolver guard.** With `127.0.0.1`/`::1` first and caching on, you
  must supply at least one more upstream or catalog compilation `fail()`s
  (`init.pp:245-247`).
- **`$content` bypasses augeas entirely** (`init.pp:198`) — the structured
  options/search/sortlist rendering is skipped and the file is written
  verbatim.
- **`--` option semantics differ by mode.** In direct mode a `--`-prefixed
  entry in `$extra_options` actively removes that option via the augeas lens;
  in NetworkManager mode `--` entries are filtered and ignored
  (`init.pp:178`, template `resolv.conf.epp:54-60`).
- **`$resolv_domain` and `resolv::host_conf::spoof` are deprecated/obsolete**
  (`init.pp:23-28`, `host_conf.pp:8-11,31-36`) but retained for API stability.
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet
  the manifest consumes the `simp_options::dns::*` seam via `simplib::lookup`
  (the lookup function is provided by `simp/simplib`). `simp_options` appears
  only as a test fixture (`.fixtures.yml:9`).
- **Ships a custom augeas lens** (`lib/augeas/lenses/resolv.aug`) — the direct
  mode depends on it being on the augeas load path.

## The `simp_options` / `simplib::lookup` seam

This is the module's SIMP feature-toggle seam. Both calls are in
`manifests/init.pp`:

| Line | Key | `default_value` |
|------|-----|-----------------|
| `init.pp:120` | `simp_options::dns::servers` | `undef` |
| `init.pp:121` | `simp_options::dns::search` | `undef` |

Keep routing SIMP feature toggles through
`simplib::lookup('simp_options::*', 'default_value' => ...)` with an explicit
default rather than assuming `simp_options` is included.

## Dependencies

Module dependencies (from `metadata.json:15-28`):

- `simp/simplib` `>= 4.9.0 < 6.0.0` (provides `simplib::lookup`,
  `simplib::host_is_me`, `simplib::deprecation`, the `simp_file_line` type, the
  `Simplib::IP` / `Simplib::Domain` data types, and the
  `simplib__networkmanager` fact)
- `simp/named` `>= 6.0.0 < 8.0.0` (the `named`, `named::caching` classes and
  `named::caching::forwarders` define, used by the autoconf branch)
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` (provides `stdlib::start_with` and
  `strip`/`concat`/`pick`/`sort`/`unique` helpers)

There is **no `simp.optional_dependencies`** key in `metadata.json`.

Fixture-only dependencies (from `.fixtures.yml`, present for test compilation,
not runtime deps): `augeas_core`, `rsync`, `selinux_core`, `simp_options`,
`concat` (plus the runtime deps above are also checked out as fixtures).

Runtime requirement (from `metadata.json` `requirements`): `openvox
>= 8.0.0 < 9.0.0`.

Supported OS matrix (from `metadata.json`): CentOS 9/10; RedHat 8/9/10;
OracleLinux 8/9/10; Rocky 8/9/10; AlmaLinux 8/9/10.

## Repository layout

- `manifests/init.pp` — the `resolv` class (all DNS logic).
- `manifests/host_conf.pp` — the `resolv::host_conf` class (`/etc/host.conf`).
- `types/domain.pp` — `Resolv::Domain` = `Variant[Simplib::Domain,Enum['.']]`.
- `types/sortlist.pp` — `Resolv::Sortlist` = array of IP/netmask entries.
- `templates/etc/resolv.conf.epp` — augeas-`changes` rules for direct mode.
- `templates/etc/NetworkManager/conf.epp` — NetworkManager drop-in content.
- `templates/etc/host.conf.epp` — `/etc/host.conf` content.
- `lib/augeas/lenses/resolv.aug` — custom augeas lens for `/etc/resolv.conf`.
- `metadata.json` — deps, OS matrix, OpenVox requirement (no optional deps).
- `spec/classes/init_spec.rb`, `spec/classes/host_conf_spec.rb` — rspec-puppet
  class unit tests.
- `spec/type_aliases/domain_spec.rb`, `spec/type_aliases/sortlist_spec.rb` —
  type-alias unit tests.
- `spec/acceptance/suites/default/00_default_spec.rb` — beaker acceptance suite;
  `spec/acceptance/nodesets/` ships both `docker_*` and vagrant nodesets
  (`almalinux`/`centos`/`oel`/`rhel`/`rocky` 8/9/10).
- `REFERENCE.md` — generated Puppet Strings reference.
- No `data/` / `hiera.yaml` — this module ships no in-module Hiera data.
- **Acceptance runs in CI:** `.github/workflows/pr_tests.yml` has an
  `acceptance` job (`pr_tests.yml:116-153`) alongside `puppet-syntax`,
  `puppet-style`, `ruby-style`, `file-checks`, `releng-checks`, and
  `spec-tests`. Its matrix nodes are `docker_alma8/9/10`, `docker_centos9/10`,
  `docker_oel8/9/10`, `docker_rhel8/9/10`, and `docker_rocky8/9/10`. It starts
  `podman.socket`, exports `DOCKER_HOST`, and runs
  `bundle exec rake beaker:suites[default,<node>]`. No `BEAKER_HYPERVISOR` env
  is set — the `docker_*` nodesets pin `hypervisor: docker` themselves.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run a single class spec
bundle exec rspec spec/classes/init_spec.rb

# Puppet lint
bundle exec rake lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md

# Run the default beaker acceptance suite (CI runs the docker_* nodes)
bundle exec rake beaker:suites[default]
```

Relevant gem pins (from `Gemfile`): `puppetlabs_spec_helper ~> 8.0.0`
(`Gemfile:30`), `simp-rake-helpers ~> 5.24.0` (`Gemfile:36`),
`simp-rspec-puppet-facts ~> 4.0.0` (`Gemfile:38`), `simp-beaker-helpers
~> 2.0.0` (`Gemfile:52`). Rubocop is pinned to `~> 1.88.0` (`Gemfile:16`). The
test group installs both `openvox` and `puppet` gems, defaulting to the
`>= 8 < 9` range (`Gemfile:23`). `spec/spec_helper.rb` uses
`require 'puppetlabs_spec_helper/module_spec_helper'` (`spec_helper.rb:11`).

## Conventions

- Preserve the `@summary` / `@param` puppet-strings docstrings on the classes —
  they drive `REFERENCE.md`. Regenerate `REFERENCE.md` after changing docs or
  parameters.
- Continue routing SIMP feature toggles through
  `simplib::lookup('simp_options::*', 'default_value' => ...)` rather than
  assuming `simp_options` is included.
- Keep the two DNS render paths (augeas lens for direct mode, EPP template for
  NetworkManager mode) in sync when adding options; remember `--` removal
  entries are honored only in direct mode.
- `Gemfile`, `spec/spec_helper.rb`, and `.github/workflows/pr_tests.yml` carry
  a **puppetsync** notice — they are baseline-managed and the next sync
  overwrites local edits. Push changes to those files upstream to the baseline,
  not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used in `manifests/init.pp`.
