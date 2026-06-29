require 'spec_helper_acceptance'

test_name 'resolv'

describe 'resolv' do
  let(:servers) { ['8.8.8.8', '8.8.4.4', '1.1.1.1'] }

  hosts.each do |host|
    context "prep #{host}" do
      # Under Docker, /etc/resolv.conf is a bind mount injected by the
      # container runtime. Any atomic write (Puppet's file resource, `sed -i`)
      # fails with "Device or resource busy" because it cannot rename over the
      # mountpoint. Unmount it so it becomes a regular file the module can
      # manage. This is a no-op on real systems (vagrant), where it is not a
      # mountpoint.
      it 'detaches the resolv.conf bind mount when running under Docker' do
        # After detaching, seed the file to mirror the starting state of a real
        # beaker VM, whose hostname is *.simp.beaker so its /etc/resolv.conf
        # already carries `search simp.beaker` ahead of the nameservers. Two
        # things depend on this: (1) the augeas resolv.conf lens edits existing
        # keys in place, so a leading `search` line makes the entry ordering
        # deterministic, and (2) contexts that pass no `search` rely on this
        # pre-existing line being preserved (matching vagrant).
        on(host, 'if mountpoint -q /etc/resolv.conf; then umount /etc/resolv.conf; printf "search simp.beaker\n" > /etc/resolv.conf; fi')
      end

      # The module manages PEERDNS in /etc/sysconfig/network via simp_file_line,
      # which (unlike file_line) does not create the file if it is missing. Real
      # EL systems ship this file; minimal EL9/EL10 containers do not, so ensure
      # it exists. No-op where it already exists (EL8/vagrant).
      it 'ensures /etc/sysconfig/network exists' do
        on(host, 'mkdir -p /etc/sysconfig && touch /etc/sysconfig/network')
      end

      # This is in place for EL8 and is due to single-request-reopen being
      # spammed into set by /etc/NetworkManager/dispatcher.d/fix-slow-dns which
      # appears to be a bug in the CentOS Vagrant image.
      it 'removes the fix-slow-dns script' do
        on(host, 'puppet resource file /etc/NetworkManager/dispatcher.d/fix-slow-dns ensure=absent')
        on(host, %(sed -i '/options/d' /etc/resolv.conf), accept_all_exit_codes: true)
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
          # This assertion validates the resolv.conf that NetworkManager itself
          # generates from the module's [global-dns] config. NM only does so
          # when it actively manages a network device. Under Docker the
          # container runtime owns eth0, so NM marks every device 'unmanaged',
          # has no connection to attach DNS to, and does not (re)generate
          # /etc/resolv.conf at all (no header, original ordering, no search).
          # This is a NetworkManager runtime capability that requires a managed
          # device, which Docker cannot provide -- skip it there. It still runs
          # on vagrant, where NM manages a device.
          nm_manages_device = on(
            host,
            "nmcli -t -f STATE device 2>/dev/null | grep -qvE '^(unmanaged|unavailable)$'",
            accept_all_exit_codes: true,
          ).exit_code.zero?

          skip 'NetworkManager manages no device under Docker (no real netdev); cannot regenerate resolv.conf' unless nm_manages_device

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
          # This context passes no `search`, so the expected `search simp.beaker`
          # line is only present if carried over from the system's prior state.
          # On a real system the preceding NetworkManager-managed run emits the
          # host's search domain, which augeas then preserves. Under Docker NM
          # manages no device (the runtime owns eth0), so the prior NM run never
          # populates a search line for augeas to keep, and the carried-over
          # nameserver ordering also differs from a real run. This depends on
          # NetworkManager runtime behavior Docker cannot reproduce -- skip it
          # there; it still runs on vagrant.
          nm_manages_device = on(
            host,
            "nmcli -t -f STATE device 2>/dev/null | grep -qvE '^(unmanaged|unavailable)$'",
            accept_all_exit_codes: true,
          ).exit_code.zero?

          skip 'NetworkManager manages no device under Docker; prior NM-managed resolv.conf state is not reproducible' unless nm_manages_device

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
