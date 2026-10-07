unit Unit2;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  AdWnPort,Dialogs, VrControls, VrGradient, StdCtrls,AdPort,

  adselcom,oomisc,
  gentypes;

type
  Tsetup_form = class(TForm)
    VrGradient1: TVrGradient;
    Label1: TLabel;
    ComboBox1: TComboBox;
    Label2: TLabel;
    ComboBox2: TComboBox;
    CheckBox1: TCheckBox;
    Label3: TLabel;
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure detectports;
    procedure CheckBox1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);

  private
    { Private declarations }


  public
    { Public declarations }
    comport:byte;
    BAUDRATE:LONGINT;
//  createdata:procedure;
  end;

var
  setup_form: Tsetup_form;

implementation

uses Unit1;

{$R *.dfm}


procedure Tsetup_form.Button1Click(Sender: TObject);
begin
//  a:=scanini.ReadInteger('COMPORT','COMM',0);
 // b:=round(scanini.ReadFloat('COMPORT','BAUDRATE',115200));
if MessageBox(application.handle,'Save Settings?',pchar(Caption),mb_yesno or MB_DEFBUTTON2)=
              idyes then begin
 scanini.WriteInteger('COMPORT','COMM',strtoint(combobox1.items[combobox1.ItemIndex]));
 scanini.WriteFloat('COMPORT','BAUDRATE',strtofloat(combobox2.items[combobox2.ItemIndex]));
 scanini.UpdateFile;
 hide;
 form1.createdata;
              end;



end;

procedure Tsetup_form.CheckBox1Click(Sender: TObject);
var x:byte;
begin
combobox1.Clear;
if checkbox1.Checked=false then detectports else
for x:= 0 to 255 do
combobox1.items.Add(inttostr(x));
combobox1.ItemIndex:=0;
for X:=1 to 255 do
   if inttostr(comport)=combobox1.items[X] then combobox1.ItemIndex:=X;
end;

procedure tsetup_form.detectports;
var
I : Integer;
begin
combobox1.Items.Clear;
combobox1.items.Add('0');

//ShowPortsInUse := False;
for I := 1 to 255 do
if IsPortAvailable(I) then
combobox1.Items.Add(inttostr(i));
//ListBox1.ITems.Add(format('Com%d is available', [I]));
//showmessage(inttostr(comport));
//SHOWMESSAGE(FLOATTOSTR(BAUDRATE));

if BAUDRATE=57600 THEN COMBOBOX2.ItemIndex:=1 ELSE
 COMBOBOX2.ItemIndex:=0;

for i:=1 to 255 do
   if inttostr(comport)=combobox1.items[i] then combobox1.ItemIndex:=i;

end;

procedure Tsetup_form.FormCreate(Sender: TObject);
begin
//  detectports;
end;


end.
