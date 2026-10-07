object MainMDI: TMainMDI
  Left = 0
  Top = 0
  Caption = 'UVSCANNER'
  ClientHeight = 301
  ClientWidth = 467
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsMDIForm
  Menu = MainMenu1
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 32
    Top = 32
    Width = 75
    Height = 25
    Caption = 'Button1'
    TabOrder = 0
    OnClick = Button1Click
  end
  object MainMenu1: TMainMenu
    Left = 288
    Top = 72
    object Connect1: TMenuItem
      Caption = '&Connect'
      object Scanner1: TMenuItem
        Caption = '&Scanner'
        OnClick = Scanner1Click
      end
    end
  end
end
