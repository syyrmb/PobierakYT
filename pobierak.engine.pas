unit pobierak.Engine;
{ Copyright (c) 2026 CelularBat
  Licensed under GPLv3: https://www.gnu.org/licenses/gpl-3.0.html }

{$mode ObjFPC}{$H+}


interface

uses
  {$ifdef unix}cthreads,{$endif} Classes, SysUtils, StdCtrls, copyttab, ComCtrls, Dialogs, Controls,
  memothread;


type
  TJobTab = object
    ID: integer; // g_UniqueTabID is assigned at creation, and saved into TJobTab.tab.Tag
    tab: TTabSheet;
    memo: TMemo;
    memoThr: TMemoThr;
    isFinished: Pboolean; // wrapper to MemoThr.isTaskfinished
    isAlive: boolean;     // tells if Tab wasn't closed
    function closeTab(): boolean;
    procedure ClearMemo();
  end;

type
  TJobTabArray = array of TJobTab;

const
  COLLAPSE_PATTERS_ARR: array[0..0] of string = ('(?m)\[download\]\s+\d+(\.\d+)?% of.*ETA.*?$');


var
  g_JobTabs: TJobTabArray;
  // this is an array where all tabs are contained. Index in this array = ID

var
  g_UniqueTabID: integer;
  // This is tab index counter, which increases when new tab is added

var
  ConsoleMemoThread: TMemoThr;  // MemoThread for the Main console


function RunInNewTab(EXE_PATH, ARGS: string; HEADERS: TStringArray;
  var PageControl: TPageControl; newName: string): boolean;
function RunInNewTab(ARGS: string; var PageControl: TPageControl;
  newName: string): boolean;
function RunInNewTab(ARGS: string; HEADERS: TStringArray;
  var PageControl: TPageControl; newName: string): boolean;

function RunTab(ARGS: string; HEADERS: TStringArray; newName: string): boolean;
function RunTab(ARGS: string; newName: string): boolean;


function RunInConsole(ARGS: string): boolean;
function RunInConsole(ARGS: string; HEADER: TStringArray): boolean;

function CheckDependencies(): boolean;
procedure PrintLineConsole(lineOfText: string);




implementation

uses pobierak.settings, MainForm;





function RunInConsole(ARGS: string): boolean;
var page:TTabSheet;
begin
  //  if (not CheckDependencies()) then begin Result:=false; exit; end;
  Form1.PageControlConsole.ActivePage := Form1.ConsoleTab;
  page := Form1.PageControlConsole.Pages[0];
  Result := RunWithMemoConsole(Form1.Memo1,page, g_PobierakSettings.s_YTdl_PATH,
    ARGS, ConsoleMemoThread, [args], []);
end;

function RunInConsole(ARGS: string; HEADER: TStringArray): boolean;
var page:TTabSheet;
begin
  // if (not CheckDependencies()) then begin Result:=false; exit; end;
  Form1.PageControlConsole.ActivePage := Form1.ConsoleTab;
  page := Form1.PageControlConsole.Pages[0];
  Result := RunWithMemoConsole(Form1.Memo1,page, g_PobierakSettings.s_YTdl_PATH,
    ARGS, ConsoleMemoThread, HEADER, []);
end;


function RunInNewTab(EXE_PATH, ARGS: string; HEADERS: TStringArray;
  var PageControl: TPageControl; newName: string): boolean;
var
  fullName: string;
  page: TTabSheet;
  m: Tmemo;
  MemoThread: TMemoThr;
  l: integer;
begin

  fullName := '[' + IntToStr(g_UniqueTabID) + ']' + newName;
  SpawnNewTab(PageControl, 0, fullName, page, m);
  sleep(100);

  Result := RunWithMemoConsole(m,page, EXE_PATH, ARGS, MemoThread, HEADERS,
    COLLAPSE_PATTERS_ARR);

  l := Length(g_JobTabs);
  SetLength(g_JobTabs, l + 1);
  with g_JobTabs[l] do
  begin
    ID := g_UniqueTabID;
    memo := m;
    memoThr := MemoThread;
    tab := page;
    isFinished := @MemoThread.isTaskFinished;
    isAlive := True;
  end;

  page.Tag := g_UniqueTabID;
  Inc(g_UniqueTabID);

end;


procedure TJobTab.clearMemo();
begin
  self.memo.Lines.Clear();
end;

function TJobTab.closeTab(): boolean;
var
  response: integer;
begin
  Result := True;
  id := self.tab.Tag;
  if (id = -1) then exit; // We don't want to close the main console
  if not (self.isFinished^) then
  begin
    response := MessageDlg('Tab is working, stop the job?', mtConfirmation,
      [mbYes, mbNo], 0);
    if response = mrYes then
    begin
      if (Assigned(self.memoThr) and (not self.memoThr.isTaskFinished)) then
        self.memoThr.StopAndTerminate();
    end
    else
    begin
      Result := False;
      exit;
    end;

  end;
  self.tab.Free;
  self.isAlive := False;
  Result := True;

end;

// Overload adjusted for PobierakYT
function RunInNewTab(ARGS: string; HEADERS: TStringArray;
  var PageControl: TPageControl; newName: string): boolean;
begin
  if (not CheckDependencies()) then
  begin
    Result := False;
    exit;
  end;
  Result := RunInNewTab(g_PobierakSettings.s_YTdl_PATH, ARGS, HEADERS,
    PageControl, newName);
end;

function RunInNewTab(ARGS: string; var PageControl: TPageControl;
  newName: string): boolean;
begin
  if (not CheckDependencies()) then
  begin
    Result := False;
    exit;
  end;
  Result := RunInNewTab(g_PobierakSettings.s_YTdl_PATH, ARGS, [args],
    PageControl, newName);
end;

function RunTab(ARGS: string; HEADERS: TStringArray; newName: string): boolean;
begin
  if (not CheckDependencies()) then
  begin
    Result := False;
    exit;
  end;
  Result := RunInNewTab(g_PobierakSettings.s_YTdl_PATH, ARGS, HEADERS,
    Form1.PageControlConsole, newName);
end;

function RunTab(ARGS: string; newName: string): boolean;
begin
  if (not CheckDependencies()) then
  begin
    Result := False;
    exit;
  end;
  Result := RunInNewTab(g_PobierakSettings.s_YTdl_PATH, ARGS, [args],
    Form1.PageControlConsole, newName);
end;




function CheckDependencies(): boolean;
begin
  Result := True;
  if ((g_PobierakSettings.s_YTdl_PATH = '') or
    (g_PobierakSettings.s_FFMPG_FOLDER = '')) then
  begin
    Form1.PageControl1.ActivePage := Form1.TabOptions2;
    MessageDlg(
      'Welcome to PobierakYT!' + LineEnding + LineEnding +
      'Please note: This application is only a Graphical User Interface (GUI).' +
      LineEnding + 'You **MUST** download following tools:' +
      LineEnding + LineEnding +
      '1. **yt-dlp:** A command-line program to download videos and extract information.'
      +
      LineEnding +
      '2. **FFMPEG:** A complete, cross-platform solution to record, convert and stream audio and video.'
      + LineEnding + LineEnding + 'You can find download links in Options tab' +
      LineEnding + LineEnding +
      'If you already have them please add path to them or put them in the same folder.',
      mtInformation, [mbOK], 0
      );
    Result := False;
  end;
end;

 // stupid helper function;
procedure PrintLineConsole(lineOfText: string);
begin
  Form1.Memo1.Lines.Add(lineOfText);
end;


end.
