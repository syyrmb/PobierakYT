unit FolderButtonFrameUnit;
{ Copyright (c) 2026 CelularBat
  Licensed under GPLv3: https://www.gnu.org/licenses/gpl-3.0.html }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Buttons,Dialogs
  {$IFDEF WINDOWS}, ShellAPI, Windows{$ENDIF}
  {$IFDEF LINUX}, Unix{$ENDIF}
  {$IFDEF DARWIN}, MacOSAll{$ENDIF};

type

  { TFolderButtonFrame }

  TFolderButtonFrame = class(TFrame)
    Button1: TSpeedButton;
    procedure SpeedButton1Click(Sender: TObject);
  private
    FFolderPath: string;
  public
    procedure SetFolderPath(const APath: string);
  end;

implementation

{$R *.lfm}

procedure TFolderButtonFrame.SetFolderPath(const APath: string);
begin
  if APath = '' then
    Exit;

  if not DirectoryExists(APath) then
    raise Exception.CreateFmt('Folder does not exist: %s', [APath]);

  FFolderPath := ExpandFileName(APath);
end;


procedure TFolderButtonFrame.SpeedButton1Click(Sender: TObject);
begin

{$IFDEF WINDOWS}
  ShellExecute(0, 'explore', PChar(FFolderPath), nil, nil, SW_SHOWNORMAL);
  {$ENDIF}
  {$IFDEF LINUX}
  fpSystem(PAnsiChar('xdg-open "' + FFolderPath + '" &'));
  {$ENDIF}
  {$IFDEF DARWIN}
  fpSystem(PAnsiChar('open "' + FFolderPath + '" &'));
  {$ENDIF}
end;

end.

