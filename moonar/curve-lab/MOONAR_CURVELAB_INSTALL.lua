-- MOONAR CURVE LAB - isolated installer and updater, v0.8.0-preview
-- ONLY installs MOONAR_CURVELAB_LIVE.lua, MOONAR_CURVELAB_UPDATE.lua,
-- and MOONAR_CurveLab_080.jsfx. Original MOONAR 0.7.14 is NEVER modified.
local sep=package.config:sub(1,1)
local root=reaper.GetResourcePath()
local scripts=root..sep..'Scripts'
local effects=root..sep..'Effects'
local stage_dir=root..sep..'MOONAR_CURVELAB'..sep..'Updates'
local base='https://raw.githubusercontent.com/Alexa81/-/main/'
local function alert(x) reaper.ShowMessageBox(tostring(x),'MOONAR CURVE LAB / UPDATE',0) end
local function read(path)
  local f=io.open(path,'rb');if not f then return nil end
  local v=f:read('*a');f:close();return v
end
local function quote(s)
  return "'"..tostring(s):gsub("'","'\\''").."'"
end
local function exec(command,timeout)
  if not reaper.ExecProcess then return nil,'Requires reaper.ExecProcess' end
  local answer=reaper.ExecProcess(command,timeout or 45000)
  if not answer then return nil,'Command did not execute' end
  local code,output=tostring(answer):match('^(%-?%d+)\r?\n(.*)$')
  if not code or tonumber(code)~=0 then
    return nil,('Exit %s: %s'):format(tostring(code),tostring(output or answer))
  end
  return output or ''
end
local function download(relative,dest)
  if not relative:match('^moonar/curve%-lab/') or relative:find('..',1,true)
     or relative:find('[^%w%._/%-]') then return nil,'Unsafe path' end
  os.remove(dest)
  local output,problem=exec('/usr/bin/curl -fsSL --proto =https --retry 1 --connect-timeout 10 --max-time 35 -o '..
    quote(dest)..' '..quote(base..relative),45000)
  if not output then return nil,problem end
  if not read(dest) then return nil,'Empty downloaded file' end
  return true
end
local function sha256(path)
  local answer,problem=exec('/usr/bin/shasum -a 256 '..quote(path),15000)
  if not answer then return nil,problem end
  local hash=answer:match('^([a-fA-F0-9]+)')
  if not hash or #hash~=64 then return nil,'Invalid checksum command output' end
  return hash:lower()
end
local function field(raw,key)
  return raw:match('^'..key..'=([^\r\n]+)') or raw:match('\n'..key..'=([^\r\n]+)')
end
local function fail(msg,staged)
  for _,f in ipairs(staged or {}) do if f.stage then os.remove(f.stage) end end
  alert(msg..'\nOriginal MOONAR was not modified.')
end
reaper.RecursiveCreateDirectory(scripts,0)
reaper.RecursiveCreateDirectory(effects,0)
reaper.RecursiveCreateDirectory(stage_dir,0)
local manifest=stage_dir..sep..'curve-lab-latest.txt'
local ok,err=download('moonar/curve-lab/latest.txt',manifest)
if not ok then fail('Cannot read Curve Lab update channel: '..tostring(err));return end
local raw=read(manifest)
local version=field(raw,'version')
if not version or not version:match('^%d+%.%d+%.%d+%-preview$') then
  fail('Invalid Curve Lab manifest version.');return
end
local specs={
  {'engine',effects..sep..'MOONAR_CurveLab_080.jsfx','MOONAR_CurveLab_080.jsfx'},
  {'controller',scripts..sep..'MOONAR_CURVELAB_LIVE.lua','MOONAR_CURVELAB_LIVE.lua'},
  {'updater',scripts..sep..'MOONAR_CURVELAB_UPDATE.lua','MOONAR_CURVELAB_UPDATE.lua'},
}
local staged={}
for _,record in ipairs(specs) do
  local key,target,filename=record[1],record[2],record[3]
  local path=field(raw,key)
  local wanted=field(raw,key..'_sha256')
  if not path or not path:match('^moonar/curve%-lab/') or
     path:sub(-#filename)~=filename or
     not wanted or #wanted~=64 or not wanted:match('^[a-fA-F0-9]+$') then
    fail('Unsafe or incomplete manifest field: '..key,staged);return
  end
  local current=read(target)
  local identical=false
  if current then
    local existing=sha256(target)
    identical=existing and existing==wanted:lower()
  end
  if not identical then
    local entry={kind=key,target=target,stage=target..'.curve_lab_verified_stage',old=current}
    local dl,why=download(path,entry.stage)
    if not dl then fail('Download '..key..' failed: '..tostring(why),staged);return end
    local checksum,reason=sha256(entry.stage)
    if checksum~=wanted:lower() then
      staged[#staged+1]=entry
      fail('Checksum mismatch: '..key..' ('..tostring(reason or checksum)..')',staged);return
    end
    staged[#staged+1]=entry
  end
end
for _,entry in ipairs(staged) do
  if entry.old then
    local backup=entry.target..'.curve_lab_backup'
    if not read(backup) then
      local f,e=io.open(backup,'wb')
      if not f then fail('Cannot back up '..entry.kind..': '..tostring(e),staged);return end
      local wr=f:write(entry.old);local cl=f:close()
      if not wr or not cl then fail('Backup write failed for '..entry.kind,staged);return end
    end
  end
end
local installed={}
for _,entry in ipairs(staged) do
  local placed,why=os.rename(entry.stage,entry.target)
  if not placed then
    for k=#installed,1,-1 do
      local done=installed[k]
      if done.old then
        local f=io.open(done.target,'wb')
        if f then f:write(done.old);f:close() end
      else os.remove(done.target) end
    end
    fail('Update rolled back: '..entry.kind..' / '..tostring(why),staged)
    return
  end
  installed[#installed+1]=entry
end
if type(reaper.EnumInstalledFX)=='function' then pcall(reaper.EnumInstalledFX,-1) end
local script=scripts..sep..'MOONAR_CURVELAB_LIVE.lua'
local _,action_script=reaper.get_action_context()
local is_installer=(action_script or ''):find('INSTALL',1,true)~=nil
local needs_run=is_installer or #installed>0
if needs_run then
  local action=reaper.AddRemoveReaScript(true,0,script,true)
  if action and action>0 then reaper.defer(function()reaper.Main_OnCommand(action,0)end) end
end
alert('Curve Lab '..version..(#installed>0 and ' installed / repaired.' or ' is up to date.')..
 '\nFiles changed: '..#installed..
 '\nOriginal MOONAR 0.7.14 and its presets were not touched.'..
 '\nThe plugin has its own UPDATE channel.')
