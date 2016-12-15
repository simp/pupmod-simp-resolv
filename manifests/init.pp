# Configure resolv.conf
#
# See resolv.conf(5) for details on the various options.
#
# @param servers
#   An array of servers to query. If the first server is '127.0.0.1' or '::1'
#   then the host will be set up as a caching DNS server unless $caching is
#   set to false.  The other hosts will be used as the higher level
#   nameservers.
# @param search
#   Array of entries that will be searched, in order, for hosts.
# @param sortlist
#   Array of address/netmask pairs that allow addresses returned by
#   gethostbyname to be sorted.
# @param extra_options
#   A place to put any options that may not be covered by the
#   variables below. These will be appended to the options string.
# @param resolv_domain
#   Local domain name, defaults to the domain of your host.
#
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
#
class resolv (
  Array           $servers        = simplib::lookup('simp_options::dns::servers', { 'default_value' => ['127.0.0.1'], 'value_type'      => Array[String] }),
  Array           $search         = simplib::lookup('simp_options::dns::search', { 'default_value'  => [$facts['domain']], 'value_type' => Array[String] }),
  Optional[Array] $sortlist       = undef,
  Optional[Array] $extra_options  = undef,
  String          $resolv_domain  = $facts['domain'],
  Boolean         $debug          = false,
  Boolean         $rotate         = true,
  Boolean         $no_check_names = false,
  Boolean         $inet6          = false,
  Integer         $ndots          = 1,
  Integer         $timeout        = 2,
  Integer         $attempts       = 2,
  Boolean         $named_server   = false,
  Boolean         $named_autoconf = true,
  Boolean         $caching        = true
) {
  if $sortlist { validate_net_list($sortlist) }

  file { '/etc/resolv.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('resolv/etc/resolv.conf.erb')
  }

  # If this client is one of these passed IP's, then make it a real DNS server
  if $named_server or (defined('named') and defined(Class['named'])) or ($named_autoconf and host_is_me($servers)) {
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
    deconflict => true
  }

  if defined_with_params(Class['named'], {'chroot' => false}) {
      $bind_pkg = 'bind'
  }
  else {
    $bind_pkg = 'bind-chroot'
  }

}
