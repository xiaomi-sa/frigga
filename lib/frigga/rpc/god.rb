module Frigga
  module RPC
    module God
      #must have RPC_LIST for regsiter rpc_call
      RPC_LIST = %w(status restart start stop)
      def status
        hi = Frigga::Talk.god('status')
        hi.map {|k, v| [k, v[:status], v[:start_time], v[:pid], v[:start]] }
      end
      def restart(str)
        Frigga::Talk.god('restart', str)
      end

      def start(str)
        Frigga::Talk.god('start', str)
      end

      def stop(str)
        Frigga::Talk.god('stop', str)
      end      

    end #God
  end
end
