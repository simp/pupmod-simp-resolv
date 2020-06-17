# See resolv.conf(5) for details on the various options.
#
# @param servers
#   An array of servers to query. If the first server is '127.0.0.1' or '::1'
#   then the host will be set up as a caching DNS server unless $caching is
#   set to false.  The other hosts will be used as the higher level
#   nameservers
# @param search
#   Array of entries that will be searched, in order, for hosts.
# @param resolv_domain
#   Local domain name, defaults to the domain of your host.
# @param debug
#   Print debugging messages
# @param rotate
#   When `true`, enables round-robin selection of $servers to distribute the
#   query load.
# @param no_check_names
#   When `true`, disables the modern BIND checking of incoming hostnames and
#   mail names for invalid characters such as underscore (`_`), non-ASCII, or
#   control characters.
# @param inet6
#   When `true`, use AAAA (IPv6) queries and convert A (IPv4) results
# @param ndots
#   Value for the `ndots:` option in resolv.conf
# @param timeout
#   Amount of time (in seconds) the resolver will wait for a response
# @param attempts
#   Number of times to attempt querying $servers before giving up
# @param named_server
#   A boolean that states that this server is definitively a named server.
#   Bypasses the need for $named_autoconf below.
# @param named_autoconf
#   A boolean that controlls whether or not to autoconfigure named.
#   true => If the server where puppet is being run is in the list of
#           $servers then automatically configure named.
#   false => Do not autoconfigure named.
# @param caching
#   *If* the $servers array above starts with '127.0.0.1' or '::1', then
#   the system will set itself up as a caching nameserver unless this is set
#   to false.
# @param use_nmcli
#   Allows the user to update DNS entries via nmcli instead of directly
#   modifying resolv.conf
# @nmcli_device_name
#   If managing DNS servers via nmcli, this is the device the IPv4 DNS servers
#   will be added to
# @nmcli_ignore_auto_dns
#   If true, ignore the automatic DNS entries from Network Manager and instead
#   only use servers explicitly passed to this manifest
# @nmcli_auto_reapply_device
#   If true, call nmcli device reapply on the device that had DNS servers added
#   to it
# @param sortlist
#   Optional Array of address/netmask pairs that allow addresses returned by
#   gethostbyname to be sorted.
# @param extra_options
#   Optional Array to put any options that may not be covered by the variables
#   below. These will be appended to the options string.
class resolv (
  Array[Simplib::IP,0,3]     $servers                   = simplib::lookup('simp_options::dns::servers', { 'default_value' => ['127.0.0.1'] }),
  Array[Simplib::Domain,0,6] $search                    = simplib::lookup('simp_options::dns::search', { 'default_value'  => [$facts['domain']] }),
  Resolv::Domain             $resolv_domain             = $facts['domain'],
  Boolean                    $debug                     = false,
  Boolean                    $rotate                    = true,
  Boolean                    $no_check_names            = false,
  Boolean                    $inet6                     = false,
  Integer[0,15]              $ndots                     = 1,
  Integer[0,30]              $timeout                   = 2,
  Integer[0,5]               $attempts                  = 2,
  Boolean                    $named_server              = false,
  Boolean                    $named_autoconf            = true,
  Boolean                    $caching                   = true,
  Boolean                    $use_nmcli                 = false,
  Optional[String]           $nmcli_device_name         = undef,
  Boolean                    $nmcli_ignore_auto_dns     = true,
  Boolean                    $nmcli_auto_reapply_device = false,
  Optional[Resolv::Sortlist] $sortlist                  = undef,
  Optional[Array[String]]    $extra_options             = undef,
) {

  if $use_nmcli {
    if empty($nmcli_device_name) {
      fail('Cannot modify DNS servers via nmcli unless a device name is specified. Please ensure resolv::nmcli_device_name is set to a valid network device name')
    } else {
      if ! dig($facts, 'simplib__networkmanager', 'connection', $nmcli_device_name) {
        fail("The specified device: ${nmcli_device_name} is not managed by Network Manager and cannot be modified")
      }

      # Make sure we are on EL7 or newer as the nmcli commands on EL6 were not fully featured for managing resolv.conf
      if ($facts['os']['family'] == 'RedHat') and ($facts['os']['release']['major'] == '6') {
        fail('This module can only manage resolv.conf via nmcli on EL7 or newer distributions')
      }

      $_flattened_name_servers = $servers.join(' ')
      $conn_name = dig($facts, 'simplib__networkmanager', 'connection', $nmcli_device_name, 'name')

      $conn_mod_cmd = $nmcli_ignore_auto_dns ? {
        true    => "nmcli connection modify \"${conn_name}\" ipv4.ignore-auto-dns true ipv4.dns \"${_flattened_name_servers}\"",
        default => "nmcli connection modify \"${conn_name}\" ipv4.dns \"${_flattened_name_servers}\""
      }

      # Add the specified nameservers unless they are already configured for the given device
      exec { 'Add DNS servers via nmcli':
        command => $conn_mod_cmd,
        unless  => "[ \"\$( nmcli -f ip4.dns device show ${nmcli_device_name} | awk '{print \$2}' | tr '\\n' ' ' )\" == \"${_flattened_name_servers} \" ]",
        path    => '/bin:/usr/bin',
      }

      # If specified, reapply the device so that the DNS servers are active
      if $nmcli_auto_reapply_device {
        exec { 'Reapply network device to update DNS servers':
          command     => "nmcli device reapply ${nmcli_device_name}",
          path        => '/bin:/usr/bin',
          subscribe   => Exec['Add DNS servers via nmcli'],
          refreshonly => true,
        }
      }
    }
  }

  $_resolv_conf_content = epp('resolv/etc/resolv.conf.epp', {
    'nameservers'    => $servers,
    'domain'         => $resolv_domain,
    'search'         => $search,
    'sortlist'       => $sortlist,
    'debug'          => $debug,
    'ndots'          => $ndots,
    'timeout'        => $timeout,
    'attempts'       => $attempts,
    'rotate'         => $rotate,
    'no_check_names' => $no_check_names,
    'inet6'          => $inet6,
    'extra_options'  => $extra_options,
  })

  file { '/etc/resolv.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => $_resolv_conf_content,
  }

  # If this client is one of these passed IP's, then make it a real DNS server
  if $named_server or (defined('named') and defined(Class['named'])) or ($named_autoconf and simplib::host_is_me($servers)) {
    $l_is_named_server = true
  }
  else {
    $l_is_named_server = false
  }

  if $named_autoconf {
    # Having 127.0.0.1 or ::1 first tells us that we want to be a
    # caching DNS server.
    if ! $l_is_named_server and $caching and ($servers[0] == '127.0.0.1' or $servers[0] == '::1' ) {
      if size($servers) == 1 {
        fail('If using named as a caching server, 127.0.0.1 must not be your only nameserver entry.')
      }
      else {
        include '::named::caching'

        $l_forwarders = inline_template('<%= @servers[1..-1].join(" ") %>')
        named::caching::forwarders { $l_forwarders: }
      }
    }
    else {
      if $l_is_named_server {
        include '::named'
      }
    }
  }

  # We're managing resolv.conf, so ignore what dhcp says.
  simp_file_line { 'resolv_peerdns':
    path       => '/etc/sysconfig/network',
    line       => 'PEERDNS=no',
    match      => '^\s*PEERDNS=',
    deconflict => true,
  }
}
