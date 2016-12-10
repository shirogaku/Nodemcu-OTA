station_cfg = {}
station_cfg.ssid = ""
station_cfg.pwd = ""
station_cfg.bssid = ""
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
        print("Aborted all process.")
        collectgarbage()
        return
    elseif startupmode == "skip" then
        collectgarbage()
        if not file.exists("startup.lua") then
            print("Startup script not found.")
            file.close()
            return
        else
            print("Launching startup script.")
            dofile("startup.lua")
        end
    else
        print("Begin OTA Update.")
        if file.exists("version.txt") then
            file.open("version.txt","r")
            installed_version = file.readline()
            file.close()
        else
            print("Creating version file and startup file.")
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
		
		tmr.alarm(1, 2000, tmr.ALARM_SINGLE, function()
			http.get(OTA_version_link, nil, function(code, data)
				if code == 200 and data ~= installed_version then
					download_version = data
					print("New version found. Updating")
					is_need_update = true
				elseif data == installed_version then
					print("Installed version is lastest. Running startup file.")
					launchstartup()
				else
					print("Version file not found. Running startup file")
					launchstartup()
				end
			end
			)	
		end)
		
		tmr.alarm(2, 5000, tmr.ALARM_SINGLE, function()
		    if is_need_update then
                http.get(OTA_startup_link, nil, function(code, data)
					if code == 200 and data ~= nil then
						file.open("startup.lua", "w")
						file.write(data)
						file.close()
						file.open("version.txt", "w")
						file.write(download_version)
						file.close()
						print("Update completed. Running startup file.")
						launchstartup()
					else
						print("Couldn't Download startup file. Restarting.")
						launchstartup()
					end
                end
                )
            end
		end)
    end
end

print("Launching OTA in 5 seconds.")
print("Type startupmode=\"abort\" for abort.")
print("Type startupmode=\"skip\" for skipping OTA.")
tmr.alarm(0, 5000,tmr.ALARM_SINGLE, startup)
