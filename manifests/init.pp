# @summary Configures /etc/resolv.conf or the NetworkManager equivalent
#
# @see resolv.conf(5)
#
# @param ensure
#   Remove the resolv.conf from the system if set to `absent`
#
#   * No other actions will be performed on the resolv.conf file if this is set
#
# @param servers
#   An array of servers to query. If the first server is '127.0.0.1' or '::1'
#   then the host will be set up as a caching DNS server unless $caching is
#   set to false.  The other hosts will be used as the higher level
#   nameservers
#
#   * Set to `false` to actively remove this option from the configuration
#
# @param min_num_servers
#   An integer between 0 and 3 that represents the minimum number of dns
#   servers that must be configured. This number will be checked against
#   the length of the servers parameter. Puppet will fail and throw an
#   error if the minimum number of servers is not configured.
#
# @param search
#   Array of entries that will be searched, in order, for hosts.
#
#   * Set to `false` to actively remove this option from the configuration
#
# @param resolv_domain
#   Local domain name, defaults to the domain of your host.
#
#   * This is obsolete, please use `$search` instead.
#
#   * Set to `false` to actively remove this option from the configuration
#
# @param debug
#   Print debugging messages
#
# @param rotate
#   When `true`, enables round-robin selection of $servers to distribute the
#   query load.
#
# @param no_check_names
#   When `true`, disables the modern BIND checking of incoming hostnames and
#   mail names for invalid characters such as underscore (`_`), non-ASCII, or
#   control characters.
#
# @param inet6
#   When `true`, use AAAA (IPv6) queries and convert A (IPv4) results
#
# @param ndots
#   Value for the `ndots:` option in resolv.conf
#
#   * Set to `false` to actively remove this option from the configuration
#
# @param timeout
#   Amount of time (in seconds) the resolver will wait for a response
#
#   * Set to `false` to actively remove this option from the configuration
#
# @param attempts
#   Number of times to attempt querying $servers before giving up
#
#   * Set to `false` to actively remove this option from the configuration
#
# @param named_server
#   A boolean that states that this server is definitively a named server.
#   Bypasses the need for $named_autoconf below.
#
# @param named_autoconf
#   A boolean that controlls whether or not to autoconfigure named.
#   true           => If the server where puppet is being run is in the list of
#           $servers then automatically configure named.
#   false          => Do not autoconfigure named.
#
# @param caching
#   *If* the $servers array above starts with '127.0.0.1' or '::1', then
#   the system will set itself up as a caching nameserver unless this is set
#   to false.
#
# @param use_nmcli
#   Allows the user to update DNS entries via nmcli instead of directly
#   modifying resolv.conf
#
# @param nmcli_connection_name
#   **DEPRECATED** => Remains for API until next release
#
# @param nmcli_ignore_auto_dns
#   **DEPRECATED** => Remains for API until next release
#
# @param nmcli_auto_reapply_device
#   **DEPRECATED** => Remains for API until next release
#
# @param sortlist
#   Optional Array of address/netmask pairs that allow addresses returned by
#   gethostbyname to be sorted.
#
#   * Set to `false` to actively remove this option from the configuration
#
# @param extra_options
#   Optional Array to put any options that may not be covered by the variables
#   below. These will be appended to the options string.
#
#   * Adding `--` in front of any option will actively remove it from the
#     configuration if not using NMCLI
#   * When using NMCLI , '--' items will be ignored since it is authoritative
#
#   @example Manage Extra Options
#
#     ---
#     extra_options:
#       # Add ip6-bytestring
#       - 'ip6-bytestring'
#       # Ensure that ip6-dotint is not set
#       - '--ip6-dotint'
#
# @param content
#   Unless in NMCLI mode, ignores all other options and writes the specified
#   content to `/etc/resolv.conf`
#
# @param ignore_dhcp_dns
#   Ignores entries passed down from DHCP
#
class resolv (
  Enum['present', 'absent']                                 $ensure                    = 'present',
  Optional[Variant[Boolean[false], Array[Simplib::IP,0,3]]] $servers                   = simplib::lookup('simp_options::dns::servers', 'default_value' => undef ),
  Optional[Integer[0,3]]                                    $min_num_servers           = 0,
  Optional[Variant[Boolean[false], Array[Simplib::Domain]]] $search                    = simplib::lookup('simp_options::dns::search', 'default_value' => undef ),
  Optional[Variant[Boolean[false], Resolv::Domain]]         $resolv_domain             = undef,
  Boolean                                                   $debug                     = false,
  Boolean                                                   $rotate                    = true,
  Boolean                                                   $no_check_names            = false,
  Boolean                                                   $inet6                     = false,
  Variant[Boolean[false], Integer[0,15]]                    $ndots                     = 1,
  Variant[Boolean[false], Integer[0,30]]                    $timeout                   = 2,
  Variant[Boolean[false], Integer[0,5]]                     $attempts                  = 2,
  Boolean                                                   $named_server              = false,
  Boolean                                                   $named_autoconf            = true,
  Boolean                                                   $caching                   = true,
  Boolean                                                   $use_nmcli                 = pick($facts.dig('simplib__networkmanager', 'enabled'), false),
  Optional[String[1]]                                       $nmcli_connection_name     = undef,
  Optional[Boolean]                                         $nmcli_ignore_auto_dns     = undef,
  Optional[Boolean]                                         $nmcli_auto_reapply_device = undef,
  Optional[Variant[Boolean[false], Resolv::Sortlist]]       $sortlist                  = undef,
  Optional[Array[String[1]]]                                $extra_options             = undef,
  Optional[Variant[Array[String[1]], String[1]]]            $content                   = undef,
  Boolean                                                   $ignore_dhcp_dns           = true
) {

  if $servers.length <= $min_num_servers {
    fail("The number of dns servers configured: ${servers.length} is less than the minimum number of servers configured: ${min_num_servers}")
  }

  if $ensure == 'absent' {
    file { '/etc/resolv.conf': ensure => 'absent' }
  }
  else {
    $_options = sort(unique(concat(
      $ndots ? { false => ['--ndots'], default => ["ndots:${ndots}"] },
      $timeout ? { false => ['--timeout'], default => ["timeout:${timeout}"] },
      $attempts ? { false => ['--attempts'], default => ["attempts:${attempts}"] },
      $debug ? { true => ['debug'], false => ['--debug'], default => [] },
      $rotate ? { true => ['rotate'], false => ['--rotate'], default => [] },
      $no_check_names ? { true => ['no-check-names'], false => ['--no-check-names'], default => [] },
      $inet6 ? { true => ['inet6'], false => ['--inet6'], default => [] },
      $extra_options ? { NotUndef => $extra_options, default => [] }
    )))

    if $search {
      if $resolv_domain {
        $_search = sort(unique($search + [$resolv_domain]))
      }
      else {
        $_search = $search
      }
    }
    elsif $resolv_domain {
      $_search = [$resolv_domain]
    }
    else {
      $_search = $search
    }

    if $use_nmcli {
      $_nmcli_config_content = epp('resolv/etc/NetworkManager/conf.epp',
        {
          'nameservers' => pick($servers, []),
          'search'      => $_search,
          'options'     => $_options.filter |$opt| { !stdlib::start_with($opt, '--') }
        })
    }
    elsif $ensure == 'present' {
      $_nmcli_config_content = "[main]\ndns=none\n"

      if $content {
        $_content = $content.split("\n").map |$entry| { strip($entry) }.join("\n")
      }
      else {
        $_content = undef
      }

      file { '/etc/resolv.conf':
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => $_content
      }

      unless $content {
        $_resolv_conf_rules = epp('resolv/etc/resolv.conf.epp', {
          'nameservers' => pick($servers, []),
          'domain'      => $resolv_domain,
          'search'      => $_search,
          'sortlist'    => $sortlist,
          'options'     => $_options
        })

        augeas { '/etc/resolv.conf':
          context => '/files/etc/resolv.conf',
          changes => $_resolv_conf_rules,
          require => File['/etc/resolv.conf']
        }
      }
    }

    if $facts.dig('simplib__networkmanager', 'enabled') {
      file { '/etc/NetworkManager/conf.d/zz_10_simp_dns.conf':
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => $_nmcli_config_content,
        notify  => Exec["${module_name}_restart_networkmanager"]
      }

      exec { "${module_name}_restart_networkmanager":
        command     => 'pkill -HUP NetworkManager',
        refreshonly => true,
        path        => '/bin:/usr/bin'
      }
    }
  }

  if $servers =~ Array[Simplib::IP] {
    # If this client is one of these passed IP's, then make it a real DNS server
    if $named_server or (defined('named') and defined(Class['named'])) or ($named_autoconf and simplib::host_is_me($servers)) {
      $_is_named_server = true
    }
    else {
      $_is_named_server = false
    }

    if $named_autoconf {
      # Having 127.0.0.1 or ::1 first tells us that we want to be a
      # caching DNS server.
      if ! $_is_named_server and $caching and ($servers[0] == '127.0.0.1' or $servers[0] == '::1' ) {
        if size($servers) == 1 {
          fail('If using named as a caching server, 127.0.0.1 must not be your only nameserver entry.')
        }
        else {
          include 'named::caching'

          $l_forwarders = inline_template('<%= @servers[1..-1].join(" ") %>')
          named::caching::forwarders { $l_forwarders: }
        }
      }
      else {
        if $_is_named_server {
          include 'named'
        }
      }
    }
  }

  if $ignore_dhcp_dns {
    $_peerdns = 'no'
  }
  else {
    $_peerdns = 'yes'
  }

  simp_file_line { 'resolv_peerdns':
    path       => '/etc/sysconfig/network',
    line       => "PEERDNS=${_peerdns}",
    match      => '^\s*PEERDNS=',
    deconflict => true,
  }
}
