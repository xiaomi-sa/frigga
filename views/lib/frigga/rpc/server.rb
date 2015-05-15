module Frigga
  module RPC
    module Server
      RPC_LIST = %w(ver update)
      def ver
        VER
      end

      def update
        restart_flag = false
        if system("which git > /dev/null") && File.directory?(".git")
          clean  = `git status --porcelain`.empty?
          current_branch = `git symbolic-ref HEAD`.chomp
          master = current_branch == "refs/heads/master"
          no_new_commits = system('git diff --exit-code --quiet origin/master master')

          short_branch = current_branch.split('/').last

          if !master
            return ["fail", "Frigga on a non-master branch '#{short_branch}', won't auto-update!"]
          elsif !no_new_commits
            return ["fail", "Frigga has unpushed commits on master, won't auto-update!"]
          elsif !clean
            return ["fail", "Frigga has a dirty tree, won't auto-update!"]
          end

          if clean && master && no_new_commits
            quietly = "> /dev/null 2>&1"
            fetch   = "(git fetch origin #{quietly})"
            reset   = "(git reset --hard origin/master #{quietly})"
            reclean = "(git clean -df #{quietly})"

            if system "#{fetch}"
              origin_log = `git log origin/master -1 --oneline`
              master_log = `git log master -1 --oneline`
              restart_flag = (origin_log == master_log ? false : true)
            else
              return ["fail", "Git fetch failed."]
            end

            unless system "#{reset} && #{reclean}"              
              return ["fail", "Auto-update of Frigga Failed!"]
            end

            if restart_flag
              Thread.new { sleep 1; exit}
              return ["succ", "Auto-update of Frigga Succeed, ready to restart"]
            else
              return ["succ", "Frigga is already up to date, Don't need restart."]
            end
          end

        else
          return ["fail", "Don't have git and .git, won't auto-update!"]
        end

      end # update

      def update_god
        Dir.chdir Pathname.new(__FILE__).realpath + "../../../../script"
        `./run.rb stop_god`
        sleep(1)
        `./run.rb start`
      end

    end
  end

end
