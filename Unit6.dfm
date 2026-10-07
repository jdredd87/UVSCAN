object Form6: TForm6
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'PID Edit'
  ClientHeight = 277
  ClientWidth = 410
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poMainFormCenter
  ShowHint = True
  OnClose = FormClose
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 17
    Width = 82
    Height = 19
    Caption = 'Row Height'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object Label2: TLabel
    Left = 8
    Top = 52
    Width = 64
    Height = 19
    Caption = 'Font Size'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object Label3: TLabel
    Left = 192
    Top = 52
    Width = 74
    Height = 19
    Caption = 'Font Color'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object Label4: TLabel
    Left = 192
    Top = 17
    Width = 74
    Height = 19
    Caption = 'Row Color'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object Label5: TLabel
    Left = 128
    Top = 121
    Width = 138
    Height = 19
    Caption = 'Warning Font Color'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object Label6: TLabel
    Left = 128
    Top = 85
    Width = 138
    Height = 19
    Caption = 'Warning Row Color'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object Label7: TLabel
    Left = 159
    Top = 160
    Width = 99
    Height = 19
    Caption = 'Filter Warning'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object SpinEdit1: TSpinEdit
    Left = 96
    Top = 8
    Width = 81
    Height = 29
    Hint = 'Grid row height'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    MaxValue = 100
    MinValue = 0
    ParentFont = False
    TabOrder = 0
    Value = 0
    OnChange = SpinEdit1Change
  end
  object SpinEdit2: TSpinEdit
    Left = 96
    Top = 49
    Width = 81
    Height = 29
    Hint = 'Grid row font size'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    MaxValue = 70
    MinValue = -20
    ParentFont = False
    TabOrder = 1
    Value = 0
    OnChange = SpinEdit2Change
  end
  object Button1: TButton
    Left = 272
    Top = 17
    Width = 33
    Height = 19
    Hint = 'Change PID row color'
    Caption = 'Color'
    TabOrder = 2
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 272
    Top = 52
    Width = 33
    Height = 19
    Hint = 'Change PID row color'
    Caption = 'Color'
    TabOrder = 3
    OnClick = Button2Click
  end
  object edit1: TEdit
    Left = 311
    Top = 17
    Width = 34
    Height = 21
    ReadOnly = True
    TabOrder = 4
    Text = 'Color'
  end
  object Edit2: TEdit
    Left = 311
    Top = 51
    Width = 34
    Height = 21
    ReadOnly = True
    TabOrder = 5
    Text = 'Color'
  end
  object Formula: TLabeledEdit
    Left = 8
    Top = 197
    Width = 394
    Height = 21
    Hint = 'PID formula'
    CharCase = ecUpperCase
    EditLabel.Width = 38
    EditLabel.Height = 13
    EditLabel.Caption = 'Formula'
    TabOrder = 6
    OnChange = FormulaChange
  end
  object Result: TLabeledEdit
    Left = 8
    Top = 240
    Width = 64
    Height = 21
    Hint = 'PID result format'
    CharCase = ecLowerCase
    EditLabel.Width = 67
    EditLabel.Height = 13
    EditLabel.Caption = 'Result Format'
    TabOrder = 7
    OnChange = ResultChange
  end
  object Button3: TButton
    Left = 167
    Top = 237
    Width = 91
    Height = 25
    Caption = 'SAVE SETTINGS'
    TabOrder = 8
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 352
    Top = 237
    Width = 50
    Height = 25
    Caption = 'RESET'
    TabOrder = 9
    OnClick = Button4Click
  end
  object Button5: TButton
    Left = 272
    Top = 89
    Width = 33
    Height = 19
    Hint = 'Change PID row color'
    Caption = 'Color'
    TabOrder = 10
    OnClick = Button5Click
  end
  object Button6: TButton
    Left = 272
    Top = 124
    Width = 33
    Height = 19
    Hint = 'Change PID row color'
    Caption = 'Color'
    TabOrder = 11
    OnClick = Button6Click
  end
  object Edit3: TEdit
    Left = 311
    Top = 89
    Width = 34
    Height = 21
    ReadOnly = True
    TabOrder = 12
    Text = 'Color'
  end
  object Edit4: TEdit
    Left = 311
    Top = 123
    Width = 34
    Height = 21
    ReadOnly = True
    TabOrder = 13
    Text = 'Color'
  end
  object spinedit3: TEdit
    Left = 272
    Top = 162
    Width = 73
    Height = 21
    TabOrder = 14
    Text = '200000'
    OnChange = SpinEdit3Change
  end
  object CheckBox1: TCheckBox
    Left = 8
    Top = 152
    Width = 113
    Height = 17
    Caption = 'Auto Open Window'
    TabOrder = 15
  end
  object colord: TColorDialog
    CustomColors.Strings = (
      'ColorA=FFFFFFFF'
      'ColorB=FFFFFFFF'
      'ColorC=FFFFFFFF'
      'ColorD=FFFFFFFF'
      'ColorE=FFFFFFFF'
      'ColorF=FFFFFFFF'
      'ColorG=FFFFFFFF'
      'ColorH=FFFFFFFF'
      'ColorI=FFFFFFFF'
      'ColorJ=FFFFFFFF'
      'ColorK=FFFFFFFF'
      'ColorL=FFFFFFFF'
      'ColorM=FFFFFFFF'
      'ColorN=FFFFFFFF'
      'ColorO=FFFFFFFF'
      'ColorP=FFFFFFFF')
    Options = [cdFullOpen, cdSolidColor, cdAnyColor]
    Left = 360
    Top = 16
  end
end
