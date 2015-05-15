#!/usr/bin/env ruby
#ecoding: utf-8
$: << "../lib" << "./lib"

require "pathname"
require 'yaml'

Dir.chdir Pathname.new(__FILE__).realpath + "../.."

DIR = File.expand_path("")

def load_yml(yml_path)
  yaml_context = nil
  begin
    yaml_context = YAML::load_file(yml_path) if File.exist?(yml_path)
  rescue Exception => e
    abort "Read yaml file[#{yml_path}] error! -> #{e}"
  end
  yaml_context
end

#log white_ip from ip.yml
if File.exist?("conf/ip.yml")
  white_ip = load_yml("conf/ip.yml")
  abort "ip.yml must be array!" unless white_ip.kind_of?(Array)
end
#load main config
conf       = load_yml("conf/frigga.yml")
#http-server basic auth
Http_auth_user, Http_auth_passwd = conf.fetch "http_auth", nil
#http-server port
Http_port  = conf.fetch "port", 9001
#http-server ip white_list
White_list = (white_ip.nil? ? [] : white_ip)
#ldap config
Ldap       = conf.fetch "ldap", {}


#god's sock
GOD_SOCK   = "/tmp/god.17165.sock"
#log level: debug > info > warn > fatal
LOG_LEVEL  = 'info'
VER        = '1.0.0'

require 'frigga'
#ok, let's go
Frigga::WebServer.run!
