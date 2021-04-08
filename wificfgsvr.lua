-- {"version": "1.0.0"}
local module =...
	return function()
		cprint("[wificfgsvr.lua]", initStage, 1)
		----cprint(node.heap(), 2) 
		if (initStage == 0) then
			--cprint("[wifi.setmode]", 3)
			wifi.setmode(wifi.STATIONAP)
			if (cfg.Mode == "AP") then
				nextCfgStep = 5
			else
				nextCfgStep = 1
			end
			initStage = nextCfgStep
			return
		end
		if (initStage == 1) then
			if cfg.WiFiPwd == nil then
				cfg.WiFiPwd = ""
			end
			local staconfig = {}
			staconfig.ssid = cfg.StationWiFiSSID
			staconfig.pwd = cfg.StationWiFiPwd
			wifi.sta.config(staconfig)
			initStage = 2
			return
		end
		if (initStage == 2) then
			--cprint("[wifi.connect]", 3)
			wifi.sta.connect()
			initStage = 3
			return
		end
		if (initStage == 3) then
			ip = wifi.sta.getip()
			initStage = 4
			return
		end

		if initStage == 4 then
			if ip ~= nil then
				initStage = 5
				cprint(ip, 0)
				tmrSvrCfg:unregister()
				node.task.post(function()
					dofile("server.lua")
				end)
				return
			else
				--cprint("[no sta ip]", 5)
				initStage = 1
				failureCnt = failureCnt + 1
				if failureCnt > 10 then
					node.restart()
				end
				return
			end
		end

		if initStage == 5 then
			--cprint("[AP config]", 5)
			local wificfg={
				ssid = cfg.APServerSSID,
				auth = AUTH_OPEN,
				channel = cfg.APServerChannel}

			if cfg.APServerPwd ~= nil then
				if #cfg.APServerPwd >= 10 then
					wificfg.pwd = cfg.APServerPwd
				end
			end
			wifi.ap.config(wificfg)
			initStage = 6
			wificfg = nil
			return
		end

		if initStage == 6 then
			--cprint("[server ip]", 5)
			local ipcfg =  {
				ip=cfg.APServerIP,
				netmask="255.255.255.0",
				gateway=cfg.APServerIP}
			wifi.ap.setip(ipcfg)
			initStage = 7
			return
		end

		if initStage == 7 then
			serverip= wifi.ap.getip()
			cprint("[server ip]: ",serverip, 1)
			if serverip ~= nil then
				tmrSvrCfg:unregister()
				initStage = 0
				cprint("[ready to connect]", node.heap(), 1)

				failureCnt = 0
				node.task.post(function()
					dofile("server.lua")
				end)
				if module then
					package.loaded[module] = nil
					module = nil
				end

				return

		--		wifi.sta.getap(
		--			function(t) 
		--				local k, v
		--				local i = 0
		--				for k,v in pairs(t) do
		--					cprint("cfgsvr", k, v, 5)
		--					aplist[i] = k
		--					i = i + 1
		--				end
		--			end
		--		)
			else
				initStage = 5
				failureCnt = failureCnt + 1
				if failureCnt > 10 then
					node.restart()
				end
				--cprint("no server ip", 5)
			end
		end
	end
