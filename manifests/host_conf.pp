# This class configures /etc/host.conf.
# See host.conf(5) for descriptions of the variables.
#
class resolv::host_conf (
  Optional[Array[Pattern[/^\./]]] $trim    = undef,
  Boolean                         $multi   = true,
  Enum['off','nowarn','warn']     $spoof   = 'warn',
  Boolean                         $reorder = true
) {

  file { '/etc/host.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('resolv/etc/host.conf.erb')
  }
}
