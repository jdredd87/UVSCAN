unit VDEVCTRLLib_TLB;

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
// File generated on 8/30/2008 11:10:43 PM from Type Library described below.

// ************************************************************************  //
// Type Lib: C:\Program Files\LogWorks2\vdevctrl.dll (1)
// LIBID: {55920B35-3475-48ED-8F51-BB039D2C1F07}
// LCID: 0
// Helpfile: 
// HelpString: LW2 Virtual Device
// DepndLst: 
//   (1) v2.0 stdole, (C:\WINDOWS\system32\stdole2.tlb)
// Errors:
//   Hint: Parameter 'type' of ILW2VDev.AddChannel changed to 'type_'
//   Hint: Parameter 'type' of ILW2VDev.AddChannelEx changed to 'type_'
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
  VDEVCTRLLibMajorVersion = 1;
  VDEVCTRLLibMinorVersion = 0;

  LIBID_VDEVCTRLLib: TGUID = '{55920B35-3475-48ED-8F51-BB039D2C1F07}';

  DIID__ILW2VDevEvents: TGUID = '{B08DEE12-3251-41EA-90F8-7C95092181EB}';
  IID_ILW2VDev: TGUID = '{D3A95FBD-BE44-4F39-8BE7-7C23F31B32D2}';
  CLASS_LW2VDev: TGUID = '{280516EF-2D82-4680-89DF-801AEA50749B}';
type

// *********************************************************************//
// Forward declaration of types defined in TypeLibrary                    
// *********************************************************************//
  _ILW2VDevEvents = dispinterface;
  ILW2VDev = interface;
  ILW2VDevDisp = dispinterface;

// *********************************************************************//
// Declaration of CoClasses defined in Type Library                       
// (NOTE: Here we map each CoClass to its Default Interface)              
// *********************************************************************//
  LW2VDev = ILW2VDev;


// *********************************************************************//
// Declaration of structures, unions and aliases.                         
// *********************************************************************//
  PSYSINT1 = ^SYSINT; {*}


// *********************************************************************//
// DispIntf:  _ILW2VDevEvents
// Flags:     (4096) Dispatchable
// GUID:      {B08DEE12-3251-41EA-90F8-7C95092181EB}
// *********************************************************************//
  _ILW2VDevEvents = dispinterface
    ['{B08DEE12-3251-41EA-90F8-7C95092181EB}']
  end;

// *********************************************************************//
// Interface: ILW2VDev
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {D3A95FBD-BE44-4F39-8BE7-7C23F31B32D2}
// *********************************************************************//
  ILW2VDev = interface(IDispatch)
    ['{D3A95FBD-BE44-4F39-8BE7-7C23F31B32D2}']
    function Get_IsConnected: Integer; safecall;
    procedure AddChannel(const name: WideString;
    const units: WideString; min: Double; max: Double;
    type_: SYSINT; var chan: SYSINT); safecall;
    procedure SetValue(chan: Integer; value: Double); safecall;
    procedure AddChannelEx(const name: WideString; const units: WideString; min: Double; 
                           max: Double; type_: SYSINT; const devname: WideString; devinput: SYSINT; 
                           devtype: SYSINT; devfunc: SYSINT; var chan: SYSINT); safecall;
    property IsConnected: Integer read Get_IsConnected;
  end;

// *********************************************************************//
// DispIntf:  ILW2VDevDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {D3A95FBD-BE44-4F39-8BE7-7C23F31B32D2}
// *********************************************************************//
  ILW2VDevDisp = dispinterface
    ['{D3A95FBD-BE44-4F39-8BE7-7C23F31B32D2}']
    property IsConnected: Integer readonly dispid 1;
    procedure AddChannel(const name: WideString; const units: WideString; min: Double; max: Double; 
                         type_: SYSINT; var chan: SYSINT); dispid 2;
    procedure SetValue(chan: Integer; value: Double); dispid 3;
    procedure AddChannelEx(const name: WideString; const units: WideString; min: Double; 
                           max: Double; type_: SYSINT; const devname: WideString; devinput: SYSINT; 
                           devtype: SYSINT; devfunc: SYSINT; var chan: SYSINT); dispid 4;
  end;


// *********************************************************************//
// OLE Control Proxy class declaration
// Control Name     : TLW2VDev
// Help String      : LW2VDev Control
// Default Interface: ILW2VDev
// Def. Intf. DISP? : No
// Event   Interface: _ILW2VDevEvents
// TypeFlags        : (2) CanCreate
// *********************************************************************//
  TLW2VDev = class(TOleControl)
  private
    FIntf: ILW2VDev;
    function  GetControlInterface: ILW2VDev;
  protected
    procedure CreateControl;
    procedure InitControlData; override;
  public
    procedure AddChannel(const name: WideString; const units: WideString; min: Double; max: Double; 
                         type_: SYSINT; var chan: SYSINT);
    procedure SetValue(chan: Integer; value: Double);
    procedure AddChannelEx(const name: WideString; const units: WideString; min: Double; 
                           max: Double; type_: SYSINT; const devname: WideString; devinput: SYSINT; 
                           devtype: SYSINT; devfunc: SYSINT; var chan: SYSINT);
    property  ControlInterface: ILW2VDev read GetControlInterface;
    property  DefaultInterface: ILW2VDev read GetControlInterface;
    property IsConnected: Integer index 1 read GetIntegerProp;
  published
    property Anchors;
  end;

procedure Register;

resourcestring
  dtlServerPage = 'ActiveX';

  dtlOcxPage = 'ActiveX';

implementation

uses ComObj;

procedure TLW2VDev.InitControlData;
const
  CControlData: TControlData2 = (
    ClassID: '{280516EF-2D82-4680-89DF-801AEA50749B}';
    EventIID: '';
    EventCount: 0;
    EventDispIDs: nil;
    LicenseKey: nil (*HR:$80004002*);
    Flags: $00000000;
    Version: 401);
begin
  ControlData := @CControlData;
end;

procedure TLW2VDev.CreateControl;

  procedure DoCreate;
  begin
    FIntf := IUnknown(OleObject) as ILW2VDev;
  end;

begin
  if FIntf = nil then DoCreate; c
end;

function TLW2VDev.GetControlInterface: ILW2VDev;
begin
  CreateControl;
  Result := FIntf;
end;

procedure TLW2VDev.AddChannel(const name: WideString; const units: WideString; min: Double;
                              max: Double; type_: SYSINT; var chan: SYSINT);
begin
  DefaultInterface.AddChannel(name, units, min, max, type_, chan);
end;

procedure TLW2VDev.SetValue(chan: Integer; value: Double);
begin
  DefaultInterface.SetValue(chan, value);
end;

procedure TLW2VDev.AddChannelEx(const name: WideString; const units: WideString; min: Double;
                                max: Double; type_: SYSINT; const devname: WideString;
                                devinput: SYSINT; devtype: SYSINT; devfunc: SYSINT; var chan: SYSINT);
begin
  DefaultInterface.AddChannelEx(name, units, min, max, type_, devname, devinput, devtype, devfunc,
                                chan);
end;

procedure Register;
begin
  RegisterComponents(dtlOcxPage, [TLW2VDev]);
end;

end.
