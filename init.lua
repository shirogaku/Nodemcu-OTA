station_cfg = {}
station_cfg.ssid = ""
station_cfg.pwd = ""
station_cfg.bssid = ""
startupmode = "skip"
OTA_version_link = "http://foo.bar/version.html"
OTA_startup_link = "http://foo.bar/startup.lua"

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
		is_version_check_done = false
		-- HTTP get is asynchronous need to fix this
        http.get(OTA_version_link, nil, function(code, data)
            if code == 200 and data ~= installed_version then
                download_version = data
                print("New version found. Updating")
				is_need_update = true
				is_version_check_done = true
            elseif data == installed_version then
                print("Current version is lastest. Restarting")
                node.restart()
            else
                print("Version file not found. Restarting")
                node.restart()
            end
        end
        )
		
		tmr.alarm(1, 2000, tmr.ALARM_SINGLE, function()
		    if is_need_update then
                print("Here!!!")
                http.get(OTA_startup_link, nil, function(code, data)
                if code == 200 and data ~= nil then
                    file.open("startup.lua", "w")
                    file.write(data)
                    file.close()
                    file.open("version.txt", "w")
                    file.write(download_version)
                    file.close()
                    print("Update completed. Restarting")
                else
                    print("Couldn't Download startup file. Restarting")
                end
                    node.restart()
                end
                )
            end
		end)
        print("Outside update condition")
    end
end

print("Luanching startup script in 5 seconds.")
print("Type startupmode=\"abort\" for abort")
print("Type startupmode=\"OTA\" for running OTA and run startup script.")
tmr.alarm(0, 5000,tmr.ALARM_SINGLE, startup)
