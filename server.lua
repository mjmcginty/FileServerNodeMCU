-- {"version": "1.0.0"}
contentTypeHtml = "\r\nContent-type: text/html"
contentTypeBin = "\r\nContent-type: application/octet-stream"
contentTypeImage = "\r\nContent-type: image/jpg"
headerBlock = "\r\nConnection: close\r\nServer: ESPServer\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-cache\r\n\r\n"
local currentFileName = ""
local isPostData = false
local retval = ""
local success = "{ \"status\": \"success\", \"bytes\": "
local option
local isResetting = false
cprint("* * * filexfer server is online * * *", 0)
activeClients = {}

function getFreeHeapHeader() 
	return "\r\nFreeHeap: " .. node.heap()
end

function getFileObject(sck, fileName, mode)
	local port, ip = sck:getpeer()
	if (activeClients[ip] == nil) then
		activeClients[ip] = {}
		cprint("creating active client for " .. ip, 2)
	end
	if (activeClients[ip][fileName] == nil) then
		activeClients[ip][fileName] = file.open(fileName, mode)
		cprint("opening file handle " .. fileName, 3)
	end
	return activeClients[ip][fileName]
end

function closeFileObject(sck, fileName)
	local port, ip = sck:getpeer()
	if (activeClients[ip] ~= nil) then
		if (activeClients[ip][fileName] ~= nil) then
			activeClients[ip][fileName]:close()
			activeClients[ip][fileName] = nil
			cprint("closing file handle " .. fileName, 3)
		end 
	end
end

local srv=net.createServer(net.TCP, 60) 
srv:listen(80,
    function(conn) 
		assignHandlers(conn)
    end
)

function assignHandlers(conn)
        conn:on("disconnection", disconnection)
        conn:on("sent", sent)
        conn:on("receive", receive)
end

local function getfilesize(name)
	local stat = file.stat(name)
	local tempbuf = ""
	if stat then
		tempbuf = stat.size
		cprint(name .. " " .. stat.size, 2)
	end
	return tempbuf
end

local function writefile(sck, name, mode, data)
	local f = getFileObject(sck, "t_" .. name, mode)
    if (f == nil) then
        return -1
    end
    f:write(data)
    closeFileObject(sck, "t_" .. name)
	f = nil
	return success.. getfilesize("t_" .. name).. "}"
end

local function processOption(name, opt, isComplete)
	if (#name > 18) then
		return false
	end
	if (file.exists(name) == false) then
		retval = success .. "}"
		return true
	end

	if (opt == "Backup") then
		if (isComplete == true) then
			s, e = string.find(string.reverse(name), ".", 1, true)
			local ext = string.sub(name, -s)
			local buName = string.sub(name, 1, -(s + 1)) .. "(1)" .. ext
			cprint(buName, 2)

			if (file.exists(buName)) then
				file.remove(buName)
			end
			file.rename(name, buName)
		end
		retval = success  .. getfilesize(name) .. "}"
		return true
	end
	if (opt == "Overwrite") then
		if (isComplete == true) then
			file.remove(name)
		end
		retval = success .. "}"
		return true
	end
	if (opt == "Ignore") then
		retval = success .. "}"
		return true
	end
	if (opt == "Abort") then
		retval = "\"error file exists\"}"
		return false
	end
end

function disconnection(conn) 
	cprint("disconnection", 1)
    isPostData = false
end

function sent(conn) 
	if (isPostData ~= true) then
		currentFileName = ""
		isPostData = false
		if (conn ~= nil) then 
			conn:close()
		end
		cprint("onsent closing connection", 1)
	else
		if (conn ~= nil) then 
			conn:close()
		end
	end
end

function receive(conn, payload)
    tmr.wdclr();
    local s, e, m, buf, k, v
    local tbl = {}
    local i = 1
	local method

	s, e = string.find(payload, "HTTP", 1, true)
    if (isPostData and (e == nil)) then
        retval = writefile(conn, currentFileName, "a+", payload)
		cprint("ispostdata raw data" .. #payload, 4)
		payload = nil
		--isPostData = false
		cprint("sending status 100", 4)
		buf = "HTTP/1.1 100 CONTINUE" .. contentTypeHtml .. getFreeHeapHeader() .. headerBlock
		conn:send(buf)
		return
    else
        if e ~= nil then
            buf = string.sub(payload, 1, s - 2)
            for m in string.gmatch(buf, "/?([%w+%p+][^/+]*)") do
                tbl[i] = m
				cprint(i .. " " .. m, 5)
                i = i + 1
            end
            m = nil
			method = tbl[1]
			cprint(#tbl .. " " .. method, 1)

            if tbl[2] == "api" then
                local cmd = tbl[3]
                if (tbl[4] ~= nil) and (tbl[4] ~= "/") then
                    currentFileName = tbl[4]
                end
				if (tbl[5] ~= nil) then
                    option = tbl[5]
                end
				-- option is always the last parameter, 
				-- for rename it will be at index 5
				if (tbl[6] ~= nil) then
                    option = tbl[6]
                end

				cprint("cmd " .. cmd, 1)
				if (cmd == "restart") then
					retval = "apparent failure"
					isResetting = true
					node.restart()
					return
				end
				
				if (cmd == "heap") then
					retval = node.heap()
				end
				
				if (cmd == "dofile") then
					retval = dofile(currentFileName)
				end

                if (cmd == "send") then
					if (#currentFileName > 18) then
						buf = "HTTP/1.1 409 INVALID FILE NAME" .. contentTypeHtml .. getFreeHeapHeader() .. headerBlock
						conn:send(buf)
						return
					end
					if (processOption(currentFileName, option, false)) then
						retval = writefile(conn, currentFileName, "w+", "")
						cprint(retval, 2)
					else
						buf = "HTTP/1.1 403 FILE EXISTS" .. contentTypeHtml .. getFreeHeapHeader() .. headerBlock
						conn:send(buf)
						return
					end
                end

                if (cmd == "append") then
			        s, e = string.find(payload, "\r\n\r\n", 1, true)
					cprint("payload length " .. #payload, 4)
					isPostData = true
					if e ~= nil then
						buf = string.sub(payload, s + 4)
						cprint("data length " .. #buf .. " " .. s .. ' ' .. e, 5)
						if #buf > 0 then
							retval = writefile(conn, currentFileName, "a+", buf)
							cprint(retval, 3)
						else
							isPostData = false
						end
					--else
					--	retval = writefile(conn, currentFileName, "a+", payload)
					end
                end

                if (cmd == "persist") then
					if (processOption(currentFileName, option, true)) then
	                    file.rename("t_" .. currentFileName, currentFileName)
						retval = success.. getfilesize(currentFileName).. "}"
					end
                end
				if (cmd == "rename") then
					if (processOption(tbl[5], option, true)) then
	                    file.rename(currentFileName, tbl[5])
					end
                end

				if (cmd == "delete") then
                    file.remove(currentFileName)
                end

				if (cmd == "list") then
                    -- get list of files and send to client
					local listBuf = "[{\"name\":\".\",\"size\": 0}"
					l = file.list();
					for k,v in pairs(l) do
						listBuf = listBuf..",{\"name\":\""..k.."\",\"size\":"..v.."}"
					end
					listBuf = listBuf.."]"

					buf = "HTTP/1.1 200 OK" .. contentTypeHtml .. getFreeHeapHeader() .. headerBlock .. listBuf
					conn:send(buf)
					payload = nil
					tbl = nil
					l = nil
					listBuf = nil
					return
                end

				if (cmd == "version") then
					local f = getFileObject(conn, currentFileName, "r")
	                f:seek("set", 2)
					buf = "HTTP/1.1 200 OK" .. contentTypeHtml .. getFreeHeapHeader() .. headerBlock .. f:readline()
					closeFileObject(conn, currentFileName)
					f = nil
					conn:send(buf)
					payload = nil
					tbl = nil
					return
                end

                buf = ""
                if retval == nil then
                    retval = "[nil]"
                end
            else
				-- if no command was present the client wants to download an existing file.  
				-- default document name is hard-coded in the line below
                local filename = "index.html"
                if tbl[2] ~= nil and tbl[2] ~= "/" then
                    filename = tbl[2]
                end
				closeFileObject(conn, filename)
				cprint("calling upload " .. filename, 1)
                require("fileupload")(conn, filename)
				buf = nil
				payload = nil
				tbl = nil
				return
            end
        end
    end
    buf = "HTTP/1.1 200 OK" .. contentTypeHtml.. getFreeHeapHeader() .. headerBlock .. retval
	payload = nil
	tbl = nil
	if isResetting == false then
		conn:send(buf)
	end
end
