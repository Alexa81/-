-- MOONAR UPDATE 1.3 / WHOLE PLUGIN REPAIR + REAPER macOS
-- GitHub channel: https://github.com/Alexa81/-/tree/main/moonar
-- This script repairs the controller AND the JSFX engine independently.
-- Never modifies preset files or unrelated tracks/effects.
local SEP=package.config:sub(1,1)
local root=reaper.GetResourcePath()
local scripts=root..SEP..'Scripts'
local effects=root..SEP..'Effects'
local work=root..SEP..'MOONAR_RESYNTH'..SEP..'Updates'
local base='https://raw.githubusercontent.com/Alexa81/-/main/'
local function message(s)
  reaper.ShowMessageBox(tostring(s),'MOONAR UPDATE / REPAIR',0)
end
local function read(path)
  local f=io.open(path,'rb');if not f then return nil end
  local data=f:read('*a');f:close();return data
end
local function write(path,data)
  local f,e=io.open(path,'wb');if not f then return false,e end
  local ok,err=f:write(data)
  local done,err2=f:close()
  if not ok or not done then return false,err or err2 end
  return true
end
local function quote(s)
  return "'"..tostring(s):gsub("'","'\\''").."'"
end
local function exec(command,timeout)
  if type(reaper.ExecProcess)~='function' then return nil,'ExecProcess API missing' end
  local raw=reaper.ExecProcess(command,timeout or 45000)
  if raw==nil then return nil,'Command did not run' end
  -- REAPER returns one string: "0\nOUTPUT" for exit 0; NOT two return values.
  local code,output=tostring(raw):match('^(%-?%d+)\r?\n(.*)$')
  if not code then return nil,'Unexpected command response: '..tostring(raw) end
  if tonumber(code)~=0 then return nil,'Exit '..code..': '..(output or '') end
  return output or ''
end
local function download(relative,destination)
  if not relative:match('^moonar/') or relative:find('..',1,true) or
     relative:find('[^a-zA-Z0-9_./%-]') then
    return false,'Unsafe release path'
  end
  os.remove(destination)
  local _,err=exec('/usr/bin/curl -fsSL --proto =https --retry 1 --connect-timeout 10 --max-time 35 -o '..
    quote(destination)..' '..quote(base..relative),45000)
  if err then return false,err end
  if not read(destination) then return false,'Downloaded file missing' end
  return true
end
local function digest(path)
  local output,err=exec('/usr/bin/shasum -a 256 '..quote(path),15000)
  if err then return nil,err end
  local value=output:match('^([a-fA-F0-9]+)')
  if not value or #value~=64 then return nil,'Invalid shasum output' end
  return value:lower()
end
local function field(text,key)
  return text:match('^'..key..'=([^\r\n]+)') or text:match('\n'..key..'=([^\r\n]+)')
end
local function healthy(path,expected)
  local body=read(path)
  if not body then return false end
  local hash=digest(path)
  return hash==expected:lower()
end
local function backup(path,old)
  if not old then return true end
  local filename=path..'.backup_before_moonar_repair'
  if not read(filename) then return write(filename,old) end
  return true
end
local function install(stage,target)
  local ok,err=os.rename(stage,target)
  if not ok then return false,err end
  return true
end
local function cleanup(items)
  for _,item in ipairs(items) do if item.stage then os.remove(item.stage) end end
end
reaper.RecursiveCreateDirectory(scripts,0)
reaper.RecursiveCreateDirectory(effects,0)
reaper.RecursiveCreateDirectory(work,0)
local mf=work..SEP..'latest-repair.txt'
local ok,err=download('moonar/latest.txt',mf)
if not ok then message('Cannot check GitHub: '..tostring(err)..'\nNo files changed.');return end
local m=read(mf)
local version=field(m,'version')
local ui=field(m,'controller')
local ui_hash=field(m,'sha256')
local jsfx=field(m,'engine')
local js_hash=field(m,'engine_sha256')
if not version or not version:match('^%d+%.%d+%.%d+$') or
   not ui or ui~='moonar/releases/v'..version..'/MOONAR_RESYNTH_LIVE.lua' or
   not jsfx or not jsfx:match('^moonar/releases/v%d+%.%d+%.%d+/MOONAR_Resynth_%d+%.jsfx$') or
   not jsfx:find('/v'..version..'/',1,true) or
   not ui_hash or not ui_hash:match('^[a-fA-F0-9]+$') or #ui_hash~=64 or
   not js_hash or not js_hash:match('^[a-fA-F0-9]+$') or #js_hash~=64 then
  message('Invalid update manifest; plugin files were not changed.')
  return
end
local engine_name=jsfx:match('([^/]+)$')
local components={
  {kind='JSFX engine',path=jsfx,target=effects..SEP..engine_name,expected=js_hash},
  {kind='Lua interface',path=ui,target=scripts..SEP..'MOONAR_RESYNTH_LIVE.lua',expected=ui_hash}
}
local changes={}
for _,part in ipairs(components) do
  if not healthy(part.target,part.expected) then
    part.stage=part.target..'.moonar_verified_download'
    local got,problem=download(part.path,part.stage)
    if not got then
      cleanup(components)
      message('Cannot download '..part.kind..': '..tostring(problem)..'\nNo plugin files changed.')
      return
    end
    local actual,problem_hash=digest(part.stage)
    if actual~=part.expected:lower() then
      cleanup(components)
      message('Checksum failed for '..part.kind..': '..tostring(problem_hash or actual)..'\nNo plugin files changed.')
      return
    end
    changes[#changes+1]=part
  end
end
-- Repair the selected track's FX instance too. File-level "up to date" is NOT
-- sufficient when an older broken 0.6.1 instance is still in the FX chain.
local function activate_selected_engine()
  if not reaper.GetSelectedTrack or not reaper.TrackFX_GetCount then return false,'No track API' end
  local track=reaper.GetSelectedTrack(0,0)
  if not track then return false,'No selected track' end
  local modern,old=-1,-1
  for i=0,reaper.TrackFX_GetCount(track)-1 do
    local ok,name=reaper.TrackFX_GetFXName(track,i,'')
    if ok and name then
      if name:find('MOONAR Resynth 0.6.2',1,true) then modern=i end
      if name:find('MOONAR Resynth',1,true) and not name:find('0.6.2',1,true) then old=i end
    end
  end
  if modern>=0 then
    local enabled=reaper.TrackFX_GetEnabled and reaper.TrackFX_GetEnabled(track,modern)
    if enabled==false and reaper.TrackFX_SetEnabled then
      reaper.TrackFX_SetEnabled(track,modern,true)
    end
    if type(reaper.TrackFX_SetOffline)=='function' then reaper.TrackFX_SetOffline(track,modern,false) end
    return enabled==false,'JSFX 0.6.2 present and enabled'
  end
  if old<0 then return false,'Selected track has no MOONAR FX' end
  if type(reaper.EnumInstalledFX)=='function' then pcall(reaper.EnumInstalledFX,-1) end
  local names={'JS: MOONAR Resynth 0.6.2 Syntax Fixed','JS: MOONAR_Resynth_062',
    'JS: MOONAR_Resynth_062.jsfx'}
  for _,name in ipairs(names) do
    local id=reaper.TrackFX_AddByName(track,name,false,1)
    if id and id>=0 then
      local ok,loaded=reaper.TrackFX_GetFXName(track,id,'')
      if ok and loaded and loaded:find('MOONAR Resynth 0.6.2',1,true) then
        if reaper.TrackFX_GetParam and reaper.TrackFX_SetParam then
          for i=0,21 do
            if i~=10 then
              local v=reaper.TrackFX_GetParam(track,old,i)
              if v~=nil then reaper.TrackFX_SetParam(track,id,i,v) end
            end
          end
        end
        if reaper.TrackFX_SetEnabled then reaper.TrackFX_SetEnabled(track,id,true) end
        if type(reaper.TrackFX_SetOffline)=='function' then reaper.TrackFX_SetOffline(track,id,false) end
        -- Leave the old FX in place, not deleted or bypassed, until Lua
        -- imports the sample into the new engine on the selected track.
        return true,'Attached JSFX 0.6.2 to selected track; load sample to activate'
      end
    end
  end
  return false,'JSFX file installed; REAPER FX browser may need refresh (F5)'
end
local function open_live()
  local script=scripts..SEP..'MOONAR_RESYNTH_LIVE.lua'
  local action=reaper.AddRemoveReaScript(true,0,script,true)
  if action and action>0 then
    reaper.defer(function()reaper.Main_OnCommand(action,0)end)
  end
end
if #changes==0 then
  local needs_restart,status=activate_selected_engine()
  message('MOONAR RESYNTH '..version..' verified.\nLua interface: OK.\nJSFX engine file: OK.\nSelected track: '..status)
  if needs_restart then open_live() end
  return
end
for _,part in ipairs(changes) do
  part.old=read(part.target)
  local saved,why=backup(part.target,part.old)
  if not saved then
    cleanup(components)
    message('Backup failed for '..part.kind..': '..tostring(why)..'\nNo plugin files changed.')
    return
  end
end
local completed={}
for _,part in ipairs(changes) do
  local installed,problem=install(part.stage,part.target)
  if not installed then
    for i=#completed,1,-1 do
      local prev=completed[i]
      if prev.old then write(prev.target,prev.old) else os.remove(prev.target) end
    end
    cleanup(components)
    message('Repair aborted: '..tostring(problem)..'. Previous files restored.')
    return
  end
  completed[#completed+1]=part
end
if type(reaper.EnumInstalledFX)=='function' then pcall(reaper.EnumInstalledFX,-1) end
local attached,track_status=activate_selected_engine()
local fixed={}
for _,part in ipairs(completed) do fixed[#fixed+1]=part.kind end
reaper.SetExtState('MOONAR_RESYNTH_LIVE','VERSION',version,true)
message('MOONAR '..version..' updated / repaired:\n- '..table.concat(fixed,'\n- ')..
  '\nSelected track: '..track_status..
  '\n\nPresets and previous JSFX preserved. REAPER stays open.')
-- Open the newly installed GUI on the selected track so it can reimport any
-- saved sample path; the existing GUI closes via its single-instance token.
open_live()
