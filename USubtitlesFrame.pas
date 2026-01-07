unit USubtitlesFrame;
{ Copyright (c) 2026 CelularBat
  Licensed under GPLv3: https://www.gnu.org/licenses/gpl-3.0.html }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
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


  private
  public
  end;

implementation

{$R *.lfm}

{ TSubtitlesFrame }

procedure TSubtitlesFrame.btnCheckSubsClick(Sender: TObject);
begin
  RunTab(edtSubtitlesURL.Text + ' --list-subs --simulate ""', 'FSub');
end;

procedure TSubtitlesFrame.btnDownloadSubClick(Sender: TObject);
var
  subs_args: string;
begin
  subs_args := edtSubtitlesURL.Text;
  if (Length(edtSubLang.Text) > 0) then
    subs_args += ' --sub-format "' + edtSubFormat.Text + '"'
  else
    subs_args += ' --sub-format "best"';
  subs_args += ' --sub-langs "' + edtSubLang.Text + '"';
  if (RadioGroupSubs.ItemIndex = 0) then
    subs_args += ' --write-subs'
  else
    subs_args += ' --write-auto-subs';
  subs_args += ' --skip-download ';
  subs_args += ' -o "subs/%(uploader)s_%(title)s.%(ext)s"';
  subs_args += g_PobierakSettings.ParseSettingsArgs(True);

  RunTab(subs_args, [subs_args, 'Downloading subtitles:'], 'Subs');
end;




end.
