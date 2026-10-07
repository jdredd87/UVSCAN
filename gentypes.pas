unit gentypes;

interface

uses   inifiles,SYSUTILS,Grids, BaseGrid, AdvGrid,classes,windows,graphics;

type

dtcmodules=record
ABS,
BCM,
PCM,
NETWORK,
AIRBAG,
IPC,
HUD,
RADIO,
IMMOBILIZER:BOOLEAN;
END;

scancommandREC=record
  mcicode:string;
  value:string;
  command1,
  command2:string;
end;

AUTONAMEREC=RECORD
NAMEHEADER1,nameheader2:STRING;
DATE,TIME,ENABLED,INCREMENTAL:BOOLEAN;
incx:integer;
END;

vehicler=record
  firmware:string;
  vin:string;
  osid:string;
end;

{GAUGEREC=RECORD
  COMP,NAME,VALUE,FORMULA,VEND,VSTART,COLOR1,COLOR2,COLOR3,TEXT:STRING;
END;}

dhpscanrecord=record
COMPORT:BYTE;
BAUD:LONGINT;
IPADDRESS:STRING;
IPPORT:STRING;
AP:INTEGER; // MODE 1,2
SENDVPW:INTEGER;
font,fontsize,fontcolor,primary,secondary:string;
PAUSEBUTTON,SCANBUTTON:INTEGER;
savepath:string;
WB:BYTE;
WBCOMPORT:BYTE;
TC4_1,TC4_2,TC4_3, TC4_4,WBVALUE,LambaValue:string;

end;

PID_Rec=Record
PIDID,  // 1
LongName, // engine speed
Desc, // engine speed of the engine
Formula, // N0 * N1
Units, // RPM
DataLength, // 2
PCMPID, // 000C
PIDGroupID, // 1 = OSID LOOKUP
ShortName, // RPM
ResultsLookup, // 0 = ON , 1 = OFF
PIDCategoryID,mci,value,
filterstart,audiofile:string; // 1 = ENGINE TAB
GRIDLINE:BYTE;
BlockID,PIDPos:byte;
enabled:boolean;

prow,pid_grid_row:byte; // row on the scanner grid
scanner_x:byte; // # in scanner_pids

pidwindowindex:integer;
pidwindowhandle:longint;
pidwindowvx:byte;

fcolor,rcolor:tcolor;

gfcolor,grcolor,wfcolor,wrcolor:tcolor;
wfilter:real;

//TOP,LEFT,WIDTH,HEIGHT,OPEN:INTEGER;

end;


pid_list_count=record
count:byte;
bytecount:byte;
f_count:byte;
f_bytecount:byte;
end;


Scanner_Info=record
lastblock:Byte;
bytecount:byte;
Pid_Count:byte;
Pid_POS:byte; // current PID POS Counter
CurrentBlock:Byte;
PID_Strings:tstringlist;
linecount:longint;
fakepids:tstringlist;
adports:tstringlist;
end;

type
bufferrec=record
DATA:ansistring;
inuse:boolean;
done:boolean;
end;

function newstrtofloat(v:string):real;

function newstrtoint(v:string):integer;

//Const Stacksize = 1024 * 16;

function IntToBin ( value: LongInt; digits: integer ): string;

function TrimSpaces(stemp: string): string;
function StringtoHex(Data: string): string;
function HexToString(Value: string): string;

function bootobyte(f:boolean):byte;
function bootostr(f:boolean):string;
function copyfrombuffer(start,count:longint;var dest:ansistring):boolean;
function buffercount:longint;
function initbuffer(overrideit:boolean):boolean;
function writetobuffer(str:string):boolean;
function searchbuffer(str:string):longint;
function removefrombuffer(start,count:longint):boolean;
function SearchAndReplace
   (sSrc, sLookFor, sReplaceWith : string) : string;
function TColorToHex(Color : TColor) : string;
function IsNumber(s: string): Boolean;
   function HexToTColor(sColor : string) : TColor;
function DateTimeDiff(Start, Stop : TDateTime) : int64;
var
intportcount:integer;
      nextpidavail,piddone:boolean;
      vehicle:vehicler;
      scanini:TIniFile;
      heartbeat:longint;
      hardwaretype:byte;
      sendpidwait:integer;
      nuketype:INTEGER;
      Buffer:bufferrec;
      bufferstr:ansistring;
  scannerrunning:boolean;
  Log_Grid,PIDCSV,dtclist,
  pid_grid_config:tadvstringgrid;
  dtccount:integer;
  pidcounter:pid_list_count;
  LogStatus: byte; // 0 = off
                   // 1 = start
                   // 2 = pause
                   // 3 = saving

  availablepids:array of pid_Rec; // pids that load up from CSV
  group:byte;
  Scanner_Pids:array [1..128] of pid_Rec; // pids to scan for
  ScanI:scanner_info;

  pidtfailed:boolean;
  pid_passed:integer;
  pid_failed:integer;
  pid_fake:integer;

  PID_TIMEOUTCOUNT:BYTE;

  ppid:pid_rec;
  timedout:boolean;
  lastcommand:string;
  sendtestdevice:boolean;
  big_done:boolean;
  start,LOGSTART,finish,tstamp:tdatetime; // for log time
  admode:boolean;
  ini:TIniFile;
  cfg:dhpscanrecord;
  nukebuffer_error:byte; // after 5 clears and no data, then uh oh!
  scan_logging:boolean;
  AUTONAME:AUTONAMEREC;
  SENDCOMMANDS:SCANCOMMANDREC;
  backupcsv:textfile;

  st,et:tdatetime;
  rcolor,fcolor:longint;
  gridapply:boolean=false;

  DTCM:dtcmodules;
  currentdtc:string='';

  const
   versionid:string='10.18.08b p2';

implementation


function DateTimeDiff(Start, Stop : TDateTime) : int64;
var TimeStamp : TTimeStamp;
begin
  TimeStamp := DateTimeToTimeStamp(Stop - Start);
  Dec(TimeStamp.Date, TTimeStamp(DateTimeToTimeStamp(0)).Date);
  Result := (TimeStamp.Date*24*60*60)+(TimeStamp.Time div 1000);
end;
function newstrtoint(v:string):integer;
var g:integer;
begin
try
g:=strtoint(v);
except
g:=-999;
end;
newstrtoint:=g;
end;

function bootostr(f:boolean):string;
begin
  if f=true then bootostr:='1' else
   bootostr:='0';
end;

function bootobyte(f:boolean):byte;
begin
  if f=true then bootobyte:=1 else
   bootobyte:=0;
end;

function newstrtofloat(v:string):real;
var g:real;
begin
try
g:=strtofloat(v);
except
g:=-999;
end;
newstrtofloat:=g;
end;



function TColorToHex(Color : TColor) : string;
begin
   Result :=
     IntToHex(GetRValue(Color), 2) +
     IntToHex(GetGValue(Color), 2) +
     IntToHex(GetBValue(Color), 2) ;
end;

function IsNumber(s: string): Boolean;
var l:real;
begin
result:=true;
try
l:=strtofloat(s);
except
result:=false;
end;
end;

function IntToBin ( value: LongInt; digits: integer ): string;
begin
    result := StringOfChar ( '0', digits ) ;
    while value > 0 do begin
      if ( value and 1 ) = 1 then
        result [ digits ] := '1';
      dec ( digits ) ;
      value := value shr 1;
    end;
end;

function HexToTColor(sColor : string) : TColor;
begin
   Result :=
     RGB(
       newStrToInt('$'+Copy(sColor, 1, 2)),
       newStrToInt('$'+Copy(sColor, 3, 2)),
       newStrToInt('$'+Copy(sColor, 5, 2))
     ) ;
end;

function SearchAndReplace
   (sSrc, sLookFor, sReplaceWith : string) : string;
var
   nPos, nLenLookFor : integer;
begin
   nPos := Pos(sLookFor, sSrc) ;
   nLenLookFor := Length(sLookFor) ;
   while (nPos > 0) do begin
     Delete(sSrc, nPos, nLenLookFor) ;
     Insert(sReplaceWith, sSrc, nPos) ;
     nPos := Pos(sLookFor, sSrc) ;
   end;
   Result := sSrc;
end;

function TrimSpaces(stemp: string): string;
const Remove = [' ', #13, #10];
var
  i: integer;
begin
  result := '';
  for i := 1 to length(stemp) do begin
    if not (stemp[i] in remove) then
      result := result+stemp[i];
  end;
end;

function StringtoHex(Data: string): string;
var
  i, i2: Integer;
  s: string;
begin
  i2 := 1;
  for i := 1 to Length(Data) do
  begin
    Inc(i2);
    if i2 = 2 then
    begin
      s  := s + '';
      i2 := 1;
    end;
    s := s + IntToHex(Ord(Data[i]), 2);
  end;
  Result := s;
end;

function HexToString(Value: string): string;
var

 Final: string;
 HexValue: Cardinal;
 I: Integer;
begin
 I:=1;
  while I<=Length(Value) do
   begin
    HexValue:=newStrToInt('$'+Copy(Value,I,2));
    Final:=Final+Chr(HexValue);
    I:=I+2;
   end;
 Result:=Copy(Final,1,Length(Final));
end;

function buffercount:longint;
begin
try
buffercount:=length(buffer.data);
except
buffercount:=0;
end;
sleep(0);
end;

function initbuffer(overrideit:boolean):boolean;
begin



if buffer.inuse=true
 then if overrideit=false then  repeat
 sleep(0);
 until buffer.inuse=false;          // change this to repeat until its done

//setlength(buffer.data,1024);
buffer.data:='';
buffer.inuse:=false;
buffer.done:=false;
{writeln('Buffer Data Length : ',length(Buffer.data));
writeln('Buffer Data Size : ',sizeof(Buffer.data));
writeln('BUffer In Use : ',buffer.inuse);}
initbuffer:=true;
end;

function writetobuffer(str:string):boolean;
begin
writetobuffer:=false;
if buffer.inuse=true
 then
 repeat
 sleep(0);
 until buffer.inuse=false;          // change this to repeat until its done


buffer.inuse:=true;
sleep(0);
try
buffer.data:=buffer.data+str;
buffer.inuse:=false;
writetobuffer:=true;
except
buffer.inuse:=false;
writetobuffer:=false;
end;

end;

function searchbuffer(str:string):longint;
var x:longint;
begin
searchbuffer:=0; // not found
if buffer.inuse=true
 then
 repeat
 sleep(0);
 until buffer.inuse=false;          // change this to repeat until its done
buffer.inuse:=true;
try
x:=pos(str,buffer.data);
searchbuffer:=x;
buffer.inuse:=false;
except
buffer.inuse:=false;
searchbuffer:=0;
end;
end;


function removefrombuffer(start,count:longint):boolean;
begin


removefrombuffer:=false;
if buffer.inuse=true
 then
 repeat
 sleep(0);
 until buffer.inuse=false;          // change this to repeat until its done

buffer.inuse:=true;
try
 delete(buffer.data,start,count);
 buffer.inuse:=false;
except
buffer.inuse:=false;
removefrombuffer:=false;
end;

end;

function copyfrombuffer(start,count:longint;var dest:ansistring):boolean;
var x:longint;
   tmps:ansistring;
begin
copyfrombuffer:=false;

if buffer.inuse=true
 then
 repeat
 sleep(0);
 until buffer.inuse=false;          // change this to repeat until its done

buffer.inuse:=true;
tmps:='';


try

 for x:=start to start+count-1 do
 begin
 tmps:=tmps+buffer.data[x];
 sleep(0);
 end;
 dest:=tmps;
 buffer.inuse:=false;
 copyfrombuffer:=true;

except
buffer.inuse:=false;
copyfrombuffer:=false;
end;

end;


end.
