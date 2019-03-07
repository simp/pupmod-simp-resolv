# This class configures /etc/host.conf.
# See host.conf(5) for descriptions of the variables.
#
# @param trim
# @param multi
# @param spoof
#   defunct, see: https://bugzilla.redhat.com/show_bug.cgi?id=1577265)
#
#   Remains to prevent issues with direct ``class`` calls.
# @param reorder
class resolv::host_conf (
  Optional[Array[Pattern[/^\./]]] $trim    = undef,
  Boolean                         $multi   = true,
  Optional[String]                $spoof   = undef,
  Boolean                         $reorder = true
) {

  file { '/etc/host.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('resolv/etc/host.conf.erb')
  }

  if $spoof {
    simplib::deprecation(
      'resolv::host_conf::spoof',
      'resolv::host_conf::spoof has been deprecated since it has no effect on the system'
    )
  }
}
