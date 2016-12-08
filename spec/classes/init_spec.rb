require 'spec_helper'

describe 'resolv' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        let(:params) {{
          :servers => ['1.2.3.4','5.6.7.8']
        }}

        context 'with default parameters' do
          let(:expected) { File.read('spec/expected/default_resolv.conf') }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/resolv.conf').with_content(expected) }
        end

        context 'with everything set' do
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

      end
    end
  end
end
