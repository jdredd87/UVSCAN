object GaugeEditorForm: TGaugeEditorForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Gauge'
  ClientHeight = 392
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblPid: TLabel
    Left = 12
    Top = 15
    Width = 19
    Height = 15
    Caption = 'PID'
  end
  object lblScale: TLabel
    Left = 12
    Top = 196
    Width = 54
    Height = 15
    Caption = 'Scale from'
  end
  object lblTo: TLabel
    Left = 152
    Top = 196
    Width = 11
    Height = 15
    Caption = 'to'
  end
  object lblHelp: TLabel
    Left = 12
    Top = 232
    Width = 290
    Height = 96
    AutoSize = False
    Caption =
      'The coloured bands, the card colour, flashing and sounds come fr' +
      'om the PID'#39's alert levels - the same ones the live grid uses. Se' +
      't them with Display & alerts (right-click a PID or a gauge).'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ShowAccelChar = False
    WordWrap = True
  end
  object lblPreview: TLabel
    Left = 320
    Top = 334
    Width = 74
    Height = 15
    Caption = 'Preview value'
  end
  object cbPid: TComboBox
    Left = 44
    Top = 11
    Width = 258
    Height = 23
    Style = csDropDownList
    DropDownCount = 24
    TabOrder = 0
    OnChange = cbPidChange
  end
  object rgStyle: TRadioGroup
    Left = 12
    Top = 46
    Width = 290
    Height = 64
    Caption = 'Style'
    Columns = 3
    TabOrder = 1
    OnClick = SettingChange
  end
  object rgSize: TRadioGroup
    Left = 12
    Top = 118
    Width = 290
    Height = 64
    Caption = 'Size'
    Columns = 3
    TabOrder = 2
    OnClick = SettingChange
  end
  object edtMin: TEdit
    Left = 76
    Top = 192
    Width = 68
    Height = 23
    TabOrder = 3
    OnChange = SettingChange
  end
  object edtMax: TEdit
    Left = 172
    Top = 192
    Width = 68
    Height = 23
    TabOrder = 4
    OnChange = SettingChange
  end
  object btnSuggest: TButton
    Left = 246
    Top = 191
    Width = 56
    Height = 25
    Hint = 'Suggest a scale for this PID'
    Caption = 'Auto'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 5
    OnClick = btnSuggestClick
  end
  object pnlPreview: TPanel
    Left = 320
    Top = 11
    Width = 308
    Height = 312
    BevelOuter = bvNone
    Color = clWindow
    ParentBackground = False
    TabOrder = 6
  end
  object tbPreview: TTrackBar
    Left = 400
    Top = 330
    Width = 228
    Height = 24
    Max = 100
    TabOrder = 7
    ThumbLength = 16
    TickStyle = tsNone
    OnChange = SettingChange
  end
  object btnOK: TButton
    Left = 452
    Top = 358
    Width = 85
    Height = 26
    Caption = 'OK'
    Default = True
    TabOrder = 8
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 543
    Top = 358
    Width = 85
    Height = 26
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 9
  end
  object tmrFlash: TTimer
    Interval = 500
    OnTimer = tmrFlashTimer
    Left = 24
    Top = 340
  end
end
