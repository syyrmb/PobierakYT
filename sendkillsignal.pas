unit SendKillSignal;

{$mode ObjFPC}{$H+}

interface

uses
  {$IFDEF WINDOWS} Windows, {$ENDIF}
  {$IFDEF LINUX} BaseUnix, {$ENDIF}
  Process, SysUtils;

procedure KillSignal(AProcess: TProcess);

implementation

procedure KillSignal(AProcess: TProcess);
{$IFDEF WINDOWS}
var
  PID: DWORD;
{$ENDIF}
begin
  // Basic validation: Check if process object exists and is still active
  if (AProcess = nil) or (not AProcess.Running) then Exit;

  try
    {$IFDEF WINDOWS}
    // In Windows, Ctrl+C is a console event.
    // We attach to the target process's console and trigger the event.
    PID := AProcess.ProcessID;
    if AttachConsole(PID) then
    begin
      // Disable Ctrl+C handling in our own application temporarily
      // so we don't accidentally close ourselves.
      SetConsoleCtrlHandler(nil, True);
      try
        // Send the CTRL_C_EVENT to all processes sharing this console group
        GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0);
      finally
        // Re-enable our own handler and detach from the child's console
        SetConsoleCtrlHandler(nil, False);
        FreeConsole;
      end;
    end;
    {$ENDIF}

    {$IFDEF LINUX}
    // Linux: Send SIGINT (Signal 2), which is the equivalent of Ctrl+C.
    // Using -PID sends the signal to the entire process group.
    if fpKill(-AProcess.ProcessID, SIGINT) <> 0 then
    begin
      WriteLn('Linux SIGINT failed: ', fpGetErrno);
    end;
    {$ENDIF}

  except
    on E: Exception do
      WriteLn('Critical error sending Ctrl+C: ', E.Message);
  end;
end;

end.
