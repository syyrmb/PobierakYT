unit WCustomFormatList;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Grids;

type

  { TFrame1 }

  TCustomFormatList = class(TForm)
    StringGrid1: TStringGrid;
  private

  public

  end;

  var
    CustomFormatList : TCustomFormatList;

implementation

{$R *.lfm}

end.

