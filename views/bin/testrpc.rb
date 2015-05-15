$: << 'lib' << '../lib'
require "rubygems"
require "xmlrpc/client"
require "pp"

#server = XMLRPC::Client.new2("http://foo:bar@0.0.0.0:9001/rpc")
server = XMLRPC::Client.new2("http://127.0.0.1:9001/rpc")
#result = server.call('system.listMethods')
#result = server.call('supervisor.getAllProcessInfo')
#result = server.call('deployment.getAllStatus')
#result = server.call('help')
puts server.call('help')
puts "-----------------------"
loop do
begin
  x = gets.strip.split(/\s/)
  next if x.empty?
  result = server.call(*x)
  pp result
  puts "-----------------------"
rescue => e
  puts e.message
  puts e.backtrace.join("\n")
  next
end
end
#result = server.call('help')
#puts result
#result = server.call('god.status')
#result = server.call('deploy.startDeploy', '8081', 'first_deploy-1.0.0.0.tar.gz')
#puts result

__END__
options = {
  :backtrace  => true,
  :dir_mode   => :script,
  :dir        => 'pids',
  :monitor    => true
}

current_dir = Dir.pwd

Daemons.run_proc('tower', options) do
  loop do
    Dir.chdir(current_dir)
    logger = Log.instance
    EM.run do
      # hit Control + C to stop
      # Signal.trap("INT")  { EM.stop }
      # Signal.trap("TERM") { EM.stop }

      #load conf file
      $conf = load_config('../conf/dm-server.yaml')
      EM.stop if $conf.nil?

      $logger.info "start dm-server..."
      EM.start_server($conf['ip'], $conf['port'], DomainReportServer)
      $DB = Sequel.connect($conf['db'], :max_connections => 10)
    end
    sleep 3
  end
end
