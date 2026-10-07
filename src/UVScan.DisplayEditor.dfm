object DisplayEditorForm: TDisplayEditorForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Display & alerts'
  ClientHeight = 600
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object lblPid: TLabel
    Left = 12
    Top = 10
    Width = 610
    Height = 20
    AutoSize = False
    Caption = 'PID'
    EllipsisPosition = epEndEllipsis
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -15
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    ShowAccelChar = False
  end
  object lblHelp: TLabel
    Left = 12
    Top = 34
    Width = 616
    Height = 32
    AutoSize = False
    Caption =
      'How this PID looks in the live grid and on the dashboard. Alert ' +
      'levels change the colours, flash the row or gauge and sound an a' +
      'larm when the value crosses a threshold.'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ShowAccelChar = False
    WordWrap = True
  end
  object gbNormal: TGroupBox
    Left = 12
    Top = 70
    Width = 616
    Height = 62
    Caption = 'Normal look'
    TabOrder = 0
    object lblFontSize: TLabel
      Left = 12
      Top = 27
      Width = 81
      Height = 15
      Caption = 'Value font size'
    end
    object lblTextColor: TLabel
      Left = 212
      Top = 27
      Width = 57
      Height = 15
      Caption = 'Text colour'
    end
    object lblRowColor: TLabel
      Left = 418
      Top = 27
      Width = 58
      Height = 15
      Caption = 'Row colour'
    end
    object cbFontSize: TComboBox
      Left = 104
      Top = 23
      Width = 90
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      OnChange = NormalChange
    end
    object cbxText: TColorBox
      Left = 278
      Top = 23
      Width = 124
      Height = 22
      TabOrder = 1
      OnChange = NormalChange
    end
    object cbxRow: TColorBox
      Left = 484
      Top = 23
      Width = 120
      Height = 22
      TabOrder = 2
      OnChange = NormalChange
    end
  end
  object gbLevels: TGroupBox
    Left = 12
    Top = 140
    Width = 616
    Height = 330
    Caption = 'Alert levels - checked from the top, the first that matches is used'
    TabOrder = 1
    object lblLevelName: TLabel
      Left = 12
      Top = 168
      Width = 32
      Height = 15
      Caption = 'Name'
    end
    object lblWhen: TLabel
      Left = 262
      Top = 168
      Width = 78
      Height = 15
      Caption = 'When value is'
    end
    object lblLevelRow: TLabel
      Left = 12
      Top = 200
      Width = 58
      Height = 15
      Caption = 'Row colour'
    end
    object lblLevelText: TLabel
      Left = 262
      Top = 200
      Width = 57
      Height = 15
      Caption = 'Text colour'
    end
    object lblSound: TLabel
      Left = 12
      Top = 262
      Width = 34
      Height = 15
      Caption = 'Sound'
    end
    object lvLevels: TListView
      Left = 12
      Top = 22
      Width = 490
      Height = 132
      Columns = <
        item
          Caption = 'Name'
          Width = 110
        end
        item
          Caption = 'When'
          Width = 80
        end
        item
          Caption = 'Colours'
          Width = 80
        end
        item
          Caption = 'Flash'
          Width = 50
        end
        item
          Caption = 'Sound'
          Width = 145
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnCustomDrawSubItem = lvLevelsCustomDrawSubItem
      OnSelectItem = lvLevelsSelectItem
    end
    object btnAddLevel: TButton
      Left = 512
      Top = 22
      Width = 92
      Height = 25
      Caption = 'Add'
      TabOrder = 1
      OnClick = btnAddLevelClick
    end
    object btnDeleteLevel: TButton
      Left = 512
      Top = 51
      Width = 92
      Height = 25
      Caption = 'Remove'
      TabOrder = 2
      OnClick = btnDeleteLevelClick
    end
    object btnUp: TButton
      Left = 512
      Top = 80
      Width = 92
      Height = 25
      Caption = 'Move up'
      TabOrder = 3
      OnClick = btnUpClick
    end
    object btnDown: TButton
      Left = 512
      Top = 109
      Width = 92
      Height = 25
      Caption = 'Move down'
      TabOrder = 4
      OnClick = btnDownClick
    end
    object btnPresets: TButton
      Left = 512
      Top = 164
      Width = 92
      Height = 25
      Caption = 'Presets...'
      TabOrder = 15
      OnClick = btnPresetsClick
    end
    object edtLevelName: TEdit
      Left = 95
      Top = 164
      Width = 150
      Height = 23
      TabOrder = 5
      OnChange = LevelChange
    end
    object cbOp: TComboBox
      Left = 350
      Top = 164
      Width = 100
      Height = 23
      Style = csDropDownList
      TabOrder = 6
      OnChange = LevelChange
    end
    object edtValue: TEdit
      Left = 456
      Top = 164
      Width = 46
      Height = 23
      TabOrder = 7
      OnChange = LevelChange
    end
    object cbxLevelRow: TColorBox
      Left = 95
      Top = 196
      Width = 150
      Height = 22
      TabOrder = 8
      OnChange = LevelChange
    end
    object cbxLevelText: TColorBox
      Left = 350
      Top = 196
      Width = 152
      Height = 22
      TabOrder = 9
      OnChange = LevelChange
    end
    object chkFlash: TCheckBox
      Left = 95
      Top = 230
      Width = 300
      Height = 17
      Caption = 'Flash the row and gauge while the value is in this level'
      TabOrder = 10
      OnClick = LevelChange
    end
    object cbSound: TComboBox
      Left = 95
      Top = 258
      Width = 150
      Height = 23
      Style = csDropDownList
      TabOrder = 11
      OnChange = LevelChange
    end
    object edtSoundFile: TEdit
      Left = 251
      Top = 258
      Width = 251
      Height = 23
      TabOrder = 12
      TextHint = 'Sound file (.wav)'
      OnChange = LevelChange
    end
    object btnBrowseSound: TButton
      Left = 506
      Top = 257
      Width = 28
      Height = 25
      Caption = '...'
      TabOrder = 13
      OnClick = btnBrowseSoundClick
    end
    object btnTestSound: TButton
      Left = 538
      Top = 257
      Width = 66
      Height = 25
      Caption = 'Test'
      TabOrder = 14
      OnClick = btnTestSoundClick
    end
    object chkRepeat: TCheckBox
      Left = 95
      Top = 292
      Width = 440
      Height = 17
      Caption = 'Repeat the sound every few seconds while the value stays in this level'
      TabOrder = 16
      OnClick = LevelChange
    end
  end
  object gbPreview: TGroupBox
    Left = 12
    Top = 478
    Width = 616
    Height = 70
    Caption = 'Preview'
    TabOrder = 2
    object lblPreviewValue: TLabel
      Left = 12
      Top = 31
      Width = 28
      Height = 15
      Caption = 'Value'
    end
    object pbPreview: TPaintBox
      Left = 150
      Top = 20
      Width = 454
      Height = 40
      OnPaint = pbPreviewPaint
    end
    object edtPreview: TEdit
      Left = 50
      Top = 27
      Width = 86
      Height = 23
      TabOrder = 0
      TextHint = 'try a value'
      OnChange = edtPreviewChange
    end
  end
  object btnClear: TButton
    Left = 12
    Top = 562
    Width = 90
    Height = 26
    Caption = 'Clear all'
    TabOrder = 3
    OnClick = btnClearClick
  end
  object btnOK: TButton
    Left = 452
    Top = 562
    Width = 85
    Height = 26
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 4
  end
  object btnCancel: TButton
    Left = 543
    Top = 562
    Width = 85
    Height = 26
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 5
  end
  object tmrFlash: TTimer
    Interval = 500
    OnTimer = tmrFlashTimer
    Left = 300
    Top = 556
  end
  object pmPresets: TPopupMenu
    Left = 360
    Top = 556
    object miHighIsBad: TMenuItem
      Caption = 'Green / yellow / red - high values are bad (knock retard, temperatures)'
      OnClick = miHighIsBadClick
    end
    object miLowIsBad: TMenuItem
      Caption = 'Green / yellow / red - low values are bad (voltage, oil pressure)'
      OnClick = miLowIsBadClick
    end
  end
end
