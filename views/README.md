## 介绍

Frigga是一个针对程序部署以及监控的自动化工具

在北欧神话中，frigga是神后，odin的妻子；掌管婚姻和家庭；负责纺织云彩

frigga是部署的client端，相配合的是odin，部署的控制端。在一次部署任务中frigga负责调用thor进行部署
在部署功能中，frigga的上游系统是odin，下游系统是thor

## 功能：

- 作为client端发起一次程序部署
- 提供xmlrpc接口来进行部署任务的查询
- 集成了god，用来作为程序的supervise
- 支持web化的god
- 支持日志
- 支持添加自定义的xmlrpc接口
- 支持自升级


## 环境依赖

- Ruby 1.9.3

## 安装

```
git clone 
```

## 使用

### 基本用法
                      

`启动frigga god 以及需要启动的supervise程序`

                      
```                   
cd script/ && ./run.rb start
```


`用god管理进程`


```
god start/stop/restart frigga
```


### 使用god管理进程

`添加god配置文件到 conf/ 目录下, 配置文件以.god作为后缀`


### 为frigga添加白名单

`在conf/下添加ip.yml文件,将需要信任的机器加入`


```
---
 - 10.237.37.23
 - 10.237.37.24
```

### 高级功能


`添加自定义xmlrpc接口`


## Halp!
  联系 xiedanbo &lt;xiedanbo@xiaomi.com&gt;
