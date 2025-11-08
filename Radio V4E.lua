-- Author: Domagoj29
-- GitHub: https://github.com/Domagoj-29
-- Workshop: https://steamcommunity.com/profiles/76561198935577915/myworkshopfiles/

-- Initializing variables and tables

local uiR=0
local uiG=0
local uiB=0

local numberChannel={}
local boolChannel={}

local PTTButton=false
local ExternalPTT=false
local muteToggle=false

local ReceiveFrequencySet=0
local SendFrequencySet=0

local horizontalGap=0
local verticalGap=0

local maxDigits=6
local fourDigitTableOffset=0

local ReceiveIncrements={false,false,false,false,false,false}
local ReceiveDecrements={false,false,false,false,false,false}
local ReceiveDigits={0,0,0,0,0,0}

local SendIncrements={false,false,false,false,false,false}
local SendDecrements={false,false,false,false,false,false}
local SendDigits={0,0,0,0,0,0}

local receiveIncrementCapacitor={}
local receiveDecrementCapacitor={}
local receiveDigitUpDown={}

local sendIncrementCapacitor={}
local sendDecrementCapacitor={}
local sendDigitUpDown={}

local frequencyModeCoordinatesX={0,0,0,0,0,0}

local numberDataScrollX=0
local boolDataScrollX=0

local signalStrength=0

local DataButton=false
local MuteButton=false
local DuplexButton=false

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
	screen.drawRectF(w-7-horizontalGap*4,0,1+horizontalGap,1)
	screen.drawRectF(w-5-horizontalGap*3,0,1+horizontalGap,2)
	screen.drawRectF(w-3-horizontalGap*2,0,1+horizontalGap,3)
	screen.drawRectF(w-1-horizontalGap,0,1+horizontalGap,4)
end
local function drawSignalStrengthIndicator(signalStrength)
	if signalStrength>0 then
		screen.drawRectF(w-7-horizontalGap*4,0,1+horizontalGap,1)
	end
	if signalStrength>0.25 then
		screen.drawRectF(w-5-horizontalGap*3,0,1+horizontalGap,2)
	end
	if signalStrength>0.5 then
		screen.drawRectF(w-3-horizontalGap*2,0,1+horizontalGap,3)
	end
	if signalStrength>0.75 then
		screen.drawRectF(w-1-horizontalGap,0,1+horizontalGap,4)
	end
end
local function drawInvisibleRectangles()
	screen.drawRectF(0,0,w,6)
	screen.drawRectF(0,h-2,w,2)
end
local function drawReturnArrow(shadingOffset)
	screen.drawLine(1+shadingOffset,1,3+shadingOffset,-1)
	screen.drawLine(0+shadingOffset,2,5+shadingOffset+horizontalGap,2)
	screen.drawLine(1+shadingOffset,3,3+shadingOffset,5)
end
local function getHighlightColor(isSelected)
	if isSelected then
		return 255,127,0
	else
		return uiR,uiG,uiB
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
	local clampedNumber=clamp(number,-10^(4+horizontalGap)+1,10^(5+horizontalGap)-1)
	local truncatedNumber=truncate(clampedNumber)
	local numberLength=string.len(tostring(truncatedNumber))
	local decimals=math.max(0,4+math.floor(horizontalGap+0.5)-numberLength)

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

for i=1,maxDigits do
	receiveDigitUpDown[i]=createDigitUpDown()
	receiveIncrementCapacitor[i]=createCapacitor()
	receiveDecrementCapacitor[i]=createCapacitor()

	sendDigitUpDown[i]=createDigitUpDown()
	sendIncrementCapacitor[i]=createCapacitor()
	sendDecrementCapacitor[i]=createCapacitor()
end

numberDataScroll=createScrollUpDown()
boolDataScroll=createScrollUpDown()
previousDataMode=createStringMemoryGate() -- This remembers the last data (bool,number,video) mode you were in
mutePushToToggle=createPushToToggle()
duplexPushToToggle=createPushToToggle()
returnButtonPulse=createPulse()
cycleDataModesPulse=createPulse()

local screenMode="Menu" -- "Menu","Frequency","NumberData","BoolData","VideoData"
function onTick()
	uiR=property.getNumber("UI R")
	uiG=property.getNumber("UI G")
	uiB=property.getNumber("UI B")

	local w=input.getNumber(1)
	local h=input.getNumber(2)
	local inputX=input.getNumber(3)
	local inputY=input.getNumber(4)
	signalStrength=input.getNumber(7)

	for i=1,8 do
		numberChannel[i]=dynamicDecimalRounding(input.getNumber(7+i))
	end

	local isPressed=input.getBool(1)
	ExternalPTT=input.getBool(3)

	for i=1,8 do
		boolChannel[i]=boolToString(input.getBool(3+i))
	end

	horizontalGap=clamp((w/32-1),0,2)
	verticalGap=clamp((h/32-1),0,2)

	local ReturnButton=isPressed and isPointInRectangle(inputX,inputY,-1,-1,6+horizontalGap,6)
	if returnButtonPulse(ReturnButton) then
		previousDataMode(screenMode,screenMode~="Frequency")
		screenMode="Menu"
	end

	maxDigits=w==32 and 4 or 6
	fourDigitTableOffset=w==32 and 1 or 0
	frequencyModeCoordinatesX={w/2+10,w/2+5,w/2,w/2-6,w/2-11,w/2-16}

	local cycleDataModes=isPressed and isPointInRectangle(inputX,inputY,w/2-9,-1,16,6)

	local Up=isPressed and isPointInRectangle(inputX,inputY,-1,-1,w+2,h/2-1)
	local Down=isPressed and isPointInRectangle(inputX,inputY,-1,h/2+1,w+2,h/2)

	DataButton=false
	local videoSwitchbox=false

	if screenMode=="Menu" then
		local FrqButton=isPressed and isPointInRectangle(inputX,inputY,w/2-8,h/2-16,15,6)
		PTTButton=isPressed and isPointInRectangle(inputX,inputY,w/2-8,h/2-10+verticalGap,15,6)
		DataButton=isPressed and isPointInRectangle(inputX,inputY,w/2-11,h/2-4+verticalGap*2,20,6)
		MuteButton=isPressed and isPointInRectangle(inputX,inputY,w/2-11,h/2+2+verticalGap*3,20,6)
        DuplexButton=isPressed and isPointInRectangle(inputX,inputY,w/2-11,h/2+8+verticalGap*4,20,6)

		if FrqButton then
			screenMode="Frequency"
		end
		PTTButtonR,PTTButtonG,PTTButtonB=getHighlightColor(PTTButton or ExternalPTT)
		if DataButton then
			screenMode=previousDataMode(nil,false)
		end
		muteToggle=mutePushToToggle(MuteButton)
		muteButtonR,muteButtonG,muteButtonB=getHighlightColor(muteToggle)

		isFullDuplex=duplexPushToToggle(DuplexButton)
	elseif screenMode=="Frequency" then
		for i=1,maxDigits do
			if not isFullDuplex then
				ReceiveIncrements[i]=isPressed and isPointInRectangle(inputX,inputY,frequencyModeCoordinatesX[i+fourDigitTableOffset],h/2-9,5,6)
				ReceiveDecrements[i]=isPressed and isPointInRectangle(inputX,inputY,frequencyModeCoordinatesX[i+fourDigitTableOffset],h/2+1,5,6)
				ReceiveDigits[i]=receiveDigitUpDown[i](ReceiveIncrements[i],ReceiveDecrements[i])
			else
				ReceiveIncrements[i]=isPressed and isPointInRectangle(inputX,inputY,frequencyModeCoordinatesX[i+fourDigitTableOffset],h/2-12,5,6)
				ReceiveDecrements[i]=isPressed and isPointInRectangle(inputX,inputY,frequencyModeCoordinatesX[i+fourDigitTableOffset],h/2-4,5,6)
				ReceiveDigits[i]=receiveDigitUpDown[i](ReceiveIncrements[i],ReceiveDecrements[i])

				SendIncrements[i]=isPressed and isPointInRectangle(inputX,inputY,frequencyModeCoordinatesX[i+fourDigitTableOffset],h/2+2,5,6)
				SendDecrements[i]=isPressed and isPointInRectangle(inputX,inputY,frequencyModeCoordinatesX[i+fourDigitTableOffset],h/2+10,5,6)
				SendDigits[i]=sendDigitUpDown[i](SendIncrements[i],SendDecrements[i])
			end
		end
		ReceiveFrequencySet=ReceiveDigits[1]+ReceiveDigits[2]*10+ReceiveDigits[3]*100+ReceiveDigits[4]*1000+ReceiveDigits[5]*10000+ReceiveDigits[6]*100000
		SendFrequencySet=SendDigits[1]+SendDigits[2]*10+SendDigits[3]*100+SendDigits[4]*1000+SendDigits[5]*10000+SendDigits[6]*100000
	elseif screenMode=="NumberData" then
		local notAnyButton=not (ReturnButton or DataButton or cycleDataModes)
		numberDataScrollX=h==32 and numberDataScroll(Down and notAnyButton,Up and notAnyButton) or 0

		if cycleDataModesPulse(cycleDataModes) then
			screenMode="BoolData"
		end
	elseif screenMode=="BoolData" then
		local notAnyButton=not (ReturnButton or DataButton or cycleDataModes)
		boolDataScrollX=h==32 and boolDataScroll(Down and notAnyButton,Up and notAnyButton) or 0

		if cycleDataModesPulse(cycleDataModes) then
			screenMode="VideoData"
		end
	elseif screenMode=="VideoData" then
		videoSwitchbox=true
		if cycleDataModesPulse(cycleDataModes) then
			screenMode="NumberData"
		end
	end

	output.setNumber(1,ReceiveFrequencySet)

	if not isFullDuplex then
		output.setBool(1,PTTButton or ExternalPTT)
	else
		output.setBool(4,PTTButton or ExternalPTT)
		output.setNumber(2,SendFrequencySet)
	end
	output.setBool(2,muteToggle)
	output.setBool(3,videoSwitchbox)
	output.setBool(5,PTTButton or ExternalPTT)
	output.setBool(6,isFullDuplex)
end
function onDraw()
	w=screen.getWidth()
	h=screen.getHeight()

	if screenMode~="VideoData" then
		screen.setColor(15,15,15)
		screen.drawClear()
	end

	screen.setColor(0,0,0)
	if screenMode=="Menu" then
		screen.drawText(w/2-6,h/2-15,"FRQ")
		screen.drawText(w/2-6,h/2-9+verticalGap,"PTT")
		screen.drawText(w/2-9,h/2-3+verticalGap*2,"DATA")
		screen.drawText(w/2-9,h/2+3+verticalGap*3,"MUTE")
		if not isFullDuplex then
			screen.drawText(w/2-9,h/2+9+verticalGap*4,"HDPX")
		else
			screen.drawText(w/2-9,h/2+9+verticalGap*4,"FDPX")
		end
		if w>32 then
			screen.drawText(w-14,h-5,"V4E")
		end
	elseif screenMode=="Frequency" then
		if w>32 and isFullDuplex then
			screen.drawText(1,h/2-7,"RECV")
			drawColon(21,h/2-7)
			screen.drawText(1,h/2+6,"SEND")
			drawColon(21,h/2+6)
		end
		for i=1,maxDigits do
			if not isFullDuplex then
				screen.drawText(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2-3,string.format("%.0f",ReceiveDigits[i]))
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2-6,false)
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2+3,true)
			else
				screen.drawText(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2-7,string.format("%.0f",ReceiveDigits[i]))
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2-10,false)
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2-1,true)

				screen.drawText(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2+7,string.format("%.0f",SendDigits[i]))
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2+4,false)
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2+13,true)
			end
		end
	elseif screenMode=="NumberData" then
		for i=1,8 do
			screen.drawText(1,i*6+i*verticalGap+numberDataScrollX,string.format("%.0f",i))
			drawColon(6,i*6+i*verticalGap+numberDataScrollX)
			screen.drawTextBox(w-35,i*6+i*verticalGap+numberDataScrollX,35,5,numberChannel[i],1)
		end
		screen.drawText(w/2-7,0,"Num")
	elseif screenMode=="BoolData" then
		for i=1,8 do
			screen.drawText(1,i*6+i*verticalGap+boolDataScrollX,string.format("%.0f",i))
			drawColon(6,i*6+i*verticalGap+boolDataScrollX)
			screen.drawTextBox(w-15,i*6+i*verticalGap+boolDataScrollX,15,5,boolChannel[i],1)
		end
	elseif screenMode=="VideoData" then
		screen.drawText(w/2-7,0,"Vid")
	end

	if screenMode=="Menu" then
		screen.setColor(uiR,uiG,uiB)
		screen.drawText(w/2-7,h/2-15,"FRQ")
		screen.drawText(w/2-10,h/2-3+verticalGap*2,"DATA")

		if not isFullDuplex then
			screen.drawText(w/2-10,h/2+9+verticalGap*4,"HDPX")
		else
			screen.drawText(w/2-10,h/2+9+verticalGap*4,"FDPX")
		end
		if w>32 then
			screen.drawText(w-15,h-5,"V4E")
		end

		screen.setColor(getHighlightColor(PTTButton or ExternalPTT))
		screen.drawText(w/2-7,h/2-9+verticalGap,"PTT")
		screen.setColor(getHighlightColor(muteToggle))
		screen.drawText(w/2-10,h/2+3+verticalGap*3,"MUTE")
	elseif screenMode=="Frequency" then
		screen.setColor(uiR,uiG,uiB)
		if w>32 and isFullDuplex then
			screen.drawText(0,h/2-7,"RECV")
			drawColon(20,h/2-7)
			screen.drawText(0,h/2+6,"SEND")
			drawColon(20,h/2+6)
		end
		for i=1,maxDigits do
 			if not isFullDuplex then
				screen.setColor(uiR,uiG,uiB)
				screen.drawText(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2-3,string.format("%.0f",ReceiveDigits[i]))

				screen.setColor(getHighlightColor(receiveIncrementCapacitor[i](ReceiveIncrements[i],1,15)))
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2-6,false)

				screen.setColor(getHighlightColor(receiveDecrementCapacitor[i](ReceiveDecrements[i],1,15)))
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2+3,true)
			else
				screen.setColor(uiR,uiG,uiB)
				screen.drawText(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2-7,string.format("%.0f",ReceiveDigits[i]))

				screen.setColor(getHighlightColor(receiveIncrementCapacitor[i](ReceiveIncrements[i],1,15)))
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2-10,false)

				screen.setColor(getHighlightColor(receiveDecrementCapacitor[i](ReceiveDecrements[i],1,15)))
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2-1,true)

				screen.setColor(uiR,uiG,uiB)
				screen.drawText(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2+7,string.format("%.0f",SendDigits[i]))

				screen.setColor(getHighlightColor(sendIncrementCapacitor[i](SendIncrements[i],1,15)))
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2+4,false)

				screen.setColor(getHighlightColor(sendDecrementCapacitor[i](SendDecrements[i],1,15)))
				drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2+13,true)
			end
		end
	elseif screenMode=="NumberData" then
		screen.setColor(uiR,uiG,uiB)
		for i=1,8 do
			screen.drawText(0,i*6+i*verticalGap+numberDataScrollX,string.format("%.0f",i))
			drawColon(5,i*6+i*verticalGap+numberDataScrollX)
			screen.drawTextBox(w-36,i*6+i*verticalGap+numberDataScrollX,35,5,numberChannel[i],1)
		end

		screen.setColor(15,15,15)
		drawInvisibleRectangles()

		screen.setColor(0,0,0)
		screen.drawText(w/2-7,0,"Num")

		screen.setColor(uiR,uiG,uiB)
		screen.drawText(w/2-8,0,"Num")
	elseif screenMode=="BoolData" then
		screen.setColor(uiR,uiG,uiB)
		for i=1,8 do
			screen.drawText(0,i*6+i*verticalGap+boolDataScrollX,string.format("%.0f",i))
			drawColon(5,i*6+i*verticalGap+boolDataScrollX)
			screen.drawTextBox(w-16,i*6+i*verticalGap+boolDataScrollX,15,5,boolChannel[i],1)
		end

		screen.setColor(15,15,15)
		drawInvisibleRectangles()

		screen.setColor(0,0,0)
		screen.drawText(w/2-7,0,"Log")

		screen.setColor(uiR,uiG,uiB)
		screen.drawText(w/2-8,0,"Log")
	elseif screenMode=="VideoData" then
		screen.setColor(uiR,uiG,uiB)
		screen.drawText(w/2-8,0,"Vid")
	end

	if screenMode~="Menu" then
		screen.setColor(0,0,0)
		drawReturnArrow(1)
		screen.setColor(uiR,uiG,uiB)
		drawReturnArrow(0)
	end

	if screenMode~="VideoData" then
		screen.setColor(25,25,25)
		drawSignalStrengthBackground()
	end
	screen.setColor(getSignalColor(signalStrength))
	drawSignalStrengthIndicator(signalStrength)
end
