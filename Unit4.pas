unit Unit4;

interface

uses
Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls,GENTYPES;

type
  TForm4 = class(TForm)
    LabeledEdit1: TLabeledEdit;
    incit: TCheckBox;
    enable: TCheckBox;
    Button1: TButton;
    LabeledEdit2: TLabeledEdit;
    LabeledEdit3: TLabeledEdit;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form4: TForm4;

implementation

{$R *.dfm}

procedure TForm4.Button1Click(Sender: TObject);
begin
form4.Position:= podesktopcenter;
AUTONAME.NAMEHEADER1:=LABELEDEDIT1.TEXT;
autoname.nameheader2:=labelededit2.Text;
autoname.INCREMENTAL:=incit.Checked;
autoname.ENABLED:=enable.checked;
cfg.savepath:=labelededit3.Text;
form4.Hide;
end;

end.
