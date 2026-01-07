unit decorator_StaticText_Link;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls, Graphics, LCLIntf, Controls;

type
  TStaticTextLinkDecorator = class(TComponent)
  private
    FStaticText: TStaticText;
    procedure OnMouseEnter(Sender: TObject);
    procedure OnMouseLeave(Sender: TObject);
    procedure OnClick(Sender: TObject);
  public
    constructor Create(AText: TStaticText);   reintroduce;
    destructor Destroy; override;
  end;

implementation

constructor TStaticTextLinkDecorator.Create(AText: TStaticText);
begin
  if not Assigned(AText) then
    raise Exception.Create('AText cannot be nil');

  if not Assigned(AText.Owner) then
    raise Exception.Create('AText must have an Owner');

  inherited Create(AText.Owner);

  FStaticText := AText;
  FStaticText.OnMouseEnter := @OnMouseEnter;
  FStaticText.OnMouseLeave := @OnMouseLeave;
  FStaticText.OnClick := @OnClick;
end;

destructor TStaticTextLinkDecorator.Destroy;
begin
  if Assigned(FStaticText) then
  begin
    FStaticText.OnMouseEnter := nil;
    FStaticText.OnMouseLeave := nil;
    FStaticText.OnClick := nil;
  end;
  inherited Destroy;
end;

procedure TStaticTextLinkDecorator.OnMouseEnter(Sender: TObject);
begin
  TStaticText(Sender).Cursor := crHandPoint;
  TStaticText(Sender).Font.Color := clBlue;
end;

procedure TStaticTextLinkDecorator.OnMouseLeave(Sender: TObject);
begin
  TStaticText(Sender).Font.Color := clHighlight;
end;

procedure TStaticTextLinkDecorator.OnClick(Sender: TObject);
begin
  OpenURL(TStaticText(Sender).Caption);
end;

end.
