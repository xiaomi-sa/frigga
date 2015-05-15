$: << "./"
require 'sinatra/base'
require 'rack/rpc'
require 'frigga/log'
require 'frigga/auth'
require 'frigga/talk'
require 'frigga/rpc'
require 'sinatra-websocket'
require "file/tail"

module Frigga
  class Tail < File
    include File::Tail
  end

  class WebServer < Sinatra::Base
    include Frigga::Auth
    configure do
      set :public_folder, Proc.new { File.join(File.expand_path(""), "static") }
      set :views, Proc.new { File.join(File.expand_path(""), "views") }
      enable :sessions
      set :port => Http_port
      set :bind => '0.0.0.0'
      set :show_exceptions => false
    end
    # use Rack::Auth::Basic, "Protected Area" do |username, password|
    #   username == 'foo' && password == 'bar'
    # end
    before '*' do
      Logger.info "[#{request.ip}] #{request.path}"
      if White_list.include?(request.ip)
        Logger.info "[#{request.ip}] in white-list, skip Auth!"
      else
        protected! unless request.websocket?
      end
      @ver = VER
    end

    not_found do
      erb :notfound
    end

    error do
      @error = env['sinatra.error'].message
      erb :error
    end

    get '/' do
      if session[:notice]
        @msg = session[:notice].dup
        session[:notice] = nil
      end
      @process = Frigga::Talk.god('status')    
      erb :index
    end

    get '/about' do
      @process = Frigga::Talk.god('status')
      raise "Frigga hasn't watched by God" if @process.empty?  
      erb :about
    end

    get '/log/*' do
      #check log file
      name, type, index = params[:splat][0].split('/')
      raise "url error" if name.nil? or type.nil?
      log = nil
      log_file = nil
      thr = nil
      if name == "god"
        if File.exist?("/var/log/messages")
          log_file = "/var/log/messages"
        elsif File.exist?("/var/log/syslog")
          log_file = "/var/log/syslog"
        end
      else
        process = Frigga::Talk.god('status')
        raise "Don't have name:#{name}" unless process.key?(name) 
        if !process[name][:all_log][type.to_sym].nil? && !process[name][:all_log][type.to_sym].eql?("/dev/null")
          if process[name][:all_log][type.to_sym].kind_of?(Array)
            if !index.nil? && (0 .. process[name][:all_log][type.to_sym].size-1).include?(index.to_i)
              log_file = process[name][:all_log][type.to_sym][index.to_i] if File.exist?(process[name][:all_log][type.to_sym][index.to_i])
             end
          else 
            log_file = process[name][:all_log][type.to_sym] if File.exist?(process[name][:all_log][type.to_sym])
          end
        end 
      end
      raise "We can't find log file, sorry..." if log_file.nil?

      #start websocet
      if !request.websocket?
        erb :tail
      else
        request.websocket do |ws|
          ws.onopen do
            log = Tail.new(log_file)
            log.interval = 5
            log.backward(5)
            log.return_if_eof = true
            thr = Thread.new { 
              loop do 
                unless log.closed?
                  log.tail { |line| ws.send line }
                end
                sleep 0.25
              end
            }
          end

          ws.onmessage do |msg|
            if msg =~ /END/i
              thr.kill if thr.alive?
              log.close unless log.closed?
              ws.close_connection 
            end
          end

          ws.onclose do
            thr.kill if thr.alive?
            log.close unless log.closed?
          end
        end
      end
    end

    post '/god/:action' do |action|
      unless %w(restart start stop).include?(action)
        raise "Don't know action[#{action}]"
      end
      hi = Frigga::Talk.god(action, params[:name])
      if hi.empty?
        raise "#{action.capitalize} #{params[:name]} failed! #{hi[1]}"
      end
      session[:notice] = "Action: #{action} process[#{params[:name]}] success!"
      sleep 0.5
      redirect to '/'
    end

    #get '/ctmgr' do
    #  if session[:notice]
    #    @msg = session[:notice].dup
    #    session[:notice] = nil
    #  end
    #  include Frigga::RPC::Ctmgr
    #  @ctstatus = getCtstatus()
    #  erb :ctmgr
    #end

    use Rack::RPC::Endpoint, Frigga::RPC::Runner.new
  end
end

