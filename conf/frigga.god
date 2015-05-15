frigga_path = File.expand_path("./bin")
God.watch do |w|
  w.name = "frigga"
  w.start = "ruby #{frigga_path}/frigga.rb"
  w.keepalive(:memory_max => 100.megabytes, :cpu_max => 50.percent)
  w.behavior(:clean_pid_file)

  w.lifecycle do |on|
    on.condition(:flapping) do |c|
      c.to_state = [:start, :restart]
      c.times = 3
      c.within = 3.minute
      c.transition = :unmonitored
      c.retry_in = 10.minutes
      c.retry_times = 2
      c.retry_within = 1.hours
    end
  end

end
