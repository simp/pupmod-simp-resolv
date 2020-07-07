require 'spec_helper_acceptance'

test_name 'resolv'

describe 'resolv' do
  servers = ['8.8.8.8', '8.8.4.4', '1.1.1.1']

  hosts.each do |host|
    context "on #{host} with default options" do
      let(:manifest) do
        <<~EOF
          class { 'resolv':
            servers                   => #{servers},
          }
        EOF
      end

      it 'should apply with no errors' do
        apply_manifest_on(host, manifest)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end
    end

    if pfact_on(host, 'operatingsystemmajrelease').to_i >= 7
      context "on #{host} with default options using legacy network" do
        let(:manifest) do
          <<~EOF
            if $facts['os']['release']['major'] == '7' {
              $package = 'initscripts'
            } else {
              $package = 'network-scripts'
            }
            package { $package:
              ensure => installed,
            }
            -> service { 'NetworkManager':
              ensure => stopped,
              enable => false,
            }
            -> service { 'network':
              ensure => running,
              enable => true,
            }
            -> class { 'resolv':
              servers => #{servers},
            }
          EOF
        end

        it 'should apply with no errors' do
          apply_manifest_on(host, manifest)
        end
      end

      context "on #{host} with default options using NM" do
        let(:manifest) do
          <<~EOF
            package { 'NetworkManager':
              ensure => installed,
            }
            -> service { 'network':
              ensure => stopped,
              enable => false,
            }
            -> service { 'NetworkManager':
              ensure => running,
              enable => true,
            }
            -> class { 'resolv':
              servers => #{servers},
            }
          EOF
        end

        it 'should apply with no errors' do
          apply_manifest_on(host, manifest)
        end
      end

      context "on #{host} with NetworkManager" do
        let(:manifest) do
          <<~EOF
            class { 'resolv':
              servers                   => #{servers},
              use_nmcli                 => true,
              nmcli_connection_name     => "System eth0",
              nmcli_ignore_auto_dns     => true,
              nmcli_auto_reapply_device => true,
            }
          EOF
        end

        it 'should apply with no errors' do
          apply_manifest_on(host, manifest)
        end

        it 'should be idempotent' do
          apply_manifest_on(host, manifest, catch_changes: true)
        end

        it 'should list all of the new DNS servers in the device information' do
          device = pfact_on(host, 'defaultgatewayiface')

          result = on host,
            %{nmcli -f ip4.dns device show #{device} | awk '{print $2}'},
            :accept_all_exit_codes => true

          nameservers = result.stdout.split("\n")

          # Ensure list of nameservers matches the nameservers declared in the Puppet manifest
          expect(nameservers).to eq(servers)
        end

        it 'should fail gracefully on an unmanaged interface' do
          device = pfact_on(host, 'defaultgatewayiface')

          on host,
            %{sed -i -e '/^NM_CONTROLLED=/d;$a NM_CONTROLLED=no' /etc/sysconfig/network-scripts/ifcfg-#{device} && systemctl restart NetworkManager}

          result = apply_manifest_on(host, manifest, expect_failures: true)
          expect(result.stderr).to match %r{The specified connection: "System eth0" is not managed}
        end
      end
    end
  end
end
