unit MTSSDKLib_TLB;

// ************************************************************************ //
// WARNING                                                                    
// -------                                                                    
// The types declared in this file were generated from data read from a       
// Type Library. If this type library is explicitly or indirectly (via        
// another type library referring to this type library) re-imported, or the   
// 'Refresh' command of the Type Library Editor activated while editing the   
// Type Library, the contents of this file will be regenerated and all        
// manual modifications will be lost.                                         
// ************************************************************************ //

// $Rev: 8291 $
// File generated on 2/1/2012 1:54:06 AM from Type Library described below.

// ************************************************************************  //
// Type Lib: C:\Users\CPStevenC\Desktop\UVSCAN\MTSSDK.OCX (1)
// LIBID: {21DA5218-0A6C-4240-9486-D6BFD4FA83FC}
// LCID: 0
// Helpfile: 
// HelpString: MTS SDK v1.0
// DepndLst: 
//   (1) v2.0 stdole, (C:\Windows\SysWOW64\stdole2.tlb)
// ************************************************************************ //
// *************************************************************************//
// NOTE:                                                                      
// Items guarded by $IFDEF_LIVE_SERVER_AT_DESIGN_TIME are used by properties  
// which return objects that may need to be explicitly created via a function 
// call prior to any access via the property. These items have been disabled  
// in order to prevent accidental use from within the object inspector. You   
// may enable them by defining LIVE_SERVER_AT_DESIGN_TIME or by selectively   
// removing them from the $IFDEF blocks. However, such items must still be    
// programmatically created via a method of the appropriate CoClass before    
// they can be used.                                                          
{$TYPEDADDRESS OFF} // Unit must be compiled without type-checked pointers. 
{$WARN SYMBOL_PLATFORM OFF}
{$WRITEABLECONST ON}
{$VARPROPSETTER ON}
interface

uses Windows, ActiveX, Classes, Graphics, OleCtrls, OleServer, StdVCL, Variants;
  


// *********************************************************************//
// GUIDS declared in the TypeLibrary. Following prefixes are used:        
//   Type Libraries     : LIBID_xxxx                                      
//   CoClasses          : CLASS_xxxx                                      
//   DISPInterfaces     : DIID_xxxx                                       
//   Non-DISP interfaces: IID_xxxx                                        
// *********************************************************************//
const
  // TypeLibrary Major and minor versions
  MTSSDKLibMajorVersion = 1;
  MTSSDKLibMinorVersion = 0;

  LIBID_MTSSDKLib: TGUID = '{21DA5218-0A6C-4240-9486-D6BFD4FA83FC}';

  DIID__IMTSEvents: TGUID = '{4A8AA6AC-E180-433E-8871-A2F8D2413F03}';
  IID_IMTS: TGUID = '{FCE3DA3F-110C-4781-B751-ABDC039BCF18}';
  CLASS_MTS: TGUID = '{74087A4E-4AF1-4F8C-BACB-3959C212AAD2}';
type

// *********************************************************************//
// Forward declaration of types defined in TypeLibrary                    
// *********************************************************************//
  _IMTSEvents = dispinterface;
  IMTS = interface;
  IMTSDisp = dispinterface;

// *********************************************************************//
// Declaration of CoClasses defined in Type Library                       
// (NOTE: Here we map each CoClass to its Default Interface)              
// *********************************************************************//
  MTS = IMTS;


// *********************************************************************//
// DispIntf:  _IMTSEvents
// Flags:     (4096) Dispatchable
// GUID:      {4A8AA6AC-E180-433E-8871-A2F8D2413F03}
// *********************************************************************//
  _IMTSEvents = dispinterface
    ['{4A8AA6AC-E180-433E-8871-A2F8D2413F03}']
    procedure ConnectionEvent(Result: Integer); dispid 1;
    procedure ConnectionError; dispid 2;
    procedure NewData; dispid 3;
  end;

// *********************************************************************//
// Interface: IMTS
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {FCE3DA3F-110C-4781-B751-ABDC039BCF18}
// *********************************************************************//
  IMTS = interface(IDispatch)
    ['{FCE3DA3F-110C-4781-B751-ABDC039BCF18}']
    function Get_PortCount: Integer; safecall;
    function Get_CurrentPort: Integer; safecall;
    procedure Set_CurrentPort(pVal: Integer); safecall;
    function Get_PortName: WideString; safecall;
    procedure Connect; safecall;
    procedure Disconnect; safecall;
    function Get_InputCount: Integer; safecall;
    function Get_CurrentInput: Integer; safecall;
    procedure Set_CurrentInput(pVal: Integer); safecall;
    function Get_InputName: WideString; safecall;
    function Get_InputUnit: WideString; safecall;
    function Get_InputDeviceName: WideString; safecall;
    function Get_InputDeviceType: Integer; safecall;
    function Get_InputType: Integer; safecall;
    function Get_InputDeviceChannel: Integer; safecall;
    function Get_InputAFRMultiplier: Single; safecall;
    function Get_InputMinValue: Single; safecall;
    function Get_InputMaxValue: Single; safecall;
    function Get_InputMinVolt: Single; safecall;
    function Get_InputMaxVolt: Single; safecall;
    function Get_InputSample: Integer; safecall;
    function Get_InputFunction: Integer; safecall;
    procedure StartData; safecall;
    property PortCount: Integer read Get_PortCount;
    property CurrentPort: Integer read Get_CurrentPort write Set_CurrentPort;
    property PortName: WideString read Get_PortName;
    property InputCount: Integer read Get_InputCount;
    property CurrentInput: Integer read Get_CurrentInput write Set_CurrentInput;
    property InputName: WideString read Get_InputName;
    property InputUnit: WideString read Get_InputUnit;
    property InputDeviceName: WideString read Get_InputDeviceName;
    property InputDeviceType: Integer read Get_InputDeviceType;
    property InputType: Integer read Get_InputType;
    property InputDeviceChannel: Integer read Get_InputDeviceChannel;
    property InputAFRMultiplier: Single read Get_InputAFRMultiplier;
    property InputMinValue: Single read Get_InputMinValue;
    property InputMaxValue: Single read Get_InputMaxValue;
    property InputMinVolt: Single read Get_InputMinVolt;
    property InputMaxVolt: Single read Get_InputMaxVolt;
    property InputSample: Integer read Get_InputSample;
    property InputFunction: Integer read Get_InputFunction;
  end;

// *********************************************************************//
// DispIntf:  IMTSDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {FCE3DA3F-110C-4781-B751-ABDC039BCF18}
// *********************************************************************//
  IMTSDisp = dispinterface
    ['{FCE3DA3F-110C-4781-B751-ABDC039BCF18}']
    property PortCount: Integer readonly dispid 1;
    property CurrentPort: Integer dispid 2;
    property PortName: WideString readonly dispid 3;
    procedure Connect; dispid 4;
    procedure Disconnect; dispid 5;
    property InputCount: Integer readonly dispid 6;
    property CurrentInput: Integer dispid 7;
    property InputName: WideString readonly dispid 8;
    property InputUnit: WideString readonly dispid 9;
    property InputDeviceName: WideString readonly dispid 10;
    property InputDeviceType: Integer readonly dispid 11;
    property InputType: Integer readonly dispid 12;
    property InputDeviceChannel: Integer readonly dispid 13;
    property InputAFRMultiplier: Single readonly dispid 14;
    property InputMinValue: Single readonly dispid 15;
    property InputMaxValue: Single readonly dispid 16;
    property InputMinVolt: Single readonly dispid 17;
    property InputMaxVolt: Single readonly dispid 18;
    property InputSample: Integer readonly dispid 19;
    property InputFunction: Integer readonly dispid 20;
    procedure StartData; dispid 21;
  end;


// *********************************************************************//
// OLE Control Proxy class declaration
// Control Name     : TMTS
// Help String      : MTS SDK v1.0
// Default Interface: IMTS
// Def. Intf. DISP? : No
// Event   Interface: _IMTSEvents
// TypeFlags        : (2) CanCreate
// *********************************************************************//
  TMTSConnectionEvent = procedure(ASender: TObject; Result: Integer) of object;

  TMTS = class(TOleControl)
  private
    FOnConnectionEvent: TMTSConnectionEvent;
    FOnConnectionError: TNotifyEvent;
    FOnNewData: TNotifyEvent;
    FIntf: IMTS;
    function  GetControlInterface: IMTS;
  protected
    procedure CreateControl;
    procedure InitControlData; override;
  public
    procedure Connect;
    procedure Disconnect;
    procedure StartData;
    property  ControlInterface: IMTS read GetControlInterface;
    property  DefaultInterface: IMTS read GetControlInterface;
    property PortCount: Integer index 1 read GetIntegerProp;
    property PortName: WideString index 3 read GetWideStringProp;
    property InputCount: Integer index 6 read GetIntegerProp;
    property InputName: WideString index 8 read GetWideStringProp;
    property InputUnit: WideString index 9 read GetWideStringProp;
    property InputDeviceName: WideString index 10 read GetWideStringProp;
    property InputDeviceType: Integer index 11 read GetIntegerProp;
    property InputType: Integer index 12 read GetIntegerProp;
    property InputDeviceChannel: Integer index 13 read GetIntegerProp;
    property InputAFRMultiplier: Single index 14 read GetSingleProp;
    property InputMinValue: Single index 15 read GetSingleProp;
    property InputMaxValue: Single index 16 read GetSingleProp;
    property InputMinVolt: Single index 17 read GetSingleProp;
    property InputMaxVolt: Single index 18 read GetSingleProp;
    property InputSample: Integer index 19 read GetIntegerProp;
    property InputFunction: Integer index 20 read GetIntegerProp;
  published
    property Anchors;
    property CurrentPort: Integer index 2 read GetIntegerProp write SetIntegerProp stored False;
    property CurrentInput: Integer index 7 read GetIntegerProp write SetIntegerProp stored False;
    property OnConnectionEvent: TMTSConnectionEvent read FOnConnectionEvent write FOnConnectionEvent;
    property OnConnectionError: TNotifyEvent read FOnConnectionError write FOnConnectionError;
    property OnNewData: TNotifyEvent read FOnNewData write FOnNewData;
  end;

procedure Register;

resourcestring
  dtlServerPage = 'Win32';

  dtlOcxPage = 'Win32';

implementation

uses ComObj;

procedure TMTS.InitControlData;
const
  CEventDispIDs: array [0..2] of DWORD = (
    $00000001, $00000002, $00000003);
  CControlData: TControlData2 = (
    ClassID: '{74087A4E-4AF1-4F8C-BACB-3959C212AAD2}';
    EventIID: '{4A8AA6AC-E180-433E-8871-A2F8D2413F03}';
    EventCount: 3;
    EventDispIDs: @CEventDispIDs;
    LicenseKey: nil (*HR:$80004002*);
    Flags: $00000000;
    Version: 401);
begin
  ControlData := @CControlData;
  TControlData2(CControlData).FirstEventOfs := Cardinal(@@FOnConnectionEvent) - Cardinal(Self);
end;

procedure TMTS.CreateControl;

  procedure DoCreate;
  begin
    FIntf := IUnknown(OleObject) as IMTS;
  end;

begin
  if FIntf = nil then DoCreate;
end;

function TMTS.GetControlInterface: IMTS;
begin
  CreateControl;
  Result := FIntf;
end;

procedure TMTS.Connect;
begin
  DefaultInterface.Connect;
end;

procedure TMTS.Disconnect;
begin
  DefaultInterface.Disconnect;
end;

procedure TMTS.StartData;
begin
  DefaultInterface.StartData;
end;

procedure Register;
begin
  RegisterComponents(dtlOcxPage, [TMTS]);
end;

end.
