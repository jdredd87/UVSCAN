unit Unit1;

interface

uses
  shellapi, unit7,
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms,
  Dialogs, StdCtrls, oomisc, AdPort, CheckLst, ComCtrls, Menus,
  ToolWin, ExtCtrls, formula, grids, basegrid, advgrid, stdconvs,
  AdWnPort, inifiles, unit5, gentypes,
  AdPacket, Buttons,
  VrThreads, OleCtrls, MTSSDKLib_TLB,
  AdvObj;

type

  TForm1 = class(TForm)
    ToolBar1: TToolBar;
    ConnectAVT: TToolButton;
    pcminfob: TToolButton;
    ScannerB: TToolButton;
    Startlogb: TToolButton;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    saveCSV: TSaveDialog;
    Setup1: TMenuItem;
    FileM: TMenuItem;
    LoadSavedList1: TMenuItem;
    SavePidList1: TMenuItem;
    ClearCheckedPIDs1: TMenuItem;
    pidlistsave: TSaveDialog;
    pidlistopen: TOpenDialog;
    About1: TMenuItem;
    About2: TMenuItem;
    forma: TArtFormula;
    comport: TApdWinsockPort;
    avtinit: TApdDataPacket;
    AVTSPEED: TApdDataPacket;
    avtversion: TApdDataPacket;
    AVTVIN1: TApdDataPacket;
    AVTVIN2: TApdDataPacket;
    AVTVIN3: TApdDataPacket;
    AVTOSID: TApdDataPacket;
    blockFE: TApdDataPacket;
    BLOCKFD: TApdDataPacket;
    BLOCKFC: TApdDataPacket;
    BLOCKFB: TApdDataPacket;
    BLOCKFA: TApdDataPacket;
    BLOCKF9: TApdDataPacket;
    BLOCKF8: TApdDataPacket;
    BLOCKF7: TApdDataPacket;
    DisconnectB: TToolButton;
    ADPORTS: TApdDataPacket;
    pauseb: TToolButton;
    BADPID: TApdDataPacket;
    Logging: TMenuItem;
    AutoName1: TMenuItem;
    PIDPanel: TPageControl;
    TabSheet9: TTabSheet;
    PIDPage: TPageControl;
    TabSheet1: TTabSheet;
    EnginePids: TCheckListBox;
    TabSheet2: TTabSheet;
    TrannyPids: TCheckListBox;
    TabSheet3: TTabSheet;
    indypids: TCheckListBox;
    TabSheet4: TTabSheet;
    BodyPids: TCheckListBox;
    TabSheet5: TTabSheet;
    ACCPids: TCheckListBox;
    TabSheet6: TTabSheet;
    otherpids: TCheckListBox;
    TabSheet10: TTabSheet;
    fakepids: TCheckListBox;
    TabSheet11: TTabSheet;
    ad: TCheckListBox;
    MTS: TMTS;
    TabSheet7: TTabSheet;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    pid_grid: TAdvStringGrid;
    N1: TMenuItem;
    estVehicleforPIDS1: TMenuItem;
    TabSheet8: TTabSheet;
    Edit1: TEdit;
    Button1: TButton;
    Label1: TLabel;
    vinupdate: TLabeledEdit;
    Button2: TButton;
    GroupBox2: TGroupBox;
    Button3: TButton;
    Button5: TButton;
    Button4: TButton;
    VrTimer1: TVrTimer;
    Logcolor1: TMenuItem;
    OpenLOG1: TMenuItem;
    LogOpen: TOpenDialog;
    DTCs1: TMenuItem;
    ReadDTCs1: TMenuItem;
    ClearDTCs1: TMenuItem;
    dtc_ago: TApdDataPacket;
    dtc_find: TApdDataPacket;
    pidpop: TPopupMenu;
    ModifySelectedPID1: TMenuItem;
    ResetallRows1: TMenuItem;
    CheckBox1: TCheckBox;
    ShowGauge1: TMenuItem;
    HideGauge1: TMenuItem;
    HideallPIDWindow1: TMenuItem;
    FindModules: TApdDataPacket;
    sbar: TStatusBar;
    STOPSCANNER: TToolButton;
    Timer1: TTimer;
    CHECKPID1: TApdDataPacket;
    CHECKPID2: TApdDataPacket;
    checkpid3: TApdDataPacket;
    EnableallPids1: TMenuItem;
    portlist: TListBox;
    wbfire: TButton;
    Button6: TButton;
    AFRLabel: TLabel;
    GroupBox1: TGroupBox;
    statusmemo: TMemo;
    Panel1: TPanel;
    StaticText5: TStaticText;
    pbs: TStaticText;
    tfp: TStaticText;
    StaticText6: TStaticText;
    StaticText4: TStaticText;
    StaticText2: TStaticText;
    tsp: TStaticText;
    StaticText3: TStaticText;
    pbc: TStaticText;
    StaticText1: TStaticText;
    LambaLabel: TLabel;

    procedure modifypid(xx: Byte);

    procedure pcminfobClick(Sender: TObject);

    procedure FormClose(Sender: TObject; var Action: TCloseAction);

    procedure add_pidlist(t: pid_Rec; b: Byte);
    procedure ScannerBClick(Sender: TObject);

    function calculate(N: Boolean; formula: string; value1, value2, value3, value4: Real): string;

    procedure addpidtolist(Sender: TObject);

    procedure pidsize(Sender: TObject);
    procedure createdata;
    procedure Setup1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);

    procedure loadlist(FileName: string; Sender: TObject);
    procedure savelist(FileName: string; Sender: TObject);
    procedure ClearCheckedPIDs1Click(Sender: TObject);
    procedure SavePidList1Click(Sender: TObject);
    procedure LoadSavedList1Click(Sender: TObject);
    procedure ConnectAVTClick(Sender: TObject);
    procedure avtinitStringPacket(Sender: TObject; Data: string);
    procedure avtversionStringPacket(Sender: TObject; Data: string);
    procedure AVTSPEEDStringPacket(Sender: TObject; Data: string);
    procedure AVTVIN1StringPacket(Sender: TObject; Data: string);
    procedure AVTVIN2StringPacket(Sender: TObject; Data: string);
    procedure AVTVIN3StringPacket(Sender: TObject; Data: string);
    procedure AVTOSIDStringPacket(Sender: TObject; Data: string);

    function PCMINFO(SKIP: Boolean): Boolean;

    procedure sendcommand(s: string; wait: Word);
    procedure blockFEStringPacket(Sender: TObject; Data: string);
    procedure DisconnectBClick(Sender: TObject);
    procedure StartlogbClick(Sender: TObject);
    procedure pausebClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure SpeedButton2Click(Sender: TObject);
    procedure BADPIDStringPacket(Sender: TObject; Data: string);
    procedure pid_gridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TabSheet7Show(Sender: TObject);
    procedure AutoName1Click(Sender: TObject);
    procedure About2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure estVehicleforPIDS1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure checkline(Sender: string);
    procedure VrTimer1Timer(Sender: TObject);
    procedure OpenLOG1Click(Sender: TObject);
    procedure ReadDTCs1Click(Sender: TObject);
    procedure dtc_agoStringPacket(Sender: TObject; Data: string);
    procedure dtc_findStringPacket(Sender: TObject; Data: string);
    procedure wbfireClick(Sender: TObject);
    procedure ClearDTCs1Click(Sender: TObject);
    procedure dtc_findTimeout(Sender: TObject);
    procedure ModifySelectedPID1Click(Sender: TObject);
    procedure pidpopPopup(Sender: TObject);
    procedure ResetallRows1Click(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure ShowGauge1Click(Sender: TObject);
    procedure HideGauge1Click(Sender: TObject);
    procedure HideallPIDWindow1Click(Sender: TObject);
    procedure FindModulesStringPacket(Sender: TObject; Data: string);
    procedure STOPSCANNERClick(Sender: TObject);
    procedure addmemoline(s: string);
    procedure FormShow(Sender: TObject);
    procedure CHECKPID2StringPacket(Sender: TObject; Data: string);
    procedure CHECKPID1StringPacket(Sender: TObject; Data: string);
    procedure checkpid3StringPacket(Sender: TObject; Data: string);
    procedure CHECKPID1Timeout(Sender: TObject);
    procedure EnableallPids1Click(Sender: TObject);
    procedure MTSConnectionError(Sender: TObject);
    procedure MTSConnectionEvent(ASender: TObject; Result: Integer);
    procedure MTSNewData(Sender: TObject);
    procedure portlistClick(Sender: TObject);
    procedure Button6Click(Sender: TObject);
  private

  public
    procedure WMHotKey(var Msg: TWMHotKey); message WM_HOTKEY;
    { Public declarations }
  end;

var

  Form1: TForm1;
  sysinfo: _SYSTEM_INFO;
  FE_Counter: Byte = 0; // use this to send keep alive
  BAD_PID: Boolean = false;
  HOTKEY1: Integer;
  testingpids: Boolean = false;
  sentcommand: Boolean = false;
  sendhb: Boolean = false;

implementation

uses unit8, Unit4, Unit6;

{$R *.dfm}

procedure TForm1.addmemoline(s: string);
begin
  statusmemo.Lines.add(s);
  statusmemo.Perform(EM_LINESCROLL, 0, 255);
end;

procedure TForm1.WMHotKey(var Msg: TWMHotKey);
begin
  if Msg.HotKey = HOTKEY1 then
  begin
    if (scannerrunning = false) then
      Exit
    else

      Form1.Startlogb.Click;
  end;
end;

procedure TForm1.savelist(FileName: string; Sender: TObject);
var
  X, i: Integer;
  TList: TCheckListBox;
begin
  TList := Sender as TCheckListBox;
  if TList.Items.Count = 0 then
    Exit;

  if UpperCase(FileName) = 'UVSCAN_CHECKLIST.PID' then
    FileName := ExtractFilePath(application.ExeName) + 'UVSCAN_CHECKLIST.PID';

  ini := TIniFile.Create(FileName);

  try
    for i := 0 to TList.Items.Count - 1 do
    begin
      if TList.Checked[i] then
        X := 1
      else
        X := 0;

      if TList.ItemEnabled[i] = false then
        X := 2;

      ini.WriteInteger(TList.Name, TList.Items[i], X);
    end;

    ini.WriteInteger('PIDCOUNT', 'PBC', PIDCOUNTER.bytecount);
    ini.WriteInteger('PIDCOUNT', 'TSP', PIDCOUNTER.Count);
    ini.WriteInteger('PIDCOUNT', 'TFP', PIDCOUNTER.F_count);
  finally
    ini.Free;
  end;
end;

procedure TForm1.loadlist(FileName: string; Sender: TObject);
var
  X, z, i: Integer;
  TList: TCheckListBox;
  r: Integer;
begin
  TList := Sender as TCheckListBox;

  if SysUtils.FileExists(GetCurrentDir + '\' + 'uvscan_Checklist.pid') = false then
    Exit;
  if FileName = '' then
    ini := TIniFile.Create(GetCurrentDir + '\' + 'uvscan_Checklist.pid')
  else
    ini := TIniFile.Create(FileName);

  try
    ini.ReadSection(TList.Name, TList.Items);
    for i := 0 to TList.Items.Count - 1 do
    begin
      r := ini.ReadInteger(TList.Name, TList.Items[i], 0);
      TList.ItemEnabled[i] := true;
      case r of
        0:
          TList.Checked[i] := false;
        1:
          TList.Checked[i] := true;
        2:
          begin;
            TList.Checked[i] := false;
            TList.ItemEnabled[i] := false;
          end;
      end;
    end;
    PIDCOUNTER.bytecount := ini.ReadInteger('PIDCOUNT', 'PBC', 0);
    PIDCOUNTER.Count := ini.ReadInteger('PIDCOUNT', 'TSP', 0);
    PIDCOUNTER.F_count := ini.ReadInteger('PIDCOUNT', 'TFP', 0);
  finally
    ini.Free;
  end;
  pbc.Caption := IntToStr(PIDCOUNTER.bytecount);
  tsp.Caption := IntToStr(PIDCOUNTER.Count);
  tfp.Caption := IntToStr(PIDCOUNTER.F_count);
end;

procedure TForm1.LoadSavedList1Click(Sender: TObject);
var
  X: Integer;
begin
  if pidlistopen.Execute then
  begin
    for X := 0 to EnginePids.Count - 1 do
      EnginePids.Checked[X] := false;
    for X := 0 to TrannyPids.Count - 1 do
      TrannyPids.Checked[X] := false;
    for X := 0 to BodyPids.Count - 1 do
      BodyPids.Checked[X] := false;
    for X := 0 to indypids.Count - 1 do
      indypids.Checked[X] := false;
    for X := 0 to fakepids.Count - 1 do
      fakepids.Checked[X] := false;
    for X := 0 to ad.Count - 1 do
      ad.Checked[X] := false;
    for X := 0 to ACCPids.Count - 1 do
      ACCPids.Checked[X] := false;
    for X := 0 to otherpids.Count - 1 do
      otherpids.Checked[X] := false;
    FillChar(PIDCOUNTER, SizeOf(PIDCOUNTER), #0);
    pbc.Caption := IntToStr(PIDCOUNTER.bytecount);
    tsp.Caption := IntToStr(PIDCOUNTER.Count);
    tfp.Caption := IntToStr(PIDCOUNTER.F_count);
    loadlist(pidlistopen.FileName, EnginePids);
    loadlist(pidlistopen.FileName, TrannyPids);
    loadlist(pidlistopen.FileName, indypids);
    loadlist(pidlistopen.FileName, BodyPids);
    loadlist(pidlistopen.FileName, ACCPids);
    loadlist(pidlistopen.FileName, ad);
    loadlist(pidlistopen.FileName, fakepids);
    loadlist(pidlistopen.FileName, otherpids);
  end;
end;

procedure TForm1.modifypid(xx: Byte);
var
  g: TColor;
  prow2: Integer;
  fz: Integer;
  h: TColor;
begin

  prow2 := xx;
  fz := pid_grid.FontSizes[1, prow2];

  if pid_grid.Cells[0, prow2] = '' then
    Exit;

  with tform6.Create(application) do
  begin
    ppid := scanner_pids[prow2];
    ppid.pid_grid_row := prow2;
    ppid.scanner_x := prow2;

    FormStyle := fsstayontop;
    Caption := 'PID Grid Editor : ' + pid_grid.Cells[0, prow2];
    prow := prow2;
    pid_grid.Row := prow2;
    pid_grid.Col := 1;
    formula.EditLabel.Caption := scanner_pids[prow].LongName + ' Formula';
    formula.Text := scanner_pids[prow].formula;
    Result.Text := scanner_pids[prow].ResultsLookup;

    SpinEdit1.Value := pid_grid.RowHeights[prow2];
    spinedit2.Value := fz;

    spinedit3.Text := FloatToStr(scanner_pids[prow].wfilter);

    Edit1.Color := scanner_pids[prow].grcolor;
    edit2.Color := scanner_pids[prow].gfcolor;
    edit3.Color := scanner_pids[prow].wrcolor;
    edit4.Color := scanner_pids[prow].wfcolor;

    Show;
  end;
end;

procedure TForm1.ModifySelectedPID1Click(Sender: TObject);
begin
  modifypid(pid_grid.Row);
end;

procedure TForm1.MTSConnectionError(Sender: TObject);
begin
  addmemoline('******** WB INIT FAILED ********');
  cfg.WBVALUE := '-1';
end;

procedure TForm1.MTSConnectionEvent(ASender: TObject; Result: Integer);
begin
  if Result = 0 then
  begin
    addmemoline('****** WB INIT PASSED ******');
    MTS.StartData();
  end
  else
  begin
    addmemoline('*** WB INIT FAILED *** ERROR :' + IntToStr(Result));
    cfg.WBVALUE := '-1';
  end;
end;

procedure TForm1.MTSNewData(Sender: TObject);
var
  Value, value2: Double;
  sample: Integer;
  ICOUNT, N: Integer;
begin
  ICOUNT := MTS.InputCount;
  Dec(ICOUNT);
  if ICOUNT = -1 then
    Exit;
  for N := 0 to ICOUNT do
  begin
    MTS.CurrentInput := N;

    begin
      case MTS.InputType of

        0:
          if MTS.InputFunction = 0 then
          begin
            sample := MTS.InputSample;
            value2 := sample;
            value2 := Value / 1000;
            value2 := Value + 0.5;
            cfg.LambaVALUE := Format('%.1f', [value2]);
            LambaLabel.Caption := Format('%.1f', [value2]);
          end;
        1:
          if MTS.InputFunction = 0 then
          begin
            sample := MTS.InputSample;
            Value := sample;
            Value := Value / 1000;
            Value := Value + 0.5;
            Value := Value * MTS.InputAFRMultiplier;
            if Value > 22.4 then
              Value := 22.4
            else if Value < 7.4 then
              Value := 7.4;
            cfg.WBVALUE := Format('%.1f', [Value]);
            AFRLabel.Caption := Format('%.1f', [Value]);
          end;
        2:
          begin
            if MTS.InputFunction = 9 then
            begin
              Value := MTS.InputMaxValue - MTS.InputMinValue;
              sample := MTS.InputSample;
              Value := (Value * sample) / 1024;
              Value := Value + MTS.InputMinValue;
            end
            else
              Value := MTS.InputFunction * -1;

            if MTS.InputName = 'TC4_1' then
              cfg.TC4_1 := Format('%.1f', [Value]);
            if MTS.InputName = 'TC4_2' then
              cfg.TC4_2 := Format('%.1f', [Value]);
            if MTS.InputName = 'TC4_3' then
              cfg.TC4_3 := Format('%.1f', [Value]);
            if MTS.InputName = 'TC4_4' then
              cfg.TC4_4 := Format('%.1f', [Value]);
          end;

      else
        Value := MTS.InputFunction * -1;
      end;
    end;
  end;
end;

procedure TForm1.OpenLOG1Click(Sender: TObject);
begin
  if LogOpen.Execute = false then
    Exit;

  with tform5.Create(application) do
  begin
    FormStyle := fsstayontop;
    WindowState := wsmaximized;
    Caption := LogOpen.FileName;
    Show;
    logview.LoadFromCSV(LogOpen.FileName);
    initlist;
    pagecontrol1.ActivePageIndex := 0;
    logview.AutoFitColumns;
  end;
end;

procedure TForm1.sendcommand(s: string; wait: Word);
begin

  s := UpperCase(s);
  s := trimspaces(s);
  s := hextostring(s);

  try
    try
      comport.PutString(s);
    finally
      if wait <> 0 then

        delayticks(wait, true);
    end;
  except
    if comport.dsr = false then
      big_done := true;

    addmemoline('Error Sending : ' + stringtohex(s));
  end;
end;

function TForm1.PCMINFO(SKIP: Boolean): Boolean;
var
  failedinit: Boolean;
  wx: Byte;

  procedure fmessage(b: Byte);
  begin
    failedinit := true;
    case b of
      1:
        addmemoline('FIRMWARE Version Failed');
      2:
        addmemoline('Vehicle VIN Failed');
    end;
    ConnectAVT.Enabled := true;
    pcminfob.Enabled := false;
    ScannerB.Enabled := false;
    STOPSCANNER.Enabled := false;
    DisconnectB.Enabled := false;
    Startlogb.Enabled := false;
    comport.Open := false; // added 5-29-08 , close the port if failed!
    if cfg.WB = 1 then

      MTS.Disconnect;
  end;

begin
  FillChar(vehicle, SizeOf(vehicle), #0);
  failedinit := false;

  blockFE.Enabled := false;
  BLOCKFD.Enabled := false;
  BLOCKFC.Enabled := false;
  BLOCKFB.Enabled := false;
  BLOCKFA.Enabled := false;
  BLOCKF9.Enabled := false;
  BLOCKF8.Enabled := false;
  BLOCKF7.Enabled := false;

  avtinit.Enabled := true;
  avtversion.Enabled := true;
  AVTVIN1.Enabled := true;
  AVTVIN2.Enabled := true;
  AVTVIN3.Enabled := true;
  AVTOSID.Enabled := true;

  if cfg.SENDVPW = 1 then
    sendcommand('E133', 5)
  else
    sendcommand('E133', 5);
  sendcommand('B0', 5);
  sendcommand('056C10F13C01', 5);
  sendcommand('056C10F13C02', 5);
  sendcommand('056C10F13C03', 5);
  sendcommand('056C10F13C0A', 10);

  for wx := 1 to 20 do
  begin
    if vehicle.firmware <> '' then
      if vehicle.vin <> '' then
        if vehicle.osid <> '' then
          Break;

    Sleep(100);
    application.ProcessMessages;
    addmemoline('Attempting to gather data try #' + IntToStr(wx));
  end;

  sbar.Panels[0].Text := 'FIRMWARE ' + vehicle.firmware;
  sbar.Panels[1].Text := 'VIN  ' + vehicle.vin;
  sbar.Panels[2].Text := 'PCM OSID ' + vehicle.osid;

  if Length(vehicle.firmware) < 1 then
    fmessage(1);
  if Length(vehicle.vin) < 17 then
    fmessage(2);

  if failedinit = false then
  begin
    pcminfob.Enabled := true;
    ScannerB.Enabled := true;
    DisconnectB.Enabled := true;
    logstatus := 0;
  end;
end;

procedure TForm1.AutoName1Click(Sender: TObject);
begin
  FORM4.LabeledEdit1.Text := AUTONAME.NAMEHEADER1;
  FORM4.LABELEDEDIT2.Text := AUTONAME.nameheader2;
  FORM4.LabeledEdit3.Text := cfg.savepath;
  FORM4.enable.Checked := AUTONAME.Enabled;
  FORM4.incit.Checked := AUTONAME.INCREMENTAL;
  FORM4.Show;
end;

procedure TForm1.avtinitStringPacket(Sender: TObject; Data: string);
begin
  addmemoline('AVT INIT Passed');
end;

procedure TForm1.AVTOSIDStringPacket(Sender: TObject; Data: string);
var
  s: string;
  v: Longint;
begin
  Delete(Data, 1, 5);
  s := stringtohex(Data);
  v := NEWSTRTOINT('$' + s);
  vehicle.osid := IntToStr(v);
  addmemoline('OSID : ' + vehicle.osid);
end;

// 01 60 0C 00
// 6C F1 10 7C 0A 00 C0 04 78

procedure TForm1.AVTSPEEDStringPacket(Sender: TObject; Data: string);
begin
  addmemoline('SPEED Set');
end;

procedure TForm1.avtversionStringPacket(Sender: TObject; Data: string);
begin
  vehicle.firmware := stringtohex(Data[3]);
  addmemoline('AVT Version ' + vehicle.firmware);
end;

procedure TForm1.AVTVIN1StringPacket(Sender: TObject; Data: string);
begin
  vehicle.vin := '';
  addmemoline('VIN Part 1');
  Delete(Data, 1, 8);
  vehicle.vin := Data;
end;

procedure TForm1.AVTVIN2StringPacket(Sender: TObject; Data: string);
begin
  addmemoline('VIN Part 2');
  Delete(Data, 1, 7);
  vehicle.vin := vehicle.vin + Data;
end;

procedure TForm1.AVTVIN3StringPacket(Sender: TObject; Data: string);
begin
  addmemoline('VIN Part 3');
  Delete(Data, 1, 7);
  vehicle.vin := vehicle.vin + Data;
  addmemoline('Vehicle VIN : ' + (vehicle.vin));
end;

procedure TForm1.BADPIDStringPacket(Sender: TObject; Data: string);
var
  PIDID: string;
  X: Integer;
begin

  BAD_PID := true;

  if testingpids = false then
  begin
    addmemoline('PID NOT SUPPORTED: ' + stringtohex(Data));
    addmemoline('POSSIBLE BAD SCAN DATA WILL HAPPEN!');
  end;
end;

procedure TForm1.checkline(Sender: string);
var
  cx, cy: Integer;
  mydate: tdatetime;
  rs: string;
  gstr: TStringList;
  tx: TStringList;
begin
  cy := 0;
  if logstatus <> 1 then
    Exit;
  tx := TStringList.Create;
  tx.Clear;
  tx.add(IntToStr(scani.linecount));
  finish := Now() - start;

  for cx := 1 to pid_grid.RowCount do
    if pid_grid.Cells[0, cx] <> '' then // filter out blank lines?!
      tx.add(pid_grid.Cells[1, cx]);

  Form1.sbar.Panels[4].Text := 'LINECOUNT ' + IntToStr(scani.linecount);
  log_grid.Rows[scani.linecount] := tx;
  Inc(scani.linecount);
  log_grid.RowCount := scani.linecount + 1;
  Writeln(backupcsv, tx.DelimitedText);
  tx.Free;
end;

procedure TForm1.blockFEStringPacket(Sender: TObject; Data: string);

  procedure checkwarning(final_calc: string; cx: Integer);
  begin
    if isnumber(final_calc) then
    begin
      if pid_grid.Colors[2, scanner_pids[cx].gridline] <> scanner_pids[cx].gfcolor then
      begin
        if (newstrtofloat(final_calc) < scanner_pids[cx].wfilter) and (scanner_pids[cx].grcolor <> pid_grid.Colors[2, cx]) then
          with tform8(pp.list[scanner_pids[cx].pidwindowindex]) do
            try
              begin
                Color := scanner_pids[cx].grcolor;
                Value.Font.Color := scanner_pids[cx].gfcolor;
                ptitle.Font.Color := scanner_pids[cx].gfcolor;
                units.Font.Color := scanner_pids[cx].gfcolor;
                pid_grid.RowColor[cx] := scanner_pids[cx].grcolor;
                pid_grid.FontColors[1, cx] := scanner_pids[cx].gfcolor;
                pid_grid.FontColors[2, cx] := scanner_pids[cx].gfcolor;
              end;
            except
            end
        else if (newstrtofloat(final_calc) >= scanner_pids[cx].wfilter) and (scanner_pids[cx].wrcolor <> pid_grid.Colors[2, cx])
        then
        begin
          with tform8(pp.list[scanner_pids[cx].pidwindowindex]) do
            try
              begin
                Color := scanner_pids[cx].wrcolor;
                Value.Font.Color := scanner_pids[cx].wfcolor;
                ptitle.Font.Color := scanner_pids[cx].wfcolor;
                units.Font.Color := scanner_pids[cx].wfcolor;
                pid_grid.RowColor[cx] := scanner_pids[cx].wrcolor;
                pid_grid.FontColors[1, cx] := scanner_pids[cx].wfcolor;
                pid_grid.FontColors[2, cx] := scanner_pids[cx].wfcolor;
              end;
            except
            end;
        end;
      end;
    end;
  end;

  procedure fixresult(var s: string; r: string);
  var
    Temp: string;
    Y, X: Integer;
  begin
    Temp := s;
    r := LowerCase(r);
    for X := 1 to Length(r) - 1 do
      if isnumber(s) = true then
      begin
        case r[X] of
          '*': // temp changes
            case r[X + 1] of
              'c':
                Temp := FloatToStr(FahrenheitToCelsius(newstrtofloat(Temp)));
              'f':
                Temp := FloatToStr(CelsiusToFahrenheit(newstrtofloat(Temp)));
            end;
          '%': // value formatting
            case r[X + 1] of
              'f':
                Temp := Format('%f', [newstrtofloat(Temp)]);
              'd':
                Temp := Format('%d', [Round(newstrtofloat(Temp))]);
              'y':
                begin
                  Temp := IntToStr(Round(newstrtofloat(Temp)));
                  if Temp = '0' then
                    Temp := 'NO'
                  else if Temp = '1' then
                    Temp := 'YES';
                end;
              'o':
                begin
                  Temp := IntToStr(Round(newstrtofloat(Temp)));
                  if Temp = '0' then
                    Temp := 'OFF'
                  else if Temp = '1' then
                    Temp := 'ON';
                end;
            end;
        end;
        s := Temp;
      end;
  end;

  procedure processdata(pd: string);
  var
    ppx: Integer;
    Pid_Var1, Pid_Var2, Pid_Var3, Pid_Var4, temp_debug_str, final_calc: string;
    // variables and final calc
    MCIX, cx, cy, CZ: Integer; // Dummy Counters
    Varo1, Varo2, varo3, varo4: Real; // Number value for Variables
    Temp_PD: string; // Copy PD over to this to modify
    DummyStr: string; // Dummy String to play with
    Block_ID: Byte;
    frmstr: string; // copy formula to this and convert
    smcix, smicy: Integer;
    TESTMCI: string;
    tx: Byte;
    i: Longint;
  begin
    Temp_PD := pd;
    Block_ID := Ord(pd[7]); // stores 7th byte , like FE FD FC FB
    if sbar.Panels[7].Text <> '' then
      if sentcommand = true then
      begin;
        sendcommand(SENDCOMMANDS.command2, 0);
        sentcommand := false;
      end;

    sbar.Panels[7].Text := '';

    if Chr(Block_ID) in [#254, #253, #252, #251, #250, #249, #248, #247] then
    begin
      Delete(Temp_PD, 1, 7); // Kills up to the BLOCK ID
      if Length(pd) = 0 then
        Exit;
      for cx := 1 to scani.Pid_Count do // go through the pids
        if Block_ID = scanner_pids[cx].blockid then
          // if start // compares block ID's
          if (scanner_pids[cx].PCMPID <> 'FPID') and (scanner_pids[cx].PCMPID <> 'FFFF') and (scanner_pids[cx].PCMPID <> 'FFFD')
            and (scanner_pids[cx].PCMPID <> 'FFFE') then
          begin // IF BEGIN
            Pid_Var1 := '';
            Pid_Var2 := '';
            Varo1 := 0; // clear data!
            Varo2 := 0;
            Pid_Var3 := '';
            Pid_Var4 := '';
            varo3 := 0; // clear data!
            varo4 := 0;

            DummyStr := '';
            case NEWSTRTOINT(scanner_pids[cx].DataLength) of
              1:
                begin
                  Pid_Var1 := Copy(Temp_PD, scanner_pids[cx].PIDPos, 1);
                  Varo1 := Ord(Pid_Var1[1]);
                  Varo2 := 0;
                end;

              2:
                begin // CASE 2  BEGIN
                  Pid_Var1 := Copy(Temp_PD, scanner_pids[cx].PIDPos, 1);
                  Pid_Var2 := Copy(Temp_PD, scanner_pids[cx].PIDPos + 1, 1);
                  Varo1 := Ord(Pid_Var1[1]);
                  Varo2 := Ord(Pid_Var2[1]);
                end; // CASE 2 END

              3:
                begin // CASE 3  BEGIN
                  Pid_Var1 := Copy(Temp_PD, scanner_pids[cx].PIDPos, 1);
                  Pid_Var2 := Copy(Temp_PD, scanner_pids[cx].PIDPos + 1, 1);
                  Pid_Var3 := Copy(Temp_PD, scanner_pids[cx].PIDPos + 2, 1);
                  Varo1 := Ord(Pid_Var1[1]);
                  Varo2 := Ord(Pid_Var2[1]);
                  varo3 := Ord(Pid_Var3[1]);
                end; // CASE 3 END

              4:
                begin // CASE 4 BEGIN
                  Pid_Var1 := Copy(Temp_PD, scanner_pids[cx].PIDPos, 1);
                  Pid_Var2 := Copy(Temp_PD, scanner_pids[cx].PIDPos + 1, 1);
                  Pid_Var3 := Copy(Temp_PD, scanner_pids[cx].PIDPos + 2, 1);
                  Pid_Var4 := Copy(Temp_PD, scanner_pids[cx].PIDPos + 3, 1);

                  Varo1 := Ord(Pid_Var1[1]);
                  Varo2 := Ord(Pid_Var2[1]);
                  varo3 := Ord(Pid_Var3[1]);
                  varo4 := Ord(Pid_Var4[1]);
                end; // CASE 3 END
            end; // CASE END

            frmstr := scanner_pids[cx].formula;

            try
              final_calc := Form1.calculate(false, frmstr, Varo1, Varo2, varo3, varo4);
              // calculate it
            except
              final_calc := '-666';
            end;

            if scanner_pids[cx].ResultsLookup <> '' then
              fixresult(final_calc, scanner_pids[cx].ResultsLookup);

            checkwarning(final_calc, cx);

            with tform8(pp.list[scanner_pids[cx].pidwindowindex]) do
              try
                Value.Caption := final_calc;
              except
              end;

            scanner_pids[cx].Value := final_calc;
            Form1.pid_grid.Cells[1, cx] := final_calc;
            // put data on the string grid view
            TESTMCI := UpperCase(scanner_pids[cx].mci);
            temp_debug_str := final_calc;
            if TESTMCI = UpperCase(SENDCOMMANDS.mcicode) then
            begin
              if newstrtofloat(final_calc) >= newstrtofloat(SENDCOMMANDS.Value) then
              begin
                if sentcommand = false then
                begin
                  sendcommand(SENDCOMMANDS.COMMAND1, 0);
                  sbar.Panels[7].Text := 'SENDCOMMAND';
                  sentcommand := true;
                end;
              end;
            end;

            if logstatus = 1 then
            begin
            end;
          end; // IF BEGIN/END
    end;
  end; // FOR BEGIN/END

  procedure processad(adstr: string);
  var
    ccx: Integer;
    ccfs: string;
    gr: Byte;
    adreal: string;
    bx: Integer;
    cx: Integer;
  begin
    Delete(adstr, 1, 2);

    for ccx := 1 to scani.Pid_Count do
    begin
      if (scanner_pids[ccx].PCMPID = 'FFFF') or (scanner_pids[ccx].PCMPID = 'FFFE') or (scanner_pids[ccx].PCMPID = 'FFFD') then
      // AD1
      begin
        bx := 1;
        if scanner_pids[ccx].PCMPID = 'FFFF' then
          bx := 1;
        if scanner_pids[ccx].PCMPID = 'FFFE' then
          bx := 2;
        if scanner_pids[ccx].PCMPID = 'FFFD' then
          bx := 3;

        ccfs := scanner_pids[ccx].formula;
        gr := Ord(adstr[bx]);
        try
          adreal := Form1.calculate(false, ccfs, gr, 0, 0, 0);
        except
          adreal := '-666';
        end;

        if scanner_pids[ccx].ResultsLookup <> '' then
          fixresult(adreal, scanner_pids[ccx].ResultsLookup);

        scanner_pids[ccx].Value := adreal;
        Form1.pid_grid.Cells[1, ccx] := scanner_pids[ccx].Value;

        checkwarning(adreal, ccx);

        with tform8(pp.list[scanner_pids[ccx].pidwindowindex]) do
          try
            Value.Caption := adreal;
          except
          end;
      end;
    end;
  end;

  procedure processfakepids;
  var
    cca, ccz: Integer;
    mcifail: Boolean;
    cfinal, ccfs: string;
    cx, rb: Integer;
    rs: string;
    PIDCode: string;
  begin
    for ccz := 0 to scani.fakepids.Count - 1 do
    begin
      mcifail := false;
      rb := NEWSTRTOINT(scani.fakepids.strings[ccz]);

      if scanner_pids[rb].PCMPID = 'FPID' then
      begin
        mcifail := false;

        PIDCode := Trim(UpperCase(scanner_pids[rb].mci));

        if (PIDCode) = '%TC4_1%' then
        begin
          rs := cfg.TC4_1;
          cfinal := rs;
        end
        else if (PIDCode) = '%TC4_2%' then
        begin
          rs := cfg.TC4_2;
          cfinal := rs;
        end
        else if (PIDCode) = '%TC4_3%' then
        begin
          rs := cfg.TC4_3;
          cfinal := rs;
        end
        else if (PIDCode) = '%TC4_4%' then
        begin
          rs := cfg.TC4_4;
          cfinal := rs;
        end
        else if (PIDCode) = '%LC1AFR%' then
        begin
          rs := cfg.WBVALUE;
          cfinal := rs;
        end
        else if (PIDCode) = '%LC1LAMBA%' then
        begin
          rs := cfg.LambaVALUE;
          cfinal := rs;
        end

        else if (PIDCode) = '%LOGTIME%' then
        begin
          finish := Now() - LOGstart;
          rs := FormatDateTime('HH', finish) + ':' + FormatDateTime('NN', finish) + ':' + FormatDateTime('SS', finish) + ':' +
            FormatDateTime('ZZZ', finish);
          cfinal := rs;
        end
        else if (PIDCode) = '%RUNTIME%' then
        begin
          finish := Now() - start;
          rs := FormatDateTime('HH', finish) + ':' + FormatDateTime('NN', finish) + ':' + FormatDateTime('SS', finish) + ':' +
            FormatDateTime('ZZZ', finish);
          cfinal := rs;
        end
        else
        begin
          ccfs := scanner_pids[rb].formula;
          for cca := 1 to scani.Pid_Count do
            if (Pos(UpperCase(Trim(scanner_pids[cca].mci)), UpperCase(Trim(ccfs))) <> 0) then
              if Trim(scanner_pids[cca].Value) <> '' then
                ccfs := StringReplace(UpperCase(Trim(ccfs)), UpperCase(Trim(scanner_pids[cca].mci)), scanner_pids[cca].Value,
                  [rfReplaceAll, rfIgnoreCase]);
          try
            cfinal := Form1.calculate(false, ccfs, 0, 0, 0, 0);
          except
            cfinal := '-666';
          end;
        end;

        if scanner_pids[rb].ResultsLookup <> '' then
          fixresult(cfinal, scanner_pids[rb].ResultsLookup);

        checkwarning(cfinal, rb);

        scanner_pids[rb].Value := cfinal;
        Form1.pid_grid.Cells[1, scanner_pids[rb].gridline] := cfinal;

        with tform8(pp.list[scanner_pids[rb].pidwindowindex]) do
          try
            Value.Caption := cfinal;
          except
          end;
      end;
    end;
    checkline('fakepids'); // check the log lines
  end;

var
  hexdata: string;
begin
  sbar.Panels[6].Text := '';
  hexdata := stringtohex(Data);
  processdata(Data);
  if (Sender as TApdDataPacket).Name = 'ADPORTS' then
    processad(Data);
  if Data[7] = Chr(scani.lastblock) then
    processfakepids;
  Inc(FE_Counter);
  if (sendhb = true) or (FE_Counter = 6) then
  // possibly fix this to be a better way?
  begin
    FE_Counter := 0;
    sbar.Panels[6].Text := 'HEARTBEAT';
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  sendcommand(Edit1.Text, 5000);
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  v1, v2, v3: string; // vin segments;
  vin: string;
  X: Byte;
begin
  vin := vinupdate.Text;

  for X := 1 to Length(vin) do
    if not(vin[X] in ['0' .. '9', 'A' .. 'Z']) then
    begin;
      ShowMessage('Valid Chars for VIN are A to Z and 0 to 9 ');
      Exit;
    end;

  if Length(vin) <> 17 then
  begin;
    ShowMessage('VIN ERROR PLEASE CHECK!');
    Exit;
  end;
  v1 := '0B 6C 10 F1 3B 01 00 ' + stringtohex(Copy(vin, 1, 5));
  v2 := '0B 6C 10 F1 3B 02 ' + stringtohex(Copy(vin, 6, 6));
  v3 := '0B 6C 10 F1 3B 03 ' + stringtohex(Copy(vin, 12, 6));

  sendcommand(v1, 1000);
  sendcommand(v2, 1000);
  sendcommand(v3, 1000);

  ShowMessage
    ('VIN Update Commands sent.  Please turn key off for 15 seconds to allow VIN to update. Do a PCM INFO to verify change.');

end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  sendcommand('0B 6C 10 F1 AE 02 40 00 00 00 00 00', 100);
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  sendcommand('0B6C10F1AE01000000000000', 100);
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  sendcommand('0B6C10F1AE01808000000000', 100);
end;

procedure TForm1.Button6Click(Sender: TObject);
begin
  MTS.Disconnect;
end;

procedure TForm1.wbfireClick(Sender: TObject);
begin
  MTS.CurrentPort := portlist.ItemIndex;

  addmemoline('Starting WB on Selected Comport ' + portlist.Items[portlist.ItemIndex]);
  try
    MTS.Connect;
  except
    addmemoline('FAILED WB STARTUP on Comport ' + portlist.Items[portlist.ItemIndex]);
  end;
end;

function TForm1.calculate(N: Boolean; formula: string; value1, value2, value3, value4: Real): string;
var
  g: string;
  fs: string;
begin
  formula := searchandreplace(formula, 'N0', FloatToStr(value1));
  formula := searchandreplace(formula, 'N1', FloatToStr(value1));
  formula := searchandreplace(formula, 'N2', FloatToStr(value2));
  formula := searchandreplace(formula, 'N3', FloatToStr(value3));
  formula := searchandreplace(formula, 'N4', FloatToStr(value4));

  formula := '(' + formula + ')';

  try
    g := forma.ComputeStr(formula);
  except
    g := '0';
  end;

  calculate := g;
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
var
  cx: Integer;
begin
  if pp.Count <= 0 then
  begin
    CheckBox1.Checked := false;
    Exit;
  end;

  if CheckBox1.Checked then

    for cx := 0 to pp.Count do

      with tform8(pp.list[scanner_pids[cx].pidwindowindex]) do
        try
          Show
        except
        end
  else

    for cx := 0 to pp.Count do

      with tform8(pp.list[scanner_pids[cx].pidwindowindex]) do
        try
          hide;
        except
        end;
end;

procedure TForm1.createdata;
var
  CZ, rz, cx: Longint; // couter
  g: Boolean;
  t: TFont;
begin
  EnginePids.Items.Clear;
  TrannyPids.Items.Clear;
  indypids.Items.Clear;
  BodyPids.Items.Clear;
  ACCPids.Items.Clear;
  otherpids.Items.Clear;
  ad.Items.Clear;
  fakepids.Items.Clear;
  PIDPanel.ActivePageIndex := 0;
  timedout := true;
  scannerrunning := false;

  scani.PID_Strings := TStringList.Create; // stores pids to send
  scani.fakepids := TStringList.Create; // stores fake pid locations
  scani.ADPORTS := TStringList.Create; // stores ad port locations

  PIDPage.ActivePageIndex := 0;
  PIDCSV := TAdvStringGrid.Create(SELF);
  log_grid := TAdvStringGrid.Create(SELF);
  dtclist := TAdvStringGrid.Create(SELF);
  pid_grid_config := TAdvStringGrid.Create(SELF);

  log_grid.Parent := Form1;
  log_grid.Visible := false;
  log_grid.hide;

  if FileExists('dtcs.csv') = false then
  begin
    ShowMessage('DTCS.CSV MISSING!');
    application.Terminate;
  end;

  try
    pid_grid_config.LoadFromCSV('pidgrid.csv');
  except
    ShowMessage('PIDGRID.CSV MISSING! CREATING FILE!');
    // COUNT	NAME	ROWHEIGHT	FONTSIZE	ROW COLOR	FONT COLOR	FORMULA	RESULT
    pid_grid_config.ColCount := 11;
    pid_grid_config.Cells[0, 0] := 'COUNT';
    pid_grid_config.Cells[1, 0] := 'NAME';
    pid_grid_config.Cells[2, 0] := 'ROWHEIGHT';
    pid_grid_config.Cells[3, 0] := 'FONTSIZE';
    pid_grid_config.Cells[4, 0] := 'ROW COLOR';
    pid_grid_config.Cells[5, 0] := 'FONT COLOR';
    pid_grid_config.Cells[6, 0] := 'FORMULA';
    pid_grid_config.Cells[7, 0] := 'RESULT';
    pid_grid_config.Cells[8, 0] := 'WARNING COLOR';
    pid_grid_config.Cells[9, 0] := 'WARNING FONT COLOR';
    pid_grid_config.Cells[10, 0] := 'WARNING FILTER';
    pid_grid_config.Cells[11, 0] := 'TOP';
    pid_grid_config.Cells[12, 0] := 'LEFT';
    pid_grid_config.Cells[13, 0] := 'WIDTH';
    pid_grid_config.Cells[14, 0] := 'HEIGHT';
    pid_grid_config.Cells[15, 0] := 'OPEN';

    pid_grid_config.RowCount := 1;
    pid_grid_config.SaveToCSV('pidgrid.csv');
    pid_grid_config.LoadFromCSV('pidgrid.csv');
  end;

  if FileExists('pids.csv') = false then
  begin
    ShowMessage('PIDS.CSV MISSING!');
    application.Terminate;
  end;

  statusmemo.Clear;

  try
    dtclist.LoadFromCSV('dtcs.csv');
  except
    ShowMessage('Error Opening DTCS.CSV file. File Exists, but possibly locked?');
    application.Terminate;
  end;

  try
    PIDCSV.LoadFromCSV('pids.csv');
  except
    ShowMessage('Error Opening PIDS.CSV file. File Exists, but possibly locked?');
    application.Terminate;
  end;

  SetLength(availablepids, PIDCSV.RowCount);

  for cx := 1 to PIDCSV.RowCount do
    if PIDCSV.Cells[7, cx] = '1' then
      with availablepids[cx] do
      begin
        PIDID := PIDCSV.Cells[0, cx];
        LongName := PIDCSV.Cells[1, cx]; // engine speed
        Desc := PIDCSV.Cells[2, cx]; // engine speed of the engine
        formula := UpperCase(PIDCSV.Cells[3, cx]); // N0 * N1
        units := PIDCSV.Cells[4, cx]; // RPM
        DataLength := PIDCSV.Cells[5, cx]; // 2
        PCMPID := PIDCSV.Cells[6, cx]; // 000C
        PIDGroupID := PIDCSV.Cells[7, cx]; // 1 = OSID LOOKUP
        ShortName := PIDCSV.Cells[8, cx]; // RPM
        ResultsLookup := PIDCSV.Cells[9, cx]; // 0 = ON , 1 = OFF
        PIDCategoryID := PIDCSV.Cells[10, cx]; // 1 = ENGINE TAB
        mci := UpperCase(PIDCSV.Cells[11, cx]);
        blockid := 0;
        PIDPos := 0;
        case NEWSTRTOINT(PIDCategoryID) of
          1:
            EnginePids.Items.add(LongName);
          2:
            TrannyPids.Items.add(LongName);
          3:
            indypids.Items.add(LongName);
          4:
            BodyPids.Items.add(LongName);
          5:
            ACCPids.Items.add(LongName);
          6:
            fakepids.Items.add(LongName);
          7:
            ad.Items.add(LongName);
          0:
            otherpids.Items.add(LongName)
        else
          otherpids.Items.add(LongName);
        end;
        EnginePids.Sorted := true;
        TrannyPids.Sorted := true;
        indypids.Sorted := true;
        BodyPids.Sorted := true;
        ACCPids.Sorted := true;
        fakepids.Sorted := true;
        ad.Sorted := true;
        otherpids.Sorted := true;
      end;
  addmemoline('Loading CONFIG file');
  try
    scanini := TIniFile.Create(GetCurrentDir + '\' + // ChangeFileExt(
      'uvscan.ini'); // HAD TO ADD THE \ ?
    cfg.WB := scanini.ReadInteger('COMPORT', 'WB', 0);
    cfg.WBCOMPORT := scanini.ReadInteger('COMPORT', 'WBCOMM', 1);
    if cfg.WB = 1 then
    begin
      addmemoline('Setting WB PORT');
      addmemoline('Port Count : ' + IntToStr(intportcount));
      for rz := 0 to intportcount - 1 do
      begin
        if portlist.Items[rz] = 'COM' + IntToStr(cfg.WBCOMPORT) then
        begin
          portlist.ItemIndex := rz;
        end;
      end;
    end;
    cfg.comport := scanini.ReadInteger('COMPORT', 'COMM', 0);
    cfg.BAUD := scanini.ReadInteger('COMPORT', 'BAUDRATE', 115200);
    cfg.IPADDRESS := scanini.ReadString('COMPORT', 'IP', '127.0.0.1');
    cfg.IPPORT := scanini.ReadString('COMPORT', 'PORT', '10001');
    cfg.AP := scanini.ReadInteger('COMPORT', 'AP', 1);
    cfg.SENDVPW := scanini.ReadInteger('EXTRA', 'SENDVPW', 0);
    addmemoline('Comm : ' + IntToStr(cfg.comport));
    addmemoline('Baud : ' + IntToStr(cfg.BAUD));
    addmemoline('-----------------------------------------------');

    SENDCOMMANDS.mcicode := scanini.ReadString('EXTRA', 'SCANCOMMANDMCI', '');
    SENDCOMMANDS.Value := scanini.ReadString('EXTRA', 'SCANCOMMANDVALUE', '');
    SENDCOMMANDS.COMMAND1 := scanini.ReadString('EXTRA', 'SCANCOMMANDSEND1', '');
    SENDCOMMANDS.command2 := scanini.ReadString('EXTRA', 'SCANCOMMANDSEND2', '');

    cfg.Font := scanini.ReadString('PIDGRID', 'FONT', 'ARIAL');
    cfg.fontsize := scanini.ReadString('PIDGRID', 'FONTSIZE', '8');
    cfg.fontcolor := scanini.ReadString('PIDGRID', 'FONTCOLOR', '000000');
    cfg.primary := scanini.ReadString('PIDGRID', 'PRIMARY', 'D4D0C8');
    cfg.secondary := scanini.ReadString('PIDGRID', 'SECONDARY', '808080');
    AUTONAME.NAMEHEADER1 := scanini.ReadString('EXTRA', 'HEADER1', '');
    AUTONAME.nameheader2 := scanini.ReadString('EXTRA', 'HEADER2', '');
    CZ := scanini.ReadInteger('EXTRA', 'AUTOSAVE', 0);
    AUTONAME.Enabled := false;
    case CZ of
      0:
        AUTONAME.Enabled := false;
      1:
        AUTONAME.Enabled := true;
    end;
    CZ := scanini.ReadInteger('EXTRA', 'AUTOINC', 0);
    AUTONAME.INCREMENTAL := false;
    case CZ of
      0:
        AUTONAME.INCREMENTAL := false;
      1:
        AUTONAME.INCREMENTAL := true;
    end;

    cfg.savepath := scanini.ReadString('EXTRA', 'SAVEPATH', '');

    if (cfg.savepath[Length(cfg.savepath)] <> '\') and (cfg.savepath[Length(cfg.savepath)] <> '"') then
      cfg.savepath := cfg.savepath + '\';

    t := TFont.Create;
    t.Name := cfg.Font;
    t.Size := NEWSTRTOINT(cfg.fontsize);
    try
      t.Color := NEWSTRTOINT('$' + cfg.fontcolor);
    finally
    end;

    loadlist('', EnginePids);
    loadlist('', TrannyPids);
    loadlist('', indypids);
    loadlist('', BodyPids);
    loadlist('', ACCPids);
    loadlist('', ad);
    loadlist('', fakepids);
    loadlist('', otherpids);
    addmemoline('Number of CPUs (Core/HyperThread): ' + IntToStr(sysinfo.dwNumberOfProcessors));
    if sysinfo.dwNumberOfProcessors > 1 then
      addmemoline('Setting UVSCAN to run on CPU #1');
    setprocessaffinitymask(SELF.Handle, 1);
  finally
    scanini.Free;
  end;
  try
    pid_grid.FixedFont := t;
  finally
  end;
  try
    pid_grid.Font := t;
  finally
  end;
  try
    pid_grid.Bands.PrimaryColor := hextotcolor(cfg.primary);
  finally
  end;
  try
    pid_grid.Bands.SecondaryColor := hextotcolor(cfg.secondary);
  finally
  end;

  for cx := 0 to pid_grid.RowCount - 2 do
  begin
    pid_grid.RowHeights[cx] := 21;
    if Odd(cx) then
      pid_grid.RowColor[cx] := hextotcolor(cfg.primary)
    else
      pid_grid.RowColor[cx] := hextotcolor(cfg.secondary);
  end;
end;

procedure TForm1.DisconnectBClick(Sender: TObject);
begin
  if pauseb.Enabled = false then // if the button is off, then do it !
  begin
    timedout := true;
    sendhb := false;
    scannerrunning := false;
    VrTimer1.Enabled := false;
    ConnectAVT.Enabled := true;
    pcminfob.Enabled := false;
    ScannerB.Enabled := false;
    STOPSCANNER.Enabled := false;
    DisconnectB.Enabled := false;
    pauseb.Enabled := false;
    Startlogb.Enabled := false;
    blockFE.Enabled := false;
    BLOCKFD.Enabled := false;
    BLOCKFC.Enabled := false;
    BLOCKFB.Enabled := false;
    BLOCKFA.Enabled := false;
    BLOCKF9.Enabled := false;
    BLOCKF8.Enabled := false;
    BLOCKF7.Enabled := false;
    logstatus := 33;
  end;

  if gridapply = true then
  begin
    ShowMessage('Please wait for PIDGRID to be initilized before disconnecting.');
    Exit;
  end;

  if (logstatus = 1) or (logstatus = 2) then
  begin
    ShowMessage('Please stop your scan before disconnect.');
    Exit;
  end;

  pauseb.Enabled := false;
  Startlogb.Caption := 'START LOG (F8)';
  logstatus := 33;
  pauseb.Caption := 'PAUSE';
  ToolBar1.GradientEndColor := $00ACB7BD;

  DisconnectB.Enabled := false;
  VrTimer1.Enabled := false;

  scannerrunning := false;

  if admode then
  begin
    addmemoline('AD Mode Turning Off');
    sendcommand('52 59 00', 4);
  end;

  delayticks(5, false);
  if pp.Count <= 0 then
    Exit;
  closewindows;
  CheckBox1.Checked := false;
  LASTLEFT := 0;
  if cfg.WB = 1 then
  begin
    try
      MTS.Disconnect;
    except
      addmemoline('error closing WB port');
    end;
  end;

  try
    comport.DonePort;
  except
    addmemoline('error closing port stage 1');
  end;

  try
    comport.Open := false;
  except
    addmemoline('error closing port stage 2');
  end;

  delayticks(10, false);
  sbar.Panels[3].Text := 'NOT CONNECTED';
  scannerrunning := false;
  VrTimer1.Enabled := false;
  ConnectAVT.Enabled := true;
  pcminfob.Enabled := false;
  ScannerB.Enabled := false;
  STOPSCANNER.Enabled := false;
  DisconnectB.Enabled := false;
  pauseb.Enabled := false;
  Startlogb.Enabled := false;
  blockFE.Enabled := false;
  BLOCKFD.Enabled := false;
  BLOCKFC.Enabled := false;
  BLOCKFB.Enabled := false;
  BLOCKFA.Enabled := false;
  BLOCKF9.Enabled := false;
  BLOCKF8.Enabled := false;
  BLOCKF7.Enabled := false;
  sendhb := false;

  comport.Open := false;
  if cfg.WB = 1 then

    MTS.Disconnect;
end;

procedure TForm1.dtc_agoStringPacket(Sender: TObject; Data: string);
begin
  addmemoline('-- ' + currentdtc + ' DTC COUNT SET HEX :: ' + stringtohex(Data));
  dtc_ago.Enabled := false;
  dtc_find.Enabled := true;
  DTCCOUNT := NEWSTRTOINT((stringtohex(Data[8])));
end;

procedure TForm1.dtc_findStringPacket(Sender: TObject; Data: string);
var
  DESCRIPTION, dtccode: string;
  X, Y: Integer;
begin
  addmemoline('-- ' + currentdtc + ' DTC CODE DATA HEX :: ' + stringtohex(Data));

  dtccode := '0000';
  DESCRIPTION := 'Unknown?';

  dtccode := Data[7] + Data[8];
  dtccode := stringtohex(dtccode);
  // temp fix
  dtccode := 'P' + dtccode;

  if (dtccode) = 'P0000' then
  begin
    addmemoline('-- ' + currentdtc + ' DTC CODES ENDED');
    Exit;
  end;

  for X := 0 to dtclist.RowCount - 1 do
    if dtccode = UpperCase(dtclist.Cells[0, X]) then
      DESCRIPTION := dtclist.Cells[1, X];
  addmemoline('DTC Code    : ' + dtccode);
  addmemoline('Description : ' + DESCRIPTION);
end;

procedure TForm1.dtc_findTimeout(Sender: TObject);
begin
  Form1.dtc_ago.Enabled := true;
  Form1.dtc_find.Enabled := false;
end;

procedure TForm1.pcminfobClick(Sender: TObject);
var
  TempStr: string;
begin
  if (logstatus = 1) or (logstatus = 2) then
  begin
    ShowMessage('Please stop your scan log first.');
    Exit;
  end;
  PCMINFO(false);
end;

procedure TForm1.FindModulesStringPacket(Sender: TObject; Data: string);
begin
  Delete(Data, 1, 4);
  Data := stringtohex(Data);

  if Data = '2060' then
    dtcm.Abs := true
  else if Data = '4060' then
    dtcm.BCM := true
  else if Data = '1060' then
    dtcm.PCM := true
  else if Data = '5060' then
    dtcm.NETWORK := true
  else if Data = '5860' then
    dtcm.AIRBAG := true
  else if Data = '6060' then
    dtcm.IPC := true
  else if Data = '6260' then
    dtcm.HUD := true
  else if Data = '8060' then
    dtcm.RADIO := true
  else if Data = 'C060' then
    dtcm.IMMOBILIZER := true;

  if Data = '2060' then
    addmemoline('-- ABS Module Detected!')
  else if Data = '4060' then
    addmemoline('-- BCM Module Detected!')
  else if Data = '1060' then
    addmemoline('-- PCM/ECM Module Detected!')
  else if Data = '5060' then
    addmemoline('-- Network Module Detected!')
  else if Data = '5860' then
    addmemoline('-- Airbag Module Detected!')
  else if Data = '6060' then
    addmemoline('-- IPC (Instrument Panel Cluster) Module Detected!')
  else if Data = '6260' then
    addmemoline('-- HUD (Heads Up Display) Module Detected!')
  else if Data = '8060' then
    addmemoline('-- Radio Module Detected!')
  else if Data = 'C060' then
    addmemoline('-- Immobilizer Module Detected!')
  else
    addmemoline('-- Module ' + Data + ' Unknown! Sorry!');
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if scannerrunning then
  begin
    ShowMessage('Scanner is currently running. Please disconnect properly then Close!');
    Action := canone; // exit me back out
    Exit;
  end;

  try

    if cfg.WB = 1 then

      MTS.Disconnect;
  except
    addmemoline('error closing WB port');
  end;

  try
    comport.DonePort;
  except
    addmemoline('error closing port stage 1');
  end;
  delayticks(10, false);
  try
    comport.Open := false;
  except
    addmemoline('error closing port stage 2');
  end;

  scani.PID_Strings.Free;
  scani.fakepids.Free;
  scani.ADPORTS.Free;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  kid, i: Integer;
begin

  GetSystemInfo(sysinfo);

  if (sysinfo.dwNumberOfProcessors >= 2) then
    setprocessaffinitymask(GetCurrentProcess, 1);

  pid_grid.PopupMenu := pidpop;

  Form1.DoubleBuffered := true;

  big_done := false;
  group := 1;
  FillChar(PIDCOUNTER, SizeOf(PIDCOUNTER), #0);
  intportcount := MTS.PortCount;

  if (intportcount <> 0) then // exit;

  begin
    portlist.Clear;
    for i := 0 to intportcount - 1 do
    begin;
      MTS.CurrentPort := i;
      portlist.AddItem(MTS.PortName, MTS);
    end;
    portlist.ItemIndex := 0;
  end;

  createdata;

  avtinit.StartString := hextostring(avtinit.StartString);
  avtversion.StartString := hextostring(avtversion.StartString);
  AVTSPEED.StartString := hextostring(AVTSPEED.StartString);
  AVTVIN1.StartString := hextostring(AVTVIN1.StartString);
  AVTVIN2.StartString := hextostring(AVTVIN2.StartString);
  AVTVIN3.StartString := hextostring(AVTVIN3.StartString);

  AVTOSID.StartString := hextostring(AVTOSID.StartString);

  blockFE.StartString := hextostring(blockFE.StartString);
  BLOCKFD.StartString := hextostring(BLOCKFD.StartString);
  BLOCKFC.StartString := hextostring(BLOCKFC.StartString);
  BLOCKFB.StartString := hextostring(BLOCKFB.StartString);
  BLOCKFA.StartString := hextostring(BLOCKFA.StartString);
  BLOCKF9.StartString := hextostring(BLOCKF9.StartString);
  BLOCKF8.StartString := hextostring(BLOCKF8.StartString);
  BLOCKF7.StartString := hextostring(BLOCKF7.StartString);
  ADPORTS.StartString := hextostring(ADPORTS.StartString);

  CHECKPID1.StartString := hextostring(CHECKPID1.StartString);

  CHECKPID2.StartString := hextostring(CHECKPID2.StartString);

  checkpid3.StartString := hextostring(checkpid3.StartString);

  BADPID.StartString := hextostring(BADPID.StartString);
  FindModules.StartString := hextostring(FindModules.StartString);
  dtc_ago.StartString := hextostring(dtc_ago.StartString);
  dtc_find.StartString := hextostring(dtc_find.StartString);

  HOTKEY1 := GlobalAddAtom('F8LOG');

  RegisterHotKey(Form1.Handle, HOTKEY1, 0, vk_F8);

  pid_grid.FixedCols := 0;

  if DirectoryExists('backup') = false then
  begin
    addmemoline('');
    addmemoline(GetCurrentDir + '\Backup\ was missing. Created for backup scans!');
    addmemoline('Any scan created will also have a backup created here that is ' + 'written constantly.');
    MkDir('backup');
  end;

  if comport.Open then
    comport.Open := false;

end;

procedure TForm1.FormShow(Sender: TObject);
begin
  if UpperCase(ParamStr(1)) = '-CONNECT' then
  begin
    ConnectAVT.Click;
    if UpperCase(ParamStr(2)) = '-SCAN' then
    begin
      ScannerB.Click;
      if UpperCase(ParamStr(3)) = '-LOG' then
        Startlogb.Click;
    end;
  end;
end;

procedure TForm1.HideallPIDWindow1Click(Sender: TObject);
var
  cx: Integer;
begin
  if pp.Count <= 0 then
  begin
    CheckBox1.Checked := false;
    Exit;
  end;

  for cx := 0 to pp.Count do
    with tform8(pp.list[scanner_pids[cx].pidwindowindex]) do
      try
        hide
      except
      end;
  CheckBox1.Checked := false;
end;

procedure TForm1.HideGauge1Click(Sender: TObject);
begin
  if pp.Count <= 0 then
    Exit;
  with tform8(pp.list[scanner_pids[pid_grid.Row].pidwindowindex]) do
    try
      hide
    except
    end;
end;

procedure TForm1.CHECKPID1StringPacket(Sender: TObject; Data: string);
var
  t: pid_Rec;
begin
  Delete(Data, 1, 6);
  Delete(Data, 3, 1);
  Data := stringtohex(Data);
  nextpidavail := true;
  Inc(pid_passed);
end;

procedure TForm1.CHECKPID1Timeout(Sender: TObject);
begin
  statusmemo.Lines.add('TIMEOUT - Next PID Request!');
  nextpidavail := true;
  Inc(PID_TIMEOUTCOUNT);
end;

procedure TForm1.CHECKPID2StringPacket(Sender: TObject; Data: string);
var
  t: pid_Rec;
begin
  Delete(Data, 1, 7);
  Delete(Data, 3, 2);
  Data := stringtohex(Data);
  pidtfailed := true;
  statusmemo.Lines.add('PID FAILED: ' + t.LongName + ' : ' + Data);
  nextpidavail := true;
  Inc(pid_failed);
  pidtfailed := true;
end;

procedure TForm1.checkpid3StringPacket(Sender: TObject; Data: string);
var
  t: pid_Rec;
begin
  Delete(Data, 1, 6);
  Delete(Data, 3, 2);
  Data := stringtohex(Data);
  nextpidavail := true;
  Inc(pid_passed);
end;

procedure TForm1.ClearCheckedPIDs1Click(Sender: TObject);
var
  X: Integer;
begin
  if MessageBox(application.Handle, 'Clear Checked PIDs?', PChar(Caption), mb_yesno or MB_DEFBUTTON2) = idYes then
  begin
    for X := 0 to EnginePids.Count - 1 do
      EnginePids.Checked[X] := false;
    for X := 0 to TrannyPids.Count - 1 do
      TrannyPids.Checked[X] := false;
    for X := 0 to BodyPids.Count - 1 do
      BodyPids.Checked[X] := false;
    for X := 0 to indypids.Count - 1 do
      indypids.Checked[X] := false;
    for X := 0 to fakepids.Count - 1 do
      fakepids.Checked[X] := false;
    for X := 0 to ad.Count - 1 do
      ad.Checked[X] := false;
    for X := 0 to ACCPids.Count - 1 do
      ACCPids.Checked[X] := false;
    for X := 0 to otherpids.Count - 1 do
      otherpids.Checked[X] := false;
    FillChar(PIDCOUNTER, SizeOf(PIDCOUNTER), #0);
    pbc.Caption := IntToStr(PIDCOUNTER.bytecount);
    tsp.Caption := IntToStr(PIDCOUNTER.Count);
    tfp.Caption := IntToStr(PIDCOUNTER.F_count);
  end;
end;

procedure TForm1.ClearDTCs1Click(Sender: TObject);
begin
  if (logstatus = 1) or (logstatus = 2) then
  begin
    ShowMessage('Please stop your scan log first.');
    Exit;
  end;

  addmemoline('DTC List being Cleared');
  addmemoline('---------------------------------');
  sendcommand('046C10F120', 10);
  sendcommand('056C10F11000', 10);
  sendcommand('046C10F114', 10);
  addmemoline('DTC CLEAR Commands Sent.');
end;

procedure TForm1.ConnectAVTClick(Sender: TObject);
var
  cx: Byte;
  wx: Byte;
begin
  VrTimer1.Enabled := false;

  if (comport.Open = true) or (big_done = true) then
    try
      comport.DonePort;
      addmemoline('Disconnecting and Closing PORT');
    except
      addmemoline('Error Closing Port Stage 1');
    end;

  big_done := false;

  if cfg.WB = 1 then
  begin
    MTS.CurrentPort := cfg.WBCOMPORT;
    addmemoline('WIDEBAND ENABLED');
    addmemoline('WIDEBAND COMPORT = ' + IntToStr(cfg.WBCOMPORT));

    wbfire.Click;

    try
      MTS.Disconnect;
    except
    end;
  end;

  if cfg.AP = 1 then
  begin
    comport.devicelayer := dlwin32;
    comport.ComNumber := cfg.comport;
    comport.BAUD := cfg.BAUD;
    addmemoline('COM = ' + IntToStr(comport.ComNumber));
    addmemoline('BAUD = ' + IntToStr(comport.BAUD));
  end
  else
  begin
    comport.devicelayer := dlwinsock;
    comport.WsAddress := cfg.IPADDRESS;
    comport.WsPort := cfg.IPPORT;
    addmemoline('IP = ' + (comport.WsAddress));
    addmemoline('PORT = ' + (comport.WsPort));
  end;

  ConnectAVT.Enabled := false;
  delayticks(5, true);
  try
    comport.initport;
    comport.Open := true;
    sbar.Panels[3].Text := 'CONNECTED';
    addmemoline('Port INIT DONE');
    delayticks(10, true);
    comport.Open := true;
    timedout := false;
    delayticks(10, true);
    comport.FlushInBuffer;
    comport.FlushOutBuffer;
    Sleep(300);
    PCMINFO(false);
  except
    ConnectAVT.Enabled := true;
    addmemoline('Port INIT FAILED. Please check device settings.');
    big_done := true;
    Exit;
  end;
end;

procedure TForm1.Setup1Click(Sender: TObject);
begin
  ShowMessage('Internal SETUP disabled. Loading UVSCAN.INI in notepad currently! After changes, close and restart UVSCAN.');
  ShellExecute(Handle, 'open', 'notepad.exe', 'uvscan.ini', nil, SW_SHOWNORMAL);
end;

procedure TForm1.ShowGauge1Click(Sender: TObject);
begin
  if pp.Count <= 0 then
    Exit;

  with tform8(pp.list[scanner_pids[pid_grid.Row].pidwindowindex]) do
    try
      Show;
    except
    end;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
  pid_grid.Zoom(1);
end;

procedure TForm1.SpeedButton2Click(Sender: TObject);
begin
  pid_grid.Zoom(-1);
end;

procedure TForm1.StartlogbClick(Sender: TObject);
var
  FN, FN2: string;
  rightnow: tdatetime;
  rdn: Byte;
  dx, dy: Integer;
label
  redoname;
var
  colt: TStringList;
begin
  rdn := 0;
  colt := TStringList.Create;
  comport.FlushInBuffer;
  comport.FlushOutBuffer;
  application.ProcessMessages;
  saveCSV.InitialDir := cfg.savepath;

  if (logstatus <> 1) and (logstatus <> 2) then // anything or paused
  begin
    for rdn := 0 to pid_grid.RowCount do // -2 do
    begin
      colt.add(pid_grid.Cells[0, rdn]);
    end;
    colt.strings[0] := 'Count';
    scani.linecount := 0;
    if AUTONAME.Enabled then
    begin
      if AUTONAME.NAMEHEADER1 = '' then
        AUTONAME.NAMEHEADER1 := 'SCANLOG_';
      if AUTONAME.nameheader2 = '' then
        AUTONAME.NAMEHEADER1 := 'c';
      FN := AUTONAME.nameheader2;
      rightnow := Now;
      FN := FormatDateTime(FN, rightnow);
      FN := searchandreplace(FN, ' ', '_');
      FN := searchandreplace(FN, '\', '-');
      FN := searchandreplace(FN, '/', '-');
      FN := searchandreplace(FN, ':', '_');
      FN := searchandreplace(FN, '.', '_');
      FN := searchandreplace(FN, '@', '_');

      FN2 := AUTONAME.NAMEHEADER1 + FN;
    redoname:

      if AUTONAME.INCREMENTAL = true then
      begin
        Inc(rdn);
        if rdn = 50 then
          AUTONAME.incx := 55555;

        Inc(AUTONAME.incx);
        FN2 := FN2 + '_' + IntToStr(AUTONAME.incx);
        if FileExists(FN2 + '.csv') then
          goto redoname;
      end;
      Randomize;
      if FileExists(FN2 + '.csv') then
        FN2 := FN2 + '_' + IntToStr(Random(666666));
      FN2 := FN2 + '.csv';
{$I-}
      AssignFile(backupcsv, GetCurrentDir + '\backup\' + FN2);
      Rewrite(backupcsv); {$I+}
      if IOResult <> 0 then
        addmemoline('Error creating backup scan: ' + FN2);
      Writeln(backupcsv, colt.DelimitedText);
      if DirectoryExists(cfg.savepath) then
        FN2 := cfg.savepath + FN2;
      saveCSV.FileName := FN2;
      addmemoline('Auto-Created : ' + FN2);
      scani.linecount := 1;
    end
    else
    begin
      if saveCSV.Execute = false then
        Exit;
      if ExtractFileExt(saveCSV.FileName) = '' then
        saveCSV.FileName := saveCSV.FileName + '.CSV';
      addmemoline('Manual-Created : ' + saveCSV.FileName);
      scani.linecount := 1;

{$I-}
      FN2 := saveCSV.FileName;
      AssignFile(backupcsv, GetCurrentDir + '\backup\' + FN2);
      Rewrite(backupcsv); {$I+}
      if IOResult <> 0 then
        addmemoline('Error creating backup scan: ' + FN2);
      Writeln(backupcsv, colt.DelimitedText);
    end;
    pauseb.Enabled := true;
    Startlogb.Caption := 'STOP LOG (F8)';
    LOGstart := Now();
    logstatus := 1;
    ToolBar1.GradientEndColor := clGreen;
  end
  else
  begin
    logstatus := 33;
    pauseb.Enabled := false;
    Startlogb.Caption := 'START LOG (F8)';
    logstatus := 33;
    pauseb.Caption := 'PAUSE';
    pauseb.Enabled := false;
    ToolBar1.GradientEndColor := $00ACB7BD;
    try
{$I-} CloseFile(backupcsv); {$I+}
    except
    end;
    log_grid.Cells[0, 0] := 'Count';
    log_grid.ColCount := scani.Pid_Count + 1; // 1 for count/row
    try
      log_grid.SaveToCSV(saveCSV.FileName);
    finally
      saveCSV.FileName := '*.csv';
    end;
    (* **  END OF SAVING THE LOG FILE ** *)
  end;
  ToolBar1.Repaint;
  ToolBar1.Refresh;
end;

procedure TForm1.TabSheet7Show(Sender: TObject);
begin
  pid_grid.Row := 1;
  pid_grid.Col := 1;
  pid_grid.SetFocus;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  X: Integer;
begin
  DisconnectB.Enabled := true;
  Timer1.Enabled := false;
end;

procedure TForm1.ScannerBClick(Sender: TObject);

  function SetupPIDs: Boolean;
  var
    cx: Byte;
    TempStr: string;
  begin
    if pid_grid.zoomfactor <> 0 then
      for cx := 0 to pid_grid.zoomfactor - 1 do
        pid_grid.Zoom(-1);

    for cx := 1 to pid_grid.RowCount - 1 do
    begin
      pid_grid.RowHeights[cx] := 21;
      pid_grid.Font.Size := 8;
      pid_grid.FontSizes[0, cx] := 8;
      pid_grid.FontSizes[1, cx] := 8;
      pid_grid.FontSizes[2, cx] := 8;
      pid_grid.FontColors[1, cx] := clBlack;
      pid_grid.FontColors[2, cx] := clBlack;

      if Odd(cx) then
        pid_grid.RowColor[cx] := hextotcolor(cfg.primary)
      else
        pid_grid.RowColor[cx] := hextotcolor(cfg.secondary);
    end;

    SetupPIDs := true;

    if scani.PID_Strings.Count = 0 then
    begin
      ShowMessage('No REAL PIDS selected!');
      addmemoline('Aborted SCAN: No Real PIDS');
      SetupPIDs := false;
      Exit;
    end;

    case scani.lastblock of
      254:
        scani.PID_Strings.add('09 6C 10 F1 2A 14 FE 00 00 00');
      253:
        scani.PID_Strings.add('09 6C 10 F1 2A 14 FE FD 00 00');
      252:
        scani.PID_Strings.add('09 6C 10 F1 2A 14 FE FD FC 00');
      251:
        scani.PID_Strings.add('09 6C 10 F1 2A 14 FE FD FC FB');

      250:
        begin
          scani.PID_Strings.add('09 6C 10 F1 2A 14 FE FD FC FB');
          scani.PID_Strings.add('09 6C 10 F1 2A 24 FA 00 00 00');
        end;

      249:
        begin
          scani.PID_Strings.add('09 6C 10 F1 2A 14 FE FD FC FB');
          scani.PID_Strings.add('09 6C 10 F1 2A 24 FA F9 00 00');
        end;
      248:
        begin
          scani.PID_Strings.add('09 6C 10 F1 2A 14 FE FD FC FB');
          scani.PID_Strings.add('09 6C 10 F1 2A 24 FA F9 F8 00');
        end;
      247, 246, 245:
        begin
          scani.PID_Strings.add('09 6C 10 F1 2A 14 FE FD FC FB');
          scani.PID_Strings.add('09 6C 10 F1 2A 24 FA F9 F8 F7');
        end;
    end;
  end;

  function addpid(AP: pid_Rec; t: TObject): Boolean;
  var
    cx: Byte; // dummy couter
    Count: Integer; // 64 counter
    PIDCode: string; // code string
    addfake, addad, dontsend: Boolean;
  begin
    dontsend := false;
    addpid := true;
    addad := false;
    AP.PCMPID := UpperCase(AP.PCMPID); // UPPERCASE EM
    AP.PIDID := UpperCase(AP.PIDID);
    addmemoline('Adding PID ' + AP.LongName + ' ' + AP.PCMPID + ' length = ' + AP.DataLength);
    addfake := false;
    AP.PCMPID := UpperCase(AP.PCMPID);

    if (AP.PCMPID = 'FPID') or (AP.DataLength = '0') then
    begin
      addfake := true;
      dontsend := true; // FAKE PIDS
    end;

    if (AP.PCMPID = 'FFFD') or (AP.PCMPID = 'FFFE') or (AP.PCMPID = 'FFFF') then
    begin
      AP.DataLength := '0';
      addad := true;
      admode := true;
      dontsend := true; // AD
    end;

    // fix this all soon !

    // have to make this SMART to auto fit pids in to fill all data
    // space

    if dontsend = false then
    begin
      PIDCode := AP.PCMPID; // the PID!
      case Length(PIDCode) of // pads it with zeros if need be
        1:
          Insert('000', PIDCode, 1);
        2:
          Insert('00', PIDCode, 1);
        3:
          Insert('0', PIDCode, 1);
      end;

      if scani.Pid_POS + NEWSTRTOINT(AP.DataLength) in [8, 9, 10] then
      begin
        Dec(scani.currentblock);
        scani.Pid_POS := 1;
      end;
      Count := 64;
      if (1 and NEWSTRTOINT(AP.DataLength)) > 0 then
        Inc(Count);
      if (2 and NEWSTRTOINT(AP.DataLength)) > 0 then
        Inc(Count, 2);
      if (4 and NEWSTRTOINT(AP.DataLength)) > 0 then
        Inc(Count, 4);
      if (1 and scani.Pid_POS) > 0 then
        Inc(Count, 8);
      if (2 and scani.Pid_POS) > 0 then
        Inc(Count, 16);
      if (4 and scani.Pid_POS) > 0 then
        Inc(Count, 32);
      scani.PID_Strings.add('0A6C10F12C' + stringtohex(Chr(scani.currentblock)) + stringtohex(Chr(Count)) + PIDCode + 'FFFF');
      Inc(scani.Pid_Count);
      Inc(scani.bytecount, NEWSTRTOINT(AP.DataLength));
      scanner_pids[scani.Pid_Count] := AP;
      scanner_pids[scani.Pid_Count].blockid := scani.currentblock;
      scanner_pids[scani.Pid_Count].PIDPos := scani.Pid_POS;
      scanner_pids[scani.Pid_Count].gridline := scani.Pid_Count;
      Inc(scani.Pid_POS, NEWSTRTOINT(AP.DataLength));
      pid_grid.Cells[0, scani.Pid_Count] := AP.ShortName;
      pid_grid.Cells[2, scani.Pid_Count] := AP.units;

      if scani.Pid_POS >= 7 then
      begin
        Dec(scani.currentblock); // if its over 6 dec block id
        scani.Pid_POS := 1;
      end;
    end
    else if (addfake) or (addad) then

    begin
      Inc(scani.Pid_Count);
      scanner_pids[scani.Pid_Count] := AP;
      scanner_pids[scani.Pid_Count].blockid := scani.currentblock;
      scanner_pids[scani.Pid_Count].PIDPos := scani.Pid_POS;
      scanner_pids[scani.Pid_Count].gridline := scani.Pid_Count;

      pid_grid.Cells[0, scani.Pid_Count] := AP.ShortName;
      pid_grid.Cells[2, scani.Pid_Count] := AP.units;
    end;

    if addfake then
      scani.fakepids.add(IntToStr(scani.Pid_Count));

    scani.lastblock := scani.currentblock;

    if Odd(scani.Pid_Count) then
      scanner_pids[scani.Pid_Count].rcolor := hextotcolor(cfg.primary)
    else
      scanner_pids[scani.Pid_Count].rcolor := hextotcolor(cfg.secondary);
    scanner_pids[scani.Pid_Count].fcolor := clBlack;

    scanner_pids[scani.Pid_Count].wfilter := 200000;
    if Odd(scani.Pid_Count) then
      scanner_pids[scani.Pid_Count].grcolor := hextotcolor(cfg.primary)
    else
      scanner_pids[scani.Pid_Count].grcolor := hextotcolor(cfg.secondary);
    scanner_pids[scani.Pid_Count].gfcolor := clBlack;
    scanner_pids[scani.Pid_Count].wrcolor := scanner_pids[scani.Pid_Count].grcolor;
    scanner_pids[scani.Pid_Count].wfcolor := scanner_pids[scani.Pid_Count].gfcolor;

    addpidwindow(scanner_pids[scani.Pid_Count]);
    Sleep(5);
  end;

  function checkpids(bs: Byte; Sender: TObject): Boolean;
  var
    cx, cy: Integer;
    clist: TCheckListBox;
    CZ: Integer;
  begin
    checkpids := true;
    clist := Sender as TCheckListBox;
    if clist.Count = 0 then
      Exit;
    for cx := 0 to clist.Count - 1 do // counter list
      if clist.Checked[cx] = true then // if checked
        for CZ := 1 to PIDCSV.RowCount do // counter to find PID size
          if UpperCase(clist.Items[cx]) = UpperCase(PIDCSV.Cells[1, CZ])
          // if its found
          then
            if PIDCSV.Cells[7, CZ] = '1' then
              if bs = NEWSTRTOINT(PIDCSV.Cells[5, CZ]) then
              // if the size = bs then begin
              begin
                for cy := 0 to Length(availablepids) - 1 do
                  if availablepids[cy].LongName = clist.Items[cx] then
                    if addpid(availablepids[cy], Sender) = false then
                      checkpids := false;
              end;
  end;

  function findremovepid(s: string; Sender: TObject): Boolean;
  var
    cx, cy: Integer;
    clist: TCheckListBox;
    CZ: Integer;
    Temp, temp2: string;
  begin
    Temp := Copy(s, Length(s) - 7, 4); // copy the id
    clist := Sender as TCheckListBox;
    if clist.Count = 0 then
      Exit;

    addmemoline('removing !!' + Temp + '!! >> ' + s);
    if clist.Count = 0 then
      Exit;
    for cx := 0 to clist.Count - 1 do // counter list
      if clist.Checked[cx] = true then // if checked
        for CZ := 1 to PIDCSV.RowCount do // counter to find PID size
          if UpperCase(clist.Items[cx]) = UpperCase(PIDCSV.Cells[1, CZ])
          // if its found
          then
            if PIDCSV.Cells[7, CZ] = '1' then
            begin
              temp2 := UpperCase(PIDCSV.Cells[6, CZ]);
              case Length(temp2) of // pads it with zeros if need be
                1:
                  Insert('000', temp2, 1);
                2:
                  Insert('00', temp2, 1);
                3:
                  Insert('0', temp2, 1);
              end;

              if Temp = temp2 then // then if the size = bs then begin
              begin
                for cy := 0 to Length(availablepids) - 1 do
                  if availablepids[cy].LongName = clist.Items[cx] then
                  begin
                    clist.Checked[cx] := false;
                    if availablepids[cy].DataLength = '0' then
                      Dec(PIDCOUNTER.F_count)
                    else
                      Dec(PIDCOUNTER.Count);
                    Dec(PIDCOUNTER.bytecount, NEWSTRTOINT(availablepids[cy].DataLength));
                  end;
              end;
            end;

    savelist('uvscan_checklist.pid', EnginePids);
    savelist('uvscan_checklist.pid', TrannyPids);
    savelist('uvscan_checklist.pid', indypids);
    savelist('uvscan_checklist.pid', BodyPids);
    savelist('uvscan_checklist.pid', ACCPids);
    savelist('uvscan_checklist.pid', ad);
    savelist('uvscan_checklist.pid', fakepids);
    savelist('uvscan_checklist.pid', otherpids);

    pbc.Caption := IntToStr(PIDCOUNTER.bytecount);
    tsp.Caption := IntToStr(PIDCOUNTER.Count);
    tfp.Caption := IntToStr(PIDCOUNTER.F_count);
  end;

  procedure applypidgridsetup;
  var
    X, Y, z: Integer;
  begin
    gridapply := false;
    try
      pid_grid_config.LoadFromCSV('pidgrid.csv');
    except
      ShowMessage('Error Loading PIDGRID.CSV');
      Exit;
    end;

    if pid_grid_config.RowCount = 0 then
      Exit;
    gridapply := true;

    for X := 1 to scani.Pid_Count do
      for Y := 1 to pid_grid_config.RowCount do
        if pid_grid_config.Cells[0, Y] = scanner_pids[X].PIDID then
        begin
          Form1.pid_grid.RowHeights[X] := NEWSTRTOINT(pid_grid_config.Cells[2, Y]);
          Form1.pid_grid.FontSizes[0, X] := NEWSTRTOINT(pid_grid_config.Cells[3, Y]);
          Form1.pid_grid.FontSizes[1, X] := NEWSTRTOINT(pid_grid_config.Cells[3, Y]);
          Form1.pid_grid.FontSizes[2, X] := NEWSTRTOINT(pid_grid_config.Cells[3, Y]);
          Form1.pid_grid.RowColor[X] := hextotcolor(pid_grid_config.Cells[4, Y]);
          Form1.pid_grid.FontColors[1, X] := hextotcolor(pid_grid_config.Cells[5, Y]);
          Form1.pid_grid.FontColors[2, X] := hextotcolor(pid_grid_config.Cells[5, Y]);

          gentypes.scanner_pids[X].formula := pid_grid_config.Cells[6, Y];
          gentypes.scanner_pids[X].ResultsLookup := pid_grid_config.Cells[7, Y];

          gentypes.scanner_pids[X].gfcolor := hextotcolor(pid_grid_config.Cells[5, Y]);

          gentypes.scanner_pids[X].grcolor := hextotcolor(pid_grid_config.Cells[4, Y]);

          gentypes.scanner_pids[X].wfcolor := hextotcolor(pid_grid_config.Cells[9, Y]);

          gentypes.scanner_pids[X].wrcolor := hextotcolor(pid_grid_config.Cells[8, Y]);

          if pid_grid_config.Cells[10, Y] = '' then
            pid_grid_config.Cells[10, Y] := '200000';

          try
            gentypes.scanner_pids[X].wfilter := newstrtofloat(pid_grid_config.Cells[10, Y]);

          except
            gentypes.scanner_pids[X].wfilter := 200000;
          end;

          with tform8(pp.list[scanner_pids[X].pidwindowindex]) do
            try
              begin
                Color := hextotcolor(pid_grid_config.Cells[4, Y]);
                ptitle.Font.Color := hextotcolor(pid_grid_config.Cells[5, Y]);
                Value.Font.Color := hextotcolor(pid_grid_config.Cells[5, Y]);
                units.Font.Color := hextotcolor(pid_grid_config.Cells[5, Y]);
                if pid_grid_config.Cells[15, Y] = '1' then
                begin
                  Show;
                  Top := StrToInt(pid_grid_config.Cells[11, Y]);
                  Left := StrToInt(pid_grid_config.Cells[12, Y]);
                  Width := StrToInt(pid_grid_config.Cells[13, Y]);
                  Height := StrToInt(pid_grid_config.Cells[14, Y]);
                end;
              end;
            except
            end;

        end;

    gridapply := false;
  end;

var
  cx, bc, CZ: Byte;
label
  rebuildlist;
begin
  savelist('uvscan_checklist.pid', EnginePids);
  savelist('uvscan_checklist.pid', TrannyPids);
  savelist('uvscan_checklist.pid', indypids);
  savelist('uvscan_checklist.pid', BodyPids);
  savelist('uvscan_checklist.pid', ACCPids);
  savelist('uvscan_checklist.pid', ad);
  savelist('uvscan_checklist.pid', fakepids);
  savelist('uvscan_checklist.pid', otherpids);

  if (logstatus = 1) or (logstatus = 2) then
  begin
    ShowMessage('Stop your Scan Logging First.');
    Exit;
  end;

  logstatus := 33;
  scani.linecount := 0;
  Form1.sbar.Panels[4].Text := 'LINECOUNT ' + IntToStr(scani.linecount);
  ToolBar1.GradientEndColor := $00ACB7BD;
  sendhb := false;
  pid_grid.zoomfactor := 0;
  VrTimer1.Enabled := false;
  ScannerB.Enabled := false;
  STOPSCANNER.Enabled := false;
rebuildlist:
  sentcommand := false;
  DisconnectB.Enabled := false;
  BAD_PID := false;
  BADPID.Enabled := false;
  scani.fakepids.Clear;
  scani.ADPORTS.Clear;

  if log_grid <> nil then
    log_grid.Destroy;

  pid_grid.Clear;
  log_grid := TAdvStringGrid.Create(SELF);
  log_grid.Parent := Form1;
  log_grid.Visible := false;
  log_grid.hide;

  savelist('uvscan_checklist.pid', EnginePids);
  savelist('uvscan_checklist.pid', TrannyPids);
  savelist('uvscan_checklist.pid', indypids);
  savelist('uvscan_checklist.pid', BodyPids);
  savelist('uvscan_checklist.pid', ACCPids);
  savelist('uvscan_checklist.pid', ad);
  savelist('uvscan_checklist.pid', fakepids);
  savelist('uvscan_checklist.pid', otherpids);

  scani.PID_Strings.Clear;
  scani.linecount := 1;
  scani.currentblock := $FE;
  scani.lastblock := $FE;
  scani.bytecount := 0;
  scani.Pid_Count := 0;
  scani.Pid_POS := 1;

  pid_grid.ColumnHeaders[0] := 'Title';
  pid_grid.ColumnHeaders[1] := 'Value';
  pid_grid.ColumnHeaders[2] := 'Type';

  log_grid.ColCount := pid_grid.RowCount - 2;
  // FIXXXXXX

  delayticks(5, false);
  BAD_PID := false;
  for bc := 2 downto 0 do
  begin
    if checkpids(bc, EnginePids) = false then
    begin;
      addmemoline('to many pids');
      Exit;
    end;
    if checkpids(bc, TrannyPids) = false then
    begin;
      addmemoline('to many pids');
      Exit;
    end;
    if checkpids(bc, BodyPids) = false then
    begin;
      addmemoline('to many pids');
      Exit;
    end;
    if checkpids(bc, indypids) = false then
    begin;
      addmemoline('to many pids');
      Exit;
    end;
    if checkpids(bc, ACCPids) = false then
    begin;
      addmemoline('to many pids');
      Exit;
    end;
    if checkpids(bc, otherpids) = false then
    begin;
      addmemoline('to many pids');
      Exit;
    end;
    if checkpids(bc, ad) = false then
    begin;
      addmemoline('to many pids');
      Exit;
    end;
    if checkpids(bc, fakepids) = false then
    begin;
      addmemoline('to many pids');
      Exit;
    end;
  end;

  VrTimer1.Enabled := true;

  if SetupPIDs = false then
  begin
    addmemoline('Error setting up PID StringList');
    ScannerB.Enabled := true;
    STOPSCANNER.Enabled := true;
    Exit;
  end;

  avtinit.Enabled := false;
  avtversion.Enabled := false;
  AVTVIN1.Enabled := false;
  AVTVIN2.Enabled := false;
  AVTVIN3.Enabled := false;
  AVTOSID.Enabled := false;

  STOPSCANNER.Enabled := true;
  blockFE.Enabled := true;
  BLOCKFD.Enabled := true;
  BLOCKFC.Enabled := true;
  BLOCKFB.Enabled := true;
  BLOCKFA.Enabled := true;
  BLOCKF9.Enabled := true;
  BLOCKF8.Enabled := true;
  BLOCKF7.Enabled := true;
  ADPORTS.Enabled := true;

  BADPID.Enabled := true;

  start := Now();
  LOGstart := Now();
  for cx := 1 to scani.Pid_Count do // SETS GRID COL TITLES
    log_grid.Cells[cx, 0] := scanner_pids[cx].ShortName;
  for bc := 0 to scani.PID_Strings.Count - 1 do
  begin
    sendcommand(scani.PID_Strings[bc], 4);
    if BAD_PID then
    begin;
      addmemoline('PID failed. Unchecking it, and rebuilding List');
      findremovepid(scani.PID_Strings[bc], EnginePids);
      findremovepid(scani.PID_Strings[bc], TrannyPids);
      findremovepid(scani.PID_Strings[bc], BodyPids);
      findremovepid(scani.PID_Strings[bc], indypids);
      findremovepid(scani.PID_Strings[bc], ACCPids);
      findremovepid(scani.PID_Strings[bc], otherpids);
      findremovepid(scani.PID_Strings[bc], ad);
      findremovepid(scani.PID_Strings[bc], fakepids);
    end;
    if BAD_PID then
      goto rebuildlist;
  end;

  delayticks(2, false);

  Startlogb.Enabled := true;
  pauseb.Enabled := true;
  if admode then
  begin
    addmemoline('INIT AD Mode');
    sendcommand('525901', 0);
  end;
  ScannerB.Enabled := true;
  STOPSCANNER.Enabled := true;
  scannerrunning := true;
  BADPID.Enabled := false;
  PIDPanel.ActivePageIndex := 1;
  applypidgridsetup;
  Timer1.Enabled := true;
end;

procedure TForm1.pidpopPopup(Sender: TObject);
begin
  pidpop.Items[0].Caption := 'Modify Selected PID (' + pid_grid.Cells[0, pid_grid.Row] + ')';
end;

procedure TForm1.pidsize(Sender: TObject);
var
  X: Integer;
  tcl: TCheckListBox;
begin
  tcl := Sender as TCheckListBox;
  for X := 1 to PIDCSV.RowCount do
    if UpperCase(tcl.Items[tcl.ItemIndex]) = UpperCase(PIDCSV.Cells[1, X]) then
      pbs.Caption := PIDCSV.Cells[5, X]; // addmemoline('size = '+pidcsv.cells[5,x]);
end;

procedure TForm1.pid_gridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = vk_f1 then
    SpeedButton1.Click;
  if Key = vk_f2 then
    SpeedButton2.Click;
end;

procedure TForm1.portlistClick(Sender: TObject);
begin
  MTS.CurrentPort := portlist.ItemIndex;
end;

procedure TForm1.ReadDTCs1Click(Sender: TObject);

  procedure dtcrequest(id, tag: string);
  begin
    currentdtc := tag;
    addmemoline('');
    addmemoline('-- ' + tag + ' DTC Detecting ');
    dtc_find.Enabled := false;

    dtc_ago.StartString := '07006CF1' + id + '5908';
    dtc_ago.StartString := hextostring(dtc_ago.StartString);

    dtc_find.StartString := '08006CF1' + id + '59';
    dtc_find.StartString := hextostring(dtc_find.StartString);

    dtc_ago.Enabled := true;
    sendcommand('05 6C ' + id + ' F1 27 01', 20);
    sendcommand('07 6C ' + id + ' F1 19 08 FF FF   ', 20);
    sendcommand('07 6C ' + id + ' F1 19 08 FF 00   ', 20);
    addmemoline('-- ' + tag + ' DTC Count : ' + IntToStr(DTCCOUNT));
    dtc_ago.Enabled := false;
    dtc_find.Enabled := true;
  end;

var
  X: Integer;
begin
  if (logstatus = 1) or (logstatus = 2) then
  begin
    ShowMessage('Please stop your scan log first.');
    Exit;
  end;

  FillChar(dtcm, SizeOf(dtcm), 0); // should set all to false
  // dtc codes
  DTCCOUNT := 0;
  for X := 1 to 5 do
    addmemoline('');
  addmemoline('DTC CODES Reader (Beta, expect issues)');
  addmemoline('------------------------------');
  addmemoline('Detecting Vehicle Modules : START');
  FindModules.Enabled := true;

  sendcommand('04 6C FE F1 20', 20); // shows modules each

  addmemoline('Detecting Vehicle Modules : DONE');
  FindModules.Enabled := false; // ok they are found lets continue!

  if dtcm.Abs then
    dtcrequest('20', 'ABS');
  if dtcm.BCM then
    dtcrequest('40', 'BCM');
  if dtcm.PCM then
    dtcrequest('10', 'PCM/ECM');
  if dtcm.NETWORK then
    dtcrequest('50', 'NETWORK');
  if dtcm.AIRBAG then
    dtcrequest('58', 'AIRBAG');
  if dtcm.IPC then
    dtcrequest('60', 'IPC');
  if dtcm.HUD then
    dtcrequest('62', 'HUD');
  if dtcm.RADIO then
    dtcrequest('80', 'RADIO');
  if dtcm.IMMOBILIZER then
    dtcrequest('C0', 'IMMOBILIZER');

  // 07 00 6C F1 10 59 08

  // check for 07 00 6C F1 10 59 08 01  ??  01 = # set ??
  // 08 00 6C F1 10 59 04 40 BB   04 40 = code bb = status
  // 08 00 6C F1 10 59s 00 00 FF   00 00 = end
end;

procedure TForm1.ResetallRows1Click(Sender: TObject);
var
  z, cx: Integer;
  yy: TColor;
begin
  if pid_grid.zoomfactor <> 0 then
    for cx := 0 to pid_grid.zoomfactor - 1 do
      pid_grid.Zoom(-1);

  for cx := 1 to pid_grid.RowCount - 1 do
  begin
    pid_grid.RowHeights[cx] := 21;
    pid_grid.Font.Size := 8;
    pid_grid.FontSizes[0, cx] := 8;
    pid_grid.FontSizes[1, cx] := 8;
    pid_grid.FontSizes[2, cx] := 8;
    pid_grid.FontColors[1, cx] := clBlack;
    pid_grid.FontColors[2, cx] := clBlack;

    if Odd(cx) then
      yy := hextotcolor(cfg.primary)
    else
      yy := hextotcolor(cfg.secondary);

    pid_grid.RowColor[cx] := yy;

    scanner_pids[cx].gfcolor := clBlack;
    scanner_pids[cx].grcolor := yy;
    scanner_pids[cx].wfilter := 200000;

    with tform8(pp.list[scanner_pids[cx].pidwindowindex]) do
      try
        begin
          Color := yy;
          ptitle.Color := clBlack;
          Value.Color := clBlack;
          units.Color := clBlack;
        end;
      except
      end;
  end;
end;

procedure TForm1.About2Click(Sender: TObject);
begin
  ShowMessage('UVSCAN ' + versionid + ' by Steven Chesser' + #10#13 + 'http://www.uvscanning.com');
end;

procedure TForm1.addpidtolist(Sender: TObject);
var
  Y, X, z: Integer;
  tcl: TCheckListBox;
begin
  tcl := Sender as TCheckListBox;
  if tcl.Checked[tcl.ItemIndex] = true then
  begin
    for z := 1 to PIDCSV.RowCount do
      if UpperCase(tcl.Items[tcl.ItemIndex]) = UpperCase(PIDCSV.Cells[1, z]) then
        if NEWSTRTOINT(PIDCSV.Cells[7, z]) = group then
          if NEWSTRTOINT(PIDCSV.Cells[5, z]) = 0 then
          begin
            addmemoline('0 Byte Sized PID added!');
            Inc(PIDCOUNTER.F_count);
          end
          else
          begin
            for X := 1 to PIDCSV.RowCount do
              if UpperCase(tcl.Items[tcl.ItemIndex]) = UpperCase(PIDCSV.Cells[X, Y]) then
                if NEWSTRTOINT(PIDCSV.Cells[7, z]) = group then
                  Y := NEWSTRTOINT(PIDCSV.Cells[5, X]);
            if PIDCOUNTER.bytecount + Y >= 48 then
            begin
              tcl.Checked[tcl.ItemIndex] := false;
              addmemoline('bytecount');
              Exit;
            end;
            Inc(PIDCOUNTER.Count);
            for X := 1 to PIDCSV.RowCount do
              if UpperCase(tcl.Items[tcl.ItemIndex]) = UpperCase(PIDCSV.Cells[1, X]) then
                if NEWSTRTOINT(PIDCSV.Cells[7, z]) = group then
                  Inc(PIDCOUNTER.bytecount, NEWSTRTOINT(PIDCSV.Cells[5, X]));
          end;
  end
  else

  begin
    for z := 1 to PIDCSV.RowCount do
      if UpperCase(tcl.Items[tcl.ItemIndex]) = UpperCase(PIDCSV.Cells[1, z]) then
        if NEWSTRTOINT(PIDCSV.Cells[7, z]) = group then
          if NEWSTRTOINT(PIDCSV.Cells[5, z]) = 0 then
          begin
            Dec(PIDCOUNTER.F_count);
          end
          else
          begin
            Dec(PIDCOUNTER.Count);
            for X := 1 to PIDCSV.RowCount do
              if UpperCase(tcl.Items[tcl.ItemIndex]) = UpperCase(PIDCSV.Cells[1, X]) then
                if NEWSTRTOINT(PIDCSV.Cells[7, z]) = group then
                  Dec(PIDCOUNTER.bytecount, NEWSTRTOINT(PIDCSV.Cells[5, X]));
          end;
  end;
  pbc.Caption := IntToStr(PIDCOUNTER.bytecount);
  tsp.Caption := IntToStr(PIDCOUNTER.Count);
  tfp.Caption := IntToStr(PIDCOUNTER.F_count);
end;

procedure TForm1.add_pidlist(t: pid_Rec; b: Byte);

  procedure al(a: TObject; txt: string; bx: Byte);
  var
    X: Integer;
  begin
    X := TCheckListBox(a).Items.add(txt);
    if bx = 2 then
    begin
      if X = 0 then
        X := 1;

      TCheckListBox(a).ItemEnabled[X - 1] := false;
      statusmemo.Lines.add('code 2 :: ' + txt);
    end;
  end;

begin
  with t do

  begin
    case NEWSTRTOINT(PIDCategoryID) of
      1:
        al(EnginePids, LongName, b);
      2:
        al(TrannyPids, LongName, b);
      3:
        al(indypids, LongName, b);
      4:
        al(BodyPids, LongName, b);
      5:
        al(ACCPids, LongName, b);
      6:
        al(fakepids, LongName, b);
      7:
        al(ad, LongName, b);
      0:
        al(otherpids, LongName, b);
    else
      al(otherpids, LongName, b);
    end;
  end;
end;

procedure TForm1.EnableallPids1Click(Sender: TObject);
var
  X: Integer;
begin
  if MessageBox(application.Handle, 'Enable All PIDs?', PChar(Caption), mb_yesno or MB_DEFBUTTON2) = idYes then
  begin
    for X := 0 to EnginePids.Count - 1 do
      EnginePids.ItemEnabled[X] := true;
    for X := 0 to TrannyPids.Count - 1 do
      TrannyPids.ItemEnabled[X] := true;
    for X := 0 to BodyPids.Count - 1 do
      BodyPids.ItemEnabled[X] := true;
    for X := 0 to indypids.Count - 1 do
      indypids.ItemEnabled[X] := true;
    for X := 0 to fakepids.Count - 1 do
      fakepids.ItemEnabled[X] := true;
    for X := 0 to ad.Count - 1 do
      ad.ItemEnabled[X] := true;
    for X := 0 to ACCPids.Count - 1 do
      ACCPids.ItemEnabled[X] := true;
    for X := 0 to otherpids.Count - 1 do
      otherpids.ItemEnabled[X] := true;
  end;
  EnginePids.Repaint;
  TrannyPids.Repaint;
  BodyPids.Repaint;
  indypids.Repaint;
  fakepids.Repaint;
  ad.Repaint;
  ACCPids.Repaint;
  otherpids.Repaint;
end;

procedure TForm1.estVehicleforPIDS1Click(Sender: TObject);

  function Tdiff(StartDate: tdatetime; EndDate: tdatetime): Double;
  var
    Hour: Word;
    Min: Word;
    Sec: Word;
    MSec: Word;
    Delta: tdatetime;
  begin
    try
      Delta := EndDate - StartDate;
      DecodeTime(Delta, Hour, Min, Sec, MSec);
      Result := (((Hour * 60) + Min) * 60) + Sec;
    except
      Result := 0;
    end;
  end;

var
  cx: Integer;
  PIDCode: string;
  FAKEP: Boolean;
  o: Byte;
begin
  if comport.Open = false then
  begin
    statusmemo.Lines.add('Connect to vehicle first before testing for PIDS');
    Exit;
  end;

  o := 0;
  sbar.Panels[6].Text := '';
  pid_passed := 0;
  pid_failed := 0;
  pid_fake := 0;
  piddone := false;
  statusmemo.Lines.add('');
  statusmemo.Lines.add('Testing for VALID PIDs');
  statusmemo.Lines.add('--------------------------');
  statusmemo.Lines.add('Total PIDs to check: ' + IntToStr(Length(availablepids)));

  cx := 1;
  nextpidavail := false;

  CHECKPID1.Enabled := true;
  CHECKPID2.Enabled := true;
  checkpid3.Enabled := true;

  nextpidavail := true;

  EnginePids.Clear;
  TrannyPids.Clear;
  indypids.Clear;
  BodyPids.Clear;
  ACCPids.Clear;
  fakepids.Clear;
  ad.Clear;
  otherpids.Clear;

  EnginePids.Sorted := false;
  TrannyPids.Sorted := false;
  indypids.Sorted := false;
  BodyPids.Sorted := false;
  ACCPids.Sorted := false;
  fakepids.Sorted := false;
  ad.Sorted := false;
  otherpids.Sorted := false;
  PID_TIMEOUTCOUNT := 0;

  et := Now;

  st := Now;

  repeat
    sbar.Panels[6].Text := IntToStr(cx) + '/' + IntToStr(Length(availablepids));
    ;

    statusmemo.Lines.add(FloatToStr(Tdiff(st, et)));

    if nextpidavail then

    begin
      if pidtfailed then
        o := 2
      else
        o := 0;
      pidtfailed := false;

      FAKEP := false;

      if (UpperCase(availablepids[cx].PCMPID) = 'FPID') then
        FAKEP := true;
      if (UpperCase(availablepids[cx].PCMPID) = 'FFFF') then
        FAKEP := true;
      if (UpperCase(availablepids[cx].PCMPID) = 'FFFE') then
        FAKEP := true;
      if (UpperCase(availablepids[cx].PCMPID) = 'FFFD') then
        FAKEP := true;

      if FAKEP then

      begin
        add_pidlist(availablepids[cx], o);
        Inc(pid_fake);
        Inc(cx);
        nextpidavail := true;
      end
      else if availablepids[cx].PIDGroupID = '1' then
      begin
        PIDCode := availablepids[cx].PCMPID;
        case Length(PIDCode) of // pads it with zeros if need be
          1:
            Insert('000', PIDCode, 1);
          2:
            Insert('00', PIDCode, 1);
          3:
            Insert('0', PIDCode, 1);
        end;

        add_pidlist(availablepids[cx], o);
        statusmemo.Lines.add('Requesting PID : ' + availablepids[cx].LongName + ' : ' + IntToStr(cx));
        nextpidavail := false;
        st := Now;

        sendcommand('07 6C 10 F0 22 ' + PIDCode + '01', 4);
        Inc(cx);
      end
      else
      begin;
        Inc(cx);
        nextpidavail := true;
      end;
    end
    else
    begin
      application.handlemessage;
    end;

  until (timedout) or (piddone) or (PID_TIMEOUTCOUNT >= 3) or (cx >= Length(availablepids));

  sbar.Panels[6].Text := IntToStr(cx) + '/' + IntToStr(Length(availablepids));;
  CHECKPID1.Enabled := false;
  CHECKPID2.Enabled := false;
  checkpid3.Enabled := false;

  statusmemo.Lines.add('PIDS Passed  : ' + IntToStr(pid_passed));
  statusmemo.Lines.add('PIDS Failed  : ' + IntToStr(pid_failed));
  statusmemo.Lines.add('PIDS FAKE/AD : ' + IntToStr(pid_fake));

  EnginePids.Sorted := true;
  TrannyPids.Sorted := true;
  indypids.Sorted := true;
  BodyPids.Sorted := true;
  ACCPids.Sorted := true;
  fakepids.Sorted := true;
  ad.Sorted := true;
  otherpids.Sorted := true;

  pidlistsave.FileName := vehicle.osid;
  pidlistsave.InitialDir := GetCurrentDir;

  if pidlistsave.Execute then
  begin
    savelist(pidlistsave.FileName, EnginePids);
    savelist(pidlistsave.FileName, TrannyPids);
    savelist(pidlistsave.FileName, indypids);
    savelist(pidlistsave.FileName, BodyPids);
    savelist(pidlistsave.FileName, ACCPids);
    savelist(pidlistsave.FileName, ad);
    savelist(pidlistsave.FileName, fakepids);
    savelist(pidlistsave.FileName, otherpids);
  end;
end;

procedure TForm1.SavePidList1Click(Sender: TObject);
begin
  if pidlistsave.Execute then
  begin
    savelist(pidlistsave.FileName, EnginePids);
    savelist(pidlistsave.FileName, TrannyPids);
    savelist(pidlistsave.FileName, indypids);
    savelist(pidlistsave.FileName, BodyPids);
    savelist(pidlistsave.FileName, ACCPids);
    savelist(pidlistsave.FileName, ad);
    savelist(pidlistsave.FileName, fakepids);
    savelist(pidlistsave.FileName, otherpids);
  end;
end;

procedure TForm1.pausebClick(Sender: TObject);
begin
  case logstatus of
    1:
      begin;
        logstatus := 2;
        pauseb.Caption := 'RESUME';
        ToolBar1.GradientEndColor := clRed;
      end;

    2:
      begin;
        logstatus := 1;
        pauseb.Caption := 'PAUSE';
        ToolBar1.GradientEndColor := clGreen;
      end;
  end;
end;

procedure TForm1.VrTimer1Timer(Sender: TObject);
begin
  comport.PutString(hextostring('046CFEF13F'));
end;

procedure TForm1.STOPSCANNERClick(Sender: TObject);
begin
  if (logstatus = 1) or (logstatus = 2) then
    if MessageBox(application.Handle, 'LOGGING A SCAN. This will abort it! Continue to STOP?', PChar(Caption),
      mb_yesno or MB_DEFBUTTON2) = idYes then
    begin
      addmemoline(#10#13 + '.. SCANNER STOPED .. ' + #10#13);
      if admode then
      begin
        addmemoline('AD Mode Turning Off');
        sendcommand('52 59 00', 4);
      end;
      ToolBar1.GradientEndColor := $00ACB7BD;
      logstatus := 33;
      pauseb.Caption := 'PAUSE';
      sendhb := false;
      FE_Counter := 0;
      pauseb.Enabled := false;
      Startlogb.Caption := 'START LOG (F8)';
      logstatus := 33;
      pauseb.Caption := 'PAUSE';
      pauseb.Enabled := false;
      log_grid.Cells[0, 0] := 'Count';
      Startlogb.Enabled := false;
      VrTimer1.Enabled := false;
      STOPSCANNER.Enabled := false;
      pauseb.Enabled := false;
      Startlogb.Enabled := false;
      blockFE.Enabled := false;
      BLOCKFD.Enabled := false;
      BLOCKFC.Enabled := false;
      BLOCKFB.Enabled := false;
      BLOCKFA.Enabled := false;
      BLOCKF9.Enabled := false;
      BLOCKF8.Enabled := false;
      BLOCKF7.Enabled := false;

      try
{$I-} CloseFile(backupcsv); {$I+}
      except
      end;
    end;
end;

end.
