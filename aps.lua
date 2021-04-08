aplist = {}

wifi.sta.getap(
					function(t) 
						local k, v
						local i = 0
						for k,v in pairs(t) do
							cprint("cfgsvr", k, v)
							aplist[i] = k
							i = i + 1
						end
					end
				)