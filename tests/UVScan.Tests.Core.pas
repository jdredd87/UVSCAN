unit UVScan.Tests.Core;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.JSON, DUnitX.TestFramework,
  UVScan.Hex, UVScan.Avt, UVScan.Class2, UVScan.Formula, UVScan.Pids, UVScan.Dpid, UVScan.Dtc,
  UVScan.QuickStart;

type
  [TestFixture]
  TQuickStartTests = class
  public
    [Test] procedure LegacySwitchesStillWork;
    [Test] procedure LogMeansScanAndConnect;
    [Test] procedure ValuesWithSpaces;
    [Test] procedure QuickPicksAKnownOne;
    [Test] procedure UnknownQuickOrMissingValueIsReported;
    [Test] procedure ArgumentsParseBack;
    [Test] procedure JsonRoundTrip;
  end;

  [TestFixture]
  THexTests = class
  public
    [Test] procedure RoundTrip;
    [Test] procedure RejectsOddDigits;
  end;

  [TestFixture]
  TAvtFramingTests = class
  public
    [Test] procedure EncodesBusMessageWithLengthNibble;
    [Test] procedure ParsesBusFrameAndStripsStatus;
    [Test] procedure ParsesFramesSplitAcrossReads;
    [Test] procedure ParsesNonBusFrames;
    [Test] procedure ParsesExtendedLengthFrame;
    [Test] procedure ResyncsAfterStrayHeaderByte;
    [Test] procedure ResyncsAfterTruncatedFrame;
    [Test] procedure ResyncsAfterHeaderWithoutData;
    [Test] procedure ResyncsWhenReadingTwoBytesLate;
    [Test] procedure ResyncsWhenReadingThreeBytesLate;
    [Test] procedure SkipsTailOfFrameAtConnect;
  end;

  [TestFixture]
  TClass2Tests = class
  public
    [Test] procedure ReadVinBlockMatchesLegacyBytes;
    [Test] procedure DefineDpidMatchesLegacyBytes;
    [Test] procedure RequestDpidsMatchesLegacyBytes;
    [Test] procedure WriteVinMatchesLegacyBytes;
    [Test] procedure FormatsDtcs;
    [Test] procedure RejectsBadDpidSlot;
    [Test] procedure ParsesPidRanges;
  end;

  [TestFixture]
  TFormulaTests = class
  public
    [Test] procedure EngineSpeed;
    [Test] procedure BitFlags;
    [Test] procedure ComparisonsYieldOneOrZero;
    [Test] procedure MciReferences;
    [Test] procedure PrecedenceAndUnaryMinus;
    [Test] procedure DivisionByZeroIsNaN;
    [Test] procedure RejectsGarbage;
    [Test] procedure Conditional;
    [Test] procedure ExplainsMissingPercent;
  end;

  [TestFixture]
  TPidCatalogTests = class
  public
    [Test] procedure LoadsCatalog;
    [Test] procedure FormatsResults;
    [Test] procedure RoundsReadings;
    [Test] procedure TidyDecimalsFitThePid;
    [Test] procedure ShippedPidFileLoadsCleanly;
    [Test] procedure ShippedDtcFileLoadsCleanly;
  end;

  [TestFixture]
  TDpidPlannerTests = class
  private
    function Req(Item: Integer; Pid: Word; Size: Byte): TDpidRequest;
  public
    [Test] procedure ThreeTwoBytePidsFillExactlyOneDpid;
    [Test] procedure PacksLargestFirstWithoutSplitting;
    [Test] procedure StreamRequestsSplitIntoGroupsOfFour;
    [Test] procedure RejectsTooManyBytes;
  end;

implementation

{ THexTests }

procedure THexTests.RoundTrip;
begin
  Assert.AreEqual('6C 10 F1 3C 01', BytesToHex(HexToBytes('6c10f13c01')));
  Assert.AreEqual('0A-FF', BytesToHex(HexToBytes(' 0a ff '), '-'));
end;

procedure THexTests.RejectsOddDigits;
begin
  Assert.WillRaise(procedure begin HexToBytes('ABC') end, EConvertError);
  Assert.WillRaise(procedure begin HexToBytes('ZZ') end, EConvertError);
end;

{ TAvtFramingTests }

procedure TAvtFramingTests.EncodesBusMessageWithLengthNibble;
begin
  Assert.AreEqual('05 6C 10 F1 3C 01', BytesToHex(EncodeBusMessage(HexToBytes('6C10F13C01'))));
  Assert.AreEqual('F1 A5', BytesToHex(EncodeAvtFrame($F, HexToBytes('A5'))));
  Assert.AreEqual('B0', BytesToHex(EncodeAvtFrame($B, nil)));
end;

procedure TAvtFramingTests.ParsesBusFrameAndStripsStatus;
var
  P: TAvtFrameParser;
  F: TAvtFrame;
begin
  P := TAvtFrameParser.Create;
  try
    P.Push(HexToBytes('0C 00 6C F1 10 6A FE 01 02 03 04 05 06'));
    Assert.IsTrue(P.TryNext(F));
    Assert.IsTrue(F.IsBusMessage);
    Assert.AreEqual('6C F1 10 6A FE 01 02 03 04 05 06', BytesToHex(F.BusMessage));
    Assert.IsFalse(P.TryNext(F));
    Assert.AreEqual(0, P.Pending);
  finally
    P.Free;
  end;
end;

procedure TAvtFramingTests.ParsesFramesSplitAcrossReads;
var
  P: TAvtFrameParser;
  F: TAvtFrame;
begin
  P := TAvtFrameParser.Create;
  try
    P.Push(HexToBytes('92 04'));
    Assert.IsFalse(P.TryNext(F));
    P.Push(HexToBytes('13 01'));
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('92 04 13', F.ToHex);
    Assert.IsFalse(P.TryNext(F));
    P.Push(HexToBytes('60'));
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('01 60', F.ToHex);
  finally
    P.Free;
  end;
end;

procedure TAvtFramingTests.ParsesNonBusFrames;
var
  P: TAvtFrameParser;
  F: TAvtFrame;
begin
  P := TAvtFrameParser.Create;
  try
    P.Push(HexToBytes('91 07 64 58 10 20 30'));
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual(9, Integer(F.Kind));
    Assert.IsFalse(F.IsBusMessage);
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual(6, Integer(F.Kind));
    Assert.AreEqual('58 10 20 30', BytesToHex(F.Data));
  finally
    P.Free;
  end;
end;

procedure TAvtFramingTests.ParsesExtendedLengthFrame;
var
  P: TAvtFrameParser;
  F: TAvtFrame;
  Msg: TBytes;
begin
  Msg := HexToBytes('6C F1 10 7C 01 00 31 32 33 34 35 36 37 38 39 40');
  Assert.AreEqual('11 10', BytesToHex(Copy(EncodeBusMessage(Msg), 0, 2)));
  P := TAvtFrameParser.Create;
  try
    P.Push(ConcatBytes(HexToBytes('11 11 00'), Msg));
    Assert.IsTrue(P.TryNext(F));
    Assert.IsTrue(F.IsBusMessage);
    Assert.AreEqual(BytesToHex(Msg), BytesToHex(F.BusMessage));
  finally
    P.Free;
  end;
end;

procedure TAvtFramingTests.ResyncsAfterStrayHeaderByte;
var
  P: TAvtFrameParser;
  F: TAvtFrame;
begin
  // Captured on an AVT-841: a duplicated 0C header byte ahead of a stream frame.
  P := TAvtFrameParser.Create;
  try
    P.Push(HexToBytes('0C 0C 00 6C F1 10 6A FE 00 00 01 75 00 00 01 60'));
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('6C F1 10 6A FE 00 00 01 75 00 00', BytesToHex(F.BusMessage));
    Assert.AreEqual(1, P.Resyncs);
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('01 60', F.ToHex);
  finally
    P.Free;
  end;
end;

procedure TAvtFramingTests.ResyncsAfterTruncatedFrame;
var
  P: TAvtFrameParser;
  F: TAvtFrame;
begin
  // Captured on an AVT-841 + Keyspan on Android: the PCM was still streaming
  // when UVScan connected, the AVT reset cut a stream frame short after
  // "0C 00", then answered E1 33 with 91 07, then the VIN block 1 reply came.
  P := TAvtFrameParser.Create;
  try
    P.Push(HexToBytes('0C 00 91 07 0C 00 6C F1 10 7C 01 00 32 47 31 57 48 01 60'));
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('91 07', F.ToHex);
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('6C F1 10 7C 01 00 32 47 31 57 48', BytesToHex(F.BusMessage));
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('01 60', F.ToHex);
    Assert.AreEqual(2, P.Resyncs); // the cut frame's header, then its status byte
  finally
    P.Free;
  end;
end;

procedure TAvtFramingTests.ResyncsAfterHeaderWithoutData;
var
  P: TAvtFrameParser;
  F: TAvtFrame;
begin
  // Captured on a 1999 Grand Prix (AVT-841 + Keyspan USA-19HS, Windows) while
  // streaming: a 0C header with none of its bytes, then the transmit status
  // for a tester present and the next stream frames.
  P := TAvtFrameParser.Create;
  try
    P.Push(HexToBytes('0C 01 60 0C 00 6C F1 10 6A FE 00 00 02 16 00 00 0C 00 6C F1 10 6A FD 68 80 7A 63 00 80'));
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('01 60', F.ToHex);
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('6C F1 10 6A FE 00 00 02 16 00 00', BytesToHex(F.BusMessage));
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('6C F1 10 6A FD 68 80 7A 63 00 80', BytesToHex(F.BusMessage));
    Assert.AreEqual(1, P.Resyncs);
  finally
    P.Free;
  end;
end;

procedure TAvtFramingTests.ResyncsWhenReadingTwoBytesLate;
var
  P: TAvtFrameParser;
  F: TAvtFrame;
  Good: Integer;
begin
  // Captured on a Galaxy S23 (AVT-841 + Keyspan USA-19H) with the bench PCM:
  // stream frames read from their third byte, so "6C F1 ..." looked like a
  // kind 6 frame of 12 bytes, again and again. Within a frame or two the
  // parser must be back on the real frames.
  P := TAvtFrameParser.Create;
  try
    P.Push(HexToBytes(
      '6C F1 10 6A FE 00 00 01 08 00 80 ' +
      '0C 00 6C F1 10 6A FE 00 00 01 08 00 80 ' +
      '0C 00 6C F1 10 6A FE 00 00 01 08 00 80 ' +
      '0C 00 6C F1 10 6A FE 00 00 01 08 00 80 ' +
      '0C 00 6C F1 10 6A FE 00 00 01 08 00 80'));
    Good := 0;
    while P.TryNext(F) do
    begin
      Assert.AreNotEqual(Integer($6), Integer(F.Kind), 'still reading two bytes late: ' + F.ToHex);
      if F.IsBusMessage and (BytesToHex(F.BusMessage) = '6C F1 10 6A FE 00 00 01 08 00 80') then
        Inc(Good);
    end;
    Assert.IsTrue(Good >= 2, Format('only %d stream frames read', [Good]));
    Assert.IsTrue(P.Resyncs > 0);
  finally
    P.Free;
  end;
end;

procedure TAvtFramingTests.ResyncsWhenReadingThreeBytesLate;
const
  A = '0C 00 6C F1 10 6A FE 00 00 01 08 00 80 ';
  B = '0C 00 6C F1 10 6A FD 00 75 00 00 00 00 ';
var
  P: TAvtFrameParser;
  F: TAvtFrame;
  Good: Integer;
begin
  // Captured on a Galaxy S9+ (AVT-841 + Keyspan USA-19H) with the bench PCM:
  // stream frames read from their fourth byte came out as "F1 10",
  // "FE 00 00 01 08 00 80 0C 00 6C F1 10 6A FD 00" and "75 00 00 00 00 0C",
  // a cycle that kept repeating.
  P := TAvtFrameParser.Create;
  try
    P.Push(HexToBytes('F1 10 6A FE 00 00 01 08 00 80 ' + B + A + B + A + B));
    Good := 0;
    while P.TryNext(F) do
    begin
      Assert.IsTrue(F.Kind in [$0, $6, $9], 'still out of step: ' + F.ToHex);
      if F.IsBusMessage and (Length(F.BusMessage) = 11) then
        Inc(Good);
    end;
    Assert.IsTrue(Good >= 4, Format('only %d stream frames read', [Good]));
    Assert.IsTrue(P.Resyncs > 0);
  finally
    P.Free;
  end;
end;

procedure TAvtFramingTests.SkipsTailOfFrameAtConnect;
var
  P: TAvtFrameParser;
  F: TAvtFrame;
begin
  // Connecting in the middle of a stream frame: the first byte read is the
  // last byte of a frame ("... 08 00 80").
  P := TAvtFrameParser.Create;
  try
    P.Push(HexToBytes('80 0C 00 6C F1 10 6A FE 00 00 01 08 00 80'));
    Assert.IsTrue(P.TryNext(F));
    Assert.AreEqual('6C F1 10 6A FE 00 00 01 08 00 80', BytesToHex(F.BusMessage));
    Assert.AreEqual(1, P.Resyncs);
  finally
    P.Free;
  end;
end;

{ TClass2Tests }

procedure TClass2Tests.ReadVinBlockMatchesLegacyBytes;
begin
  Assert.AreEqual('05 6C 10 F1 3C 01', BytesToHex(EncodeBusMessage(ReadBlockRequest(BlockVin1))));
  Assert.AreEqual('05 6C 10 F1 3C 0A', BytesToHex(EncodeBusMessage(ReadBlockRequest(BlockOsid))));
end;

procedure TClass2Tests.DefineDpidMatchesLegacyBytes;
begin
  // Legacy: '0A6C10F12C' + block + (64 + size + pos*8) + PID + 'FFFF'
  Assert.AreEqual('0A 6C 10 F1 2C FE 4A 00 0C FF FF',
    BytesToHex(EncodeBusMessage(DefineDpidRequest($FE, 1, 2, $000C))));
  Assert.AreEqual('0A 6C 10 F1 2C FD 59 00 05 FF FF',
    BytesToHex(EncodeBusMessage(DefineDpidRequest($FD, 3, 1, $0005))));
end;

procedure TClass2Tests.RequestDpidsMatchesLegacyBytes;
begin
  // The PCM refuses anything but 4 DPID slots (verified on a bench PCM).
  Assert.AreEqual('09 6C 10 F1 2A 14 FE FD 00 00',
    BytesToHex(EncodeBusMessage(RequestDpidsRequest($14, [$FE, $FD]))));
end;

procedure TClass2Tests.WriteVinMatchesLegacyBytes;
var
  R: TArray<TBytes>;
begin
  R := WriteVinRequests('1G1YY22G965100001');
  Assert.AreEqual('0B 6C 10 F1 3B 01 00 31 47 31 59 59', BytesToHex(EncodeBusMessage(R[0])));
  Assert.AreEqual('0B 6C 10 F1 3B 02 32 32 47 39 36 35', BytesToHex(EncodeBusMessage(R[1])));
  Assert.AreEqual('0B 6C 10 F1 3B 03 31 30 30 30 30 31', BytesToHex(EncodeBusMessage(R[2])));
  Assert.WillRaise(procedure begin WriteVinRequests('short') end, EArgumentException);
end;

procedure TClass2Tests.FormatsDtcs;
begin
  Assert.AreEqual('P0300', FormatDtc($03, $00));
  Assert.AreEqual('P1416', FormatDtc($14, $16));
  Assert.AreEqual('C0035', FormatDtc($40, $35));
  Assert.AreEqual('U0100', FormatDtc($C1, $00));
end;

procedure TClass2Tests.RejectsBadDpidSlot;
begin
  Assert.WillRaise(procedure begin DefineDpidRequest($FE, 6, 2, 1) end, EArgumentException);
  Assert.WillRaise(procedure begin DefineDpidRequest($FE, 0, 1, 1) end, EArgumentException);
end;

procedure TClass2Tests.ParsesPidRanges;
var
  R: TArray<TPidRange>;
begin
  R := ParsePidRanges('0000-00FF, $1000-$1FFF;1234');
  Assert.AreEqual(3, Integer(Length(R)));
  Assert.AreEqual(256, R[0].Count);
  Assert.AreEqual(Integer($1000), Integer(R[1].First));
  Assert.AreEqual(Integer($1FFF), Integer(R[1].Last));
  Assert.AreEqual(1, R[2].Count);
  try
    ParsePidRanges('2000-1000');
    Assert.Fail('reversed range accepted');
  except
    on EConvertError do
      ;
  end;
  try
    ParsePidRanges('zz');
    Assert.Fail('garbage accepted');
  except
    on EConvertError do
      ;
  end;
end;

{ TFormulaTests }

procedure TFormulaTests.EngineSpeed;
var
  F: TFormula;
begin
  F := TFormula.Create('((N1 << 8) +N2) *0.25');
  try
    Assert.AreEqual(Double(800), F.Evaluate([$0C, $80], []), 1e-9);
    Assert.IsTrue(F.UsesInputs);
  finally
    F.Free;
  end;
end;

procedure TFormulaTests.BitFlags;
var
  F: TFormula;
begin
  F := TFormula.Create('((N0 >> 3) & 1)');
  try
    Assert.AreEqual(Double(1), F.Evaluate([8], []), 0);
    Assert.AreEqual(Double(0), F.Evaluate([7], []), 0);
  finally
    F.Free;
  end;
  F := TFormula.Create('N0 & 15');
  try
    Assert.AreEqual(Double(5), F.Evaluate([$F5], []), 0);
  finally
    F.Free;
  end;
end;

procedure TFormulaTests.ComparisonsYieldOneOrZero;
var
  F: TFormula;
begin
  F := TFormula.Create('((N1 > 4) & 2) + ((N2 > 5) & 3)');
  try
    // (1 & 2) + (1 & 3) = 0 + 1
    Assert.AreEqual(Double(1), F.Evaluate([10, 10], []), 0);
  finally
    F.Free;
  end;
end;

procedure TFormulaTests.MciReferences;
var
  F: TFormula;
begin
  F := TFormula.Create('(%IPW% / (1 / ((%RPM% / 60 ) / 2) * 1000)) * 100');
  try
    Assert.AreEqual(2, Integer(Length(F.Variables)));
    Assert.AreEqual('IPW', F.Variables[0]);
    Assert.AreEqual('RPM', F.Variables[1]);
    // 3 ms at 3000 rpm: one injection per 40 ms -> 7.5 %
    Assert.AreEqual(Double(7.5), F.Evaluate([], [3, 3000]), 1e-9);
    Assert.IsTrue(IsNan(F.Evaluate([], [3])));
  finally
    F.Free;
  end;
end;

procedure TFormulaTests.PrecedenceAndUnaryMinus;
var
  F: TFormula;
begin
  F := TFormula.Create('N0-40');
  try
    Assert.AreEqual(Double(50), F.Evaluate([90], []), 0);
  finally
    F.Free;
  end;
  F := TFormula.Create('-2 + 3 * 4 - .5');
  try
    Assert.AreEqual(Double(9.5), F.Evaluate([], []), 1e-9);
  finally
    F.Free;
  end;
end;

procedure TFormulaTests.DivisionByZeroIsNaN;
var
  F: TFormula;
begin
  F := TFormula.Create('N0 / N2');
  try
    Assert.IsTrue(IsNan(F.Evaluate([1, 0], [])));
  finally
    F.Free;
  end;
end;

procedure TFormulaTests.RejectsGarbage;

  function Compile(const Text: string): TTestLocalMethod;
  begin
    Result :=
      procedure
      begin
        TFormula.Create(Text).Free;
      end;
  end;

begin
  Assert.WillRaise(Compile('(N0 + 1'), EFormulaError);
  Assert.WillRaise(Compile('N0 $ 1'), EFormulaError);
  Assert.WillRaise(Compile('%RPM'), EFormulaError);
end;

procedure TFormulaTests.Conditional;
var
  F: TFormula;
begin
  // From an old UVSCAN file: crank sensor period -> rpm, 0 when no signal.
  F := TFormula.Create('(((N1 << 8) + N2) ? 1310720 / ((N1 << 8) + N2) : 0)');
  try
    Assert.AreEqual(Double(0), F.Evaluate([0, 0], []), 0, 'no division by zero taken');
    Assert.AreEqual(Double(1310720 / 256), F.Evaluate([1, 0], []), 1e-9);
  finally
    F.Free;
  end;
  F := TFormula.Create('N0 > 10 ? N0 > 100 ? 2 : 1 : 0');
  try
    Assert.AreEqual(Double(0), F.Evaluate([5], []), 0);
    Assert.AreEqual(Double(1), F.Evaluate([50], []), 0);
    Assert.AreEqual(Double(2), F.Evaluate([200], []), 0);
  finally
    F.Free;
  end;
  try
    TFormula.Create('N0 ? 1').Free;
    Assert.Fail('"N0 ? 1" should not compile');
  except
    on EFormulaError do
      ;
  end;
end;

procedure TFormulaTests.ExplainsMissingPercent;
var
  Msg: string;
begin
  Msg := '';
  try
    TFormula.Create('(%MAFGmPerSec% * 1000) / ((((%RPM / 60) / 2) * 6) + 0.000001)').Free;
  except
    on E: EFormulaError do
      Msg := E.Message;
  end;
  Assert.IsTrue(Pos('Missing closing % after %RPM', Msg) > 0, Msg);
  Assert.IsTrue(Pos('%RPM%', Msg) > 0, Msg);
end;

{ TPidCatalogTests }

procedure TPidCatalogTests.LoadsCatalog;
var
  C: TPidCatalog;
begin
  C := TPidCatalog.Create;
  try
    C.LoadFromJsonText(
      '{"version":1,"pids":[' +
      '{"id":1,"name":"ENGINE SPEED","shortName":"RPM","kind":"vehicle","category":"engine","pid":"000C","bytes":2,"formula":"((N1 << 8) +N2) *0.25","units":"RPM","mci":"RPM"},' +
      '{"id":3,"name":"ECT","kind":"vehicle","category":"engine","pid":"5","bytes":1,"formula":"N0-40","mci":"%ECT%"},' +
      '{"id":20,"name":"AFR (LC-1)","kind":"calculated","category":"calculated","formula":"%AD1% * 3.008 + 7.35","format":"%f","mci":"AFRWideband"},' +
      '{"id":21,"name":"AD1","kind":"analog","category":"analog","analogChannel":1,"formula":"N0 * 0.0196","mci":"AD1"}]}');
    Assert.AreEqual(4, C.Count);
    Assert.AreEqual(0, C.Warnings.Count, C.Warnings.Text);
    Assert.AreEqual(Integer(pkVehicle), Integer(C[0].Kind));
    Assert.AreEqual(Integer($000C), Integer(C[0].PidNumber));
    Assert.AreEqual(Integer($0005), Integer(C[1].PidNumber));
    Assert.AreEqual('ECT', C[1].Mci);
    Assert.AreEqual(Integer(pkCalculated), Integer(C[2].Kind));
    Assert.AreEqual(Integer(pkAnalog), Integer(C[3].Kind));
    Assert.AreEqual(1, C[3].AnalogChannel);
    Assert.AreEqual('FFFF', C[3].PidCode);
    Assert.AreEqual('AFRWIDEBAND', C[2].Mci);
    Assert.IsNotNull(C.FindByMci('rpm'));
  finally
    C.Free;
  end;
end;

procedure TPidCatalogTests.FormatsResults;
var
  P: TPidDef;
begin
  P := TPidDef.Create;
  try
    Assert.AreEqual('12.346', P.FormatValue(12.34567));
    P.ResultFormat := '%f';
    Assert.AreEqual('12.35', P.FormatValue(12.34567));
    P.ResultFormat := '%o';
    Assert.AreEqual('ON', P.FormatValue(1));
    Assert.AreEqual('OFF', P.FormatValue(0));
    P.ResultFormat := '*f%d';
    Assert.AreEqual('212', P.FormatValue(100));
    Assert.AreEqual('--', P.FormatValue(NaN));
  finally
    P.Free;
  end;
end;

procedure TPidCatalogTests.RoundsReadings;
var
  P: TPidDef;
begin
  P := TPidDef.Create;
  try
    Assert.AreEqual('44', P.FormatValue(44.33, 0));
    Assert.AreEqual('45', P.FormatValue(44.5, 0));
    Assert.AreEqual('13.0', P.FormatValue(12.97, 1), 'the same width every time');
    Assert.AreEqual('0.45', P.FormatValue(0.4512, 2));
    Assert.AreEqual('0', P.FormatValue(-0.2, 0), 'no minus zero');
    Assert.AreEqual('-3', P.FormatValue(-3.1, 0));
    P.ResultFormat := '%f';
    Assert.AreEqual('12', P.FormatValue(12.34567, 0), 'rounding overrides %f');
    P.ResultFormat := '%o';
    Assert.AreEqual('ON', P.FormatValue(1, 2));
    P.ResultFormat := '*f';
    Assert.AreEqual('212.0', P.FormatValue(100, 1));
    Assert.AreEqual('--', P.FormatValue(NaN, 0));
  finally
    P.Free;
  end;
end;

procedure TPidCatalogTests.TidyDecimalsFitThePid;

  function Tidy(Kind: TPidKind; Bytes: Integer; const Formula, Units: string; const Format: string = ''): Integer;
  var
    P: TPidDef;
  begin
    P := TPidDef.Create;
    try
      P.Kind := Kind;
      P.DataLength := Bytes;
      P.FormulaText := Formula;
      P.Units := Units;
      P.ResultFormat := Format;
      Result := P.TidyDecimals;
    finally
      P.Free;
    end;
  end;

begin
  Assert.AreEqual(0, Tidy(pkVehicle, 1, 'N0/2.55', '%'), 'TP %');
  Assert.AreEqual(0, Tidy(pkVehicle, 1, '(N0-128)/1.28', '%', '%f'), 'fuel trim');
  Assert.AreEqual(0, Tidy(pkVehicle, 2, '((N1 << 8) +N2) *0.25', 'RPM'), 'RPM');
  Assert.AreEqual(0, Tidy(pkVehicle, 1, '((N0 >> 3) & 1)', 'None'), 'a status bit');
  Assert.AreEqual(0, Tidy(pkVehicle, 1, 'N0/1.609', 'MPH', '%f'), 'MPH');
  Assert.AreEqual(1, Tidy(pkVehicle, 1, 'N0/10', 'V'), 'ignition volts');
  Assert.AreEqual(1, Tidy(pkVehicle, 1, '22.5*N0/256', 'Degrees'), 'knock retard shows 0.4');
  Assert.AreEqual(1, Tidy(pkVehicle, 2, '(((N1<<8)+N2)/65.535)', 'ms', '%f'), 'injector pulse');
  Assert.AreEqual(2, Tidy(pkVehicle, 2, 'N1 * 0.005', 'V'), 'O2 volts');
  Assert.AreEqual(2, Tidy(pkVehicle, 1, 'N0 * 0.01563', ':1'), 'gear ratio');
  Assert.AreEqual(2, Tidy(pkAnalog, 0, 'N0/51', 'Volts', '%f'), 'analog input');
  Assert.AreEqual(1, Tidy(pkCalculated, 0, '%AD1% * 3.008 + 7.35', ':1', '%f'), 'wide-band AFR');
  Assert.AreEqual(0, Tidy(pkCalculated, 0, '%AD2% * 31.9 - 9.7', 'PSI', '%f'), 'fuel pressure');
  Assert.AreEqual(0, Tidy(pkVehicle, 1, 'N0 / 2.55', '%', '%d'), '%d');
end;

procedure TPidCatalogTests.ShippedPidFileLoadsCleanly;
var
  Dir, F: string;
  I: Integer;
  C: TPidCatalog;
begin
  Dir := ExtractFilePath(ParamStr(0));
  F := '';
  for I := 0 to 5 do
  begin
    if FileExists(Dir + 'data\pids.json') then
    begin
      F := Dir + 'data\pids.json';
      Break;
    end;
    Dir := ExtractFilePath(ExcludeTrailingPathDelimiter(Dir));
  end;
  Assert.IsTrue(F <> '', 'data\pids.json not found');
  C := TPidCatalog.Create;
  try
    C.LoadFromFile(F);
    Assert.IsTrue(C.Count > 50);
    Assert.AreEqual('', C.Warnings.Text, 'pids.json warnings');
    Assert.AreEqual(#$B0'C', C.FindByMci('ECT').Units);
  finally
    C.Free;
  end;
end;

function FindShippedFile(const Name: string): string;
var
  Dir: string;
  I: Integer;
begin
  Dir := ExtractFilePath(ParamStr(0));
  for I := 0 to 5 do
  begin
    Result := Dir + 'data\' + Name;
    if FileExists(Result) then
      Exit;
    Dir := ExtractFilePath(ExcludeTrailingPathDelimiter(Dir));
  end;
  Result := '';
end;

procedure TPidCatalogTests.ShippedDtcFileLoadsCleanly;
var
  F: string;
  C: TDtcCatalog;
begin
  F := FindShippedFile('dtcs.json');
  Assert.IsTrue(F <> '', 'data\dtcs.json not found');
  C := TDtcCatalog.Create;
  try
    C.LoadFromFile(F);
    Assert.AreEqual('', C.Warnings.Text);
    Assert.IsTrue(C.Count > 1000);
    Assert.IsTrue(Pos('Misfire', C.Describe('p0300')) > 0, C.Describe('P0300'));
  finally
    C.Free;
  end;
end;

{ TDpidPlannerTests }

function TDpidPlannerTests.Req(Item: Integer; Pid: Word; Size: Byte): TDpidRequest;
begin
  Result.Item := Item;
  Result.Pid := Pid;
  Result.Size := Size;
end;

procedure TDpidPlannerTests.ThreeTwoBytePidsFillExactlyOneDpid;
var
  Plan: TDpidPlan;
  Msgs: TArray<TBytes>;
begin
  // The legacy packer requested an extra undefined DPID in this case.
  Plan := PlanDpids([Req(0, $000C, 2), Req(1, $1193, 2), Req(2, $1250, 2)]);
  Assert.AreEqual(1, Integer(Length(Plan.Dpids)));
  Assert.AreEqual(6, Plan.Dpids[0].Used);
  Assert.AreEqual(Integer(5), Integer(Plan.Dpids[0].Slots[2].Position));
  Msgs := Plan.StreamRequests(StreamSpeedFast);
  // Up to 4 DPIDs go in both PCM schedule slots: twice the update rate.
  Assert.AreEqual(2, Integer(Length(Msgs)));
  Assert.AreEqual('6C 10 F1 2A 14 FE 00 00 00', BytesToHex(Msgs[0]));
  Assert.AreEqual('6C 10 F1 2A 24 FE 00 00 00', BytesToHex(Msgs[1]));
end;

procedure TDpidPlannerTests.PacksLargestFirstWithoutSplitting;
var
  Plan: TDpidPlan;
  D: TDpidDef;
  S: TDpidSlot;
begin
  Plan := PlanDpids([Req(0, 1, 1), Req(1, 2, 2), Req(2, 3, 2), Req(3, 4, 1), Req(4, 5, 2), Req(5, 6, 2)]);
  Assert.AreEqual(2, Integer(Length(Plan.Dpids)));
  Assert.AreEqual(10, Plan.TotalBytes);
  for D in Plan.Dpids do
    for S in D.Slots do
      Assert.IsTrue(S.Position + S.Size - 1 <= DpidDataBytes);
  Assert.AreEqual(Integer($FE), Integer(Plan.Dpids[0].Id));
  Assert.AreEqual(Integer($FD), Integer(Plan.Dpids[1].Id));
end;

procedure TDpidPlannerTests.StreamRequestsSplitIntoGroupsOfFour;
var
  Reqs: TArray<TDpidRequest>;
  I: Integer;
  Msgs: TArray<TBytes>;
begin
  for I := 0 to 14 do
    Reqs := Reqs + [Req(I, I + 1, 2)]; // 30 bytes -> 5 DPIDs
  Msgs := PlanDpids(Reqs).StreamRequests(StreamSpeedMedium);
  Assert.AreEqual(2, Integer(Length(Msgs)));
  // Two PCM schedule slots; a second request in the same slot would replace the first.
  Assert.AreEqual('6C 10 F1 2A 13 FE FD FC FB', BytesToHex(Msgs[0]));
  Assert.AreEqual('6C 10 F1 2A 23 FA 00 00 00', BytesToHex(Msgs[1]));
end;

procedure TDpidPlannerTests.RejectsTooManyBytes;
var
  Reqs: TArray<TDpidRequest>;
  I: Integer;
  Plan: TTestLocalMethod;
begin
  for I := 0 to 24 do
    Reqs := Reqs + [Req(I, I + 1, 2)]; // 50 bytes
  Plan :=
    procedure
    begin
      PlanDpids(Reqs);
    end;
  Assert.WillRaise(Plan, EDpidPlanError);
end;

{ TQuickStartTests }

procedure TQuickStartTests.LegacySwitchesStillWork;
var
  Q: TQuickStart;
  Problem: string;
begin
  Assert.IsTrue(ParseQuickStartArgs(['-port', 'COM9', '-connect', '-scan', '-log'], nil, Q, Problem), Problem);
  Assert.AreEqual('COM9', Q.Port);
  Assert.IsTrue(Q.Connect and Q.Scan and Q.Log);
  Assert.IsFalse(Q.FullScreen or Q.Chart or Q.Retry);
  Assert.IsTrue(ParseQuickStartArgs(['-port', '192.168.2.99:10001'], nil, Q, Problem));
  Assert.AreEqual('192.168.2.99:10001', Q.Port);
  Assert.IsFalse(Q.Connect, 'only the port');
  Assert.IsTrue(ParseQuickStartArgs([], nil, Q, Problem));
  Assert.IsFalse(Q.Any, 'no switches: nothing to do');
  Assert.IsTrue(ParseQuickStartArgs(['-NSHighResolutionCapable', 'x.csv'], nil, Q, Problem), 'not ours: ignored');
  Assert.IsFalse(Q.Any);
end;

procedure TQuickStartTests.LogMeansScanAndConnect;
var
  Q: TQuickStart;
  Problem: string;
begin
  Assert.IsTrue(ParseQuickStartArgs(['/log', '/fullscreen'], nil, Q, Problem));
  Assert.IsTrue(Q.Log and Q.Scan and Q.Connect and Q.FullScreen);
  Assert.IsTrue(ParseQuickStartArgs(['-retry'], nil, Q, Problem));
  Assert.IsFalse(Q.Retry, 'retry without connecting means nothing');
end;

procedure TQuickStartTests.ValuesWithSpaces;
var
  Q: TQuickStart;
  Problem: string;
begin
  // Windows hands a quoted value over as one parameter, without the quotes.
  Assert.IsTrue(ParseQuickStartArgs(['-list', 'Basic engine', '-dashboard', 'Fuel trims', '-scan', '-chart'], nil, Q,
    Problem), Problem);
  Assert.AreEqual('Basic engine', Q.List);
  Assert.AreEqual('Fuel trims', Q.Dashboard);
  Assert.IsTrue(Q.Scan and Q.Connect and Q.Chart);
end;

procedure TQuickStartTests.QuickPicksAKnownOne;
var
  Q: TQuickStart;
  Problem: string;
begin
  Assert.IsTrue(ParseQuickStartArgs(['-quick', 'drag STRIP', '-port', 'COM3'], DefaultQuickStarts, Q, Problem), Problem);
  Assert.AreEqual('Drag strip', Q.Name);
  Assert.AreEqual('Acceleration', Q.List);
  Assert.AreEqual('COM3', Q.Port, 'switches add to it');
  Assert.IsTrue(Q.Log and Q.Scan and Q.Connect and Q.FullScreen and Q.Retry);
end;

procedure TQuickStartTests.UnknownQuickOrMissingValueIsReported;
var
  Q: TQuickStart;
  Problem: string;
begin
  Assert.IsFalse(ParseQuickStartArgs(['-quick', 'Nope'], DefaultQuickStarts, Q, Problem));
  Assert.Contains(Problem, 'Nope');
  Assert.IsFalse(ParseQuickStartArgs(['-list'], nil, Q, Problem));
  Assert.Contains(Problem, 'needs a value');
  Assert.IsFalse(ParseQuickStartArgs(['-list', '-scan'], nil, Q, Problem), 'a switch is not a value');
  Assert.IsFalse(ParseQuickStartArgs(['-adapter', 'obdlink'], nil, Q, Problem));
  Assert.Contains(Problem, 'avt or elm327');
  Assert.IsTrue(ParseQuickStartArgs(['-adapter', 'ELM327', '-port', 'COM4'], nil, Q, Problem), Problem);
  Assert.AreEqual('elm327', Q.Adapter);
end;

procedure TQuickStartTests.ArgumentsParseBack;
var
  A, B: TQuickStart;
  Args: TArray<string>;
  Problem, S: string;
  Quoted: Boolean;
  Part: string;
  C: Char;
begin
  A := DefaultQuickStarts[0];
  A.Dashboard := 'Fuel trims';
  A.Port := 'COM9';
  A.Adapter := 'elm327';
  A.Chart := True;
  // Split like Windows does: spaces outside quotes; quotes dropped.
  Args := nil;
  Part := '';
  Quoted := False;
  S := A.Arguments + ' ';
  for C in S do
    if C = '"' then
      Quoted := not Quoted
    else if (C = ' ') and not Quoted then
    begin
      if Part <> '' then
        Args := Args + [Part];
      Part := '';
    end
    else
      Part := Part + C;
  Assert.IsTrue(ParseQuickStartArgs(Args, nil, B, Problem), Problem);
  Assert.AreEqual(A.Port, B.Port);
  Assert.AreEqual('elm327', B.Adapter);
  Assert.AreEqual(A.List, B.List);
  Assert.AreEqual(A.Dashboard, B.Dashboard);
  Assert.IsTrue((A.Connect = B.Connect) and (A.Scan = B.Scan) and (A.Log = B.Log) and (A.FullScreen = B.FullScreen) and
    (A.Chart = B.Chart) and (A.Retry = B.Retry), A.Arguments);
end;

procedure TQuickStartTests.JsonRoundTrip;
var
  A: TQuickStarts;
  B: TQuickStarts;
  J: TJSONArray;
begin
  A := DefaultQuickStarts;
  A[0].Adapter := 'elm327';
  J := QuickStartsToJson(A);
  try
    B := QuickStartsFromJson(J);
  finally
    J.Free;
  end;
  Assert.AreEqual(1, Integer(Length(B)));
  Assert.AreEqual(A[0].Name, B[0].Name);
  Assert.AreEqual(A[0].List, B[0].List);
  Assert.IsTrue(B[0].Log and B[0].FullScreen and B[0].Retry);
  Assert.AreEqual('elm327', B[0].Adapter);
  Assert.AreEqual(0, IndexOfQuickStart(B, 'DRAG strip'));
end;

initialization
  TDUnitX.RegisterTestFixture(TQuickStartTests);
  TDUnitX.RegisterTestFixture(THexTests);
  TDUnitX.RegisterTestFixture(TAvtFramingTests);
  TDUnitX.RegisterTestFixture(TClass2Tests);
  TDUnitX.RegisterTestFixture(TFormulaTests);
  TDUnitX.RegisterTestFixture(TPidCatalogTests);
  TDUnitX.RegisterTestFixture(TDpidPlannerTests);

end.
