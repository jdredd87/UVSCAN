unit Unit7;

interface
uses
  Windows, Messages, SysUtils, menus,Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls,gentypes;

type

 tFormX = class
    private
      // The data fields of this new class
      topx,
      leftx,
      widthx,
      heightx,
      handlex:longint;
      piddatax:pid_Rec;

    public
      // Properties to read these data values
      property top : longint
          read topx;
      property left : longint
          read leftx;

      property piddata:pid_rec
      read piddatax;

      property width:longint
       read widthx;
       property height:longint
       read heightx;

      property handle: longint
          read handlex;

      // Constructor
      constructor Create(const topx:longint;
            const leftx:longint;
            const width:longint;
            const height:longint;
            const handlex:longint;
            const piddatax:pid_rec);
  end;

  function addpidwindow(var p:pid_rec):boolean;
  procedure closewindows;

  var
  pidwindows:tlist;
  lastleft:integer;

  pp:tlist;

implementation

uses unit1,unit8;

constructor tformx.Create(const topx:longint;
            const leftx:longint;
            const width:longint;
            const height:longint;
            const handlex:longint;
            const piddatax:pid_rec);

begin
  // Save the passed parameters
self.topx:=topx;
self.leftx:=leftx;
self.handlex:=handlex;
self.widthx:=widthx;
self.heightx:=widthx;
self.piddatax:=piddata;
end;

  procedure closewindows;
  var cx:integer;
  begin
  for cx:=pp.count-1 downto 0 do
   begin
   with tform8(pp.list[cx]) do
     begin
     tform8(pp.list[cx]).Close;
     tform8(pp.List[cx]).Free;
     pp.Delete(cx);
     end;
   end;
pp.Clear;
for cx:=pidwindows.Count-1 downto 0 do
 begin
   pidwindows.Delete(cx);

 end;
  end;

function addpidwindow(var p:pid_rec):boolean;

var xx:longint;
    g:tform8;
begin
g:=tform8.Create(nil);
 pp.add(g);
with g do
 begin
   width:=200;
   height:=160;
   pidrow:=p.GRIDLINE;

   bordericons:=BORDERicons-[BIMAXIMIZE]-[biminimize];
   formstyle:=fsstayontop;

   color:=p.rcolor;

   xx:=handle;

 if pidwindows.count>0 then
 begin
  left:=lastleft;
  top:=TformX(pidwindows[pidwindows.count-1]).top+height;

  if left+width>screen.width then
   begin
     top:=0;
     inc(lastleft,width);
     lastlefT:=0;
     left:=lastleft;
   end;

  if top+height>screen.Height then
   begin
     top:=0;
     inc(lastleft,width);
     left:=lastleft;
   end;
 end else
 begin
   top:=0;
   left:=0;
 end;

   caption:=p.LongName;

   ptitle.Caption:=p.shortname;
   value.Caption:='--';
   units.Caption:=p.Units;

   pidwindows.add(tformx.Create(top,left,width,height,handle,p));
   HIDE;

 end;
 p.pidwindowindex:=pp.Count-1;

 end;

begin

pp:=tlist.create;
pidwindows:=tlist.Create;
lastleft:=0;

end.
