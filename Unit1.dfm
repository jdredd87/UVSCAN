object Form1: TForm1
  Left = 192
  Top = 132
  Caption = 'UV Scanner'
  ClientHeight = 761
  ClientWidth = 1078
  Color = clBtnFace
  Constraints.MinHeight = 600
  Constraints.MinWidth = 800
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Arial'
  Font.Pitch = fpFixed
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  Position = poDesktopCenter
  WindowState = wsMaximized
  OnClose = FormClose
  OnCreate = FormCreate
  OnMouseDown = FormMouseDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 14
  object ToolBar1: TToolBar
    Left = 0
    Top = 0
    Width = 1078
    Height = 24
    AutoSize = True
    ButtonWidth = 114
    Caption = 'Scanner Tool Bar'
    DrawingStyle = dsGradient
    EdgeBorders = [ebLeft, ebTop, ebRight, ebBottom]
    EdgeInner = esNone
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Arial'
    Font.Pitch = fpFixed
    Font.Style = [fsBold]
    List = True
    ParentFont = False
    ShowCaptions = True
    TabOrder = 0
    object ConnectAVT: TToolButton
      Left = 0
      Top = 0
      Caption = 'CONNECT'
      ImageIndex = 0
      ParentShowHint = False
      ShowHint = False
      OnClick = ConnectAVTClick
    end
    object DisconnectB: TToolButton
      Left = 114
      Top = 0
      Caption = 'DISCONNECT'
      Enabled = False
      ImageIndex = 4
      OnClick = DisconnectBClick
    end
    object pcminfob: TToolButton
      Left = 228
      Top = 0
      Caption = 'PCM INFO'
      Enabled = False
      ImageIndex = 1
      OnClick = pcminfobClick
    end
    object ScannerB: TToolButton
      Left = 342
      Top = 0
      Caption = 'SCANNER'
      Enabled = False
      ImageIndex = 2
      OnClick = ScannerBClick
    end
    object Startlogb: TToolButton
      Left = 456
      Top = 0
      Caption = 'START LOG (F8)'
      Enabled = False
      ImageIndex = 3
      OnClick = StartlogbClick
    end
    object pauseb: TToolButton
      Left = 570
      Top = 0
      Caption = 'PAUSE'
      Enabled = False
      ImageIndex = 5
      OnClick = pausebClick
    end
    object STOPSCANNER: TToolButton
      Left = 684
      Top = 0
      Caption = 'STOP SCANNER'
      Enabled = False
      ImageIndex = 6
      OnClick = STOPSCANNERClick
    end
  end
  object PIDPanel: TPageControl
    Left = 0
    Top = 24
    Width = 1078
    Height = 718
    ActivePage = TabSheet8
    Align = alClient
    HotTrack = True
    MultiLine = True
    TabOrder = 1
    object TabSheet9: TTabSheet
      Caption = 'Settings'
      ImageIndex = 2
      object PIDPage: TPageControl
        Left = 0
        Top = 0
        Width = 313
        Height = 689
        ActivePage = TabSheet11
        Align = alLeft
        MultiLine = True
        TabHeight = 20
        TabOrder = 0
        object TabSheet1: TTabSheet
          Caption = 'Engine'
          object EnginePids: TCheckListBox
            Left = 0
            Top = 0
            Width = 305
            Height = 639
            OnClickCheck = addpidtolist
            Align = alClient
            ItemHeight = 14
            TabOrder = 0
            OnClick = pidsize
          end
        end
        object TabSheet2: TTabSheet
          Caption = 'Transmission'
          ImageIndex = 1
          object TrannyPids: TCheckListBox
            Left = 0
            Top = 0
            Width = 305
            Height = 639
            OnClickCheck = addpidtolist
            Align = alClient
            ItemHeight = 14
            TabOrder = 0
            OnClick = pidsize
          end
        end
        object TabSheet3: TTabSheet
          Caption = 'Indicators'
          ImageIndex = 2
          object indypids: TCheckListBox
            Left = 0
            Top = 0
            Width = 305
            Height = 639
            OnClickCheck = addpidtolist
            Align = alClient
            ItemHeight = 14
            TabOrder = 0
            OnClick = pidsize
          end
        end
        object TabSheet4: TTabSheet
          Caption = 'Body'
          ImageIndex = 3
          object BodyPids: TCheckListBox
            Left = 0
            Top = 0
            Width = 305
            Height = 639
            OnClickCheck = addpidtolist
            Align = alClient
            ItemHeight = 14
            TabOrder = 0
            OnClick = pidsize
          end
        end
        object TabSheet5: TTabSheet
          Caption = 'Accessories'
          ImageIndex = 4
          object ACCPids: TCheckListBox
            Left = 0
            Top = 0
            Width = 305
            Height = 639
            OnClickCheck = addpidtolist
            Align = alClient
            ItemHeight = 14
            TabOrder = 0
            OnClick = pidsize
          end
        end
        object TabSheet6: TTabSheet
          Caption = 'Other'
          ImageIndex = 5
          object otherpids: TCheckListBox
            Left = 0
            Top = 0
            Width = 305
            Height = 639
            OnClickCheck = addpidtolist
            Align = alClient
            ItemHeight = 14
            TabOrder = 0
            OnClick = pidsize
          end
        end
        object TabSheet10: TTabSheet
          Caption = 'Fake PIDS'
          ImageIndex = 6
          object fakepids: TCheckListBox
            Left = 0
            Top = 0
            Width = 305
            Height = 639
            OnClickCheck = addpidtolist
            Align = alClient
            ItemHeight = 14
            TabOrder = 0
            OnClick = pidsize
          end
        end
        object TabSheet11: TTabSheet
          Caption = 'Analog Digital'
          ImageIndex = 7
          object ad: TCheckListBox
            Left = 0
            Top = 0
            Width = 305
            Height = 639
            OnClickCheck = addpidtolist
            Align = alClient
            ItemHeight = 14
            TabOrder = 0
            OnClick = pidsize
          end
        end
      end
      object GroupBox1: TGroupBox
        Left = 313
        Top = 0
        Width = 757
        Height = 689
        Align = alClient
        Caption = 'ComStatus'
        TabOrder = 1
        object statusmemo: TMemo
          Left = 2
          Top = 16
          Width = 753
          Height = 540
          Align = alClient
          Color = clScrollBar
          Lines.Strings = (
            'Memo1')
          TabOrder = 0
        end
        object Panel1: TPanel
          Left = 2
          Top = 556
          Width = 753
          Height = 131
          Align = alBottom
          Color = clMedGray
          ParentBackground = False
          TabOrder = 1
          DesignSize = (
            753
            131)
          object StaticText5: TStaticText
            Left = 4
            Top = 7
            Width = 120
            Height = 24
            Anchors = [akLeft, akBottom]
            Caption = 'PID Byte Size '
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -16
            Font.Name = 'MS Sans Serif'
            Font.Pitch = fpFixed
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 0
          end
          object pbs: TStaticText
            Left = 123
            Top = 7
            Width = 19
            Height = 24
            Anchors = [akLeft, akBottom]
            Caption = '0 '
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -16
            Font.Name = 'MS Sans Serif'
            Font.Pitch = fpFixed
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 1
          end
          object tfp: TStaticText
            Left = 123
            Top = 107
            Width = 11
            Height = 17
            Anchors = [akLeft, akBottom]
            Caption = '0'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'MS Sans Serif'
            Font.Pitch = fpFixed
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 2
          end
          object StaticText6: TStaticText
            Left = 4
            Top = 109
            Width = 78
            Height = 18
            Anchors = [akLeft, akBottom]
            Caption = 'Total Fake PIDS'
            TabOrder = 3
          end
          object StaticText4: TStaticText
            Left = 123
            Top = 84
            Width = 18
            Height = 17
            Anchors = [akLeft, akBottom]
            Caption = '48'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'MS Sans Serif'
            Font.Pitch = fpFixed
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 4
          end
          object StaticText2: TStaticText
            Left = 4
            Top = 37
            Width = 122
            Height = 18
            Anchors = [akLeft, akBottom]
            Caption = 'Total PID Bytes Allowed '
            TabOrder = 5
          end
          object tsp: TStaticText
            Left = 123
            Top = 60
            Width = 11
            Height = 17
            Anchors = [akLeft, akBottom]
            Caption = '0'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'MS Sans Serif'
            Font.Pitch = fpFixed
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 6
          end
          object StaticText3: TStaticText
            Left = 4
            Top = 61
            Width = 100
            Height = 18
            Anchors = [akLeft, akBottom]
            Caption = 'Total Selected PIDS '
            TabOrder = 7
          end
          object pbc: TStaticText
            Left = 123
            Top = 37
            Width = 11
            Height = 17
            Anchors = [akLeft, akBottom]
            Caption = '0'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'MS Sans Serif'
            Font.Pitch = fpFixed
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 8
          end
          object StaticText1: TStaticText
            Left = 4
            Top = 85
            Width = 75
            Height = 18
            Anchors = [akLeft, akBottom]
            Caption = 'PID Byte Count'
            TabOrder = 9
          end
        end
      end
    end
    object TabSheet7: TTabSheet
      Caption = 'Data Grid'
      ImageIndex = 1
      OnMouseDown = TabSheet7MouseDown
      OnShow = TabSheet7Show
      DesignSize = (
        1070
        689)
      object SpeedButton1: TSpeedButton
        Left = 3
        Top = 3
        Width = 70
        Height = 22
        Caption = 'Zoom IN (F1)'
        OnClick = SpeedButton1Click
      end
      object SpeedButton2: TSpeedButton
        Left = 79
        Top = 3
        Width = 82
        Height = 22
        Caption = 'Zoom OUT (F2)'
        OnClick = SpeedButton2Click
      end
      object pid_grid: TAdvStringGrid
        Left = 3
        Top = 24
        Width = 1064
        Height = 662
        Cursor = crDefault
        Anchors = [akLeft, akTop, akRight, akBottom]
        ColCount = 3
        DefaultColWidth = 125
        DefaultRowHeight = 21
        DrawingStyle = gdsClassic
        RowCount = 80
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Pitch = fpFixed
        Font.Style = []
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goDrawFocusSelected, goRowSizing, goColSizing, goTabs, goRowSelect]
        ParentFont = False
        ScrollBars = ssBoth
        TabOrder = 0
        OnKeyDown = pid_gridKeyDown
        OnMouseDown = pid_gridMouseDown
        ActiveRowShow = True
        ActiveRowColor = 4227327
        GridFixedLineColor = clNone
        HoverRowCells = [hcNormal, hcSelected]
        OnCellChanging = pid_gridCellChanging
        ActiveCellFont.Charset = DEFAULT_CHARSET
        ActiveCellFont.Color = clDefault
        ActiveCellFont.Height = -11
        ActiveCellFont.Name = 'Tahoma'
        ActiveCellFont.Style = [fsBold]
        ColumnHeaders.Strings = (
          'PID'
          'VALUE'
          'TYPE')
        ColumnSize.Stretch = True
        ColumnSize.SynchWithGrid = True
        ControlLook.FixedGradientFrom = clMenuBar
        ControlLook.FixedGradientTo = clMenuBar
        ControlLook.FixedGradientHoverFrom = clGray
        ControlLook.FixedGradientHoverTo = clWhite
        ControlLook.FixedGradientDownFrom = clGray
        ControlLook.FixedGradientDownTo = clSilver
        ControlLook.DropDownHeader.Font.Charset = DEFAULT_CHARSET
        ControlLook.DropDownHeader.Font.Color = clWindowText
        ControlLook.DropDownHeader.Font.Height = -11
        ControlLook.DropDownHeader.Font.Name = 'Tahoma'
        ControlLook.DropDownHeader.Font.Style = []
        ControlLook.DropDownHeader.Visible = True
        ControlLook.DropDownHeader.Buttons = <>
        ControlLook.DropDownFooter.Font.Charset = DEFAULT_CHARSET
        ControlLook.DropDownFooter.Font.Color = clWindowText
        ControlLook.DropDownFooter.Font.Height = -11
        ControlLook.DropDownFooter.Font.Name = 'Tahoma'
        ControlLook.DropDownFooter.Font.Style = []
        ControlLook.DropDownFooter.Visible = True
        ControlLook.DropDownFooter.Buttons = <>
        EnableBlink = True
        Filter = <>
        FilterDropDown.Font.Charset = DEFAULT_CHARSET
        FilterDropDown.Font.Color = clWindowText
        FilterDropDown.Font.Height = -11
        FilterDropDown.Font.Name = 'Tahoma'
        FilterDropDown.Font.Style = []
        FilterDropDownClear = '(All)'
        FilterEdit.TypeNames.Strings = (
          'Starts with'
          'Ends with'
          'Contains'
          'Not contains'
          'Equal'
          'Not equal'
          'Larger than'
          'Smaller than'
          'Clear')
        FixedColWidth = 47
        FixedRowHeight = 22
        FixedColAlways = True
        FixedFont.Charset = DEFAULT_CHARSET
        FixedFont.Color = clWindowText
        FixedFont.Height = -11
        FixedFont.Name = 'Tahoma'
        FixedFont.Pitch = fpFixed
        FixedFont.Style = [fsBold]
        FloatFormat = '%.2f'
        Grouping.HeaderColor = cl3DLight
        Grouping.SummaryColor = clScrollBar
        HoverButtons.Buttons = <>
        HoverButtons.Position = hbLeftFromColumnLeft
        HTMLSettings.ImageFolder = 'images'
        HTMLSettings.ImageBaseName = 'img'
        MouseActions.RowSelect = True
        PrintSettings.DateFormat = 'dd/mm/yyyy'
        PrintSettings.Font.Charset = DEFAULT_CHARSET
        PrintSettings.Font.Color = clWindowText
        PrintSettings.Font.Height = -11
        PrintSettings.Font.Name = 'Tahoma'
        PrintSettings.Font.Style = []
        PrintSettings.FixedFont.Charset = DEFAULT_CHARSET
        PrintSettings.FixedFont.Color = clWindowText
        PrintSettings.FixedFont.Height = -11
        PrintSettings.FixedFont.Name = 'Tahoma'
        PrintSettings.FixedFont.Style = []
        PrintSettings.HeaderFont.Charset = DEFAULT_CHARSET
        PrintSettings.HeaderFont.Color = clWindowText
        PrintSettings.HeaderFont.Height = -11
        PrintSettings.HeaderFont.Name = 'Tahoma'
        PrintSettings.HeaderFont.Style = []
        PrintSettings.FooterFont.Charset = DEFAULT_CHARSET
        PrintSettings.FooterFont.Color = clWindowText
        PrintSettings.FooterFont.Height = -11
        PrintSettings.FooterFont.Name = 'Tahoma'
        PrintSettings.FooterFont.Style = []
        PrintSettings.PageNumSep = '/'
        ScrollWidth = 16
        SearchFooter.Color = clMenuBar
        SearchFooter.ColorTo = clNone
        SearchFooter.FindNextCaption = 'Find next'
        SearchFooter.FindPrevCaption = 'Find previous'
        SearchFooter.Font.Charset = DEFAULT_CHARSET
        SearchFooter.Font.Color = clWindowText
        SearchFooter.Font.Height = -11
        SearchFooter.Font.Name = 'Tahoma'
        SearchFooter.Font.Style = []
        SearchFooter.HighLightCaption = 'Highlight'
        SearchFooter.HintClose = 'Close'
        SearchFooter.HintFindNext = 'Find next occurence'
        SearchFooter.HintFindPrev = 'Find previous occurence'
        SearchFooter.HintHighlight = 'Highlight occurences'
        SearchFooter.MatchCaseCaption = 'Match case'
        SearchFooter.ResultFormat = '(%d of %d)'
        SelectionColor = 4227327
        SortSettings.DefaultFormat = ssAutomatic
        Version = '8.4.7.0'
        ExplicitWidth = 771
        ExplicitHeight = 428
        ColWidths = (
          47
          47
          949)
        RowHeights = (
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21
          21)
      end
      object CheckBox1: TCheckBox
        Left = 176
        Top = 3
        Width = 97
        Height = 17
        Caption = 'Show Gauges'
        TabOrder = 1
        OnClick = CheckBox1Click
      end
    end
    object TabSheet8: TTabSheet
      Caption = 'PCM Tools'
      ImageIndex = 2
      object Label1: TLabel
        Left = 3
        Top = 11
        Width = 113
        Height = 14
        Caption = 'SEND Command to PCM'
      end
      object AFRLabel: TLabel
        Left = 136
        Top = 293
        Width = 90
        Height = 33
        Caption = '-1 AFR'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -29
        Font.Name = 'Arial'
        Font.Pitch = fpFixed
        Font.Style = []
        ParentFont = False
      end
      object LambaLabel: TLabel
        Left = 136
        Top = 332
        Width = 130
        Height = 33
        Caption = '-1 LAMBA'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -29
        Font.Name = 'Arial'
        Font.Pitch = fpFixed
        Font.Style = []
        ParentFont = False
      end
      object Edit1: TEdit
        Left = 3
        Top = 43
        Width = 233
        Height = 22
        TabOrder = 0
        Text = 'F1A5'
      end
      object Button1: TButton
        Left = 242
        Top = 31
        Width = 75
        Height = 22
        Caption = 'SEND'
        TabOrder = 1
        OnClick = Button1Click
      end
      object vinupdate: TLabeledEdit
        Left = 3
        Top = 88
        Width = 121
        Height = 22
        CharCase = ecUpperCase
        EditLabel.Width = 54
        EditLabel.Height = 14
        EditLabel.Caption = 'VIN Update'
        MaxLength = 17
        TabOrder = 2
      end
      object Button2: TButton
        Left = 130
        Top = 88
        Width = 75
        Height = 22
        Caption = 'UPDATE VIN'
        TabOrder = 3
        OnClick = Button2Click
      end
      object GroupBox2: TGroupBox
        Left = 3
        Top = 147
        Width = 225
        Height = 140
        Caption = 'Toggles'
        TabOrder = 4
        object Button3: TButton
          Left = 51
          Top = 22
          Width = 127
          Height = 25
          Caption = 'RESET LTFT'
          TabOrder = 0
          OnClick = Button3Click
        end
        object Button5: TButton
          Left = 51
          Top = 101
          Width = 127
          Height = 25
          Caption = 'TURN SES LIGHT OFF'
          TabOrder = 1
          OnClick = Button5Click
        end
        object Button4: TButton
          Left = 51
          Top = 62
          Width = 127
          Height = 25
          Caption = 'TURN SES LIGHT ON'
          TabOrder = 2
          OnClick = Button4Click
        end
      end
      object portlist: TListBox
        Left = 3
        Top = 293
        Width = 127
        Height = 180
        ItemHeight = 14
        TabOrder = 5
        OnClick = portlistClick
      end
      object wbfire: TButton
        Left = 3
        Top = 479
        Width = 127
        Height = 25
        Caption = 'FIRE UP WB'
        TabOrder = 7
        OnClick = wbfireClick
      end
      object Button6: TButton
        Left = 3
        Top = 526
        Width = 127
        Height = 25
        Caption = 'DISCONNECT WB'
        TabOrder = 6
        OnClick = Button6Click
      end
    end
  end
  object sbar: TStatusBar
    Left = 0
    Top = 742
    Width = 1078
    Height = 19
    Panels = <
      item
        Text = 'FIRMWARE'
        Width = 90
      end
      item
        Text = 'VIN'
        Width = 150
      end
      item
        Text = 'PCM OSID'
        Width = 140
      end
      item
        Text = 'NOT CONNECTED'
        Width = 100
      end
      item
        Text = 'LINECOUNT 0'
        Width = 110
      end
      item
        Text = 'LOGSTATUS'
        Width = 100
      end
      item
        Width = 80
      end
      item
        Width = 50
      end>
  end
  object MainMenu1: TMainMenu
    Left = 704
    Top = 24
    object File1: TMenuItem
      Caption = '&File'
      object Setup1: TMenuItem
        Caption = '&Setup'
        OnClick = Setup1Click
      end
    end
    object FileM: TMenuItem
      Caption = '&PIDs'
      object LoadSavedList1: TMenuItem
        Caption = '&Load Checked PID List'
        OnClick = LoadSavedList1Click
      end
      object SavePidList1: TMenuItem
        Caption = '&Save Checked PID List'
        OnClick = SavePidList1Click
      end
      object EnableallPids1: TMenuItem
        Caption = '&Enable All Pids'
        OnClick = EnableallPids1Click
      end
      object ClearCheckedPIDs1: TMenuItem
        Caption = '&Clear Checked PIDs'
        OnClick = ClearCheckedPIDs1Click
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object estVehicleforPIDS1: TMenuItem
        Caption = '&Test Vehicle for PIDS'
        OnClick = estVehicleforPIDS1Click
      end
    end
    object Logging: TMenuItem
      Caption = '&Logging'
      object AutoName1: TMenuItem
        Caption = '&AutoName'
        OnClick = AutoName1Click
      end
    end
    object DTCs1: TMenuItem
      Caption = 'DTCs'
      object ReadDTCs1: TMenuItem
        Caption = 'Read DTCs'
        OnClick = ReadDTCs1Click
      end
      object ClearDTCs1: TMenuItem
        Caption = 'Clear DTCs'
        OnClick = ClearDTCs1Click
      end
    end
    object Logcolor1: TMenuItem
      Caption = '&Logcolor'
      object OpenLOG1: TMenuItem
        Caption = '&Open LOG'
        OnClick = OpenLOG1Click
      end
    end
    object About1: TMenuItem
      Caption = '&Help'
      object About2: TMenuItem
        Caption = '&About'
        OnClick = About2Click
      end
    end
  end
  object saveCSV: TSaveDialog
    DefaultExt = 'CSV'
    FileName = '*.csv'
    Filter = '*.csv|CSV'
    Left = 676
    Top = 24
  end
  object pidlistsave: TSaveDialog
    DefaultExt = '*.pid'
    FileName = '*.pid'
    Filter = '*.pid|*.pid'
    Left = 616
    Top = 24
  end
  object pidlistopen: TOpenDialog
    FileName = '*.pid'
    Filter = '*.pid|*.pid'
    InitialDir = '*.pid'
    Left = 648
    Top = 24
  end
  object forma: TArtFormula
    UnQuotedString = False
    Step = False
    ExternGetVar = False
    VarNameLiterals = '_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    NoLeadingZero = False
    ZeroEmptyString = False
    Left = 584
    Top = 24
  end
  object comport: TApdWinsockPort
    WsLocalAddresses.Strings = (
      '192.168.56.1'
      '192.168.50.79'
      '192.168.232.119'
      '169.254.141.53')
    WsLocalAddressIndex = 0
    WsPort = '10001'
    WsSocksServerInfo.Port = 0
    WsTelnet = False
    AutoOpen = False
    Baud = 115200
    BufferFull = 3072
    BufferResume = 1024
    ComNumber = 2
    HWFlowOptions = [hwfUseRTS, hwfRequireCTS]
    TraceAllHex = True
    TraceSize = 4000000
    TraceName = 'uvscantrace.log'
    LogSize = 16000000
    LogName = 'uvscan.log'
    Left = 520
    Top = 24
  end
  object avtinit: TApdDataPacket
    Enabled = False
    AutoEnable = False
    EndCond = [ecPacketSize]
    StartString = '9107'
    ComPort = comport
    PacketSize = 2
    OnStringPacket = avtinitStringPacket
    Left = 352
    Top = 104
  end
  object AVTSPEED: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = 'C100'
    ComPort = comport
    PacketSize = 2
    OnStringPacket = AVTSPEEDStringPacket
    Left = 352
    Top = 168
  end
  object avtversion: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '92'
    ComPort = comport
    PacketSize = 3
    OnStringPacket = avtversionStringPacket
    Left = 352
    Top = 136
  end
  object AVTVIN1: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1107C0100'
    ComPort = comport
    PacketSize = 13
    TimeOut = 4000
    OnStringPacket = AVTVIN1StringPacket
    Left = 408
    Top = 104
  end
  object AVTVIN2: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1107C02'
    ComPort = comport
    PacketSize = 13
    TimeOut = 4000
    OnStringPacket = AVTVIN2StringPacket
    Left = 408
    Top = 136
  end
  object AVTVIN3: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1107C03'
    ComPort = comport
    PacketSize = 13
    TimeOut = 4000
    OnStringPacket = AVTVIN3StringPacket
    Left = 408
    Top = 168
  end
  object AVTOSID: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '6CF1107C0A'
    ComPort = comport
    PacketSize = 9
    OnStringPacket = AVTOSIDStringPacket
    OnTimeout = AVTOSIDTimeout
    Left = 464
    Top = 104
  end
  object blockFE: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1106AFE'
    ComPort = comport
    PacketSize = 13
    OnStringPacket = blockFEStringPacket
    Left = 528
    Top = 104
  end
  object BLOCKFD: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1106AFD'
    ComPort = comport
    PacketSize = 13
    OnStringPacket = blockFEStringPacket
    Left = 528
    Top = 136
  end
  object BLOCKFC: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1106AFC'
    ComPort = comport
    PacketSize = 13
    OnStringPacket = blockFEStringPacket
    Left = 528
    Top = 168
  end
  object BLOCKFB: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1106AFB'
    ComPort = comport
    PacketSize = 13
    OnStringPacket = blockFEStringPacket
    Left = 528
    Top = 200
  end
  object BLOCKFA: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1106AFA'
    ComPort = comport
    PacketSize = 13
    OnStringPacket = blockFEStringPacket
    Left = 528
    Top = 232
  end
  object BLOCKF9: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1106AF9'
    ComPort = comport
    PacketSize = 13
    OnStringPacket = blockFEStringPacket
    Left = 528
    Top = 264
  end
  object BLOCKF8: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1106AF8'
    ComPort = comport
    PacketSize = 13
    OnStringPacket = blockFEStringPacket
    Left = 528
    Top = 296
  end
  object BLOCKF7: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1106AF7'
    ComPort = comport
    PacketSize = 13
    OnStringPacket = blockFEStringPacket
    Left = 528
    Top = 328
  end
  object ADPORTS: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '6458'
    ComPort = comport
    PacketSize = 5
    OnStringPacket = blockFEStringPacket
    Left = 592
    Top = 104
  end
  object BADPID: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0C006CF1107F2C'
    ComPort = comport
    PacketSize = 11
    OnStringPacket = BADPIDStringPacket
    Left = 352
    Top = 200
  end
  object VrTimer1: TVrTimer
    Enabled = False
    Interval = 2500
    Priority = tpHigher
    OnTimer = VrTimer1Timer
    Left = 768
    Top = 24
  end
  object LogOpen: TOpenDialog
    DefaultExt = '*.csv'
    Left = 448
    Top = 24
  end
  object ApplicationEvents1: TApplicationEvents
    OnActionExecute = ApplicationEvents1ActionExecute
    Left = 416
    Top = 24
  end
  object dtc_ago: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '07006CF1105908'
    ComPort = comport
    PacketSize = 8
    TimeOut = 4000
    OnStringPacket = dtc_agoStringPacket
    Left = 648
    Top = 104
  end
  object dtc_find: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '08006CF11059'
    ComPort = comport
    PacketSize = 9
    TimeOut = 15000
    OnStringPacket = dtc_findStringPacket
    OnTimeout = dtc_findTimeout
    Left = 648
    Top = 144
  end
  object pidpop: TPopupMenu
    OnPopup = pidpopPopup
    Left = 352
    Top = 264
    object ModifySelectedPID1: TMenuItem
      Caption = 'Modify Selected PID '
      OnClick = ModifySelectedPID1Click
    end
    object ResetallRows1: TMenuItem
      Caption = 'Reset All Row Settings'
      OnClick = ResetallRows1Click
    end
    object ShowGauge1: TMenuItem
      Caption = 'Show Gauge'
      OnClick = ShowGauge1Click
    end
    object HideGauge1: TMenuItem
      Caption = 'Hide Gauge'
      OnClick = HideGauge1Click
    end
    object HideallPIDWindow1: TMenuItem
      Caption = 'Hide all PID Windows'
      OnClick = HideallPIDWindow1Click
    end
  end
  object FindModules: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '05006CF1'
    ComPort = comport
    PacketSize = 6
    TimeOut = 15000
    OnStringPacket = FindModulesStringPacket
    Left = 648
    Top = 184
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 3000
    OnTimer = Timer1Timer
    Left = 384
    Top = 24
  end
  object script: TApdScript
    ComPort = comport
    DisplayToTerminal = False
    OnScriptParseVariable = scriptScriptParseVariable
    OnScriptUserFunction = scriptScriptUserFunction
    Left = 648
    Top = 216
  end
  object CHECKPID1: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '08006CF01062'
    ComPort = comport
    PacketSize = 9
    TimeOut = 100
    OnStringPacket = CHECKPID1StringPacket
    OnTimeout = CHECKPID1Timeout
    Left = 352
    Top = 320
  end
  object CHECKPID2: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '0A006CF0107F22'
    ComPort = comport
    PacketSize = 11
    TimeOut = 100
    OnStringPacket = CHECKPID2StringPacket
    Left = 352
    Top = 352
  end
  object checkpid3: TApdDataPacket
    Enabled = False
    EndCond = [ecPacketSize]
    StartString = '09006CF01062'
    ComPort = comport
    PacketSize = 10
    TimeOut = 100
    OnStringPacket = checkpid3StringPacket
    Left = 352
    Top = 392
  end
end
