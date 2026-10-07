unit Unit3;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus,unit1,unit2, StdCtrls;

type
  TMainMDI = class(TForm)
    MainMenu1: TMainMenu;
    Connect1: TMenuItem;
    Scanner1: TMenuItem;
    Button1: TButton;
    procedure Scanner1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainMDI: TMainMDI;
  scans:array[1..4] of tform1;
  sx:byte=1;

implementation

{$R *.dfm}

procedure TMainMDI.Button1Click(Sender: TObject);
begin
scans[sx]:=tform1.Create(application);
scans[sx].Visible:=true;
inc(Sx);
end;
procedure TMainMDI.Scanner1Click(Sender: TObject);
var tscan:tform1;
begin
tscan:=tform1.Create(application);
tscan.Visible:=true;
end;

end.
