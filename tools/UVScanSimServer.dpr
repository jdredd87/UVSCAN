program UVScanSimServer;

{ Serves UVScan's simulated AVT and GM PCM on the network, as an AVT with an
  Ethernet port would be: for trying UVScan's Network (TCP/IP) connection
  without the hardware.

  UVScanSimServer [port] [address]

  port     default 10001
  address  default 0.0.0.0 (every network this PC is on; Windows asks once
           whether to let it through the firewall). 127.0.0.1 keeps it to
           this PC.

  In UVScan pick Network (TCP/IP) and type 127.0.0.1:10001 on this PC, or
  this PC's address (ipconfig) from a phone on the same Wi-Fi. An Android
  emulator reaches this PC as 10.0.2.2; a phone on USB can use
  "adb reverse tcp:10001 tcp:10001" and 127.0.0.1. Each connection gets a
  simulator of its own. Enter stops it. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils,
  UVScan.Hex in '..\src\UVScan.Hex.pas',
  UVScan.Serial in '..\src\UVScan.Serial.pas',
  UVScan.Avt in '..\src\UVScan.Avt.pas',
  UVScan.Class2 in '..\src\UVScan.Class2.pas',
  UVScan.Simulator in '..\src\UVScan.Simulator.pas';

var
  Server: TSimulatorServer;
  Port: Integer;
  Address: string;

begin
  Port := StrToIntDef(ParamStr(1), DefaultTcpPort);
  Address := ParamStr(2);
  if Address = '' then
    Address := '0.0.0.0';
  try
    Server := TSimulatorServer.Create(Port, Address,
      procedure(S: string)
      begin
        Writeln(FormatDateTime('hh:nn:ss  ', Now) + S);
      end);
    try
      Writeln(Format('Simulated AVT listening on %s:%d. In UVScan: Network (TCP/IP), address %s:%d.',
        [Address, Server.Port, IfThen(Address = '0.0.0.0', 'this PC''s', Address), Server.Port]));
      Writeln('Enter stops it.');
      Readln;
    finally
      Server.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
