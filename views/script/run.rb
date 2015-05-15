#!/usr/bin/env ruby
#ecoding: utf-8
require "pathname"

Dir.chdir Pathname.new(__FILE__).realpath + "../.."

# Auto-update code
if system("which git > /dev/null") && File.directory?(".git")
  clean  = `git status --porcelain`.empty?
  current_branch = `git symbolic-ref HEAD`.chomp
  master = current_branch == "refs/heads/master"
  no_new_commits = system('git diff --exit-code --quiet origin/master master')

  short_branch = current_branch.split('/').last

  if !master
    warn "Frigga on a non-master branch '#{short_branch}', won't auto-update!"
  elsif !no_new_commits
    warn "Frigga has unpushed commits on master, won't auto-update!"
  elsif !clean
    warn "Frigga has a dirty tree, won't auto-update!"
  end

  if clean && master && no_new_commits
    quietly = "> /dev/null 2>&1"
    fetch   = "(git fetch origin #{quietly})"
    reset   = "(git reset --hard origin/master #{quietly})"
    reclean = "(git clean -df #{quietly})"

    unless system "#{fetch} && #{reset} && #{reclean}"
      warn "Auto-update of Frigga FAILED, continuing."
    end
  end
else
  warn "Don't have git or .git, won't auto-update!"
end

# update gem

gem_lock =Pathname.new(File.dirname(__FILE__)).realpath.to_s.split("/")[0..-2].join("/") + "/Gemfile.lock"
`rm -rf #{gem_lock}`
`bundle update --local`
abort "Install gem failed!" if $? != 0

DIR = File.expand_path("")
abort "God does not  exist..."  unless system("which god > /dev/null")

require "thor"
class Cli < Thor
  desc "start", "Start God, Frigga and #{DIR}/gods/*.god"
  def start
    #wake up god
    wakeup_god = %W(god --no-events --log-level info -c #{DIR}/conf/base.god)
    abort "Start God failed!" unless system *wakeup_god

    #use god to load frigga.god for wakeing frigga up
    wakeup_frigga = "god load conf/frigga.god"
    abort "Start Frigga failed!" unless system *wakeup_frigga

    #start process
    Dir.glob(File.join(Dir.pwd, 'gods', "*.god")) do |god|
      start_process = "god load #{god}"
      `#{start_process}`
      warn "Start process[#{god}] failed!" unless $? == 0
    end

    #check process status
    puts "Command: god status"
    system("god status")
  end

  desc "stop", "Stop God and Frigga, Don't stop *.god"
  def stop
    #stop frigg
    stop_frigg = "god stop frigga"
    `#{stop_frigg}`
    warn "Stop Frigga failed!" unless $? == 0

    #stop god
    stop_god = %W(god quit)
    abort "Stop God failed!" unless system *stop_god
  end

  desc "nuke", "Stop God,Frigga and *.god"
  def nuke
    #terminate god
    nuke_god = %W(god terminate)
    abort "Nuke all gods failed!" unless system *nuke_god
  end

  desc "stop_god", "Stop God only, update god gem."
  def stop_god
    # update god
    stop_god = %W(god quit)
    abort "Stop God failed!" unless system *stop_god
  end

end

Cli.start(ARGV)

