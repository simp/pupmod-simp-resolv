# @summary Configures /etc/host.conf
#
# @see host.conf(5)
#
# @param trim
# @param multi
# @param reorder
# @param spoof
#   defunct, see: https://bugzilla.redhat.com/show_bug.cgi?id=1577265)
#
#   Remains to prevent issues with direct ``class`` calls.
class resolv::host_conf (
  Optional[Array[Pattern[/^\./]]] $trim    = undef,
  Boolean                         $multi   = true,
  Boolean                         $reorder = true,
  Optional[String]                $spoof   = undef
) {
  file { '/etc/host.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp(
      'resolv/etc/host.conf.epp', {
        'trim'    => $trim,
        'multi'   => $multi,
        'reorder' => $reorder
      }
    )
  }

  if $spoof {
    simplib::deprecation(
      'resolv::host_conf::spoof',
      'resolv::host_conf::spoof has been deprecated since it has no effect on the system'
    )
  }
}
