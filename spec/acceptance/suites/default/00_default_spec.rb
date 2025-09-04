require 'spec_helper_acceptance'

test_name 'resolv'

describe 'resolv' do
  servers = ['8.8.8.8', '8.8.4.4', '1.1.1.1']

  hosts.each do |host|
    context "prep #{host}" do
      # This is in place for EL8 and is due to single-request-reopen being
      # spammed into set by /etc/NetworkManager/dispatcher.d/fix-slow-dns which
      # appears to be a bug in the CentOS Vagrant image.
      it 'removes the fix-slow-dns script' do
        on(host, 'puppet resource file /etc/NetworkManager/dispatcher.d/fix-slow-dns ensure=absent')
        on(host, %(sed -i '/options/d' /etc/resolv.conf))
      end
    end
  end

  hosts.each do |host|
    context "on #{host} with default options and not networkmanager" do
      let(:manifest) do
        <<~EOF
          class { 'resolv':
            servers   => #{servers.reverse},
            search    => ['simp.beaker', 'foo.bar', 'bar.baz'],
            use_nmcli => false,
          }
        EOF
      end

      it 'applies with no errors' do
        apply_manifest_on(host, manifest)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it 'has a properly filled /etc/resolv.conf' do
        expected_content = <<~EXPECTED
          search simp.beaker foo.bar bar.baz
          nameserver 1.1.1.1
          nameserver 8.8.4.4
          nameserver 8.8.8.8
          options attempts:2 ndots:1 rotate timeout:2
        EXPECTED

        expect(file_content_on(host, '/etc/resolv.conf').strip).to eq(expected_content.strip)
      end
    end

    context "on #{host} with disabled options" do
      let(:manifest) do
        <<~EOF
          class { 'resolv':
            servers   => #{servers},
            search    => ['simp.beaker', 'foo.bar', 'bar.baz'],
            use_nmcli => false,
            rotate    => false,
            attempts  => false,
            ndots     => false,
            timeout   => false
          }
        EOF
      end

      it 'applies with no errors' do
        apply_manifest_on(host, manifest)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it 'has a properly filled /etc/resolv.conf' do
        expected_content = <<~EXPECTED
          search simp.beaker foo.bar bar.baz
          nameserver 8.8.8.8
          nameserver 8.8.4.4
          nameserver 1.1.1.1
        EXPECTED

        expect(file_content_on(host, '/etc/resolv.conf').strip).to eq(expected_content.strip)
      end
    end

    context "on #{host} enabling all default options" do
      let(:manifest) do
        <<~EOF
          class { 'resolv':
            servers        => #{servers},
            use_nmcli      => false,
            search         => ['simp.beaker', 'foo.bar', 'bar.baz'],
            debug          => true,
            no_check_names => true,
            sortlist       => ['1.2.3.0/255.255.255.0', '2.3.0.0/255.255.0.0'],
            extra_options  => ['edns0'],
          }
        EOF
      end

      it 'applies with no errors' do
        apply_manifest_on(host, manifest)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it 'has a properly filled /etc/resolv.conf' do
        expected_content = <<~EXPECTED
          search simp.beaker foo.bar bar.baz
          nameserver 8.8.8.8
          nameserver 8.8.4.4
          nameserver 1.1.1.1
          sortlist 1.2.3.0/255.255.255.0 2.3.0.0/255.255.0.0
          options attempts:2 debug edns0 ndots:1 no-check-names rotate timeout:2
        EXPECTED

        expect(file_content_on(host, '/etc/resolv.conf').strip).to eq(expected_content.strip)
      end
    end

    context "on #{host} setting the content directly" do
      let(:manifest) do
        <<~EOF
          class { 'resolv':
            servers        => #{servers},
            use_nmcli      => false,
            search         => ['simp.beaker', 'foo.bar', 'bar.baz'],
            debug          => true,
            no_check_names => true,
            sortlist       => ['3.4.5.0/255.255.255.0', '2.3.0.0/255.255.0.0'],
            extra_options  => ['edns0'],
            content        => "nameserver 8.8.8.8  \n   nameserver 1.1.1.1",
          }
        EOF
      end

      it 'applies with no errors' do
        apply_manifest_on(host, manifest)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it 'has a properly filled /etc/resolv.conf' do
        expected_content = <<~EXPECTED
          nameserver 8.8.8.8
          nameserver 1.1.1.1
        EXPECTED

        expect(file_content_on(host, '/etc/resolv.conf').strip).to eq(expected_content.strip)
      end
    end

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

      it 'applies with no errors' do
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

      it 'applies with no errors' do
        apply_manifest_on(host, manifest)
      end
    end

    context "on #{host} with NetworkManager" do
      context 'by default' do
        let(:manifest) do
          <<~EOF
            class { 'resolv':
              servers => #{servers.reverse},
            }
          EOF
        end

        it 'applies with no errors' do
          apply_manifest_on(host, manifest)
        end

        it 'is idempotent' do
          apply_manifest_on(host, manifest, catch_changes: true)
        end

        it 'has a properly filled /etc/resolv.conf' do
          expected_content = <<~EXPECTED
            # Generated by NetworkManager
            search simp.beaker
            nameserver 1.1.1.1
            nameserver 8.8.4.4
            nameserver 8.8.8.8
            options attempts:2 ndots:1 rotate timeout:2
          EXPECTED

          expect(file_content_on(host, '/etc/resolv.conf').strip).to eq(expected_content.strip)
        end
      end

      context 'when forcing nmcli off' do
        let(:manifest) do
          <<~EOF
            class { 'resolv':
              servers   => #{servers},
              use_nmcli => false,
              rotate    => false,
            }
          EOF
        end

        it 'applies with no errors' do
          apply_manifest_on(host, manifest)
        end

        it 'is idempotent' do
          apply_manifest_on(host, manifest, catch_changes: true)
        end

        it 'has a properly filled /etc/resolv.conf' do
          expected_content = <<~EXPECTED
            search simp.beaker
            nameserver 8.8.8.8
            nameserver 8.8.4.4
            nameserver 1.1.1.1
            options attempts:2 ndots:1 timeout:2
          EXPECTED

          expect(file_content_on(host, '/etc/resolv.conf').strip).to eq(expected_content.strip)
        end
      end
    end
  end
end
