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

          os_facts
        end

        let(:params) {{
          :servers => ['1.2.3.4','5.6.7.8']
        }}

        context 'with default parameters' do
          let(:params) {{
            :servers => ['1.2.3.4','5.6.7.8']
            }}
          let(:expected) { File.read('spec/expected/default_resolv.conf') }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/resolv.conf').with_content(expected) }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_simp_file_line('resolv_peerdns') }
          it { is_expected.not_to contain_class('named') }
          it { is_expected.not_to contain_class('named::caching') }
        end

        context 'resolv.conf with everything except nmcli set' do
          let(:params) {{
            :servers => ['1.2.3.4','5.6.7.8'],
            :search  => ['test.net'],
            :sortlist => ['127.0.0.1'],
            :extra_options => ['foo = bar'],
            :resolv_domain => 'test.net',
            :debug => true,
            :rotate => false,
            :no_check_names => true,
            :inet6 => true,
            :ndots => 5,
            :timeout => 5,
            :attempts => 5,
          }}
          let(:expected) { File.read('spec/expected/fancy_resolv.conf') }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/resolv.conf').with_content(expected) }
        end

        unless os_facts[:os][:release][:major].to_i < 7
          context 'managing resolv.conf with nmcli' do
            let(:facts) { os_facts.merge({:simplib__networkmanager => {
              "general" => {
                "status" => {
                  "STATE" => "connected",
                  "CONNECTIVITY" => "full",
                  "WIFI-HW" => "enabled",
                  "WIFI" => "enabled",
                  "WWAN-HW" => "enabled",
                  "WWAN" => "enabled"
                },
                "hostname" => "foo.bar.baz"
              },
              "enabled" => true,
              "connection" => {
                "eth0" => {
                  "uuid" => "5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03",
                  "type" => "802-3-ethernet",
                  "name" => "System eth0"
                }
              }
            }})}

            context 'manage via nmcli with all settings' do
              let(:params) {{
                :servers => ['1.2.3.4','5.6.7.8'],
                :use_nmcli => true,
                :nmcli_device_name => 'eth0',
                :nmcli_ignore_auto_dns => true,
                :nmcli_auto_reapply_device => true
              }}
              it { is_expected.to compile.with_all_deps }
              it { is_expected.to contain_exec('Add DNS servers via nmcli') }
              it { is_expected.to contain_exec('Reapply network device to update DNS servers').that_subscribes_to('Exec[Add DNS servers via nmcli]') }
            end

            context 'manage via nmcli and but do not reapply the device' do
              let(:params) {{
                :servers => ['1.2.3.4','5.6.7.8'],
                :use_nmcli => true,
                :nmcli_device_name => 'eth0',
                :nmcli_ignore_auto_dns => true,
                :nmcli_auto_reapply_device => false
              }}
              it { is_expected.to compile.with_all_deps }
              it { is_expected.to contain_exec('Add DNS servers via nmcli') }
              it { is_expected.not_to contain_exec('Reapply network device to update DNS servers') }
            end
          end

          context 'node_is_nameserver' do
            let(:facts) { os_facts.merge({:ipaddress => '10.0.2.15'}) }

            let(:params) {{
              :servers => ['1.2.3.4','5.6.7.8','10.0.2.15']
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.not_to contain_class('named::caching') }
            it { is_expected.to contain_class('named') }
          end
        end

        context 'node_is_nameserver' do
          let(:facts) { os_facts.merge({:ipaddress => '10.0.2.15'}) }

          let(:params) {{
            :servers => ['1.2.3.4','5.6.7.8','10.0.2.15']
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_class('named::caching') }
          it { is_expected.to contain_class('named') }
        end

        context 'node_is_nameserver_with_selinux' do
          let(:facts) { os_facts.merge({
            :fqdn => 'foo.bar.baz',
            :hostname => 'foo',
            :interfaces => 'eth0',
            :ipaddress_eth0 => '10.0.2.15',
            :selinux_enforced => true,
          }) }
          let(:params) {{
            :servers => ['1.2.3.4','5.6.7.8','10.0.2.15']
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_class('named::caching') }
          it { is_expected.to contain_class('named') }
        end

        context 'node_with_named_autoconf_and_caching' do
          let(:facts) { os_facts.merge({
            :fqdn => 'foo.bar.baz',
            :hostname => 'foo',
            :interfaces => 'eth0',
            :ipaddress_eth0 => '10.0.2.15',
          }) }
          let(:params) {{
            :servers => ['127.0.0.1','1.2.3.4','5.6.7.8']
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('named::caching') }
        end

        context 'node_with_named_autoconf_and_caching_only_127.0.0.1' do
          let(:facts) { os_facts.merge({
            :fqdn => 'foo.bar.baz',
            :hostname => 'foo',
            :interfaces => 'eth0',
            :ipaddress_eth0 => '10.0.2.15',
          }) }
          let(:params) {{
            :servers => ['127.0.0.1']
          }}
          it { expect { is_expected.to compile.with_all_deps}.to raise_error(/not be your only/) }
        end

      end
    end
  end
end
