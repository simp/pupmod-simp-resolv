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
class resolv (
  Array $servers                 = simplib::lookup('::simp_options::dns::servers', { 'default_value' => ['127.0.0.1'], 'value_type'      => Array[String] }),
  Array $search                  = simplib::lookup('::simp_options::dns::search', { 'default_value'  => [$facts['domain']], 'value_type' => Array[String] }),
  Optional[Array] $sortlist      = undef,
  Optional[Array] $extra_options = undef,
  String $resolv_domain          = $facts['domain'],
  Boolean $debug                 = false,
  Boolean $rotate                = true,
  Boolean $no_check_names        = false,
  Boolean $inet6                 = false,
  Integer $ndots                 = 1,
  Integer $timeout               = 2,
  Integer $attempts              = 2
) {
  if $sortlist { validate_net_list($sortlist) }

  file { '/etc/resolv.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('resolv/etc/resolv.conf.erb')
  }
}
