unit Unit5;

interface


uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,gentypes,
  Dialogs, Menus, Grids, BaseGrid, AdvGrid, ToolWin, ComCtrls, Series, TeEngine,
  ExtCtrls, TeeProcs, Chart, StdCtrls, AsgHTML, AsgImport, AdvObj;


type
  TForm5 = class(TForm)
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Exit1: TMenuItem;
    PopupMenu1: TPopupMenu;
    SortbyColumn1: TMenuItem;
    SaveDialog1: TSaveDialog;
    SavetoHTML1: TMenuItem;
    Graph1: TMenuItem;
    LineGraph1: TMenuItem;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    logview: TAdvStringGrid;
    TabSheet2: TTabSheet;
    GroupBox1: TGroupBox;
    Chart1: TChart;
    CheckBox1: TCheckBox;
    fstart: TLabeledEdit;
    fend: TLabeledEdit;
    ComboBox1: TComboBox;
    ComboBox2: TComboBox;
    ComboBox3: TComboBox;
    Button1: TButton;
    Button2: TButton;
    htmld: TAdvGridHTMLSettingsDialog;
    Settings1: TMenuItem;
    HTML1: TMenuItem;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SortbyColumn1Click(Sender: TObject);
    procedure SavetoHTML1Click(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure initlist;
    procedure Button1Click(Sender: TObject);
    PROCEDURE adddata(v:boolean);
    procedure Button2Click(Sender: TObject);
    procedure HTML1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form5: TForm5;

implementation

{$R *.dfm}


procedure tform5.initlist;
var x:byte;
begin
for x:=0 to logview.ColCount-1 do combobox1.Items.Add(logview.Cells[x,0]); // x
for x:=0 to logview.ColCount-1 do combobox2.Items.Add(logview.Cells[x,0] ) // y
end;

procedure tform5.adddata(v: Boolean);
var x,y:longint;
a,b,c:real;
begin

if v then
chart1.RemoveAllSeries; // clean it up first

case combobox3.ItemIndex of      // create the series
0:CHART1.AddSeries(TLINESERIES);
1:CHART1.AddSeries(TPOINTSERIES);
end;

if fstart.text='' then a:=-100000 else a:=newstrtofloat(fstart.Text);
if fend.text='' then b:=1000000 else b:=newstrtofloat(fend.Text);


case combobox3.ItemIndex of
0:begin
for x:=1 to logview.RowCount-1 do
begin

if logview.cells[combobox1.ItemIndex,x]='' then c:=0 else
c:=newstrtofloat(logview.cells[combobox1.ItemIndex,x]);

if (c>=a) and (c<=b) then chart1.series[0].AddXY(x,c,'');

end;
chart1.LeftAxis.Title.Caption:=combobox1.Items[combobox1.ItemIndex];
chart1.BottomAxis.Title.caption:='Row Count';
end;

1:begin
for x:=1 to logview.RowCount-1 do
begin
chart1.Series[0].AddXY(newstrtofloat(logview.Cells[combobox1.ItemIndex,x]),newstrtofloat(logview.Cells[combobox2.ItemIndex,x]),'');
end;
chart1.LeftAxis.Title.Caption:=combobox2.Items[combobox2.ItemIndex];
chart1.BottomAxis.Title.caption:=combobox1.Items[combobox1.ItemIndex];
end;
end;

end;

procedure TForm5.Button1Click(Sender: TObject);
var x,y:longint;
begin
adddata(true);
end;

procedure TForm5.Button2Click(Sender: TObject);
begin
adddata(false);
end;

procedure TForm5.CheckBox1Click(Sender: TObject);
begin
if checkbox1.Checked then
chart1.View3D:=true else
chart1.view3d:=false;
end;

procedure TForm5.FormClose(Sender: TObject; var Action: TCloseAction);
begin
form5.Free;
end;

procedure TForm5.FormCreate(Sender: TObject);
begin
//pagecontrol1.ActivePage:=form5.TabSheet1;
end;

procedure TForm5.HTML1Click(Sender: TObject);
begin
htmld.Execute;
end;

procedure TForm5.SavetoHTML1Click(Sender: TObject);
begin
if savedialog1.Execute then
logview.SaveToHTML(savedialog1.FileName);
end;

procedure TForm5.SortbyColumn1Click(Sender: TObject);
begin
logview.SortByColumn(logview.col);
end;

end.

















