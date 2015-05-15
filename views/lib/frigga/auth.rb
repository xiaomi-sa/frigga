module Frigga
  module Auth
    require 'net/ldap'
    require 'open-uri'
    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && check_ldap
    end

    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Oops... we need your login name & password\n"])
      end
    end

    def check_ldap
      ldap =  Net::LDAP.new({ :host => Ldap['host'], 
                              :port => Ldap['port'], 
                              :base => Ldap['base'],
                              :auth => {  :method => :simple,
                                          :username => Ldap['username'],
                                          :password => Ldap['password']
                                        }
      })

      filter = Net::LDAP::Filter.eq("mail", @auth.credentials[0])
      ldap_entry = nil
      ldap.search(:filter => filter) {|entry| ldap_entry = entry}
      return false if ldap_entry.nil?
      ldap.auth(ldap_entry.dn, @auth.credentials[1])
      if ldap.bind
        door_god = get_doorgod_list(@auth.credentials[0].split('@')[0])
        ip_list = `ip -f inet addr | grep global | awk '{print $2}' | awk -F/ '{print $1}'`.split("\n").select {|f| f =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d+{1,3}/}
        return ip_list.map {|f| door_god.scan("(#{f})").empty? ? false : true}.any?
      else
        return false
      end
    end #check_ldap

    def get_doorgod_list(user)
      host_list = open "http://krb1.xiaomi.net/getmyinfo.php?user=#{user}" do |f|
        f.read
      end
    end

  end
end