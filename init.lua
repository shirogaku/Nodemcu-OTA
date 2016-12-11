_DEBUG = false
station_cfg = {}
station_cfg.ssid = ""
station_cfg.pwd = ""
station_cfg.bssid
startupmode = "OTA"
OTA_version_link = "http://foo.bar/version.html"
OTA_startup_link = "http://foo.bar/startup.lua"

function launchstartup()
	wifi.sta.disconnect()
	collectgarbage()
	dofile("startup.lua")
end 

function startup()
    if startupmode == "abort" then
        if _DEBUG then if _DEBUG then print("Aborted all process.") end end
        collectgarbage()
        return
    elseif startupmode == "skip" then
        collectgarbage()
        if not file.exists("startup.lua") then
            if _DEBUG then if _DEBUG then print("Startup script not found.") end end
            file.close()
            return
        else
            if _DEBUG then print("Launching startup script.") end
            dofile("startup.lua")
        end
    else
        if _DEBUG then print("Begin OTA Update.") end
        if file.exists("version.txt") then
            file.open("version.txt","r")
            installed_version = file.readline()
            file.close()
        else
            if _DEBUG then print("Creating version file and startup file.") end
            file.open("version.txt", "w")
            file.writeline("1")
            file.close()
            file.open("startup.lua", "w")
            file.write("print(\"This is dummy script. Please upload script as startup.lua\")")
            file.close()
        end
        
        wifi.setmode(wifi.STATION)
        wifi.sta.config(station_cfg)
		
		
		is_need_update = false
		
		node.task.post(node.task.HIGH_PRIORITY, function()
			tmr.alarm(1, 200, tmr.ALARM_AUTO, function()
				if wifi.sta.getip() ~= nil then
					http.get(OTA_version_link, nil, function(code, data)
						if code == 200 and data ~= installed_version then
							download_version = data
							is_need_update = true
							if _DEBUG then print("New version found. Updating") end
							tmr.stop(1)
						elseif data == installed_version then
							if _DEBUG then print("Installed version is lastest. Running startup file.") end
							tmr.stop(1)
							tmr.stop(2)
							launchstartup()
						else
							if _DEBUG then print("Version file not found. Running startup file") end
							tmr.stop(1)
							tmr.stop(2)
							launchstartup()
						end
					end
					)
				end
			end
			)
		end)
		
		node.task.post(node.task.LOW_PRIORITY, function()
			tmr.alarm(2, 200, tmr.ALARM_AUTO, function()
				if is_need_update == true then
					http.get(OTA_startup_link, nil, function(code, data)
						if code == 200 and data ~= nil then
							file.open("startup.lua", "w")
							file.write(data)
							file.close()
							file.open("version.txt", "w")
							file.write(download_version)
							file.close()
							if _DEBUG then print("Update completed. Running startup file.") end
							tmr.stop(2)
							launchstartup()
						else
							print("Couldn't Download startup file. Restarting.")
							tmr.stop(2)
							launchstartup()
						end
					end
					)
				end
			end
			)
		end)
	end
end

if _DEBUG then print("Launching OTA in 3 seconds.") end
if _DEBUG then print("Type startupmode=\"abort\" for abort.") end
if _DEBUG then print("Type startupmode=\"skip\" for skipping OTA.") end
tmr.alarm(0, 3000,tmr.ALARM_SINGLE, startup)
