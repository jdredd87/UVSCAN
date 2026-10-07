object PidEditorForm: TPidEditorForm
  Left = 0
  Top = 0
  Caption = 'PID definitions'
  ClientHeight = 660
  ClientWidth = 1090
  Color = clBtnFace
  Constraints.MinHeight = 520
  Constraints.MinWidth = 960
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object splMain: TSplitter
    Left = 480
    Top = 0
    Width = 5
    Height = 512
    MinSize = 300
  end
  object pnlList: TPanel
    Left = 0
    Top = 0
    Width = 480
    Height = 512
    Align = alLeft
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Top = 8
    Padding.Right = 4
    TabOrder = 0
    object edtFilter: TEdit
      AlignWithMargins = True
      Left = 8
      Top = 8
      Width = 468
      Height = 23
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 6
      Align = alTop
      TabOrder = 0
      TextHint = 'Filter by id, name, PID or MCI...'
      OnChange = edtFilterChange
    end
    object lvList: TListView
      Left = 8
      Top = 37
      Width = 468
      Height = 431
      Align = alClient
      Columns = <
        item
          Caption = 'ID'
          Width = 45
        end
        item
          Caption = 'Name'
          Width = 180
        end
        item
          Caption = 'Kind'
          Width = 75
        end
        item
          Caption = 'PID'
          Width = 55
        end
        item
          Caption = 'Bytes'
          Width = 42
        end
        item
          Caption = 'Units'
          Width = 50
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 1
      ViewStyle = vsReport
      OnSelectItem = lvListSelectItem
    end
    object pnlListButtons: TPanel
      Left = 8
      Top = 468
      Width = 468
      Height = 44
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 2
      object btnAdd: TButton
        Left = 0
        Top = 10
        Width = 90
        Height = 26
        Caption = 'Add'
        TabOrder = 0
        OnClick = btnAddClick
      end
      object btnDuplicate: TButton
        Left = 96
        Top = 10
        Width = 90
        Height = 26
        Caption = 'Duplicate'
        TabOrder = 1
        OnClick = btnDuplicateClick
      end
      object btnDelete: TButton
        Left = 192
        Top = 10
        Width = 90
        Height = 26
        Caption = 'Delete'
        TabOrder = 2
        OnClick = btnDeleteClick
      end
      object btnImport: TButton
        Left = 296
        Top = 10
        Width = 80
        Height = 26
        Hint = 'Import an old UVSCAN PIDS.csv (replace or merge)'
        Caption = 'Import...'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        OnClick = btnImportClick
      end
      object btnDefaults: TButton
        Left = 382
        Top = 10
        Width = 86
        Height = 26
        Hint = 'Put the factory default PID definitions back'
        Caption = 'Defaults...'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
        OnClick = btnDefaultsClick
      end
    end
  end
  object pnlDetail: TPanel
    Left = 485
    Top = 0
    Width = 605
    Height = 512
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lblId: TLabel
      Left = 16
      Top = 19
      Width = 11
      Height = 15
      Caption = 'ID'
    end
    object edtId: TEdit
      Left = 110
      Top = 16
      Width = 80
      Height = 23
      NumbersOnly = True
      TabOrder = 0
      OnChange = FieldChanged
    end
    object chkEnabled: TCheckBox
      Left = 210
      Top = 19
      Width = 300
      Height = 17
      Caption = 'Enabled (offered in the scan list)'
      TabOrder = 1
      OnClick = FieldChanged
    end
    object lblName: TLabel
      Left = 16
      Top = 51
      Width = 32
      Height = 15
      Caption = 'Name'
    end
    object edtName: TEdit
      Left = 110
      Top = 48
      Width = 470
      Height = 23
      TabOrder = 2
      OnChange = FieldChanged
    end
    object lblShortName: TLabel
      Left = 16
      Top = 83
      Width = 64
      Height = 15
      Caption = 'Short name'
    end
    object edtShortName: TEdit
      Left = 110
      Top = 80
      Width = 190
      Height = 23
      TabOrder = 3
      TextHint = 'Used for log columns'
      OnChange = FieldChanged
    end
    object lblUnits: TLabel
      Left = 320
      Top = 83
      Width = 27
      Height = 15
      Caption = 'Units'
    end
    object edtUnits: TEdit
      Left = 390
      Top = 80
      Width = 190
      Height = 23
      TabOrder = 4
      OnChange = FieldChanged
    end
    object lblDescription: TLabel
      Left = 16
      Top = 115
      Width = 60
      Height = 15
      Caption = 'Description'
    end
    object edtDescription: TEdit
      Left = 110
      Top = 112
      Width = 470
      Height = 23
      TabOrder = 5
      OnChange = FieldChanged
    end
    object lblKind: TLabel
      Left = 16
      Top = 155
      Width = 24
      Height = 15
      Caption = 'Kind'
    end
    object cbKind: TComboBox
      Left = 110
      Top = 152
      Width = 190
      Height = 23
      Style = csDropDownList
      TabOrder = 6
      OnChange = FieldChanged
    end
    object lblCategory: TLabel
      Left = 320
      Top = 155
      Width = 48
      Height = 15
      Caption = 'Category'
    end
    object cbCategory: TComboBox
      Left = 390
      Top = 152
      Width = 190
      Height = 23
      Style = csDropDownList
      TabOrder = 7
      OnChange = FieldChanged
    end
    object lblPid: TLabel
      Left = 16
      Top = 187
      Width = 52
      Height = 15
      Caption = 'PID (hex)'
    end
    object edtPid: TEdit
      Left = 110
      Top = 184
      Width = 80
      Height = 23
      CharCase = ecUpperCase
      MaxLength = 6
      TabOrder = 8
      OnChange = FieldChanged
    end
    object lblBytes: TLabel
      Left = 210
      Top = 187
      Width = 29
      Height = 15
      Caption = 'Bytes'
    end
    object cbBytes: TComboBox
      Left = 250
      Top = 184
      Width = 50
      Height = 23
      Style = csDropDownList
      TabOrder = 9
      OnChange = FieldChanged
      Items.Strings = (
        '1'
        '2'
        '3'
        '4')
    end
    object lblChannel: TLabel
      Left = 320
      Top = 187
      Width = 80
      Height = 15
      Caption = 'Analog channel'
    end
    object cbChannel: TComboBox
      Left = 420
      Top = 184
      Width = 50
      Height = 23
      Style = csDropDownList
      TabOrder = 10
      OnChange = FieldChanged
      Items.Strings = (
        '1'
        '2'
        '3')
    end
    object lblFormula: TLabel
      Left = 16
      Top = 227
      Width = 44
      Height = 15
      Caption = 'Formula'
    end
    object edtFormula: TEdit
      Left = 110
      Top = 224
      Width = 470
      Height = 23
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      TabOrder = 11
      TextHint = 'e.g. ((N1 << 8) + N2) * 0.25   or   %IPW% * 2'
      OnChange = FieldChanged
    end
    object lblFormulaStatus: TLabel
      Left = 110
      Top = 251
      Width = 470
      Height = 30
      AutoSize = False
      Caption = 'Formula OK'
      ShowAccelChar = False
      WordWrap = True
    end
    object lblFormat: TLabel
      Left = 16
      Top = 291
      Width = 38
      Height = 15
      Caption = 'Format'
    end
    object cbFormat: TComboBox
      Left = 110
      Top = 288
      Width = 90
      Height = 23
      TabOrder = 12
      OnChange = FieldChanged
      Items.Strings = (
        ''
        '%f'
        '%d'
        '%o'
        '%y'
        '*c'
        '*f'
        '*f%d')
    end
    object lblFormatHelp: TLabel
      Left = 210
      Top = 291
      Width = 370
      Height = 15
      AutoSize = False
      Caption = '%f 2 decimals, %d whole, %o OFF/ON, %y NO/YES, *c F->C, *f C->F'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblMci: TLabel
      Left = 16
      Top = 323
      Width = 24
      Height = 15
      Caption = 'MCI'
    end
    object edtMci: TEdit
      Left = 110
      Top = 320
      Width = 190
      Height = 23
      CharCase = ecUpperCase
      TabOrder = 13
      OnChange = FieldChanged
    end
    object lblMciHelp: TLabel
      Left = 310
      Top = 323
      Width = 270
      Height = 15
      AutoSize = False
      Caption = 'Name other formulas use as %NAME% (unique)'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object gbTest: TGroupBox
      Left = 16
      Top = 362
      Width = 564
      Height = 92
      Caption = ' Try the formula '
      TabOrder = 14
      object lblTestInput: TLabel
        Left = 12
        Top = 31
        Width = 90
        Height = 15
        Caption = 'Data bytes (hex)'
      end
      object edtTestInput: TEdit
        Left = 160
        Top = 28
        Width = 250
        Height = 23
        TabOrder = 0
        OnChange = edtTestInputChange
      end
      object lblTestResultCaption: TLabel
        Left = 12
        Top = 62
        Width = 32
        Height = 15
        Caption = 'Result'
      end
      object lblTestResult: TLabel
        Left = 160
        Top = 60
        Width = 390
        Height = 19
        AutoSize = False
        Caption = '-'
        ShowAccelChar = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -14
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
    end
  end
  object pnlProblems: TPanel
    Left = 0
    Top = 502
    Width = 1090
    Height = 110
    Align = alBottom
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Right = 8
    TabOrder = 3
    Visible = False
    object lbProblems: TListBox
      Left = 8
      Top = 0
      Width = 1074
      Height = 110
      Hint = 'Click a problem to go to that PID'
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 160
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ItemHeight = 15
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      OnClick = lbProblemsClick
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 612
    Width = 1090
    Height = 48
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    DesignSize = (
      1090
      48)
    object lblProblems: TLabel
      Left = 12
      Top = 17
      Width = 600
      Height = 15
      AutoSize = False
      Caption = 'No problems'
      ShowAccelChar = False
      OnClick = lblProblemsClick
    end
    object btnSave: TButton
      Left = 878
      Top = 11
      Width = 95
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Save'
      TabOrder = 0
      OnClick = btnSaveClick
    end
    object btnCancel: TButton
      Left = 981
      Top = 11
      Width = 95
      Height = 28
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
