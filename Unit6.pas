unit Unit6;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Spin, ExtCtrls,gentypes;

type
  TForm6 = class(TForm)
    SpinEdit1: TSpinEdit;
    Label1: TLabel;
    Label2: TLabel;
    SpinEdit2: TSpinEdit;
    Label3: TLabel;
    Label4: TLabel;
    Button1: TButton;
    Button2: TButton;
    edit1: TEdit;
    Edit2: TEdit;
    colord: TColorDialog;
    Formula: TLabeledEdit;
    Result: TLabeledEdit;
    Button3: TButton;
    Button4: TButton;
    Label5: TLabel;
    Label6: TLabel;
    Button5: TButton;
    Button6: TButton;
    Edit3: TEdit;
    Edit4: TEdit;
    Label7: TLabel;
    spinedit3: TEdit;
    CheckBox1: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure SpinEdit1Change(Sender: TObject);
    procedure SpinEdit2Change(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure FormulaChange(Sender: TObject);
    procedure ResultChange(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure SpinEdit3Change(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    prow:integer;
    ppid:pid_rec;
  end;

var
  Form6: TForm6;
canchange:boolean=false;
implementation

uses Unit1,unit7;

{$R *.dfm}

procedure TForm6.Button1Click(Sender: TObject);
begin
if canchange=false then exit;
colord.color:=edit1.color;
if colord.Execute=true then
 edit1.Color:=colord.Color;
 form1.pid_grid.RowColor[prow]:=colord.color;
 scanner_pids[prow].grcolor:=colord.color;

 with tform(pp.List[scanner_pids[prow].pidwindowindex]) do
 begin
   color:=colord.color;
 end;

 end;

procedure TForm6.Button2Click(Sender: TObject);
var z:integer;
begin
if canchange=false then exit;
colord.Color:=edit2.color;
if colord.Execute=true then edit2.Color:=colord.Color;
form1.pid_grid.FontColors[1,prow]:=colord.color;
form1.pid_grid.FontColors[2,prow]:=colord.color;
scanner_pids[prow].gfcolor:=colord.color;

  with tform(pp.List[scanner_pids[prow].pidwindowindex]) do
        begin
           for z:=0 to controlcount-1 do
           if controls[z] is tlabel then
           tlabel(controls[z]).Font.Color:=
           colord.color;
        end;

 end;

procedure TForm6.Button3Click(Sender: TObject);
vaR X,Y:INTEGER;
    found:boolean;
    prow:integer;
begin
if MessageBox(application.handle,pchar('Save PIDGRID settings for '+ppid.LongName),pchar(Caption),mb_yesno or MB_DEFBUTTON2)=
              idno then exit;
prow:=form1.pid_grid.row;
// find it in the list
found:=false;
for x:=1 to pid_grid_config.RowCount do
if pid_grid_config.Cells[0,x]=ppid.PIDID then
begin
    form1.addmemoline('Found Updating : '+ppid.ShortName);
    pid_grid_config.Cells[0,x]:=scanner_pids[ppid.scanner_x].PIDID;
    pid_grid_config.Cells[1,x]:=scanner_pids[ppid.scanner_x].ShortName;
    pid_grid_config.Cells[2,x]:=inttostr(spinedit1.value);//inttostr(form1.pid_grid.RowHeights[ppid.scanner_x]);// '30'; // row
    pid_grid_config.Cells[3,x]:=inttostr(spinedit2.value);
    pid_grid_config.Cells[4,x]:=tcolortohex(edit1.color);
    pid_grid_config.Cells[5,x]:=tcolortohex(edit2.color);
    pid_grid_config.Cells[6,x]:=formula.Text;
    pid_grid_config.Cells[7,x]:=result.Text;
    pid_grid_config.Cells[8,x]:=tcolortohex(edit3.color);
    pid_grid_config.Cells[9,x]:=tcolortohex(edit4.color);
    pid_grid_config.Cells[10,x]:=(spinedit3.text);
    pid_grid_config.Cells[11,x]:= inttostr(tform(pp.List[scanner_pids[prow].pidwindowindex]).Top);
    pid_grid_config.Cells[12,x]:= inttostr(tform(pp.List[scanner_pids[prow].pidwindowindex]).left);
    pid_grid_config.Cells[13,x]:= inttostr(tform(pp.List[scanner_pids[prow].pidwindowindex]).width);
    pid_grid_config.Cells[14,x]:= inttostr(tform(pp.List[scanner_pids[prow].pidwindowindex]).height);
    pid_grid_config.cells[15,x]:=bootostr(checkbox1.checked);
    found:=true;
end;

if found=false then
begin
    pid_grid_config.RowCount:=pid_grid_config.RowCount+1;
    x:=pid_grid_config.RowCount-1;
    form1.addmemoline('Found Adding : '+ppid.ShortName);
    pid_grid_config.Cells[0,x]:=scanner_pids[ppid.scanner_x].PIDID;
    pid_grid_config.Cells[1,x]:=scanner_pids[ppid.scanner_x].ShortName;
    pid_grid_config.Cells[2,x]:=inttostr(spinedit1.value);//inttostr(form1.pid_grid.RowHeights[ppid.scanner_x]);// '30'; // row
    pid_grid_config.Cells[3,x]:=inttostr(spinedit2.value);
    pid_grid_config.Cells[4,x]:=tcolortohex(edit1.color);
    pid_grid_config.Cells[5,x]:=tcolortohex(edit2.color);
    pid_grid_config.Cells[6,x]:=formula.Text;
    pid_grid_config.Cells[7,x]:=result.Text;
    pid_grid_config.Cells[8,x]:=tcolortohex(edit3.color);
    pid_grid_config.Cells[9,x]:=tcolortohex(edit4.color);
    pid_grid_config.Cells[10,x]:=(spinedit3.text);
    pid_grid_config.Cells[11,x]:= inttostr(tform(pp.List[scanner_pids[prow].pidwindowindex]).Top);
    pid_grid_config.Cells[12,x]:= inttostr(tform(pp.List[scanner_pids[prow].pidwindowindex]).left);
    pid_grid_config.Cells[13,x]:= inttostr(tform(pp.List[scanner_pids[prow].pidwindowindex]).width);
    pid_grid_config.Cells[14,x]:= inttostr(tform(pp.List[scanner_pids[prow].pidwindowindex]).height);
    pid_grid_config.cells[15,x]:=bootostr(checkbox1.checked);

end;
PID_GRID_CONFIG.SaveToCSV('PIDGRID.CSV');

end;

procedure TForm6.Button4Click(Sender: TObject);
begin
if MessageBox(application.handle,pchar('Reset DEFAULT PIDGRID settings for '+ppid.LongName),pchar(Caption),mb_yesno or MB_DEFBUTTON2)=
              idno then exit;

SPINEDIT1.Value:=21;
SPINEDIT2.VALUE:=8;

checkbox1.Checked:=false;

if odd(PPID.pid_grid_row) then

EDIT1.COLOR:=HEXTOTCOLOR(CFG.secondary) ELSE
EDIT1.COLOR:=HEXTOTCOLOR(CFG.primary);

if odd(PPID.pid_grid_row) then

EDIT3.COLOR:=HEXTOTCOLOR(CFG.secondary) ELSE
EDIT3.COLOR:=HEXTOTCOLOR(CFG.primary);

EDIT2.COLOR:=CLBLACK;
edit4.color:=clblack;

spinedit3.text:='200000';

form1.pid_grid.RowColor[prow]:=EDIT1.COLOR;
form1.pid_grid.FontColors[1,prow]:=EDIT2.color;
form1.pid_grid.FontColors[2,prow]:=EDIT2.color;

end;

procedure TForm6.Button5Click(Sender: TObject);
begin
if canchange=false then exit;
colord.Color:=edit3.color;
if colord.Execute=true then edit3.Color:=colord.Color;
 scanner_pids[prow].wrcolor:=colord.color;
end;

procedure TForm6.Button6Click(Sender: TObject);
begin
if canchange=false then exit;
colord.Color:=edit4.color;
if colord.Execute=true then edit4.Color:=colord.Color;
 scanner_pids[prow].wfcolor:=colord.color;
end;

procedure TForm6.FormClose(Sender: TObject; var Action: TCloseAction);
begin
form6.Free;
end;

procedure TForm6.FormCreate(Sender: TObject);
begin
prow:=1;
end;

procedure TForm6.FormShow(Sender: TObject);
begin
canchange:=true;
end;

procedure TForm6.FormulaChange(Sender: TObject);
begin
gentypes.scanner_pids[prow].Formula:=formula.Text;
end;

procedure TForm6.ResultChange(Sender: TObject);
begin
gentypes.scanner_pids[prow].ResultsLookup:=result.Text;
end;

procedure TForm6.SpinEdit1Change(Sender: TObject);
begin
if canchange=false then exit;
form1.pid_grid.RowHeights[prow]:=spinedit1.Value;
end;

procedure TForm6.SpinEdit2Change(Sender: TObject);
begin
if canchange=false then exit;
form1.pid_grid.FontSizes[0,prow]:=spinedit2.Value; // skip this guy
form1.pid_grid.FontSizes[1,prow]:=spinedit2.Value;
form1.pid_grid.FontSizes[2,prow]:=spinedit2.Value;
end;

procedure TForm6.SpinEdit3Change(Sender: TObject);
begin

if canchange=false then exit;

if isnumber(spinedit3.Text) then
scanner_pids[prow].wfilter:=newstrtofloat(spinedit3.text);

end;

end.
