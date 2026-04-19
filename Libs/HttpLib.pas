{******************************************************************************
  Plan9Basic Interpreter Engine

  MIT License
  Copyright (c) 2026 André Murta

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
******************************************************************************}

unit HttpLib;

{******************************************************************************
  HttpLib - HTTP Client Library for Plan9Basic
  Version: 4.0 - Pure Synchronous (No Events, No Async)

  Simple, blocking HTTP requests that return results directly.
  Works on all platforms: Windows, macOS, Linux, Android, iOS.

  USAGE:
    let client# = http_client#("https://api.example.com")
    let response$ = http_get$(client#, "/data")
    if http_ok(client#) <> 0 then
        println response$
    end if
    let x = http_free(client#)

  Function Count: 82 functions
******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Net.HttpClient, System.Net.URLClient,
  System.Net.HttpClientComponent, System.Net.Mime, System.NetEncoding,
  System.Generics.Collections, System.IOUtils,
  exec, UnitGC, basic;

const
  HTTP_GC_TAG = 'BASIC_HTTP';
  HTTP_FORM_GC_TAG = 'BASIC_HTTP_FORM';

procedure RegisterHttpFuncs(Funcs: TFunctionsDictionary; Eng: TBasicEngine; OutP: TStrings);

implementation

var
  lastError: Integer;
  lastErrorMsg: String;

const
  ERR_NONE = 0;
  ERR_INVALID_CLIENT = 1;
  ERR_INVALID_URL = 2;
  ERR_CONNECTION = 3;
  ERR_TIMEOUT = 4;
  ERR_SSL = 5;
  ERR_INVALID_ARGUMENT = 6;
  ERR_FILE = 7;
  ERR_AUTH = 8;
  ERR_INVALID_RESPONSE = 9;
  ERR_INVALID_FORM = 10;

type
  TFormFieldType = (fftText, fftFile);

  TFormField = record
    FieldType: TFormFieldType;
    Name: String;
    Value: String;
    FileName: String;
    ContentType: String;
  end;

  TBasHttpFormData = class
  private
    FFields: TList<TFormField>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddField(const Name, Value: String);
    procedure AddFile(const FieldName, FilePath: String);
    procedure AddFileNamed(const FieldName, FilePath, AFileName: String);
    procedure AddFileTyped(const FieldName, FilePath, AFileName, AContentType: String);
    procedure Clear;
    function GetFieldCount: Integer;
    function GetFileCount: Integer;
    function BuildMultipartFormData: TMultipartFormData;
    function BuildUrlEncoded: String;
    property Fields: TList<TFormField> read FFields;
  end;

  TBasHttpClient = class
  private
    FClient: TNetHTTPClient;
    FHeaders: TStringList;
    FCookies: TStringList;
    FQueryParams: TStringList;
    FLastStatusCode: Integer;
    FLastStatusText: String;
    FLastResponseHeaders: TStringList;
    FLastResponseBody: String;
    FLastResponseBytes: TBytes;
    FLastResponseCookies: TStringList;
    FLastContentType: String;
    FLastContentLength: Int64;
    FLastRedirectUrl: String;
    FBaseUrl: String;
    FUserAgent: String;
    FTimeout: Integer;
    FResponseTimeout: Integer;
    FFollowRedirects: Boolean;
    FMaxRedirects: Integer;
    FAcceptEncoding: String;
    FContentType: String;
    FAccept: String;
    FAcceptCharset: String;
    FAcceptLanguage: String;
    FAuthType: String;
    FAuthUsername: String;
    FAuthPassword: String;
    FAuthToken: String;
    FAuthHeader: String;
    FProxyHost: String;
    FProxyPort: Integer;
    FProxyUsername: String;
    FProxyPassword: String;
    FValidateSSL: Boolean;
    FLastRequestUrl: String;
    FLastRequestMethod: String;
    FLastError: Integer;
    FLastErrorMsg: String;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ApplySettings;
    procedure ClearLastResponse;
    procedure StoreResponse(const Response: IHTTPResponse);
    function BuildFullUrl(const Endpoint: String): String;
    function GetAuthHeader: String;
    function BuildQueryString: String;

    // Simple synchronous request execution
    function ExecuteRequest(const Method, Url: String; const Body: String = '';
      BodyStream: TStream = nil; OwnsStream: Boolean = False;
      MultipartData: TMultipartFormData = nil; OwnsMultipart: Boolean = False;
      DownloadStream: TStream = nil; OwnsDownload: Boolean = False): Boolean;

    property Client: TNetHTTPClient read FClient;
    property Headers: TStringList read FHeaders;
    property Cookies: TStringList read FCookies;
    property QueryParams: TStringList read FQueryParams;
    property LastStatusCode: Integer read FLastStatusCode write FLastStatusCode;
    property LastStatusText: String read FLastStatusText write FLastStatusText;
    property LastResponseHeaders: TStringList read FLastResponseHeaders;
    property LastResponseBody: String read FLastResponseBody write FLastResponseBody;
    property LastResponseBytes: TBytes read FLastResponseBytes write FLastResponseBytes;
    property LastResponseCookies: TStringList read FLastResponseCookies;
    property LastContentType: String read FLastContentType write FLastContentType;
    property LastContentLength: Int64 read FLastContentLength write FLastContentLength;
    property LastRedirectUrl: String read FLastRedirectUrl write FLastRedirectUrl;
    property LastRequestUrl: String read FLastRequestUrl;
    property BaseUrl: String read FBaseUrl write FBaseUrl;
    property UserAgent: String read FUserAgent write FUserAgent;
    property Timeout: Integer read FTimeout write FTimeout;
    property ResponseTimeout: Integer read FResponseTimeout write FResponseTimeout;
    property FollowRedirects: Boolean read FFollowRedirects write FFollowRedirects;
    property MaxRedirects: Integer read FMaxRedirects write FMaxRedirects;
    property AcceptEncoding: String read FAcceptEncoding write FAcceptEncoding;
    property ContentType: String read FContentType write FContentType;
    property Accept: String read FAccept write FAccept;
    property AcceptCharset: String read FAcceptCharset write FAcceptCharset;
    property AcceptLanguage: String read FAcceptLanguage write FAcceptLanguage;
    property AuthType: String read FAuthType write FAuthType;
    property AuthUsername: String read FAuthUsername write FAuthUsername;
    property AuthPassword: String read FAuthPassword write FAuthPassword;
    property AuthToken: String read FAuthToken write FAuthToken;
    property AuthHeader: String read FAuthHeader write FAuthHeader;
    property ProxyHost: String read FProxyHost write FProxyHost;
    property ProxyPort: Integer read FProxyPort write FProxyPort;
    property ProxyUsername: String read FProxyUsername write FProxyUsername;
    property ProxyPassword: String read FProxyPassword write FProxyPassword;
    property ValidateSSL: Boolean read FValidateSSL write FValidateSSL;
    property ClientLastError: Integer read FLastError write FLastError;
    property ClientLastErrorMsg: String read FLastErrorMsg write FLastErrorMsg;
  end;

var
  ValidHttpClients: TList<Pointer>;

//------------------------------------------------------------------------------
// TBasHttpFormData Implementation
//------------------------------------------------------------------------------

constructor TBasHttpFormData.Create;
begin
  inherited Create;
  FFields := TList<TFormField>.Create;
end;

destructor TBasHttpFormData.Destroy;
begin
  FFields.Free;
  inherited;
end;

procedure TBasHttpFormData.AddField(const Name, Value: String);
var
  Field: TFormField;
begin
  Field.FieldType := fftText;
  Field.Name := Name;
  Field.Value := Value;
  Field.FileName := '';
  Field.ContentType := '';
  FFields.Add(Field);
end;

procedure TBasHttpFormData.AddFile(const FieldName, FilePath: String);
begin
  AddFileNamed(FieldName, FilePath, ExtractFileName(FilePath));
end;

procedure TBasHttpFormData.AddFileNamed(const FieldName, FilePath, AFileName: String);
var
  Ext: String;
  ContentType: String;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if Ext = '.jpg' then ContentType := 'image/jpeg'
  else if Ext = '.jpeg' then ContentType := 'image/jpeg'
  else if Ext = '.png' then ContentType := 'image/png'
  else if Ext = '.gif' then ContentType := 'image/gif'
  else if Ext = '.pdf' then ContentType := 'application/pdf'
  else if Ext = '.txt' then ContentType := 'text/plain'
  else if Ext = '.html' then ContentType := 'text/html'
  else if Ext = '.xml' then ContentType := 'application/xml'
  else if Ext = '.json' then ContentType := 'application/json'
  else ContentType := 'application/octet-stream';
  AddFileTyped(FieldName, FilePath, AFileName, ContentType);
end;

procedure TBasHttpFormData.AddFileTyped(const FieldName, FilePath, AFileName, AContentType: String);
var
  Field: TFormField;
begin
  Field.FieldType := fftFile;
  Field.Name := FieldName;
  Field.Value := FilePath;
  Field.FileName := AFileName;
  Field.ContentType := AContentType;
  FFields.Add(Field);
end;

procedure TBasHttpFormData.Clear;
begin
  FFields.Clear;
end;

function TBasHttpFormData.GetFieldCount: Integer;
var
  Field: TFormField;
begin
  Result := 0;
  for Field in FFields do
    if Field.FieldType = fftText then
      Inc(Result);
end;

function TBasHttpFormData.GetFileCount: Integer;
var
  Field: TFormField;
begin
  Result := 0;
  for Field in FFields do
    if Field.FieldType = fftFile then
      Inc(Result);
end;

function TBasHttpFormData.BuildMultipartFormData: TMultipartFormData;
var
  Field: TFormField;
begin
  Result := TMultipartFormData.Create;
  for Field in FFields do
  begin
    if Field.FieldType = fftText then
      Result.AddField(Field.Name, Field.Value)
    else if Field.FieldType = fftFile then
    begin
      if FileExists(Field.Value) then
        Result.AddFile(Field.Name, Field.Value, Field.ContentType);
    end;
  end;
end;

function TBasHttpFormData.BuildUrlEncoded: String;
var
  Field: TFormField;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    for Field in FFields do
      if Field.FieldType = fftText then
        Parts.Add(TNetEncoding.URL.Encode(Field.Name) + '=' + TNetEncoding.URL.Encode(Field.Value));
    Result := String.Join('&', Parts.ToStringArray);
  finally
    Parts.Free;
  end;
end;

//------------------------------------------------------------------------------
// TBasHttpClient Implementation
//------------------------------------------------------------------------------

constructor TBasHttpClient.Create;
begin
  inherited Create;
  FClient := TNetHTTPClient.Create(nil);
  FHeaders := TStringList.Create;
  FCookies := TStringList.Create;
  FQueryParams := TStringList.Create;
  FLastResponseHeaders := TStringList.Create;
  FLastResponseCookies := TStringList.Create;

  // Defaults
  FUserAgent := 'Plan9Basic-HttpLib/4.0';
  FTimeout := 30000;
  FResponseTimeout := 60000;
  FFollowRedirects := True;
  FMaxRedirects := 5;
  FAcceptEncoding := 'gzip, deflate';
  FContentType := '';
  FAccept := '*/*';
  FAcceptCharset := 'utf-8';
  FAcceptLanguage := 'en-US,en;q=0.9';
  FValidateSSL := True;
  FLastError := 0;
  FLastErrorMsg := '';

  // Set name-value separator for headers (stored as "Name:Value")
  FLastResponseHeaders.NameValueSeparator := ':';

  // Register in valid clients list
  if Assigned(ValidHttpClients) then
    ValidHttpClients.Add(Pointer(Self));

  ApplySettings;
end;

destructor TBasHttpClient.Destroy;
begin
  // Unregister from valid clients list
  if Assigned(ValidHttpClients) then
    ValidHttpClients.Remove(Pointer(Self));

  FClient.Free;
  FHeaders.Free;
  FCookies.Free;
  FQueryParams.Free;
  FLastResponseHeaders.Free;
  FLastResponseCookies.Free;
  inherited;
end;

procedure TBasHttpClient.ApplySettings;
begin
  FClient.UserAgent := FUserAgent;
  FClient.ConnectionTimeout := FTimeout;
  FClient.ResponseTimeout := FResponseTimeout;
  FClient.HandleRedirects := FFollowRedirects;
  FClient.MaxRedirects := FMaxRedirects;
  FClient.AcceptEncoding := FAcceptEncoding;
  FClient.Accept := FAccept;
  FClient.ContentType := FContentType;
  FClient.AcceptCharSet := FAcceptCharset;
  FClient.AcceptLanguage := FAcceptLanguage;
  if FProxyHost <> '' then
    FClient.ProxySettings := TProxySettings.Create(FProxyHost, FProxyPort, FProxyUsername, FProxyPassword);
end;

procedure TBasHttpClient.ClearLastResponse;
begin
  FLastStatusCode := 0;
  FLastStatusText := '';
  FLastResponseHeaders.Clear;
  FLastResponseBody := '';
  SetLength(FLastResponseBytes, 0);
  FLastResponseCookies.Clear;
  FLastContentType := '';
  FLastContentLength := 0;
  FLastRedirectUrl := '';
  FLastError := 0;
  FLastErrorMsg := '';
end;

procedure TBasHttpClient.StoreResponse(const Response: IHTTPResponse);
var
  i: Integer;
  LocHeader: String;
begin
  ClearLastResponse;
  if Response <> nil then
  begin
    FLastStatusCode := Response.StatusCode;
    FLastStatusText := Response.StatusText;
    FLastContentType := Response.MimeType;
    FLastContentLength := Response.ContentLength;

    for i := 0 to Length(Response.Headers) - 1 do
      FLastResponseHeaders.Add(Response.Headers[i].Name + ':' + Response.Headers[i].Value);

    SetLength(FLastResponseBytes, 0);
    if (Response.ContentStream <> nil) and (Response.ContentStream.Size > 0) then
    begin
      Response.ContentStream.Position := 0;
      SetLength(FLastResponseBytes, Response.ContentStream.Size);
      Response.ContentStream.ReadBuffer(FLastResponseBytes[0], Response.ContentStream.Size);
      Response.ContentStream.Position := 0;
    end;

    FLastResponseBody := Response.ContentAsString();

    for i := 0 to Response.Cookies.Count - 1 do
      FLastResponseCookies.Add(Response.Cookies[i].Name + '=' + Response.Cookies[i].Value);

    LocHeader := '';
    for i := 0 to Length(Response.Headers) - 1 do
    begin
      if SameText(Response.Headers[i].Name, 'Location') then
      begin
        LocHeader := Response.Headers[i].Value;
        Break;
      end;
    end;
    if LocHeader <> '' then
      FLastRedirectUrl := LocHeader;
  end;
end;

function TBasHttpClient.BuildFullUrl(const Endpoint: String): String;
var
  QueryStr: String;
begin
  if (Endpoint.StartsWith('http://')) or (Endpoint.StartsWith('https://')) then
    Result := Endpoint
  else if FBaseUrl <> '' then
  begin
    if FBaseUrl.EndsWith('/') and Endpoint.StartsWith('/') then
      Result := FBaseUrl + Copy(Endpoint, 2, MaxInt)
    else if (not FBaseUrl.EndsWith('/')) and (not Endpoint.StartsWith('/')) then
      Result := FBaseUrl + '/' + Endpoint
    else
      Result := FBaseUrl + Endpoint;
  end
  else
    Result := Endpoint;

  QueryStr := BuildQueryString;
  if QueryStr <> '' then
  begin
    if Pos('?', Result) > 0 then
      Result := Result + '&' + QueryStr
    else
      Result := Result + '?' + QueryStr;
  end;

  FLastRequestUrl := Result;
end;

function TBasHttpClient.GetAuthHeader: String;
begin
  Result := '';
  if FAuthType = 'basic' then
    Result := 'Basic ' + TNetEncoding.Base64.Encode(FAuthUsername + ':' + FAuthPassword)
  else if FAuthType = 'bearer' then
    Result := 'Bearer ' + FAuthToken
  else if FAuthType = 'custom' then
    Result := FAuthHeader;
end;

function TBasHttpClient.BuildQueryString: String;
var
  i: Integer;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    for i := 0 to FQueryParams.Count - 1 do
      Parts.Add(TNetEncoding.URL.Encode(FQueryParams.Names[i]) + '=' +
                TNetEncoding.URL.Encode(FQueryParams.ValueFromIndex[i]));
    Result := String.Join('&', Parts.ToStringArray);
  finally
    Parts.Free;
  end;
end;

function TBasHttpClient.ExecuteRequest(const Method, Url: String; const Body: String;
  BodyStream: TStream; OwnsStream: Boolean;
  MultipartData: TMultipartFormData; OwnsMultipart: Boolean;
  DownloadStream: TStream; OwnsDownload: Boolean): Boolean;
var
  Response: IHTTPResponse;
  FullUrl: String;
  AuthHdr: String;
  i: Integer;
  HeaderName, HeaderValue: String;
  ReqBodyStream: TStringStream;
begin
  Result := False;
  ClearLastResponse;
  FLastRequestMethod := Method;

  try
    ApplySettings;
    FullUrl := BuildFullUrl(Url);

    // Clear existing custom headers
    FClient.CustHeaders.Clear;

    // Add custom headers
    for i := 0 to FHeaders.Count - 1 do
    begin
      HeaderName := FHeaders.Names[i];
      HeaderValue := FHeaders.ValueFromIndex[i];
      FClient.CustHeaders.Add(TNameValuePair.Create(HeaderName, HeaderValue));
    end;

    // Add auth header
    AuthHdr := GetAuthHeader;
    if AuthHdr <> '' then
      FClient.CustHeaders.Add(TNameValuePair.Create('Authorization', AuthHdr));

    // Add cookies
    if FCookies.Count > 0 then
    begin
      HeaderValue := '';
      for i := 0 to FCookies.Count - 1 do
      begin
        if HeaderValue <> '' then
          HeaderValue := HeaderValue + '; ';
        HeaderValue := HeaderValue + FCookies.Names[i] + '=' + FCookies.ValueFromIndex[i];
      end;
      FClient.CustHeaders.Add(TNameValuePair.Create('Cookie', HeaderValue));
    end;

    // Execute request based on method
    if SameText(Method, 'GET') then
    begin
      if DownloadStream <> nil then
        Response := FClient.Get(FullUrl, DownloadStream)
      else
        Response := FClient.Get(FullUrl);
    end
    else if SameText(Method, 'POST') then
    begin
      if MultipartData <> nil then
        Response := FClient.Post(FullUrl, MultipartData)
      else if BodyStream <> nil then
        Response := FClient.Post(FullUrl, BodyStream)
      else if Body <> '' then
      begin
        ReqBodyStream := TStringStream.Create(Body, TEncoding.UTF8);
        try
          Response := FClient.Post(FullUrl, ReqBodyStream);
        finally
          ReqBodyStream.Free;
        end;
      end
      else
        Response := FClient.Post(FullUrl, TStream(nil));
    end
    else if SameText(Method, 'PUT') then
    begin
      if MultipartData <> nil then
        Response := FClient.Put(FullUrl, MultipartData)
      else if BodyStream <> nil then
        Response := FClient.Put(FullUrl, BodyStream)
      else if Body <> '' then
      begin
        ReqBodyStream := TStringStream.Create(Body, TEncoding.UTF8);
        try
          Response := FClient.Put(FullUrl, ReqBodyStream);
        finally
          ReqBodyStream.Free;
        end;
      end
      else
        Response := FClient.Put(FullUrl, TStream(nil));
    end
    else if SameText(Method, 'PATCH') then
    begin
      if BodyStream <> nil then
        Response := FClient.Patch(FullUrl, BodyStream)
      else if Body <> '' then
      begin
        ReqBodyStream := TStringStream.Create(Body, TEncoding.UTF8);
        try
          Response := FClient.Patch(FullUrl, ReqBodyStream);
        finally
          ReqBodyStream.Free;
        end;
      end
      else
        Response := FClient.Patch(FullUrl, TStream(nil));
    end
    else if SameText(Method, 'DELETE') then
      Response := FClient.Delete(FullUrl)
    else if SameText(Method, 'HEAD') then
      Response := FClient.Head(FullUrl)
    else if SameText(Method, 'OPTIONS') then
      Response := FClient.Options(FullUrl)
    else
    begin
      FLastError := ERR_INVALID_ARGUMENT;
      FLastErrorMsg := 'Unknown HTTP method: ' + Method;
      Exit;
    end;

    StoreResponse(Response);
    Result := True;

  except
    on E: ENetHTTPClientException do
    begin
      FLastError := ERR_CONNECTION;
      FLastErrorMsg := E.Message;
      lastError := ERR_CONNECTION;
      lastErrorMsg := E.Message;
    end;
    on E: Exception do
    begin
      FLastError := ERR_CONNECTION;
      FLastErrorMsg := E.Message;
      lastError := ERR_CONNECTION;
      lastErrorMsg := E.Message;
    end;
  end;

  // Cleanup owned resources
  if OwnsStream and (BodyStream <> nil) then
    BodyStream.Free;
  if OwnsMultipart and (MultipartData <> nil) then
    MultipartData.Free;
  if OwnsDownload and (DownloadStream <> nil) then
    DownloadStream.Free;
end;

//------------------------------------------------------------------------------
// Validation Helpers
//------------------------------------------------------------------------------

procedure SetError(Code: Integer; const Msg: String);
begin
  lastError := Code;
  lastErrorMsg := Msg;
end;

procedure ValidateClient(P: Pointer; const FuncName: String);
begin
  if P = nil then
  begin
    SetError(ERR_INVALID_CLIENT, FuncName + ': Client is nil');
    raise Exception.Create(FuncName + ': Client is nil');
  end;
  if not Assigned(ValidHttpClients) or (ValidHttpClients.IndexOf(P) < 0) then
  begin
    SetError(ERR_INVALID_CLIENT, FuncName + ': Invalid client pointer');
    raise Exception.Create(FuncName + ': Invalid client pointer');
  end;
end;

//------------------------------------------------------------------------------
// Error Functions
//------------------------------------------------------------------------------

function n_http_error(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := lastError;
  Result.s := '';
  Result.p := nil;
end;

function s_http_errormsg(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := lastErrorMsg;
  Result.p := nil;
end;

function s_http_strerror(var Args: Array of TAsmData): TAsmData;
var
  Code: Integer;
begin
  Code := Trunc(Args[0].n);
  Result.n := 0;
  Result.p := nil;
  case Code of
    ERR_NONE: Result.s := 'No error';
    ERR_INVALID_CLIENT: Result.s := 'Invalid or null client pointer';
    ERR_INVALID_URL: Result.s := 'Malformed URL';
    ERR_CONNECTION: Result.s := 'Network connection failed';
    ERR_TIMEOUT: Result.s := 'Request timed out';
    ERR_SSL: Result.s := 'SSL/TLS certificate error';
    ERR_INVALID_ARGUMENT: Result.s := 'Invalid function argument';
    ERR_FILE: Result.s := 'File read/write error';
    ERR_AUTH: Result.s := 'Authentication failed';
    ERR_INVALID_RESPONSE: Result.s := 'Malformed response';
    ERR_INVALID_FORM: Result.s := 'Invalid form data pointer';
  else
    Result.s := 'Unknown error code: ' + IntToStr(Code);
  end;
end;

function n_http_clearerror(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  lastErrorMsg := '';
  Result.n := 1;
  Result.s := '';
  Result.p := nil;
end;

//------------------------------------------------------------------------------
// Client Creation/Management
//------------------------------------------------------------------------------

function p_http_client(var Args: Array of TAsmData): TAsmData;
var
  Client: TBasHttpClient;
begin
  Client := TBasHttpClient.Create;
  GC.Add(Client, HTTP_GC_TAG);
  Result.n := 0;
  Result.s := '';
  Result.p := Pointer(Client);
end;

function p_http_client_url(var Args: Array of TAsmData): TAsmData;
var
  Client: TBasHttpClient;
begin
  Client := TBasHttpClient.Create;
  Client.BaseUrl := Args[0].s;
  GC.Add(Client, HTTP_GC_TAG);
  Result.n := 0;
  Result.s := '';
  Result.p := Pointer(Client);
end;

function n_http_free(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    if Args[0].p <> nil then
    begin
      ValidateClient(Args[0].p, 'http_free');
      GC.Release(TObject(Args[0].p));
      TBasHttpClient(Args[0].p).Free;
      Result.n := 1;
    end;
  except
  end;
end;

function p_http_reset(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_reset#');
    with TBasHttpClient(Args[0].p) do
    begin
      Headers.Clear;
      Cookies.Clear;
      QueryParams.Clear;
      ClearLastResponse;
      AuthType := '';
      AuthUsername := '';
      AuthPassword := '';
      AuthToken := '';
      AuthHeader := '';
    end;
  except
  end;
end;

//------------------------------------------------------------------------------
// Client Configuration
//------------------------------------------------------------------------------

function p_http_baseurl(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_baseurl#');
    TBasHttpClient(Args[0].p).BaseUrl := Args[1].s;
  except
  end;
end;

function s_http_baseurl_get(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_baseurl$');
    Result.s := TBasHttpClient(Args[0].p).BaseUrl;
  except
  end;
end;

function p_http_timeout(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_timeout#');
    TBasHttpClient(Args[0].p).Timeout := Trunc(Args[1].n);
  except
  end;
end;

function n_http_timeout_get(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_timeout');
    Result.n := TBasHttpClient(Args[0].p).Timeout;
  except
  end;
end;

function p_http_responsetimeout(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_responsetimeout#');
    TBasHttpClient(Args[0].p).ResponseTimeout := Trunc(Args[1].n);
  except
  end;
end;

function p_http_useragent(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_useragent#');
    TBasHttpClient(Args[0].p).UserAgent := Args[1].s;
  except
  end;
end;

function p_http_contenttype(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_contenttype#');
    TBasHttpClient(Args[0].p).ContentType := Args[1].s;
  except
  end;
end;

function p_http_accept(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_accept#');
    TBasHttpClient(Args[0].p).Accept := Args[1].s;
  except
  end;
end;

function p_http_followredirects(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_followredirects#');
    TBasHttpClient(Args[0].p).FollowRedirects := Args[1].n <> 0;
  except
  end;
end;

function p_http_maxredirects(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_maxredirects#');
    TBasHttpClient(Args[0].p).MaxRedirects := Trunc(Args[1].n);
  except
  end;
end;

function p_http_validatessl(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_validatessl#');
    TBasHttpClient(Args[0].p).ValidateSSL := Args[1].n <> 0;
  except
  end;
end;

//------------------------------------------------------------------------------
// Query Parameters
//------------------------------------------------------------------------------

function p_http_param(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_param#');
    TBasHttpClient(Args[0].p).QueryParams.Values[Args[1].s] := Args[2].s;
  except
  end;
end;

function s_http_param_get(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_param$');
    Result.s := TBasHttpClient(Args[0].p).QueryParams.Values[Args[1].s];
  except
  end;
end;

function p_http_paramremove(var Args: Array of TAsmData): TAsmData;
var
  Idx: Integer;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_paramremove#');
    Idx := TBasHttpClient(Args[0].p).QueryParams.IndexOfName(Args[1].s);
    if Idx >= 0 then
      TBasHttpClient(Args[0].p).QueryParams.Delete(Idx);
  except
  end;
end;

function p_http_paramclear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_paramclear#');
    TBasHttpClient(Args[0].p).QueryParams.Clear;
  except
  end;
end;

//------------------------------------------------------------------------------
// Headers
//------------------------------------------------------------------------------

function p_http_header(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_header#');
    TBasHttpClient(Args[0].p).Headers.Values[Args[1].s] := Args[2].s;
  except
  end;
end;

function s_http_header_get(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_header$');
    Result.s := TBasHttpClient(Args[0].p).Headers.Values[Args[1].s];
  except
  end;
end;

function p_http_headerremove(var Args: Array of TAsmData): TAsmData;
var
  Idx: Integer;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_headerremove#');
    Idx := TBasHttpClient(Args[0].p).Headers.IndexOfName(Args[1].s);
    if Idx >= 0 then
      TBasHttpClient(Args[0].p).Headers.Delete(Idx);
  except
  end;
end;

function p_http_headerclear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_headerclear#');
    TBasHttpClient(Args[0].p).Headers.Clear;
  except
  end;
end;

function n_http_headercount(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_headercount');
    Result.n := TBasHttpClient(Args[0].p).Headers.Count;
  except
  end;
end;

//------------------------------------------------------------------------------
// Authentication
//------------------------------------------------------------------------------

function p_http_basicauth(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_basicauth#');
    TBasHttpClient(Args[0].p).AuthType := 'basic';
    TBasHttpClient(Args[0].p).AuthUsername := Args[1].s;
    TBasHttpClient(Args[0].p).AuthPassword := Args[2].s;
  except
  end;
end;

function p_http_bearerauth(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_bearerauth#');
    TBasHttpClient(Args[0].p).AuthType := 'bearer';
    TBasHttpClient(Args[0].p).AuthToken := Args[1].s;
  except
  end;
end;

function p_http_customauth(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_customauth#');
    TBasHttpClient(Args[0].p).AuthType := 'custom';
    TBasHttpClient(Args[0].p).AuthHeader := Args[1].s;
  except
  end;
end;

function p_http_clearauth(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_clearauth#');
    TBasHttpClient(Args[0].p).AuthType := '';
    TBasHttpClient(Args[0].p).AuthUsername := '';
    TBasHttpClient(Args[0].p).AuthPassword := '';
    TBasHttpClient(Args[0].p).AuthToken := '';
    TBasHttpClient(Args[0].p).AuthHeader := '';
  except
  end;
end;

//------------------------------------------------------------------------------
// Cookies
//------------------------------------------------------------------------------

function p_http_cookie(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_cookie#');
    TBasHttpClient(Args[0].p).Cookies.Values[Args[1].s] := Args[2].s;
  except
  end;
end;

function s_http_cookie_get(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_cookie$');
    Result.s := TBasHttpClient(Args[0].p).Cookies.Values[Args[1].s];
  except
  end;
end;

function p_http_cookieremove(var Args: Array of TAsmData): TAsmData;
var
  Idx: Integer;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_cookieremove#');
    Idx := TBasHttpClient(Args[0].p).Cookies.IndexOfName(Args[1].s);
    if Idx >= 0 then
      TBasHttpClient(Args[0].p).Cookies.Delete(Idx);
  except
  end;
end;

function p_http_cookieclear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_cookieclear#');
    TBasHttpClient(Args[0].p).Cookies.Clear;
  except
  end;
end;

function n_http_cookiecount(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_cookiecount');
    Result.n := TBasHttpClient(Args[0].p).Cookies.Count;
  except
  end;
end;

//------------------------------------------------------------------------------
// Proxy
//------------------------------------------------------------------------------

function p_http_proxy(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_proxy#');
    TBasHttpClient(Args[0].p).ProxyHost := Args[1].s;
    TBasHttpClient(Args[0].p).ProxyPort := Trunc(Args[2].n);
  except
  end;
end;

function p_http_proxyauth(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_proxyauth#');
    TBasHttpClient(Args[0].p).ProxyUsername := Args[1].s;
    TBasHttpClient(Args[0].p).ProxyPassword := Args[2].s;
  except
  end;
end;

function p_http_clearproxy(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    ValidateClient(Args[0].p, 'http_clearproxy#');
    TBasHttpClient(Args[0].p).ProxyHost := '';
    TBasHttpClient(Args[0].p).ProxyPort := 0;
    TBasHttpClient(Args[0].p).ProxyUsername := '';
    TBasHttpClient(Args[0].p).ProxyPassword := '';
  except
  end;
end;

//------------------------------------------------------------------------------
// Form Data
//------------------------------------------------------------------------------

function p_http_form(var Args: Array of TAsmData): TAsmData;
var
  Form: TBasHttpFormData;
begin
  Form := TBasHttpFormData.Create;
  GC.Add(Form, HTTP_FORM_GC_TAG);
  Result.n := 0;
  Result.s := '';
  Result.p := Pointer(Form);
end;

function p_http_formfield(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    if Args[0].p = nil then
    begin
      SetError(ERR_INVALID_FORM, 'http_formfield#: Form is nil');
      Exit;
    end;
    TBasHttpFormData(Args[0].p).AddField(Args[1].s, Args[2].s);
  except
  end;
end;

function p_http_formfile(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    if Args[0].p = nil then
    begin
      SetError(ERR_INVALID_FORM, 'http_formfile#: Form is nil');
      Exit;
    end;
    TBasHttpFormData(Args[0].p).AddFile(Args[1].s, Args[2].s);
  except
  end;
end;

function p_http_formfilenamed(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    if Args[0].p = nil then
    begin
      SetError(ERR_INVALID_FORM, 'http_formfilenamed#: Form is nil');
      Exit;
    end;
    TBasHttpFormData(Args[0].p).AddFileNamed(Args[1].s, Args[2].s, Args[3].s);
  except
  end;
end;

function p_http_formfiletype(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    if Args[0].p = nil then
    begin
      SetError(ERR_INVALID_FORM, 'http_formfiletype#: Form is nil');
      Exit;
    end;
    TBasHttpFormData(Args[0].p).AddFileTyped(Args[1].s, Args[2].s, Args[3].s, Args[4].s);
  except
  end;
end;

function p_http_formclear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := Args[0].p;
  try
    if Args[0].p <> nil then
      TBasHttpFormData(Args[0].p).Clear;
  except
  end;
end;

function n_http_formfieldcount(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    if Args[0].p <> nil then
      Result.n := TBasHttpFormData(Args[0].p).GetFieldCount;
  except
  end;
end;

function n_http_formfilecount(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    if Args[0].p <> nil then
      Result.n := TBasHttpFormData(Args[0].p).GetFileCount;
  except
  end;
end;

function s_http_formurlencoded(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    if Args[0].p <> nil then
      Result.s := TBasHttpFormData(Args[0].p).BuildUrlEncoded;
  except
  end;
end;

function n_http_formfree(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    if Args[0].p <> nil then
    begin
      GC.Release(TObject(Args[0].p));
      TBasHttpFormData(Args[0].p).Free;
      Result.n := 1;
    end;
  except
  end;
end;

//------------------------------------------------------------------------------
// HTTP Methods - All Synchronous
//------------------------------------------------------------------------------

function s_http_get(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_get$');
    TBasHttpClient(Args[0].p).ExecuteRequest('GET', Args[1].s);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function s_http_post(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_post$');
    TBasHttpClient(Args[0].p).ExecuteRequest('POST', Args[1].s, Args[2].s);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function s_http_postform(var Args: Array of TAsmData): TAsmData;
var
  MultipartData: TMultipartFormData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_postform$');
    if Args[2].p = nil then
    begin
      SetError(ERR_INVALID_FORM, 'http_postform$: Form is nil');
      Exit;
    end;
    MultipartData := TBasHttpFormData(Args[2].p).BuildMultipartFormData;
    TBasHttpClient(Args[0].p).ExecuteRequest('POST', Args[1].s, '', nil, False, MultipartData, True);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function s_http_postformurl(var Args: Array of TAsmData): TAsmData;
var
  FormStr: String;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_postformurl$');
    if Args[2].p = nil then
    begin
      SetError(ERR_INVALID_FORM, 'http_postformurl$: Form is nil');
      Exit;
    end;
    TBasHttpClient(Args[0].p).ContentType := 'application/x-www-form-urlencoded';
    FormStr := TBasHttpFormData(Args[2].p).BuildUrlEncoded;
    TBasHttpClient(Args[0].p).ExecuteRequest('POST', Args[1].s, FormStr);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function s_http_postformstr(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_postformstr$');
    TBasHttpClient(Args[0].p).ContentType := 'application/x-www-form-urlencoded';
    TBasHttpClient(Args[0].p).ExecuteRequest('POST', Args[1].s, Args[2].s);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function s_http_put(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_put$');
    TBasHttpClient(Args[0].p).ExecuteRequest('PUT', Args[1].s, Args[2].s);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function s_http_putform(var Args: Array of TAsmData): TAsmData;
var
  MultipartData: TMultipartFormData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_putform$');
    if Args[2].p = nil then
    begin
      SetError(ERR_INVALID_FORM, 'http_putform$: Form is nil');
      Exit;
    end;
    MultipartData := TBasHttpFormData(Args[2].p).BuildMultipartFormData;
    TBasHttpClient(Args[0].p).ExecuteRequest('PUT', Args[1].s, '', nil, False, MultipartData, True);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function s_http_patch(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_patch$');
    TBasHttpClient(Args[0].p).ExecuteRequest('PATCH', Args[1].s, Args[2].s);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function s_http_delete(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_delete$');
    TBasHttpClient(Args[0].p).ExecuteRequest('DELETE', Args[1].s);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function n_http_head(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_head');
    TBasHttpClient(Args[0].p).ExecuteRequest('HEAD', Args[1].s);
    Result.n := TBasHttpClient(Args[0].p).LastStatusCode;
  except
  end;
end;

function s_http_options(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_options$');
    TBasHttpClient(Args[0].p).ExecuteRequest('OPTIONS', Args[1].s);
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

//------------------------------------------------------------------------------
// Response Access
//------------------------------------------------------------------------------

function n_http_status(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_status');
    Result.n := TBasHttpClient(Args[0].p).LastStatusCode;
  except
  end;
end;

function s_http_statustext(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_statustext$');
    Result.s := TBasHttpClient(Args[0].p).LastStatusText;
  except
  end;
end;

function s_http_body(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_body$');
    Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
  except
  end;
end;

function s_http_bodybase64(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_bodybase64$');
    Result.s := TNetEncoding.Base64.EncodeBytesToString(TBasHttpClient(Args[0].p).LastResponseBytes);
  except
  end;
end;

function s_http_respheader(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  HdrName, HdrValue: String;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_respheader$');
    for i := 0 to TBasHttpClient(Args[0].p).LastResponseHeaders.Count - 1 do
    begin
      HdrName := TBasHttpClient(Args[0].p).LastResponseHeaders.Names[i];
      if SameText(HdrName, Args[1].s) then
      begin
        HdrValue := TBasHttpClient(Args[0].p).LastResponseHeaders.ValueFromIndex[i];
        Result.s := HdrValue;
        Break;
      end;
    end;
  except
  end;
end;

function s_http_respheaders(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_respheaders$');
    Result.s := TBasHttpClient(Args[0].p).LastResponseHeaders.Text;
  except
  end;
end;

function n_http_respheadercount(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_respheadercount');
    Result.n := TBasHttpClient(Args[0].p).LastResponseHeaders.Count;
  except
  end;
end;

function s_http_respheadername(var Args: Array of TAsmData): TAsmData;
var
  Idx: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_respheadername$');
    Idx := Trunc(Args[1].n);
    if (Idx >= 0) and (Idx < TBasHttpClient(Args[0].p).LastResponseHeaders.Count) then
      Result.s := TBasHttpClient(Args[0].p).LastResponseHeaders.Names[Idx];
  except
  end;
end;

function s_http_respheadervalue(var Args: Array of TAsmData): TAsmData;
var
  Idx: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_respheadervalue$');
    Idx := Trunc(Args[1].n);
    if (Idx >= 0) and (Idx < TBasHttpClient(Args[0].p).LastResponseHeaders.Count) then
      Result.s := TBasHttpClient(Args[0].p).LastResponseHeaders.ValueFromIndex[Idx];
  except
  end;
end;

function s_http_respcookie(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  CookieName: String;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_respcookie$');
    for i := 0 to TBasHttpClient(Args[0].p).LastResponseCookies.Count - 1 do
    begin
      CookieName := TBasHttpClient(Args[0].p).LastResponseCookies.Names[i];
      if SameText(CookieName, Args[1].s) then
      begin
        Result.s := TBasHttpClient(Args[0].p).LastResponseCookies.ValueFromIndex[i];
        Break;
      end;
    end;
  except
  end;
end;

function s_http_respcookies(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_respcookies$');
    Result.s := TBasHttpClient(Args[0].p).LastResponseCookies.Text;
  except
  end;
end;

function n_http_respcookiecount(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_respcookiecount');
    Result.n := TBasHttpClient(Args[0].p).LastResponseCookies.Count;
  except
  end;
end;

function s_http_respcontenttype(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_respcontenttype$');
    Result.s := TBasHttpClient(Args[0].p).LastContentType;
  except
  end;
end;

function n_http_contentlength(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_contentlength');
    Result.n := TBasHttpClient(Args[0].p).LastContentLength;
  except
  end;
end;

function s_http_redirecturl(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_redirecturl$');
    Result.s := TBasHttpClient(Args[0].p).LastRedirectUrl;
  except
  end;
end;

function n_http_ok(var Args: Array of TAsmData): TAsmData;
var
  Status: Integer;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_ok');
    Status := TBasHttpClient(Args[0].p).LastStatusCode;
    if (Status >= 200) and (Status < 300) then
      Result.n := 1;
  except
  end;
end;

function n_http_isredirect(var Args: Array of TAsmData): TAsmData;
var
  Status: Integer;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_isredirect');
    Status := TBasHttpClient(Args[0].p).LastStatusCode;
    if (Status >= 300) and (Status < 400) then
      Result.n := 1;
  except
  end;
end;

function n_http_isclienterror(var Args: Array of TAsmData): TAsmData;
var
  Status: Integer;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_isclienterror');
    Status := TBasHttpClient(Args[0].p).LastStatusCode;
    if (Status >= 400) and (Status < 500) then
      Result.n := 1;
  except
  end;
end;

function n_http_isservererror(var Args: Array of TAsmData): TAsmData;
var
  Status: Integer;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_isservererror');
    Status := TBasHttpClient(Args[0].p).LastStatusCode;
    if (Status >= 500) and (Status < 600) then
      Result.n := 1;
  except
  end;
end;

//------------------------------------------------------------------------------
// File Operations
//------------------------------------------------------------------------------

function n_http_download(var Args: Array of TAsmData): TAsmData;
var
  FileStream: TFileStream;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_download');
    FileStream := TFileStream.Create(Args[2].s, fmCreate);
    try
      TBasHttpClient(Args[0].p).ExecuteRequest('GET', Args[1].s, '', nil, False, nil, False, FileStream, False);
      if TBasHttpClient(Args[0].p).LastStatusCode = 200 then
        Result.n := 1;
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
      SetError(ERR_FILE, E.Message);
  end;
end;

function s_http_upload(var Args: Array of TAsmData): TAsmData;
var
  FileStream: TFileStream;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_upload$');
    if not FileExists(Args[2].s) then
    begin
      SetError(ERR_FILE, 'File not found: ' + Args[2].s);
      Exit;
    end;
    FileStream := TFileStream.Create(Args[2].s, fmOpenRead or fmShareDenyWrite);
    try
      TBasHttpClient(Args[0].p).ExecuteRequest('POST', Args[1].s, '', FileStream, False);
      Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
      SetError(ERR_FILE, E.Message);
  end;
end;

function s_http_uploadput(var Args: Array of TAsmData): TAsmData;
var
  FileStream: TFileStream;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_uploadput$');
    if not FileExists(Args[2].s) then
    begin
      SetError(ERR_FILE, 'File not found: ' + Args[2].s);
      Exit;
    end;
    FileStream := TFileStream.Create(Args[2].s, fmOpenRead or fmShareDenyWrite);
    try
      TBasHttpClient(Args[0].p).ExecuteRequest('PUT', Args[1].s, '', FileStream, False);
      Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
      SetError(ERR_FILE, E.Message);
  end;
end;

function s_http_postfile(var Args: Array of TAsmData): TAsmData;
var
  MultipartData: TMultipartFormData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  try
    ValidateClient(Args[0].p, 'http_postfile$');
    if not FileExists(Args[3].s) then
    begin
      SetError(ERR_FILE, 'File not found: ' + Args[3].s);
      Exit;
    end;
    MultipartData := TMultipartFormData.Create;
    try
      MultipartData.AddFile(Args[2].s, Args[3].s);
      TBasHttpClient(Args[0].p).ExecuteRequest('POST', Args[1].s, '', nil, False, MultipartData, False);
      Result.s := TBasHttpClient(Args[0].p).LastResponseBody;
    finally
      MultipartData.Free;
    end;
  except
    on E: Exception do
      SetError(ERR_FILE, E.Message);
  end;
end;

function n_http_savebody(var Args: Array of TAsmData): TAsmData;
var
  FileStream: TFileStream;
  BodyBytes: TBytes;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  try
    ValidateClient(Args[0].p, 'http_savebody');
    FileStream := TFileStream.Create(Args[1].s, fmCreate);
    try
      BodyBytes := TBasHttpClient(Args[0].p).LastResponseBytes;
      if Length(BodyBytes) > 0 then
        FileStream.WriteBuffer(BodyBytes[0], Length(BodyBytes));
      Result.n := 1;
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
      SetError(ERR_FILE, E.Message);
  end;
end;

//------------------------------------------------------------------------------
// URL/HTML Encoding
//------------------------------------------------------------------------------

function s_http_urlencode(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := TNetEncoding.URL.Encode(Args[0].s);
end;

function s_http_urldecode(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := TNetEncoding.URL.Decode(Args[0].s);
end;

function s_http_htmlencode(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := TNetEncoding.HTML.Encode(Args[0].s);
end;

function s_http_htmldecode(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := TNetEncoding.HTML.Decode(Args[0].s);
end;

//------------------------------------------------------------------------------
// Simple Functions (No Client Required)
//------------------------------------------------------------------------------

function s_http_simpleget(var Args: Array of TAsmData): TAsmData;
var
  Client: TBasHttpClient;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  Client := TBasHttpClient.Create;
  try
    Client.ExecuteRequest('GET', Args[0].s);
    Result.s := Client.LastResponseBody;
  finally
    Client.Free;
  end;
end;

function s_http_simplepost(var Args: Array of TAsmData): TAsmData;
var
  Client: TBasHttpClient;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  Client := TBasHttpClient.Create;
  try
    Client.ExecuteRequest('POST', Args[0].s, Args[1].s);
    Result.s := Client.LastResponseBody;
  finally
    Client.Free;
  end;
end;

function n_http_simpledownload(var Args: Array of TAsmData): TAsmData;
var
  Client: TBasHttpClient;
  FileStream: TFileStream;
begin
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  Client := TBasHttpClient.Create;
  try
    try
      FileStream := TFileStream.Create(Args[1].s, fmCreate);
      try
        Client.ExecuteRequest('GET', Args[0].s, '', nil, False, nil, False, FileStream, False);
        if Client.LastStatusCode = 200 then
          Result.n := 1;
      finally
        FileStream.Free;
      end;
    except
      on E: Exception do
        SetError(ERR_FILE, E.Message);
    end;
  finally
    Client.Free;
  end;
end;

//------------------------------------------------------------------------------
// Registration
//------------------------------------------------------------------------------

procedure RegisterHttpFuncs(Funcs: TFunctionsDictionary; Eng: TBasicEngine; OutP: TStrings);
var
  Fn: TLinkFunction;
begin
  Fn.FarCall := True;

  // Error handling
  Fn.Entry := @n_http_error; Funcs.Add('http_error@', Fn);
  Fn.Entry := @s_http_errormsg; Funcs.Add('http_errormsg$@', Fn);
  Fn.Entry := @s_http_strerror; Funcs.Add('http_strerror$@n', Fn);
  Fn.Entry := @n_http_clearerror; Funcs.Add('http_clearerror@', Fn);

  // Client creation/management
  Fn.Entry := @p_http_client; Funcs.Add('http_client#@', Fn);
  Fn.Entry := @p_http_client_url; Funcs.Add('http_client#@$', Fn);
  Fn.Entry := @n_http_free; Funcs.Add('http_free@#', Fn);
  Fn.Entry := @p_http_reset; Funcs.Add('http_reset#@#', Fn);

  // Client configuration
  Fn.Entry := @p_http_baseurl; Funcs.Add('http_baseurl#@#$', Fn);
  Fn.Entry := @s_http_baseurl_get; Funcs.Add('http_baseurl$@#', Fn);
  Fn.Entry := @p_http_timeout; Funcs.Add('http_timeout#@#n', Fn);
  Fn.Entry := @n_http_timeout_get; Funcs.Add('http_timeout@#', Fn);
  Fn.Entry := @p_http_responsetimeout; Funcs.Add('http_responsetimeout#@#n', Fn);
  Fn.Entry := @p_http_useragent; Funcs.Add('http_useragent#@#$', Fn);
  Fn.Entry := @p_http_contenttype; Funcs.Add('http_contenttype#@#$', Fn);
  Fn.Entry := @p_http_accept; Funcs.Add('http_accept#@#$', Fn);
  Fn.Entry := @p_http_followredirects; Funcs.Add('http_followredirects#@#n', Fn);
  Fn.Entry := @p_http_maxredirects; Funcs.Add('http_maxredirects#@#n', Fn);
  Fn.Entry := @p_http_validatessl; Funcs.Add('http_validatessl#@#n', Fn);

  // Query parameters
  Fn.Entry := @p_http_param; Funcs.Add('http_param#@#$$', Fn);
  Fn.Entry := @s_http_param_get; Funcs.Add('http_param$@#$', Fn);
  Fn.Entry := @p_http_paramremove; Funcs.Add('http_paramremove#@#$', Fn);
  Fn.Entry := @p_http_paramclear; Funcs.Add('http_paramclear#@#', Fn);

  // Headers
  Fn.Entry := @p_http_header; Funcs.Add('http_header#@#$$', Fn);
  Fn.Entry := @s_http_header_get; Funcs.Add('http_header$@#$', Fn);
  Fn.Entry := @p_http_headerremove; Funcs.Add('http_headerremove#@#$', Fn);
  Fn.Entry := @p_http_headerclear; Funcs.Add('http_headerclear#@#', Fn);
  Fn.Entry := @n_http_headercount; Funcs.Add('http_headercount@#', Fn);

  // Authentication
  Fn.Entry := @p_http_basicauth; Funcs.Add('http_basicauth#@#$$', Fn);
  Fn.Entry := @p_http_bearerauth; Funcs.Add('http_bearerauth#@#$', Fn);
  Fn.Entry := @p_http_customauth; Funcs.Add('http_customauth#@#$', Fn);
  Fn.Entry := @p_http_clearauth; Funcs.Add('http_clearauth#@#', Fn);

  // Cookies
  Fn.Entry := @p_http_cookie; Funcs.Add('http_cookie#@#$$', Fn);
  Fn.Entry := @s_http_cookie_get; Funcs.Add('http_cookie$@#$', Fn);
  Fn.Entry := @p_http_cookieremove; Funcs.Add('http_cookieremove#@#$', Fn);
  Fn.Entry := @p_http_cookieclear; Funcs.Add('http_cookieclear#@#', Fn);
  Fn.Entry := @n_http_cookiecount; Funcs.Add('http_cookiecount@#', Fn);

  // Proxy
  Fn.Entry := @p_http_proxy; Funcs.Add('http_proxy#@#$n', Fn);
  Fn.Entry := @p_http_proxyauth; Funcs.Add('http_proxyauth#@#$$', Fn);
  Fn.Entry := @p_http_clearproxy; Funcs.Add('http_clearproxy#@#', Fn);

  // Form data
  Fn.Entry := @p_http_form; Funcs.Add('http_form#@', Fn);
  Fn.Entry := @p_http_formfield; Funcs.Add('http_formfield#@#$$', Fn);
  Fn.Entry := @p_http_formfile; Funcs.Add('http_formfile#@#$$', Fn);
  Fn.Entry := @p_http_formfilenamed; Funcs.Add('http_formfilenamed#@#$$$', Fn);
  Fn.Entry := @p_http_formfiletype; Funcs.Add('http_formfiletype#@#$$$$', Fn);
  Fn.Entry := @p_http_formclear; Funcs.Add('http_formclear#@#', Fn);
  Fn.Entry := @n_http_formfieldcount; Funcs.Add('http_formfieldcount@#', Fn);
  Fn.Entry := @n_http_formfilecount; Funcs.Add('http_formfilecount@#', Fn);
  Fn.Entry := @s_http_formurlencoded; Funcs.Add('http_formurlencoded$@#', Fn);
  Fn.Entry := @n_http_formfree; Funcs.Add('http_formfree@#', Fn);

  // HTTP methods - all synchronous
  Fn.Entry := @s_http_get; Funcs.Add('http_get$@#$', Fn);
  Fn.Entry := @s_http_post; Funcs.Add('http_post$@#$$', Fn);
  Fn.Entry := @s_http_postform; Funcs.Add('http_postform$@#$#', Fn);
  Fn.Entry := @s_http_postformurl; Funcs.Add('http_postformurl$@#$#', Fn);
  Fn.Entry := @s_http_postformstr; Funcs.Add('http_postformstr$@#$$', Fn);
  Fn.Entry := @s_http_put; Funcs.Add('http_put$@#$$', Fn);
  Fn.Entry := @s_http_putform; Funcs.Add('http_putform$@#$#', Fn);
  Fn.Entry := @s_http_patch; Funcs.Add('http_patch$@#$$', Fn);
  Fn.Entry := @s_http_delete; Funcs.Add('http_delete$@#$', Fn);
  Fn.Entry := @n_http_head; Funcs.Add('http_head@#$', Fn);
  Fn.Entry := @s_http_options; Funcs.Add('http_options$@#$', Fn);

  // Response access
  Fn.Entry := @n_http_status; Funcs.Add('http_status@#', Fn);
  Fn.Entry := @s_http_statustext; Funcs.Add('http_statustext$@#', Fn);
  Fn.Entry := @s_http_body; Funcs.Add('http_body$@#', Fn);
  Fn.Entry := @s_http_bodybase64; Funcs.Add('http_bodybase64$@#', Fn);
  Fn.Entry := @s_http_respheader; Funcs.Add('http_respheader$@#$', Fn);
  Fn.Entry := @s_http_respheaders; Funcs.Add('http_respheaders$@#', Fn);
  Fn.Entry := @n_http_respheadercount; Funcs.Add('http_respheadercount@#', Fn);
  Fn.Entry := @s_http_respheadername; Funcs.Add('http_respheadername$@#n', Fn);
  Fn.Entry := @s_http_respheadervalue; Funcs.Add('http_respheadervalue$@#n', Fn);
  Fn.Entry := @s_http_respcookie; Funcs.Add('http_respcookie$@#$', Fn);
  Fn.Entry := @s_http_respcookies; Funcs.Add('http_respcookies$@#', Fn);
  Fn.Entry := @n_http_respcookiecount; Funcs.Add('http_respcookiecount@#', Fn);
  Fn.Entry := @s_http_respcontenttype; Funcs.Add('http_respcontenttype$@#', Fn);
  Fn.Entry := @n_http_contentlength; Funcs.Add('http_contentlength@#', Fn);
  Fn.Entry := @s_http_redirecturl; Funcs.Add('http_redirecturl$@#', Fn);
  Fn.Entry := @n_http_ok; Funcs.Add('http_ok@#', Fn);
  Fn.Entry := @n_http_isredirect; Funcs.Add('http_isredirect@#', Fn);
  Fn.Entry := @n_http_isclienterror; Funcs.Add('http_isclienterror@#', Fn);
  Fn.Entry := @n_http_isservererror; Funcs.Add('http_isservererror@#', Fn);

  // File operations
  Fn.Entry := @n_http_download; Funcs.Add('http_download@#$$', Fn);
  Fn.Entry := @s_http_upload; Funcs.Add('http_upload$@#$$', Fn);
  Fn.Entry := @s_http_uploadput; Funcs.Add('http_uploadput$@#$$', Fn);
  Fn.Entry := @s_http_postfile; Funcs.Add('http_postfile$@#$$$', Fn);
  Fn.Entry := @n_http_savebody; Funcs.Add('http_savebody@#$', Fn);

  // URL/HTML encoding
  Fn.Entry := @s_http_urlencode; Funcs.Add('http_urlencode$@$', Fn);
  Fn.Entry := @s_http_urldecode; Funcs.Add('http_urldecode$@$', Fn);
  Fn.Entry := @s_http_htmlencode; Funcs.Add('http_htmlencode$@$', Fn);
  Fn.Entry := @s_http_htmldecode; Funcs.Add('http_htmldecode$@$', Fn);

  // Simple functions
  Fn.Entry := @s_http_simpleget; Funcs.Add('http_simpleget$@$', Fn);
  Fn.Entry := @s_http_simplepost; Funcs.Add('http_simplepost$@$$', Fn);
  Fn.Entry := @n_http_simpledownload; Funcs.Add('http_simpledownload@$$', Fn);
end;

initialization
  ValidHttpClients := TList<Pointer>.Create;

finalization
  ValidHttpClients.Free;
  ValidHttpClients := nil;

end.
