unit copyTTab;
{ Copyright (c) 2026 CelularBat
  Licensed under GPLv3: https://www.gnu.org/licenses/gpl-3.0.html }

{$mode ObjFPC}{$H+}



interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ComCtrls, Dialogs, StdCtrls;

type
  PTTabSheet = ^TTabSheet;


function SpawnNewTab(var PageControl: TPageControl; CloneIdx: integer;
  newName: string; out page: TTabSheet; out Memo: Tmemo): boolean;


implementation




// modification of code from:
// https://forum.lazarus.freepascal.org/index.php/topic,37456.msg251745.html#msg251745


procedure CopyProperties(FromControl, ToControl: TControl);
var
  TempMem: TMemoryStream;
  FromName: string;
begin
  FromName := FromControl.Name;
  FromControl.Name := '';
  try
    TempMem := TMemoryStream.Create;
    try
      try
        TempMem.WriteComponent(FromControl);
        TempMem.Position := 0;
        TempMem.ReadComponent(ToControl);
      except
        on E: Exception do
        begin
          ShowMessage('Error in CopyProperties: ' + E.ClassName +
            #13#10 + E.Message + ' ');
        end;
      end;

    finally
      TempMem.Free;
    end;
  finally
    FromControl.Name := FromName;
  end;
end;

var g_newComponentIdx :LongInt;

function CloneControl(FromControl: TControl): TControl;
var
  ChildControl,Cloned_ChildControl: TControl;
  i: integer;
begin
  Result := TControlClass(FromControl.ClassType).Create(FromControl.Owner);

  CopyProperties(FromControl, Result);  // Clone all properties, with empty name

  Result.Name := FromControl.Name + '_' + intToStr(g_newComponentIdx); // new unique name
  Inc(g_newComponentIdx);


  if FromControl is TWinControl then  // recursively iterate through all component children to copy them
    for ChildControl in TWinControl(FromControl).GetEnumeratorControls do
    begin
      Cloned_ChildControl := CloneControl(ChildControl);
      Cloned_ChildControl.Parent := TWinControl(Result);
    end;
end;




//////////// Implementation for PobierakYT///////////////////////////////////////////////////
function _StripUnicode(const Input: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(Input) do
    if Ord(Input[i]) < 128 then
      Result := Result + Input[i];
end;

function _StripWrongChars(const Input: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(Input) do
  begin
    if Input[i] in ['0'..'9', 'A'..'Z', 'a'..'z'] then
      Result := Result + Input[i];
  end;
end;



function SpawnNewTab(var PageControl: TPageControl; CloneIdx: integer;
  newName: string; out page: TTabSheet; out Memo: Tmemo): boolean;
var
  i: integer;
begin
  Result := False;

  page := CloneControl(PageControl.Pages[0]) as TTabSheet;
  page.PageControl := PageControl;
  page.Parent := PageControl;


  // Cleaning TMemo from copied text
  for i := 0 to page.ControlCount - 1 do
  begin
    if (page.Controls[i] is TMemo) then
    begin
      Memo := page.Controls[i] as TMemo;
      Memo.Lines.Clear();
      break;
    end;
  end;

  page.Caption := newName;
  PageControl.ActivePage := page;

  Result := true;
end;




end.
