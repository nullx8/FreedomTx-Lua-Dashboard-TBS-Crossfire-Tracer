----------------------------------------------------------
-- Updated by Mario Hennenberger
-- from: https://github.com/nullx8/FreedomTx-Lua-Dashboard-TBS-Crossfire
--
-- Initial release by Farley Farley
-- fetched from : https://github.com/AndrewFarley/Taranis-XLite-Q7-Lua-Dashboard
----------------------------------------------------------


------- GLOBALS -------
-- The model name when it can't detect a model name from the handset

local modelName = "Unknown"
local oldTime={0,0,0,0,0,0}
local Time={0,0,0,0,0,0}

local lowVoltage = 13.8
local currentVoltage = 14.0
local highVoltage = 16.8
-- For our timer tracking
local timerLeft = 0
local maxTimerValue = 0
-- For armed drawing
local armed = 0
-- For mode drawing
local mode = 0
-- Animation increment
local animationIncrement = 0
-- is off trying to go on...
local isArmed = 0
-- Our global to get our current rssi
local rssi = 0
-- For debugging / development
local lastMessage = "None"
local lastNumberMessage = "0"
local lastsaynbattpercent=200
local lasttopspeed=0
local lastCapa=0
local lastMaxAmp=0

-- Batt
local max_batt = 4.2
local min_batt = 3.3
local total_max_bat = 0
local total_min_bat = 5
local total_max_curr = 0

------- HELPERS -------
function round(num, decimals)
  local mult = 10^(decimals or 0)
  return math.floor(num * mult + 0.5) / mult
end

-- A little animation / frame counter to help us with various animations
local function setAnimationIncrement()
  animationIncrement = math.fmod(math.ceil(math.fmod(getTime() / 100, 2) * 8), 4)
end

local function checkForNewBattery()
  if getValue('Capa') > 0 and getValue('Capa') < 2 then
    -- if capacity used below 2 but not zero we just assume the battery has ben changed
	-- reset helper tmp values
	lastsaynbattpercent = 200 -- makes sure battery is bigger than possible to allow rewrite by battery function
	lasttopspeed = 0 -- reset last recorded top speed to 0
    lastCapa =0 -- reset battery usage
  end
end

local function SayBattPercent(battp)  
  if (battp =="") then
    battp = 0
  end
  if (battp < (lastsaynbattpercent-5)) then --only say in 10 % steps

    Time[6] = Time[6] + (getTime() - oldTime[6]) 
        
    if Time[6]> 700 then --and only say if battpercent 10 % below for more than 10sec
      Time[6] = 0
      if (battp ~=0) then
        lastsaynbattpercent=battp
        playNumber(lastsaynbattpercent, 13, 0)
        if lastsaynbattpercent <= 10 then 
          playFile("batcrit.wav") 
        end
      end
    end
    oldTime[6] = getTime() 

  else    
    Time[6] = 0
    oldTime[6] = getTime() 
    if battp < 20 then 
      playFile("batcrit.wav") 
    end
  end
end

-- Sexy voltage helper
local function drawTransmitterVoltage(start_x,start_y,voltage)
  
  local batteryWidth = 12
  
  -- Battery Outline
  lcd.drawRectangle(start_x, start_y, batteryWidth + 2, 6, SOLID)
  lcd.drawLine(start_x + batteryWidth + 2, start_y + 1, start_x + batteryWidth + 2, start_y + 4, SOLID, FORCE) -- Positive Nub

  -- Battery Percentage (after battery)
  local curVolPercent = getValue('Bat_')
  if curVolPercent < 20 then
    lcd.drawText(start_x + batteryWidth + 5, start_y, curVolPercent.."%", SMLSIZE + BLINK)
  else
    if curVolPercent == 100 then
      lcd.drawText(start_x + batteryWidth + 5, start_y, "99%", SMLSIZE)
    else
      lcd.drawText(start_x + batteryWidth + 5, start_y, curVolPercent.."%", SMLSIZE)
    end
      
  end
  
  -- Filled in battery
  local pixels = math.ceil((curVolPercent / 100) * batteryWidth)
  if pixels == 1 then
    lcd.drawLine(start_x + pixels, start_y + 1, start_x + pixels, start_y + 4, SOLID, FORCE)
  end
  if pixels > 1 then
    lcd.drawRectangle(start_x + 1, start_y + 1, pixels, 4)
  end
  if pixels > 2 then
    lcd.drawRectangle(start_x + 2, start_y + 2, pixels - 1, 2)
    lcd.drawLine(start_x + pixels, start_y + 2, start_x + pixels, start_y + 3, SOLID, FORCE)
  end
end

local function drawFlightTimer(start_x, start_y)
  local timerWidth = 44
  local timerHeight = 20
  local myWidth = 0
  local percentageLeft = 0
  
  lcd.drawRectangle( start_x, start_y, timerWidth, 10 )
  lcd.drawText( start_x + 2, start_y + 2, "Arm Time", SMLSIZE )
  lcd.drawRectangle( start_x, start_y + 10, timerWidth, timerHeight )

  if timerLeft < 0 then
    lcd.drawRectangle( start_x + 2, start_y + 20, 3, 2 )
    lcd.drawText( start_x + 2 + 3, start_y + 12, (timerLeft * -1).."s", DBLSIZE + BLINK )
  else
    lcd.drawTimer( start_x + 2, start_y + 12, timerLeft, DBLSIZE )
  end 
  
  percentageLeft = (timerLeft / maxTimerValue)
  local offset = 0
  while offset < (timerWidth - 2) do
    if (percentageLeft * (timerWidth - 2)) > offset then
      -- print("Percent left: "..percentageLeft.." width: "..myWidth.." offset: "..offset.." timerHeight: "..timerHeight)
      lcd.drawLine( start_x + 1 + offset, start_y + 11, start_x + 1 + offset, start_y + 9 + timerHeight - 1, SOLID, 0)
    end
    offset = offset + 1
  end
  
end

local function drawTime()
  -- Draw date time
  local datenow = getDateTime()
  local min = datenow.min .. ""
  if datenow.min < 10 then
    min = "0" .. min
  end
  local hour = datenow.hour .. ""
  if datenow.hour < 10 then
    hour = "0" .. hour
  end
  if math.ceil(math.fmod(getTime() / 100, 2)) == 1 then
    hour = hour .. ":"
  end
  lcd.drawText(107,0,hour, SMLSIZE)
  lcd.drawText(119,0,min, SMLSIZE)
end

local function drawRSSI(start_x, start_y)
  local timerWidth = 44
  local timerHeight = 15
  local myWidth = 0
  local percentageLeft = 0
  
  lcd.drawRectangle( start_x, start_y, timerWidth, 10 )
  lcd.drawText( start_x + 2, start_y + 2, "L:", SMLSIZE)
  if rssi < 80 then
    lcd.drawText( start_x + 9, start_y + 2, rssi, SMLSIZE + BLINK)
    lcd.drawText( start_x + 25, start_y + 2, getValue('TQly'), SMLSIZE + BLINK)
  else
    lcd.drawText( start_x + 9, start_y + 2, rssi, SMLSIZE)
  end
  lcd.drawRectangle( start_x, start_y + 10, timerWidth, timerHeight )


  
  if rssi > 0 then
    lcd.drawLine(start_x + 1,  start_y + 20, start_x + 1,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 2,  start_y + 20, start_x + 2,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 3,  start_y + 20, start_x + 3,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 4,  start_y + 20, start_x + 4,  start_y + 23, SOLID, FORCE)
  end
  if rssi > 10 then
    lcd.drawLine(start_x + 5,  start_y + 19, start_x + 5,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 6,  start_y + 19, start_x + 6,  start_y + 23, SOLID, FORCE)
  end
  if rssi > 13 then
    lcd.drawLine(start_x + 7,  start_y + 19, start_x + 7,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 8,  start_y + 19, start_x + 8,  start_y + 23, SOLID, FORCE)
  end
  if rssi > 16 then
    lcd.drawLine(start_x + 9,  start_y + 18, start_x + 9,  start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 10, start_y + 18, start_x + 10, start_y + 23, SOLID, FORCE)
  end
  if rssi > 19 then
    lcd.drawLine(start_x + 11, start_y + 18, start_x + 11, start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 12, start_y + 18, start_x + 12, start_y + 23, SOLID, FORCE)
  end
  if rssi > 22 then
    lcd.drawLine(start_x + 13, start_y + 17, start_x + 13, start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 14, start_y + 17, start_x + 14, start_y + 23, SOLID, FORCE)
  end
  if rssi > 25 then
    lcd.drawLine(start_x + 15, start_y + 17, start_x + 15, start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 16, start_y + 17, start_x + 16, start_y + 23, SOLID, FORCE)
  end
  if rssi > 28 then
    lcd.drawLine(start_x + 17, start_y + 16, start_x + 17, start_y + 23, SOLID, FORCE)
    lcd.drawLine(start_x + 18, start_y + 16, start_x + 18, start_y + 23, SOLID, FORCE)
  end
  if rssi > 31 then
    lcd.drawLine(start_x + 19, start_y + 16, start_x + 19, start_y + 23, SOLID, FORCE)
  end
  if rssi > 34 then
    lcd.drawLine(start_x + 20, start_y + 16, start_x + 20, start_y + 23, SOLID, FORCE)
  end
  if rssi > 37 then
    lcd.drawLine(start_x + 21, start_y + 15, start_x + 21, start_y + 23, SOLID, FORCE)
  end
  if rssi > 40 then
    lcd.drawLine(start_x + 22, start_y + 15, start_x + 22, start_y + 23, SOLID, FORCE)
  end
  if rssi > 43 then
    lcd.drawLine(start_x + 23, start_y + 15, start_x + 23, start_y + 23, SOLID, FORCE)
  end
  if rssi > 46 then
    lcd.drawLine(start_x + 24, start_y + 15, start_x + 24, start_y + 23, SOLID, FORCE)
  end
  if rssi > 49 then
    lcd.drawLine(start_x + 25, start_y + 14, start_x + 25, start_y + 23, SOLID, FORCE)
  end
  if rssi > 52 then
    lcd.drawLine(start_x + 26, start_y + 14, start_x + 26, start_y + 23, SOLID, FORCE)
  end
  if rssi > 55 then
    lcd.drawLine(start_x + 27, start_y + 14, start_x + 27, start_y + 23, SOLID, FORCE)
  end
  if rssi > 58 then
    lcd.drawLine(start_x + 28, start_y + 14, start_x + 28, start_y + 23, SOLID, FORCE)
  end
  if rssi > 61 then
    lcd.drawLine(start_x + 29, start_y + 13, start_x + 29, start_y + 23, SOLID, FORCE)
  end
  if rssi > 64 then
    lcd.drawLine(start_x + 30, start_y + 13, start_x + 30, start_y + 23, SOLID, FORCE)
  end
  if rssi > 67 then
    lcd.drawLine(start_x + 31, start_y + 13, start_x + 31, start_y + 23, SOLID, FORCE)
  end
  if rssi > 70 then
    lcd.drawLine(start_x + 32, start_y + 13, start_x + 32, start_y + 23, SOLID, FORCE)
  end
  if rssi > 73 then
    lcd.drawLine(start_x + 33, start_y + 12, start_x + 33, start_y + 23, SOLID, FORCE)
  end
  if rssi > 76 then
    lcd.drawLine(start_x + 34, start_y + 12, start_x + 34, start_y + 23, SOLID, FORCE)
  end
  if rssi > 79 then
    lcd.drawLine(start_x + 35, start_y + 12, start_x + 35, start_y + 23, SOLID, FORCE)
  end
  if rssi > 82 then
    lcd.drawLine(start_x + 36, start_y + 12, start_x + 36, start_y + 23, SOLID, FORCE)
  end
  if rssi > 85 then
    lcd.drawLine(start_x + 37, start_y + 11, start_x + 37, start_y + 23, SOLID, FORCE)
  end
  if rssi > 88 then
    lcd.drawLine(start_x + 38, start_y + 11, start_x + 38, start_y + 23, SOLID, FORCE)
  end
  if rssi > 91 then
    lcd.drawLine(start_x + 39, start_y + 11, start_x + 39, start_y + 23, SOLID, FORCE)
  end
  if rssi > 94 then
    lcd.drawLine(start_x + 40, start_y + 11, start_x + 40, start_y + 23, SOLID, FORCE)
  end
  if rssi > 97 then
    lcd.drawLine(start_x + 41, start_y + 11, start_x + 41, start_y + 23, SOLID, FORCE)
  end
  if rssi > 98 then
    lcd.drawLine(start_x + 42, start_y + 11, start_x + 42, start_y + 23, SOLID, FORCE)
  end
  
  if rssi > 0 then
    lcd.drawLine(101, 5, 101, 5, SOLID, FORCE)
    lcd.drawLine(100, 2, 102, 2, SOLID, FORCE)
    lcd.drawLine(99, 3, 99, 3, SOLID, FORCE)
    lcd.drawLine(103, 3, 103, 3, SOLID, FORCE)
    lcd.drawLine(99, 0, 103, 0, SOLID, FORCE)
    lcd.drawLine(98, 1, 98, 1, SOLID, FORCE)
    lcd.drawLine(104, 1, 104, 1, SOLID, FORCE)
  end
  
end

local function drawVoltageText(start_x, start_y)
  -- First, try to get voltage from VFAS...
  local voltage = getValue('RxBt')
  
  if tonumber(voltage) >= 10 then
    lcd.drawText(start_x+4,start_y,string.format("%.2f", voltage),MIDSIZE)
  else
    lcd.drawText(start_x + 11,start_y,string.format("%.2f", voltage),MIDSIZE)
  end
  lcd.drawText(start_x + 31, start_y -1, 'v', MEDSIZE)
end

local function drawVoltageImage(start_x, start_y)
  
  -- Define the battery width (so we can adjust it later)
  local batteryWidth = 12 

  -- Draw our battery outline
  lcd.drawLine(start_x + 2, start_y + 1, start_x + batteryWidth - 2, start_y + 1, SOLID, 0)
  lcd.drawLine(start_x, start_y + 2, start_x + batteryWidth - 1, start_y + 2, SOLID, 0)
  lcd.drawLine(start_x, start_y + 2, start_x, start_y + 50, SOLID, 0)
  lcd.drawLine(start_x, start_y + 50, start_x + batteryWidth - 1, start_y + 50, SOLID, 0)
  lcd.drawLine(start_x + batteryWidth, start_y + 3, start_x + batteryWidth, start_y + 49, SOLID, 0)

  -- top one eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 8, start_x + batteryWidth - 1, start_y + 8, SOLID, 0)
  -- top quarter line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 2), start_y + 14, start_x + batteryWidth - 1, start_y + 14, SOLID, 0)
  -- third eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 20, start_x + batteryWidth - 1, start_y + 20, SOLID, 0)
  -- Middle line
  lcd.drawLine(start_x + 1, start_y + 26, start_x + batteryWidth - 1, start_y + 26, SOLID, 0)
  -- five eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 32, start_x + batteryWidth - 1, start_y + 32, SOLID, 0)
  -- bottom quarter line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 2), start_y + 38, start_x + batteryWidth - 1, start_y + 38, SOLID, 0)
  -- seven eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 44, start_x + batteryWidth - 1, start_y + 44, SOLID, 0)
  
  -- Voltage top
  lcd.drawText(start_x + batteryWidth + 4, start_y + 0, "4.3", SMLSIZE)
  -- Voltage middle
  lcd.drawText(start_x + batteryWidth + 4, start_y + 24, "3.8", SMLSIZE)
  -- Voltage bottom
  lcd.drawText(start_x + batteryWidth + 4, start_y + 47, "3.3", SMLSIZE)
  
  -- Now draw how full our voltage is...
  local voltage = math.ceil((getValue('RxBt')/4))
  voltageLow = (3.3 * 4)
  voltageHigh = (4.35 *4)
  voltageIncrement = ((voltageHigh - voltageLow) / 47)
  
  local offset = 0  -- Start from the bottom up
  while offset < 47 do
    if ((offset * voltageIncrement) + voltageLow) < tonumber(voltage) then
      lcd.drawLine( start_x + 1, start_y + 49 - offset, start_x + batteryWidth - 1, start_y + 49 - offset, SOLID, 0)
    end
    offset = offset + 1
  end
end

local function gatherInput(event)
  
  -- Get our RSSI
  rssi = getValue('RQly')
  rssi2 = getValue('TQly')

  -- Get the seconds left in our timer
  timerLeft = getValue('timer1')
  -- And set our max timer if it's bigger than our current max timer
  if timerLeft > maxTimerValue then
    maxTimerValue = timerLeft
  end

  -- Get our current transmitter voltage
  currentVoltage = getValue('RxBt')

  -- Armed / Disarm / Buzzer switch
  armed = getValue('sa')

  -- Our "mode" switch
  mode = getValue('FM')

  -- Do some event handling to figure out what button(s) were pressed  :)
  if event > 0 then
    lastNumberMessage = event
  end
  
  if event == 131 then
    lastMessage = "Page Button HELD"
    killEvents(131)
  end
  if event == 99 then
    lastMessage = "Page Button Pressed"
    killEvents(99)
  end
  if event == 97 then
    lastMessage = "Exit Button Pressed"
    killEvents(97)
  end

  if event == 96 then
    lastMessage = "Menu Button Pressed"
    killEvents(96)
  end
  
  if event == EVT_ROT_RIGHT then
    lastMessage = "Navigate Right Pressed"
    killEvents(EVT_ROT_RIGHT)
  end
  if event == EVT_ROT_LEFT then
    lastMessage = "Navigate Left Pressed"
    killEvents(EVT_ROT_LEFT)
  end
  if event == 98 then
    lastMessage = "Navigate Button Pressed"
    killEvents(98)
  end

end

local function getModeText()
  local modeText = getValue('FM')
  if modeText == 0 then
    modeText = "no clue!"
  end
--  if mode < -512 then
--    modeText = "Air Mode"
--  elseif mode > -100 and mode < 100 then
--    modeText = "Acro"
--  elseif mode > 512 then
--    modeText = "Horizon"
--  end
  return modeText
end

local function run(event)
  
  -- Now begin drawing...
  lcd.clear()
  
  -- Gather input from the user
  gatherInput(event)
  
  -- Set our animation "frame"
  setAnimationIncrement()

  -- Check if we just armed...
  if armed > 512 then
    isArmed = 1
  elseif armed < 512 and isArmed == 1 then
    isArmed = 0
  else
    isArmed = 0
  end

  -- Draw a horizontal line seperating the header
  lcd.drawLine(0, 7, 128, 7, SOLID, FORCE)

  -- Draw our model name centered at the top of the screen
 lcd.drawText( 64 - math.ceil((#modelName * 5) / 2),0, modelName, SMLSIZE)

  modeText = getModeText()
-- this doesnt work for some reason
--  lcd.drawText( 64 - math.ceil((#modeText * 5) / 2),0, modeText, SMLSIZE)
 lcd.drawText( 46 ,10, modeText, SMLSIZE)

  -- capacity Used
  if getValue('Capa') > 0 then 
    -- only update if not zero
	lastCapa = getValue('Capa')
  end 
  if tonumber(lastCapa) >= 100 then
    lcd.drawText(55-4, 36, lastCapa, MIDSIZE)
  else
    lcd.drawText(55, 36, lastCapa, MIDSIZE)
  end
  lcd.drawText( 55 + 20, 35, 'A', MEDSIZE)

  -- amps Current
  if lastMaxAmp < getValue('Curr') then
    lastMaxAmp = getValue('Curr')
  end
  if getValue('Curr') >0 then 
    lcd.drawText( 67 ,43, string.format("%.1f", getValue('Curr')), SMLSIZE)
  else 
    -- show max value
    lcd.drawText( 67 ,43, string.format("%.1f", lastMaxAmp, SMLSIZE))
  end
  -- Volts Current
  --  lcd.drawText( 85 ,35, string.format("%.2f", getValue('RxBt')), MIDSIZE)
  --  lcd.drawText( 88 + 20, 33, 'V', MEDSIZE)

  -- Draw our sexy voltage
--  drawTransmitterVoltage(4,0, getValue('RxBt'))

  -- Draw our flight timer
  drawFlightTimer(84, 34)
  
  -- Draw RSSI
  drawRSSI(84, 8)
  
  -- draw sending power in RSSIBar
  lcd.drawText( 87, 19, getValue('TPW2'), SMLSIZE)

  -- Draw Time in Top Right
  drawTime()

  -- Draw Voltage bottom middle
  drawVoltageText(45,50)
  
  -- Draw voltage battery graphic
  drawVoltageImage(3, 10)

  SayBattPercent(getValue('Bat_'))
  
  -- GPS
  if tonumber(getValue('Sats')) >4 then
    -- display GPS Data
    lcd.drawText( 34 ,19, string.format("%.1f", getValue('GSpd')), MIDSIZE)
    if getValue('GSpd') > lasttopspeed then
	  if getValue('Sats') >= 8 then
		-- only update topspeed with proper fix
		lasttopspeed = getValue('GSpd')
	  end
	end
	lcd.drawText( 34 ,31, getValue('Alt'), SMLSIZE)
--    lcd.drawText( 72 ,16, getValue('Sats'), SMLSIZE)
-- put sat count on top right
    lcd.drawText( 0 ,0, "GPS", SMLSIZE)
    lcd.drawText( 16 ,0, getValue('Sats'), SMLSIZE)
  else
    lcd.drawText( 0 ,0, "No GPS", SMLSIZE)
    if lasttopspeed > 0 then
	  lcd.drawText( 27 ,19, "T ", MIDSIZE)
	  lcd.drawText( 34 ,19, string.format("%.1f", lasttopspeed), MIDSIZE)
    end
  end

  checkForNewBattery()
  
  return 0
end


local function init_func()
  -- Called once when model is loaded, only need to get model name once...
  local modeldata = model.getInfo()
  if modeldata then
    modelName = modeldata['name']
  end
end


return { run=run, init=init_func  }
