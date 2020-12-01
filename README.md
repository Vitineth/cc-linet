# `linet` System

## Message Structure

```
Timestamp: long

ClientIdentifier: integer

Content: string

MessageType: one of
	M 
	B

Message:
	M:ClientIdentifier:ClientIdentifier:Timestamp:Content
	B:ClientIdentifier:Timestamp:Content
	
===========

M:< from client ID >:< to client ID >:< timestamp >:< content >
B:< from client ID >:< timestamp >:< content >
```

## RDM Structure

```
ClientID: number

LightCount: number

RDMConstant: "rdm"

PeripheralID: string

Side: one of
	"front" 
	"back" 
	"left" 
	"right" 
	"top" 
	"bottom"
	
Locator: one of
	PeripheralID
	Side
	
Type: one of
	"static" 
	"5bit"
	
Color: one of
	"white" 
	"orange" 
	"magenta" 
	"lblue" 
	"yellow" 
	"lime" 
	"pink" 
	"grey" 
	"lgrey" 
	"cyan" 
	"purple" 
	"blue" 
	"brown" 
	"green" 
	"red" 
	"black" 

LightIdentifier:
	Locator."static".Color
	Locator."5bit"
	
LightEntry:
	LightIdentifier=LightCount
	
LightEntryList:
	LightEntry
	LightEntryList-LightEntry

RDMMessage:
	RDMConstant:ClientID:LightEntryList
```

## Configuration Strings

```
PeripheralID: string

Side: one of
	"front" 
	"back" 
	"left" 
	"right" 
	"top" 
	"bottom"

Type: one of
	"static" 
	"5bit"
	
Color: one of
	"white" 
	"orange" 
	"magenta" 
	"lblue" 
	"yellow" 
	"lime" 
	"pink" 
	"grey" 
	"lgrey" 
	"cyan" 
	"purple" 
	"blue" 
	"brown" 
	"green" 
	"red" 
	"black" 

LightIdentifier:
	"static".Side.Color
	"5bit".PeripheralID

LightEntry:
	LightIdentifier=LightCount
	
LightEntryList:
	LightEntry
	LightEntryList-LightEntry
```

Parsing structure

1. Split on "`-`"