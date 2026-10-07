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
ENABLED,INCREMENTAL:BOOLEAN;
incx:integer;
END;

vehicler=record
  firmware:string;
  vin:string;
  osid:string;
end;

dhpscanrecord=record
COMPORT:BYTE;
BAUD:LONGINT;
IPADDRESS:STRING;
IPPORT:STRING;
AP:INTEGER; // MODE 1,2
SENDVPW:INTEGER;
font,fontsize,fontcolor,primary,secondary:string;
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
PIDCategoryID, // 1 = ENGINE TAB
mci,value:string;
GRIDLINE:BYTE;
BlockID,PIDPos:byte;

pid_grid_row:byte; // row on the scanner grid
scanner_x:byte; // # in scanner_pids

pidwindowindex:integer;

fcolor,rcolor:tcolor;

gfcolor,grcolor,wfcolor,wrcolor:tcolor;
wfilter:real;

end;

pid_list_count=record
count:byte;
bytecount:byte;
f_count:byte;
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

function newstrtofloat(v:string):real;

function newstrtoint(v:string):integer;

function TrimSpaces(stemp: string): string;
function StringtoHex(Data: string): string;
function HexToString(Value: string): string;

function bootostr(f:boolean):string;
function SearchAndReplace
   (sSrc, sLookFor, sReplaceWith : string) : string;
function TColorToHex(Color : TColor) : string;
function IsNumber(s: string): Boolean;
   function HexToTColor(sColor : string) : TColor;
var
intportcount:integer;
      nextpidavail,piddone:boolean;
      vehicle:vehicler;
      scanini:TIniFile;
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

  timedout:boolean;
  big_done:boolean;
  start,LOGSTART,finish:tdatetime; // for log time
  admode:boolean;
  ini:TIniFile;
  cfg:dhpscanrecord;
  AUTONAME:AUTONAMEREC;
  SENDCOMMANDS:SCANCOMMANDREC;
  backupcsv:textfile;

  st,et:tdatetime;
  gridapply:boolean=false;

  DTCM:dtcmodules;
  currentdtc:string='';

  const
   versionid:string='10.18.08b p2';

implementation

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

sleep(0);
end;

end;

end;

end;

end;

end.
