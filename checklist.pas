unit checklist;


interface
uses
  FastMM4,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls,
  Dialogs, StdCtrls, oomisc,
  CheckLst, ComCtrls, Menus, ToolWin, Grids, BaseGrid, AdvGrid, ExtCtrls,
  inifiles,gentypes;

    procedure loadlist(appname:String;filename:string;sender:tobject);
    procedure savelist(appname:String;filename:string;sender:tobject);


implementation

procedure savelist(appname:string;filename:string;sender:tobject);
var i:integer;
tlist:tchecklistbox;
begin
  tlist:=sender as tchecklistbox;
  if tlist.items.count=0 then exit;
  if filename='' then
  ini := TIniFile.Create(ChangeFileExt(appname,
       '_Checklist.pid')) else
  ini := TIniFile.Create(filename);
  try
    for i := 0 to tlist.Items.Count - 1 do
      ini.WriteBool(tlist.name, tlist.Items[i], tlist.Checked[i]);
      ini.WriteInteger('PIDCOUNT','PBC',PIDCOUNTER.bytecount);
      ini.WriteInteger('PIDCOUNT','TSP',PIDCOUNTER.Count);
     ini.WriteInteger('PIDCOUNT','TFP',PIDCOUNTER.F_count);
  finally
   ini.Free;
  end;
end;

procedure loadlist(appname:String;filename:string;sender:tobject);
vAR x,z,I:INTEGER;
tlist:tchecklistbox;
begin
tlist:=sender as tchecklistbox;
 if sysutils.FileExists(ChangeFileExt(
  appname,'_Checklist.pid'))=false
 then exit;
  if filename='' then
  ini := TIniFile.Create(
  ChangeFileExt(
 appname,'_Checklist.pid')) else
  ini := TIniFile.Create(filename);
 try
    ini.ReadSection(tlist.name, tlist.Items);
    for i := 0 to tlist.Items.Count - 1 do
    tlist.Checked[i] := ini.ReadBool(tlist.name, tlist.Items[i], False);
  PIDCOUNTER.bytecount:=INI.ReadInteger ('PIDCOUNT','PBC',0);
  PIDCOUNTER.count:=INI.READINTEGER('PIDCOUNT','TSP',0);
  PIDCOUNTER.f_count:=INI.ReadInteger('PIDCOUNT','TFP',0);
  finally
    ini.Free;
  end;
end;


end.
