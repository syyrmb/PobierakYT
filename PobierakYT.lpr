program PobierakYT;
{ Copyright (c) 2026 CelularBat
  Licensed under GPLv3: https://www.gnu.org/licenses/gpl-3.0.html }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  MainForm,
  RunExternal,
  pobierak.settings,
  MemoThread,
  debugUtils,
  CustomFormatsForm,
  FolderButtonFrameUnit, UVideosFrame{ you can add units after this };

  {$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);


  Application.Run;
end.
