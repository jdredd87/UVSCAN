object setup_form: Tsetup_form
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'Scanner SETUP'
  ClientHeight = 214
  ClientWidth = 428
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object VrGradient1: TVrGradient
    Left = 0
    Top = 0
    Width = 428
    Height = 214
    Align = alClient
    ExplicitWidth = 425
    ExplicitHeight = 297
  end
  object Label1: TLabel
    Left = 32
    Top = 64
    Width = 165
    Height = 22
    Caption = 'Available Comports'
    Font.Charset = ANSI_CHARSET
    Font.Color = clWhite
    Font.Height = -19
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    Transparent = True
  end
  object Label2: TLabel
    Left = 32
    Top = 117
    Width = 89
    Height = 22
    Caption = 'Baud Rate'
    Font.Charset = ANSI_CHARSET
    Font.Color = clWhite
    Font.Height = -19
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    Transparent = True
  end
  object Label3: TLabel
    Left = 319
    Top = 57
    Width = 85
    Height = 16
    Caption = 'Show All Ports'
    Font.Charset = ANSI_CHARSET
    Font.Color = clWhite
    Font.Height = -13
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    Transparent = True
  end
  object ComboBox1: TComboBox
    Left = 219
    Top = 56
    Width = 62
    Height = 30
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Arial'
    Font.Style = []
    ItemHeight = 22
    ItemIndex = 0
    ParentFont = False
    TabOrder = 0
    Text = '0'
    Items.Strings = (
      '0')
  end
  object ComboBox2: TComboBox
    Left = 176
    Top = 109
    Width = 105
    Height = 30
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Arial'
    Font.Style = []
    ItemHeight = 22
    ItemIndex = 0
    ParentFont = False
    TabOrder = 1
    Text = '115200'
    Items.Strings = (
      '115200'
      '57600')
  end
  object CheckBox1: TCheckBox
    Left = 299
    Top = 56
    Width = 14
    Height = 17
    TabOrder = 2
    OnClick = CheckBox1Click
  end
  object Button1: TButton
    Left = 176
    Top = 160
    Width = 89
    Height = 25
    Caption = 'Apply Changes'
    TabOrder = 3
    OnClick = Button1Click
  end
end
