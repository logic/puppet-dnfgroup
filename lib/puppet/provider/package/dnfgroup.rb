# frozen_string_literal: true

# dnfgroup - A puppet package provider for DNF groups
# Copyright (C) 2018 Ed Marshall
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

require 'puppet/provider/package'

Puppet::Type.type(:package).provide( # rubocop:disable Metrics/BlockLength
  :dnfgroup,
  parent: Puppet::Provider::Package
) do

  has_feature :installable
  has_feature :uninstallable

  commands dnf: '/usr/bin/dnf'

  def self.error_level
    '1'
  end

  def self.instances # rubocop:disable Metrics/MethodLength
    packages = []
    cmd = "#{command(:dnf)} group list --hidden -d 9 -e #{error_level}"
    execpipe(cmd) do |process|
      regex = /^\s+(.+) \(([^)]+)\)\s*(\[[^\]]+\])?\s*$/
      in_installed = false
      process.each_line do |line|
        unless line.start_with? '   '
          in_installed = line.start_with? 'Installed'
          next
        end
        next unless in_installed
        next unless (match = regex.match(line))
        packages << new(
          name: match[2],
          alias: match[1],
          ensure: :installed,
          provider: name
        )
      end
    end
    packages
  end

  def query
    self.class.instances.each do |package|
      case @resource[:name].downcase
      when package.name.downcase, package.get(:alias).downcase
        return package.properties
      end
    end
    nil
  end

  def install
    dnf('group', 'install', '-d', '0', '-e', self.class.error_level, '-y',
        @resource[:name])
  end

  def uninstall
    dnf('group', 'remove', '-d', '0', '-e', self.class.error_level, '-y',
        @resource[:name])
  end
end
