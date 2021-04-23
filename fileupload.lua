-- {version: "1.0.1"}
local module =...
	return function(conn, pname)
		local CHUNKSIZE = 256
		local MAXNAMELEN = 18
		local buf
		local _port, _ip = conn:getpeer()
		local fname = string.sub(pname, 1, MAXNAMELEN)
		if (currentCPU == "8266") then
			tmr.wdclr();
		end

		if file.exists(fname) then
			local s, e = string.find(string.reverse(fname), ".", 1, true)
			local ext = string.lower(string.sub(fname, -(s - 1)))
			cprint(ext, 1)
			local contentType

			if (ext == "html" or ext == "htm" or ext == "js"  or ext == "json" or ext == "txt") then
				contentType = contentTypeHtml
			elseif (ext == "jpg" or ext == "png" or ext == "bmp" or ext == "ico" or ext == "gif" or ext == "jpeg") then
				contentType = contentTypeImage
			else 
				contentType = contentTypeBin
			end

			buf = "HTTP/1.1 200 OK" .. contentType .. headerBlock
		else
			fname = "error404.html"
			buf = "HTTP/1.1 404 FILE NOT FOUND" .. contentTypeHtml .. headerBlock
		end

		local function unloadModule()
			if module ~= nil then
				package.loaded[module] = nil
				cprint("unloading fileupload" .. _ip .. _port, 0)
			end
			module = nil
		end

		local fileOpenFailCount = 0

		conn:on ("sent",
			function(sck)
				function sendfile(sck)
					local f = getFileObject(nil, fname, "r", _ip, _port)
					if (f ~= nil) then
						fileOpenFailCount = 0
						buf = f:read(CHUNKSIZE)
					else
						-- file has already been found to exist, if the file object is
						-- nil something went very wrong, so by sending an empty response 
						-- this function will get called again.  but we don't want to let 
						-- it loop endlessly, so count errors, and close out if too many.
						fileOpenFailCount = fileOpenFailCount + 1
						if (fileOpenFailCount > 5) then
							buf = nil
							fileOpenFailCount = 0
							cprint("failed 5 times to open file " .. fname, 1)
						else
							cprint("failed to open file " .. fname .. " sending empty response", 2)
							buf = ""
						end
					end
					if buf ~= nil then 
						cprint("sent " .. #buf .. " bytes, heap: " .. node.heap(), 4)
						sck:send(buf)
					else
						closeFileObject(nil, fname, _ip, _port)
						cprint("file:read returned nil, closing connection, heap: " .. node.heap(), 2)
						sck:close()
						unloadModule()
						return
					end
				end
				sck:on("sent", sendfile)
				sck:on("disconnection",
					function(sck)
						cprint("disconnection fileupload.sendfile, heap: " .. node.heap(), 0)
						print(sck)
						closeFileObject(nil, fname, _ip, _port)
						unloadModule()
						return
					end
				)
				sendfile(sck)
			end
		)
		conn:on ("receive",
			function(sck, pl)
				cprint("received data closing connection, heap: " .. node.heap(), 0)
				sck:close()
			end
		)
		if buf == nil then
			buf = ""    
		end
		conn:send(buf)
	end