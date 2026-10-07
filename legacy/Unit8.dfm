object Form8: TForm8
  Left = 0
  Top = 0
  Caption = 'PIDWINDOW'
  ClientHeight = 119
  ClientWidth = 171
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PopupMenu = PopupMenu1
  DesignSize = (
    171
    119)
  PixelsPerInch = 96
  TextHeight = 13
  object ptitle: TLabel
    Left = 0
    Top = 0
    Width = 171
    Height = 24
    Alignment = taCenter
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = 'Title'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -20
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    Transparent = False
    Layout = tlCenter
    ExplicitWidth = 153
  end
  object value: TLabel
    Left = 0
    Top = 47
    Width = 171
    Height = 25
    Alignment = taCenter
    Anchors = [akLeft, akRight]
    AutoSize = False
    Caption = '--'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -20
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object units: TLabel
    Left = 0
    Top = 95
    Width = 171
    Height = 24
    Alignment = taCenter
    Anchors = [akLeft, akRight, akBottom]
    AutoSize = False
    Caption = 'Unit'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -20
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object PopupMenu1: TPopupMenu
    Left = 136
    Top = 24
    object ModifyPIDRowWindow1: TMenuItem
      Caption = 'Modify PID Row/Window'
      OnClick = ModifyPIDRowWindow1Click
    end
    object HideAllPIDWindows1: TMenuItem
      Caption = 'Hide All PID Windows'
      OnClick = HideAllPIDWindows1Click
    end
    object SaveLocations1: TMenuItem
      Caption = 'Save Locations'
      OnClick = SaveLocations1Click
    end
  end
end
