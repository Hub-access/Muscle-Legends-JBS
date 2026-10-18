-- JBS Fast R7 2026-10-18 | Standalone fast-training revision; platform results in bundled report.
local createJBSStandaloneFast=(function()
-- Standalone training only. Delay feedback never treats Strength as an acknowledgement.
return function(config)
 local settings=config.settings or {}
 local function num(v,d,lo,hi)
  if type(v)~="number" or v~=v then v=d end
  return math.clamp(v,lo,hi)
 end
 local ceiling=num(settings.maxRate,1600,200,2400)
 local floor=num(settings.minRate,200,50,ceiling)
 local initial=num(settings.startRate,900,floor,ceiling)
 local fixed=settings.fixedRate and num(settings.fixedRate,initial,50,2400) or nil
 local delay=num(settings.queueDelay,.12,.05,.5)
 local kp,ki=initial*.7,initial*.12
 local self={revision=7,active=false,rate=0,target=fixed or initial,ceiling=ceiling,sent=0,
  capacity=0,learnedLimit=initial,draining=false,status="未开启"}
 local credit,remote,character,stat,fire=0,nil,nil,nil,nil
 local previousStrength,lastOff=nil,-math.huge
 local bias=initial
 local lastPingAt=0
 local gainAt,gain,lastProgress=0,0,0
 local noProgress=false
 local function send(count)
  local sent=0
  local ok,e=pcall(function()
   for _=1,count do
    if not config.active() or not remote or not remote.Parent then break end
    fire(remote,"rep");sent+=1
   end
  end)
  self.sent+=sent
  if sent>0 then config.sent(sent) end
  if not ok then self.lastError=tostring(e);credit=0;self.status="训练事件报错，等待恢复" end
 end
 function self:Pause()
  if self.active then lastOff=config.clock() end
  self.active=false;self.rate=0;credit=0;self.status="未开启"
 end
 function self:Retest() self:Pause();self.gainRate=nil;self.lastError=nil end
 function self:Step(dt,state)
  if not (config.active() and state.alive and state.remote and state.remote.Parent and
   (state.remote:IsA("RemoteEvent") or state.remote:IsA("UnreliableRemoteEvent"))) then self:Pause();return end
  local now=config.clock()
  local changed=remote~=state.remote or character~=state.character or stat~=state.stat
  if not self.active or changed then
   remote=state.remote;character=state.character;stat=state.stat;fire=remote.FireServer
   self.active=true;credit=0;self.draining=false;lastPingAt=now
   gainAt=now;gain=0;lastProgress=now;noProgress=false;previousStrength=state.strength
   if changed or now-lastOff>=10 then
    bias=initial;self.target=fixed or initial
   else
    bias=math.clamp(self.target+kp*math.max(0,(self.ping or 0)-(self.baselinePing or 0)),floor,initial)
   end
  end
  if type(state.strength)=="number" then
   local delta=previousStrength and state.strength-previousStrength or 0
   if delta>0 then gain+=delta;lastProgress=now;noProgress=false
   elseif delta<0 then lastProgress=now;noProgress=false end
   previousStrength=state.strength
  end
  if now-gainAt>=4 then self.gainRate=gain/(now-gainAt);gainAt=now;gain=0 end
  if now-lastPingAt>=.2 then
   local elapsed=math.min(.5,now-lastPingAt);lastPingAt=now
   local p=config.ping()
   if type(p)=="number" and p>0 and p<120 then
    self.ping=p;self.baselinePing=math.min(self.baselinePing or p,p)
    local base=self.baselinePing
    local queued=math.max(0,p-base)
    local hard=math.clamp(base+1.1,1.25,1.75)
    local resume=math.clamp(base+.075,.18,.35)
    if self.draining then
     if p<=resume then self.draining=false;credit=0 end
    elseif p>hard then
     self.draining=true;credit=0
     if not fixed then
      self.target=math.max(floor,self.target*.85)
      bias=math.min(bias,self.target+kp*delay)
     end
    elseif not fixed then
     -- Proportional response removes pressure immediately; the bounded integral
     -- learns the sustainable rate without using call-to-gain conversion ratios.
     bias=math.clamp(bias-ki*(queued-delay)*elapsed,floor,initial)
     self.target=math.clamp(bias-kp*queued,floor,initial)
     self.learnedLimit=math.clamp(bias-kp*delay,floor,initial)
    end
   end
  end
  if type(dt)~="number" or dt~=dt or dt<=0 or dt>.25 then self.rate=0;credit=0;return end
  if self.draining then self.rate=0;credit=0;self.status="等待网络恢复";return end
  noProgress=now-lastProgress>4
  local wanted=noProgress and math.min(fixed or self.target,100) or fixed or self.target
  self.capacity=math.min(fixed or ceiling,25/dt)
  self.rate=math.min(wanted,self.capacity)
  self.status=noProgress and "检查训练条件" or "极速锻炼 · 延迟反馈持续发送"
  local batch=wanted>=500 and 25 or wanted>=100 and 5 or 1
  credit=math.min(50,credit+dt*self.rate)
  local count=math.min(math.floor(25/batch),math.floor((credit+1e-8)/batch))*batch
  if count>0 then credit-=count;send(count) end
 end
 return self
end

end)()
local createJBSPerformance=(function()
-- Local observations, pacing and bounded invocations; never a server acknowledgement.
return function(config)
 local self={rate=0,selectedRate=440,capacity=440,sentRate=0,repRate=0,gainRate=nil,status="未开启",
  total=0,repTotal=0,gainedStrength=0,gainedDurability=0,gainedRebirths=0,
  stopped=false,packTraining=false,bossActive=false,bossTraining=false,combatUntil=0,
  pending=nil,locked=false,variant=1,lastError=nil,packStatus=nil}
 local now=config.clock
 local credit,refill=22,now()
 local times,head,tail={},1,0
 local invocations,observations={},{}
 local leases=config.leases or {}
 local reportAt,reportTotal,reportReps=now(),0,0
 local frameTime,sendAcc,hand=1/60,0,0
 local profile,remoteEpoch,charEpoch,lastMode=nil,nil,nil,"idle"
 local warmLeft,windowTime,windowGain=1,0,0
 local bestRate,bestGain,holdLeft,zeroWindows=440,0,0,0
 local attributedGain=0
 local capacityAnchor,capacityChanged=440,0
 local rates={440,360,280,200,120,60,20}
 local function allowance()
  local t=now();credit=math.min(22,credit+math.max(0,t-refill)*460);refill=t
  while head<=tail and times[head]<=t-1+1e-8 do times[head]=nil;head+=1 end
  if head>2048 then local t2={};for i=head,tail do t2[#t2+1]=times[i] end;times=t2;head=1;tail=#t2 end
  if self.stopped or credit<1 or tail-head+1>=460 then return false end
  credit-=1;tail+=1;times[tail]=t;return true
 end
 local function isEvent(r) return r and r.Parent and (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent")) end
 function self:Fire(r,...)
  if not isEvent(r) then self.lastError="目标不是可用的 RemoteEvent";return false end
  if not allowance() then return false end
  local ok,e=pcall(r.FireServer,r,...);if ok then self.total+=1 else self.lastError=tostring(e) end;return ok
 end
 function self:FireGuarded(r,active,...)
  if not isEvent(r) then return false end
  while not self.stopped and r.Parent and (not active or active()) do
   if allowance() then
    local ok,e=pcall(r.FireServer,r,...);if ok then self.total+=1 else self.lastError=tostring(e) end;return ok
   end
   config.wait(0.05)
  end
  return false
 end
 function self:FireReliable(r,...) return self:FireGuarded(r,nil,...) end
 local function beginInvoke(r,args)
  if self.stopped or not r or not r.Parent then return nil,"不可用" end
  if leases[r] then return nil,"等待上一条调用" end
  if not allowance() then return nil,"等待发送额度" end
  local entry={at=now(),done=false};invocations[r]=entry;leases[r]=entry;self.total+=1
  entry.thread=config.spawn(function()
   entry.results=table.pack(pcall(r.InvokeServer,r,table.unpack(args,1,args.n)));entry.done=true;entry.doneAt=now()
   if not entry.results[1] then self.lastError=tostring(entry.results[2]) end
   if invocations[r]==entry then invocations[r]=nil end
   if leases[r]==entry then leases[r]=nil end
  end)
  return entry
 end
 function self:InvokeOnce(r,...)
  if not r or not r.Parent then return false end
  if not r:IsA("RemoteFunction") then return self:Fire(r,...) end
  return beginInvoke(r,table.pack(...))~=nil
 end
 function self:Call(r,active,...)
  if active and not active() then return false,"流程已取消" end
  if not r or not r.Parent then return false,"远程对象不可用" end
  if not r:IsA("RemoteFunction") then return self:FireGuarded(r,active,...) end
  local entry,reason=beginInvoke(r,table.pack(...))
  if not entry then return false,reason end
  local deadline=now()+8
  while not entry.done and not self.stopped and (not active or active()) and now()<deadline do config.wait(0.05) end
  if not entry.done then return false,"调用仍在等待，未重复发送" end
  if self.stopped or (active and not active()) then return false,"流程已取消" end
  if not entry.results[1] then return false,tostring(entry.results[2]) end
  if entry.results[2]==false then return false,"服务器返回拒绝" end
  return true,table.unpack(entry.results,2,entry.results.n)
 end
 function self:PendingCalls()
  local n=0;for r,e in pairs(leases) do if e.event and now()>=e.deadline then leases[r]=nil else n+=1 end end;return n
 end
 function self:ObserveValue(kind,value,key)
  if type(value)~="number" or value~=value or math.abs(value)==math.huge then return end
  local old=observations[kind]
  if old and old.key==key and value>old.value then
   local field=kind=="strength" and "gainedStrength" or (kind=="durability" and "gainedDurability" or "gainedRebirths")
   self[field]+=value-old.value
  end
  if old then old.value=value;old.key=key else observations[kind]={value=value,key=key} end
 end
 function self:ForgetValue(kind) observations[kind]=nil end
 local function resetProbe()
  self.selectedRate=math.min(440,self.capacity);bestRate=self.selectedRate;bestGain=0
  holdLeft=0;zeroWindows=0;warmLeft=1;windowTime=0;windowGain=0;self.gainRate=nil;sendAcc=0
  capacityAnchor=self.capacity;capacityChanged=0
 end
 function self:Retest() profile=nil;self.lastError=nil end
 function self:SetCombat() self.combatUntil=now()+math.clamp(frameTime*2.5,0.15,1.5) end
 local function chooseLower(rate)
  for _,v in ipairs(rates) do if v<rate*0.98 then return v end end
 end
 function self:Step(dt,s)
  if self.stopped then return end
  local t=now()
  if t-reportAt>=1 then
   self.sentRate=(self.total-reportTotal)/(t-reportAt);self.repRate=(self.repTotal-reportReps)/(t-reportAt)
   reportAt=t;reportTotal=self.total;reportReps=self.repTotal
  end
  if dt>0 and dt<=0.5 then frameTime=frameTime*0.85+dt*0.15 end
  self.capacity=math.min(440,22/math.max(frameTime,1/240))
  self:ObserveValue("strength",s.strength,s.stat)
  local gain=self.gainedStrength-attributedGain;attributedGain=self.gainedStrength
  if lastMode~="fast" then gain=0 end
  for _,entry in pairs(invocations) do if t-entry.at>8 then self.lastError="远程函数超过8秒未返回，未重复调用" end end
  if self.pending and self.pending.invoking and t-self.pending.at>8 then self.lastError="重生调用超过8秒未返回，未重复调用" end
  local mode=s.mode
  if not s.alive or not s.remote or not s.remote.Parent then mode="paused" end
  local nextProfile=s.profileKey or "default"
  if profile~=nextProfile or remoteEpoch~=s.remote or charEpoch~=s.character or (lastMode=="idle" and mode=="fast") then
   profile=nextProfile;remoteEpoch=s.remote;charEpoch=s.character;resetProbe();gain=0
  end
  -- A reset/rebirth of the same stat does not discard positive increments or the active-time window.
  if mode=="idle" or mode=="paused" then
   self.rate=0;sendAcc=0
   self.status=mode=="idle" and "未开启" or (self.packStatus or "等待角色 / 换装")
   lastMode=mode;return
  end
  if dt>0.5 then
   sendAcc=0;warmLeft=1;windowTime=0;windowGain=0;self.gainRate=nil
   self.status="长帧后重新测量";lastMode=mode;return
  end
  if mode=="fast" and type(s.strength)=="number" then
   local elapsed=math.max(dt,0)
   if self.capacity>capacityAnchor*1.3 or self.capacity<capacityAnchor*0.7 then capacityChanged+=elapsed else capacityChanged=0 end
   if capacityChanged>=1.5 then resetProbe();gain=0 end
   if holdLeft>0 then holdLeft-=elapsed;if holdLeft<=0 then resetProbe() end end
   self.status=holdLeft>0 and "保持观测档位" or "对比力量增速"
   if warmLeft>0 then warmLeft=math.max(0,warmLeft-elapsed)
   else
    windowTime+=elapsed;windowGain+=math.max(0,gain)
    if windowTime>=4 then
     local observed=windowGain/windowTime;self.gainRate=observed
     if holdLeft<=0 then
      if observed>0 and (bestGain==0 or observed>=bestGain*0.98) then
       bestGain=math.max(bestGain,observed);bestRate=math.min(self.selectedRate,self.capacity);zeroWindows=0
       local lower=chooseLower(bestRate)
       if lower then self.selectedRate=lower else self.selectedRate=bestRate;holdLeft=45 end
      elseif observed<=0 then
       zeroWindows+=1
       if zeroWindows>=2 then self.selectedRate=math.min(120,self.capacity);holdLeft=15;self.status="未观察到增长" end
      else self.selectedRate=bestRate;holdLeft=45 end
      warmLeft=1
     end
     windowTime=0;windowGain=0
    end
   end
   self.rate=math.min(self.selectedRate,self.capacity)
  elseif mode=="combat" then self.rate=math.min(400,self.capacity);self.status="Boss输出"
  elseif mode=="normal" then self.rate=10;self.status="普通锻炼"
  else self.rate=math.min(120,self.capacity);self.status="等待力量数据" end
  lastMode=mode
  sendAcc=math.min(22,sendAcc+math.max(0,dt)*self.rate)
  local n=math.floor(sendAcc+1e-8);sendAcc-=n
  for _=1,n do
   local ok
   if mode=="combat" then hand+=1;ok=self:Fire(s.remote,"punch",hand%2==0 and "rightHand" or "leftHand")
   else ok=self:Fire(s.remote,"rep");if ok then self.repTotal+=1 end end
   if not ok then break end
  end
 end
 function self:PollRebirth(count)
  local p=self.pending;if not p or count==nil then return end
  if p.entry and p.entry.done and p.invoking then p.invoking=false;p.deadline=math.max(p.deadline,p.entry.doneAt+p.delay) end
  if count>p.before then
   self.variant=p.variant;self.locked=true;self.failures=0
   if not p.invoking then self.pending=nil;if leases[p.remote]==p then leases[p.remote]=nil end end
  elseif not p.invoking and now()>=p.deadline then
   self.pending=nil
   if leases[p.remote]==p then leases[p.remote]=nil end
   if self.locked then self.failures=(self.failures or 0)+1;if self.failures>=3 then self.locked=false;self.failures=0 end end
   if not self.locked then self.variant=self.variant%#config.variants+1 end
  end
 end
 function self:RequestRebirth(count,eligible)
  self:PollRebirth(count)
  if self.stopped or self.pending or not eligible or count==nil then return false end
  local v=config.variants[self.variant];local r=config.remote(v[1])
  if not r or not r.Parent or (not r:IsA("RemoteEvent") and not r:IsA("RemoteFunction")) then return false end
  local lease=leases[r]
  if lease then
   if lease.event and (now()>=lease.deadline or count>lease.before) then leases[r]=nil else return false,"等待上一条调用" end
  end
  if r:IsA("RemoteEvent") and not allowance() then return false end
  local delay=math.max(self.locked and 0.35 or 1.25,(config.ping() or 0)*3+0.25)
  local p={before=count,variant=self.variant,deadline=now()+delay,delay=delay,remote=r,at=now(),invoking=false};self.pending=p
  if r:IsA("RemoteFunction") then
   -- beginInvoke owns the one outstanding call, including across UI sessions.
   local args=v[2] and table.pack(v[2]) or table.pack()
   local entry,e=beginInvoke(r,args)
   if not entry then self.pending=nil;return false,e end
   p.entry=entry;p.invoking=not entry.done
  else
   p.event=true;leases[r]=p
   local ok,e
   if v[2] then ok,e=pcall(r.FireServer,r,v[2]) else ok,e=pcall(r.FireServer,r) end
   if ok then self.total+=1 else self.lastError=tostring(e) end
  end
  return true
 end
 function self:Stop()
  self.stopped=true
  -- A client timeout cannot cancel work already sent to the server. Keep the lease
  -- until the response arrives; the draining worker performs no further requests.
  self.pending=nil
 end
 return self
end

end)()
local createJBSPets=(function()
-- Plans use supplied/fallback pet stats. They do not assert the game's hidden buff formula.
return function(config)
 local self={status="尚未换装",verifiedSource=nil,diffActive=false,confirmed=false,sent=0,profileKey="default"}
 local rise,fall={},{}
 local function scoreBetter(a,b)
  return not b or a.strength>b.strength or (a.strength==b.strength and a.durability>b.durability)
 end
 function self:Plan(owned,slots,mode)
  local epoch=config.epoch and config.epoch()
  local operations=0
  slots=math.clamp(math.floor(slots),0,24)
  if slots==0 then return {} end
  if mode=="rebirth" then
   local candidates=table.clone(owned)
   table.sort(candidates,function(a,b) return a.rebirth>b.rebirth end)
   local result={};for _,p in ipairs(candidates) do if #result>=slots then break end;if p.rebirth>0 then result[#result+1]=p end end
   return result
  end
  local buckets,candidates={},{}
  for _,p in ipairs(owned) do
   local key=table.concat({p.repSpeed,p.strength,p.durability},":")
   buckets[key]=(buckets[key] or 0)+1
   if buckets[key]<=slots then candidates[#candidates+1]=p end
  end
  local dp={[0]={[0]={strength=0,durability=0}}}
  for _,p in ipairs(candidates) do
   for n=slots-1,0,-1 do
    if dp[n] then
     dp[n+1]=dp[n+1] or {}
     for speed,old in pairs(dp[n]) do
      operations+=1
      if operations%4096==0 and config.cooperate then
       if not config.cooperate() then return nil,"流程已取消" end
       if config.epoch and config.epoch()~=epoch then return nil,"context_changed" end
      end
      local nextSpeed=math.min(100,speed+math.max(0,math.floor(p.repSpeed)))
      local cell={strength=old.strength+p.strength,durability=old.durability+p.durability,parent=old,pet=p}
      if scoreBetter(cell,dp[n+1][nextSpeed]) then dp[n+1][nextSpeed]=cell end
     end
    end
   end
  end
  local best,bestSpeed=nil,-1
  for n=0,slots do
   for speed,cell in pairs(dp[n] or {}) do
    if speed>bestSpeed or (speed==bestSpeed and scoreBetter(cell,best)) then best=cell;bestSpeed=speed end
   end
  end
  local result={};while best and best.pet do table.insert(result,1,best.pet);best=best.parent end
  return result
 end
 local function equal(a,b)
  for p in pairs(a) do if not b[p] then return false end end
  for p in pairs(b) do if not a[p] then return false end end
  return true
 end
 local function waitState(owned,target,source,epoch)
  local deadline=config.clock()+math.clamp(1.5+(config.ping() or 0)*3,1.5,8)
  local nextCheck=0;local lastVersion=-1
  while config.active() do
   if config.epoch and config.epoch()~=epoch then return false,"context_changed" end
   local t=config.clock();local version=config.version and config.version() or t
   if t>=nextCheck or version~=lastVersion then
    nextCheck=t+0.25;lastVersion=version
    local state,key=config.readEquipment(owned)
    if not state or key~=source then return false,"装备状态来源失效" end
    if equal(state,target) then return true end
   end
   if t>=deadline then return false,"装备状态确认超时" end
   config.wait(0.05)
  end
  return false,"流程已取消"
 end
 function self:Apply(owned,plan)
  self.confirmed=false;self.diffActive=false;self.failure=nil
  if not config.active() then return false,"流程已取消" end
  local epoch=config.epoch and config.epoch()
  local target={};local profile={}
  for _,p in ipairs(plan) do target[p.instance]=true;profile[#profile+1]=table.concat({p.repSpeed,p.strength,p.durability,p.rebirth},":") end
  table.sort(profile)
  local before,source,explicit=config.readEquipment(owned)
  if source=="configured_invalid" then self.status="显式装备读取器无效";return false,self.status end
  if not before then self.verifiedSource=nil;rise={};fall={} end
  local trusted=before and (explicit or self.verifiedSource==source)
  local function send(cmd,p)
   if not config.active() then return false end
   if config.epoch and config.epoch()~=epoch then self.failure="context_changed";return false end
   if config.alivePet and not config.alivePet(p) then self.failure="context_changed";return false end
   local ok=config.send(cmd,p);if ok then self.sent+=1 end;return ok
  end
  self.status="正在切换装备"
  if trusted then
   self.diffActive=true
   for p in pairs(before) do if not target[p] and not send("unequipPet",p) then return false,self.failure or "卸下调用失败" end end
   -- Confirm removals before adding, so server-side slot limits cannot reject the new set.
   local kept={};for p in pairs(before) do if target[p] then kept[p]=true end end
   local ok,e=waitState(owned,kept,source,epoch);if not ok then self.status=e;return false,e end
   for p in pairs(target) do if not kept[p] and not send("equipPet",p) then return false,self.failure or "装备调用失败" end end
  else
   for _,p in ipairs(owned) do if not send("unequipPet",p.instance) then return false,self.failure or "卸下调用失败" end end
   if before then
    local ok,e=waitState(owned,{},source,epoch)
    if not ok then self.status=e;return false,e end
    if next(before) then fall[source]=true end
   else
    config.wait(0.1)
   end
   for _,p in ipairs(plan) do if not send("equipPet",p.instance) then return false,self.failure or "装备调用失败" end end
  end
  if before then
   local ok,e=waitState(owned,target,source,epoch)
   if not ok then self.status=e;return false,e end
   if next(target) then rise[source]=true end
   if explicit or (rise[source] and fall[source]) then self.verifiedSource=source end
   self.confirmed=true;self.status="已观察到目标装备状态"
  else
   config.wait(math.max(0.25,(config.ping() or 0)*2))
   if not config.active() then return false,"流程已取消" end
   self.status="兼容换装：缺少可确认状态"
  end
  if config.epoch and config.epoch()~=epoch then return false,"context_changed" end
  self.profileKey=table.concat(profile,"|")
  return true,self.confirmed and "confirmed" or "unverified"
 end
 return self
end

end)()

local function loadLibrary()
-- JBS UI library v3.2. Evaluating this file returns an API; it creates no window.
-- Compatible with the CreateWindow/Tab/control/Notify calls used by JBS v3.1.
local environment=_G
do local ok,e=pcall(function() return type(getgenv)=="function" and getgenv() or _G end);if ok and type(e)=="table" then environment=e end end
local KEY="__JBSMetalLibraryExtremeR320261018"
local cached=environment[KEY]
if cached then
 assert(cached.Version=="3.2", "JBS 库版本冲突，请重新进入游戏")
 return cached
end
local Library={Version="3.2",Revision="Extreme-R3-2026-10-18",GameState="idle"}
local instance,window
local function currentGui()
 local player=game:GetService("Players").LocalPlayer
 assert(player,"JBS 必须在游戏客户端运行")
 local root=player:WaitForChild("PlayerGui",12);assert(root,"PlayerGui尚未就绪，请重新执行");return root
end
local function legacyConflict()
 local roots={currentGui()}
 local ok,core=pcall(function() return game:GetService("CoreGui") end)
 if ok and core then roots[#roots+1]=core end
 for _,root in ipairs(roots) do
  for _,node in ipairs(root:GetDescendants()) do
   if node:IsA("ScreenGui") and (node.Name=="JBS_91_78_Showcase" or (node.Name=="JBS_Metal_v31" and not (instance and instance:IsAlive()))) then return node.Name end
   if node:IsA("TextLabel") or node:IsA("TextButton") then
    local text=node.Text or ""
    if text=="JBS 鸡巴骚" or text=="JBS鸡巴骚" or text=="JBS 力量传奇 · 金属版" then return text end
   end
  end
 end
 -- Original JBS exposes these flags even when its window has been hidden/destroyed.
 -- Before this library's own game starts, they are evidence of an older game session.
 if Library.GameState=="idle" then
  for _,key in ipairs({"auto_train","auto_rebirth","auto_wheel","auto_petbuy","auto_packrebirth","auto_eategg","auto_fasttrain","auto_boss"}) do
   if rawget(_G,key)~=nil then return "旧版 JBS 功能状态" end
  end
 end
end
local function checkLegacy()
 local conflict=legacyConflict()
 assert(not conflict,"检测到旧 JBS（"..tostring(conflict).."）。请退出并重新进入游戏，只运行新版启动文件；不要同时运行原脚本或旧 UI。")
end
local function createRenderer()
-- JBS 91&78 · native pink-purple metal grille
-- Embedded metal renderer; game-dependent entry point. See the bundled README.
-- Game callbacks are supplied through the embedded compatibility adapter.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
assert(player, "请在客户端 LocalScript 中运行")
local playerGui = player:WaitForChild("PlayerGui",12);assert(playerGui,"PlayerGui尚未就绪，请重新执行")
local previous = playerGui:FindFirstChild("JBS_Metal_v31")
assert(not previous, "JBS 已在运行")
local scene = {version="metal-grid-2", width=1016, height=726, palette={base="#16091F", panel="#251033", pink="#FF4FD8", violet="#A855F7", pearl="#D8B4FE", white="#FFE6FA"}, pattern={pitchX=42, pitchY=28, size=13}, navigation={{id="main", label="主要", icon="bolt"}, {id="travel", label="传送", icon="pin"}, {id="pets", label="宠物", icon="pet"}, {id="boss", label="Boss", icon="crown"}, {id="pack", label="换包重生", icon="weight"}}, features={}}
local colorCache={}
local function rgb(hex)
 if not colorCache[hex] then colorCache[hex]=Color3.fromHex(hex:gsub("#", "")) end
 return colorCache[hex]
end
local P = scene.palette
local WHITE = Color3.new(1,1,1)
local function make(class, properties, parent)
 local object = Instance.new(class)
 for key, value in pairs(properties) do object[key] = value end
 object.Parent = parent
 return object
end
local function corner(object, radius) make("UICorner", {CornerRadius=UDim.new(0,radius)}, object) end
local function gradient(object, stops, rotation)
 local keys = {}
 for _, stop in ipairs(stops) do keys[#keys+1] = ColorSequenceKeypoint.new(stop[1],rgb(stop[2])) end
 return make("UIGradient",{Color=ColorSequence.new(keys),Rotation=rotation or 0},object)
end
local function stroke(object, color, thickness, transparency)
 return make("UIStroke",{Color=rgb(color),Thickness=thickness or 1,Transparency=transparency or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},object)
end
local function frame(parent,name,x,y,w,h,color,r,z,alpha)
 local o=make("Frame",{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=rgb(color or P.base),BackgroundTransparency=alpha or 0,BorderSizePixel=0,Active=false,ZIndex=z or 1},parent)
 if r then corner(o,r) end
 return o
end
local function label(parent,name,text,x,y,w,h,size,color,bold,z)
 -- 分级字号：窗口外观大字（≥18pt）保持原尺寸；内容区小字放大 1.75 倍提升可读性；Tribe/背景水印/悬浮按钮文字保持原样
 -- 外观项：LOGO 43/45、标题 20/25、导航 19、按钮图标 20-26 均恢复原始大小；内容项：功能名 16→22、状态 12→17、说明 11-13→15-18、输入值 15→21
 return make("TextLabel",{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextSize=(size>=18 or name=="Tribe" or name=="JBSMetalMark" or name=="Text") and size or math.floor(size*1.75+.5),TextColor3=rgb(color or P.white),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=false,Active=false,Selectable=false,ZIndex=z or 5},parent)
end
local function button(parent,name,x,y,w,h,r)
 local b=make("TextButton",{Name=name,Text="",Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Selectable=true,ClipsDescendants=true,ZIndex=5},parent)
 if r then corner(b,r) end
 return b
end
local connections, tweens, temporaries = {}, {}, {}
local destroyed=false
local function connect(event,callback)
 local c=event:Connect(callback);connections[#connections+1]=c;return c
end
local function tween(object, properties, duration, delay)
 local t=TweenService:Create(object,TweenInfo.new(duration or .22,Enum.EasingStyle.Quart,Enum.EasingDirection.Out,0,false,delay or 0),properties)
 tweens[t]=true
 t.Completed:Once(function() tweens[t]=nil end)
 t:Play();return t
end
local gui=make("ScreenGui",{Name="JBS_Metal_v31",ResetOnSpawn=false,DisplayOrder=30,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
gui:SetAttribute("JBSLibraryVersion","3.2")
local viewport=frame(gui,"Viewport",0,0,0,0,P.base,nil,1,1)
viewport.Size=UDim2.fromScale(1,1)
local canvas=frame(viewport,"ReferenceCanvas",0,0,1016,726,P.base,nil,1,1)
canvas.Position=UDim2.fromScale(.5,.5);canvas.AnchorPoint=Vector2.new(.5,.5)
local scale=make("UIScale",{Scale=1},canvas)
local expanded=false
local function fit()
 local size=viewport.AbsoluteSize
 scale.Scale=math.max(.05,math.min((size.X-44)/1016,(size.Y-44)/726,expanded and 1.6 or 1.2))
end
connect(viewport:GetPropertyChangedSignal("AbsoluteSize"),fit);fit()
-- Ordinary Frames keep content visible on low-memory mobile clients.
local shell=make("Frame",{Name="Window",Size=UDim2.fromOffset(1016,726),BackgroundColor3=WHITE,BorderSizePixel=0,ClipsDescendants=true,ZIndex=2},canvas)
make("UIScale",{Scale=0.92},shell)  -- 整窗缩放:稍微变小(约8%)
corner(shell,28)
local shellMetal=gradient(shell,{{0,"#64245D"},{.3,P.panel},{.58,P.base},{1,"#572476"}},30)
local rim=stroke(shell,P.white,1.5,.08)
local metalStops={{0,"#8B439F"},{.28,P.pink},{.43,P.pearl},{.49,P.white},{.53,"#562168"},{.7,P.violet},{1,"#D777D1"}}
local rimGradient=gradient(rim,metalStops,25)
local glows={}
for i,thickness in ipairs({16,9,4}) do
 local g=frame(canvas,"AmbientRim"..i,0,0,1016,726,P.base,28,1,1)
 local s=stroke(g,P.pink,thickness,.96-i*.025)
 glows[#glows+1]={object=g,stroke=s}
end
local inner=frame(shell,"InnerEdge",5,5,1006,716,P.base,23,2,1);stroke(inner,P.pearl,1,.78)
local headerLine=frame(shell,"HeaderLine",28,93,960,1,P.pearl,nil,3,.82)
local logo=label(shell,"HeaderJBS","JBS",28,21,89,52,43,P.white,true)
logo.TextColor3=WHITE
local logoGradient=gradient(logo,{{0,"#B36DCC"},{.25,P.pink},{.41,P.pearl},{.47,P.white},{.51,"#642075"},{.66,"#F38CD9"},{1,P.pearl}},15)
label(shell,"Title","JBS 力量传奇",135,24,320,26,20,P.white,true)
label(shell,"Tribe","部落 ID · 91&78",135,53,300,19,12,P.pearl)
for i=0,15 do
 local slat=frame(shell,"HeaderMetal",618+i*12,27,1,39,P.pearl,nil,3,.62)
 gradient(slat,{{0,"#69256C"},{.43,P.pink},{.5,P.white},{.59,"#713087"},{1,P.pearl}},75)
end
local minimize=button(shell,"Minimize",858,28,32,32,8)
local expand=button(shell,"Expand",902,28,32,32,8)
local close=button(shell,"Close",946,28,32,32,8)
label(minimize,"Glyph","—",6,0,26,30,20,P.pearl)
label(expand,"Glyph","□",7,0,26,30,22,P.pearl)
label(close,"Glyph","×",8,0,24,30,26,P.pearl)
-- ===== 新增：标题栏 Ping 小窗 =====
-- 位置：标题文字与金属百叶窗之间的空档；常驻显示实时 Data Ping，颜色分级 <250绿 / <2500黄 / 红
local pingStats=game:GetService("Stats")
local pingBox=frame(shell,"PingBadge",462,27,148,40,P.base,10,6,0)
gradient(pingBox,{{0,"#3C185E"},{1,"#572476"}},20)
stroke(pingBox,P.pearl,1,.35)
local pingDot=frame(pingBox,"Dot",10,17,6,6,P.pink,nil,7,0)
local pingText=label(pingBox,"Value","PING --",24,7,100,26,12,P.white,true,7)
local pingUnit=label(pingBox,"Unit","ms",126,14,16,14,8,P.pearl,false,7)
local pingAccum=0
local function updatePing()
 local ok,v=pcall(function() return pingStats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
 local p=(ok and type(v)=="number") and v or 0
 if p<=0 then pingText.Text="PING --" return end
 pingText.Text=string.format("PING %d",math.floor(p+.5))
 local c
 if p<250 then c=rgb("#7DFF8A")
 elseif p<2500 then c=rgb("#FFDC64")
 else c=rgb("#FF6E6E") end
 pingText.TextColor3=c
 pingDot.BackgroundColor3=c
end
updatePing()
local side=frame(shell,"Sidebar",13,94,350,619,P.panel,18,3,1)
local content=frame(shell,"Content",375,94,628,619,P.panel,18,3)
content.BackgroundColor3=WHITE;content.ClipsDescendants=true
local contentMetal=gradient(content,{{0,"#74286D"},{.45,"#2C103F"},{1,"#5D257C"}},34)
stroke(content,P.pearl,1,.38)
-- The glyph prototype is reused; one shared render loop controls spatial reflection.
-- All marks remain upright. Safe inset keeps their bounds inside the rounded corners.
local glyphs={}
local prototype=label(nil,"JBSMetalMark","JBS",0,0,29,17,scene.pattern.size,P.white,true,2)
prototype.TextColor3=WHITE
local protoGradient=gradient(prototype,{{0,"#A663BB"},{.27,"#F4AFE2"},{.42,P.white},{.49,"#7A398F"},{.67,"#BD76DE"},{1,"#EC97D6"}},90)
local function pattern(parent,w,h,opacity)
 local material=frame(parent,"BrandMaterial",0,0,w,h,P.base,nil,1,1)
 material.ClipsDescendants=true
 for row=0,math.floor((h-30)/42) do
  local y=12+row*42
  for col=0,math.floor(w/56) do
   local x=12+col*56+(row%2)*28
   if x+29<w-12 then
    local glyph=prototype:Clone();glyph.Position=UDim2.fromOffset(x,y);glyph.TextTransparency=1-opacity;glyph.Parent=material
    glyphs[#glyphs+1]={object=glyph,x=x,y=y,width=w,base=opacity}
   end
  end
 end
end
pattern(side,350,619,.29);pattern(content,628,619,.65);prototype:Destroy()
local searchMaterial=frame(side,"SearchMaterial",8,0,334,70,P.white,17,4)
searchMaterial.BackgroundColor3=WHITE
gradient(searchMaterial,{{0,"#542354"},{1,P.panel}},25)
stroke(searchMaterial,P.pearl,1,.55)
local search=make("TextBox",{Name="Search",PlaceholderText="搜索功能",Text="",ClearTextOnFocus=false,Position=UDim2.fromOffset(8,0),Size=UDim2.fromOffset(334,70),BackgroundTransparency=1,BackgroundColor3=WHITE,BorderSizePixel=0,TextColor3=rgb(P.white),PlaceholderColor3=rgb(P.pearl),Font=Enum.Font.Gotham,TextSize=24,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5},side)
corner(search,17)
make("UIPadding",{PaddingLeft=UDim.new(0,24),PaddingRight=UDim.new(0,18)},search)
for i=1,#scene.navigation do
 local backing=frame(side,"NavigationBacking",8,90+(i-1)*72,334,57,P.panel,12,3,.08)
end
local selection=frame(side,"SelectedNavigation",8,90,334,57,P.white,12,4)
selection.BackgroundColor3=WHITE;gradient(selection,{{0,"#E73CBD"},{.7,P.violet},{1,"#7F33D0"}},15);stroke(selection,P.white,1,.48)
local selectionGlow=frame(selection,"LightStrip",0,15,3,26,P.white,2,5)
local menuButtons={}
-- Consistent lightweight vector icons. These are UI symbols, with no external assets.
local function line(parent,x1,y1,x2,y2,color,width)
 local dx,dy=x2-x1,y2-y1
 local o=frame(parent,"IconStroke",(x1+x2)/2,(y1+y2)/2,math.sqrt(dx*dx+dy*dy),width or 1.6,color,1,6)
 o.AnchorPoint=Vector2.new(.5,.5);o.Rotation=math.deg(math.atan2(dy,dx));return o
end
local function icon(parent,kind,x,y)
 local p=frame(parent,"Icon",x,y,24,24,P.base,nil,6,1)
 local paths={bolt={{13,2,4,14},{4,14,11,14},{11,14,10,22},{10,22,20,9},{20,9,13,9},{13,9,13,2}},weight={{7,12,17,12},{4,7,4,17},{7,5,7,19},{17,5,17,19},{20,7,20,17}},pin={{4,9,12,3},{12,3,20,9},{20,9,18,15},{18,15,12,22},{12,22,6,15},{6,15,4,9}},pet={{4,9,3,3},{3,3,9,6},{9,6,15,6},{15,6,21,3},{21,3,20,16},{20,16,16,20},{16,20,8,20},{8,20,4,16},{4,16,4,9},{8,12,8,13},{16,12,16,13},{10,16,12,18},{12,18,14,16}},crown={{3,6,8,11},{8,11,12,3},{12,3,16,11},{16,11,21,6},{21,6,19,19},{19,19,5,19},{5,19,3,6},{6,16,18,16}},spark={{12,2,15,9},{15,9,22,12},{22,12,15,15},{15,15,12,22},{12,22,9,15},{9,15,2,12},{2,12,9,9},{9,9,12,2}}}
 for _,v in ipairs(paths[kind] or paths.spark) do line(p,v[1],v[2],v[3],v[4],P.pearl) end
 return p
end
for i,item in ipairs(scene.navigation) do
 local b=button(side,item.id,8,90+(i-1)*72,334,57,12)
 icon(b,item.icon,24,16)
 local title=label(b,"Label",item.label,68,0,210,57,19,P.pearl)
 label(b,"Index",string.format("%02d",i),299,0,27,57,11,P.pearl)
 menuButtons[i]={button=b,title=title,item=item}
end
frame(side,"SignatureRule",24,505,302,1,P.pearl,nil,4,.7)
local sideLogo=label(side,"SideJBS","JBS",24,524,140,50,45,P.white,true)
sideLogo.TextColor3=WHITE
local sideLogoGradient=gradient(sideLogo,metalStops,20)
local signatureSubtitle=label(side,"SignatureSubtitle","部落专属",24,576,84,18,11,P.pearl)
signatureSubtitle.TextXAlignment=Enum.TextXAlignment.Center
label(side,"IDs","91&78",219,548,105,39,25,P.white,true)
local titleGuard=frame(content,"TitleGuard",1,1,626,115,P.panel,17,3,.02)
make("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.35,0),NumberSequenceKeypoint.new(.65,.8),NumberSequenceKeypoint.new(1,1)})},titleGuard)
local pageTitle=label(content,"PageTitle","主要",26,23,325,35,25,P.white,true)
local description=label(content,"Description","功能列表",26,65,350,20,12,P.pearl)
local edition=frame(content,"Edition",474,26,127,33,P.white,7,4)
gradient(edition,{{0,"#AC4B9E"},{1,"#62288B"}},20);stroke(edition,P.pearl,1,.45)
label(edition,"EditionText","JBS · 91&78",12,0,106,33,12,P.white,true)
local list=make("Frame",{Name="Features",Position=UDim2.fromOffset(22,116),Size=UDim2.fromOffset(584,398),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},content)
local footer=frame(content,"FooterShade",1,521,626,97,P.panel,nil,3,.13)
make("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})},footer)
local dot=frame(content,"StatusLight",27,578,5,5,P.white,3,5);stroke(dot,P.pink,3,.72)
label(content,"Footer","JBS · 力量传奇",40,563,350,34,13,P.white,true)
label(content,"FooterIDs","91&78",530,563,85,34,14,P.white,true)
local stars={}
for i=1,16 do
 local x=28+(i*37)%570
 local y=i<=6 and 10+(i*7)%85 or 530+(i*13)%64
 local s=frame(content,"Spark",x,y,2,2,P.white,1,2,.5)
 stars[#stars+1]={object=s,phase=i*.77}
 if i%4==0 then
  for _,size in ipairs({{1,10},{10,1}}) do
   local ray=frame(s,"StarRay",1,1,size[1],size[2],P.white,nil,2,.3)
   ray.AnchorPoint=Vector2.new(.5,.5)
  end
 end
end
local notice=frame(shell,"ReadyNotice",410,620,570,90,P.white,12,15)
gradient(notice,{{0,"#852A77"},{1,"#3C185E"}},15);stroke(notice,P.pearl,1,.25)
label(notice,"Mark","JBS",17,10,66,44,26,P.white,true,16)
label(notice,"Ready","界面已就绪",95,10,450,25,15,P.white,true,16)
label(notice,"Details","91&78 · 金属印记",95,35,450,46,11,P.pearl,false,16)
notice.Details.TextWrapped=true
notice.Visible=false
local restore=button(viewport,"RestoreJBS",0,0,132,46,14) -- 收起后的悬浮按钮
restore.Position=UDim2.fromScale(.5,.5);restore.AnchorPoint=Vector2.new(.5,.5);restore.BackgroundTransparency=0;restore.BackgroundColor3=WHITE
stroke(restore,P.pearl,1,.2);gradient(restore,{{0,"#982A80"},{1,"#6539A3"}},20)
local restoreLabel=label(restore,"Text","JBS 鸡巴骚",0,0,132,46,16,P.white,true) -- 注意：TextButton.Text 是属性(字符串)，不能用 restore.Text 访问子标签，必须接住 label() 的返回值
restoreLabel.TextXAlignment=Enum.TextXAlignment.Center -- 文字居中
restore.Visible=false
-- ===== 新增：关闭确认弹窗 =====
-- × 不再直接销毁：先弹确认框，「确定关闭」才执行 gui:Destroy()，「取消」返回
local confirmMask=frame(viewport,"CloseMask",0,0,0,0,P.base,nil,40,.5)
confirmMask.Size=UDim2.fromScale(1,1)
local confirmBox=frame(viewport,"CloseConfirm",0,0,480,150,P.base,18,41,0)
confirmBox.Position=UDim2.fromScale(.5,.5);confirmBox.AnchorPoint=Vector2.new(.5,.5)
gradient(confirmBox,{{0,"#5A2170"},{.5,"#2C103F"},{1,"#3C185E"}},20)
stroke(confirmBox,P.pearl,1,.25)
label(confirmBox,"Title","关闭 JBS 界面？",28,20,330,34,20,P.white,true,45)
local okBtn=button(confirmBox,"ConfirmClose",28,78,200,52,14)
okBtn.BackgroundTransparency=0;okBtn.BackgroundColor3=WHITE
gradient(okBtn,{{0,"#E73CBD"},{1,"#7F33D0"}},20)
stroke(okBtn,P.white,1,.4)
local okLabel=label(okBtn,"Text","确定关闭",0,0,200,52,16,P.white,true)
okLabel.TextXAlignment=Enum.TextXAlignment.Center
local cancelBtn=button(confirmBox,"CancelClose",252,78,200,52,14)
cancelBtn.BackgroundTransparency=.15;cancelBtn.BackgroundColor3=WHITE
gradient(cancelBtn,{{0,"#41174F"},{1,"#2C103F"}},0)
stroke(cancelBtn,P.pearl,1,.45)
local cancelLabel=label(cancelBtn,"Text","取消",0,0,200,52,16,P.pearl,true)
cancelLabel.TextXAlignment=Enum.TextXAlignment.Center
local onClosedHandler
local sessionClosed=false
local function endSession()
 if sessionClosed then return end;sessionClosed=true
 pcall(function() local hook=_G.__JBS_shutdown_hook or _G.__JBS_boot_cleanup;if type(hook)=="function" then hook() end end)
 if onClosedHandler then pcall(onClosedHandler) end
end
local function setConfirm(open)
 confirmMask.Visible=open;confirmBox.Visible=open
 if open then confirmMask.BackgroundTransparency=1;tween(confirmMask,{BackgroundTransparency=.5},.18) end
end
confirmMask.Visible=false;confirmBox.Visible=false
connect(okBtn.Activated,function()
 -- 确认关闭：先停掉旧会话(功能线程/标志/Boss心跳)，再重置 Library 状态，最后销毁界面
 -- 这样关闭后无需重进服务器，直接重新执行脚本即可完整加载
 endSession()
 gui:Destroy()
end)
connect(cancelBtn.Activated,function() setConfirm(false) end)
-- ===== 新增：悬浮窗拖动 =====
-- 原因：canvas 被固定在屏幕中心（scale .5,.5），且全脚本没有任何拖动输入处理，因此窗口无法移动
-- 方案：标题栏热区按住即可拖动整个窗口（避开右上角三个窗口按钮）；收起后的悬浮按钮同样可拖动；拖动范围不限
local dragHandle=button(shell,"DragHandle",13,8,830,78)
local dragging,dragStart,dragStartPos
local restoreDragging,restoreMoved,restoreStart,restoreStartPos
local dragConnections={}
local function dragEndWatch(input,key,finish)
 if dragConnections[key] then dragConnections[key]:Disconnect() end
 dragConnections[key]=input.Changed:Connect(function()
  if input.UserInputState==Enum.UserInputState.End then
   finish();local c=dragConnections[key];dragConnections[key]=nil;if c then c:Disconnect() end
  end
 end)
end
connect(gui.Destroying,function() for _,c in pairs(dragConnections) do c:Disconnect() end;table.clear(dragConnections) end)
connect(UserInputService.WindowFocusReleased,function()
 dragging=false;restoreDragging=false
 for _,c in pairs(dragConnections) do c:Disconnect() end;table.clear(dragConnections)
end)
connect(dragHandle.InputBegan,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  dragging=true;dragStart=input.Position;dragStartPos=canvas.Position
  dragEndWatch(input,"main",function() dragging=false end)
 end
end)
connect(restore.InputBegan,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  restoreDragging=true;restoreMoved=false;restoreStart=input.Position;restoreStartPos=restore.Position
  dragEndWatch(input,"restore",function() restoreDragging=false end)
 end
end)
connect(UserInputService.InputChanged,function(input)
 if not dragging and not restoreDragging then return end
 if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
 if dragging then
  local delta=input.Position-dragStart
  canvas.Position=UDim2.new(.5,dragStartPos.X.Offset+delta.X,.5,dragStartPos.Y.Offset+delta.Y)
 end
 if restoreDragging then
  local delta=input.Position-restoreStart
  if math.abs(delta.X)+math.abs(delta.Y)>8 then restoreMoved=true end
  restore.Position=UDim2.new(restoreStartPos.X.Scale,restoreStartPos.X.Offset+delta.X,restoreStartPos.Y.Scale,restoreStartPos.Y.Offset+delta.Y)
 end
end)
-- WindUI-compatible binding layer. All callbacks are supplied by the original game file.
local actionEvent=make("BindableEvent",{Name="UISelectionChanged"},gui)
local scroll=make("ScrollingFrame",{Name="ControlScroll",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=5,ScrollBarImageColor3=rgb(P.pink),ScrollingDirection=Enum.ScrollingDirection.Y,Active=true,ZIndex=5},list)
local category="main"
local cards={}
local empty=label(scroll,"Empty","没有匹配的功能",4,4,564,70,15,P.pearl)
empty.TextXAlignment=Enum.TextXAlignment.Center;empty.Visible=false
local adapter,window={},{}
local toggleKeys={
 ["自动重生"]="auto_rebirth",["自动锻炼"]="auto_train",["自动轮盘"]="auto_wheel",
 ["自动购买"]="auto_petbuy",["自动打Boss"]="auto_boss",["换包重生"]="auto_packrebirth",
 ["快速锻炼"]="auto_fasttrain",["自动吃蛋"]="auto_eategg",["Boss重生"]="auto_bossrebirth",
}
local displayNames={
 ["目标次数"]="重生目标次数",["自动购买"]="自动购买宠物 / 光环",
 ["购买一次"]="购买所选宠物 / 光环",["悬停高度"]="Boss 悬停高度",
 ["送蛋"]="赠送蛋白蛋",["自动吃蛋"]="自动使用蛋白蛋",
 ["快速锻炼"]="快速锻炼",
}
-- UI-only lifetime: every toast gets its own three-second deadline.
-- Heartbeat is independent of decorative animation pause/focus handling.
local NOTICE_DURATION=3
local noticeToken,noticeDeadline=0,0
local progressTrack=frame(notice,"CountdownTrack",18,77,534,4,"#281034",2,16)
stroke(progressTrack,P.pearl,1,.75)
local progressFill=frame(progressTrack,"CountdownFill",0,0,534,4,P.white,2,17)
gradient(progressFill,{{0,P.pink},{.52,P.violet},{.86,P.pearl},{1,P.white}},0)
stroke(progressFill,P.pink,2,.55)
local countdown=label(notice,"Countdown","3.0s",488,9,64,23,11,P.pearl,false,17)
countdown.TextXAlignment=Enum.TextXAlignment.Right
notice.Ready.Size=UDim2.fromOffset(380,25)
notice.Details.Size=UDim2.fromOffset(450,34)
notice.Active=false
local function updateNoticeCountdown()
 if not notice.Visible then return end
 local remaining=math.max(0,noticeDeadline-os.clock())
 progressFill.Size=UDim2.fromScale(remaining/NOTICE_DURATION,1)
 countdown.Text=string.format("%.1fs",math.ceil(remaining*10)/10)
 if remaining<=0 then notice.Visible=false end
end
connect(RunService.Heartbeat,updateNoticeCountdown)
-- Presentation only: retain original feature callbacks and their parameters.
local function formatNoticeContent(content,title)
 local message=tostring(content or "")
 message=message:gsub("，无限", ""):gsub(",%s*无限", "")
 message=message:gsub("自动重生已开启", "自动重生以开始"):gsub("自动重生已开始", "自动重生以开始")
 local closed=string.find(tostring(title or ""),"已关闭",1,true) or string.find(message,"已关闭",1,true) or string.find(message,"已停止",1,true)
 message=message:gsub("%s*开🦌开🦌", ""):gsub("%s*🐍了🐍了", "")
 message=message..(closed and " 🐍了🐍了" or " 开🦌开🦌")
 return message
end
function adapter:Notify(options)
 if destroyed then return end
 noticeToken=noticeToken+1;local token=noticeToken
 noticeDeadline=os.clock()+NOTICE_DURATION
 gui:SetAttribute("NoticeSequence",noticeToken)
 notice.Ready.Text=tostring(options.Title or "JBS")
 notice.Details.Text=formatNoticeContent(options.Content,options.Title)
 progressFill.Size=UDim2.fromScale(1,1)
 countdown.Text="3.0s"
 notice.Visible=shell.Visible and gui.Enabled
 task.delay(NOTICE_DURATION,function()
  if not destroyed and token==noticeToken then
   progressFill.Size=UDim2.fromScale(0,1)
   countdown.Text="0.0s"
   notice.Visible=false
  end
 end)
 -- When the window is hidden, retain a short native notification instead.
 if not notice.Visible then
  pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title=options.Title or "JBS",Text=notice.Details.Text,Duration=NOTICE_DURATION}) end)
 end
end
local function syncToggle(c)
 if c.kind~="Toggle" then return end
 local key=toggleKeys[c.originalTitle]
 if key then c.value=_G[key]==true end
 if c.lastSyncedValue==c.value and c.lastSyncedBusy==c.busy then return end
 c.lastSyncedValue=c.value;c.lastSyncedBusy=c.busy
 c.state.Text=c.busy and "处理中" or (c.value and "已开启" or "已关闭")
 c.track.BackgroundColor3=rgb(c.value and P.pink or "#5A3565")
 c.knob.Position=UDim2.fromOffset(c.value and 25 or 3,3)
 c.edge.Transparency=c.value and .12 or .6
 c.button:SetAttribute("Value",c.value)
end
local function invoke(c,value)
 if destroyed or c.busy then return end
 c.busy=true
 if c.kind=="Toggle" then syncToggle(c) end
 if c.kind=="Button" then c.state.Text="处理中…" end
 task.spawn(function()
  if destroyed then return end
  local ok,err=pcall(c.options.Callback or function() end,value)
  c.busy=false
  if destroyed then return end
  if c.kind=="Toggle" then syncToggle(c) end
  if c.kind=="Button" then c.state.Text="执行 ›" end
  if not ok then
   adapter:Notify({Title="操作未完成",Content=tostring(err),Duration=7})
   warn("[JBS Metal UI] "..tostring(err))
  end
 end)
end
local function filterCards(animate)
 local y,count=4,0;local q=string.lower(search.Text)
 for _,c in ipairs(cards) do
  local show=c.item.category==category and (q=="" or (c.kind~="Divider" and c.kind~="Section" and string.find(string.lower(c.item.label.." "..c.originalTitle),q,1,true)~=nil))
  c.button.Visible=show
  if show then
   c.y=y;c.button.Position=UDim2.fromOffset(4,y);y=y+c.height+8
   if c.kind~="Divider" and c.kind~="Section" then count=count+1 end
  end
 end
 scroll.CanvasSize=UDim2.fromOffset(0,y+6)
 empty.Visible=count==0;description.Text=(q~="" and "搜索结果" or "功能列表")
 if animate then
  scroll.CanvasPosition=Vector2.zero
  list.Position=UDim2.fromOffset(22,125);
  tween(list,{Position=UDim2.fromOffset(22,116),},.22)
 end
end
-- Dropdown is a window-level modal, so neither the page nor its scroll area clips it.
local popup=frame(shell,"DropdownModal",380,112,600,488,P.base,16,30,.02)
popup.Visible=false;stroke(popup,P.pink,1,.1)
local popupTitle=label(popup,"Title","选择",18,12,500,30,18,P.white,true,31)
local popupClose=button(popup,"CloseDropdown",552,10,32,32,8);popupClose.ZIndex=32
label(popupClose,"Glyph","×",4,0,28,32,24,P.white,false,33)
local popupSearch=make("TextBox",{Name="OptionSearch",Position=UDim2.fromOffset(18,52),Size=UDim2.fromOffset(564,40),BackgroundColor3=rgb(P.panel),BorderSizePixel=0,Text="",PlaceholderText="搜索选项",TextColor3=rgb(P.white),PlaceholderColor3=rgb(P.pearl),TextSize=26,Font=Enum.Font.Gotham,ClearTextOnFocus=false,ZIndex=31},popup)
corner(popupSearch,8)
local popupList=make("ScrollingFrame",{Name="Options",Position=UDim2.fromOffset(18,102),Size=UDim2.fromOffset(564,366),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=5,ScrollBarImageColor3=rgb(P.pink),ScrollingDirection=Enum.ScrollingDirection.Y,Active=true,ZIndex=31},popup)
local popupOwner,popupConnections=nil,{}
local function clearOptions()
 for _,c in ipairs(popupConnections) do c:Disconnect() end
 table.clear(popupConnections)
 for _,child in ipairs(popupList:GetChildren()) do child:Destroy() end
end
local function closePopup()
 popup.Visible=false;popupOwner=nil;clearOptions()
end
local drawOptions
local function refreshPlayerOptions(c)
 if c.originalTitle~="送蛋目标" then return end
 local values={}
 for _,p in ipairs(Players:GetPlayers()) do if p~=player then table.insert(values,p.Name) end end
 c.handle:Refresh(values,false)
end
local function openPopup(c)
 closePopup();popupOwner=c;refreshPlayerOptions(c)
 popupTitle.Text=c.item.label;popupSearch.Text="";popup.Visible=true
 popupList.CanvasPosition=Vector2.zero;drawOptions()
end
drawOptions=function()
 clearOptions()
 local c=popupOwner;if not c then return end
 local q=string.lower(popupSearch.Text);local n=0
 local function option(text,value)
  local b=button(popupList,"Option"..n,0,n*43,551,37,8);b.ZIndex=32
  b.BackgroundTransparency=0;b.BackgroundColor3=rgb(value==c.value and "#713175" or P.panel)
  label(b,"Label",text,12,0,526,37,15,P.white,false,33)
  popupConnections[#popupConnections+1]=b.Activated:Connect(function()
   if c.busy then return end
   c.value=value;c.valueLabel.Text=value or "请选择";closePopup();invoke(c,value)
  end)
  n=n+1
 end
 if c.options.AllowNone then option("清除选择",nil) end
 for _,value in ipairs(c.values) do
  if string.find(string.lower(tostring(value)),q,1,true) then option(tostring(value),value) end
 end
 if n==0 then label(popupList,"EmptyOptions","没有可选项，请稍后刷新",12,0,520,44,16,P.pearl,false,33);n=1 end
 popupList.CanvasSize=UDim2.fromOffset(0,n*43)
end
connect(popupClose.Activated,closePopup)
connect(popupSearch:GetPropertyChangedSignal("Text"),drawOptions)
connect(shell:GetPropertyChangedSignal("Visible"),function() if not shell.Visible then closePopup() end end)
local activeSlider,sliderInput=nil,nil
local function sliderAt(c,x)
 local low,high=c.options.Value.Min,c.options.Value.Max
 local a=math.clamp((x-c.slider.AbsolutePosition.X)/math.max(1,c.slider.AbsoluteSize.X),0,1)
 local step=10^(c.options.Value.Precision or 0)
 local value=math.clamp(math.floor((low+(high-low)*a)*step+.5)/step,low,high)
 if value==c.value then return end
 c.value=value;c.valueLabel.Text=tostring(value)
 c.fill.Size=UDim2.fromScale((value-low)/math.max(1,high-low),1)
 c.thumb.Position=UDim2.fromScale((value-low)/math.max(1,high-low),.5)
 invoke(c,value)
end
connect(UserInputService.InputChanged,function(input)
 if activeSlider and (input==sliderInput or (sliderInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)) then sliderAt(activeSlider,input.Position.X) end
end)
connect(UserInputService.InputEnded,function(input)
 if activeSlider and (input==sliderInput or input.UserInputType==Enum.UserInputType.MouseButton1) then activeSlider=nil;sliderInput=nil end
end)
connect(UserInputService.WindowFocusReleased,function() activeSlider=nil;sliderInput=nil end)
local function addControl(tab,kind,options)
 options=options or {}
 local originalTitle=options.Title or ""
 local title=displayNames[originalTitle] or originalTitle
 local height=(kind=="Section" and 30) or (kind=="Divider" and 4) or ((kind=="Input" or kind=="Dropdown" or kind=="Slider") and 92) or 64
 local b=button(scroll,kind.."_"..(#cards+1),4,4,566,height,11)
 local fill=gradient(b,{{0,"#4B1B50"},{.6,"#2A103F"},{1,"#5A2572"}},15)
 b.BackgroundTransparency=.01;b.BackgroundColor3=WHITE
 local edge=stroke(b,P.pearl,1,.6)
 local c={button=b,item={id=tostring(#cards+1),label=title,category=tab.id},originalTitle=originalTitle,kind=kind,options=options,edge=edge,fill=fill,y=4,height=height,hover=false,sweep=2,busy=false}
 cards[#cards+1]=c;b:SetAttribute("ControlType",kind);b:SetAttribute("OriginalTitle",originalTitle)
 local handle={};c.handle=handle
 if kind=="Divider" then
  b.BackgroundTransparency=1;edge.Transparency=1
  frame(b,"Rule",12,1,540,1,P.pearl,nil,6,.75)
 elseif kind=="Section" then
  b.BackgroundTransparency=1;edge.Transparency=1
  label(b,"SectionTitle",title,12,0,530,30,13,P.pearl,true)
 else
  local name=label(b,"FeatureName",title,16,0,kind=="Toggle" and 350 or 530,kind=="Toggle" and height or 40,16,P.white,true)
  name.TextTruncate=Enum.TextTruncate.AtEnd
  if kind=="Toggle" then
   c.value=options.Value==true
   c.state=label(b,"State","已关闭",382,0,82,height,12,P.pearl)
   c.track=frame(b,"Switch",482,19,50,26,"#5A3565",13,6)
   c.knob=frame(c.track,"Knob",3,3,20,20,P.white,10,7)
   syncToggle(c)
   connect(b.Activated,function()
    if not popup.Visible and not c.busy then c.value=not c.value;invoke(c,c.value) end
   end)
  elseif kind=="Button" then
   name.Size=UDim2.fromOffset(415,height)
   c.state=label(b,"State","执行 ›",452,0,102,height,13,P.pearl)
   connect(b.Activated,function()
    if popup.Visible then return end
    gui:SetAttribute("SelectedFeature",title);actionEvent:Fire(title);invoke(c)
   end)
  elseif kind=="Input" then
   local box=make("TextBox",{Name="Value",Position=UDim2.fromOffset(16,43),Size=UDim2.fromOffset(532,37),BackgroundColor3=rgb(P.base),BorderSizePixel=0,Text=tostring(options.Value or ""),PlaceholderText=options.Placeholder or "请输入",ClearTextOnFocus=options.ClearTextOnFocus==true,TextColor3=rgb(P.white),PlaceholderColor3=rgb(P.pearl),TextSize=26,Font=Enum.Font.Gotham,ZIndex=7},b)
   corner(box,7)
   connect(box.FocusLost,function() invoke(c,box.Text) end)
  elseif kind=="Dropdown" then
   c.values=table.clone(options.Values or {});c.value=options.Value
   c.valueLabel=label(b,"Value",c.value or "请选择",16,41,494,40,15,P.pearl)
   c.valueLabel.TextTruncate=Enum.TextTruncate.AtEnd
   label(b,"Arrow","⌄",520,41,26,40,20,P.pearl)
   function handle:Refresh(values,clear)
    c.values=table.clone(values or {})
    if clear or (c.value~=nil and not table.find(c.values,c.value)) then
     c.value=nil;c.valueLabel.Text="请选择";invoke(c,nil)
    end
    if popupOwner==c then drawOptions() end
   end
   connect(b.Activated,function() if not c.busy then openPopup(c) end end)
  elseif kind=="Slider" then
   local v=options.Value;c.value=v.Default
   name.Size=UDim2.fromOffset(440,40)
   c.valueLabel=label(b,"Value",tostring(c.value),480,0,70,40,16,P.pearl,true)
   c.slider=button(b,"Slider",20,45,526,34,0);c.slider.ZIndex=7
   local track=frame(c.slider,"Track",0,14,526,6,"#5A3565",3,7)
   c.fill=frame(track,"Fill",0,0,0,6,P.pink,3,8)
   local a=(c.value-v.Min)/math.max(1,v.Max-v.Min)
   c.fill.Size=UDim2.fromScale(a,1)
   c.thumb=frame(track,"Thumb",0,0,18,18,P.white,9,9);c.thumb.AnchorPoint=Vector2.new(.5,.5);c.thumb.Position=UDim2.fromScale(a,.5)
   connect(c.slider.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
     activeSlider=c;sliderInput=input;sliderAt(c,input.Position.X)
    end
   end)
  end
  connect(b.MouseEnter,function() tween(edge,{Transparency=.15},.16) end)
  connect(b.MouseLeave,function() tween(edge,{Transparency=(kind=="Toggle" and c.value) and .12 or .6},.16) end)
 end
 filterCards(false)
 return handle
end
local tabCount=0
function adapter:CreateWindow(options)
 shell.Title.Text="JBS 力量传奇"
 shell.Tribe.Text=""
 shell.Tribe.Visible=false
 return window
end
function window:Tab(options)
 tabCount=tabCount+1;local nav=scene.navigation[tabCount]
 assert(nav,"界面页面数量超出配置")
 local tab={id=nav.id}
 for _,kind in ipairs({"Input","Toggle","Button","Dropdown","Slider","Section","Divider"}) do
  tab[kind]=function(self,opts) return addControl(self,kind,opts) end
 end
 return tab
end
for i,m in ipairs(menuButtons) do
 connect(m.button.Activated,function()
  closePopup();activeSlider=nil;sliderInput=nil
  category=m.item.id;gui:SetAttribute("SelectedPage",category);pageTitle.Text=m.item.label
  tween(selection,{Position=UDim2.fromOffset(8,90+(i-1)*72)},.28)
  for _,other in ipairs(menuButtons) do other.title.TextColor3=rgb(other==m and P.white or P.pearl) end
  filterCards(true)
 end)
end
connect(search:GetPropertyChangedSignal("Text"),function() filterCards(true) end)
local function updatePlayerOptions()
 for _,c in ipairs(cards) do if c.kind=="Dropdown" and c.originalTitle=="送蛋目标" then refreshPlayerOptions(c) end end
end
connect(Players.PlayerAdded,updatePlayerOptions)
connect(Players.PlayerRemoving,function() task.defer(updatePlayerOptions) end)
connect(gui.Destroying,clearOptions)

local elapsed,acc=0,0
local visible=true
local animation
local function render(t,dt)
 local pointer=UserInputService:GetMouseLocation()
 local mx=math.clamp((pointer.X-content.AbsolutePosition.X)/math.max(1,content.AbsoluteSize.X),0,1)
 local angle=28+(mx-.5)*20
 contentMetal.Rotation=angle+math.sin(t*.3)*8
 contentMetal.Offset=Vector2.new(math.sin(t*.22)*.12,0)
 shellMetal.Rotation=30+math.sin(t*.25)*10
 rimGradient.Rotation=(t*40)%360
 rimGradient.Offset=Vector2.new(math.sin(t*.7)*.35,math.cos(t*.7)*.35)
 logoGradient.Offset=Vector2.new(math.sin(t*.8)*.65,0)
 sideLogoGradient.Offset=Vector2.new(math.sin(t*.5)*.45,0)
 for _,g in ipairs(glyphs) do
  local beam=(t/7.2%1)*(g.width+619*.52+330)-180
  local d=(g.x+g.y*(.48+(mx-.5)*.12))-beam
  local light=math.exp(-((d/63)^2))
  local narrow=math.exp(-((d/16)^2))
  g.object.TextTransparency=1-math.min(1,g.base+light*.3+narrow*.32)
  g.object.TextColor3= d<0 and rgb(P.pink):Lerp(WHITE,1-light*.35) or rgb(P.pearl):Lerp(WHITE,1-light*.4)
 end
 for _,s in ipairs(stars) do s.object.BackgroundTransparency=.35+.6*(.5+.5*math.sin(t*(.8+s.phase*.03)+s.phase)) end
 pingAccum=pingAccum+dt -- Ping 小窗每 0.5s 刷新一次(与主窗口动画同生命周期，窗口隐藏时自动暂停)
 if pingAccum>=.5 then pingAccum=0 updatePing() end
 for _,c in ipairs(cards) do
  if c.sweep<1.2 and c.hover and c.button.Visible then c.sweep=c.sweep+dt*3;c.shine.Offset=Vector2.new(c.sweep,0) end
 end
 for _,c in ipairs(cards) do syncToggle(c) end
end
local function stop()
 if animation then animation:Disconnect();animation=nil end
 for t in pairs(tweens) do t:Cancel() end
 table.clear(tweens)
 for object in pairs(temporaries) do object:Destroy() end
 table.clear(temporaries)
 shell.Position=UDim2.fromOffset(0,0)
 list.Position=UDim2.fromOffset(22,116)
 for i,m in ipairs(menuButtons) do if m.item.id==category then selection.Position=UDim2.fromOffset(8,90+(i-1)*72) end end
 for _,c in ipairs(cards) do c.button.Position=UDim2.fromOffset(4,c.y) end
end
local function start()
 if animation or destroyed or not visible or not gui.Enabled then return end
 animation=RunService.RenderStepped:Connect(function(dt)
  acc=acc+dt
  if acc<1/15 then return end
  local step=acc;acc=0;elapsed=elapsed+step;render(elapsed,step)
 end)
end
local function reveal()
 visible=true;shell.Visible=true;restore.Visible=false;elapsed=0;acc=0
 for _,g in ipairs(glows) do g.object.Visible=true end
 shell.Position=UDim2.fromOffset(0,20)
 tween(shell,{Position=UDim2.fromOffset(0,0)},.7)
 list.Position=UDim2.fromOffset(22,128);tween(list,{Position=UDim2.fromOffset(22,116),},.5,.3)
 start()
end
local function hide()
 closePopup();activeSlider=nil;sliderInput=nil
 visible=false;stop();shell.Visible=false;restore.Visible=true;notice.Visible=false
 for _,g in ipairs(glows) do g.object.Visible=false end
end
connect(minimize.Activated,hide) -- — 缩小：收起为悬浮按钮
connect(close.Activated,function() setConfirm(true) end) -- × 关闭：先弹确认框，「确定关闭」才销毁界面
connect(restore.Activated,function() if restoreMoved then restoreMoved=false return end reveal() end) -- 拖动结束的释放不触发展开
connect(expand.Activated,function() expanded=not expanded;fit() end)
connect(gui:GetPropertyChangedSignal("Enabled"),function() if gui.Enabled then start() else stop() end end)
connect(UserInputService.WindowFocusReleased,stop)
connect(UserInputService.WindowFocused,start)
connect(shell:GetPropertyChangedSignal("Visible"),function() if shell.Visible and visible then start() else stop() end end)
connect(gui.Destroying,function()
 endSession()
 destroyed=true;stop()
 for _,c in ipairs(connections) do c:Disconnect() end
end)
local showEvent=make("BindableEvent",{Name="ShowWindow"},gui)
connect(showEvent.Event,reveal)
gui:SetAttribute("SelectedPage","main")
filterCards(false);render(0,0);reveal()

function adapter:Show() if not destroyed then reveal() end end
function adapter:Destroy() if not destroyed then gui:Destroy() end end
function adapter:IsAlive() return not destroyed and gui.Parent~=nil end
function adapter:SetOnClosed(fn) onClosedHandler=fn end -- 确认关闭后通知 Library 重置会话状态
return adapter

end
function Library:CreateWindow(options)
 if instance and instance:IsAlive() then instance:Show();return window end
 if self.GameState=="running" or self.GameState=="failed" then error("JBS 界面已失效，请重新进入游戏，避免重复功能循环",0) end
 checkLegacy()
 local before=currentGui():FindFirstChild("JBS_Metal_v31")
 local ok,result=pcall(createRenderer)
 if not ok then
  local gui=currentGui():FindFirstChild("JBS_Metal_v31")
  if gui and gui~=before and gui:GetAttribute("JBSLibraryVersion")=="3.2" then gui:Destroy() end
  error(result,0)
 end
 instance=result
 -- 确认关闭(×)后的会话重置：功能线程由 _G.__JBS_shutdown_hook 停止，这里把库状态放回 idle
 -- 效果：关闭后无需重进服务器，重新执行本文件即可完整重建窗口与功能
 if instance.SetOnClosed then
  instance:SetOnClosed(function()
   self.GameState="idle"
   instance=nil;window=nil
  end)
 end
 window=instance:CreateWindow(options or {})
 for _,message in ipairs(self.PendingNotifications or {}) do instance:Notify(message) end
 self.PendingNotifications=nil
 return window
end
function Library:Notify(options)
 if instance and instance:IsAlive() then return instance:Notify(options) end
 self.PendingNotifications=self.PendingNotifications or {}
 self.PendingNotifications[#self.PendingNotifications+1]=options
end
function Library:Show()
 if instance and instance:IsAlive() then instance:Show() end
end
function Library:Destroy()
 assert(self.GameState=="idle","游戏功能仍属于当前会话，请重新进入游戏后换版；不能只销毁 UI 再重复初始化功能")
 if instance then instance:Destroy() end
 instance=nil;window=nil
end
function Library:BeginGame()
 if self.GameState=="running" then
  assert(instance and instance:IsAlive(),"JBS 界面已失效，请重新进入游戏，避免重复功能循环")
  self:Show();return false,"already-running"
 end
 if self.GameState=="starting" or self.GameState=="checking" then return false,"already-starting" end
 assert(self.GameState~="failed","JBS 上次启动未完成，请重新进入游戏后重试")
 -- Reserve before any WaitForChild yield to prevent two concurrent launchers.
 self.GameState="checking"
 local ok,err=pcall(function()
  -- Keep the old flag check active before the new game writes its own flags.
  local conflict=legacyConflict()
  if not conflict then
   for _,key in ipairs({"auto_train","auto_rebirth","auto_wheel","auto_petbuy","auto_packrebirth","auto_eategg","auto_fasttrain","auto_boss"}) do
    if rawget(_G,key)~=nil then conflict="旧版 JBS 功能状态";break end
   end
  end
  assert(not conflict,"检测到旧 JBS（"..tostring(conflict).."）。请重新进入游戏，仅运行新版启动文件。")
 end)
 if not ok then self.GameState="idle";error(err,0) end
 self.GameState="starting"
 self.Session=(self.Session or 0)+1
 return true
end
function Library:FinishGame(ok,err,generation)
 if self.GameState~="starting" or self.Session~=generation then return end
 self.GameState=ok and "running" or "failed"
 self.LastError=ok and nil or tostring(err)
end
environment[KEY]=Library
return Library

end
local function loadGame()
-- Game module v3.2: returns a function accepting JBS_UI; no UI/network loader here.
return function(WindUI)
 assert(type(WindUI)=="table" and WindUI.Version=="3.2" and type(WindUI.BeginGame)=="function","请传入 JBS_UI v3.2 库，不要再加载旧 WindUI")
 local proceed,reason=WindUI:BeginGame()
 if not proceed then return WindUI,reason end
 local launchGeneration=WindUI.Session
 local function runOriginalGame()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

-- ==================== 原生通知（不依赖UI库） ====================
local function notify(title, text, dur)
        pcall(function()
                StarterGui:SetCore("SendNotification", {
                        Title = title,
                        Text = text,
                        Duration = dur or 5,
                })
        end)
end

-- ==================== 主保护 ====================
local okMain, errMain = pcall(function()

-- ==================== 游戏对象（带超时） ====================
local rEvents,rebirthRemote,muscleEvent,leaderstats,rebirths,strengthStat
do
 local deadline=os.clock()+12
 repeat
  rEvents=ReplicatedStorage:FindFirstChild("rEvents")
  rebirthRemote=rEvents and rEvents:FindFirstChild("rebirthRemote")
  muscleEvent=player:FindFirstChild("muscleEvent")
  leaderstats=player:FindFirstChild("leaderstats")
  rebirths=leaderstats and leaderstats:FindFirstChild("Rebirths")
  strengthStat=leaderstats and leaderstats:FindFirstChild("Strength")
  if rEvents and rebirthRemote and muscleEvent and strengthStat and rebirths then break end
  task.wait(0.05)
 until os.clock()>=deadline
end

-- 沿用输入脚本的重生门槛估算；未获服务端公式确认。
local function calculateRequiredStrength()
        local stats = player:FindFirstChild("leaderstats")
        local rb = stats and stats:FindFirstChild("Rebirths")
        local rebirthCount = rb and rb.Value or 0
        local baseRequired = 10000 + 5000 * rebirthCount
        return math.max(1, math.floor(baseRequired * 0.5))
end

-- ==================== 重生请求：多协议自动试探引擎 ====================
-- 沿用输入脚本的候选命令与通道；当前尚未在目标服务器确认协议。
-- 观察到重生数增长时暂时复用该候选，这只是相关性，不能证明命令唯一有效。
local rebirthCallVariants = {
        { "rebirthRemote", "rebirthRequest" },
        { "rebirthRemote", "rebirth" },
        { "rebirthRemote" },
        { "rebirthRemote", "Rebirth" },
        { "rebirthRemote", "buyRebirth" },
        { "rebirthRemote", "requestRebirth" },
        { "rebirthRemote", "doRebirth" },
        { "muscleEvent", "rebirth" },
        { "muscleEvent", "rebirthRequest" },
}
local sessionAlive=true
local performanceConnections={}
local function perfConnect(signal,callback)
 local c=signal:Connect(callback);performanceConnections[#performanceConnections+1]=c;return c
end
local function safeUiRoot()
 if type(gethui)=="function" then
  local ok,r=pcall(gethui)
  if ok and r then local valid,isInstance=pcall(function() return r:IsA("Instance") end);if valid and isInstance then return r end end
 end
 local root=player:WaitForChild("PlayerGui",12);assert(root,"PlayerGui尚未就绪，请重新执行");return root
end
local options={}
local sharedEnvironment=_G
do
 local ok,env=pcall(function() return type(getgenv)=="function" and getgenv() or _G end)
 if not ok or type(env)~="table" then env=_G end
 sharedEnvironment=env
 if type(env.JBS_EXTREME_CONFIG)=="table" then options=env.JBS_EXTREME_CONFIG end
end
local pingSeconds=0
local refsDirty,nextRefRefresh=true,0
local character,humanoid,characterRoot
local valueBindings,rootBindings,inventoryBindings={},{},{}
local petVersion=0
local function disconnectGroup(group)
 for k,c in pairs(group) do c:Disconnect();group[k]=nil end
end
local function referenceEvent(group,key,signal,callback)
 if group[key] then group[key]:Disconnect() end
 group[key]=signal:Connect(callback)
end
local leaseKey="__JBSRemoteLeasesR3"
if type(sharedEnvironment[leaseKey])~="table" then sharedEnvironment[leaseKey]={} end
local Perf=createJBSPerformance({clock=os.clock,spawn=task.spawn,cancel=task.cancel,wait=task.wait,leases=sharedEnvironment[leaseKey],
 variants=rebirthCallVariants,ping=function() return pingSeconds end,
 remote=function(channel) if channel=="rebirthRemote" then return rebirthRemote end;return muscleEvent end})
local r2={startedAt=os.clock(),inventoryVersion=0,slotSource="原版兼容值12",statSource="原版宠物数值表",equipmentSource=nil,
 packLastError=nil,plans={},stateVersion=0}
local standalonePingItem
local function standalonePing()
 local ok,value=pcall(function()
  standalonePingItem=standalonePingItem or game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
  return standalonePingItem:GetValue()/1000
 end)
 if ok and type(value)=="number" and value>0 then return value end
 standalonePingItem=nil;return pingSeconds
end
local StandaloneFast=createJBSStandaloneFast({clock=os.clock,settings=options.fastTraining,
 ping=standalonePing,
 active=function() return sessionAlive and not Perf.stopped and _G.auto_fasttrain==true end,
 sent=function(count) Perf.total+=count;Perf.repTotal+=count end})
local workerFlags={normal="auto_train",fast="auto_fasttrain",rebirth="auto_rebirth",wheel="auto_wheel",petbuy="auto_petbuy",egg="auto_eategg",pack="auto_packrebirth",bossrb="auto_bossrebirth"}
local workerEpochs,workerOwners={},setmetatable({},{__mode="k"})
function r2.currentWorker() local owner=workerOwners[coroutine.running()];return owner and owner.feature end
function r2.invalidate(feature) workerEpochs[feature]=(workerEpochs[feature] or 0)+1 end
function r2.owns(feature)
 if not sessionAlive then return false end
 local owner=workerOwners[coroutine.running()]
 return not owner or owner.feature~=feature or owner.epoch==(workerEpochs[feature] or 0)
end
function r2.active(feature)
 return r2.owns(feature) and (not workerFlags[feature] or _G[workerFlags[feature]]==true)
end
function r2.startWorker(feature,fn)
 if not sessionAlive then return nil end
 r2.invalidate(feature);local epoch=workerEpochs[feature]
 return task.spawn(function()
  local co=coroutine.running();workerOwners[co]={feature=feature,epoch=epoch}
  local ok,e=xpcall(fn,function(err) return tostring(err) end)
  if not ok and sessionAlive and workerEpochs[feature]==epoch then
   if workerFlags[feature] then _G[workerFlags[feature]]=false end
   Perf.lastError=e
   if feature=="bossrb" and _G.__JBS_bossrb_stop then _G.__JBS_bossrb_stop() end
   WindUI:Notify({Title="功能已停止",Content=e.."；可复制运行诊断",Duration=6})
  end
  workerOwners[co]=nil
 end)
end
local function markDirty() if sessionAlive then refsDirty=true;r2.stateVersion+=1 end end
local function petDirty() petVersion+=1;r2.inventoryVersion+=1;r2.stateVersion+=1;r2.plans={} end
local function equipmentDirty()
 petVersion+=1;r2.stateVersion+=1
 if not _G.auto_packrebirth then Perf:Retest() end
end
_G.__JBS_boot_cleanup=function()
 sessionAlive=false;Perf:Stop()
 disconnectGroup(valueBindings);disconnectGroup(rootBindings);disconnectGroup(inventoryBindings)
 for _,c in pairs(performanceConnections) do c:Disconnect() end
 table.clear(performanceConnections)
 if r2.releaseBody then r2.releaseBody() end
 if r2.cancelPrompts then r2.cancelPrompts() end
 _G.__JBS_boot_cleanup=nil
end
local function bindValue(kind,obj)
 local old=valueBindings[kind]
 if old and old.object==obj then return end
 if old then old:Disconnect();valueBindings[kind]=nil end
 Perf:ForgetValue(kind)
 if not obj then return end
 local function observed()
  if sessionAlive and obj.Parent then Perf:ObserveValue(kind,obj.Value,obj);r2.stateVersion+=1 end
 end
 observed()
 local c=obj.Changed:Connect(function(value)
  if sessionAlive and obj.Parent and type(value)=="number" then
   Perf:ObserveValue(kind,value,obj);r2.stateVersion+=1
  else observed() end
 end)
 valueBindings[kind]={object=obj,Disconnect=function() c:Disconnect() end}
end
local boundStats,boundEvents,boundInventory,boundCharacter
local function numericStat(name)
 local obj=leaderstats and leaderstats:FindFirstChild(name)
 if obj and (obj:IsA("IntValue") or obj:IsA("NumberValue")) then return obj end
end
local function watchInventory(folder)
 if boundInventory==folder and not r2.rebindPets then return end
 disconnectGroup(inventoryBindings);boundInventory=folder;r2.rebindPets=false;petDirty()
 if not folder then return end
 local function inventoryChanged() r2.rebindPets=true;markDirty();petDirty() end
 referenceEvent(inventoryBindings,"added",folder.DescendantAdded,inventoryChanged)
 referenceEvent(inventoryBindings,"removed",folder.DescendantRemoving,inventoryChanged)
 for _,sub in ipairs(folder:GetChildren()) do
  if sub:IsA("Folder") then
   for _,pet in ipairs(sub:GetChildren()) do
    referenceEvent(inventoryBindings,pet,pet.AttributeChanged,function(name)
     if name=="Equipped" or name=="equipped" or name=="IsEquipped" or name=="isEquipped" then equipmentDirty() else petDirty() end
    end)
    for _,v in ipairs(pet:GetChildren()) do
     if v:IsA("BoolValue") or v:IsA("NumberValue") or v:IsA("IntValue") then
      referenceEvent(inventoryBindings,v,v:GetPropertyChangedSignal("Value"),v:IsA("BoolValue") and equipmentDirty or petDirty)
     end
    end
   end
  end
 end
end
local function refreshReferences(force)
 local t=os.clock()
 if force or refsDirty or t>=nextRefRefresh then
  refsDirty=false;nextRefRefresh=t+1
  rEvents=ReplicatedStorage:FindFirstChild("rEvents")
  muscleEvent=player:FindFirstChild("muscleEvent")
  leaderstats=player:FindFirstChild("leaderstats")
  strengthStat=numericStat("Strength")
  rebirths=numericStat("Rebirths")
  rebirthRemote=rEvents and rEvents:FindFirstChild("rebirthRemote")
  bindValue("strength",strengthStat);bindValue("rebirth",rebirths)
  bindValue("durability",numericStat("Durability") or numericStat("durability"))
  if boundStats~=leaderstats then
   boundStats=leaderstats
   if rootBindings.statsAdded then rootBindings.statsAdded:Disconnect();rootBindings.statsAdded=nil end
   if rootBindings.statsRemoved then rootBindings.statsRemoved:Disconnect();rootBindings.statsRemoved=nil end
   if leaderstats then
    referenceEvent(rootBindings,"statsAdded",leaderstats.ChildAdded,markDirty)
    referenceEvent(rootBindings,"statsRemoved",leaderstats.ChildRemoved,markDirty)
   end
  end
  if boundEvents~=rEvents then
   boundEvents=rEvents
   if rootBindings.remoteAdded then rootBindings.remoteAdded:Disconnect();rootBindings.remoteAdded=nil end
   if rootBindings.remoteRemoved then rootBindings.remoteRemoved:Disconnect();rootBindings.remoteRemoved=nil end
   if rEvents then
    referenceEvent(rootBindings,"remoteAdded",rEvents.ChildAdded,markDirty)
    referenceEvent(rootBindings,"remoteRemoved",rEvents.ChildRemoved,markDirty)
   end
  end
  watchInventory(player:FindFirstChild("petsFolder"))
 end
 if character~=player.Character or not humanoid or not humanoid.Parent or not characterRoot or not characterRoot.Parent then
  character=player.Character
  humanoid=character and character:FindFirstChildOfClass("Humanoid")
  characterRoot=character and character:FindFirstChild("HumanoidRootPart")
 end
 if boundCharacter~=character then
  boundCharacter=character;r2.actorDirty=true
  if rootBindings.actorAdded then rootBindings.actorAdded:Disconnect();rootBindings.actorAdded=nil end
  if rootBindings.actorRemoved then rootBindings.actorRemoved:Disconnect();rootBindings.actorRemoved=nil end
  if character then
   local function actorDirty() r2.actorDirty=true end
   referenceEvent(rootBindings,"actorAdded",character.ChildAdded,actorDirty)
   referenceEvent(rootBindings,"actorRemoved",character.ChildRemoved,actorDirty)
  end
 end
end
local actorCache={}
function r2.actor()
 refreshReferences()
 if not character or not character:IsDescendantOf(workspace) or not humanoid or not humanoid.Parent or humanoid.Health<=0 or not characterRoot or not characterRoot.Parent then return nil end
 if actorCache.character~=character or r2.actorDirty or os.clock()>=(actorCache.next or 0) then
  actorCache.character=character;r2.actorDirty=false;actorCache.next=os.clock()+0.5
  actorCache.punch=character:FindFirstChild("Punch");actorCache.weight=character:FindFirstChild("Weight")
  actorCache.left=character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
  actorCache.right=character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
 end
 return character,characterRoot,humanoid,actorCache.punch,actorCache.left,actorCache.right,actorCache.weight
end
local heldBodies=setmetatable({},{__mode="k"})
function r2.holdBody(hum,root)
 if heldBodies[hum]==nil then heldBodies[hum]=hum.PlatformStand==true end
 if not hum.PlatformStand then hum.PlatformStand=true end
 if root.AssemblyLinearVelocity~=Vector3.zero then root.AssemblyLinearVelocity=Vector3.zero end
 if root.AssemblyAngularVelocity~=Vector3.zero then root.AssemblyAngularVelocity=Vector3.zero end
end
function r2.releaseBody()
 for hum,old in pairs(heldBodies) do if hum.Parent then pcall(function() hum.PlatformStand=old end) end;heldBodies[hum]=nil end
end
perfConnect(player.ChildAdded,markDirty);perfConnect(player.ChildRemoved,markDirty)
perfConnect(player:GetPropertyChangedSignal("Character"),markDirty)
perfConnect(player.AttributeChanged,function(name)
 if name=="MaxPetSlots" or name=="maxPetSlots" then petDirty() end
end)
perfConnect(ReplicatedStorage.ChildAdded,markDirty);perfConnect(ReplicatedStorage.ChildRemoved,markDirty)
local nextPing=0
local frameState={}
perfConnect(RunService.Heartbeat,function(dt)
 if not sessionAlive then return end
 refreshReferences()
 local t=os.clock()
 if t>=nextPing then nextPing=t+1;pcall(function() pingSeconds=game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end) end
 Perf:PollRebirth(rebirths and rebirths.Value)
 local mode="idle"
 local standaloneFast=false
 if _G.auto_packrebirth then mode=Perf.packTraining and "fast" or "paused"
 elseif t<Perf.combatUntil and r2.currentHitbox and r2.currentHitbox.Parent and r2.currentHitbox:IsDescendantOf(workspace) then mode="combat"
 elseif Perf.bossActive then mode=Perf.bossTraining and "fast" or "paused"
 elseif _G.auto_fasttrain then mode="idle";standaloneFast=true
 elseif _G.auto_train then mode="normal" end
 frameState.mode=mode;frameState.remote=muscleEvent;frameState.character=character;frameState.stat=strengthStat
 frameState.strength=strengthStat and strengthStat.Value;frameState.rebirth=rebirths and rebirths.Value
 frameState.alive=humanoid and humanoid.Parent and humanoid.Health>0 and characterRoot and characterRoot.Parent and character and character:IsDescendantOf(workspace)
 frameState.profileKey=r2.farmingProfile or "unconfigured"
 Perf:Step(dt,frameState)
 if standaloneFast then
  StandaloneFast:Step(dt,frameState)
  Perf.rate=StandaloneFast.rate;Perf.gainRate=StandaloneFast.gainRate;Perf.status=StandaloneFast.status
  if StandaloneFast.lastError then Perf.lastError=StandaloneFast.lastError end
 else StandaloneFast:Pause() end
end)
local function stopR2Runtime()
 for feature in pairs(workerEpochs) do r2.invalidate(feature) end
 if r2.cancelPrompts then r2.cancelPrompts() end
 r2.releaseBody()
 disconnectGroup(valueBindings);disconnectGroup(rootBindings);disconnectGroup(inventoryBindings)
end

-- One initial workspace index; subsequent repair is confined to the two game subtrees.
local indexed=false
local promptIndex,bossIndex,chestIndex={},{},{}
local nextSceneAudit=0
function r2.validNode(d,class)
 return d and d.Parent and (not class or d:IsA(class)) and d:IsDescendantOf(workspace)
end
local function addSceneObject(d)
 if d:IsA("ProximityPrompt") then promptIndex[d]=true
 elseif d:IsA("BasePart") then
  if d.Name=="BossDamageHitbox" then bossIndex[d]=true end
  local p=d.Parent
  while p and p~=workspace do if p.Name=="BossChest" then chestIndex[d]=true;break end;p=p.Parent end
 end
end
local function ensureSceneIndex()
 if indexed then return end
 indexed=true
 perfConnect(workspace.DescendantAdded,addSceneObject)
 perfConnect(workspace.DescendantRemoving,function(d) promptIndex[d]=nil;bossIndex[d]=nil;chestIndex[d]=nil end)
 for _,d in ipairs(workspace:GetDescendants()) do addSceneObject(d) end
end
local function repairSceneIndex()
 ensureSceneIndex()
 local t=os.clock();if t<nextSceneAudit then return end;nextSceneAudit=t+1
 local events=workspace:FindFirstChild("Events");local arena=events and events:FindFirstChild("BossArena")
 local chest=workspace:FindFirstChild("BossChest")
 for d in pairs(bossIndex) do if not r2.validNode(d,"BasePart") or d.Name~="BossDamageHitbox" or not arena or not d:IsDescendantOf(arena) then bossIndex[d]=nil end end
 for d in pairs(chestIndex) do if not r2.validNode(d,"BasePart") or not chest or not d:IsDescendantOf(chest) then chestIndex[d]=nil end end
 if arena then for _,d in ipairs(arena:GetDescendants()) do addSceneObject(d) end end
 if chest then addSceneObject(chest);for _,d in ipairs(chest:GetDescendants()) do addSceneObject(d) end end
end
local function indexedBoss()
 repairSceneIndex()
 local events=workspace:FindFirstChild("Events");local arena=events and events:FindFirstChild("BossArena")
 if arena then for d in pairs(bossIndex) do if r2.validNode(d,"BasePart") and d.Name=="BossDamageHitbox" and d:IsDescendantOf(arena) then return d end end end
end
local function indexedChest()
 repairSceneIndex()
 local fallback
 for d in pairs(chestIndex) do if r2.validNode(d,"BasePart") then if d.Name=="CommonChest_Base" then return d end;fallback=d end end
 return fallback
end
local function promptPosition(prompt)
 if not r2.validNode(prompt,"ProximityPrompt") then return nil end
 local p=prompt.Parent
 if p:IsA("BasePart") then return p.Position end
 if p:IsA("Attachment") then return p.WorldPosition end
 if p:IsA("Model") then return p:GetPivot().Position end
end
local promptJobs={}
local promptGeneration=0
function r2.cancelPrompts()
 promptGeneration+=1
 for prompt,job in pairs(promptJobs) do
  job.cancelled=true
  if job.held then pcall(function() prompt:InputHoldEnd() end);job.held=false end
  if job.thread then pcall(task.cancel,job.thread) end
  promptJobs[prompt]=nil
 end
end
local function tryPrompt(prompt,await)
 if not sessionAlive or not r2.validNode(prompt,"ProximityPrompt") or not prompt.Enabled then return false end
 local job=promptJobs[prompt]
 if not job then
  local generation=promptGeneration
  job={done=false,held=false};promptJobs[prompt]=job
  job.thread=task.spawn(function()
   job.ok=pcall(function()
    if type(fireproximityprompt)=="function" then fireproximityprompt(prompt)
    else
     prompt:InputHoldBegin();job.held=true
     local finish=os.clock()+math.max(prompt.HoldDuration,0.05)
     while sessionAlive and not job.cancelled and promptGeneration==generation and r2.validNode(prompt) and prompt.Enabled and os.clock()<finish do task.wait(0.05) end
     if job.held then prompt:InputHoldEnd();job.held=false end
    end
   end)
   if job.held then pcall(function() prompt:InputHoldEnd() end);job.held=false end
   job.done=true
   if promptJobs[prompt]==job then promptJobs[prompt]=nil end
  end)
 elseif not await then return false end
 if await then while sessionAlive and not job.done and not job.cancelled do task.wait(0.05) end;return job.ok==true and not job.cancelled end
 return true
end
local function requestSize(_,value)
 local remote=rEvents and rEvents:FindFirstChild("changeSpeedSizeRemote")
 if remote then Perf:InvokeOnce(remote,"changeSize",value) end
end
local function stopBossModes()
 _G.auto_boss=false;_G.auto_bossrebirth=false
 if r2.stopPlainBoss then r2.stopPlainBoss() end
 if _G.__JBS_bossrb_stop then pcall(_G.__JBS_bossrb_stop) end
 r2.cancelPrompts();r2.releaseBody()
 Perf.bossActive=false;Perf.bossTraining=false;Perf.combatUntil=0;r2.currentHitbox=nil
end

local originalUI=WindUI
local WindUI=setmetatable({},{__index=originalUI})
function WindUI:Notify(o) if sessionAlive then return originalUI:Notify(o) end end
function WindUI:CreateWindow(o) return originalUI:CreateWindow(o) end
local rbTarget=0
local function fireRebirthAttempt(force)
 refreshReferences()
 if not sessionAlive or not strengthStat or not strengthStat.Parent or not rebirths or not rebirths.Parent then return false end
 if rbTarget>0 and rebirths.Value>=rbTarget then return false end
 if not r2.actor() then return false end
 return Perf:RequestRebirth(rebirths.Value,force or strengthStat.Value>=calculateRequiredStrength())
end

-- 宠物商店对象：rEvents.cPetShopRemote + shared.runtime.cPetShopFolder
local cPetShopRemote = rEvents and rEvents:FindFirstChild("cPetShopRemote")
local sharedFolder = ReplicatedStorage:FindFirstChild("shared")
local runtimeFolder = sharedFolder and sharedFolder:FindFirstChild("runtime")
local cPetShopFolder = runtimeFolder and runtimeFolder:FindFirstChild("cPetShopFolder")

task.spawn(function()
        task.wait(0.5)
        if not sessionAlive then return end
        local missing = {}
        if not rEvents then table.insert(missing, "rEvents") end
        if not rebirthRemote then table.insert(missing, "rebirthRemote") end
        if not muscleEvent then table.insert(missing, "muscleEvent") end
        if not cPetShopRemote or not cPetShopFolder then table.insert(missing, "宠物商店") end
        if #missing > 0 then
                WindUI:Notify({
                        Title = "部分功能不可用",
                        Content = "未找到: " .. table.concat(missing, ", "),
                        Duration = 8,
                })
        end
end)

-- ==================== 状态 ====================
_G.auto_train = false    -- 自动锻炼
_G.auto_rebirth = false  -- 自动重生
_G.auto_wheel = false    -- 自动轮盘
_G.auto_petbuy = false   -- 自动买宠物
_G.auto_packrebirth = false -- 换包重生
_G.auto_eategg = false    -- 自动吃蛋
_G.auto_fasttrain = false  -- 快速锻炼(极速自适应)
_G.auto_boss = false     -- 自动打Boss
_G.auto_bossrebirth = false
-- rbTarget declared above: shared by all rebirth modes
local giftAmount = 0     -- 送蛋数量(0=全部)

local trainThread, rebirthThread, wheelThread, petbuyThread
local packrebirthThread
local eateggThread
local fasttrainThread
local bossHoverConn
r2.stopPlainBoss=function()
 if bossHoverConn then bossHoverConn:Disconnect();bossHoverConn=nil end
 r2.cancelPrompts();r2.releaseBody();Perf.combatUntil=0;r2.currentHitbox=nil
end
local statsThread, giftThread

local function stop(t)
        if t then
                pcall(function() task.cancel(t) end)
        end
end

-- ==================== 关闭钩子（× 确认关闭时由 UI 层调用） ====================
-- 作用：彻底停止本会话全部功能线程与 Boss 心跳、解除 PlatformStand、清空功能标志
-- 效果：关闭后可在同一服务器内直接重新执行脚本，不会产生双重功能循环
_G.__JBS_shutdown_hook = function()
        _G.__JBS_boot_cleanup=nil
        _G.__JBS_shutdown_hook = nil -- 一次性：触发即自清
        sessionAlive=false
        stopR2Runtime()
        Perf:Stop()
        for _,c in pairs(performanceConnections) do c:Disconnect() end
        table.clear(performanceConnections)
        table.clear(promptIndex);table.clear(bossIndex);table.clear(chestIndex)
        for _, key in ipairs({ "auto_train", "auto_rebirth", "auto_wheel", "auto_petbuy",
                        "auto_packrebirth", "auto_eategg", "auto_fasttrain", "auto_boss", "auto_bossrebirth" }) do
                _G[key] = nil
        end
        for _, t in pairs({ trainThread, rebirthThread, wheelThread, petbuyThread,
                        packrebirthThread, eateggThread, fasttrainThread, statsThread, giftThread }) do
                if t then
                        pcall(function() task.cancel(t) end)
                end
        end
        if bossHoverConn then
                pcall(function() bossHoverConn:Disconnect() end)
                bossHoverConn = nil
        end
        -- 数据统计小窗随会话一起销毁，避免重执行后屏幕残留
        pcall(function()
                local parent = safeUiRoot()
                local g = parent and parent:FindFirstChild("JBSStatsPanel")
                if g then g:Destroy() end
        end)
        -- Boss重生引擎随会话停止并回收线程/连接（见换包重生页 Boss重生 开关）
        if _G.__JBS_bossrb_cleanup then pcall(_G.__JBS_bossrb_cleanup) end
        -- Boss战会锁住角色(PlatformStand)，关闭时解除，避免角色僵在原地
        r2.releaseBody()
end

-- ==================== 反挂机（双保险） ====================
local antiIdleConn = player.Idled:Connect(function()
        -- 方式1：按键模拟(部分执行器上更稳)
        pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.Y, false, game)
                task.wait(0.05)
                vim:SendKeyEvent(false, Enum.KeyCode.Y, false, game)
        end)
        if not sessionAlive then return end
        -- 方式2：鼠标模拟
        pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
end)
_G.__JBS_shutdown_hook = (function(oldHook) -- 在原钩子基础上追加：断开反挂机连接
        return function()
                if antiIdleConn then
                        pcall(function() antiIdleConn:Disconnect() end)
                        antiIdleConn = nil
                end
                if oldHook then oldHook() end
        end
end)(_G.__JBS_shutdown_hook)

-- ==================== 窗口 ====================
local Window = WindUI:CreateWindow({
        Title = "JBS 力量传奇",
        Author = "v3.1",
        Folder = "JBS_V3",
        Icon = "sparkles",
        IconThemed = true,
        Theme = "Midnight",
        Size = UDim2.fromOffset(560, 400),
        Transparent = false,
        Acrylic = false,
        SideBarWidth = 200,
        ScrollBarEnabled = true,
        HideSearchBar = false,
        Resizable = true,
})

local MainTab = Window:Tab({ Title = "主要", Icon = "zap", ShowTabTitle = true })
local TeleportTab = Window:Tab({ Title = "传送", Icon = "map-pin", ShowTabTitle = true })
local PetTab = Window:Tab({ Title = "宠物", Icon = "cat", ShowTabTitle = true })
local BossTab = Window:Tab({ Title = "Boss", Icon = "skull", ShowTabTitle = true })
local PackTab = Window:Tab({ Title = "换包重生", Icon = "refresh", ShowTabTitle = true })

-- ==================== 功能：自动锻炼 ====================
local function autoTrainLoop()
 -- The one shared Heartbeat worker reads the switch directly.
end

-- ==================== 功能：自动重生（可设目标次数） ====================
local function autoRebirthLoop()
 while r2.active("rebirth") do
  if rbTarget>0 and rebirths and rebirths.Value>=rbTarget then
   _G.auto_rebirth=false
   WindUI:Notify({Title="重生完成",Content="已达到目标次数 "..rbTarget,Duration=4})
   return
  end
  if not _G.auto_packrebirth and not Perf.bossActive then fireRebirthAttempt() end
  task.wait(0.05)
 end
end

-- ==================== 功能：自动轮盘（幸运抽奖） ====================
-- Managed utility calls. Completion means a local call returned, not that an item arrived.
local function autoWheelLoop()
 while r2.active("wheel") do
  refreshReferences()
  local remote=rEvents and rEvents:FindFirstChild("openFortuneWheelRemote")
  local shared=ReplicatedStorage:FindFirstChild("shared")
  local catalogs=shared and shared:FindFirstChild("catalogs")
  local chances=catalogs and catalogs:FindFirstChild("fortuneWheelChances")
  local wheel=chances and chances:FindFirstChild("Fortune Wheel")
  if remote and wheel then Perf:Call(remote,function() return r2.active("wheel") end,"openFortuneWheel",wheel) end
  task.wait(1)
 end
end


-- ==================== 功能：买宠物 ====================
-- 购买：cPetShopFolder:FindFirstChild(宠物名) -> cPetShopRemote:InvokeServer(宠物对象)
-- 反编译把参数丢成了FindFirstChild(nil)，此处用下拉选择的名字重建

-- 内置宠物/光环列表（动态读取失败时的兜底）
local FALLBACK_PETS = {
        "不稳定幻影", "以太仙灵小兔", "伏特爪", "冰波传奇企鹅", "反应堆兽",
        "地狱火", "地狱火龙", "大超新星", "幻影创世龙", "星界电光",
        "暗星猎人", "核心小狗", "橙色刺猬", "橙色飞马", "永恒巨型攻击",
        "永恒打击利维坦", "熵爆炸", "电光", "白色凤凰", "白色飞马",
        "等离子掠夺者", "紫色光环", "紫色新环", "紫色猎鹰", "紫色龙",
        "红色光环", "红色小猫", "红色火龙", "红色释火者", "终极超新星飞马",
        "绿色光环", "绿色蝴蝶", "绿色释火者", "肌肉之王", "肌肉老师",
        "能量闪电", "蓝色光环", "蓝色凤凰", "顶峰霸主", "魔法蝴蝶",
        "黄色光环", "黄色蝴蝶", "黄金维金人", "黑暗德古拉", "黑暗电光",
        "黑暗蝎尾怪传奇", "黑暗闪电", "黑暗风暴", "黑暗魔像",
}

-- 动态获取商店宠物列表（优先游戏内实时列表，失败回退内置列表）
local function getPetShopList()
        local names = {}
        pcall(function()
                local shared = ReplicatedStorage:FindFirstChild("shared")
                local runtime = shared and shared:FindFirstChild("runtime")
                local folder = runtime and runtime:FindFirstChild("cPetShopFolder")
                if folder then
                        for _, item in ipairs(folder:GetChildren()) do
                                table.insert(names, item.Name)
                        end
                end
        end)
        if #names == 0 then
                names = FALLBACK_PETS
        end
        table.sort(names)
        return names
end

-- 购买一只宠物，返回 成功标志, 提示信息
local function buyPet(name)
 if not sessionAlive then return false,"会话已关闭" end
 refreshReferences()
 local remote=rEvents and rEvents:FindFirstChild("cPetShopRemote")
 local shared=ReplicatedStorage:FindFirstChild("shared")
 local runtime=shared and shared:FindFirstChild("runtime")
 local folder=runtime and runtime:FindFirstChild("cPetShopFolder")
 if not remote or not folder then return false,"宠物商店尚未就绪" end
 if type(name)~="string" or name=="" then return false,"请先选择宠物" end
 local pet=folder:FindFirstChild(name);if not pet then return false,"商店里没有该宠物" end
 local ok,why=Perf:Call(remote,function()
  local owner=r2.currentWorker and r2.currentWorker()
  return sessionAlive and (owner~="petbuy" or r2.active("petbuy"))
 end,pet)
 if not ok then return false,tostring(why or "调用未完成") end
 return true,"购买调用已完成，到账待游戏确认："..name
end


-- 自动购买循环（每0.5秒一次）
local selectedPet = ""
local function autoPetBuyLoop()
        while r2.active("petbuy") do
                if selectedPet~="" then
                 local ok,why=buyPet(selectedPet)
                 if not ok and why=="服务器返回拒绝" then
                  _G.auto_petbuy=false
                  WindUI:Notify({Title="自动购买已停止",Content=why,Duration=4})
                 end
                end
                task.wait(0.5)
        end
end

-- ==================== 功能：自动打Boss（林玉自动击杀版，替换原多Boss轮换版） ====================
-- 机制：锁定Boss判定箱(BossDamageHitbox) -> 头顶绕圈贴脸输出
--       工具拳 + 双手firetouchinterest + muscleEvent三路齐发
--       自动维持体格 -> Boss死后传送到宝箱自动开 -> 等下一轮刷新
local bossHeight = 65      -- 头顶高度(判定箱上方格数)
local bossOrbitRadius = 5  -- 绕圈半径
local bossOrbitSpeed = 30  -- 绕圈速度(越大越快)
local bossTilt = true      -- 身体倾斜朝Boss
local bossPunchRate = 120  -- 每秒出拳次数(拉满)
local bossSizeVal = 2      -- 挂机期间保持的体格
local hitbox = nil         -- 当前锁定的Boss判定箱

-- 玩家muscleEvent(带回退重找)
local function getMuscleEvent()
        return muscleEvent or player:FindFirstChild("muscleEvent")
end

-- 触发附近交互(开宝箱/领奖励用)
local function interactNearby(myPos)
 ensureSceneIndex()
 local count=0
 for d in pairs(promptIndex) do
  if d.Parent and d.Enabled then
   local pos=promptPosition(d)
   if pos and (pos-myPos).Magnitude<=25 then
    if tryPrompt(d) then count+=1 end
   end
  end
 end
 return count
end

-- 销毁全图传送门(防止打Boss时被吸走)
local function destroyPortals()
        pcall(function()
                for _, obj in ipairs(game:GetDescendants()) do
                        if obj.Name == "RobloxForwardPortals" then
                                obj:Destroy()
                        end
                end
        end)
end

-- 刷新Boss判定箱：竞技场内任意含"Boss"名字的文件夹下的BossDamageHitbox
local function refreshHitbox() hitbox=indexedBoss() end
local function findChest() return indexedChest() end

-- 主循环：心跳驱动(开启时连接，关闭时断开)
local function startBossLoop()
        local me = getMuscleEvent()
        local sr = rEvents and rEvents:FindFirstChild("changeSpeedSizeRemote")
        local ang = 0
        local lastSz = 0
        local cacheT = 0
        local lastToolActivation=0
        local lastTouch=0
        local lastPrompt = 0
        local promptCount = 0

        local function bossTick(dt)
                if not _G.auto_boss then return end

                local ch,root,hum,tool,lh,rh=r2.actor()
                if not ch then return end

                local t = tick()
                if t - lastSz >= 1 then
                        lastSz = t
                        requestSize(sr,bossSizeVal)
                end

                -- 判定箱销毁立即清引用，每0.5秒重新扫描
                if hitbox and not r2.validNode(hitbox,"BasePart") then
                        hitbox = nil
                end
                if t - cacheT >= 0.2 then
                        cacheT = t
                        refreshHitbox()
                end

                if tool and r2.validNode(hitbox,"BasePart") then
                        -- Boss战：头顶绕圈贴脸输出
                        promptCount = 0
                        local bp = hitbox.Position
                        r2.holdBody(hum,root)
                        ang = (ang + bossOrbitSpeed * dt) % (math.pi * 2)
                        local sp = Vector3.new(bp.X + math.cos(ang) * bossOrbitRadius, bp.Y + bossHeight, bp.Z + math.sin(ang) * bossOrbitRadius)
                        root.CFrame = bossTilt and CFrame.lookAt(sp, Vector3.new(bp.X, sp.Y, bp.Z)) or CFrame.new(sp)
                        if t-lastToolActivation>=0.1 then
                         lastToolActivation=t;pcall(function() tool:Activate() end)
                        end
                        if t-lastTouch>=0.05 and lh and type(firetouchinterest)=="function" then
                                pcall(firetouchinterest, hitbox, lh, 0)
                                pcall(firetouchinterest, hitbox, lh, 1)
                        end
                        if t-lastTouch>=0.05 and rh and type(firetouchinterest)=="function" then
                                pcall(firetouchinterest, hitbox, rh, 0)
                                pcall(firetouchinterest, hitbox, rh, 1)
                        end
                        if t-lastTouch>=0.05 then lastTouch=t end
                        r2.currentHitbox=hitbox;Perf:SetCombat()

                else
                        -- Boss没了：维持体形、补装备、传送宝箱开箱
                        Perf.combatUntil=0;r2.currentHitbox=nil
                        r2.holdBody(hum,root)
                        if not tool then
                                local bp2 = player:FindFirstChild("Backpack")
                                local pk = bp2 and bp2:FindFirstChild("Punch")
                                if pk then
                                        pcall(function() hum:EquipTool(pk) end)
                                end
                        end
                        local base = findChest()
                        if base then
                                local cpos = base:IsA("BasePart") and base.Position or base:GetPivot().Position
                                root.CFrame = CFrame.new(cpos.X, cpos.Y + 3, cpos.Z)
                                if promptCount < 10 and t - lastPrompt >= 0.3 then
                                        lastPrompt = t
                                        promptCount = promptCount + 1
                                        interactNearby(root.Position)
                                end
                        end
                end
        end
        bossHoverConn=RunService.Heartbeat:Connect(function(dt)
         local ok,e=pcall(bossTick,dt)
         if not ok then _G.auto_boss=false;Perf.lastError=tostring(e);r2.stopPlainBoss() end
        end)
end


-- ==================== 功能：换包重生 ====================
-- 练力量时穿练速装，重生前换重生倍率装，轮回不停
local PETS = {
        ["Omega Overlord"]      = { repSpeed = 20, strength = 0,  durability = 0,  rebirth = 0 },
        ["Swift Samurai"]       = { repSpeed = 15, strength = 0,  durability = 0,  rebirth = 0 },
        ["Powercore Hound"]     = { repSpeed = 0,  strength = 25, durability = 15, rebirth = 0 },
        ["Titanium Hydra"]      = { repSpeed = 0,  strength = 0,  durability = 0,  rebirth = 2 },
        ["Tribal Overlord"]     = { repSpeed = 0,  strength = 0,  durability = 0,  rebirth = 2 },
        ["Inferno Unicorn"]     = { repSpeed = 0,  strength = 25, durability = 25, rebirth = 0 },
        ["Common Boss Pet"]     = { repSpeed = 5,  strength = 0,  durability = 0,  rebirth = 0 },
        ["Rare Boss Pet"]       = { repSpeed = 7,  strength = 0,  durability = 0,  rebirth = 0 },
        ["Epic Boss Pet"]       = { repSpeed = 10, strength = 0,  durability = 0,  rebirth = 0 },
        ["Rainbow Boss Pet"]    = { repSpeed = 10, strength = 7,  durability = 0,  rebirth = 0 },
        ["Legendary Boss Pet"]  = { repSpeed = 10, strength = 10, durability = 0,  rebirth = 0 },
        ["Mythic Boss Pet"]     = { repSpeed = 10, strength = 20, durability = 0,  rebirth = 0 },
        ["Inferno Drake"]       = { repSpeed = 40, strength = 0,  durability = 0,  rebirth = 0 },
}
-- Candidate state fields are certified only after observed removal and addition transitions.
local equipmentField=nil
local equipmentNames={"Equipped","equipped","IsEquipped","isEquipped"}
local function readField(pet,field)
 if field.mode=="attribute" then
  local value=pet:GetAttribute(field.name);if type(value)=="boolean" then return value end
 else
  local v=pet:FindFirstChild(field.name);if v and v:IsA("BoolValue") then return v.Value end
 end
end
local function readPetEquipment(owned)
 if #owned==0 then return {},"empty",true end
 if type(options.equipmentReader)=="function" then
  local result={}
  for _,p in ipairs(owned) do
   local ok,v=pcall(options.equipmentReader,p.instance)
   if not ok or type(v)~="boolean" then r2.equipmentSource="显式读取器无效";return nil,"configured_invalid" end
   if v then result[p.instance]=true end
  end
  r2.equipmentSource="显式配置 equipmentReader"
  return result,r2.equipmentSource,true
 end
 local function snapshot(field)
  local result={}
  for _,p in ipairs(owned) do
   local v=readField(p.instance,field);if type(v)~="boolean" then return nil end
   if v then result[p.instance]=true end
  end
  return result
 end
 if equipmentField then
  local state=snapshot(equipmentField)
  if state then return state,equipmentField.mode..":"..equipmentField.name,false end
  equipmentField=nil
 end
 local selected,selectedState
 for _,name in ipairs(equipmentNames) do
  for _,mode in ipairs({"attribute","child"}) do
   local field={mode=mode,name=name};local state=snapshot(field)
   if state then
    if selectedState then
     for p in pairs(state) do if not selectedState[p] then r2.equipmentSource="候选字段冲突";return nil end end
     for p in pairs(selectedState) do if not state[p] then r2.equipmentSource="候选字段冲突";return nil end end
    else selected=field;selectedState=state end
   end
  end
 end
 equipmentField=selected
 if selected then r2.equipmentSource=selected.mode..":"..selected.name;return selectedState,r2.equipmentSource,false end
 r2.equipmentSource="无可验证状态，兼容回退"
 return nil
end
local function petSlots()
 local value
 if type(options.petSlotReader)=="function" then
  local ok,v=pcall(options.petSlotReader,player)
  if not ok or type(v)~="number" or v~=v or v<0 or v>24 then return nil,"显式槽位读取器无效" end
  value=v;r2.slotSource="显式配置 petSlotReader"
 end
 if type(value)~="number" then
  for _,name in ipairs({"MaxPetSlots","maxPetSlots"}) do
   local v=player:GetAttribute(name)
   if type(v)=="number" then value=v;r2.slotSource="候选属性 "..name;break end
   local child=player:FindFirstChild(name)
   if child and (child:IsA("IntValue") or child:IsA("NumberValue")) then value=child.Value;r2.slotSource="候选数值 "..name;break end
  end
 end
 if type(value)~="number" or value~=value or value<0 or value>24 then value=12;r2.slotSource="原版兼容值12（未确认实际上限）" end
 return math.clamp(math.floor(value),0,24)
end
local function getOwnedPets()
 local result={};local folder=player:FindFirstChild("petsFolder")
 if not folder then return nil end
 for _,sub in ipairs(folder:GetChildren()) do
  if sub:IsA("Folder") then
   for _,pet in ipairs(sub:GetChildren()) do
    if #result>0 and #result%256==0 then task.wait();if not r2.active("pack") then return nil end end
    local cfg=PETS[pet.Name] or {}
    if type(options.petStatsReader)=="function" then
     local ok,v=pcall(options.petStatsReader,pet)
     if not ok or type(v)~="table" then r2.configError="显式宠物数值读取器无效";return nil end
     cfg=v;r2.statSource="显式配置 petStatsReader"
    end
    local function number(key)
     local v=cfg[key];if type(v)~="number" or v~=v or math.abs(v)>1e6 then return 0 end;return math.max(0,v)
    end
    result[#result+1]={instance=pet,name=pet.Name,repSpeed=number("repSpeed"),strength=number("strength"),durability=number("durability"),rebirth=number("rebirth")}
   end
  end
 end
 return result
end
local function packActive() return r2.active("pack") end
local equipment=createJBSPets({clock=os.clock,wait=task.wait,ping=function() return pingSeconds end,
 active=packActive,version=function() return petVersion end,readEquipment=readPetEquipment,
 epoch=function() return r2.inventoryVersion end,
 cooperate=function() task.wait();return packActive() end,
 alivePet=function(p) local f=player:FindFirstChild("petsFolder");return f and p and p.Parent and p:IsDescendantOf(f) end,
 send=function(cmd,pet)
  refreshReferences()
  local remote=rEvents and rEvents:FindFirstChild("equipPetEvent")
  if not remote then return false end
  return Perf:FireGuarded(remote,packActive,cmd,pet)
 end})
local function applyPetPlan(mode)
 local owned=getOwnedPets();local deadline=os.clock()+12
 while not owned and packActive() do
  if r2.configError then return false,r2.configError end
  Perf.packStatus="等待宠物仓库加载"
  if os.clock()>=deadline then return false,"宠物仓库12秒未加载，已停止换包" end
  task.wait(0.1);owned=getOwnedPets()
 end
 if not owned or not packActive() then return false,"流程已取消" end
 local slots,slotError=petSlots();if not slots then return false,slotError end
 local key=mode..":"..slots..":"..r2.inventoryVersion
 local plan=r2.plans[key]
 if not plan then
  local reason;plan,reason=equipment:Plan(owned,slots,mode)
  if not plan then return false,reason end
  r2.plans[key]=plan
 end
 local ok,reason=equipment:Apply(owned,plan)
 if ok and mode=="farm" then r2.farmingProfile=equipment.profileKey end
 if ok and not equipment.confirmed and not r2.warnedEquipment then
  r2.warnedEquipment=true
  WindUI:Notify({Title="换装状态未确认",Content="未找到可靠状态字段，沿用兼容换装；诊断中可查看详情",Duration=5})
 end
 return ok,reason
end
local function equipFarmingPets() return applyPetPlan("farm") end
local function equipRebirthPets() return applyPetPlan("rebirth") end

local function packSnapshot()
 refreshReferences()
 if not strengthStat or not rebirths or not muscleEvent or not rebirthRemote then return nil end
 if not strengthStat.Parent or not rebirths.Parent or not muscleEvent.Parent or not rebirthRemote.Parent then return nil end
 if not r2.actor() then return nil end
 return strengthStat,rebirths,character
end
local function awaitPackReady()
 local deadline=os.clock()+30
 while packActive() do
  local str,rb,ch=packSnapshot()
  if str then return str,rb,ch end
  Perf.packTraining=false;Perf.packStatus="等待角色或统计恢复"
  if os.clock()>=deadline then return nil,"角色或统计30秒未恢复，已停止换包" end
  task.wait(0.1)
 end
 return nil,"流程已取消"
end
local function awaitRebirthClear()
 local deadline=os.clock()+12
 while packActive() and Perf.pending do
  local _,rb=packSnapshot()
  Perf:PollRebirth(rb and rb.Value)
  if not Perf.pending then break end
  Perf.packStatus="等待上一条重生调用"
  if os.clock()>=deadline then return false,"上一条重生调用未返回，已暂停换包；没有重复发送" end
  task.wait(0.05)
 end
 return packActive()
end
local function performPackRebirth()
 local stat,rb,ch=awaitPackReady();if not stat then return false,rb end
 local target=calculateRequiredStrength()
 while packActive() do
  Perf.packStatus=nil;Perf.packTraining=true
  local lastGrowth=os.clock();local lastGain=Perf.gainedStrength
  while packActive() do
   local s,r,c=packSnapshot()
   if s~=stat or r~=rb or c~=ch then Perf.packTraining=false;return true,"restart" end
   if stat.Value>=target then break end
   if Perf.gainedStrength>lastGain then lastGrowth=os.clock();lastGain=Perf.gainedStrength end
   if os.clock()-lastGrowth>=8 then break end
   task.wait(0.05)
  end
  if not r2.owns("pack") then return true,"cancelled" end
  Perf.packTraining=false
  if not packActive() then return true,"cancelled" end
  local clear,e=awaitRebirthClear();if not clear then return false,e end
  local ok,why=equipRebirthPets();if not ok then if why=="context_changed" then return true,"restart" end;return false,why end
  local s,r,c=packSnapshot()
  if s~=stat or r~=rb or c~=ch then return true,"restart" end
  local before=rb.Value;local deadline=os.clock()+15
  while packActive() and os.clock()<deadline do
   s,r,c=packSnapshot()
   if s~=stat or r~=rb or c~=ch then return true,"restart" end
   if rb.Value>before then return true,"reborn" end
   fireRebirthAttempt(true)
   task.wait(0.05)
  end
  if not packActive() then return true,"cancelled" end
  if Perf.pending and Perf.pending.invoking then return false,"重生调用仍未返回，已停止换包；没有重复调用" end
  clear,e=awaitRebirthClear();if not clear then return false,e end
  ok,why=equipFarmingPets();if not ok then if why=="context_changed" then return true,"restart" end;return false,why end
  s,r,c=packSnapshot()
  if s~=stat or r~=rb or c~=ch then return true,"restart" end
  target=math.floor(stat.Value*1.15)+1000
  WindUI:Notify({Title="换包重生",Content="未观察到重生增长，已恢复训练；候选协议仍待实测",Duration=4})
 end
 return true,"cancelled"
end
local function autoPackRebirthLoop()
 local ok,err=xpcall(function()
  while packActive() do
   local stat,rb=awaitPackReady();if not stat then error(rb,0) end
   if rbTarget>0 and rb.Value>=rbTarget then _G.auto_packrebirth=false;break end
   local clear,e=awaitRebirthClear();if not clear then if packActive() then error(e,0) end;break end
   local changed,why=equipFarmingPets()
   if not changed then
    if why=="context_changed" then task.wait(0.05);continue end
    if packActive() then error(why,0) end;break
   end
   local success,reason=performPackRebirth();if not success then error(reason,0) end
   task.wait(0.05)
  end
 end,function(e) return tostring(e) end)
 if not r2.owns("pack") then return end
 Perf.packTraining=false
 if not ok and sessionAlive and _G.auto_packrebirth then
  _G.auto_packrebirth=false;r2.packLastError=err;Perf.lastError=err;Perf.packStatus=err
  WindUI:Notify({Title="换包已停止",Content=err.."；可复制运行诊断",Duration=7})
 else Perf.packStatus=nil end
end
local function adaptiveTrainLoop() Perf:Retest() end


-- ==================== 功能：吃蛋 / 送蛋 ====================
-- 找蛋白蛋(角色或背包)
local function findProteinEgg()
        local char = player.Character
        local backpack = player:FindFirstChild("Backpack")
        return (char and char:FindFirstChild("Protein Egg"))
                or (backpack and backpack:FindFirstChild("Protein Egg"))
end

-- 吃一发蛋(双倍力量buff)
local function eatOneEgg()
        local egg = findProteinEgg()
        if egg then
                return Perf:FireGuarded(muscleEvent,function() return r2.active("egg") end,"proteinEgg",egg)
        end
        return false
end

-- 自动吃蛋循环: 每0.5秒扫一次，找到就10连吃
local function autoEatEggLoop()
        while r2.active("egg") do
                pcall(function()
                        if findProteinEgg() then
                                for _ = 1, 10 do
                                        if not r2.active("egg") or not eatOneEgg() then break end
                                end
                        end
                end)
                task.wait(0.5)
        end
end

-- 送蛋: 把仓库里的蛋送给目标玩家，返回实送数量
local function giftEggsTo(targetPlayer,amount)
 refreshReferences()
 local remote=rEvents and rEvents:FindFirstChild("giftRemote")
 local folder=player:FindFirstChild("consumablesFolder")
 if not remote or not folder or not targetPlayer or not targetPlayer.Parent then return 0,"目标或仓库未就绪" end
 local snapshot={}
 for _,egg in ipairs(folder:GetChildren()) do if egg.Name=="Protein Egg" then snapshot[#snapshot+1]=egg end end
 local submitted=0
 for i=1,math.min(math.max(0,math.floor(amount)),#snapshot) do
  if not r2.active("gift") or not targetPlayer.Parent then break end
  local egg=snapshot[i]
  if egg.Parent==folder then
   local ok,why=Perf:Call(remote,function() return r2.active("gift") and targetPlayer.Parent~=nil end,"giftRequest",targetPlayer,egg)
   if not ok then return submitted,tostring(why or "调用未完成") end
   submitted+=1
   task.wait(0.1)
  end
 end
 return submitted,"到账待游戏确认"
end


-- 换包重生页玩家列表(送蛋下拉用)
local function getPackPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then
                        table.insert(names, p.Name)
                end
        end
        return names
end

-- ==================== 主要页 ====================
MainTab:Input({
        Title = "目标次数",
        Placeholder = "重生目标，0为无限",
        Value = "",
        ClearTextOnFocus = false,
        Callback = function(v)
                local n=tonumber(v);rbTarget=(n and n==n and n>=0 and n<math.huge) and math.floor(n) or 0
        end
})

MainTab:Toggle({
        Title = "自动重生",
        Value = false,
        Callback = function(state)
                _G.auto_rebirth = state
                r2.invalidate("rebirth")
                stop(rebirthThread)
                if state then
                        rebirthThread = r2.startWorker("rebirth",autoRebirthLoop)
                        WindUI:Notify({ Title = "已开启", Content = "自动重生已开启" .. (rbTarget > 0 and ("，目标: " .. rbTarget .. "次") or "，无限"), Duration = 2 })
                else
                        WindUI:Notify({ Title = "已关闭", Content = "自动重生已关闭", Duration = 2 })
                end
        end
})

MainTab:Divider()

MainTab:Toggle({
        Title = "自动锻炼",
        Value = false,
        Callback = function(state)
                _G.auto_train = state
                r2.invalidate("normal")
                stop(trainThread)
                if state then
                        if not muscleEvent then
                                WindUI:Notify({ Title = "提示", Content = "未找到muscleEvent，请等待游戏加载后重试", Duration = 4 })
                                _G.auto_train = false
                                return
                        end
                        trainThread = r2.startWorker("normal",autoTrainLoop)
                        WindUI:Notify({ Title = "已开启", Content = "自动锻炼已开启", Duration = 2 })
                else
                        WindUI:Notify({ Title = "已关闭", Content = "自动锻炼已关闭", Duration = 2 })
                end
        end
})

MainTab:Divider()

-- ==================== 自动轮盘 ====================
MainTab:Toggle({
        Title = "自动轮盘",
        Value = false,
        Callback = function(state)
                _G.auto_wheel = state
                r2.invalidate("wheel")
                stop(wheelThread)
                if state then
                        wheelThread = r2.startWorker("wheel",autoWheelLoop)
                        WindUI:Notify({ Title = "已开启", Content = "自动轮盘已开启", Duration = 2 })
                else
                        WindUI:Notify({ Title = "已关闭", Content = "自动轮盘已关闭", Duration = 2 })
                end
        end
})

MainTab:Divider()

MainTab:Section({ Title = "送蛋" })

MainTab:Toggle({
        Title = "自动吃蛋",
        Value = false,
        Color = Color3.fromHex("#F39C12"),
        Callback = function(state)
                _G.auto_eategg = state
                r2.invalidate("egg")
                stop(eateggThread)
                if state then
                        if not muscleEvent then
                                WindUI:Notify({ Title = "提示", Content = "未找到muscleEvent，请等待游戏加载后重试", Duration = 4 })
                                _G.auto_eategg = false
                                return
                        end
                        eateggThread = r2.startWorker("egg",autoEatEggLoop)
                        WindUI:Notify({ Title = "自动吃蛋", Content = "已开启", Duration = 2 })
                else
                        WindUI:Notify({ Title = "自动吃蛋", Content = "已关闭", Duration = 2 })
                end
        end,
})

local selectedEggTarget = ""
local EggPlayerDropdown = MainTab:Dropdown({
        Title = "送蛋目标",
        Values = getPackPlayerNames(),
        AllowNone = true,
        Callback = function(v)
                selectedEggTarget = v or ""
        end,
})

MainTab:Input({
        Title = "送蛋数量",
        Placeholder = "0为全部",
        Value = "",
        ClearTextOnFocus = false,
        Callback = function(v)
                local n=tonumber(v);giftAmount=(n and n==n and n>=0 and n<math.huge) and math.floor(n) or 0
        end,
})

MainTab:Button({
        Title = "送蛋",
        Color = Color3.fromHex("#2ECC71"),
        Callback = function()
                local target = Players:FindFirstChild(selectedEggTarget)
                if selectedEggTarget == "" or not target then
                        WindUI:Notify({ Title = "送蛋", Content = "请先选择玩家", Duration = 3 })
                        return
                end
                local folder = player:FindFirstChild("consumablesFolder")
                local have = folder and #folder:GetChildren() or 0
                if have == 0 then
                        WindUI:Notify({ Title = "送蛋", Content = "仓库里没有蛋", Duration = 3 })
                        return
                end
                local amount = giftAmount > 0 and giftAmount or 9999
                if giftThread and coroutine.status(giftThread)~="dead" then
                 WindUI:Notify({Title="送蛋",Content="上一批仍在处理中",Duration=2});return
                end
                giftThread=r2.startWorker("gift",function()
                        local sent,why=giftEggsTo(target,amount)
                        if r2.active("gift") then
                         WindUI:Notify({Title="送蛋",Content="向 "..target.Name.." 完成 "..sent.." 次调用；"..tostring(why),Duration=4})
                         EggPlayerDropdown:Refresh(getPackPlayerNames(),true)
                        end
                end)
        end,
})


-- ==================== 传送区域 ====================
local TELEPORTS = {
        { name = "大厅", pos = Vector3.new(-0.75, 90.61, 242.78) },
        { name = "小岛", pos = Vector3.new(-32.14, 8.51, 1904.41) },
        { name = "冰霜健身房", pos = Vector3.new(-2623.41, 6.99, -409.34) },
        { name = "神话健身房", pos = Vector3.new(2250.39, 6.99, 1072.77) },
        { name = "永恒健身房", pos = Vector3.new(-6758.39, 6.99, -1284.45) },
        { name = "传奇健身房", pos = Vector3.new(4603.40, 990.99, -3897.44) },
        { name = "肌肉之王健身房", pos = Vector3.new(-8625.40, 16.99, -5730.41) },
        { name = "丛林健身房", pos = Vector3.new(-8685.01, 5.99, 2392.06) },
        { name = "工业健身房", pos = Vector3.new(-5496.68, 59.04, 4927.74) },
        { name = "超载健身房", pos = Vector3.new(-3045.30, 165.41, 4990.69) },
        { name = "无转盘岛", pos = Vector3.new(1952.09, 1, 6179.98) },
        { name = "熔岩争斗", pos = Vector3.new(4472.53, 118.90, -8848.54) },
        { name = "沙漠争斗", pos = Vector3.new(973.62, 15.92, -7277.01) },
        { name = "海滩争斗", pos = Vector3.new(-1880.89, 15.87, -6137.75) },
}

local function teleportTo(pos)
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(pos)
                return true
        end
        return false
end

for _, tp in ipairs(TELEPORTS) do
        TeleportTab:Button({
                Title = tp.name,
                Callback = function()
                        if teleportTo(tp.pos) then
                                WindUI:Notify({ Title = "传送", Content = "已传送到: " .. tp.name, Duration = 2 })
                        else
                                WindUI:Notify({ Title = "传送失败", Content = "未找到角色", Duration = 2 })
                        end
                end
        })
end

-- ==================== 宠物页 ====================
PetTab:Section({ Title = "宠物商店购买" })

local PetDropdown = PetTab:Dropdown({
        Title = "选择宠物/光环",
        Values = getPetShopList(),
        AllowNone = true,
        Callback = function(v)
                selectedPet = v or ""
        end,
})

PetTab:Button({
        Title = "刷新宠物列表",
        Callback = function()
                local list = getPetShopList()
                PetDropdown:Refresh(list, true)
                WindUI:Notify({ Title = "宠物商店", Content = "已刷新，共" .. #list .. "项", Duration = 2 })
        end,
})

PetTab:Button({
        Title = "购买一次",
        Color = Color3.fromHex("#00BFFF"),
        Callback = function()
                local ok, msg = buyPet(selectedPet)
                if ok then
                        WindUI:Notify({ Title = "宠物商店", Content = msg, Duration = 3 })
                else
                        WindUI:Notify({ Title = "宠物商店", Content = msg, Duration = 4 })
                end
        end
})

PetTab:Toggle({
        Title = "自动购买",
        Value = false,
        Callback = function(state)
                _G.auto_petbuy = state
                r2.invalidate("petbuy")
                stop(petbuyThread)
                if state then
                        if selectedPet == "" then
                                WindUI:Notify({ Title = "宠物商店", Content = "请先选择宠物", Duration = 3 })
                                _G.auto_petbuy = false
                                return
                        end
                        petbuyThread = r2.startWorker("petbuy",autoPetBuyLoop)
                        WindUI:Notify({ Title = "宠物商店", Content = "自动购买已开启: " .. selectedPet, Duration = 3 })
                else
                        WindUI:Notify({ Title = "宠物商店", Content = "自动购买已关闭", Duration = 2 })
                end
        end
})

-- ==================== Boss页 ====================
BossTab:Toggle({
        Title = "自动打Boss",
        Value = false,
        Color = Color3.fromHex("#FF4040"),
        Callback = function(state)
                _G.auto_boss = state
                Perf.combatUntil=0
                if state then _G.auto_packrebirth=false;Perf.packTraining=false;stop(packrebirthThread) end
                if bossHoverConn then
                        pcall(function() bossHoverConn:Disconnect() end)
                        bossHoverConn = nil
                end
                if state then
                        if not getMuscleEvent() then
                                WindUI:Notify({ Title = "提示", Content = "未找到muscleEvent，请等待游戏加载后重试", Duration = 4 })
                                _G.auto_boss = false
                                return
                        end
                        refreshReferences()
                        destroyPortals()
                        -- 互斥：先停「Boss重生」引擎（换包重生页），避免双重控制角色
                        if _G.auto_bossrebirth then
                                _G.auto_bossrebirth = false
                                if _G.__JBS_bossrb_stop then pcall(_G.__JBS_bossrb_stop) end
                                WindUI:Notify({ Title = "Boss", Content = "已自动关闭「Boss重生」避免冲突", Duration = 3 })
                        end
                        startBossLoop()
                        WindUI:Notify({ Title = "Boss", Content = "自动击杀Boss已开启", Duration = 3 })
                else
                        hitbox = nil
                        r2.stopPlainBoss()
                        WindUI:Notify({ Title = "Boss", Content = "已关闭", Duration = 2 })
                end
        end,
})

-- ==================== 换包重生页 ====================
PackTab:Section({ Title = "换包重生" })

PackTab:Toggle({
        Title = "换包重生",
        Value = false,
        Color = Color3.fromHex("#9B59B6"),
        Callback = function(state)
                _G.auto_packrebirth = state
                r2.invalidate("pack")
                Perf.packTraining=false
                Perf.packStatus=nil;r2.packLastError=nil
                if state then stopBossModes() end
                stop(packrebirthThread)
                if state then
                        if not (muscleEvent and rebirthRemote and rebirths and strengthStat) then
                                WindUI:Notify({ Title = "提示", Content = "未找到游戏事件，请等待游戏加载后重试", Duration = 4 })
                                _G.auto_packrebirth = false
                                return
                        end
                        packrebirthThread = r2.startWorker("pack",autoPackRebirthLoop)
                        WindUI:Notify({ Title = "换包重生", Content = "已开启", Duration = 2 })
                else
                        WindUI:Notify({ Title = "换包重生", Content = "已关闭", Duration = 2 })
                end
        end,
})

PackTab:Divider()

PackTab:Toggle({
        Title = "快速锻炼",
        Value = false,
        Color = Color3.fromHex("#00BFFF"),
        Callback = function(state)
                _G.auto_fasttrain = state
                r2.invalidate("fast")
                stop(fasttrainThread)
                if state then
                        if not muscleEvent then
                                WindUI:Notify({ Title = "提示", Content = "未找到muscleEvent，请等待游戏加载后重试", Duration = 4 })
                                _G.auto_fasttrain = false
                                return
                        end
                        Perf:Retest()
                        StandaloneFast:Retest()
                        fasttrainThread = r2.startWorker("fast",adaptiveTrainLoop)
                        WindUI:Notify({ Title = "已开启", Content = "快速锻炼已开启", Duration = 2 })
                else
                        WindUI:Notify({ Title = "已关闭", Content = "快速锻炼已关闭", Duration = 2 })
                end
        end,
})

-- ==================== Boss重生引擎（缝合自 Frazil·boss+重生+锻炼） ====================
-- 流程：打Boss(绕圈出拳) → Boss死亡领宝箱 → 无Boss时举哑铃+匀速rep+多协议重生请求 → 新Boss刷新回战
-- 重执行安全：线程/连接注册到 _G.__JBS_bossrb_cleanup，由关闭钩子统一回收
do
        local ws = workspace
        local fh = 65      -- 头顶绕圈高度
        local rr = 5       -- 绕圈半径
        local rsp = 30     -- 绕圈角速度
        local tilt = true  -- 朝向Boss
        local sizeVal = 6  -- 体型调节
        local run = false
        local engineGeneration=0
        local phase = "fight"
        local seenBoss = false
        local hitbox = nil
        local ang = 0
        local lastT = 0
        local lastToolActivation=0
        local lastTouch=0
        local lastSz = 0
        local cacheT = 0
        local trainSzT = 0
        local repAcc, lastRepT = 0, 0
        local rbAcc, lastRbT = 0, 0
        local bossRbBefore, bossRbCheckT = nil, 0
        local muscleEv = muscleEvent
        local sizeRemote = rEvents and rEvents:FindFirstChild("changeSpeedSizeRemote")
        local engineThreads, engineConns = {}, {}
        local bossStep,bossScheduler,hbConn,schedThread

        local function bnotify(title, content, duration)
                pcall(function()
                        WindUI:Notify({ Title = tostring(title), Content = tostring(content), Duration = duration or 3 })
                end)
        end

        -- 判定箱查找
        local function refreshHitbox() return indexedBoss() end

        -- 领宝箱
        local function lootChests(root)
         local generation=engineGeneration
         ensureSceneIndex()
         local bc=ws:FindFirstChild("BossChest")
         if not bc then return end
         for prompt in pairs(promptIndex) do
          if not run or engineGeneration~=generation or phase~="chest" or not sessionAlive then return end
          if prompt.Parent and prompt:IsDescendantOf(bc) then
           local pos=promptPosition(prompt)
           if pos then
            root.CFrame=CFrame.new(pos+Vector3.new(0,3,0))
            task.wait(0.2)
            for _=1,10 do
             if not run or engineGeneration~=generation or not sessionAlive or not prompt.Parent or not prompt.Enabled then break end
             tryPrompt(prompt,true);task.wait(0.12)
            end
           end
          end
         end
        end

        -- 卸下指定工具（收回背包，防止双工具同屏）
        local function stowTool(name)
                local ch = player.Character
                local bp = player:FindFirstChild("Backpack")
                if not ch or not bp then return end
                local t = ch:FindFirstChild(name)
                if t and t.ClassName == "Tool" then
                        t.Parent = bp
                end
        end

        -- 装备哑铃：先卸Punch（互斥），再挂Weight
        local function equipWeight()
                local ch = player.Character
                local bp = player:FindFirstChild("Backpack")
                if not ch or not bp then return end
                local hum = ch:FindFirstChildOfClass("Humanoid")
                if hum then r2.releaseBody() end
                stowTool("Punch")
                if ch:FindFirstChild("Weight") then return end
                for _, v in pairs(bp:GetChildren()) do
                        if v.ClassName == "Tool" and v.Name == "Weight" then
                                v.Parent = ch
                        end
                end
        end

        -- 进锻炼阶段 重置双累积器
        local function enterTrain()
                phase = "train"
                Perf.combatUntil=0;r2.currentHitbox=nil
                Perf.bossTraining=true
                trainSzT = tick()
                repAcc = 0
                lastRepT = tick()
                rbAcc = 0
                lastRbT = tick()
                bossRbBefore = nil -- 重生基线重新记录
        end

        -- 引擎开关
        local function startEngine()
                if run then return true end
                engineGeneration+=1
                if not muscleEv then
                        muscleEv = player:FindFirstChild("muscleEvent") or muscleEvent
                end
                -- sizeRemote 是装饰性协议（只管体型），缺失不阻塞：锻炼/重生照常跑
                if not sizeRemote then
                        sizeRemote = rEvents and rEvents:FindFirstChild("changeSpeedSizeRemote") or nil
                end
                if not sizeRemote then
                        bnotify("Boss重生", "未找到changeSpeedSizeRemote，已跳过体型调节，不影响锻炼/重生", 4)
                end
                if not muscleEv then
                        bnotify("错误", "找不到muscleEvent，Boss重生不可用", 4)
                        return false
                end
                phase = "fight"
                seenBoss = false
                hitbox = nil
                ang = 0
                lastT = 0
                lastSz = 0
                cacheT = 0
                repAcc = 0
                lastRepT = tick()
                rbAcc = 0
                lastRbT = tick()
                run = true
                Perf.bossActive=true;Perf.bossTraining=false
                hbConn=RunService.Heartbeat:Connect(function(dt)
                 local ok,e=pcall(bossStep,dt)
                 if not ok then _G.auto_bossrebirth=false;Perf.lastError=tostring(e);if _G.__JBS_bossrb_stop then _G.__JBS_bossrb_stop() end end
                end)
                schedThread=r2.startWorker("bossrb",function() bossScheduler(engineGeneration) end)
                return true
        end

        local function stopEngine()
                engineGeneration+=1
                run = false
                if hbConn then hbConn:Disconnect();hbConn=nil end
                if schedThread then pcall(task.cancel,schedThread);schedThread=nil end
                r2.cancelPrompts();r2.releaseBody();r2.currentHitbox=nil
                Perf.bossActive=false;Perf.bossTraining=false;Perf.combatUntil=0
                local ch = player.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if hum then r2.releaseBody() end
                hitbox = nil
                phase = "fight"
                seenBoss = false
        end

        -- 心跳循环：战斗/举哑铃+重生
        bossStep=function(frameDt)
                if not run then return end
                if rbTarget>0 and rebirths and rebirths.Value>=rbTarget then
                 _G.auto_bossrebirth=false;stopEngine()
                 bnotify("重生完成","已达到目标，Boss重生已停止",4);return
                end
                local t = tick()
                if hitbox and not r2.validNode(hitbox,"BasePart") then hitbox=nil end
                if phase == "fight" then
                        if t - lastT < 0.01 then return end
                        lastT = t
                        local ch,root,hum,tool,lh,rh=r2.actor()
                        if not ch then return end

                        if t - lastSz >= 1 then
                                lastSz = t
                                requestSize(sizeRemote,sizeVal)
                        end

                        if t - cacheT >= 0.2 then
                                cacheT = t
                                hitbox = refreshHitbox()
                        end

                        -- 互斥：打boss时必须收起哑铃
                        if ch:FindFirstChild("Weight") then
                                stowTool("Weight")
                        end
                        if not tool then
                                local bp = player:FindFirstChild("Backpack")
                                local pk = bp and bp:FindFirstChild("Punch")
                                if pk then
                                        pcall(function() hum:EquipTool(pk) end)
                                        return
                                end
                        end

                        if not hitbox then return end
                        seenBoss = true

                        local bp = hitbox.Position
                        r2.holdBody(hum,root)

                        ang = (ang + rsp * 0.06 * math.min(frameDt,0.1)) % (math.pi*2)
                        local sp = Vector3.new(bp.X + math.cos(ang) * rr, bp.Y + fh, bp.Z + math.sin(ang) * rr)
                        root.CFrame = tilt and CFrame.lookAt(sp, Vector3.new(bp.X, sp.Y, bp.Z)) or CFrame.new(sp)

                        if tool and t-lastToolActivation>=0.1 then
                                lastToolActivation=t
                                pcall(function() tool:Activate() end)
                        end
                        if t-lastTouch>=0.05 and lh and type(firetouchinterest)=="function" then
                                pcall(function() firetouchinterest(hitbox, lh, 0) end)
                                pcall(function() firetouchinterest(hitbox, lh, 1) end)
                        end
                        if t-lastTouch>=0.05 and rh and type(firetouchinterest)=="function" then
                                pcall(function() firetouchinterest(hitbox, rh, 0) end)
                                pcall(function() firetouchinterest(hitbox, rh, 1) end)
                        end
                        if t-lastTouch>=0.05 then lastTouch=t end
                        r2.currentHitbox=hitbox;Perf:SetCombat()
                elseif phase == "train" then
                        local ch=player.Character
                        local wt=ch and ch:FindFirstChild("Weight")
                        if wt and t-lastRepT>=0.1 then
                         lastRepT=t;pcall(function() wt:Activate() end)
                        end
                        fireRebirthAttempt()


                else
                        lastRepT = t
                        lastRbT = t
                end
        end

        -- 调度循环：阶段切换
        bossScheduler=function(generation)
                local nTick = 0
                while run and generation==engineGeneration do
                        task.wait(0.1)
                        if run and generation==engineGeneration then
                                nTick = nTick + 1
                                if phase == "fight" then
                                        if seenBoss and not r2.validNode(hitbox,"BasePart") then
                                                phase = "chest"
                                                bnotify("Boss重生", "boss死亡 前往领箱", 2)
                                        elseif not seenBoss and not r2.validNode(hitbox,"BasePart") then
                                                local hb = refreshHitbox()
                                                if hb then
                                                        hitbox = hb
                                                else
                                                        equipWeight()
                                                        enterTrain()
                                                        bnotify("Boss重生", "无boss 举哑铃开刷", 2)
                                                end
                                        end
                                elseif phase == "chest" then
                                        local generation=engineGeneration
                                        local ch = player.Character
                                        local root = ch and ch:FindFirstChild("HumanoidRootPart")
                                        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                                        if hum then r2.releaseBody() end
                                        if root then
                                                lootChests(root)
                                        end
                                        task.wait(0.3)
                                        if run and generation==engineGeneration then
                                         seenBoss = false
                                         equipWeight()
                                         enterTrain()
                                         bnotify("Boss重生", "开始举哑铃", 2)
                                        end
                                elseif phase == "train" then
                                        if tick() - trainSzT >= 1 then
                                                trainSzT = tick()
                                                requestSize(sizeRemote,sizeVal)
                                                equipWeight()
                                        end
                                        if nTick % 2 == 0 then
                                                local hb = refreshHitbox()
                                                if hb and hb ~= hitbox then
                                                        phase = "fight"
                                                        Perf.bossTraining=false
                                                        local ch = player.Character
                                                        local root = ch and ch:FindFirstChild("HumanoidRootPart")
                                                        if root and hb then
                                                                root.CFrame = CFrame.new(hb.Position + Vector3.new(0, fh, 0))
                                                        end
                                                        hitbox = hb
                                                        seenBoss = true
                                                        bnotify("Boss重生", "新boss刷新 已就位", 2)
                                                end
                                        end
                                end
                        end
                end
        end

        -- 会话清理入口（关闭钩子调用）：停引擎+回收线程与连接
        _G.__JBS_bossrb_cleanup = function()
                stopEngine()
                for _, t in ipairs(engineThreads) do
                        pcall(function() task.cancel(t) end)
                end
                for _, c in ipairs(engineConns) do
                        pcall(function() c:Disconnect() end)
                end
                table.clear(engineThreads)
                table.clear(engineConns)
                _G.__JBS_bossrb_stop = nil
                _G.__JBS_bossrb_cleanup = nil
        end
        _G.__JBS_bossrb_stop = function()
                if run then stopEngine() end
        end

        PackTab:Divider()

        PackTab:Section({ Title = "Boss重生" })

        PackTab:Slider({
                Title = "头顶高度",
                Value = { Min = 0, Max = 200, Default = 65 },
                Callback = function(v)
                        fh = v
                end,
        })

        PackTab:Toggle({
                Title = "Boss重生",
                Value = false,
                Color = Color3.fromHex("#FF4040"),
                Callback = function(state)
                        _G.auto_bossrebirth = state
                        if state then _G.auto_packrebirth=false;Perf.packTraining=false;stop(packrebirthThread) end
                        if state then
                                if not rebirthRemote then
                                        bnotify("Boss重生", "找不到rebirthRemote", 2)
                                        _G.auto_bossrebirth = false
                                        return
                                end
                                -- 互斥：先停原生「自动打Boss」，避免双重控制角色
                                if _G.auto_boss then
                                        _G.auto_boss = false
                                        r2.stopPlainBoss()
                                        local ch = player.Character
                                        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                                        if hum then r2.releaseBody() end
                                        bnotify("Boss重生", "已自动关闭「自动打Boss」避免冲突", 3)
                                end
                                if startEngine() then
                                        bnotify("Boss重生", "已开启:打Boss+重生+举哑铃", 2)
                                else
                                        bnotify("Boss重生", "启动失败，请手动关闭开关", 3)
                                        _G.auto_bossrebirth = false
                                end
                        else
                                _G.__JBS_bossrb_stop()
                                bnotify("Boss重生", "已关闭", 2)
                        end
                end,
        })
end

-- ==================== 数据统计小窗（仿游戏自带统计面板） ====================
local statsParent = safeUiRoot()
local oldStatsGui = statsParent:FindFirstChild("JBSStatsPanel")
if oldStatsGui then oldStatsGui:Destroy() end
local duraStat = leaderstats and (leaderstats:FindFirstChild("Durability") or leaderstats:FindFirstChild("durability")) or nil
local fmtUnits = { {1e30,"Dc"},{1e27,"Oc"},{1e24,"Sp"},{1e21,"Sx"},{1e18,"Qi"},{1e15,"Qa"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"} }
local function fmtNum(n)
        if n < 0 then return "-" .. fmtNum(-n) end
        n = math.floor(n + 0.5)
        for _, u in ipairs(fmtUnits) do
                if n >= u[1] then return string.format("%.1f%s", n / u[1], u[2]) end
        end
        return tostring(n)
end
local statsGui = Instance.new("ScreenGui")
statsGui.Name = "JBSStatsPanel"; statsGui.ResetOnSpawn = false; statsGui.DisplayOrder = 50
statsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; statsGui.Parent = statsParent
local statsPanel = Instance.new("Frame")
statsPanel.Size = UDim2.fromOffset(320, 354)
statsPanel.Position = UDim2.new(.05, 0, .42, 0)
statsPanel.BackgroundColor3 = Color3.fromRGB(18, 12, 30); statsPanel.BackgroundTransparency = .08
statsPanel.BorderSizePixel = 0; statsPanel.Visible = false; statsPanel.Parent = statsGui
do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = statsPanel
        local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(216, 180, 254); s.Transparency = .55; s.Thickness = 1; s.Parent = statsPanel
end
local statsTitle = Instance.new("TextLabel")
statsTitle.Size = UDim2.new(1, 0, 0, 40); statsTitle.Position = UDim2.new(0, 0, 0, 0)
statsTitle.BackgroundColor3 = Color3.fromRGB(91, 33, 122); statsTitle.BackgroundTransparency = .2
statsTitle.BorderSizePixel = 0; statsTitle.Text = "数据统计"
statsTitle.TextColor3 = Color3.fromRGB(255, 230, 250); statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextSize = 18; statsTitle.Parent = statsPanel
do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = statsTitle
        local fix = Instance.new("Frame")
        fix.Size = UDim2.new(1, 0, 0, 12); fix.Position = UDim2.new(0, 0, 1, -12)
        fix.BackgroundColor3 = Color3.fromRGB(91, 33, 122); fix.BackgroundTransparency = .2; fix.BorderSizePixel = 0
        fix.Parent = statsTitle
end
local statsRow = {}
local function mkStatRow(key, name, y)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1; l.BorderSizePixel = 0
        l.Position = UDim2.fromOffset(14, y); l.Size = UDim2.fromOffset(96, 24)
        l.Text = name; l.TextColor3 = Color3.fromRGB(216, 180, 254); l.Font = Enum.Font.Gotham
        l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextYAlignment = Enum.TextYAlignment.Center
        l.Parent = statsPanel
        local v = Instance.new("TextLabel")
        v.BackgroundTransparency = 1; v.BorderSizePixel = 0
        v.Position = UDim2.fromOffset(104, y); v.Size = UDim2.fromOffset(202, 24)
        v.Text = "--"; v.TextColor3 = Color3.fromRGB(255, 230, 250); v.Font = Enum.Font.GothamBold
        v.TextSize = 13; v.TextXAlignment = Enum.TextXAlignment.Right; v.TextYAlignment = Enum.TextYAlignment.Center
        v.Parent = statsPanel
        statsRow[key] = v
end
mkStatRow("rebirth", "重生", 52)
mkStatRow("rebirthRate", "重生速度", 84)
mkStatRow("strength", "力量", 116)
mkStatRow("durability", "耐久", 148)
mkStatRow("strengthRate", "力量平均", 180)
mkStatRow("durabilityRate", "耐久平均", 212)
mkStatRow("liveGain", "力量/秒", 244)
mkStatRow("sendRate", "请求/秒", 276)
mkStatRow("worker", "状态", 308)
PackTab:Button({Title="重新测量速度",Callback=function() Perf:Retest() end})
PackTab:Button({Title="复制运行诊断",Callback=function()
 local executor="未提供识别接口"
 if type(identifyexecutor)=="function" then local ok,v=pcall(identifyexecutor);if ok then executor=tostring(v) end end
 local candidate=rebirthCallVariants[Perf.variant]
 local report=table.concat({
  "JBS Extreme R3 2026-10-18", "执行器="..executor, "PlaceId="..tostring(game.PlaceId),
  "状态="..Perf.status,"Ping(ms)="..tostring(math.floor(pingSeconds*1000)),
  "请求/秒="..string.format("%.1f",Perf.sentRate),"有效目标="..tostring(Perf.rate),"选定档位="..tostring(StandaloneFast.active and StandaloneFast.target or Perf.selectedRate),"帧率容量="..tostring(StandaloneFast.active and StandaloneFast.capacity or Perf.capacity),
  "力量/秒(客户端同步)="..tostring(Perf.gainRate or "尚未完成测量"),
  "重生候选="..table.concat(candidate," / "),"候选关联增长="..tostring(Perf.locked),
  "请求等待中="..tostring(Perf.pending~=nil),"最近错误="..tostring(Perf.lastError or "无"),
  "累计力量正增量="..tostring(Perf.gainedStrength),
  "装备状态来源="..tostring(r2.equipmentSource),"换装状态="..equipment.status,
  "差异切换="..tostring(equipment.diffActive),"已认证状态源="..tostring(equipment.verifiedSource),
  "槽位来源="..r2.slotSource,"宠物数值来源="..r2.statSource,
  "换包最近错误="..tostring(r2.packLastError or "无"),"未结调用="..tostring(Perf:PendingCalls()),
  "触碰接口="..tostring(type(firetouchinterest)=="function"),
  "交互接口="..tostring(type(fireproximityprompt)=="function"),
 },"\n")
 print(report)
 local copied=false
 if type(setclipboard)=="function" then copied=pcall(setclipboard,report) end
 WindUI:Notify({Title="运行诊断",Content=copied and "报告已复制，可直接发回；游戏内效果仍需观察" or "报告已输出至执行器控制台",Duration=5})
end})
local sessionStart = r2.startedAt
local baseStrength = strengthStat and strengthStat.Value or 0
local baseRebirths = rebirths and rebirths.Value or 0
local baseDurability = duraStat and duraStat.Value or 0
local function refreshStatsPanel()
        statsRow.liveGain.Text=Perf.gainRate and string.format("%.1f（同步观测）",Perf.gainRate) or "等待完整测量窗口"
        statsRow.sendRate.Text=string.format("实发 %.0f / 目标 %.0f",Perf.sentRate,Perf.rate)
        statsRow.worker.Text=Perf.lastError and "最近报错，可复制诊断" or (Perf.pending and "等待重生结果" or Perf.status)
        local hours = math.max(os.clock() - sessionStart, 1) / 3600 -- 按真实经过时间计算；开局短窗口会波动
        local str = strengthStat and strengthStat.Value or 0
        local rb = rebirths and rebirths.Value or 0
        duraStat=leaderstats and (leaderstats:FindFirstChild("Durability") or leaderstats:FindFirstChild("durability"))
        local du = duraStat and duraStat.Value or 0
        local strInc, rbInc, duInc = Perf.gainedStrength, Perf.gainedRebirths, Perf.gainedDurability
        statsRow.rebirth.Text = fmtNum(rb) .. " 已获得 " .. fmtNum(rbInc)
        statsRow.rebirthRate.Text = fmtNum(rbInc / hours) .. "/时 " .. fmtNum(rbInc * 24 / hours) .. "/天"
        statsRow.strength.Text = fmtNum(str) .. " 已获得 " .. fmtNum(strInc)
        statsRow.durability.Text = duraStat and (fmtNum(du) .. " 已获得 " .. fmtNum(duInc)) or "--"
        statsRow.strengthRate.Text = fmtNum(strInc / hours) .. "/时 " .. fmtNum(strInc * 24 / hours) .. "/天"
        statsRow.durabilityRate.Text = duraStat and (fmtNum(duInc / hours) .. "/时 " .. fmtNum(duInc * 24 / hours) .. "/天") or "--"
end
statsThread=task.spawn(function()
        while sessionAlive and statsGui.Parent do
                if statsPanel.Visible then pcall(refreshStatsPanel) end
                task.wait(0.5)
        end
end)
PackTab:Button({
        Title = "数据统计",
        Color = Color3.fromHex("#9B59B6"),
        Callback = function()
                statsPanel.Visible = not statsPanel.Visible
                if statsPanel.Visible then pcall(refreshStatsPanel) end
        end,
})

-- ==================== 启动 ====================
task.wait(0.3)
WindUI:Notify({
        Title = "脚本加载完成",
        Content = (muscleEvent and rebirthRemote) and "JBS Extreme R3 已加载 · 安卓 Delta 待实测" or "JBS Extreme R3 已加载，部分游戏对象缺失",
        Duration = 3,
})

end)
if not okMain then
        local uiRoot=player:FindFirstChild("PlayerGui")
        local failedGui=uiRoot and uiRoot:FindFirstChild("JBS_Metal_v31")
        if failedGui then pcall(function() failedGui:Destroy() end) end
        if _G.__JBS_shutdown_hook then pcall(_G.__JBS_shutdown_hook) elseif _G.__JBS_boot_cleanup then pcall(_G.__JBS_boot_cleanup) end
        notify("JBS 力量传奇", "运行出错: " .. tostring(errMain), 10)
        warn("[JBS] 运行错误: ", errMain)
end

 return okMain,errMain
 end
 local ok,success,err=pcall(runOriginalGame)
 local failure=ok and err or success
 WindUI:FinishGame(ok and success==true,failure,launchGeneration)
 if not ok or not success then error("JBS 启动未完成: "..tostring(failure),0) end
 return WindUI
end

end
return loadGame()(loadLibrary())
