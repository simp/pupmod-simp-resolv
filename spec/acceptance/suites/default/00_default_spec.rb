require 'spec_helper_acceptance'

test_name 'resolv'

describe 'resolv' do

  servers = ['8.8.8.8', '8.8.4.4', '1.1.1.1']

  hosts.each do |host|
    let(:manifest) { <<~EOF
      class { 'resolv':
        servers                   => #{servers},
        manage_via_nmcli          => true,
        nmcli_device_name         => $facts['defaultgatewayiface'],
        nmcli_ignore_auto_dns     => true,
        auto_reapply_nmcli_device => true,
      }
      EOF
    }

    hosts.each do |host|
      context "on #{host}" do

        it 'should apply with no errors' do
          apply_manifest_on(host, manifest)
        end

        it 'should be idempotent' do
          apply_manifest_on(host, manifest, catch_changes: true)
        end

        it 'should list all of the new DNS servers in the device information' do
          device = pfact_on(host, 'defaultgatewayiface')

          nameservers = on(
            hosts.find { |h| h != host },
            %{nmcli -f ip4.dns device show #{device} | awk '{print $2}' | sort | tr '\n' ' '},
            :accept_all_exit_codes => true
          ).stdout.split(' ')

          # Ensure list of nameservers matches the nameservers declared in the Puppet manifest
          expect(nameservers).to eq(servers)
        end
      end
    end
  end
end
