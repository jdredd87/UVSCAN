program uvscan;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  Unit4 in 'Unit4.pas' {Form4},
  Unit5 in 'Unit5.pas' {Form5},
  Unit6 in 'Unit6.pas' {Form6},
  Unit7 in 'Unit7.pas',
  Unit8 in 'Unit8.pas' {Form8};

{$R *.res}

begin


  Application.Initialize;
  Application.Title := 'UVScanner';

  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm4, Form4);
  Application.Run;
end.
