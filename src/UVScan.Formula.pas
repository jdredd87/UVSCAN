unit UVScan.Formula;

{ Small expression evaluator for PID formulas (replaces ArtFormula).

  Syntax: numbers, N0..N4 (N0 and N1 = data byte 1, N2..N4 = bytes 2..4),
  %NAME% references to other PIDs' MCI codes, parentheses, unary + -, and
  binary operators with C precedence:
    * /   then  + -   then  << >>   then  < <= > >=   then  = == <> !=
    then  &   then  |
  Comparisons yield 1 or 0. Bitwise operators work on the truncated integer
  value. Division by zero and missing values give NaN. }

interface

uses
  System.SysUtils, System.Math;

type
  EFormulaError = class(Exception);

  TFormulaOp = (foConst, foInput, foVar, foNeg, foAdd, foSub, foMul, foDiv,
    foShl, foShr, foAnd, foOr, foLt, foLe, foGt, foGe, foEq, foNe);

  TFormulaInstr = record
    Op: TFormulaOp;
    Value: Double;   // foConst
    Index: Integer;  // foInput: byte index 0..3; foVar: index into Variables
  end;

  TFormula = class
  private
    FText: string;
    FCode: TArray<TFormulaInstr>;
    FVariables: TArray<string>;
    FUsesInputs: Boolean;
  public
    constructor Create(const Text: string);
    { Inputs: data bytes 1..4 as Inputs[0..3]. VarValues: aligned with Variables. }
    function Evaluate(const Inputs: array of Double; const VarValues: array of Double): Double;
    function IsEmpty: Boolean;
    property Text: string read FText;
    { Upper-case MCI names referenced, without the % signs. }
    property Variables: TArray<string> read FVariables;
    property UsesInputs: Boolean read FUsesInputs;
  end;

implementation

uses
  System.Character, System.Generics.Collections;

type
  TTokenKind = (tkEnd, tkNumber, tkInput, tkVar, tkOp, tkLParen, tkRParen);

  TToken = record
    Kind: TTokenKind;
    Text: string;
    Value: Double;
    Index: Integer;
  end;

  TParser = class
  private
    FSrc: string;
    FPos: Integer;
    FTok: TToken;
    FCode: TList<TFormulaInstr>;
    FVars: TList<string>;
    FUsesInputs: Boolean;
    procedure Next;
    procedure Emit(Op: TFormulaOp; Value: Double = 0; Index: Integer = 0);
    function IsOp(const S: string): Boolean;
    procedure ParseOr;
    procedure ParseAnd;
    procedure ParseEquality;
    procedure ParseRelational;
    procedure ParseShift;
    procedure ParseAdditive;
    procedure ParseMultiplicative;
    procedure ParseUnary;
    procedure ParsePrimary;
    procedure Fail(const Msg: string);
  public
    constructor Create(const Src: string);
    destructor Destroy; override;
    procedure Parse;
  end;

{ TParser }

constructor TParser.Create(const Src: string);
begin
  inherited Create;
  FSrc := Src;
  FPos := 1;
  FCode := TList<TFormulaInstr>.Create;
  FVars := TList<string>.Create;
end;

destructor TParser.Destroy;
begin
  FCode.Free;
  FVars.Free;
  inherited;
end;

procedure TParser.Fail(const Msg: string);
begin
  raise EFormulaError.CreateFmt('%s at position %d in "%s"', [Msg, FPos, FSrc]);
end;

procedure TParser.Emit(Op: TFormulaOp; Value: Double; Index: Integer);
var
  I: TFormulaInstr;
begin
  I.Op := Op;
  I.Value := Value;
  I.Index := Index;
  FCode.Add(I);
end;

procedure TParser.Next;
const
  TwoCharOps: array[0..6] of string = ('<<', '>>', '<=', '>=', '==', '<>', '!=');
var
  Start: Integer;
  C: Char;
  S, Name: string;
  Fmt: TFormatSettings;
begin
  while (FPos <= Length(FSrc)) and FSrc[FPos].IsWhiteSpace do
    Inc(FPos);
  FTok := Default(TToken);
  if FPos > Length(FSrc) then
  begin
    FTok.Kind := tkEnd;
    Exit;
  end;
  C := FSrc[FPos];
  Start := FPos;

  if C.IsDigit or (C = '.') then
  begin
    while (FPos <= Length(FSrc)) and (FSrc[FPos].IsDigit or (FSrc[FPos] = '.')) do
      Inc(FPos);
    S := Copy(FSrc, Start, FPos - Start);
    Fmt := TFormatSettings.Invariant;
    if not TryStrToFloat(S, FTok.Value, Fmt) then
      Fail('Bad number "' + S + '"');
    FTok.Kind := tkNumber;
    Exit;
  end;

  if CharInSet(C, ['N', 'n']) and (FPos < Length(FSrc)) and CharInSet(FSrc[FPos + 1], ['0'..'4'])
    and ((FPos + 2 > Length(FSrc)) or not FSrc[FPos + 2].IsLetterOrDigit) then
  begin
    FTok.Kind := tkInput;
    FTok.Index := Ord(FSrc[FPos + 1]) - Ord('0');
    if FTok.Index > 0 then
      Dec(FTok.Index); // N0 and N1 are both byte 1
    Inc(FPos, 2);
    Exit;
  end;

  if C = '%' then
  begin
    Inc(FPos);
    while (FPos <= Length(FSrc)) and (FSrc[FPos] <> '%') do
      Inc(FPos);
    if FPos > Length(FSrc) then
      Fail('Unterminated %NAME% reference');
    Name := UpperCase(Trim(Copy(FSrc, Start + 1, FPos - Start - 1)));
    Inc(FPos);
    if Name = '' then
      Fail('Empty %% reference');
    FTok.Kind := tkVar;
    FTok.Text := Name;
    Exit;
  end;

  if C = '(' then
  begin
    FTok.Kind := tkLParen;
    Inc(FPos);
    Exit;
  end;
  if C = ')' then
  begin
    FTok.Kind := tkRParen;
    Inc(FPos);
    Exit;
  end;

  S := Copy(FSrc, FPos, 2);
  for Name in TwoCharOps do
    if S = Name then
    begin
      FTok.Kind := tkOp;
      FTok.Text := S;
      Inc(FPos, 2);
      Exit;
    end;
  if CharInSet(C, ['+', '-', '*', '/', '&', '|', '<', '>', '=']) then
  begin
    FTok.Kind := tkOp;
    FTok.Text := C;
    Inc(FPos);
    Exit;
  end;
  Fail('Unexpected character "' + C + '"');
end;

function TParser.IsOp(const S: string): Boolean;
begin
  Result := (FTok.Kind = tkOp) and (FTok.Text = S);
end;

procedure TParser.Parse;
begin
  Next;
  ParseOr;
  if FTok.Kind <> tkEnd then
    Fail('Unexpected input');
end;

procedure TParser.ParseOr;
begin
  ParseAnd;
  while IsOp('|') do
  begin
    Next;
    ParseAnd;
    Emit(foOr);
  end;
end;

procedure TParser.ParseAnd;
begin
  ParseEquality;
  while IsOp('&') do
  begin
    Next;
    ParseEquality;
    Emit(foAnd);
  end;
end;

procedure TParser.ParseEquality;
var
  Op: TFormulaOp;
begin
  ParseRelational;
  while IsOp('=') or IsOp('==') or IsOp('<>') or IsOp('!=') do
  begin
    if IsOp('=') or IsOp('==') then
      Op := foEq
    else
      Op := foNe;
    Next;
    ParseRelational;
    Emit(Op);
  end;
end;

procedure TParser.ParseRelational;
var
  Op: TFormulaOp;
begin
  ParseShift;
  while IsOp('<') or IsOp('<=') or IsOp('>') or IsOp('>=') do
  begin
    if IsOp('<') then
      Op := foLt
    else if IsOp('<=') then
      Op := foLe
    else if IsOp('>') then
      Op := foGt
    else
      Op := foGe;
    Next;
    ParseShift;
    Emit(Op);
  end;
end;

procedure TParser.ParseShift;
var
  Op: TFormulaOp;
begin
  ParseAdditive;
  while IsOp('<<') or IsOp('>>') do
  begin
    if IsOp('<<') then
      Op := foShl
    else
      Op := foShr;
    Next;
    ParseAdditive;
    Emit(Op);
  end;
end;

procedure TParser.ParseAdditive;
var
  Op: TFormulaOp;
begin
  ParseMultiplicative;
  while IsOp('+') or IsOp('-') do
  begin
    if IsOp('+') then
      Op := foAdd
    else
      Op := foSub;
    Next;
    ParseMultiplicative;
    Emit(Op);
  end;
end;

procedure TParser.ParseMultiplicative;
var
  Op: TFormulaOp;
begin
  ParseUnary;
  while IsOp('*') or IsOp('/') do
  begin
    if IsOp('*') then
      Op := foMul
    else
      Op := foDiv;
    Next;
    ParseUnary;
    Emit(Op);
  end;
end;

procedure TParser.ParseUnary;
begin
  if IsOp('-') then
  begin
    Next;
    ParseUnary;
    Emit(foNeg);
  end
  else if IsOp('+') then
  begin
    Next;
    ParseUnary;
  end
  else
    ParsePrimary;
end;

procedure TParser.ParsePrimary;
var
  Idx: Integer;
begin
  case FTok.Kind of
    tkNumber:
      begin
        Emit(foConst, FTok.Value);
        Next;
      end;
    tkInput:
      begin
        FUsesInputs := True;
        Emit(foInput, 0, FTok.Index);
        Next;
      end;
    tkVar:
      begin
        Idx := FVars.IndexOf(FTok.Text);
        if Idx < 0 then
          Idx := FVars.Add(FTok.Text);
        Emit(foVar, 0, Idx);
        Next;
      end;
    tkLParen:
      begin
        Next;
        ParseOr;
        if FTok.Kind <> tkRParen then
          Fail('Missing ")"');
        Next;
      end;
  else
    Fail('Expected a value');
  end;
end;

{ TFormula }

constructor TFormula.Create(const Text: string);
var
  P: TParser;
begin
  inherited Create;
  FText := Trim(Text);
  if FText = '' then
    Exit;
  P := TParser.Create(FText);
  try
    P.Parse;
    FCode := P.FCode.ToArray;
    FVariables := P.FVars.ToArray;
    FUsesInputs := P.FUsesInputs;
  finally
    P.Free;
  end;
end;

function TFormula.IsEmpty: Boolean;
begin
  Result := Length(FCode) = 0;
end;

function ToInt(const V: Double): Int64; inline;
begin
  Result := Trunc(V);
end;

function TFormula.Evaluate(const Inputs: array of Double; const VarValues: array of Double): Double;
var
  Stack: array[0..63] of Double;
  SP: Integer;
  Instr: TFormulaInstr;
  A, B, R: Double;
begin
  if IsEmpty then
    Exit(NaN);
  SP := -1;
  for Instr in FCode do
  begin
    case Instr.Op of
      foConst:
        R := Instr.Value;
      foInput:
        if Instr.Index <= High(Inputs) then
          R := Inputs[Instr.Index]
        else
          R := NaN;
      foVar:
        if Instr.Index <= High(VarValues) then
          R := VarValues[Instr.Index]
        else
          R := NaN;
      foNeg:
        begin
          Stack[SP] := -Stack[SP];
          Continue;
        end;
    else
      begin
        B := Stack[SP];
        Dec(SP);
        A := Stack[SP];
        Dec(SP);
        if IsNan(A) or IsNan(B) then
          R := NaN
        else
          case Instr.Op of
            foAdd: R := A + B;
            foSub: R := A - B;
            foMul: R := A * B;
            foDiv: if B = 0 then R := NaN else R := A / B;
            foShl: R := ToInt(A) shl ToInt(B);
            foShr: R := ToInt(A) shr ToInt(B);
            foAnd: R := ToInt(A) and ToInt(B);
            foOr:  R := ToInt(A) or ToInt(B);
            foLt:  R := Ord(A < B);
            foLe:  R := Ord(A <= B);
            foGt:  R := Ord(A > B);
            foGe:  R := Ord(A >= B);
            foEq:  R := Ord(SameValue(A, B));
            foNe:  R := Ord(not SameValue(A, B));
          else
            R := NaN;
          end;
      end;
    end;
    Inc(SP);
    if SP > High(Stack) then
      raise EFormulaError.Create('Formula too complex: ' + FText);
    Stack[SP] := R;
  end;
  Result := Stack[SP];
end;

end.
