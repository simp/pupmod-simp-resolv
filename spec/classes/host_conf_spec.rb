require 'spec_helper'

describe 'resolv::host_conf' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context 'with default parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_file('/etc/host.conf').with_content(<<-EOM.gsub(/^\s+/,''))
            multi on
            spoof warn
            reorder on
            EOM
          }
        end

        context 'with_trim' do
          let(:params){{ :trim => ['.bar.baz','.alpha.beta'] }}
          it { is_expected.to create_file('/etc/host.conf').with_content(<<-EOM.gsub(/^\s+/,''))
             multi on
             spoof warn
             reorder on
             trim .bar.baz,.alpha.beta
             EOM
          }
        end

        context 'with_bad_trim' do
          let(:params){{ :trim => ['bar.baz'] }}
          it {
            expect {
              is_expected.to compile.with_all_deps
            }.to raise_error(/expects a match for Pattern/)
          }
        end
      end
    end
  end
end
