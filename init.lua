_DEBUG = true -- True for enable debug message. False for disable it.
station_cfg = {}
station_cfg.ssid = ""
station_cfg.pwd = ""
--station_cfg.bssid = "" -- If you have many same SSID in the area Please fill this with MAC Address. You should delete this if you have only one SSID.
startupmode = "OTA"
OTA_version_link = "http://foo.bar/version.txt"
OTA_startup_link = "http://foo.bar/startup.lua"

function launchstartupOTASuccess()
	tmr.stop(0)
	wifi.sta.disconnect()
	collectgarbage()
	dofile("startup.lua")
end

function launchstartupOTAFail()
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
            return
        else
            if _DEBUG then print("Launching startup script.") end
            dofile("startup.lua")
        end
    else
        if _DEBUG then print("Begin OTA Update.") end
        if not file.exists("version.txt") or not file.exists("startup.lua") then
            if _DEBUG then print("Creating version file and startup file.") end
            file.open("version.txt", "w")
            file.writeline("1")
            file.close()
            file.open("startup.lua", "w")
            file.write("print(\"This is dummy script. Please upload script as startup.lua\")")
            file.close()
        else
            file.open("version.txt","r")
            installed_version = file.readline()
            file.close()
        end
        
		is_need_update = false
		get_version_data = nil
		startup_data = nil
		download_version = nil
		
        wifi.setmode(wifi.STATION, false)
		wifi.sta.eventMonReg(wifi.STA_GOTIP,function()
			node.task.post(function()
				http.get(OTA_version_link, nil, function(code, get_version_data)
				if code == 200 and get_version_data ~= installed_version then
					download_version = get_version_data
					is_need_update = true
					if _DEBUG then print("New version found. Updating") end
					if get_version_data == installed_version then
						if _DEBUG then print("Installed version is lastest. Running startup file.") end 
						launchstartupOTASuccess()
					else
						if _DEBUG then print("Version file not found. Running startup file.") end
						launchstartupOTASuccess()
					end
				else
					if _DEBUG then print("OTA service unavailable. Running startup file.") end
					launchstartupOTASuccess()
				end
			end
			)
		end
		)
			
			tmr.alarm(0, 1000, tmr.ALARM_AUTO, function()
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
								launchstartupOTASuccess()
							else
								if _DEBUG then print("Couldn't Download startup file. Restarting.") end
								launchstartupOTASuccess()
							end
						end
						)
					end
					)
				end
			end
			)
		end)
		
		wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function()
			if _DEBUG then print("Wrong password. Running startup file.") end
			launchstartupOTAFail()
		end)
		
		wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function()
			if _DEBUG then print("Access point not found. Running startup file.") end
			launchstartupOTAFail()
		end)
		
		wifi.sta.eventMonReg(wifi.STA_FAIL, function()
			if _DEBUG then print("Failed to connect. Running startup file.") end
			launchstartupOTAFail()
		end)
		
		wifi.sta.eventMonStart()
		wifi.sta.config(station_cfg)
	end
end

if _DEBUG then print("Launching OTA in 3 seconds.") end
if _DEBUG then print("Type startupmode=\"abort\" for abort.") end
if _DEBUG then print("Type startupmode=\"skip\" for skipping OTA.") end
tmr.alarm(0, 3000,tmr.ALARM_SINGLE, startup)
