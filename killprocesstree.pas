unit KillProcessTree;

{$mode ObjFPC}{$H+}

interface

uses
  {$IFDEF WINDOWS} Windows, {$ENDIF}
  {$IFDEF LINUX} BaseUnix, Errors, {$ENDIF}
  Process, SysUtils;

procedure KillProcTree(AProcess: TProcess);

implementation

procedure KillProcTree(AProcess: TProcess);
var
  Killer: TProcess;
begin
  // Basic validation: Check if process object exists and is still active
  if (AProcess = nil) or (not AProcess.Running) then Exit;

  try
    {$IFDEF WINDOWS}
    // Windows: Use 'taskkill' to recursively terminate the entire tree (/T)
    Killer := TProcess.Create(nil);
    try
      Killer.Executable := 'taskkill';
      Killer.Parameters.Add('/F'); // Forcefully terminate
      Killer.Parameters.Add('/T'); // Include child processes
      Killer.Parameters.Add('/PID');
      Killer.Parameters.Add(IntToStr(AProcess.ProcessID));
      Killer.Options := [poNoConsole, poWaitOnExit];
      Killer.Execute;
    finally
      Killer.Free;
    end;
    {$ENDIF}

    {$IFDEF LINUX}
    // Linux: Send SIGKILL to the entire Process Group (-PID)
    try
      if fpKill(-AProcess.ProcessID, SIGKILL) <> 0 then
      begin
        // Handle potential errors like EPERM or ESRCH using baseunix error codes
        WriteLn('Linux fpKill failed: ', fpGetErrno);
      end;
    except
      on E: Exception do
        WriteLn('Error sending signal to process group: ', E.Message);
    end;
    {$ENDIF}

  except
    on E: Exception do
      // Log general execution errors (e.g., taskkill.exe missing on Windows)
      WriteLn('Critical error in KillProcessTree: ', E.Message);
  end;
end;


end.
