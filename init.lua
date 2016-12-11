_DEBUG = false -- True for enable debug message. False for disable it.
station_cfg = {}
station_cfg.ssid = ""
station_cfg.pwd = ""
station_cfg.bssid = "" -- If you have many same SSID in the area Please fill this with MAC Address. You should delete or comment this if you have only one SSID.
startupmode = "OTA" -- Default : "OTA"
OTA_version_link = "http://foo.bar/version.html" -- Version file URL
OTA_startup_link = "http://foo.bar/startup.lua" -- Startup file URL

function launchstartup()
	-- Wait for all request done or you will get error message from HTTP Client.
	tmr.alarm(3, 300, tmr.ALARM_SINGLE,function()
		wifi.sta.disconnect()
	end)
	collectgarbage()
	dofile("startup.lua")
end

function startup()
    if startupmode == "abort" then
        if _DEBUG then print("Aborted all process.") end
        collectgarbage()
        return
    elseif startupmode == "skip" then
        collectgarbage()
        if not file.exists("startup.lua") then
            if _DEBUG then print("Startup script not found.") end
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
		
		get_version_data = nil
		startup_data = nil
		download_version = nil
		
		-- Request for version file. Version file timer must more than startup file timer or it will crash.
		tmr.alarm(1, 500, tmr.ALARM_AUTO, function()
			if wifi.sta.getip() ~= nil then
				node.task.post(function()
					http.get(OTA_version_link, nil, function(code, get_version_data)
						if code == 200 and get_version_data ~= installed_version then
							download_version = get_version_data
							is_need_update = true
							if _DEBUG then print("New version found. Updating") end
							tmr.stop(1)
						elseif get_version_data == installed_version then
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
				)
			end
		end
		)
		
		-- Request for startup file.
		tmr.alarm(2, 1000, tmr.ALARM_AUTO, function()
			if is_need_update == true then
				node.task.post(function()
				http.get(OTA_startup_link, nil, function(code, startup_data)
					if code == 200 and startup_data ~= nil then
						file.open("startup.lua", "w")
						file.write(startup_data)
						file.close()
						file.open("version.txt", "w")
						file.write(download_version)
						file.close()
						if _DEBUG then print("Update completed. Running startup file.") end
						tmr.stop(2)
						launchstartup()
					else
						if _DEBUG then print("Couldn't Download startup file. Restarting.") end
						tmr.stop(2)
						launchstartup()
					end
				end
				)
				end
				)
			end
		end
		)
	end
end

if _DEBUG then print("Launching OTA in 3 seconds.") end
if _DEBUG then print("Type startupmode=\"abort\" for abort.") end
if _DEBUG then print("Type startupmode=\"skip\" for skipping OTA.") end
tmr.alarm(0, 3000,tmr.ALARM_SINGLE, startup)
