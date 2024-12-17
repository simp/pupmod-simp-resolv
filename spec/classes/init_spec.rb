require 'spec_helper'

describe 'resolv' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts[:fqdn] = 'foo.bar.baz'
          os_facts[:hostname] = 'foo'
          os_facts[:interfaces] = 'eth0'
          os_facts[:ipaddress_eth0] = '10.0.2.15'

          # The traditional defaults
          os_facts.merge({
                           simplib__networkmanager: { 'enabled' => false }
                         })
        end

        context 'with default parameters' do
          let(:expected) do
            <<~EXPECTED
            rm #comment
            rm options/debug
            rm options/inet6
            rm options/no-check-names
            defnode opts options ""
            set $opts/attempts 2
            set $opts/ndots 1
            set $opts/rotate ""
            set $opts/timeout 2
            rm options[count(*)=0]
            EXPECTED
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/resolv.conf') }
          it { is_expected.to contain_augeas('/etc/resolv.conf').with_changes(expected) }
          it { is_expected.to contain_simp_file_line('resolv_peerdns') }
          it { is_expected.not_to contain_class('named') }
          it { is_expected.not_to contain_class('named::caching') }

          context 'with NetworkManager running but not managed' do
            let(:facts) do
              os_facts.merge({
                               simplib__networkmanager: { 'enabled' => true }
                             })
            end

            let(:params) do
              { use_nmcli: false }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to contain_file('/etc/resolv.conf') }
            it { is_expected.to contain_augeas('/etc/resolv.conf').with_changes(expected) }
            it { is_expected.to contain_simp_file_line('resolv_peerdns') }
            it { is_expected.not_to contain_class('named') }
            it { is_expected.not_to contain_class('named::caching') }
            it {
              is_expected.to contain_file('/etc/NetworkManager/conf.d/zz_10_simp_dns.conf')
                .with_owner('root')
                .with_group('root')
                .with_mode('0644')
                .with_content(
                  <<~CONTENT,
                  [main]
                  dns=none
                  CONTENT
                )
                .that_notifies('Exec[resolv_restart_networkmanager]')
            }
            it {
              is_expected.to contain_exec('resolv_restart_networkmanager')
                .with_command('pkill -HUP NetworkManager')
                .with_refreshonly(true)
                .with_path('/bin:/usr/bin')
            }
          end
        end

        context 'with nameservers and domain specified' do
          let(:params) do
            {
              servers: ['1.2.3.4', '5.6.7.8'],
              resolv_domain: os_facts[:domain]
            }
          end

          let(:expected) do
            <<~EXPECTED
            rm #comment
            rm nameserver[.!="1.2.3.4" and .!="5.6.7.8"]
            set nameserver[1] 1.2.3.4
            set nameserver[2] 5.6.7.8
            rm search/domain[.!="example.com"]
            set search/domain[.="example.com"] example.com
            rm options/debug
            rm options/inet6
            rm options/no-check-names
            defnode opts options ""
            set $opts/attempts 2
            set $opts/ndots 1
            set $opts/rotate ""
            set $opts/timeout 2
            rm options[count(*)=0]
            EXPECTED
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/resolv.conf') }
          it { is_expected.to contain_augeas('/etc/resolv.conf').with_changes(expected) }
          it { is_expected.to contain_simp_file_line('resolv_peerdns') }
          it { is_expected.not_to contain_class('named') }
          it { is_expected.not_to contain_class('named::caching') }
        end

        context 'resolv.conf with everything except nmcli set' do
          let(:params) do
            {
              servers: ['1.2.3.4', '5.6.7.8'],
              search: ['test.net'],
              sortlist: ['127.0.0.1'],
              extra_options: ['foo:bar', '--bar', '--baz:stuff'],
              resolv_domain: 'foo.bar',
              debug: true,
              rotate: false,
              no_check_names: true,
              inet6: true,
              ndots: 5,
              timeout: 5,
              attempts: 5
            }
          end

          let(:expected) do
            <<~EXPECTED
            rm #comment
            rm nameserver[.!="1.2.3.4" and .!="5.6.7.8"]
            set nameserver[1] 1.2.3.4
            set nameserver[2] 5.6.7.8
            rm search/domain[.!="foo.bar" and .!="test.net"]
            set search/domain[.="foo.bar"] foo.bar
            set search/domain[.="test.net"] test.net
            set sortlist/ipaddr["127.0.0.1"] 127.0.0.1
            rm sortlist/ipaddr[.!="127.0.0.1"]
            rm options/bar
            rm options/baz
            rm options/rotate
            defnode opts options ""
            set $opts/attempts 5
            set $opts/debug ""
            set $opts/foo bar
            set $opts/inet6 ""
            set $opts/ndots 5
            set $opts/no-check-names ""
            set $opts/timeout 5
            rm options[count(*)=0]
            EXPECTED
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/resolv.conf') }
          it { is_expected.to contain_augeas('/etc/resolv.conf').with_changes(expected) }
        end

        context 'with content specified' do
          let(:params) do
            {
              servers: ['1.2.3.4', '5.6.7.8'],
              resolv_domain: os_facts[:domain],
              content: 'foo'
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/resolv.conf').with_content(params[:content]) }
          it { is_expected.not_to contain_augeas('/etc/resolv.conf') }
          it { is_expected.to contain_simp_file_line('resolv_peerdns') }
          it { is_expected.not_to contain_class('named') }
          it { is_expected.not_to contain_class('named::caching') }
        end

        context 'with ensure=absent' do
          let(:params) do
            {
              ensure: 'absent',
              servers: ['1.2.3.4', '5.6.7.8']
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/resolv.conf').with_ensure('absent') }
          it { is_expected.not_to contain_augeas('/etc/resolv.conf') }
          it { is_expected.to contain_simp_file_line('resolv_peerdns') }
          it { is_expected.not_to contain_class('named') }
          it { is_expected.not_to contain_class('named::caching') }
          it { is_expected.not_to contain_file('/etc/NetworkManager/conf.d/zz_10_simp_dns.conf') }
        end

        context 'managing resolv.conf with nmcli' do
          let(:facts) do
            os_facts.merge({
                             simplib__networkmanager: {
                               'general' => {
                                 'status' => {
                                   'STATE'        => 'connected',
                                   'CONNECTIVITY' => 'full',
                                   'WIFI-HW'      => 'enabled',
                                   'WIFI'         => 'enabled',
                                   'WWAN-HW'      => 'enabled',
                                   'WWAN'         => 'enabled'
                                 },
                                 'hostname' => 'foo.bar.baz'
                               },
                               'enabled' => true,
                               'connection' => {
                                 'eth0' => {
                                   'uuid' => '5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03',
                                   'type' => '802-3-ethernet',
                                   'name' => 'System eth0'
                                 }
                               }
                             }
                           })
          end

          context 'manage via nmcli with all settings' do
            let(:params) do
              {
                servers: ['1.2.3.4', '5.6.7.8'],
                use_nmcli: true,
                nmcli_connection_name: 'System eth0',
                nmcli_ignore_auto_dns: true,
                nmcli_auto_reapply_device: true
              }
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_file('/etc/NetworkManager/conf.d/zz_10_simp_dns.conf')
                .with_owner('root')
                .with_group('root')
                .with_mode('0644')
                .with_content(
                  <<~CONTENT,
                  [main]
                  dns=default

                  [global-dns]
                  options=attempts:2,ndots:1,rotate,timeout:2

                  [global-dns-domain-*]
                  servers=1.2.3.4,5.6.7.8
                  CONTENT
                )
                .that_notifies('Exec[resolv_restart_networkmanager]')
            }
            it {
              is_expected.to contain_exec('resolv_restart_networkmanager')
                .with_command('pkill -HUP NetworkManager')
                .with_refreshonly(true)
                .with_path('/bin:/usr/bin')
            }
          end

          context 'node_is_nameserver' do
            let(:facts) { os_facts.merge({ ipaddress: '10.0.2.15' }) }

            let(:params) do
              {
                servers: ['1.2.3.4', '5.6.7.8', '10.0.2.15']
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.not_to contain_class('named::caching') }
            it { is_expected.to contain_class('named') }
          end
        end

        context 'node_is_nameserver' do
          let(:facts) do
            os_facts.merge({ ipaddress: '10.0.2.15' })
          end

          let(:params) do
            { servers: ['1.2.3.4', '5.6.7.8', '10.0.2.15'] }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_class('named::caching') }
          it { is_expected.to contain_class('named') }
        end

        context 'node_is_nameserver_with_selinux' do
          let(:facts) do
            os_facts.merge({
                             fqdn: 'foo.bar.baz',
              hostname: 'foo',
              interfaces: 'eth0',
              ipaddress_eth0: '10.0.2.15',
              selinux_enforced: true,
                           })
          end

          let(:params) do
            { servers: ['1.2.3.4', '5.6.7.8', '10.0.2.15'] }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_class('named::caching') }
          it { is_expected.to contain_class('named') }
        end

        context 'node_with_named_autoconf_and_caching' do
          let(:facts) do
            os_facts.merge({
                             fqdn: 'foo.bar.baz',
              hostname: 'foo',
              interfaces: 'eth0',
              ipaddress_eth0: '10.0.2.15',
                           })
          end

          let(:params) do
            { servers: ['127.0.0.1', '1.2.3.4', '5.6.7.8'] }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('named::caching') }
        end

        context 'node_with_named_autoconf_and_caching_only_127.0.0.1' do
          let(:facts) do
            os_facts.merge({
                             fqdn: 'foo.bar.baz',
              hostname: 'foo',
              interfaces: 'eth0',
              ipaddress_eth0: '10.0.2.15',
                           })
          end

          let(:params) do
            { servers: ['127.0.0.1'] }
          end

          it { expect { is_expected.to compile.with_all_deps }.to raise_error(%r{not be your only}) }
        end
      end
    end
  end
end
