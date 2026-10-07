object LogViewerForm: TLogViewerForm
  Left = 0
  Top = 0
  Caption = 'Log viewer'
  ClientHeight = 760
  ClientWidth = 1220
  Color = clBtnFace
  Constraints.MinHeight = 520
  Constraints.MinWidth = 900
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnResize = FormResize
  TextHeight = 15
  object pnlBar: TPanel
    Left = 0
    Top = 0
    Width = 1220
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblView: TLabel
      Left = 556
      Top = 12
      Width = 26
      Height = 15
      Caption = 'View'
    end
    object lblMode: TLabel
      Left = 928
      Top = 12
      Width = 32
      Height = 15
      Caption = 'Chart'
    end
    object btnOpen: TButton
      Left = 8
      Top = 7
      Width = 90
      Height = 26
      Caption = 'Open log...'
      TabOrder = 0
      OnClick = btnOpenClick
    end
    object cbRecent: TComboBox
      Left = 104
      Top = 8
      Width = 280
      Height = 23
      Style = csDropDownList
      DropDownCount = 20
      TabOrder = 1
      OnChange = cbRecentChange
    end
    object btnDemo: TButton
      Left = 390
      Top = 7
      Width = 150
      Height = 26
      Hint = 'Open a made-up 10 minute drive to try the viewer'
      Caption = 'Demo drive (made up)'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      OnClick = btnDemoClick
    end
    object cbView: TComboBox
      Left = 588
      Top = 8
      Width = 170
      Height = 23
      Style = csDropDownList
      TabOrder = 3
      OnChange = cbViewChange
    end
    object btnSaveView: TButton
      Left = 762
      Top = 7
      Width = 90
      Height = 26
      Hint = 'Save the channels, colours, scales and levels as a named view'
      Caption = 'Save view...'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 4
      OnClick = btnSaveViewClick
    end
    object btnDeleteView: TButton
      Left = 856
      Top = 7
      Width = 60
      Height = 26
      Caption = 'Delete'
      TabOrder = 5
      OnClick = btnDeleteViewClick
    end
    object cbMode: TComboBox
      Left = 966
      Top = 8
      Width = 170
      Height = 23
      Style = csDropDownList
      TabOrder = 6
      OnChange = cbModeChange
    end
    object btnImage: TButton
      Left = 1142
      Top = 7
      Width = 72
      Height = 26
      Hint = 'Save the chart as a PNG picture'
      Caption = 'Image...'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 7
      OnClick = btnImageClick
    end
  end
  object pnlPlay: TPanel
    Left = 0
    Top = 40
    Width = 1220
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      1220
      40)
    object lblTime: TLabel
      Left = 650
      Top = 12
      Width = 110
      Height = 15
      AutoSize = False
      Caption = '0:00.0 / 0:00.0'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnStart: TButton
      Left = 8
      Top = 7
      Width = 34
      Height = 26
      Hint = 'Go to the start'
      Caption = '|<'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      OnClick = btnStartClick
    end
    object btnPlay: TButton
      Left = 46
      Top = 7
      Width = 70
      Height = 26
      Hint = 'Play / pause (Space)'
      Caption = 'Play'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      OnClick = btnPlayClick
    end
    object btnEnd: TButton
      Left = 120
      Top = 7
      Width = 34
      Height = 26
      Hint = 'Go to the end'
      Caption = '>|'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      OnClick = btnEndClick
    end
    object cbSpeed: TComboBox
      Left = 160
      Top = 8
      Width = 64
      Height = 23
      Hint = 'Playback speed'
      Style = csDropDownList
      ParentShowHint = False
      ShowHint = True
      TabOrder = 3
    end
    object tbPos: TTrackBar
      Left = 230
      Top = 7
      Width = 412
      Height = 26
      Max = 1000
      TabOrder = 4
      ThumbLength = 16
      TickStyle = tsNone
      OnChange = tbPosChange
    end
    object chkFollow: TCheckBox
      Left = 770
      Top = 11
      Width = 112
      Height = 17
      Hint = 'Scroll the chart to keep the cursor in view while playing'
      Caption = 'Follow cursor'
      Checked = True
      ParentShowHint = False
      ShowHint = True
      State = cbChecked
      TabOrder = 5
    end
    object chkBands: TCheckBox
      Left = 886
      Top = 11
      Width = 110
      Height = 17
      Hint = 'Shade the alert levels behind the lines'
      Caption = 'Level bands'
      Checked = True
      ParentShowHint = False
      ShowHint = True
      State = cbChecked
      TabOrder = 6
      OnClick = chkBandsClick
    end
    object chkUseDisplay: TCheckBox
      Left = 1000
      Top = 11
      Width = 214
      Height = 17
      Hint = 'Use the alert levels set in Display && alerts for PIDs with the same name'
      Caption = 'Alert levels from Display && alerts'
      Checked = True
      ParentShowHint = False
      ShowHint = True
      State = cbChecked
      TabOrder = 7
      OnClick = chkUseDisplayClick
    end
  end
  object splLeft: TSplitter
    Left = 340
    Top = 80
    Width = 5
    Height = 657
    MinSize = 200
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 80
    Width = 340
    Height = 657
    Align = alLeft
    BevelOuter = bvNone
    Padding.Left = 6
    Padding.Bottom = 4
    TabOrder = 2
    object lvChannels: TListView
      Left = 6
      Top = 0
      Width = 294
      Height = 445
      Align = alClient
      Checkboxes = True
      Columns = <
        item
          Caption = 'Channel'
          Width = 112
        end
        item
          Alignment = taRightJustify
          Caption = 'Value'
          Width = 56
        end
        item
          Alignment = taRightJustify
          Caption = 'Min'
          Width = 50
        end
        item
          Alignment = taRightJustify
          Caption = 'Avg'
          Width = 54
        end
        item
          Alignment = taRightJustify
          Caption = 'Max'
          Width = 54
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnCustomDrawItem = lvChannelsCustomDrawItem
      OnCustomDrawSubItem = lvChannelsCustomDrawSubItem
      OnItemChecked = lvChannelsItemChecked
      OnSelectItem = lvChannelsSelectItem
    end
    object gbChannel: TGroupBox
      AlignWithMargins = True
      Left = 6
      Top = 451
      Width = 294
      Height = 202
      Margins.Left = 0
      Margins.Top = 6
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alBottom
      Caption = ' Channel '
      TabOrder = 1
      object lblColor: TLabel
        Left = 12
        Top = 27
        Width = 33
        Height = 15
        Caption = 'Colour'
      end
      object lblWidth: TLabel
        Left = 180
        Top = 27
        Width = 32
        Height = 15
        Caption = 'Width'
      end
      object lblMin: TLabel
        Left = 12
        Top = 89
        Width = 21
        Height = 15
        Caption = 'Min'
      end
      object lblMax: TLabel
        Left = 146
        Top = 89
        Width = 23
        Height = 15
        Caption = 'Max'
      end
      object lblLevelSource: TLabel
        Left = 12
        Top = 172
        Width = 270
        Height = 15
        AutoSize = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object cbxColor: TColorBox
        Left = 52
        Top = 23
        Width = 118
        Height = 22
        Style = [cbStandardColors, cbExtendedColors, cbCustomColor, cbPrettyNames]
        TabOrder = 0
        OnChange = ChannelSettingChange
      end
      object cbWidth: TComboBox
        Left = 218
        Top = 23
        Width = 64
        Height = 23
        Style = csDropDownList
        TabOrder = 1
        OnChange = ChannelSettingChange
      end
      object chkAuto: TCheckBox
        Left = 12
        Top = 60
        Width = 270
        Height = 17
        Caption = 'Scale automatically (whole log)'
        TabOrder = 2
        OnClick = ChannelSettingChange
      end
      object edtMin: TEdit
        Left = 40
        Top = 85
        Width = 90
        Height = 23
        TabOrder = 3
        OnChange = ChannelSettingChange
      end
      object edtMax: TEdit
        Left = 176
        Top = 85
        Width = 90
        Height = 23
        TabOrder = 4
        OnChange = ChannelSettingChange
      end
      object chkLevelColors: TCheckBox
        Left = 12
        Top = 118
        Width = 270
        Height = 17
        Caption = 'Colour the line by alert level'
        TabOrder = 5
        OnClick = ChannelSettingChange
      end
      object btnLevels: TButton
        Left = 12
        Top = 141
        Width = 130
        Height = 26
        Hint = 'Alert levels of this channel in this view'
        Caption = 'Alert levels...'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
        OnClick = btnLevelsClick
      end
    end
  end
  object pnlMain: TPanel
    Left = 345
    Top = 80
    Width = 915
    Height = 657
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 3
    object splChart: TSplitter
      Left = 0
      Top = 400
      Width = 915
      Height = 5
      Cursor = crVSplit
      Align = alTop
      MinSize = 80
    end
    object grdLog: TDrawGrid
      Left = 0
      Top = 405
      Width = 915
      Height = 252
      Align = alClient
      BorderStyle = bsNone
      ColCount = 2
      DefaultDrawing = False
      DefaultRowHeight = 22
      RowCount = 2
      Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect, goThumbTracking]
      TabOrder = 0
      OnDrawCell = grdLogDrawCell
      OnSelectCell = grdLogSelectCell
    end
  end
  object sbLog: TStatusBar
    Left = 0
    Top = 737
    Width = 1220
    Height = 23
    Panels = <
      item
        Width = 520
      end
      item
        Width = 380
      end
      item
        Width = 50
      end>
  end
  object tmrPlay: TTimer
    Enabled = False
    Interval = 40
    OnTimer = tmrPlayTimer
    Left = 1160
    Top = 8
  end
end
