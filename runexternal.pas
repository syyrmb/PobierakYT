unit RunExternal;
{ Copyright (c) 2026 CelularBat
  Licensed under GPLv3: https://www.gnu.org/licenses/gpl-3.0.html }

{$mode ObjFPC}{$H+}

interface

uses
  {$ifdef unix}cthreads,{$endif} Classes, SysUtils, Process, Dialogs, debugUtils,
  killprocesstree;
{TO DO:
 *   procedure Run(); change to func():boolean ,with check if exe file exist.

}


{ Run external application ( in new TProcess )  and store output in TStream ( copping is done in new TThread ).
You can get output anytime you want.


// Example for writing output in real-time.

var RE : TRunExternal;
var strBuff : string;
begin
      RE := TRunExternal.Create(PATH,ARGS);
      RE.Run();                                    // now process runs asynchronously in another thread

                                                   // to get process output:
      while ( not RE.IsStreamFinished() ) do begin
          if RE.ReadOutputChunk(1000,strBuff ) then writeln(strBuff);
          sleep(500);
      end;
end;

// Or wait till process is finished and it's Output copied to Stream, and then grab all output at once

var RE : TRunExternal;

begin
      RE := TRunExternal.Create(PATH,ARGS);
      RE.Run();                                    // now process runs asynchronously in another thread

                                                   // to get process output:
      while ( not RE._PipeFinished  ) do begin
          sleep(500);
      end;

      writeln(ReadOutputAll());
end;

}

type
  TStreamThread = class;

type
  TRunExternal = class

  public
    constructor Create(path: string; args: string);
    destructor Destroy(); override;
    procedure Run();

    function ReadOutputAll(var OutBuffer): longint;
    function ReadOutputAll(): string; overload;

    function ReadOutputChunk(var OutBuffer; Count: longint): longint;
    function ReadOutputChunk(Count: longint; var ResultString: string): boolean;
      overload;
    function IsStreamFinished(): boolean;
    // Stream is finished when you've read the last chunk of data using ReadOutputChunk().
    // WARNING: Calling ReadOutputAll() doesn't make it finished.

    function IsProcessFinished(): boolean;
  public

    StreamPosTracker: longint;
    // This tracks position in Stream at which last ReadOutputChunk() ended. In this class it's used for reading from Stream to Main application
    // it's different from TStream.position, which is changed by TStream.Write/Read calls and in this class used internally for writing from Process Output to Stream
    Updated: boolean;
    // This flag informs if a new input was loaded into the stream since the last read() function.

    _PipeFinished: boolean;
    // It's TRUE when all Process Output was loaded into Stream ; and Process is not running

  private
    _Proc: TProcess;
    _CriticalSection: TRTLCriticalSection;
    _Stream: TMemoryStream;
    _Thread: TStreamThread;



  end;

type
  TStreamThread = class(TThread)
    procedure Execute(); override;
    constructor Create(CreateSuspended: boolean; var RunExternal: TRunExternal);
  private
    RE: TRunExternal;
  end;


implementation

constructor TRunExternal.Create(path: string; args: string);
begin
  _Stream := TMemoryStream.Create; // Stream for holding process output
  _Proc := TProcess.Create(nil);   // Process for running external application
  _Thread := TStreamThread.Create(True, self); //Thread for sending output from process's pipe to stream
  InitCriticalSection(_CriticalSection);

  _Proc.Executable := path; // path to executable
  _Proc.Parameters.Add(args); // arguments of executable
  _Proc.Options := [poUsePipes, poStderrToOutPut,poNewProcessGroup]; // options config to output data to pipe
  _Proc.ShowWindow := swoHide; // run executable in the background

  StreamPosTracker := 0;
  _PipeFinished := False;
end;

destructor TRunExternal.Destroy();
begin
  try
    _Thread.Terminate();
    _Thread.WaitFor();

    _Stream.Clear();
    _Stream.Free();

    _Proc.Free();
    KillProcTree(_Proc); // This is needed to kill ffmpg if it's in the middle of work
    _Thread.Free();

    DoneCriticalsection(_CriticalSection);

  except
    on E: Exception do
    begin
      ShowMessage('TRunExternal.Destroy Error: ' + E.ClassName + #13#10 + E.Message);
      exit;
    end;
  end;

  inherited Destroy;
end;

procedure TRunExternal.Run();
begin
  _Thread.Start;
end;

function TRunExternal.IsStreamFinished(): boolean;
begin
  Result := _PipeFinished and (StreamPosTracker >= _Stream.Position);
end;

function TRunExternal.ReadOutputChunk(var OutBuffer; Count: longint): longint;
var
  tempPosContainer: int64;
begin
  Result := 0;
  if (StreamPosTracker >= _Stream.Position) then
  begin
    Updated := False;
  end
  else
  begin
    EnterCriticalSection(_CriticalSection);
    try
      tempPosContainer := _Stream.Position;
      _Stream.Seek(StreamPosTracker, soBeginning);
      Result := _Stream.Read(OutBuffer, Count);
      _Stream.Seek(tempPosContainer, soBeginning);
    finally
      LeaveCriticalSection(_CriticalSection);
      StreamPosTracker := StreamPosTracker + Result;
    end;
  end;
end;


function TRunExternal.ReadOutputChunk(Count: longint;
  var ResultString: string): boolean; overload;
var
  size: longint;
var
  buf: pchar;
begin
  Result := False;

  Updated := False;
  buf := stralloc(Count + 1);
  size := ReadOutputChunk(buf^, Count);
  if size > 0 then
  begin
    (buf +size)^ := #0;
    ResultString := '' + buf;
    Result := True;
  end;

  StrDispose(buf);
end;

function TRunExternal.ReadOutputAll(var OutBuffer): longint;
var
  tempPosContainer: int64;
begin
  Result := 0;
  EnterCriticalSection(_CriticalSection);
  try
    tempPosContainer := _Stream.Position;
    _Stream.Seek(0, soBeginning);
    Result := _Stream.Read(OutBuffer, _Stream.Size);
    _Stream.Seek(tempPosContainer, soBeginning);
  finally
    LeaveCriticalSection(_CriticalSection);
  end;
  Updated := False;
end;

function TRunExternal.ReadOutputAll(): string; overload;
var
  size: longint;
var
  buf: pchar;
begin
  buf := stralloc(_Stream.Size);
  size := ReadOutputAll(buf^);
  Result := '' + buf;
  StrDispose(buf);
end;

function TRunExternal.IsProcessFinished(): boolean;
begin
  Result := not _Proc.Running;
end;

// ----------------  TStreamThread -------------------

constructor TStreamThread.Create(CreateSuspended: boolean;
  var RunExternal: TRunExternal);
begin
  inherited Create(CreateSuspended);
  FreeOnTerminate := False;  // Changed
  RE := RunExternal;
end;


procedure TStreamThread.Execute();
const
  BUF_SIZE = 2048;
var
  BytesRead: longint;
  Buffer: array[1..BUF_SIZE] of byte;
begin

  try
    RE._Proc.Execute();
  except
    on E: Exception do
    begin
      ShowMessage('RunExternal Error: ' + E.ClassName + #13#10 +
        E.Message + #13#10 + 'Failed to execute: ' + RE._Proc.Executable);
      self.Free();
      RE.Free();
      exit;
    end;
  end;

  while (not Terminated) and (RE._Proc.Running) do
  begin
    if RE._Proc.Output.NumBytesAvailable > 0 then
    begin
      BytesRead := RE._Proc.Output.Read(Buffer, BUF_SIZE);
      RE._Stream.Write(Buffer, BytesRead);
      RE.Updated := True;

    end;
    sleep(100); // When process is not sending data we are relaxing

    // Now the external process is done. But make sure to check if anything has left in the pipe
    sleep(500);
    if RE._Proc.Output.NumBytesAvailable > 0 then
    begin
      repeat
        BytesRead := RE._Proc.Output.Read(Buffer, BUF_SIZE);
        RE._Stream.Write(Buffer, BytesRead);
        sleep(50);
        ///  Showmessage(ByteArrayToHexString(Buffer,' '));  // debug
      until RE._Proc.Output.NumBytesAvailable = 0;
      RE.Updated := True;
    end;
  end;
  RE._PipeFinished := True;

end;

begin
end.
