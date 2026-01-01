-- Author: Domagoj29
-- GitHub: https://github.com/Domagoj-29
-- Workshop: https://steamcommunity.com/profiles/76561198935577915/myworkshopfiles/

-- onDraw functions

local function drawFrequencyArrow(x,y,isRotated)
	if isRotated then
		screen.drawLine(x+1,y+1,x+3,y+1)
		screen.drawLine(x,y,x+4,y)
	else
		screen.drawLine(x+1,y,x+3,y)
		screen.drawLine(x,y+1,x+4,y+1)
	end
end
local function drawColon(x,y)
	screen.drawRectF(x,y+1,1,1)
	screen.drawRectF(x,y+3,1,1)
end
local function drawSignalStrengthBackground()
	screen.drawRectF(w-7-HorizontalGap*4,0,1+HorizontalGap,1)
	screen.drawRectF(w-5-HorizontalGap*3,0,1+HorizontalGap,2)
	screen.drawRectF(w-3-HorizontalGap*2,0,1+HorizontalGap,3)
	screen.drawRectF(w-1-HorizontalGap,0,1+HorizontalGap,4)
end
local function drawSignalStrengthIndicator(signalStrength)
	if signalStrength>0 then
		screen.drawRectF(w-7-HorizontalGap*4,0,1+HorizontalGap,1)
	end
	if signalStrength>0.25 then
		screen.drawRectF(w-5-HorizontalGap*3,0,1+HorizontalGap,2)
	end
	if signalStrength>0.5 then
		screen.drawRectF(w-3-HorizontalGap*2,0,1+HorizontalGap,3)
	end
	if signalStrength>0.75 then
		screen.drawRectF(w-1-HorizontalGap,0,1+HorizontalGap,4)
	end
end
local function drawInvisibleRectangles()
	screen.drawRectF(0,0,w,6)
	screen.drawRectF(0,h-2,w,2)
end
local function drawReturnArrow(shadingOffset)
	screen.drawLine(1+shadingOffset,1,3+shadingOffset,-1)
	screen.drawLine(0+shadingOffset,2,5+shadingOffset+HorizontalGap,2)
	screen.drawLine(1+shadingOffset,3,3+shadingOffset,5)
end
local function getHighlightColor(isSelected)
	if isSelected then
		return 255,127,0
	else
		return UiR,UiG,UiB
	end
end
local function getSignalColor(signalStrength)
	if signalStrength<=0.25 then
		return 255,0,0
	elseif signalStrength<=0.5 then
		return 250,70,22
	elseif signalStrength<=0.75 then
		return 255,255,0
	else
		return 8,255,8
	end
end

-- onTick functions

local function isPointInRectangle(x,y,rectX,rectY,rectW,rectH)
	return x>rectX and y>rectY and x<rectX+rectW and y<rectY+rectH
end
local function clamp(value,min,max)
	value=math.max(min,math.min(value,max))
	return value
end
local function createCapacitor()
	local oldBoolValue=false
	local chargeCounter=0
	local dischargeCounter=nil
	return function(boolValue,chargeTicks,dischargeTicks)
		if dischargeCounter==nil then
			dischargeCounter=dischargeTicks
		end

		if boolValue then
			chargeCounter=math.min(chargeCounter+1,chargeTicks)
		else
			chargeCounter=0
		end

		if oldBoolValue and not boolValue then
			dischargeCounter=0
		end

		if not boolValue and dischargeCounter<dischargeTicks then
			dischargeCounter=dischargeCounter+1
		end

		oldBoolValue=boolValue

		return (dischargeCounter>0 and dischargeCounter<dischargeTicks) or (chargeCounter==chargeTicks and boolValue)
	end
end
local function createScrollUpDown()
	local counter=0
	return function(down,up)
		if up then
			counter=counter+1
		elseif down then
			counter=counter-1
		end
		counter=clamp(counter,-23,0)
		return counter
	end
end
local function createDigitUpDown()
	local delayTicks=15
	local timer=0
	local counter=0
	return function(up,down)
		if up or down then
			timer=timer+1
			if timer>delayTicks then
				counter=up and counter+1 or counter
				counter=down and counter-1 or counter
				timer=0
			end
		else
			timer=delayTicks
		end
		counter=(counter==-1) and 9 or counter
		counter=(counter==10) and 0 or counter
		return counter
	end
end
local function createPushToToggle()
	local oldVariable=false
	local toggleVariable=false
	return function(variable)
		if variable and not oldVariable then
			toggleVariable=not toggleVariable
		end
		oldVariable=variable
		return toggleVariable
	end
end
local function createPulse()
	local k=0
	return function(variable)
		if not variable then
			k=0
		else
			k=k+1
		end
		return k==1
	end
end
local function createStringMemoryGate()
	local storedValue="NumberData"
	return function(valueToStore,set)
		if set then
			storedValue=valueToStore
		end
		return storedValue
    end
end
local function truncate(number)
	if number>0 then
		return math.floor(number)
	else
		return math.ceil(number)
	end
end
local function dynamicDecimalRounding(number)
	local clampedNumber=clamp(number,-10^(4+HorizontalGap)+1,10^(5+HorizontalGap)-1)
	local truncatedNumber=truncate(clampedNumber)
	local numberLength=string.len(tostring(truncatedNumber))
	local decimals=math.max(0,4+math.floor(HorizontalGap+0.5)-numberLength)

	local roundedNumber=string.format("%." .. decimals .. "f",clampedNumber)
	return roundedNumber:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
end
local function boolToString(boolValue)
	if boolValue==true then
		return "ON"
	else
		return "OFF"
	end
end

digitUpDown={}
incrementCapacitor={}
decrementCapacitor={}
for i=1,6 do
	digitUpDown[i]=createDigitUpDown()
	incrementCapacitor[i]=createCapacitor()
	decrementCapacitor[i]=createCapacitor()
end

local numberDataScroll=createScrollUpDown()
local boolDataScroll=createScrollUpDown()
local previousDataMode=createStringMemoryGate() -- This remembers the last data (bool,number,video) mode you were in
local mutePushToToggle=createPushToToggle()
local returnButtonPulse=createPulse()
local cycleDataModesPulse=createPulse()

w=0
h=0
HorizontalGap=0
VerticalGap=0
FrequencySet=0
NumberDataScrollY=0
BoolDataScrollY=0
ScreenMode="Menu" -- "Menu","Frequency","NumberData","BoolData","VideoData"
NumberChannel={}
BoolChannel={}
Increments={}
Decrements={}
Digits={0,0,0,0,0,0}

UiR=property.getNumber("UI R")
UiG=property.getNumber("UI G")
UiB=property.getNumber("UI B")
function onTick()
	local inputX=input.getNumber(3)
	local inputY=input.getNumber(4)
	SignalStrength=input.getNumber(7)

	for i=1,8 do
		NumberChannel[i]=dynamicDecimalRounding(input.getNumber(7+i))
	end

    local isPressed=input.getBool(1)
	ExternalPTT=input.getBool(3)

	for i=1,8 do
		BoolChannel[i]=boolToString(input.getBool(3+i))
	end

	HorizontalGap=clamp((w/32-1),0,2)
	VerticalGap=clamp((h/32-1),0,2)

	local ReturnButton=isPressed and isPointInRectangle(inputX,inputY,-1,-1,6+HorizontalGap,6)
	if returnButtonPulse(ReturnButton) then
		previousDataMode(ScreenMode,ScreenMode~="Frequency")
		ScreenMode="Menu"
	end

	MaxDigits=w==32 and 4 or 6
	FourDigitTableOffset=w==32 and 1 or 0
	FrequencyModeCoordinatesX={w/2+10,w/2+5,w/2,w/2-6,w/2-11,w/2-16}

	local cycleDataModes=isPressed and isPointInRectangle(inputX,inputY,w/2-9,-1,16,6)

	local up=isPressed and isPointInRectangle(inputX,inputY,-1,-1,w+2,h/2-2)
	local down=isPressed and isPointInRectangle(inputX,inputY,-1,h/2+1,w+2,h/2)

	local dataButton=false
	local videoSwitchbox=false

	if ScreenMode=="Menu" then
		local frqButton=isPressed and isPointInRectangle(inputX,inputY,w/2-8,h/2-16,15,6)
		PTTButton=isPressed and isPointInRectangle(inputX,inputY,w/2-8,h/2-10+VerticalGap,15,6)
		dataButton=isPressed and isPointInRectangle(inputX,inputY,w/2-11,h/2-4+VerticalGap*2,20,6)
		local muteButton=isPressed and isPointInRectangle(inputX,inputY,w/2-11,h/2+2+VerticalGap*3,20,6)

		if frqButton then
			ScreenMode="Frequency"
		end
		PTTButtonR,PTTButtonG,PTTButtonB=getHighlightColor(PTTButton or ExternalPTT)
		if dataButton then
			ScreenMode=previousDataMode(nil,false)
		end
		MuteToggle=mutePushToToggle(muteButton)
	elseif ScreenMode=="Frequency" then
		for i=1,MaxDigits do
			Increments[i]=isPressed and isPointInRectangle(inputX,inputY,FrequencyModeCoordinatesX[i+FourDigitTableOffset],h/2-9,5,6)
			Decrements[i]=isPressed and isPointInRectangle(inputX,inputY,FrequencyModeCoordinatesX[i+FourDigitTableOffset],h/2+1,5,6)
			Digits[i]=digitUpDown[i](Increments[i],Decrements[i])
		end
		FrequencySet=Digits[1]+Digits[2]*10+Digits[3]*100+Digits[4]*1000+Digits[5]*10000+Digits[6]*100000
	elseif ScreenMode=="NumberData" then
		local notAnyButton=not (ReturnButton or dataButton or cycleDataModes)
		NumberDataScrollY=h==32 and numberDataScroll(down and notAnyButton,up and notAnyButton) or 0

		if cycleDataModesPulse(cycleDataModes) then
			ScreenMode="BoolData"
		end
	elseif ScreenMode=="BoolData" then
		local notAnyButton=not (ReturnButton or dataButton or cycleDataModes)
		BoolDataScrollY=h==32 and boolDataScroll(down and notAnyButton,up and notAnyButton) or 0

		if cycleDataModesPulse(cycleDataModes) then
			ScreenMode="VideoData"
		end
	elseif ScreenMode=="VideoData" then
		videoSwitchbox=true
		if cycleDataModesPulse(cycleDataModes) then
			ScreenMode="NumberData"
		end
	end

	output.setNumber(1,FrequencySet)

	output.setBool(1,PTTButton or ExternalPTT)
	output.setBool(2,MuteToggle)
	output.setBool(3,videoSwitchbox)
end
function onDraw()
	w=screen.getWidth()
	h=screen.getHeight()

	if ScreenMode~="VideoData" then
		screen.setColor(15,15,15)
		screen.drawClear()
	end

	screen.setColor(0,0,0)
	if ScreenMode=="Menu" then
		screen.drawText(w/2-6,h/2-15,"FRQ")
		screen.drawText(w/2-6,h/2-9+VerticalGap,"PTT")
		screen.drawText(w/2-9,h/2-3+VerticalGap*2,"DATA")
		screen.drawText(w/2-9,h/2+3+VerticalGap*3,"MUTE")
		screen.drawText(w-9,h-5,"V4")
	elseif ScreenMode=="Frequency" then
		for i=1,MaxDigits do
			screen.drawText(FrequencyModeCoordinatesX[i+FourDigitTableOffset]+2,h/2-3,string.format("%.0f",Digits[i]))
			drawFrequencyArrow(FrequencyModeCoordinatesX[i+FourDigitTableOffset]+2,h/2-6,false)
			drawFrequencyArrow(FrequencyModeCoordinatesX[i+FourDigitTableOffset]+2,h/2+3,true)
		end
	elseif ScreenMode=="NumberData" then
		for i=1,8 do
			screen.drawText(1,i*6+i*VerticalGap+NumberDataScrollY,string.format("%.0f",i))
			drawColon(6,i*6+i*VerticalGap+NumberDataScrollY)
			screen.drawTextBox(w-35,i*6+i*VerticalGap+NumberDataScrollY,35,5,NumberChannel[i],1)
		end
		screen.drawText(w/2-7,0,"Num")
	elseif ScreenMode=="BoolData" then
		for i=1,8 do
			screen.drawText(1,i*6+i*VerticalGap+BoolDataScrollY,string.format("%.0f",i))
			drawColon(6,i*6+i*VerticalGap+BoolDataScrollY)
			screen.drawTextBox(w-15,i*6+i*VerticalGap+BoolDataScrollY,15,5,BoolChannel[i],1)
		end
	elseif ScreenMode=="VideoData" then
		screen.drawText(w/2-7,0,"Vid")
	end

	if ScreenMode=="Menu" then
		screen.setColor(UiR,UiG,UiB)
		screen.drawText(w/2-7,h/2-15,"FRQ")
		screen.drawText(w/2-10,h/2-3+VerticalGap*2,"DATA")
		screen.drawText(w-10,h-5,"V4")

		screen.setColor(getHighlightColor(PTTButton or ExternalPTT))
		screen.drawText(w/2-7,h/2-9+VerticalGap,"PTT")
		screen.setColor(getHighlightColor(MuteToggle))
		screen.drawText(w/2-10,h/2+3+VerticalGap*3,"MUTE")
	elseif ScreenMode=="Frequency" then
		for i=1,MaxDigits do
			screen.setColor(UiR,UiG,UiB)
			screen.drawText(FrequencyModeCoordinatesX[i+FourDigitTableOffset]+1,h/2-3,string.format("%.0f",Digits[i]))

			screen.setColor(getHighlightColor(incrementCapacitor[i](Increments[i],1,15)))
			drawFrequencyArrow(FrequencyModeCoordinatesX[i+FourDigitTableOffset]+1,h/2-6,false)

			screen.setColor(getHighlightColor(decrementCapacitor[i](Decrements[i],1,15)))
			drawFrequencyArrow(FrequencyModeCoordinatesX[i+FourDigitTableOffset]+1,h/2+3,true)
		end
	elseif ScreenMode=="NumberData" then
		screen.setColor(UiR,UiG,UiB)
		for i=1,8 do
			screen.drawText(0,i*6+i*VerticalGap+NumberDataScrollY,string.format("%.0f",i))
			drawColon(5,i*6+i*VerticalGap+NumberDataScrollY)
			screen.drawTextBox(w-36,i*6+i*VerticalGap+NumberDataScrollY,35,5,NumberChannel[i],1)
		end

		screen.setColor(15,15,15)
		drawInvisibleRectangles()

		screen.setColor(0,0,0)
		screen.drawText(w/2-7,0,"Num")

		screen.setColor(UiR,UiG,UiB)
		screen.drawText(w/2-8,0,"Num")
	elseif ScreenMode=="BoolData" then
		screen.setColor(UiR,UiG,UiB)
		for i=1,8 do
			screen.drawText(0,i*6+i*VerticalGap+BoolDataScrollY,string.format("%.0f",i))
			drawColon(5,i*6+i*VerticalGap+BoolDataScrollY)
			screen.drawTextBox(w-16,i*6+i*VerticalGap+BoolDataScrollY,15,5,BoolChannel[i],1)
		end

		screen.setColor(15,15,15)
		drawInvisibleRectangles()

		screen.setColor(0,0,0)
		screen.drawText(w/2-7,0,"Log")

		screen.setColor(UiR,UiG,UiB)
		screen.drawText(w/2-8,0,"Log")
	elseif ScreenMode=="VideoData" then
		screen.setColor(UiR,UiG,UiB)
		screen.drawText(w/2-8,0,"Vid")
	end

	if ScreenMode~="Menu" then
		screen.setColor(0,0,0)
		drawReturnArrow(1)
		screen.setColor(UiR,UiG,UiB)
		drawReturnArrow(0)
	end

	if ScreenMode~="VideoData" then
		screen.setColor(25,25,25)
		drawSignalStrengthBackground()
	end
	screen.setColor(getSignalColor(SignalStrength))
	drawSignalStrengthIndicator(SignalStrength)
end
