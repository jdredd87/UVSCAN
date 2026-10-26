unit UVScan.Tests.LiveServer;

(* The live view's web server: the page, the data last published, the
  addresses watching, and what it answers to anything else. *)

interface

uses
  System.SysUtils, System.Classes, DUnitX.TestFramework, UVScan.LiveServer;

type
  [TestFixture]
  TLiveServerTests = class
  private
    FServer: TLiveServer;
    function Get(const Request: string): string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure ParsesRequestLines;
    [Test] procedure ServesThePage;
    [Test] procedure ServesTheLatestData;
    [Test] procedure AnswersTheRest;
    [Test] procedure NextPortWhenTaken;
    [Test] procedure ThisDevicesAddress;
    [Test] procedure ReadsQueries;
    [Test] procedure ChartFirstAllThenWhatIsNew;
    [Test] procedure ServesTheChart;
  end;

implementation

uses
  System.Math, System.JSON, System.RegularExpressions, UVScan.Serial;

procedure TLiveServerTests.Setup;
begin
  FServer := TLiveServer.Create(0);
end;

procedure TLiveServerTests.TearDown;
begin
  FreeAndNil(FServer);
end;

{ The whole answer to Request (sent as it is), read until the server closes. }
function TLiveServerTests.Get(const Request: string): string;
var
  Port: ISerialPort;
  Buf: array[0..4095] of Byte;
  Got: TBytes;
  N, L: Integer;
begin
  Port := TTcpSerialPort.Create('127.0.0.1', FServer.Port);
  Port.Open;
  Port.Write(TEncoding.ASCII.GetBytes(Request));
  try
    repeat
      N := Port.Read(Buf, SizeOf(Buf), 2000);
      if N > 0 then
      begin
        L := Length(Got);
        SetLength(Got, L + N);
        Move(Buf[0], Got[L], N);
      end;
    until N <= 0;
  except
    on ESerialError do
      ; // closed: the whole answer is in
  end;
  Result := TEncoding.UTF8.GetString(Got);
end;

procedure TLiveServerTests.ParsesRequestLines;
var
  M, P: string;
begin
  Assert.IsTrue(ParseRequestLine('GET /live.json?t=5 HTTP/1.1', M, P));
  Assert.AreEqual('GET', M);
  Assert.AreEqual('/live.json', P);
  Assert.IsTrue(ParseRequestLine('head / HTTP/1.0', M, P));
  Assert.AreEqual('HEAD', M);
  Assert.AreEqual('/', P);
  Assert.IsFalse(ParseRequestLine('GET /', M, P), 'no version');
  Assert.IsFalse(ParseRequestLine('hello there friend', M, P));
  Assert.IsFalse(ParseRequestLine('', M, P));
end;

procedure TLiveServerTests.ServesThePage;
var
  S: string;
begin
  S := Get('GET / HTTP/1.1'#13#10'Host: x'#13#10#13#10);
  Assert.StartsWith('HTTP/1.1 200 OK'#13#10, S);
  Assert.Contains(S, 'Content-Type: text/html; charset=utf-8');
  Assert.Contains(S, '<title>UVScan live</title>');
  Assert.Contains(S, 'live.json');
  Assert.EndsWith('</html>', S);
end;

procedure TLiveServerTests.ServesTheLatestData;
var
  S: string;
begin
  Assert.AreEqual(0, Length(FServer.Viewers));
  FServer.Publish('{"state":"Connected"}');
  FServer.Publish('{"state":"Scanning","rpm":"812"}');
  S := Get('GET /live.json HTTP/1.1'#13#10'Host: x'#13#10#13#10);
  Assert.StartsWith('HTTP/1.1 200 OK'#13#10, S);
  Assert.Contains(S, 'Content-Type: application/json');
  Assert.Contains(S, 'Cache-Control: no-store');
  Assert.EndsWith(#13#10#13#10'{"state":"Scanning","rpm":"812"}', S);
  Assert.AreEqual(1, Length(FServer.Viewers));
  Assert.AreEqual('127.0.0.1', FServer.Viewers[0]);
end;

procedure TLiveServerTests.AnswersTheRest;
var
  S: string;
begin
  Assert.StartsWith('HTTP/1.1 404 ', Get('GET /settings.json HTTP/1.1'#13#10#13#10));
  Assert.StartsWith('HTTP/1.1 405 ', Get('POST /live.json HTTP/1.1'#13#10'Content-Length: 0'#13#10#13#10));
  Assert.StartsWith('HTTP/1.1 400 ', Get('nonsense'#13#10#13#10));
  S := Get('HEAD / HTTP/1.1'#13#10#13#10);
  Assert.StartsWith('HTTP/1.1 200 OK', S);
  Assert.EndsWith(#13#10#13#10, S, 'no body');
  Assert.AreEqual(0, Length(FServer.Viewers), 'only the data counts as watching');
end;

procedure TLiveServerTests.NextPortWhenTaken;
var
  Other: TLiveServer;
begin
  Other := TLiveServer.Create(FServer.Port, 5);
  try
    Assert.AreNotEqual(Integer(FServer.Port), Integer(Other.Port));
    Assert.IsTrue((Other.Port > FServer.Port) and (Other.Port < FServer.Port + 5));
  finally
    Other.Free;
  end;
end;

procedure TLiveServerTests.ThisDevicesAddress;
var
  A: string;
begin
  A := LocalNetworkAddress; // '' on a PC with no network
  Assert.IsTrue((A = '') or TRegEx.IsMatch(A, '^\d{1,3}(\.\d{1,3}){3}$'), A);
  Assert.IsFalse(A.StartsWith('127.'), A);
end;

procedure TLiveServerTests.ReadsQueries;
var
  M, P, Q: string;
begin
  Assert.IsTrue(ParseRequestLine('GET /chart.json?session=2&since=12.5 HTTP/1.1', M, P, Q));
  Assert.AreEqual('/chart.json', P);
  Assert.AreEqual('session=2&since=12.5', Q);
  Assert.AreEqual('2', QueryParam(Q, 'session'));
  Assert.AreEqual('12.5', QueryParam(Q, 'since'));
  Assert.AreEqual('', QueryParam(Q, 'back'));
  Assert.AreEqual('', QueryParam('', 'since'));
end;

procedure TLiveServerTests.ChartFirstAllThenWhatIsNew;
var
  C: TLiveChart;
  J: TJSONObject;
  S: Integer;
begin
  C := TLiveChart.Create;
  try
    C.Start(['RPM', 'TCC'], ['RPM', ''], [False, True]);
    S := C.Session;
    C.Add(1, [800, 0]);
    C.Add(2, [812.5, NaN]);
    C.AddMark(2, 1);
    C.Add(3, [830, 1]);
    J := TJSONObject.ParseJSONValue(C.Json(-1, NaN, 60)) as TJSONObject;
    try
      Assert.IsTrue(J.GetValue<Boolean>('full'));
      Assert.AreEqual('RPM', J.GetValue<string>('names[0]'));
      Assert.IsTrue(J.GetValue<Boolean>('switch[1]'));
      Assert.AreEqual(3, J.GetValue<TJSONArray>('t').Count);
      Assert.AreEqual(812.5, J.GetValue<Double>('v[1][0]'), 0.001);
      Assert.IsTrue(J.GetValue<TJSONArray>('v[1]').Items[1] is TJSONNull, 'no data: null');
      Assert.AreEqual(1, J.GetValue<Integer>('marks[0][1]'));
    finally
      J.Free;
    end;
    J := TJSONObject.ParseJSONValue(C.Json(S, 2, 60)) as TJSONObject;
    try
      Assert.IsFalse(J.GetValue<Boolean>('full'));
      Assert.IsNull(J.GetValue('names'));
      Assert.AreEqual(1, J.GetValue<TJSONArray>('t').Count);
      Assert.AreEqual(3.0, J.GetValue<Double>('t[0]'), 0.0001);
    finally
      J.Free;
    end;
    J := TJSONObject.ParseJSONValue(C.Json(S, NaN, 1.5)) as TJSONObject;
    try
      Assert.AreEqual(2, J.GetValue<TJSONArray>('t').Count, 'the last 1.5 s');
    finally
      J.Free;
    end;
    C.Start(['ECT'], ['C'], [False]); // a new scan: old browsers get all again
    J := TJSONObject.ParseJSONValue(C.Json(S, 3, 60)) as TJSONObject;
    try
      Assert.IsTrue(J.GetValue<Boolean>('full'));
      Assert.AreEqual('ECT', J.GetValue<string>('names[0]'));
      Assert.AreEqual(0, J.GetValue<TJSONArray>('t').Count);
    finally
      J.Free;
    end;
  finally
    C.Free;
  end;
end;

procedure TLiveServerTests.ServesTheChart;
var
  S: string;
begin
  FServer.Chart.Start(['RPM'], ['RPM'], [False]);
  FServer.Chart.Add(1.5, [900]);
  S := Get('GET /chart.json?back=60 HTTP/1.1'#13#10#13#10);
  Assert.StartsWith('HTTP/1.1 200 OK', S);
  Assert.Contains(S, '"names":["RPM"]');
  Assert.Contains(S, '"t":[1.500],"v":[[900]]');
  Assert.AreEqual(1, Length(FServer.Viewers));
end;

initialization
  TDUnitX.RegisterTestFixture(TLiveServerTests);

end.
