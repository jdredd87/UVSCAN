object PidDiscoveryForm: TPidDiscoveryForm
  Left = 0
  Top = 0
  Caption = 'Search PCM for PIDs'
  ClientHeight = 600
  ClientWidth = 780
  Color = clBtnFace
  Constraints.MinHeight = 450
  Constraints.MinWidth = 700
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  TextHeight = 15
  object gbSearch: TGroupBox
    AlignWithMargins = True
    Left = 8
    Top = 6
    Width = 764
    Height = 150
    Margins.Left = 8
    Margins.Top = 6
    Margins.Right = 8
    Align = alTop
    Caption = ' Which PIDs to ask the PCM about (read only) '
    TabOrder = 0
    DesignSize = (
      764
      150)
    object chkSae: TCheckBox
      Left = 14
      Top = 24
      Width = 420
      Height = 17
      Caption = 'Standard SAE PIDs  ($0000 - $00FF, about 10 seconds)'
      Checked = True
      State = cbChecked
      TabOrder = 0
    end
    object chkGm: TCheckBox
      Left = 14
      Top = 46
      Width = 420
      Height = 17
      Caption = 'GM enhanced PIDs  ($1000 - $1FFF, about 2 minutes)'
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
    object lblMore: TLabel
      Left = 14
      Top = 74
      Width = 70
      Height = 15
      Caption = 'Also search'
    end
    object edtMore: TEdit
      Left = 90
      Top = 71
      Width = 250
      Height = 23
      TabOrder = 2
      TextHint = 'e.g. 2000-2FFF, 4000-40FF'
    end
    object btnStart: TButton
      Left = 360
      Top = 70
      Width = 100
      Height = 26
      Caption = 'Search'
      Default = True
      TabOrder = 3
      OnClick = btnStartClick
    end
    object btnStop: TButton
      Left = 466
      Top = 70
      Width = 80
      Height = 26
      Caption = 'Stop'
      TabOrder = 4
      OnClick = btnStopClick
    end
    object pbProgress: TProgressBar
      Left = 14
      Top = 106
      Width = 736
      Height = 14
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 5
    end
    object lblStatus: TLabel
      Left = 14
      Top = 126
      Width = 736
      Height = 15
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      Caption = 'Connect to the vehicle, choose what to search and press Search.'
    end
  end
  object lvResults: TListView
    AlignWithMargins = True
    Left = 8
    Top = 162
    Width = 764
    Height = 382
    Margins.Left = 8
    Margins.Top = 6
    Margins.Right = 8
    Margins.Bottom = 0
    Align = alClient
    Checkboxes = True
    Columns = <
      item
        Caption = 'PID'
        Width = 80
      end
      item
        Caption = 'Bytes'
        Width = 50
      end
      item
        Caption = 'Raw value'
        Width = 110
      end
      item
        Caption = 'Already defined as'
        Width = 480
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnItemChecked = lvResultsItemChecked
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 544
    Width = 780
    Height = 56
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    DesignSize = (
      780
      56)
    object lblTicked: TLabel
      Left = 290
      Top = 21
      Width = 100
      Height = 15
      Caption = '0 ticked to add'
    end
    object btnTickNew: TButton
      Left = 8
      Top = 15
      Width = 130
      Height = 28
      Hint = 'Tick every PID that is not defined yet'
      Caption = 'Tick all new'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      OnClick = btnTickNewClick
    end
    object btnUntickAll: TButton
      Left = 144
      Top = 15
      Width = 130
      Height = 28
      Caption = 'Untick all'
      TabOrder = 1
      OnClick = btnUntickAllClick
    end
    object btnAdd: TButton
      Left = 540
      Top = 15
      Width = 130
      Height = 28
      Hint = 'Add the ticked PIDs to your PID list as raw values, to name and define later'
      Anchors = [akTop, akRight]
      Caption = 'Add ticked PIDs'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      OnClick = btnAddClick
    end
    object btnClose: TButton
      Left = 676
      Top = 15
      Width = 95
      Height = 28
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Close'
      ModalResult = 2
      TabOrder = 3
    end
  end
end
