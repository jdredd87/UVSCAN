unit Unit8;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Grids, StdCtrls, Menus;

type
  TForm8 = class(TForm)
    ptitle: TLabel;
    value: TLabel;
    units: TLabel;
    PopupMenu1: TPopupMenu;
    HideAllPIDWindows1: TMenuItem;
    ModifyPIDRowWindow1: TMenuItem;
    SaveLocations1: TMenuItem;

    procedure HideAllPIDWindows1Click(Sender: TObject);
    procedure ModifyPIDRowWindow1Click(Sender: TObject);
    procedure SaveLocations1Click(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
    pidrow:byte;
  end;

var
  Form8: TForm8;

implementation

uses unit1,gentypes,unit7, Unit6;

{$R *.dfm}

procedure TForm8.HideAllPIDWindows1Click(Sender: TObject);
 var cx:integer;
  begin

  if pp.count<=0 then  exit;

  for cx:=0 to pp.Count do
  with tform8(pp.List[scanner_pids[cx].pidwindowindex]) do hide;

  form1.CheckBox1.Checked:=false;
end;

procedure TForm8.ModifyPIDRowWindow1Click(Sender: TObject);
begin
form1.pid_grid.Row:=pidrow;
form1.modifypid(pidrow);
end;

procedure TForm8.SaveLocations1Click(Sender: TObject);
begin
         //d/d
         //d
end;

end.
