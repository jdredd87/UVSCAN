unit UVScan.Dpid;

{ Packs vehicle PIDs into GM dynamic PIDs (DPIDs).

  Each DPID carries 6 data bytes (positions 1..6). DPIDs are numbered from
  $FE downwards; UVSCAN uses at most 8 ($FE..$F7), i.e. 48 bytes. PIDs are
  placed largest-first into the first DPID with room (first-fit decreasing),
  which never splits a PID across DPIDs.

  The plan lists exactly the DPIDs that hold data. Legacy UVSCAN could end
  up requesting an extra, never-defined DPID when the last one was exactly
  full; this planner cannot. }

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults, UVScan.Class2;

type
  TDpidSlot = record
    Item: Integer;      // caller's index of the PID
    Pid: Word;
    Position: Byte;     // 1-based byte position inside the DPID data
    Size: Byte;
  end;

  TDpidDef = record
    Id: Byte;
    Used: Integer;
    Slots: TArray<TDpidSlot>;
  end;

  TDpidRequest = record
    Item: Integer;
    Pid: Word;
    Size: Byte;
  end;

  EDpidPlanError = class(Exception);

  TDpidPlan = record
    Dpids: TArray<TDpidDef>;
    function TotalBytes: Integer;
    function IndexOfDpid(Id: Byte): Integer;
    { $2A requests at the given speed nibble. Up to 4 DPIDs are put in both
      PCM schedule slots (twice the update rate); 5-8 DPIDs use slot 1 for the
      first four and slot 2 for the rest. }
    function StreamRequests(Speed: Byte): TArray<TBytes>;
  end;

function PlanDpids(const Requests: TArray<TDpidRequest>): TDpidPlan;

implementation

function PlanDpids(const Requests: TArray<TDpidRequest>): TDpidPlan;
var
  Sorted: TList<TDpidRequest>;
  Dpids: TList<TDpidDef>;
  R: TDpidRequest;
  D: TDpidDef;
  Slot: TDpidSlot;
  I, Total: Integer;
  Placed: Boolean;
begin
  Total := 0;
  for R in Requests do
  begin
    if not (R.Size in [1..4]) then
      raise EDpidPlanError.CreateFmt('PID $%.4x has unsupported size %d', [R.Pid, R.Size]);
    Inc(Total, R.Size);
  end;
  if Total > MaxDpids * DpidDataBytes then
    raise EDpidPlanError.CreateFmt('Selected PIDs need %d bytes; the limit is %d', [Total, MaxDpids * DpidDataBytes]);

  Sorted := TList<TDpidRequest>.Create;
  Dpids := TList<TDpidDef>.Create;
  try
    // Largest first; ties keep the caller's order (Item ascending).
    Sorted.AddRange(Requests);
    Sorted.Sort(TComparer<TDpidRequest>.Construct(
      function(const A, B: TDpidRequest): Integer
      begin
        Result := B.Size - A.Size;
        if Result = 0 then
          Result := A.Item - B.Item;
      end));

    for R in Sorted do
    begin
      Placed := False;
      for I := 0 to Dpids.Count - 1 do
        if Dpids[I].Used + R.Size <= DpidDataBytes then
        begin
          D := Dpids[I];
          Slot.Item := R.Item;
          Slot.Pid := R.Pid;
          Slot.Size := R.Size;
          Slot.Position := D.Used + 1;
          D.Slots := D.Slots + [Slot];
          Inc(D.Used, R.Size);
          Dpids[I] := D;
          Placed := True;
          Break;
        end;
      if not Placed then
      begin
        if Dpids.Count = MaxDpids then
          raise EDpidPlanError.Create('Selected PIDs do not fit into 8 DPIDs');
        D := Default(TDpidDef);
        D.Id := FirstDpid - Dpids.Count;
        Slot.Item := R.Item;
        Slot.Pid := R.Pid;
        Slot.Size := R.Size;
        Slot.Position := 1;
        D.Slots := [Slot];
        D.Used := R.Size;
        Dpids.Add(D);
      end;
    end;
    Result.Dpids := Dpids.ToArray;
  finally
    Sorted.Free;
    Dpids.Free;
  end;
end;

{ TDpidPlan }

function TDpidPlan.TotalBytes: Integer;
var
  D: TDpidDef;
begin
  Result := 0;
  for D in Dpids do
    Inc(Result, D.Used);
end;

function TDpidPlan.IndexOfDpid(Id: Byte): Integer;
begin
  for Result := 0 to High(Dpids) do
    if Dpids[Result].Id = Id then
      Exit;
  Result := -1;
end;

function TDpidPlan.StreamRequests(Speed: Byte): TArray<TBytes>;
var
  I, Start, N: Integer;
  Ids: TArray<Byte>;
  Slot: Byte;
begin
  Result := nil;
  Start := 0;
  Slot := StreamSlot1;
  if (Length(Dpids) > 0) and (Length(Dpids) <= DpidsPerRequest) then
  begin
    SetLength(Ids, Length(Dpids));
    for I := 0 to High(Dpids) do
      Ids[I] := Dpids[I].Id;
    SetLength(Result, 2);
    Result[0] := RequestDpidsRequest(StreamSlot1 or Speed, Ids);
    Result[1] := RequestDpidsRequest(StreamSlot2 or Speed, Ids);
    Exit;
  end;
  while Start < Length(Dpids) do
  begin
    N := Length(Dpids) - Start;
    if N > DpidsPerRequest then
      N := DpidsPerRequest;
    SetLength(Ids, N);
    for I := 0 to N - 1 do
      Ids[I] := Dpids[Start + I].Id;
    Result := Result + [RequestDpidsRequest(Slot or Speed, Ids)];
    Slot := StreamSlot2;
    Inc(Start, N);
  end;
end;

end.
