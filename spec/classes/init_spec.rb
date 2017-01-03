require 'spec_helper'

describe 'resolv' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts[:fqdn] = 'foo.bar.baz'
          facts[:hostname] = 'foo'
          facts[:interfaces] = 'eth0'
          facts[:ipaddress_eth0] = '10.0.2.15'

          facts
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

        context 'resolv.conf with everything set' do
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
            :attempts => 5
          }}
          let(:expected) { File.read('spec/expected/fancy_resolv.conf') }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/resolv.conf').with_content(expected) }
        end

        context 'node_is_nameserver' do
          let(:facts) { facts.merge({:ipaddress => '10.0.2.15'}) }

          let(:params) {{
            :servers => ['1.2.3.4','5.6.7.8','10.0.2.15']
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_class('named::caching') }
          it { is_expected.to contain_class('named') }
        end

        context 'node_is_nameserver_with_selinux' do
          let(:facts) { facts.merge({
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
          let(:facts) { facts.merge({
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
          let(:facts) { facts.merge({
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
