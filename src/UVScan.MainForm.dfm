object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'UVScan'
  ClientHeight = 720
  ClientWidth = 1180
  Color = clBtnFace
  Constraints.MinHeight = 500
  Constraints.MinWidth = 900
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnResize = FormResize
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1180
    Height = 52
    Align = alTop
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    object lblPort: TLabel
      Left = 12
      Top = 18
      Width = 22
      Height = 15
      Caption = 'Port'
    end
    object cbPort: TComboBox
      Left = 42
      Top = 14
      Width = 110
      Height = 23
      Style = csDropDownList
      TabOrder = 0
    end
    object btnRefreshPorts: TButton
      Left = 156
      Top = 13
      Width = 62
      Height = 26
      Caption = 'Refresh'
      TabOrder = 1
      OnClick = btnRefreshPortsClick
    end
    object cbBaud: TComboBox
      Left = 224
      Top = 14
      Width = 80
      Height = 23
      Style = csDropDownList
      TabOrder = 2
      Items.Strings = (
        '115200'
        '57600')
    end
    object btnConnect: TButton
      Left = 316
      Top = 13
      Width = 90
      Height = 26
      Caption = 'Connect'
      TabOrder = 3
      OnClick = btnConnectClick
    end
    object btnDisconnect: TButton
      Left = 410
      Top = 13
      Width = 90
      Height = 26
      Caption = 'Disconnect'
      TabOrder = 4
      OnClick = btnDisconnectClick
    end
    object bvlSep1: TBevel
      Left = 512
      Top = 10
      Width = 2
      Height = 32
      Shape = bsLeftLine
    end
    object btnStartScan: TButton
      Left = 524
      Top = 13
      Width = 100
      Height = 26
      Caption = 'Start scan'
      TabOrder = 5
      OnClick = btnStartScanClick
    end
    object btnStopScan: TButton
      Left = 628
      Top = 13
      Width = 90
      Height = 26
      Caption = 'Stop scan'
      TabOrder = 6
      OnClick = btnStopScanClick
    end
    object bvlSep2: TBevel
      Left = 730
      Top = 10
      Width = 2
      Height = 32
      Shape = bsLeftLine
    end
    object btnLog: TButton
      Left = 742
      Top = 13
      Width = 110
      Height = 26
      Caption = 'Start log (F8)'
      TabOrder = 7
      OnClick = btnLogClick
    end
    object btnPause: TButton
      Left = 856
      Top = 13
      Width = 95
      Height = 26
      Caption = 'Pause (F9)'
      TabOrder = 8
      OnClick = btnPauseClick
    end
  end
  object pnlPids: TPanel
    Left = 0
    Top = 52
    Width = 400
    Height = 645
    Align = alLeft
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Top = 4
    Padding.Right = 4
    Padding.Bottom = 4
    TabOrder = 1
    object edtSearch: TEdit
      AlignWithMargins = True
      Left = 8
      Top = 4
      Width = 388
      Height = 23
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 6
      Align = alTop
      TabOrder = 0
      TextHint = 'Search PIDs...'
      OnChange = edtSearchChange
    end
    object lvPids: TListView
      Left = 8
      Top = 33
      Width = 388
      Height = 538
      Align = alClient
      Checkboxes = True
      Columns = <
        item
          Caption = 'PID'
          Width = 220
        end
        item
          Caption = 'Units'
          Width = 55
        end
        item
          Caption = 'Bytes'
          Width = 45
        end
        item
          Caption = 'Test'
          Width = 55
        end>
      GroupView = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 1
      ViewStyle = vsReport
      OnItemChecked = lvPidsItemChecked
    end
    object pnlPidFooter: TPanel
      Left = 8
      Top = 571
      Width = 388
      Height = 70
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 2
      object lblBudget: TLabel
        Left = 0
        Top = 8
        Width = 60
        Height = 15
        Caption = '0 selected'
      end
      object btnTestPids: TButton
        Left = 0
        Top = 34
        Width = 120
        Height = 26
        Hint = 'Ask the PCM which PIDs it supports (selected PIDs, or all if none)'
        Caption = 'Test PIDs'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        OnClick = btnTestPidsClick
      end
      object btnClearSelection: TButton
        Left = 126
        Top = 34
        Width = 120
        Height = 26
        Caption = 'Clear selection'
        TabOrder = 1
        OnClick = btnClearSelectionClick
      end
    end
  end
  object splLeft: TSplitter
    Left = 400
    Top = 52
    Width = 5
    Height = 645
    MinSize = 250
  end
  object pnlRight: TPanel
    Left = 405
    Top = 52
    Width = 775
    Height = 645
    Align = alClient
    BevelOuter = bvNone
    Padding.Top = 4
    Padding.Right = 8
    Padding.Bottom = 4
    TabOrder = 2
    object pnlNotice: TPanel
      AlignWithMargins = True
      Left = 0
      Top = 4
      Width = 767
      Height = 30
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 6
      Align = alTop
      BevelOuter = bvNone
      ParentBackground = False
      TabOrder = 0
      object lblNotice: TLabel
        AlignWithMargins = True
        Left = 10
        Top = 0
        Width = 757
        Height = 30
        Cursor = crHandPoint
        Margins.Left = 10
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alClient
        Caption = 'Notice'
        Layout = tlCenter
        OnClick = lblNoticeClick
      end
    end
    object pcMain: TPageControl
      Left = 0
      Top = 40
      Width = 767
      Height = 601
      ActivePage = tsLive
      Align = alClient
      TabOrder = 1
      object tsLive: TTabSheet
        Caption = 'Live data'
        object grdLive: TDrawGrid
          Left = 0
          Top = 0
          Width = 759
          Height = 531
          Align = alClient
          BorderStyle = bsNone
          ColCount = 5
          DefaultDrawing = False
          DefaultRowHeight = 30
          FixedCols = 0
          RowCount = 2
          Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goThumbTracking]
          TabOrder = 0
          OnDrawCell = grdLiveDrawCell
        end
        object pnlLiveFooter: TPanel
          Left = 0
          Top = 531
          Width = 759
          Height = 40
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 1
          object lblLiveHint: TLabel
            Left = 150
            Top = 12
            Width = 300
            Height = 15
            Caption = 'Tick PIDs on the left, connect, then press Start scan.'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clGrayText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object btnResetMinMax: TButton
            Left = 6
            Top = 7
            Width = 130
            Height = 26
            Caption = 'Reset min / max'
            TabOrder = 0
            OnClick = btnResetMinMaxClick
          end
        end
      end
      object tsVehicle: TTabSheet
        Caption = 'Vehicle && codes'
        ImageIndex = 1
        object gbVehicle: TGroupBox
          AlignWithMargins = True
          Left = 6
          Top = 6
          Width = 747
          Height = 120
          Margins.Left = 6
          Margins.Top = 6
          Margins.Right = 6
          Align = alTop
          Caption = ' Vehicle '
          TabOrder = 0
          object lblVinCaption: TLabel
            Left = 16
            Top = 28
            Width = 20
            Height = 15
            Caption = 'VIN'
          end
          object lblVin: TLabel
            Left = 110
            Top = 28
            Width = 5
            Height = 15
            Caption = '-'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblOsidCaption: TLabel
            Left = 16
            Top = 52
            Width = 50
            Height = 15
            Caption = 'PCM OS ID'
          end
          object lblOsid: TLabel
            Left = 110
            Top = 52
            Width = 5
            Height = 15
            Caption = '-'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblFirmwareCaption: TLabel
            Left = 16
            Top = 76
            Width = 80
            Height = 15
            Caption = 'AVT firmware'
          end
          object lblFirmware: TLabel
            Left = 110
            Top = 76
            Width = 5
            Height = 15
            Caption = '-'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object btnReadInfo: TButton
            Left = 400
            Top = 24
            Width = 140
            Height = 26
            Caption = 'Read vehicle info'
            TabOrder = 0
            OnClick = btnReadInfoClick
          end
        end
        object gbDtcs: TGroupBox
          AlignWithMargins = True
          Left = 6
          Top = 132
          Width = 747
          Height = 433
          Margins.Left = 6
          Margins.Right = 6
          Margins.Bottom = 6
          Align = alClient
          Caption = ' Trouble codes '
          Padding.Left = 6
          Padding.Right = 6
          Padding.Bottom = 6
          TabOrder = 1
          object lvDtcs: TListView
            Left = 8
            Top = 17
            Width = 731
            Height = 364
            Align = alClient
            Columns = <
              item
                Caption = 'Code'
                Width = 80
              end
              item
                Caption = 'Module'
                Width = 140
              end
              item
                Caption = 'Description'
                Width = 400
              end
              item
                Caption = 'Status'
                Width = 70
              end>
            ReadOnly = True
            RowSelect = True
            TabOrder = 0
            ViewStyle = vsReport
          end
          object pnlDtcButtons: TPanel
            Left = 8
            Top = 381
            Width = 731
            Height = 44
            Align = alBottom
            BevelOuter = bvNone
            TabOrder = 1
            object btnReadDtcs: TButton
              Left = 0
              Top = 10
              Width = 130
              Height = 26
              Caption = 'Read codes'
              TabOrder = 0
              OnClick = btnReadDtcsClick
            end
            object btnClearDtcs: TButton
              Left = 136
              Top = 10
              Width = 130
              Height = 26
              Caption = 'Clear codes'
              TabOrder = 1
              OnClick = btnClearDtcsClick
            end
          end
        end
      end
      object tsTools: TTabSheet
        Caption = 'Tools'
        ImageIndex = 2
        object gbPcm: TGroupBox
          Left = 12
          Top = 12
          Width = 560
          Height = 66
          Caption = ' PCM functions '
          TabOrder = 0
          object btnResetLtft: TButton
            Left = 12
            Top = 26
            Width = 150
            Height = 26
            Caption = 'Reset fuel trims'
            TabOrder = 0
            OnClick = btnResetLtftClick
          end
          object btnCelOn: TButton
            Left = 168
            Top = 26
            Width = 150
            Height = 26
            Caption = 'Check engine light on'
            TabOrder = 1
            OnClick = btnCelOnClick
          end
          object btnCelOff: TButton
            Left = 324
            Top = 26
            Width = 150
            Height = 26
            Caption = 'Check engine light off'
            TabOrder = 2
            OnClick = btnCelOffClick
          end
        end
        object gbWriteVin: TGroupBox
          Left = 12
          Top = 88
          Width = 560
          Height = 66
          Caption = ' Write VIN '
          TabOrder = 1
          object edtNewVin: TEdit
            Left = 12
            Top = 27
            Width = 240
            Height = 23
            CharCase = ecUpperCase
            MaxLength = 17
            TabOrder = 0
            TextHint = '17-character VIN'
          end
          object btnWriteVin: TButton
            Left = 260
            Top = 26
            Width = 120
            Height = 26
            Caption = 'Write VIN'
            TabOrder = 1
            OnClick = btnWriteVinClick
          end
        end
        object gbLogging: TGroupBox
          Left = 12
          Top = 164
          Width = 560
          Height = 66
          Caption = ' Logging '
          TabOrder = 2
          object lblLogFolderCaption: TLabel
            Left = 12
            Top = 31
            Width = 60
            Height = 15
            Caption = 'Log folder'
          end
          object edtLogFolder: TEdit
            Left = 80
            Top = 27
            Width = 370
            Height = 23
            TabOrder = 0
          end
          object btnBrowseLogFolder: TButton
            Left = 456
            Top = 26
            Width = 90
            Height = 26
            Caption = 'Browse...'
            TabOrder = 1
            OnClick = btnBrowseLogFolderClick
          end
        end
        object gbAdvanced: TGroupBox
          Left = 12
          Top = 240
          Width = 560
          Height = 130
          Caption = ' Advanced '
          TabOrder = 3
          object lblRaw: TLabel
            Left = 12
            Top = 24
            Width = 250
            Height = 15
            Caption = 'Raw AVT frame (hex, including header byte)'
          end
          object edtRaw: TEdit
            Left = 12
            Top = 44
            Width = 370
            Height = 23
            TabOrder = 0
            TextHint = 'e.g. 05 6C 10 F1 3C 01'
          end
          object btnSendRaw: TButton
            Left = 388
            Top = 43
            Width = 90
            Height = 26
            Caption = 'Send'
            TabOrder = 1
            OnClick = btnSendRawClick
          end
          object chkTrace: TCheckBox
            Left = 12
            Top = 78
            Width = 400
            Height = 17
            Caption = 'Show raw traffic in Messages (not stream data)'
            TabOrder = 2
            OnClick = chkTraceClick
          end
          object lblRate: TLabel
            Left = 12
            Top = 102
            Width = 120
            Height = 15
            Caption = 'Stream speed'
          end
          object cbRate: TComboBox
            Left = 140
            Top = 98
            Width = 240
            Height = 23
            Style = csDropDownList
            TabOrder = 3
            OnChange = cbRateChange
            Items.Strings = (
              'Fast (~10/s up to 24 bytes, ~5/s above)'
              'Medium'
              'Slow')
          end
        end
      end
      object tsMessages: TTabSheet
        Caption = 'Messages'
        ImageIndex = 3
        object memLog: TMemo
          Left = 0
          Top = 0
          Width = 759
          Height = 531
          Align = alClient
          BorderStyle = bsNone
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Consolas'
          Font.Style = []
          ParentFont = False
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
        end
        object pnlLogFooter: TPanel
          Left = 0
          Top = 531
          Width = 759
          Height = 40
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 1
          object btnClearMessages: TButton
            Left = 6
            Top = 7
            Width = 100
            Height = 26
            Caption = 'Clear'
            TabOrder = 0
            OnClick = btnClearMessagesClick
          end
        end
      end
    end
  end
  object sbMain: TStatusBar
    Left = 0
    Top = 697
    Width = 1180
    Height = 23
    Panels = <
      item
        Text = 'Disconnected'
        Width = 110
      end
      item
        Width = 110
      end
      item
        Width = 230
      end
      item
        Width = 150
      end
      item
        Width = 130
      end
      item
        Width = 50
      end>
  end
  object tmrRefresh: TTimer
    Interval = 100
    OnTimer = tmrRefreshTimer
    Left = 1100
    Top = 8
  end
end
