module Frigga
  module RPC
    require 'rack/rpc'
    require 'sinatra/base'
    Dir.glob(File.join(File.dirname(__FILE__), 'rpc', "*.rb")) do |file|
      require file
    end
    class Runner < Rack::RPC::Server
      #include rpc/*.rb and regsiter rpc call
      #eg. rpc/god.rb   god.hello
      @@rpc_list = []
      Dir.glob(File.join(File.dirname(__FILE__), 'rpc', "*.rb")) do |file|
        rpc_class = File.basename(file).split('.rb')[0].capitalize
        rpc_list = []
        eval "include Frigga::RPC::#{rpc_class}"
        eval "rpc_list = Frigga::RPC::#{rpc_class}::RPC_LIST"
        rpc_list.each do |rpc_name|
          eval "alias :old_#{rpc_class.downcase}_#{rpc_name} :#{rpc_name}"
          define_method "#{rpc_class.downcase}_#{rpc_name}".to_sym do |*arg|
            Logger.info "[#{request.ip}] called #{rpc_class.downcase}.#{rpc_name} #{arg.join(', ')}"
            eval "old_#{rpc_class.downcase}_#{rpc_name} *arg"
          end  
          rpc "#{rpc_class.downcase}.#{rpc_name}" => "#{rpc_class.downcase}_#{rpc_name}".to_sym
          @@rpc_list << "#{rpc_class.downcase}.#{rpc_name}"
        end
      end
      
      def help
        rpc_methods = (['help'] + @@rpc_list.sort).join("\n")
      end
      rpc "help" => :help

      before_filter :check_auth

      def check_auth
        unless White_list.include?(request.ip)
          Logger.info "[#{request.ip}] Not authorized"
          raise "Not authorized"
        end
      end 

    end
  end #RPC
end
