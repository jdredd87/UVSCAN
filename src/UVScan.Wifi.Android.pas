unit UVScan.Wifi.Android;

{ A Wi-Fi ELM327 makes a Wi-Fi network of its own (192.168.0.10), with no
  internet. With mobile data on, Android keeps mobile data as the network
  apps use, so a connection to the adapter would go out over mobile data and
  get nowhere. While UVScan has a connection open to an address on the
  Wi-Fi's own subnet, it uses the Wi-Fi network for its connections instead
  (ConnectivityManager.bindProcessToNetwork; needs ACCESS_NETWORK_STATE). }

interface

{ Before connecting to Host: when Host is an IPv4 address on the Wi-Fi
  network's subnet and the network apps use now is another one, use the
  Wi-Fi network for this app's connections. True when it did: call
  ReleaseWifi when that connection closes. }
function UseWifiFor(const Host: string): Boolean;
procedure ReleaseWifi;

implementation

uses
  System.SysUtils, System.SyncObjs, Androidapi.JNI, Androidapi.JNIBridge, Androidapi.Helpers, Androidapi.JNI.Net,
  Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.JavaTypes, Androidapi.JNI.Java.Net, Androidapi.Log;

var
  Users: Integer; // open connections that asked for the Wi-Fi

function ParseIPv4(const Host: string; out Address: Cardinal): Boolean;
var
  Parts: TArray<string>;
  I, B: Integer;
begin
  Address := 0;
  Parts := Host.Split(['.']);
  if Length(Parts) <> 4 then
    Exit(False);
  for I := 0 to 3 do
  begin
    if not TryStrToInt(Parts[I], B) or (B < 0) or (B > 255) then
      Exit(False);
    Address := (Address shl 8) or Cardinal(B);
  end;
  Result := True;
end;

function Connectivity: JConnectivityManager;
begin
  Result := TJConnectivityManager.Wrap(TAndroidHelper.Context.getSystemService(
    TJContext.JavaClass.CONNECTIVITY_SERVICE));
end;

function IsWifi(CM: JConnectivityManager; N: JNetwork): Boolean;
var
  Caps: JNetworkCapabilities;
begin
  if N = nil then
    Exit(False);
  Caps := CM.getNetworkCapabilities(N);
  Result := (Caps <> nil) and Caps.hasTransport(TJNetworkCapabilities.JavaClass.TRANSPORT_WIFI);
end;

{ True when Address is on the subnet of one of N's IPv4 addresses. }
function OnSubnet(CM: JConnectivityManager; N: JNetwork; Address: Cardinal): Boolean;
var
  Props: JLinkProperties;
  List: JList;
  Link: JLinkAddress;
  Bytes: TJavaArray<Byte>;
  I, Bits: Integer;
  Mine, Mask: Cardinal;
begin
  Result := False;
  Props := CM.getLinkProperties(N);
  if Props = nil then
    Exit;
  List := Props.getLinkAddresses;
  for I := 0 to List.size - 1 do
  begin
    Link := TJLinkAddress.Wrap((List.get(I) as ILocalObject).GetObjectID);
    Bytes := Link.getAddress.getAddress;
    if (Bytes = nil) or (Bytes.Length <> 4) then
      Continue; // IPv6
    Mine := (Cardinal(Bytes.Items[0]) shl 24) or (Cardinal(Bytes.Items[1]) shl 16) or
      (Cardinal(Bytes.Items[2]) shl 8) or Cardinal(Bytes.Items[3]);
    Bits := Link.getPrefixLength;
    if Bits <= 0 then
      Mask := 0
    else
      Mask := Cardinal($FFFFFFFF) shl (32 - Bits);
    if (Mine and Mask) = (Address and Mask) then
      Exit(True);
  end;
end;

procedure Say(const Text: string);
var
  M: TMarshaller;
begin
  LOGI(M.AsAnsi('UVScan: ' + Text).ToPointer);
end;

function UseWifiFor(const Host: string): Boolean;
var
  CM: JConnectivityManager;
  All: TJavaObjectArray<JNetwork>;
  Address: Cardinal;
  I: Integer;
begin
  Result := False;
  if not ParseIPv4(Host, Address) then
    Exit;
  try
    CM := Connectivity;
    if IsWifi(CM, CM.getActiveNetwork) then
      Exit; // Android uses the Wi-Fi already
    All := CM.getAllNetworks;
    for I := 0 to All.Length - 1 do
      if IsWifi(CM, All.Items[I]) and OnSubnet(CM, All.Items[I], Address) then
      begin
        Result := CM.bindProcessToNetwork(All.Items[I]);
        if Result then
        begin
          TInterlocked.Increment(Users);
          Say('connecting to ' + Host + ' over the Wi-Fi (Android uses another network for apps)');
        end;
        Exit;
      end;
  except
    on E: Exception do
      Say('could not choose the Wi-Fi network: ' + E.Message); // connect as Android routes it
  end;
end;

procedure ReleaseWifi;
begin
  if TInterlocked.Decrement(Users) > 0 then
    Exit;
  Users := 0;
  try
    Connectivity.bindProcessToNetwork(nil);
    Say('the network choice is Android''s again');
  except
    on E: Exception do
      Say('could not give the network choice back to Android: ' + E.Message);
  end;
end;

end.
