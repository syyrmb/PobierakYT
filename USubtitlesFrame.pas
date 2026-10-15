unit USubtitlesFrame;
{ Copyright (c) 2026 CelularBat
  Licensed under GPLv3: https://www.gnu.org/licenses/gpl-3.0.html }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, RegExpr, Graphics, Dialogs, StdCtrls, ExtCtrls,
  pobierak.Engine,pobierak.Settings;

type

  { TSubtitlesFrame }

  TSubtitlesFrame = class(TFrame)
    btnCheckSubs: TButton;
    btnDownloadSub: TButton;
    edtSubFormat: TEdit;
    edtSubLang: TEdit;
    edtSubtitlesURL: TEdit;
    Label8: TLabel;
    Label9: TLabel;
    GroupBox1: TGroupBox;
    RadioGroupSubs: TRadioGroup;
    procedure btnCheckSubsClick(Sender: TObject);
    procedure btnDownloadSubClick(Sender: TObject);
    procedure edtSubFormatChangeBounds(Sender: TObject);
    procedure edtSubLangChangeBounds(Sender: TObject);
    procedure LoadSettingsIntoGUI();
    constructor Create(AOwner: TComponent);
    procedure RadioGroupSubsSelectionChanged(Sender: TObject);
  private
  public
    procedure PrCoJsChecks(var outputStr: string);
  end;

implementation

{$R *.lfm}

{ TSubtitlesFrame }

{Function for validating if the proxy address entered in edtProxy TEdit box in
the UOptions frame fits in the "xxx.xxx.xxx.xxx:xxxxx" format. The address can't
start with "http://" or the like (maybe add support for it in the future).}
constructor TSubtitlesFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  self.LoadSettingsIntoGUI();
end;

procedure TSubtitlesFrame.RadioGroupSubsSelectionChanged(Sender: TObject);
begin
  g_PobierakSettings.s_SubDl := RadioGroupSubs.ItemIndex;
end;

procedure TSubtitlesFrame.LoadSettingsIntoGUI();
begin
  self.RadioGroupSubs.ItemIndex := g_PobierakSettings.s_SubDl;
  self.edtSubLang.text := g_PobierakSettings.s_SubLang;
  self.edtSubFormat.text := g_PobierakSettings.s_SubFormat;
end;

function ProxyValidation(const AText: string): Boolean;
var
  Regex: TRegExpr;
  Pattern: string;
  PortNum: longint;
begin
  Result := False;
  Pattern := '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?):([0-9]{1,5})$';
  Regex := TRegExpr.Create(Pattern);
  try
    if Regex.Exec(AText) then
    begin
      PortNum := StrToIntDef(Regex.Match[4], 0);
      if (PortNum >= 1) and (PortNum <= 65535) then
        Result := True;
    end;
  finally
    Regex.Free;
  end;
end;

procedure TSubtitlesFrame.PrCoJsChecks(var outputStr: string);
begin
      //Validate proxy address using the function above, and add proxy setting if passed.
  if AppGlobalSettings.G_Proxy <> '' then
    begin
      if ProxyValidation(AppGlobalSettings.G_Proxy) then
        begin
          outputStr := outputStr + ' --proxy ' + AppGlobalSettings.G_Proxy + ' ';
        end
      else
        begin
          ShowMessage('Please check the proxy address in Options tab. Only support IP:Port format (e.g., 127.0.0.1:10001), Adding "http://" or "https://" is not supported');
          Exit;
        end
    end;
      //Adding Cookie parameters
  if AppGlobalSettings.G_CookieEnabled = true then
    begin
      if AppGlobalSettings.G_CookieDir <> '' then
        begin
          outputStr += ' --cookies-from-browser ' + AppGlobalSettings.G_Browser + ':"' + AppGlobalSettings.G_CookieDir + '"';
        end
      else if AppGlobalSettings.G_CookieDir = '' then
        begin
          outputStr += ' --cookies-from-browser ' + AppGlobalSettings.G_Browser;
        end
    end;
    {Adding JS runtime parameters, using "--no-js-runtimes" parameter here to
     make sure user's JS runtime selection is respected.}
  if AppGlobalSettings.G_JsEnabled = true then
    begin
      if AppGlobalSettings.G_JsDir <> '' then
        begin
          outputStr += ' --no-js-runtimes --js-runtimes ' + AppGlobalSettings.G_JsRuntime + ':"' + AppGlobalSettings.G_JsDir + '"';
        end
      else if AppGlobalSettings.G_JsDir = '' then
        begin
          outputStr += ' --no-js-runtimes --js-runtimes ' + AppGlobalSettings.G_JsRuntime;
        end
      end;
end;

procedure TSubtitlesFrame.btnCheckSubsClick(Sender: TObject);
var addargs: string;
  f_ignoreGlobalOutputFormat: boolean;
begin
  addargs := '';
  if ProxyValidation(AppGlobalSettings.G_Proxy) or (AppGlobalSettings.G_Proxy = '') then
    PrCoJsChecks(addargs);
    RunTab(edtSubtitlesURL.Text + ' --list-subs --simulate ' + addargs + g_PobierakSettings.ParseSettingsArgs(f_ignoreGlobalOutputFormat), 'FSub');
end;

procedure TSubtitlesFrame.btnDownloadSubClick(Sender: TObject);
var
  subs_args: string;
  f_ignoreGlobalOutputFormat: boolean;
begin
  subs_args := edtSubtitlesURL.Text;
  if ProxyValidation(AppGlobalSettings.G_Proxy) or (AppGlobalSettings.G_Proxy = '') then
    PrCoJsChecks(subs_args);
  if (Length(edtSubFormat.Text) > 0) then
    subs_args += ' --sub-format ' + edtSubFormat.Text
  else
    subs_args += ' --sub-format "best"';
  if (Length(edtSubLang.Text) > 0) then
    subs_args += ' --sub-langs' + edtSubLang.Text + ',-live_chat"'
  else
    subs_args += ' --sub-langs ".+-orig"';
  case RadioGroupSubs.ItemIndex of
    0: subs_args += ' --write-subs';
    1: subs_args += ' --write-auto-subs';
    2: subs_args += ' --write-subs --write-auto-subs';
  end;
  subs_args += ' --skip-download';
  subs_args += ' -o "subs/%(uploader)s_%(title)s.%(ext)s"';
  subs_args += g_PobierakSettings.ParseSettingsArgs(True);

  RunTab(subs_args, [subs_args, 'Downloading subtitles:'], 'Subs');
end;

procedure TSubtitlesFrame.edtSubFormatChangeBounds(Sender: TObject);
begin
  g_PobierakSettings.s_SubFormat := edtSubFormat.text;
  AppGlobalSettings.G_SubFmt := edtSubFormat.text;
end;

procedure TSubtitlesFrame.edtSubLangChangeBounds(Sender: TObject);
begin
  g_PobierakSettings.s_SubLang := edtSubLang.text;
  AppGlobalSettings.G_SubLang := edtSubLang.text;
end;




end.
