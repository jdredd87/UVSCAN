object Form5: TForm5
  Left = 0
  Top = 0
  Caption = 'Logcolor JR'
  ClientHeight = 454
  ClientWidth = 692
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 692
    Height = 454
    ActivePage = TabSheet2
    Align = alClient
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'DATA'
      object logview: TAdvStringGrid
        Left = 0
        Top = 0
        Width = 684
        Height = 426
        Cursor = crDefault
        Align = alClient
        DefaultRowHeight = 21
        FixedCols = 0
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = []
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goDrawFocusSelected, goRowSizing, goColSizing]
        ParentFont = False
        PopupMenu = PopupMenu1
        ScrollBars = ssBoth
        TabOrder = 0
        ActiveCellFont.Charset = DEFAULT_CHARSET
        ActiveCellFont.Color = clWindowText
        ActiveCellFont.Height = -11
        ActiveCellFont.Name = 'Tahoma'
        ActiveCellFont.Style = [fsBold]
        ControlLook.FixedGradientHoverFrom = clGray
        ControlLook.FixedGradientHoverTo = clWhite
        ControlLook.FixedGradientDownFrom = clGray
        ControlLook.FixedGradientDownTo = clSilver
        ControlLook.DropDownHeader.Font.Charset = DEFAULT_CHARSET
        ControlLook.DropDownHeader.Font.Color = clWindowText
        ControlLook.DropDownHeader.Font.Height = -11
        ControlLook.DropDownHeader.Font.Name = 'Tahoma'
        ControlLook.DropDownHeader.Font.Style = []
        ControlLook.DropDownHeader.Visible = True
        ControlLook.DropDownHeader.Buttons = <>
        ControlLook.DropDownFooter.Font.Charset = DEFAULT_CHARSET
        ControlLook.DropDownFooter.Font.Color = clWindowText
        ControlLook.DropDownFooter.Font.Height = -11
        ControlLook.DropDownFooter.Font.Name = 'Tahoma'
        ControlLook.DropDownFooter.Font.Style = []
        ControlLook.DropDownFooter.Visible = True
        ControlLook.DropDownFooter.Buttons = <>
        Filter = <>
        FilterDropDown.Font.Charset = DEFAULT_CHARSET
        FilterDropDown.Font.Color = clWindowText
        FilterDropDown.Font.Height = -11
        FilterDropDown.Font.Name = 'Tahoma'
        FilterDropDown.Font.Style = []
        FilterDropDownClear = '(All)'
        FixedFont.Charset = DEFAULT_CHARSET
        FixedFont.Color = clWindowText
        FixedFont.Height = -11
        FixedFont.Name = 'Tahoma'
        FixedFont.Style = [fsBold]
        FloatFormat = '%.2f'
        PrintSettings.DateFormat = 'dd/mm/yyyy'
        PrintSettings.Font.Charset = DEFAULT_CHARSET
        PrintSettings.Font.Color = clWindowText
        PrintSettings.Font.Height = -11
        PrintSettings.Font.Name = 'Tahoma'
        PrintSettings.Font.Style = []
        PrintSettings.FixedFont.Charset = DEFAULT_CHARSET
        PrintSettings.FixedFont.Color = clWindowText
        PrintSettings.FixedFont.Height = -11
        PrintSettings.FixedFont.Name = 'Tahoma'
        PrintSettings.FixedFont.Style = []
        PrintSettings.HeaderFont.Charset = DEFAULT_CHARSET
        PrintSettings.HeaderFont.Color = clWindowText
        PrintSettings.HeaderFont.Height = -11
        PrintSettings.HeaderFont.Name = 'Tahoma'
        PrintSettings.HeaderFont.Style = []
        PrintSettings.FooterFont.Charset = DEFAULT_CHARSET
        PrintSettings.FooterFont.Color = clWindowText
        PrintSettings.FooterFont.Height = -11
        PrintSettings.FooterFont.Name = 'Tahoma'
        PrintSettings.FooterFont.Style = []
        PrintSettings.PageNumSep = '/'
        ScrollWidth = 16
        SearchFooter.FindNextCaption = 'Find next'
        SearchFooter.FindPrevCaption = 'Find previous'
        SearchFooter.Font.Charset = DEFAULT_CHARSET
        SearchFooter.Font.Color = clWindowText
        SearchFooter.Font.Height = -11
        SearchFooter.Font.Name = 'Tahoma'
        SearchFooter.Font.Style = []
        SearchFooter.HighLightCaption = 'Highlight'
        SearchFooter.HintClose = 'Close'
        SearchFooter.HintFindNext = 'Find next occurence'
        SearchFooter.HintFindPrev = 'Find previous occurence'
        SearchFooter.HintHighlight = 'Highlight occurences'
        SearchFooter.MatchCaseCaption = 'Match case'
        Version = '6.1.0.0'
        ColWidths = (
          64
          64
          64
          64
          64)
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'GRAPHS'
      ImageIndex = 1
      DesignSize = (
        684
        426)
      object GroupBox1: TGroupBox
        Left = 0
        Top = 350
        Width = 682
        Height = 73
        Anchors = [akLeft, akRight, akBottom]
        Caption = '[ Chart Options ]'
        TabOrder = 0
        object CheckBox1: TCheckBox
          Left = 3
          Top = 16
          Width = 66
          Height = 17
          Caption = '3D View'
          TabOrder = 0
          OnClick = CheckBox1Click
        end
        object fstart: TLabeledEdit
          Left = 75
          Top = 31
          Width = 54
          Height = 21
          EditLabel.Width = 51
          EditLabel.Height = 13
          EditLabel.Caption = 'Filter Start'
          TabOrder = 1
        end
        object fend: TLabeledEdit
          Left = 135
          Top = 31
          Width = 54
          Height = 21
          EditLabel.Width = 45
          EditLabel.Height = 13
          EditLabel.Caption = 'Filter End'
          TabOrder = 2
        end
        object ComboBox1: TComboBox
          Left = 528
          Top = 16
          Width = 151
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          TabOrder = 3
        end
        object ComboBox2: TComboBox
          Left = 528
          Top = 43
          Width = 151
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          TabOrder = 4
        end
        object ComboBox3: TComboBox
          Left = 416
          Top = 16
          Width = 106
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          TabOrder = 5
          Items.Strings = (
            'Line Graph'
            'Point Graph')
        end
        object Button1: TButton
          Left = 210
          Top = 13
          Width = 63
          Height = 25
          Caption = 'NEW PLOT'
          TabOrder = 6
          OnClick = Button1Click
        end
        object Button2: TButton
          Left = 279
          Top = 13
          Width = 75
          Height = 25
          Caption = 'ADD SERIES'
          TabOrder = 7
          OnClick = Button2Click
        end
      end
      object Chart1: TChart
        Left = 0
        Top = 3
        Width = 681
        Height = 340
        LeftWall.Color = 16744448
        Legend.Visible = False
        Title.Text.Strings = (
          'TChart')
        Title.Visible = False
        View3D = False
        Align = alCustom
        TabOrder = 1
        Anchors = [akLeft, akTop, akRight, akBottom]
        ColorPaletteIndex = 13
      end
    end
  end
  object MainMenu1: TMainMenu
    Left = 136
    Top = 104
    object File1: TMenuItem
      Caption = '&File'
      object SavetoHTML1: TMenuItem
        Caption = '&Save to HTML'
        OnClick = SavetoHTML1Click
      end
      object Exit1: TMenuItem
        Caption = '&Exit'
      end
    end
    object Graph1: TMenuItem
      Caption = '&Graph'
      object LineGraph1: TMenuItem
        Caption = 'Line Graph'
      end
    end
    object Settings1: TMenuItem
      Caption = 'Settings'
      object HTML1: TMenuItem
        Caption = 'HTML'
        OnClick = HTML1Click
      end
    end
  end
  object PopupMenu1: TPopupMenu
    Left = 168
    Top = 104
    object SortbyColumn1: TMenuItem
      Caption = 'Sort by Column'
      OnClick = SortbyColumn1Click
    end
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = '*.html'
    Filter = 'HTML|*.HTML'
    Left = 200
    Top = 104
  end
  object htmld: TAdvGridHTMLSettingsDialog
    Grid = logview
    Options = [hoGeneral, hoCells, hoTags, hoFiles]
    Left = 232
    Top = 104
  end
end
