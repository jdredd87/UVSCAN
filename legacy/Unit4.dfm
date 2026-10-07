object Form4: TForm4
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'AUTONAME'
  ClientHeight = 276
  ClientWidth = 382
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  PixelsPerInch = 96
  TextHeight = 13
  object LabeledEdit1: TLabeledEdit
    Left = 8
    Top = 32
    Width = 366
    Height = 21
    EditLabel.Width = 87
    EditLabel.Height = 13
    EditLabel.Caption = 'Autoname Header'
    TabOrder = 0
  end
  object incit: TCheckBox
    Left = 8
    Top = 225
    Width = 97
    Height = 17
    Caption = 'Incremental'
    TabOrder = 1
  end
  object enable: TCheckBox
    Left = 8
    Top = 248
    Width = 97
    Height = 17
    Caption = 'Enabled'
    TabOrder = 2
  end
  object Button1: TButton
    Left = 122
    Top = 240
    Width = 75
    Height = 25
    Caption = 'APPLY'
    TabOrder = 3
    OnClick = Button1Click
  end
  object LabeledEdit2: TLabeledEdit
    Left = 8
    Top = 80
    Width = 366
    Height = 21
    EditLabel.Width = 93
    EditLabel.Height = 13
    EditLabel.Caption = 'Date / Time Header'
    TabOrder = 4
  end
  object LabeledEdit3: TLabeledEdit
    Left = 8
    Top = 136
    Width = 366
    Height = 21
    EditLabel.Width = 49
    EditLabel.Height = 13
    EditLabel.Caption = 'Save Path'
    TabOrder = 5
  end
end
