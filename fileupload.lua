-- {version: "1.0.0"}
local module =...
    return function(conn, pname)
		CHUNKSIZE = 256
        MAXNAMELEN = 18
        local buf
        local fname = string.sub(pname, 1, MAXNAMELEN)
        tmr.wdclr()
        if file.exists(fname) then
			s, e = string.find(string.reverse(fname), ".", 1, true)
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
				cprint("unloading fileupload", 0)
            end
            module = nil
		end

        conn:on ("sent",
            function(sck)
                function sendfile(sck)
					local f = getFileObject(sck, fname, "r")
                    buf = f:read(CHUNKSIZE)
                    if buf ~= nil then 
                        cprint("sent " .. #buf .. " bytes, heap: " .. node.heap(), 4)
                        sck:send(buf)
                    else
						closeFileObject(sck, fname)
                        cprint("file:read returned nil, closed file heap: " .. node.heap(), 2)
                        sck:close()
						unloadModule()
                        return
                    end
                end
                sck:on("sent", sendfile)
                sck:on("disconnection",
                    function(sck)
                        cprint("disconnection fileupload.sendfile, heap: " .. node.heap(), 0)
						closeFileObject(sck, fname)
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