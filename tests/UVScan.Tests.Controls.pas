unit UVScan.Tests.Controls;

{ Real-time controls: command templates, value scaling, validation,
  controls.json, and sending through the engine against the simulator. }

interface

uses
  System.SysUtils, System.JSON, DUnitX.TestFramework,
  UVScan.Controls, UVScan.Hex, UVScan.Class2, UVScan.Defaults, UVScan.JsonFile;

type
  [TestFixture]
  TControlTests = class
  public
    [Test] procedure ExpandsHexAndPlaceholders;
    [Test] procedure RejectsBadCommands;
    [Test] procedure BuildsMessagesWithHeader;
    [Test] procedure ValueScaling;
    [Test] procedure ProblemsAreExplained;
    [Test] procedure JsonRoundTrip;
    [Test] procedure RestoreBuiltIns;
    [Test] procedure BuiltInDefaultsAreValid;
  end;

implementation

function NewControl(Kind: TControlKind; const OnText, OffText: string): TControlDef;
begin
  Result := TControlDef.Create;
  Result.Name := 'Test';
  Result.Kind := Kind;
  Result.OnText := OnText;
  Result.OffText := OffText;
end;

procedure TControlTests.ExpandsHexAndPlaceholders;
begin
  Assert.AreEqual('AE 01 80 80', BytesToHex(ExpandCommand('AE 01 80 80')));
  Assert.AreEqual('AE 01 80 80', BytesToHex(ExpandCommand('  ae,01  80 80 ')));
  Assert.AreEqual('AE 03 2A 00', BytesToHex(ExpandCommand('AE 03 {V} 00', $2A)));
  Assert.AreEqual('AE 03 12 34 00', BytesToHex(ExpandCommand('AE 03 {v16} 00', $1234)));
  Assert.IsTrue(HasValuePlaceholder('AE {V16}'));
  Assert.IsFalse(HasValuePlaceholder('AE 01'));
end;

function Raises(const Text: string; Raw: Int64 = 0): Boolean;
begin
  try
    ExpandCommand(Text, Raw);
    Result := False;
  except
    on EControlError do
      Result := True;
  end;
end;

procedure TControlTests.RejectsBadCommands;
begin
  Assert.IsTrue(Raises('AE 0'));
  Assert.IsTrue(Raises('AE XY'));
  Assert.IsTrue(Raises('AE 0102'), 'one byte per token');
  Assert.IsTrue(Raises('AE {V}', 256));
  Assert.IsTrue(Raises('AE {V16}', 70000));
  Assert.IsFalse(Raises('AE {V16}', 65535));
end;

procedure TControlTests.BuildsMessagesWithHeader;
var
  C: TControlDef;
begin
  C := NewControl(ckToggle, 'AE 01 80 80 00 00 00 00', 'AE 01 00 00 00 00 00 00');
  try
    Assert.AreEqual('6C 10 F1 AE 01 80 80 00 00 00 00', BytesToHex(C.OnMessage));
    Assert.AreEqual('6C 10 F1 AE 01 00 00 00 00 00 00', BytesToHex(C.OffMessage));
    C.Module := $40;
    Assert.AreEqual('6C 40 F1 AE 01 80 80 00 00 00 00', BytesToHex(C.OnMessage));
    Assert.IsTrue(C.HoldsControl);
    C.Kind := ckAction;
    Assert.IsFalse(C.HoldsControl);
    C.OffText := '';
    Assert.AreEqual(0, Integer(Length(C.OffMessage)));
  finally
    C.Free;
  end;
end;

procedure TControlTests.ValueScaling;
var
  C: TControlDef;
begin
  C := NewControl(ckValue, 'AE 03 01 {V} 00 00 00 00', 'AE 03 00 00 00 00 00 00');
  try
    C.MinValue := 500;
    C.MaxValue := 1600;
    C.Step := 25;
    C.Scale := 12.5;
    Assert.AreEqual('', C.Problem);
    Assert.AreEqual(Int64(64), C.RawFor(800));
    Assert.AreEqual('6C 10 F1 AE 03 01 40 00 00 00 00', BytesToHex(C.OnMessage(800)));
    // out-of-range values are clamped to min / max
    Assert.AreEqual('6C 10 F1 AE 03 01 80 00 00 00 00', BytesToHex(C.OnMessage(9999)));
    C.Offset := -40;
    Assert.AreEqual(Int64(4), C.RawFor(10)); // (10 - -40) / 12.5
  finally
    C.Free;
  end;
end;

procedure TControlTests.ProblemsAreExplained;
var
  C: TControlDef;
begin
  C := NewControl(ckToggle, 'AE 01 80 80 00 00 00 00', '');
  try
    Assert.Contains(C.Problem, 'off');
    C.OffText := 'AE 01 00 00 00 00 00 00';
    Assert.AreEqual('', C.Problem);
    C.Name := ' ';
    Assert.Contains(C.Problem, 'name');
    C.Name := 'X';
    C.OnText := 'AE 01 00 00 00 00 00 00 00';
    Assert.Contains(C.Problem, 'Too long');
    C.OnText := 'AE {V}';
    Assert.Contains(C.Problem, 'only for value');
    C.Kind := ckValue;
    C.MinValue := 0;
    C.MaxValue := 1000; // raw 1000 does not fit {V}
    Assert.Contains(C.Problem, 'one byte');
    C.MaxValue := 200;
    Assert.AreEqual('', C.Problem);
    C.OnText := 'AE 03 00';
    Assert.Contains(C.Problem, '{V}');
    C.Kind := ckAction;
    C.OnText := '';
    Assert.Contains(C.Problem, 'command');
  finally
    C.Free;
  end;
end;

procedure TControlTests.JsonRoundTrip;
var
  A, B: TControlList;
  C: TControlDef;
  Root: TJSONObject;
begin
  A := TControlList.Create;
  B := TControlList.Create;
  try
    C := NewControl(ckValue, 'AE 03 01 {V16} 00 00 00', 'AE 03 00 00 00 00 00 00');
    C.Name := 'Idle';
    C.Group := 'Engine';
    C.Module := $10;
    C.MinValue := 500;
    C.MaxValue := 1600;
    C.Step := 25;
    C.Scale := 0.25;
    C.Offset := 10;
    C.Units := 'rpm';
    C.Confirm := 'Sure?';
    C.Notes := 'note';
    C.BuiltIn := True;
    A.Add(C);
    A.Add(NewControl(ckAction, 'AE 02 40 00 00 00 00 00', ''));
    Root := A.ToJson;
    try
      B.LoadFromJsonText(JsonText(Root));
    finally
      Root.Free;
    end;
    Assert.AreEqual(0, B.Warnings.Count);
    Assert.AreEqual(2, B.Count);
    C := B[0];
    Assert.AreEqual('Idle', C.Name);
    Assert.AreEqual('Engine', C.Group);
    Assert.IsTrue(C.Kind = ckValue);
    Assert.AreEqual(Integer($10), Integer(C.Module));
    Assert.AreEqual('AE 03 01 {V16} 00 00 00', C.OnText);
    Assert.AreEqual(1600.0, C.MaxValue, 1E-9);
    Assert.AreEqual(0.25, C.Scale, 1E-9);
    Assert.AreEqual(10.0, C.Offset, 1E-9);
    Assert.AreEqual('rpm', C.Units);
    Assert.AreEqual('Sure?', C.Confirm);
    Assert.IsTrue(C.BuiltIn);
    Assert.IsTrue(B[1].Kind = ckAction);
    Assert.AreEqual('AE 02 40 00 00 00 00 00', B[1].OnText, 'actions are stored as "send"');
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TControlTests.RestoreBuiltIns;
var
  Defaults, Mine: TControlList;
begin
  Defaults := TControlList.Create;
  Mine := TControlList.Create;
  try
    Defaults.LoadFromJsonText('{"controls":[' +
      '{"name":"A","kind":"action","send":"AE 02 40 00 00 00 00 00","builtIn":true},' +
      '{"name":"B","kind":"action","send":"AE 02 80 00 00 00 00 00","builtIn":true},' +
      '{"name":"Example","kind":"action","send":"AE 02 00 00 00 00 00 00"}]}');
    Mine.LoadFromJsonText('{"controls":[{"name":"a","kind":"action","send":"AE 02 01 00 00 00 00 00"}]}');
    Assert.AreEqual(1, Mine.RestoreBuiltIns(Defaults), 'only B: A exists (by name), Example is not built in');
    Assert.AreEqual(2, Mine.Count);
    Assert.AreEqual('AE 02 01 00 00 00 00 00', Mine[0].OnText, 'own version of A kept');
    Assert.AreEqual(0, Mine.RestoreBuiltIns(Defaults));
  finally
    Defaults.Free;
    Mine.Free;
  end;
end;

procedure TControlTests.BuiltInDefaultsAreValid;
var
  L: TControlList;
  I: Integer;
begin
  L := TControlList.Create;
  try
    L.LoadFromJsonText(DefaultControlsJson);
    Assert.AreEqual(0, L.Warnings.Count, L.Warnings.Text);
    Assert.IsTrue(L.Count > 0);
    for I := 0 to L.Count - 1 do
    begin
      Assert.IsTrue(L[I].BuiltIn, L[I].Name);
      Assert.AreEqual('', L[I].Problem, L[I].Name);
    end;
  finally
    L.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TControlTests);

end.
