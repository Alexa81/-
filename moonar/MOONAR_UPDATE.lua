-- MOONAR UPDATE 1.1 : REAPER/macOS public GitHub updater (OS detection repair)
-- Fixed publisher: https://github.com/Alexa81/-/tree/main/moonar
-- Updates ONLY Scripts/MOONAR_RESYNTH_LIVE.lua; NEVER replaces JSFX or user Presets.
-- Verifies HTTPS download SHA-256 against the manifest, and rejects downgrades.
local SEP=package.config:sub(1,1)
local resource=reaper.GetResourcePath()
local scripts=resource..SEP..'Scripts'
local update_dir=resource..SEP..'MOONAR_RESYNTH'..SEP..'Updates'
local ui_target=scripts..SEP..'MOONAR_RESYNTH_LIVE.lua'
local base='https://raw.githubusercontent.com/Alexa81/-/main/'
local function alert(msg)
  reaper.ShowMessageBox(tostring(msg),'MOONAR GITHUB UPDATE',0)
end
local function read(path)
  local f=io.open(path,'rb')
  if not f then return nil end
  local text=f:read('*a')
  f:close()
  return text
end
local function write(path,content)
  local f,err=io.open(path,'wb')
  if not f then return nil,err end
  local ok,write_err=f:write(content)
  local close_ok,close_err=f:close()
  if not ok or not close_ok then return nil,write_err or close_err end
  return true
end
local function quoted(value)
  return "'"..tostring(value):gsub("'", "'\\''").."'"
end
local function exec(command,timeout)
  if not reaper.ExecProcess then return nil,'REAPER ExecProcess API not available' end
  local rc,out=reaper.ExecProcess(command, timeout or 30000)
  if rc~=0 then return nil,'Exit '..tostring(rc)..': '..tostring(out or '') end
  return out
end
local function curl(url,path)
  if not url:match('^https://raw%.githubusercontent%.com/Alexa81/%-/main/moonar/') then
    return nil,'Rejected unknown download URL'
  end
  local curl_bin='/usr/bin/curl'
  local _,err=exec(quoted(curl_bin)..' -fsSL --retry 1 --connect-timeout 8 --max-time 25 -o '..quoted(path)..' '..quoted(url),30000)
  if err then return nil,err end
  if not read(path) then return nil,'Download did not create a file' end
  return true
end
local function sha256(path)
  local output,err=exec("/usr/bin/shasum -a 256 "..quoted(path),15000)
  if err then return nil,err end
  local value=output and output:match('^([0-9a-fA-F]+)')
  return value and value:lower() or nil
end
local function version_parts(s)
  local a,b,c=tostring(s or ''):match('^(%d+)%.(%d+)%.(%d+)$')
  if not a then return nil end
  return tonumber(a)*1000000+tonumber(b)*1000+tonumber(c)
end
-- Do not reject a valid Mac solely because REAPER reports a newer OS label
-- (such as an ARM build). Required macOS tools are validated by ExecProcess
-- and return a useful error if missing, before any plugin file is changed.
local osname=tostring((reaper.GetOS and reaper.GetOS()) or 'unknown')
reaper.RecursiveCreateDirectory(scripts,0)
reaper.RecursiveCreateDirectory(update_dir,0)
local manifest_tmp=update_dir..SEP..'latest-download.txt'
local ok,err=curl(base..'moonar/latest.txt',manifest_tmp)
if not ok then alert('Cannot check GitHub: '..tostring(err)..'\nNo files changed.');return end
local manifest=read(manifest_tmp)
local latest=manifest and manifest:match('version=(%d+%.%d+%.%d+)')
local path=manifest and manifest:match('controller=([^\r\n]+)')
local expected=manifest and manifest:match('sha256=([0-9a-fA-F]+)')
local latest_num=version_parts(latest)
if not latest_num or not path or not expected or #expected~=64
  or not path:match('^moonar/releases/v%d+%.%d+%.%d+/MOONAR_RESYNTH_LIVE%.lua$')
  or not path:find('/v'..latest..'/',1,true) then
  alert('Invalid manifest from GitHub. No files changed.')
  return
end
local installed=read(ui_target)
local current=installed and installed:match('%-%- MOONAR RESYNTH (%d+%.%d+%.%d+)')
local current_num=version_parts(current)
if current_num and latest_num<=current_num then
  alert('MOONAR RESYNTH '..current..' is already current.\nLatest GitHub version: '..latest..'.')
  return
end
local tmp=update_dir..SEP..'MOONAR_RESYNTH_LIVE.new.lua'
os.remove(tmp)
local got,problem=curl(base..path,tmp)
if not got then alert('Cannot download '..latest..': '..tostring(problem)..'\nNo files changed.');return end
local actual,hash_error=sha256(tmp)
if actual~=expected:lower() then
  os.remove(tmp)
  alert('SHA-256 verification failed: '..tostring(hash_error or actual)..'.\nNo files changed.')
  return
end
local source=read(tmp)
if not source or not source:find('%-%- MOONAR RESYNTH '..latest:gsub('%.','%%.')..' ') then
  os.remove(tmp)
  alert('Downloaded file version does not match manifest. No files changed.')
  return
end
if installed then
  local backup=ui_target..'.backup_'..(current or 'previous')
  if not read(backup) then
    local saved,save_err=write(backup,installed)
    if not saved then os.remove(tmp);alert('Backup failed: '..tostring(save_err)..'. No files changed.');return end
  end
end
local replaced,rename_err=os.rename(tmp,ui_target)
if not replaced then
  alert('Cannot install downloaded version: '..tostring(rename_err)..'\nBackup was preserved.')
  return
end
local action=reaper.AddRemoveReaScript(true,0,ui_target,true)
if not action or action<=0 then
  alert('Updated to '..latest..' but REAPER could not register MOONAR LIVE. Open it from Actions manually.')
  return
end
reaper.SetExtState('MOONAR_RESYNTH_LIVE','VERSION',latest,true)
-- The currently running LIVE window watches its script file and restarts itself.
-- Do not automatically open a second copy if that window is already active.
local live_open=reaper.GetExtState('MOONAR_RESYNTH_LIVE','CURRENT_UI')
alert('Updated MOONAR RESYNTH to '..latest..'.\n\nREAPER stays open.\nUser presets and JSFX are untouched.\n\nIf the MOONAR window is closed, open MOONAR_RESYNTH_LIVE in Actions.')
if live_open=='' then
  reaper.defer(function()reaper.Main_OnCommand(action,0)end)
end
