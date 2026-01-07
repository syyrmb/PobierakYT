unit CustomFormatsForm;
{ Copyright (c) 2026 CelularBat
  Licensed under GPLv3: https://www.gnu.org/licenses/gpl-3.0.html }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, StdCtrls, Types,
  pobierak.settings, decorator_StaticText_Link;

type
  TSaveCustomListProc = procedure of object;

type
  PCustomFormatArray = ^TCustomFormatArray;

type

  { TCustomFormatsForm }

  TCustomFormatsForm = class(TForm)
    btnDone: TButton;
    btnAddRows: TButton;
    Label1: TLabel;
    StringGrid1: TStringGrid;

    StaticTextURL: TStaticText;
    procedure btnAddRowsClick(Sender: TObject);
    procedure btnDoneClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
      aRect: TRect; aState: TGridDrawState);
    procedure StringGrid1SetEditText(Sender: TObject; ACol, ARow: integer;
      const Value: string);
  private
    _p_CFA: PCustomFormatArray; // Pointer, so we can edit this array inside our class
    _StripesColor1, _StripesColor2: TColor;
    _DataSave_Proc: TSaveCustomListProc;

  public
    procedure InitForm(Title, ColumnTitle, URL: string;
      var CustomFormatArray: TCustomFormatArray;
      SaveList_Proc: TSaveCustomListProc; C1, C2: TColor);

  end;

var
  CustomAVFormatsForm: TCustomFormatsForm;
  CustomCommandsForm: TCustomFormatsForm;
  CustomOutputsForm: TCustomFormatsForm;

implementation

{$R *.lfm}

{ TCustomFormatsForm }

procedure TCustomFormatsForm.InitForm(Title, ColumnTitle, URL: string;
  var CustomFormatArray: TCustomFormatArray;
  SaveList_Proc: TSaveCustomListProc; C1, C2: TColor);
begin
  Self.Caption := Title;

  StringGrid1.Cells[1, 0] := ColumnTitle;


  _p_CFA := @CustomFormatArray;
  _StripesColor1 := C1;
  _StripesColor2 := C2;
  StaticTextURL.Caption := URL;
  _DataSave_Proc := SaveList_Proc;
end;

procedure TCustomFormatsForm.FormCreate(Sender: TObject);
begin
  //Self.Caption:= 'Custom Quality Format String';

  StringGrid1.Cells[0, 0] := '#.';
  //StringGrid1.Cells[1,0] := 'Custom Format String';
  StringGrid1.Cells[2, 0] := 'Description';

  TStaticTextLinkDecorator.Create(self.StaticTextURL);
end;

procedure TCustomFormatsForm.btnDoneClick(Sender: TObject);
begin
  _DataSave_Proc();
  Close();
end;

procedure TCustomFormatsForm.btnAddRowsClick(Sender: TObject);
begin
  StringGrid1.RowCount := StringGrid1.RowCount + 2;
end;

procedure TCustomFormatsForm.FormShow(Sender: TObject);
var
  i, len: integer;
begin
  len := Length(_p_CFA^);
  with StringGrid1 do
  begin
    if (RowCount) < len then
    begin
      RowCount := len + 1;
    end;

    for i := 0 to (len - 1) do
    begin
      Cells[1, i + 1] := _p_CFA^[i].CustomString;
      Cells[2, i + 1] := _p_CFA^[i].Description;
    end;
  end;
end;



procedure TCustomFormatsForm.StringGrid1SetEditText(Sender: TObject;
  ACol, ARow: integer; const Value: string);
var
  i, len: integer;
begin
  len := Length(_p_CFA^);

  if (ARow > len) then
    SetLength(_p_CFA^, ARow);
  if (ACol = 1) then
    _p_CFA^[ARow - 1].CustomString := Value;
  if (ACol = 2) then
    _p_CFA^[ARow - 1].Description := Value;
end;

procedure TCustomFormatsForm.StringGrid1DrawCell(Sender: TObject;
  aCol, aRow: integer; aRect: TRect; aState: TGridDrawState);
begin
  with TStringGrid(Sender) do
  begin
    if ((aCol = 0) or (aRow = 0)) then
      Canvas.Brush.Color := clBtnFace
    else if aRow mod 2 = 0 then
      Canvas.Brush.Color := _StripesColor1   // kolor parzystych wierszy
    else
      Canvas.Brush.Color := _StripesColor2;

    Canvas.FillRect(aRect); // wypełnienie tła

    Canvas.Font.Color := clBlack;

    if ((aCol = 0) and (aRow > 0)) then
      Canvas.TextRect(aRect, aRect.Left + 2, aRect.Top + 2, IntToStr(aRow))
    else
      Canvas.TextRect(aRect, aRect.Left + 2, aRect.Top + 2, Cells[aCol, aRow]);
  end;
end;



end.
