object ControlEditorForm: TControlEditorForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Real-time control'
  ClientHeight = 598
  ClientWidth = 620
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblName: TLabel
    Left = 12
    Top = 15
    Width = 32
    Height = 15
    Caption = 'Name'
  end
  object lblGroup: TLabel
    Left = 376
    Top = 15
    Width = 33
    Height = 15
    Caption = 'Group'
  end
  object lblModule: TLabel
    Left = 12
    Top = 110
    Width = 41
    Height = 15
    Caption = 'Module'
  end
  object lblOn: TLabel
    Left = 12
    Top = 142
    Width = 67
    Height = 15
    Caption = 'On command'
  end
  object lblOff: TLabel
    Left = 12
    Top = 174
    Width = 69
    Height = 15
    Caption = 'Off command'
  end
  object lblHelp: TLabel
    Left = 110
    Top = 198
    Width = 498
    Height = 48
    AutoSize = False
    Caption =
      'Hex bytes, mode byte first, e.g. AE 01 80 80 00 00 00 00 for GM ' +
      'device control. The header (priority, module, tester address) is' +
      ' added for you. In a value control {V} is one byte and {V16} two' +
      ' bytes, high first: raw = (value - offset) / scale.'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ShowAccelChar = False
    WordWrap = True
  end
  object lblConfirm: TLabel
    Left = 12
    Top = 350
    Width = 45
    Height = 15
    Caption = 'Ask first'
  end
  object lblNotes: TLabel
    Left = 12
    Top = 382
    Width = 31
    Height = 15
    Caption = 'Notes'
  end
  object lblSendsCaption: TLabel
    Left = 12
    Top = 452
    Width = 51
    Height = 15
    Caption = 'Will send'
  end
  object lblSends: TLabel
    Left = 110
    Top = 452
    Width = 498
    Height = 48
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ShowAccelChar = False
  end
  object lblProblem: TLabel
    Left = 110
    Top = 504
    Width = 498
    Height = 40
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clRed
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ShowAccelChar = False
    WordWrap = True
  end
  object edtName: TEdit
    Left = 110
    Top = 11
    Width = 250
    Height = 23
    TabOrder = 0
    OnChange = Changed
  end
  object cbGroup: TComboBox
    Left = 420
    Top = 11
    Width = 188
    Height = 23
    TabOrder = 1
    TextHint = 'e.g. Outputs, Resets'
    OnChange = Changed
  end
  object rgKind: TRadioGroup
    Left = 12
    Top = 44
    Width = 596
    Height = 50
    Caption = 'Type'
    Columns = 4
    TabOrder = 2
    OnClick = Changed
  end
  object cbModule: TComboBox
    Left = 110
    Top = 106
    Width = 250
    Height = 23
    TabOrder = 3
    OnChange = Changed
  end
  object edtOn: TEdit
    Left = 110
    Top = 138
    Width = 498
    Height = 23
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    TabOrder = 4
    TextHint = 'AE 01 80 80 00 00 00 00'
    OnChange = Changed
  end
  object edtOff: TEdit
    Left = 110
    Top = 170
    Width = 498
    Height = 23
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    TabOrder = 5
    TextHint = 'AE 01 00 00 00 00 00 00'
    OnChange = Changed
  end
  object gbValue: TGroupBox
    Left = 12
    Top = 250
    Width = 596
    Height = 86
    Caption = 'Value control'
    TabOrder = 6
    object lblMin: TLabel
      Left = 12
      Top = 28
      Width = 21
      Height = 15
      Caption = 'Min'
    end
    object lblMax: TLabel
      Left = 136
      Top = 28
      Width = 23
      Height = 15
      Caption = 'Max'
    end
    object lblStep: TLabel
      Left = 256
      Top = 28
      Width = 23
      Height = 15
      Caption = 'Step'
    end
    object lblUnits: TLabel
      Left = 366
      Top = 28
      Width = 27
      Height = 15
      Caption = 'Units'
    end
    object lblScale: TLabel
      Left = 12
      Top = 58
      Width = 27
      Height = 15
      Caption = 'Scale'
    end
    object lblOffset: TLabel
      Left = 136
      Top = 58
      Width = 32
      Height = 15
      Caption = 'Offset'
    end
    object edtMin: TEdit
      Left = 52
      Top = 24
      Width = 70
      Height = 23
      TabOrder = 0
      OnChange = Changed
    end
    object edtMax: TEdit
      Left = 172
      Top = 24
      Width = 70
      Height = 23
      TabOrder = 1
      OnChange = Changed
    end
    object edtStep: TEdit
      Left = 292
      Top = 24
      Width = 60
      Height = 23
      TabOrder = 2
      OnChange = Changed
    end
    object edtUnits: TEdit
      Left = 404
      Top = 24
      Width = 70
      Height = 23
      TabOrder = 3
      OnChange = Changed
    end
    object edtScale: TEdit
      Left = 52
      Top = 54
      Width = 70
      Height = 23
      TabOrder = 4
      OnChange = Changed
    end
    object edtOffset: TEdit
      Left = 182
      Top = 54
      Width = 70
      Height = 23
      TabOrder = 5
      OnChange = Changed
    end
  end
  object edtConfirm: TEdit
    Left = 110
    Top = 346
    Width = 498
    Height = 23
    TabOrder = 7
    TextHint = 'Question asked before sending, e.g. "Reset the learned fuel trims?" (empty = none)'
    OnChange = Changed
  end
  object memNotes: TMemo
    Left = 110
    Top = 378
    Width = 498
    Height = 60
    ScrollBars = ssVertical
    TabOrder = 8
    OnChange = Changed
  end
  object btnOK: TButton
    Left = 432
    Top = 560
    Width = 85
    Height = 26
    Caption = 'OK'
    Default = True
    TabOrder = 9
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 523
    Top = 560
    Width = 85
    Height = 26
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 10
  end
end
