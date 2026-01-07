unit MemoThread;
{ Copyright (c) 2026 CelularBat
  Licensed under GPLv3: https://www.gnu.org/licenses/gpl-3.0.html }

{$mode ObjFPC}{$H+}

// This unit is for running external console application , and writing console output to Tmemo, asychronously, and by not blocking anything.
// it uses RunExternal

// Model: External_Process_Output --> Pipe --> Stream --> TMemo

// Implementation:
// External_Process ( RunExternal._Proc ) ---{ automatically }--> Pipe
// Pipe ---{ RunExternal._Thread copies from Pipe }--> Stream (RunExternal._Stream)
interface

uses
  {$ifdef unix}cthreads,{$endif} Classes, SysUtils, StdCtrls, RegExpr, ComCtrls, Dialogs, LazUTF8,
  RunExternal, pobierak.settings, copyttab;

type
  TRegexStringsArray = array of string;

type
  TMemoThr = class(TThread)
    procedure Execute; override;
    constructor Create(var Memo: Tmemo; var RunExternal: TRunExternal);
    destructor Destroy(); override;
  public
    MyMemo: Tmemo;
    isTaskFinished: boolean; // flag for external use

    function _DebugState(ShowMessage: boolean): string;
    procedure StopAndTerminate();

  private
  // used for PobierakYT
    _page :TTabSheet;
  ////////////////////////


    RE: TRunExternal;

    // regex pattern to replace matching previous line with new line. Ex. for download % lines.
    _RegexLinePatters: array of TRegExpr;
    _IdxOfPreviousPatternMatch: integer; // index of _RegexLinePatters that matched last buffer text
    _LastBufferStart: integer;

    procedure setLinePatternToCollapse(patterns: TRegexStringsArray);

    procedure PrintBuffer(const buffer: string);


  end;

  function RunWithMemoConsole(var Memo: Tmemo;var page:TTabSheet; EXE_PATH, ARGS: string;
    out MemoThr: TMemoThr; HEADERS: TStringArray;
    LinePatternsToCollapse: TStringArray): boolean;
  function RunWithMemoConsole(var Memo: Tmemo;page: TTabSheet;EXE_PATH, ARGS: string;
    out MemoThr: TMemoThr): boolean; overload;



implementation



///////// TMemo handling section

constructor TMemoThr.Create(var Memo: Tmemo; var RunExternal: TRunExternal);
begin
  inherited Create(True);
  RE := RunExternal;
  MyMemo := Memo;
  isTaskFinished := False;
  FreeOnTerminate := True;
  MyMemo.Lines.Options := [];
end;

destructor TMemoThr.Destroy();
begin
  try
    self.isTaskFinished := True;
    self.RE.Free();

  except
    on E: Exception do
    begin
      ShowMessage('TRunExternal.Destroy Error: ' + E.ClassName + #13#10 + E.Message);
      exit;
    end;
  end;

  inherited Destroy;
end;

procedure TMemoThr.PrintBuffer(const buffer: string);
var
  WasScrolledToBottom: boolean;
  OldScrollPosition: integer;
  IdxOfCurrentPatternMatch: integer;
  i: integer;
  ConvertedBuffer: string;
  lastRegexMatch, oldMemoText: string;
begin

  ConvertedBuffer := WinCPToUTF8(buffer);


  // Checking if buffer matches collapse line pattern
  lastRegexMatch := '';
  IdxOfCurrentPatternMatch := -1;
  for i := 0 to High(Self._RegexLinePatters) do
  begin
    if Self._RegexLinePatters[i].Exec(ConvertedBuffer) then
    begin
      IdxOfCurrentPatternMatch := i;

      repeat // if regex patters matches multiple lines, than change buffer text to the last matched line
            lastRegexMatch := Self._RegexLinePatters[i].Match[0];
      until not Self._RegexLinePatters[i].ExecNext;

      ConvertedBuffer := lastRegexMatch;
      break;
    end;
  end;

  if ((IdxOfCurrentPatternMatch > -1)
     and (self._IdxOfPreviousPatternMatch = IdxOfCurrentPatternMatch))
  then
  begin
    oldMemoText := Copy(MyMemo.Text, 1, self._LastBufferStart); // memo text without deleted previous buffer
  end
  else
  begin
    oldMemoText := MyMemo.Text;
  end;

  self._IdxOfPreviousPatternMatch := IdxOfCurrentPatternMatch;
  self._LastBufferStart := Length(oldMemoText); // len of memo text without out new buffer

  // Finding out if user scrolled to bottom
  WasScrolledToBottom := (MyMemo.VertScrollBar.Position >=
    (MyMemo.VertScrollBar.Range - MyMemo.VertScrollBar.Page - 1));
  if MyMemo.Lines.Count = 0 then
    WasScrolledToBottom := True;

  if not WasScrolledToBottom then
    OldScrollPosition := MyMemo.VertScrollBar.Position;

  // Printing buffer
  //  yt-dlp output is encoded in local CodePage, so must be converted
  MyMemo.Text := oldMemoText + ConvertedBuffer;


  // Scrolling to proper position
  if (WasScrolledToBottom) then
  begin  // Scrolling to bottom
    MyMemo.SelStart := Length(MyMemo.Text);
    MyMemo.SelLength := 0; // Clear any selection
  end
  else
  begin   // Scrolling to last position ( DOESN'T WORK, BLAME LAZARUS )
    MyMemo.VertScrollBar.Position := OldScrollPosition;
  end;

end;

procedure TMemoThr.Execute();
var
  tempBuffer: string;
begin

  try
    while (not self.Terminated) and Assigned(RE) and (not RE.IsStreamFinished()) do
    begin
      if (RE.Updated) or (RE._PipeFinished) then
      begin
        if RE.ReadOutputChunk(4096, tempBuffer) then
        begin
          PrintBuffer(tempBuffer);
        end;
      end;
      sleep(200);
    end;

    MyMemo.Lines.Add('');
    MyMemo.Lines.Add('< ...Task finished >');

    if Assigned(_page) then
       _page.Caption := '✅ ' + _page.Caption;

    isTaskFinished := True;
    self.Terminate();
  except
    on E: Exception do
    begin
      ShowMessage('TMemoThr.Execute Error: ' + E.ClassName + #13#10 + E.Message);
      exit;
    end;
  end;
end;

function TMemoThr._DebugState(ShowMessage: boolean): string;
begin
  Result := 'Is Process finished: ' + booltostr(RE.IsProcessFinished(), True);
  Result += #13#10 + 'Is Stream finished: ' + booltostr(RE.IsStreamFinished(), True);
  Result += #13#10 + 'Is Pipe finished: ' + booltostr(RE._PipeFinished, True);
  Result += #13#10 + 'RE Pos Tracker: ' + IntToStr(RE.StreamPosTracker);

end;

procedure tMemoThr.StopAndTerminate();
begin
  try

    self.Terminate();
    self.WaitFor();

  except
    on E: Exception do
    begin
      ShowMessage('TMemoThr.StopAndTerminate Error: ' + E.ClassName +
        #13#10 + E.Message);
      exit;
    end;
  end;
end;

procedure TMemoThr.setLinePatternToCollapse(Patterns: TRegexStringsArray);
var
  i: integer;
var
  tempRegex: TRegExpr;
begin
  // Free previous regex
  for i := 0 to High(Self._RegexLinePatters) do
    Self._RegexLinePatters[i].Free;

  SetLength(Self._RegexLinePatters, Length(Patterns));

  for i := 0 to High(Patterns) do
  begin
    Self._RegexLinePatters[i] := TRegExpr.Create();
    Self._RegexLinePatters[i].Expression := Patterns[i];
  end;

end;



// implementation

function RunWithMemoConsole(var Memo: Tmemo;var page:TTabSheet; EXE_PATH, ARGS: string;
  out MemoThr: TMemoThr; HEADERS: TStringArray;
  LinePatternsToCollapse: TStringArray): boolean;
var
  RE: TRunExternal;
var
  i: integer;
begin
  Memo.Lines.Add('< Starting new task... >');
  for i := 0 to Length(HEADERS) - 1 do
    Memo.Lines.Add(HEADERS[i]);
  Memo.Lines.Add('');
  if not (FileExists(EXE_PATH)) then
  begin
    Memo.Lines.Add('Error: File ' + EXE_PATH + ' does not exist!');
    Memo.Lines.Add('< ...Task FAILED >');
    Exit;
  end;
  Result := False;

  try
    RE := TRunExternal.Create(EXE_PATH, ARGS);
    RE.Run();
    MemoThr := TmemoThr.Create(Memo, RE);
    if (Length(LinePatternsToCollapse) > 0) then
      MemoThr.setLinePatternToCollapse(LinePatternsToCollapse);
    if Assigned(page) then
       MemoThr._page := page;
    MemoThr.Start();
    Result := True;
  except
    on E: Exception do
    begin
      Memo.Lines.Add('< RunWithMemoConsole() Error: ' + E.Message + ' >');
      Re.Free();
      MemoThr.Terminate();
      Exit;
    end;
  end;

end;

function RunWithMemoConsole(var Memo: Tmemo;page: TTabSheet;EXE_PATH, ARGS: string;
  out MemoThr: TMemoThr): boolean; overload;
begin
  Result := RunWithMemoConsole(Memo,page, EXE_PATH, ARGS, MemoThr, [], []);
end;







end.
