module Frigga

  module RPC

    require "digest/md5"
    require "fileutils"
    require "pathname"

    BASE_PATH = Pathname.new(File.dirname(__FILE__)).realpath.to_s.split("/")[0..-4].join("/") + "/deploy/"
    CT_USERS = ["root", "work"]
    
    module Ctmgr

      RPC_LIST = %w( getCtstatus )

      def getCtstatus
        ct_all = []
        
        CT_USERS.each do |u|
          ct_detail = `crontab -l  -u #{u}`.split("\n")
          counter = 1
          if ct_detail.empty? or ct_detail =~ /^no crontab for/
            ct_all << ["user : #{u}", "no crontab for #{u}"]
          else
            ct_array = ["user : #{u}"]
            ct_detail.each do |i|
               if i =~ /^#/
                 ct_array << i 
               else
                 ct_array << [counter, i]
                 counter += 1
               end
            end
          ct_all << ct_array
          end
        end
        return ct_all
      end
      

    end # end of Ctmgr module
  end # end of RPC module
end # end of Frigga module
