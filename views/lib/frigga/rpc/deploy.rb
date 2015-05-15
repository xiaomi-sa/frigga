module Frigga

  module RPC

    require "digest/md5"
    require "fileutils"
    require "pathname"

    BASE_PATH = Pathname.new(File.dirname(__FILE__)).realpath.to_s.split("/")[0..-4].join("/") + "/deploy/"
    DATA_PATH = BASE_PATH + "data/"
    TMP_PATH  = BASE_PATH + "tmp/"
    LOG_PATH  = BASE_PATH + "log/"
    HM_PATH   = "/home/xbox/aesir/thor/thor/bin/thor.py"
    GOD_PATH  = "/home/xbox/aesir/frigga/gods/"
    DEPLOY_LCK= LOG_PATH + "deploy.lck"
    LOG_SYMBOL= "="
    
    if not File.directory?LOG_PATH
      Logger.info "Init env. Mkdir #{LOG_PATH}"
      `mkdir -p #{LOG_PATH}`
    end

    if not File.directory?TMP_PATH
      Logger.info "Init env. Mkdir #{TMP_PATH}"
      `mkdir -p #{TMP_PATH}`
    end

    module Deploy

      RPC_LIST = %w( startDeploy getDeployStatus getDeployTaskStatus getDeployLog4Mod getDeployLog )

      # Hostname`s hash
      def _mk_id_part_hostname
        hostname = `hostname`
        checksum = Digest::MD5.hexdigest(hostname)
        return checksum[0,8]
      end
      
      # Create random string
      def _random_str(len=8)
        chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
        rand_str = ""
        1.upto(len) { |i| rand_str << chars[rand(chars.size-1)] }
        return rand_str
      end
      
      # Download file ,return the abs path.
      def _down_file(path, url, file_name)

        down_cmd = "cd %s && wget %s -q -O ./%s" %[path, url, file_name]
        r = system(down_cmd)
        file_path = path + "/" + file_name

        if FileTest::exists?(file_path) and not FileTest::zero?(file_path)
          Logger.info "Download succ . file_path : #{file_path} url : #{url}"
          return ['task_id', 'succ', file_path]
        else
          Logger.fatal "Download fail. file_path : #{file_path} url : #{url}"
          return ['task_id', 'fail', file_path]
        end
      end
      
      # Unzip file.
      def _do_unzip(gz_file)

        # The zip_file like
        # "/home/xiedanbo/frigg/lib/deploy/tmp/eca12e6anPDHQkRE1364449531/cluster.tar.gz"
        # The filename_before like "cluster.tar.gz"
        # The filename_bef_tar like "cluster"
        # The task_id like "eca12e6anPDHQkRE1364449531"
        # The file_path like "/home/xiedanbo/frigg/lib/deploy/tmp/eca12e6anPDHQkRE1364449531"
        
        task_id,  filename_before = gz_file.split("/")[-2..-1]
        filename_bef_tar = filename_before.split(".tar.gz")[0]
        file_path = gz_file.split("/")[0..-2].join("/")
        file_path_af_unzip = file_path + "/" + filename_bef_tar

        tar_cmd = "cd %s &&  tar zxf %s" %[file_path, filename_before]
        r = system(tar_cmd)

        if FileTest::exists?(file_path_af_unzip)
          Logger.info "Unzip #{gz_file} succ . file_path_af_unzip : #{file_path_af_unzip}"
          return [task_id, "succ", file_path_af_unzip]
        else
          Logger.fatal "Unzip #{gz_file} fail. file_path_af_unzip : #{file_path_af_unzip}"
          return [task_id, 'fail', 'Unzip the data failed.']
        end

      end
      
      # Through the shell execute the thor script.
      def _execute_thor(thor_data_path)

        task_id = thor_data_path.split("/")[-2]
        thor_log_path = LOG_PATH + "thor_" + task_id + ".log"
        deploy_cmd = "nohup /usr/bin/python -u %s -p %s -s %s &>%s &" \
                      %[HM_PATH, thor_data_path, GOD_PATH, thor_log_path]
        r = system(deploy_cmd)
      
        Logger.info "Execute the thor succ. deploy_cmd >>> #{deploy_cmd}  <<<"
        return [task_id, 'succ', 'hahaha']

      end
      
      # Do deploy task.
      def _do_deploy( task_id, port, path, host_ip)

        if path.start_with?("/")
          url = "http://%s:%s%s" %[host_ip.to_s, port.to_s, path.to_s]
        else
          url = "http://%s:%s/%s" %[host_ip.to_s, port.to_s, path.to_s]
        end

        tmp_file_path = TMP_PATH + task_id
        Logger.info "Task_id : #{task_id}  url : #{url} tmp_file_path : #{tmp_file_path}"

        if FileTest::exists?(tmp_file_path)
          Logger.fatal "The tmp path for task was exists. #{tmp_file_path}"
          return [task_id, "fail","The tmp path for task was exists."]
        end
      
        begin
          FileUtils.mkdir(tmp_file_path) 
        rescue => e
          Logger.fatal "Mkdir #{tmp_file_path} failed."
          return [task_id, "fail",e]
        end
      
        # Check file format, support "tar.gz"
        # _file_name_prefix like "first_deploy-1.0.0.2"
        _file_name_prefix = url.split("/")[-1].split(".tar.gz")[0]
        _suffix = path.split(".")[-2..-1].join(".")

        if _suffix != "tar.gz"
          Logger.fatal "Unsupport file type. #{_suffix}"
          return [task_id, "fail","Unsupport file."]
        end
      
        # Download by url.
        deploy_file_name = _file_name_prefix  + ".tar.gz"
        down_file_result = _down_file(tmp_file_path, url, deploy_file_name)
        if down_file_result[1] == "fail"
          return down_file_result
        else
          deploy_file = down_file_result[2]
        end
      
        # Unzip the package
        unzip_result = _do_unzip(deploy_file)
        if unzip_result[1] == "fail"
          return unzip_result
        else
          thor_data_path = unzip_result[2]
        end
        
        # Execute the thor script.
        ex_thor_result = _execute_thor(thor_data_path)
        return ex_thor_result
      
      end
      
      # Use this method, wen can start a deploy task.
      def _startDeploy(task_id, port, path, host_ip)

        begin

          Logger.info "[ Detach task #{task_id} ] Start......"

          # Make sure only one task runs at a time.
          lckself = File.new __FILE__
          unless lckself.flock File::LOCK_EX | File::LOCK_NB
            Logger.fatal "[ Detach task #{task_id} ] A task was running. Get LOCK #{__FILE__} failed,exit."
            return 1
          end

          Logger.info "[ Detach task #{task_id} ] Get LOCK #{__FILE__} succ. Start _do_deploy function."

          # Execute the deploy. 
          result = _do_deploy(task_id, port, path, host_ip)
          return 0

        rescue => e
          Logger.fatal "[ Detach task #{task_id} ] Deploy #{task_id} exception : #{e} , exit."
          return 1

        ensure
          lckself.flock File::LOCK_UN

          Logger.info "[ Detach task #{task_id} ] Deploy finish. Result : #{result}\n#{LOG_SYMBOL*20} ENDTASK : #{task_id} #{LOG_SYMBOL*20}" 
                       
        end

      end

      # The RPC method
      def startDeploy(port, path)

        begin

          host_ip = request.ip

          # Create task id
          _part1 = _mk_id_part_hostname
          _part2 = _random_str
          _time_stamp = Time.now.strftime("%s")
          task_id = _part1 + _part2 + _time_stamp

          Logger.info "Task start.\n#{LOG_SYMBOL*20} task_id : #{task_id} #{LOG_SYMBOL*20}"
          
          if not FileTest::exists?(DEPLOY_LCK)
            cmd = "touch %s" %[DEPLOY_LCK]
            Logger.info "Touch file #{DEPLOY_LCK}"
            system(cmd)
          end

          # Make sure only one task runs at a time.
          dplck = File.new DEPLOY_LCK
          unless dplck.flock File::LOCK_EX | File::LOCK_NB
            Logger.fatal "A task was running. Get the LOCK #{DEPLOY_LCK} failed, exit."
            return [task_id, "fail", "A task was running"]
          end

          # Two flock.
          lckself = File.new __FILE__
          unless lckself.flock File::LOCK_EX | File::LOCK_NB
            Logger.fatal "A task was running. Get the LOCK #{__FILE__} failed, exit."
            return [task_id, "fail", "A task was running"]
          end
          lckself.flock File::LOCK_UN

          # Write the current task_id to the lock file
          File.open(DEPLOY_LCK, "w") do |f|
            Logger.info "Write the task_id : #{task_id} to the lock file."
            f.puts task_id
          end

          # Touch thor log first.
          thor_log_path = LOG_PATH + "thor_" + task_id + ".log"
          `touch #{thor_log_path}`

          # Do deploy, detach the deploy process.
          read, write = IO.pipe
          pid = fork { _startDeploy(task_id, port, path, host_ip) }
          Process.detach(pid)
          write.close
          read.close
          Logger.info "Detach task #{task_id} succ. Pid : #{pid}"

        rescue => e
          Logger.fatal "Deploy #{task_id} exception : #{e}"
          return [task_id, "fail", "Exception : #{e}"]

        ensure
          dplck.flock File::LOCK_UN
          Logger.info "Release lock file #{DEPLOY_LCK}.\n" 
        end

        return [task_id, "succ", "hahaha"]

      end

      # Parser the log, get the deploy useful info.
      def _get_deploy_info_from_log(log_path)

        info_list = []
        re = /\[{1}\@(.*?)\]{1}(.*)/ 

        if FileTest::zero?(log_path)
          sleep(2)
        end
        
        if FileTest::zero?(log_path)
          info_list = ["[@start:init]"]
        end
        
        File.open(log_path).grep(/^\[\@/) do |line|
          md = re.match(line)
          list_s = []
          # The header, split it by :
          header = md[1].strip.chomp.chomp(",").delete(" ")
          list_s << header.split(":")
          # The content
          if md[2].strip.length > 0
            list_s << md[2].strip.chomp
          end
          info_list << list_s
        end

        return info_list

      end
      
      # Get deploy status from info.
      def _get_task_deploy_status_from_info(info)
      
        # If check env was not pass.
        for i in info
          return [["jobs", -2, "thor deploy check_env failed!"]] if i[0] == ["fail_mod", "check_env"]
        end
      
        mods = []
        # Collect result
        result_d = {}
        for i in info
          mods = i[0][1].split(",") if i[0][0] == "jobs"
          if mods
            result_d["jobs"] = mods
            for mod in mods
              result_d[mod] = i[0][0] if i[0][1] == mod
            end
          end
        end

        mods.each {|element| result_d[element] = "waiting" if not result_d.has_key?(element)}
      
        # -1 means no mod detail presents.
        result_l = [["jobs", mods.length == 0 ? -1 : mods.length]]
        # result_l finally like :
        # [['jobs', 3], ['xbox', 'succ']]
          for mod in mods
              _status = result_d[mod]
              if _status == "start_mod"
                  result_l << [mod,"start"]
              elsif _status == "deploying"
                  result_l << [mod,"deploying"]
              elsif _status == "succ_mod"
                  result_l << [mod,"succ"]
              elsif _status == "fail_mod"
                  result_l << [mod,"fail"]
              else
                  result_l << [mod,"waiting"]
              end
          end
        return result_l
      end

      # Get a mod`s deploy detail log.
      def _get_mod_deploy_log(info, mod_name)
        result_list = [[mod_name]]
        for i in info
          result_list << i[1] if i[0][1] == mod_name and i[0][0] == "deploying"
        end
        return result_list
      end

      # Get a task`s deploy status.
      def getDeployTaskStatus(task_id)

        Logger.info "\n#{LOG_SYMBOL*29} getDeployTaskStatus #{LOG_SYMBOL*28}"

        thor_log_path = LOG_PATH + "thor_" + task_id + ".log"
        log_lines = `wc -l #{thor_log_path}|awk '{print $1}' `.chomp.to_s

        if not FileTest::exists?(thor_log_path)
          Logger.fatal "The thor log #{thor_log_path} not exist.\n#{LOG_SYMBOL*27} getDeployTaskStatus END #{LOG_SYMBOL*26}"
          return [["jobs", -2, "The thor log not exist."]]
        end

        begin
          info = _get_deploy_info_from_log(thor_log_path)
          result_list = _get_task_deploy_status_from_info(info)
          Logger.info "result_list : #{result_list}"
        rescue => e
          Logger.fatal "Get #{task_id} task status fail. Exception : #{e}"
          return [["jobs", -2, "Exception : #{e}"]]
        end

        Logger.info "Get #{task_id} task status succ. Log lines : #{log_lines}. Result : #{result_list} \n#{LOG_SYMBOL*27} getDeployLog4Mod END #{LOG_SYMBOL*26}"
        return result_list

      end

      # Get a deploy task of mod`s detail log.
      def getDeployLog4Mod(task_id, mod_name)

        Logger.info "\n#{LOG_SYMBOL*28} getDeployLog4Mod #{LOG_SYMBOL*28}"

        thor_log_path = LOG_PATH + "thor_" + task_id + ".log"
        if not FileTest::exists?(thor_log_path)
          Logger.fatal "Get #{task_id} task for mod #{mod_name} fail. The thor log #{thor_log_path} was not exists."
          return [["jobs", -2, "The thor log not exist."]]
        end

        begin
          info = _get_deploy_info_from_log(thor_log_path)
          result_list = _get_mod_deploy_log(info, mod_name)
        rescue => e
          Logger.fatal "Get #{task_id} task for mod #{mod_name} fail. Exception : #{e}"
          return [["jobs", -2, "Exception : #{e}"]]
        end

        Logger.info "Get #{task_id} task for mod #{mod_name} succ. Result : #{result_list} \n#{LOG_SYMBOL*26} getDeployLog4Mod END #{LOG_SYMBOL*26}"
        return result_list

      end

      # Get the global deploy status.
      def getDeployStatus()
        r_notask = [["jobs", 0, "No task running."]]

        lckself = File.new __FILE__
        if lckself.flock File::LOCK_EX | File::LOCK_NB
          lckself.flock File::LOCK_UN

          Logger.info "\n#{LOG_SYMBOL*31} getDeployStatus #{LOG_SYMBOL*30} \nGet global deploy status succ. Get lock and release LOCK #{__FILE__} succ. Result : #{r_notask}"
          return r_notask

        else
          task_id = File.readlines(DEPLOY_LCK)[0].strip
          result_list = getDeployTaskStatus(task_id)

          Logger.info "Get global deploy status succ. Get LOCK #{__FILE__} fail. Result : #{result_list}"

          return result_list
        end
        Logger.info "\n#{LOG_SYMBOL*29} getDeployStatus END #{LOG_SYMBOL*28}"
      end
    
    # Get a task`s full log.
    def getDeployLog( task_id)

        Logger.info "\n#{LOG_SYMBOL*32} getDeployLog #{LOG_SYMBOL*32}"

        thor_log_path = LOG_PATH + "thor_" + task_id + ".log"
        if not FileTest::exists?(thor_log_path)
          Logger.fatal "Cannot find the log file #{thor_log_path}"
          return [["jobs", -2, "The thor log not exist."]]
        end

        begin
          fulllog = File.readlines(thor_log_path)
        rescue => e
          Logger.fatal "Read log #{thor_log_path}, exception : #{e}"
          return [["jobs", -2, "Exception : #{e}"]]
        end

        log_lines = `wc -l #{thor_log_path}|awk '{print $1}' `.chomp.to_s
        Logger.info "Get deploy log succ. Log lines : #{log_lines}. Result :\n #{fulllog}"
        Logger.info "\n#{LOG_SYMBOL*30} getDeployLog END #{LOG_SYMBOL*30}"

        return fulllog

    end

    end # end of Deploy module
  end # end of RPC module
end # end of Frigga module
