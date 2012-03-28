## Cookbook Name:: freeswitch
## Recipe:: default
##
## Copyright 2012, "Twelve Tone Software" <lee@twelvetone.info>
##
##    This program is free software: you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation, either version 3 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program.  If not, see <http://www.gnu.org/licenses/>.
##
#
## Freeswitch cookbook
## ZRTP media pass-through proxy mode

## Build requirements
package "autoconf" 
package "automake"
package "g++"
package "git-core"
package "libjpeg62-dev"
package "libncurses5-dev"
package "libtool"
package "make"
package "python-dev"
package "gawk"
package "pkg-config"
package "gnutls-bin"

# get source
execute "git_clone" do
  command "git clone #{node[:freeswitch][:git_uri]}"
  cwd "/usr/local/src"
  creates "/usr/local/src/freeswitch"
end

# compile source and install
script "compile_freeswitch" do
  interpreter "/bin/bash"
  cwd "/usr/local/src/freeswitch"
  code <<-EOF
  ./bootstrap.sh
  ./configure
  make clean
  make
  make install
  make samples
EOF
  not_if "test -f #{node[:freeswitch][:path]}/freeswitch"
end

# install init script
template "/etc/init.d/freeswitch" do
  source "freeswitch.init.erb"
  mode 0755
end

# install defaults
template "/etc/default/freeswitch" do
  source "freeswitch.default.erb"
  mode 0644
end

# create non-root user
user node[:freeswitch][:user] do
  system true
  shell "/bin/bash"
  home node[:freeswitch][:homedir]
  gid node[:freeswitch][:group]
end

# change ownership of homedir
execute "fs_homedir_ownership" do
  cwd node[:freeswitch][:homedir]
  command "chown -R #{node[:freeswitch][:user]}:#{node[:freeswitch][:group]} ."
end

# define service
service node[:freeswitch][:service] do
  supports :restart => true, :start => true
  action [:enable]
end

cookbook_file "#{node[:freeswitch][:homedir]}/bin/gentls_cert" do
  source "gentls_cert"
  user "freeswitch"
  group "freeswitch"
  mode 0755
end
execute "build_ca" do
  user "freeswitch"
  cwd "#{node[:freeswitch][:path]}"
  command "./gentls_cert setup -cn #{node[:freeswitch][:domain]} -alt DNS:#{node[:freeswitch][:domain]} -org #{node[:freeswitch][:domain]}"
  creates "#{hode[:freeswitch][:homedir]}/conf/ssl/CA/cakey.pem"
end

execute "gen_server_cert" do
  user "freeswitch"
  cwd "#{node[:freeswitch][:path]}"
  command "./gentls_cert create_server -quiet -cn #{node[:freeswitch][:domain]} -alt DNS:#{node[:freeswitch][:domain]} -org #{node[:freeswitch][:domain]}"
  creates "#{hode[:freeswitch][:homedir]}/conf/ssl/agent.pem"
end

# set global variables
template "#{node[:freeswitch][:homedir]}/conf/vars.xml" do
  source "vars.xml.erb"
  mode 0644
end

# set SIP security attributes for registered users
template "#{node[:freeswitch][:homedir]}/conf/sip_profiles/internal.xml" do
  source "internal.xml.erb"
  mode 0644
  notifies :restart, "service[#{node[:freeswitch][:service]}]"
end

# set SIP security attributes for external users
template "#{node[:freeswitch][:homedir]}/conf/sip_profiles/external.xml" do
  source "external.xml.erb"
  mode 0644
  notifies :restart, "service[#{node[:freeswitch][:service]}]"
end