unit gauges;

interface


uses
  Windows, Messages, SysUtils,dialogs, Variants, Classes, Graphics, Controls, Forms,
  VrAngularMeter,comctrls, VrControls, VrGradient, StdCtrls,
   VrDigit, VrScope, VrProgressBar,vrLabel;

procedure create_gauge(sender:tobject;frm:TTabSheet; x,y:integer;
                       Name,Caption:String;
                       Min,Max:integer;
                       Color1,Color2,Color3:tcolor);



implementation

procedure create_gauge(sender:tobject;frm:TTabSheet; x,y:integer;
                       Name,Caption:String;
                       Min,Max:integer;
                       Color1,Color2,Color3:tcolor);

var vra:tvrangularmeter;
begin
vra:=tvrangularmeter.Create(nil);
vra.Caption:=caption;
vra.Name:=name;
vra.Left:=x;
vra.Top:=y;
vra.ColorZone1:=color1;
vra.colorzone2:=color2;
vra.ColorZone3:=color3;
vra.Decimals:=0;
vra.Parent:=frm;
end;

end.
