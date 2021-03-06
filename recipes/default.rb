#
# Cookbook Name:: locale
# Recipe:: default
#
# Copyright 2011, Heavy Water Software Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

lang = node['locale']['lang']
lc_all = node['locale']['lc_all'] || lang

case node['platform_family']
when 'debian'

  package 'locales' do
    action :install
  end

  if node['platform'] == 'debian'
    execute 'locale-gen' do
      command 'locale-gen'
      action :nothing
    end

    file '/etc/locale.gen' do
      content "#{lang} #{lang.split('.').last}\n"
      notifies :run, 'execute[locale-gen]', :immediately
    end
  else
    execute 'Generate locale' do
      command "locale-gen #{lang}"
      not_if { Locale.up_to_date?('/etc/default/locale', lang, lc_all) }
    end
  end

  execute 'Update locale' do
    command "update-locale LANG=#{lang} LC_ALL=#{lc_all}"
    not_if { Locale.up_to_date?('/etc/default/locale', lang, lc_all) }
  end

when 'rhel'
  if node['platform_version'].to_f >= 7.0
    bash 'Update locale' do
      user 'root'
      code "/usr/bin/localectl --no-ask-password set-locale LANG=#{node['locale']['lang']}"
      not_if { Locale.up_to_date?('/etc/locale.conf', lang, nil) }
    end
  else
    locale_file_path = '/etc/sysconfig/i18n'

    file locale_file_path do
      content lazy {
        locale = IO.read(locale_file_path)
        variables = Hash[locale.lines.map { |line| line.strip.split('=') }]
        variables['LANG'] = lang
        variables['LC_ALL'] = lc_all
        variables.map { |pairs| pairs.join('=') }.join("\n") + "\n"
      }
      not_if { Locale.up_to_date?(locale_file_path, lang, lc_all) }
    end
  end
when 'fedora'
  package 'systemd' do
    action :install
  end

  # It is not permitted to set LC_ALL in the locale conf file on Fedora.
  bash 'Update locale' do
    code "echo localectl set-locale LANG=#{lang} > /tmp/foo ; localectl set-locale LANG=#{lang} >> /tmp/foo 2>&1"
    not_if { Locale.up_to_date?('/etc/locale.conf', lang, nil) }
  end
end
