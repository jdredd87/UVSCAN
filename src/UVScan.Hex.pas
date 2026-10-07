unit UVScan.Hex;

{ Byte/hex helpers. Protocol data is always TBytes - never string. }

interface

uses
  System.SysUtils;

function HexToBytes(const Hex: string): TBytes;
function BytesToHex(const Bytes: TBytes; const Separator: string = ' '): string;
function BytesOf(const Values: array of Byte): TBytes;
function ConcatBytes(const A, B: TBytes): TBytes;
function SameBytes(const A, B: TBytes): Boolean;

implementation

function HexToBytes(const Hex: string): TBytes;
var
  Digits: string;
  C: Char;
  I: Integer;
begin
  Digits := '';
  for C in Hex do
    if CharInSet(C, ['0'..'9', 'A'..'F', 'a'..'f']) then
      Digits := Digits + C
    else if not CharInSet(C, [' ', #9, #13, #10, '-', ':', ',']) then
      raise EConvertError.CreateFmt('Invalid hex character "%s"', [C]);
  if Odd(Length(Digits)) then
    raise EConvertError.Create('Hex string has an odd number of digits');
  SetLength(Result, Length(Digits) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(Digits, I * 2 + 1, 2));
end;

function BytesToHex(const Bytes: TBytes; const Separator: string): string;
var
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create(Length(Bytes) * 3);
  try
    for I := 0 to High(Bytes) do
    begin
      if I > 0 then
        SB.Append(Separator);
      SB.Append(IntToHex(Bytes[I], 2));
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function BytesOf(const Values: array of Byte): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do
    Result[I] := Values[I];
end;

function ConcatBytes(const A, B: TBytes): TBytes;
begin
  SetLength(Result, Length(A) + Length(B));
  if Length(A) > 0 then
    Move(A[0], Result[0], Length(A));
  if Length(B) > 0 then
    Move(B[0], Result[Length(A)], Length(B));
end;

function SameBytes(const A, B: TBytes): Boolean;
begin
  Result := (Length(A) = Length(B)) and
    ((Length(A) = 0) or CompareMem(@A[0], @B[0], Length(A)));
end;

end.
