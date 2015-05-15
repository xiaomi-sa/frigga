## 介绍

Frigga是一款使用简单、极具扩展的进程监控的框架。她基于开源的god，修改和添加了web界面和rpc接口，以满足大集群服务管理的需求。

在北欧神话中，frigga是神后，odin的妻子；掌管婚姻和家庭；负责纺织云彩

![图片](http://noops.me/wp-content/uploads/2013/05/frigga.png)

## 功能

- 集成了god，用来作为程序的supervise程序
- C/S结构，并且集成了多种认证方式，以支持大集群运维管理
- 基本功能均提供api接口，方便扩展
- 支持单机web化的god,方便查看和管理
- 支持日志查看
- 支持添加自定义的xmlrpc接口,方便进行二次开发


## 环境依赖

- Ruby 1.9.3
- bundle

## 安装

```
git clone git@github.com:xiaomi-sa/frigga.git 
```

## 使用

### 基本用法
                     
启动frigga god 以及需要启动的supervise程序
                      
```                   
cd script/ && ./run.rb start
```
- 第一次使用会使用bundle安装vendor/cache/*.gem到系统
- 在run.sh中，调用`god --no-events --log-level info -c #{DIR}/conf/base.god`启动god
- 在run.sh中，通过god启动的frigga `god load conf/frigga.god`

通过浏览器链接http://localhost:9901, 默认用户名: admin, 默认密码: 123，可以在web查看

### 用god管理进程
- [god官方地址](http://godrb.com)
- [noops.me](http://noops.me/?p=133)上有god的使用介绍和其他进程管理工具的对比

查看启动的进程: `god status`


```
god start/stop/restart process_name
```

### 使用god管理进程

`添加god配置文件到 gods/ 目录下, 配置文件以.god作为后缀`，使用script/run.sh start时，会批量加载该目录下的*.god文件

### 建议的god配置
``` ruby
God.watch do |w|
  w.name = "agent"
  w.start = "/home/work/opdir/agent/release/run.sh"
  w.log = "/home/work/opdir/agent/release/run.log"
  w.process_log = "/home/work/opdir/agent/log/agent.log"
  w.dir = "/home/work/opdir/agent/release"
  w.env = {"PATH"=>"/home/work/jdk/bin/:/bin:/usr/bin:/sbin", "JAVA_HOME"=>"/home/work/jdk", "CLASSPATH"=>".:/home/work/jdk/lib/tools.jar:/home/work/jdk/lib/rt.jar"}
  w.keepalive
  w.behavior(:clean_pid_file)
  w.stop_timeout = 60.seconds
  
  w.lifecycle do |on|
    on.condition(:flapping) do |c|
      c.to_state = [:start, :restart]
      c.times = 3
      c.within = 10.minute
      c.transition = :unmonitored
      c.retry_in = 20.minutes
      c.retry_times = 2
      c.retry_within = 1.hours
      c.notify = 'proc_down'
    end
  end
end

God.contact(:email) do |c|
  c.name = 'proc_down'
  c.group = 'developers'
  
  c.to_email = "god@xiaomi.com"
end
```

> 其中http_url, process_log为frigga支持的新参数
> w.http_url = "www.xiaomi.com"， 在web端点击process name，可以跳转到指定的url地址

> w.process_log 支持数组或字符串配置
>> w.process_log = "/home/work/xxx/log/xxx.log"

>> w.process_log = ["/home/work/xxx/log/xxx.log", "/home/work/xxx/log/xxx1.log"]

配置好process_log后，可以通过god log process_name或web端查看日志, 如进程名为w.name = "frigga"

`god log frigga [1/2/3...]`

### 为frigga添加白名单

`在conf/下添加ip.yml文件,将需要信任的机器加入`


```
---
- 10.237.37.23
- 10.237.37.24
```

### 高级功能


`添加自定义xmlrpc接口`

> rpc接口的添加可以参照lib/frigga/rpc/god.rb

> 假设我们要添加一个叫做call_somethg的接口,支持一个叫做do_somethg的方法，可以按照下面方法开发:
>> 首先在lib/frigga/rpc/下添加一个call_somethg.rb的文件

>> call_somethg.rb文件中的namespace应该遵循以下结构。需要注意的是要将需要调用的function写入到RPC_LIST数组中，作为方法的注册。

```
module Frigga
  module RPC
    module call_somethg

      RPC_LIST = %w(do_somethg)

      def do_somethg
        do_somethg
      end

    end
  end
end

```

`使用rpc接口,遵循标准的xmlrpc协议.以下是一个调用demo`

python的调用方法
``` python
import xmlrpclib
server_ip = "your_ip"
server_port = "9001"
uri = "http://" + server_ip + ":" + server_port + "/rpc"
server = xmlrpclib.ServerProxy(uri)
print server.call_somethg.do_somethg()
```

ruby的调用方法
``` ruby
require "xmlrpc/client"
require "pp"
server = XMLRPC::Client.new2("http://127.0.0.1:9001/rpc")
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
```
调用`help`方法，会列出frigga支持的所有rpc call

## 注意事项

- 由于script/run.rb启动god时关闭了event，所以不能使用god event配置

## Help!
  联系 xiedanbo &lt;xiedanbo@xiaomi.com&gt;
