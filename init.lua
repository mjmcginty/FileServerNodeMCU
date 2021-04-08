--,init,lua,1,0,1,0

dofile("_init.lua")

dofile("cfg.lua")

-- Last argument MUST be numeric, debug level
function cprint(...)
	local arglist = {...}
	local level = arglist[#arglist]
	if level <= cfg.DebugLevel then
		print(...)
	end
end

ip = nil
serverip = nil
initStage = 0
failureCnt = 0
versions = nil

--aplist = {}
cfg.APMac = wifi.ap.getmac()
tmrSvrCfg = tmr.create()
tmrSvrCfg:alarm(4000, tmr.ALARM_AUTO, require("wificfgsvr"))


