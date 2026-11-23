

-- MOONAR RESYNTH 0.7.9 / ACCURATE ADSR PREVIEW AND STAGE-SCALE GRAPH + FULL UPDATE AND REPAIR + JSFX COMPILER FIX + SELECTED TRACK + MIDI ROUTING + GITHUB UPDATE BUTTON + RECOVER SILENCE + PREVIEW MIDI + ON-DISK PRESET BANK
-- Companion ReaScript UI: real file drag/drop and trim controls; JSFX audio engine.
-- This is an original instrument, unrelated to Tim Hox's proprietary source code.
local FX_NAME='MOONAR Resynth 0.6.4 Natural Sustain'
local JSFX_FILENAME='MOONAR_Resynth_064.jsfx'
local ENGINE_COMPATIBLE={'MOONAR_BUILD=0.6.4'}
local BUS='MOONAR_RESYNTH_BRIDGE_04'
local SR, MAX_FRAMES, NFFT, MAX_PEAKS=44100, 1323000, 16384, 64
local SLOT_STRIDE, PI=3200000,math.pi
local SEP=package.config:sub(1,1)

local function read_all(path)
  local f=io.open(path,'rb'); if not f then return nil end
  local d=f:read('*a'); f:close(); return d
end
local BUNDLED_UPDATER=[======[
-- MOONAR UPDATE 1.4 / WHOLE PLUGIN REPAIR + REAPER macOS + DYNAMIC AUDIO ENGINE
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
  local engine_path=effects..SEP..engine_name
  local engine_source=read(engine_path) or ''
  local engine_desc=engine_source:match('desc:([^\r\n]+)') or ('MOONAR Resynth '..engine_name)
  local engine_ident=engine_name:gsub('%.jsfx$','')
  local modern,old=-1,-1
  for i=0,reaper.TrackFX_GetCount(track)-1 do
    local ok,name=reaper.TrackFX_GetFXName(track,i,'')
    if ok and name then
      if name:find(engine_desc,1,true) then modern=i end
      if name:find('MOONAR Resynth',1,true) and not name:find(engine_desc,1,true) then old=i end
    end
  end
  if modern>=0 then
    local enabled=reaper.TrackFX_GetEnabled and reaper.TrackFX_GetEnabled(track,modern)
    if enabled==false and reaper.TrackFX_SetEnabled then
      reaper.TrackFX_SetEnabled(track,modern,true)
    end
    if type(reaper.TrackFX_SetOffline)=='function' then reaper.TrackFX_SetOffline(track,modern,false) end
    return enabled==false,engine_desc..' present and enabled'
  end
  if old<0 then return false,'Selected track has no MOONAR FX; launch MOONAR LIVE first' end
  if type(reaper.EnumInstalledFX)=='function' then pcall(reaper.EnumInstalledFX,-1) end
  local names={'JS: '..engine_desc, 'JS: '..engine_ident, 'JS: '..engine_name}
  for _,name in ipairs(names) do
    local id=reaper.TrackFX_AddByName(track,name,false,1)
    if id and id>=0 then
      local ok,loaded=reaper.TrackFX_GetFXName(track,id,'')
      if ok and loaded and loaded:find(engine_desc,1,true) then
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
        -- Do not delete or bypass the old FX before the new controller
        -- loads the PCM sample and finishes its live migration.
        return true,'Added '..engine_desc..'; reopening LIVE to restore sample'
      end
    end
  end
  return false,'JSFX installed; reopen MOONAR LIVE or refresh FX browser (F5)'
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

]======]
local BUNDLED_JSFX=[===[
desc:MOONAR Resynth 0.6.4 Natural Sustain
tags:instrument sampler resynthesis
options:gmem=MOONAR_RESYNTH_BRIDGE_04 maxmem=3100000
in_pin:none
out_pin:Left
out_pin:Right

// MOONAR_BUILD=0.6.4
// Independent educational sampler/resynthesis prototype, NOT Tim Hox's source.
// Protocol version 2. Natural PCM body-loop sustain (default) or optional spectral synthesis.

slider1:0<0,32000,1>Attack (ms)
slider2:200<0,32000,1>Decay (ms)
slider3:0<-48,0,0.1>Sustain (dB)
slider4:650<0,32000,1>Release (ms)
slider5:0<-36,12,0.1>Output (dB)
slider6:4<1,4,1>Polyphony (voices)
slider7:72<24,96,1>MIDI keyboard root (C5=72)
slider8:0<-12,12,0.01>Fine tune (semitones)
slider9:0<0,1000,1>Glide (ms, mono)
slider10:1<0,1,1{Off,On}>Tune detected root to nearest C
slider11:1<1,2,1>Internal import slot (1-2)
slider12:90<10,250,1>Original-to-synthesis fade (ms)
slider13:0<0,1,1{Off,On}>Legato (mono only)
slider14:0<0,100,1>Organic harmonic motion (%)
slider15:0<0,100,1>Residual noise body (%)
slider16:2<0,12,1>Pitch bend range (semitones)
slider17:0<0,10000,1>Trim Start (0-100%)
slider18:10000<1,10000,1>Trim End (0-100%)
slider19:5<0,300,1>Start Fade (ms)
slider20:70<0,300,1>End Fade / Synth Crossfade (ms)
slider21:0<-1.5,1.5,0.05>Fade In Bend
slider22:0<-1.5,1.5,0.05>Fade Out Bend
slider23:0<0,1,1{Natural Loop,Spectral}>Sustain Engine

@init
ext_noinit = 1;
initialized != 293201 ? (
  initialized=293201;
  samp_l=0;
  samp_r=1400000;
  peak_freq=2800000;
  peak_amp_l=2800128;
  peak_phase_l=2800256;
  peak_amp_r=2800384;
  peak_phase_r=2800512;
  // Temporary previous model, used for seamless live model swaps.
  prev_peak_freq=2800704;
  prev_amp_l=2800832;
  prev_phase_l=2800960;
  prev_amp_r=2801088;
  prev_phase_r=2801216;
  prev_npeak=0;
  prev_gain_l=1;
  prev_gain_r=1;
  model_ramp=1;
  voice_mem=2900000;
  event_time=2901000;
  event_status=2901256;
  event_note=2901512;
  event_velocity=2901768;
  stride=24;
  max_frames=1323000;
  peak_capacity=64;
  // Do not erase restored @serialize data when @init runs on project load.
  has_sample != 1 ? (
    has_sample=0;
    nframes=0;
    source_sr=44100;
    detected_note=72;
    npeak=0;
    handoff_end=0;
    model_gain_l=1;
    model_gain_r=1;
    nLlo=0;nLmid=0;nLhi=0;
    nRlo=0;nRmid=0;nRhi=0;
  );
  last_generation=-1;
  load_generation=-1;
  loading=0;
  load_cursor=0;
  pedal_down=0;
  bend_semi=0;
  bend_ratio=1;
  i=0;
  loop(4,
    off=voice_mem+i*stride;
    off[0]=0;
    off[15]=0;off[16]=0;off[17]=0;off[18]=1;off[19]=1;off[20]=0;
    i+=1;
  );
);

@slider
attack_step = slider1 <= 0 ? 1 : 1000 / (slider1*srate);
decay_step = 1000 / (max(1,slider2)*srate);
sus_level = 10^(slider3/20);
release_coef = slider4 <= 0 ? 0 : exp(-6.907755*1000/(max(1,slider4)*srate));
output_gain = 10^(slider5/20);
xfade_frames = max(1,slider12*0.001*source_sr);
// Trim coordinates operate on the *entire* imported source PCM, live.
clip_start=max(0,min(max(0,nframes-512),floor(nframes*slider17/10000)));
clip_end=max(clip_start+512,min(nframes,floor(nframes*slider18/10000)));
fade_in_frames=max(0,slider19*0.001*source_sr);
fade_out_frames=max(1,slider20*0.001*source_sr);
// Move the active playhead as the user drags a locator.
clip_start != old_clip_start ? (
  vv=0;
  loop(4, vvo=voice_mem+vv*stride; vvo[0]>0 ? vvo[3]=clip_start; vv+=1;);
  old_clip_start=clip_start;
);
old_clip_end=clip_end;
slide_coef = slider9 > 0 ? exp(-6.907755*1000/(max(1,slider9)*srate)) : 0;
noise_mix = slider15*0.01;
motion_depth = slider14*0.001;
bend_ratio=2^(bend_semi/12);
low_a=1-exp(-2*$pi*500/max(8000,srate));
high_a=1-exp(-2*$pi*3500/max(8000,srate));
lo_var=low_a/(2-low_a);
hi_var=high_a/(2-high_a);
cross_cov=(low_a*high_a)/(low_a+high_a-low_a*high_a);
// Noise source rand(2)-1 has variance 1/3; these make each generated
// low/mid/high band unit RMS before multiplying by measured residual RMS.
lo_norm=sqrt(3/max(0.00001,lo_var));
mid_norm=sqrt(3/max(0.00001,hi_var+lo_var-2*cross_cov));
hi_norm=sqrt(3/max(0.00001,1+hi_var-2*high_a));

@serialize
// Save both PCM source and model in the REAPER project.
file_var(0,has_sample);
file_var(0,nframes);
file_var(0,source_sr);
file_var(0,detected_note);
file_var(0,npeak);
file_var(0,handoff_end);
file_var(0,model_gain_l);
file_var(0,model_gain_r);
file_var(0,nLlo);file_var(0,nLmid);file_var(0,nLhi);
file_var(0,nRlo);file_var(0,nRmid);file_var(0,nRhi);
has_sample ? (
  file_mem(0,samp_l,nframes);
  file_mem(0,samp_r,nframes);
  file_mem(0,peak_freq,640);
);

@block
// Named gmem bridge. Lua writes audio + model first, commits generation last.
slot_base=(floor(slider11)-1)*3200000;
bridge_ready=gmem[slot_base]==1;
bridge_version=gmem[slot_base+1];
bridge_ready && bridge_version != last_generation && bridge_version != load_generation ? (
  load_generation=bridge_version;
  loading=1;
  load_cursor=0;
  incoming_len=min(max_frames,max(0,floor(gmem[slot_base+2])));
  incoming_model_only=floor(gmem[slot_base+15])==1;
  incoming_sr=max(8000,gmem[slot_base+3]);
  incoming_note=gmem[slot_base+4];
  incoming_peaks=min(peak_capacity,max(0,floor(gmem[slot_base+5])));
  incoming_handoff=min(incoming_len,max(1,floor(gmem[slot_base+6])));
  incoming_gain_l=gmem[slot_base+7];
  incoming_gain_r=gmem[slot_base+8];
  incoming_nLlo=gmem[slot_base+9];
  incoming_nLmid=gmem[slot_base+10];
  incoming_nLhi=gmem[slot_base+11];
  incoming_nRlo=gmem[slot_base+12];
  incoming_nRmid=gmem[slot_base+13];
  incoming_nRhi=gmem[slot_base+14];
  // Keep the previous spectrum alive during an update. Otherwise replacing
  // peaks mid-note can make an audible step even though the original PCM is
  // playing normally.
  incoming_model_only && has_sample ? (
    prev_npeak=npeak;
    prev_gain_l=model_gain_l;
    prev_gain_r=model_gain_r;
    pp=0;
    loop(prev_npeak,
      prev_peak_freq[pp]=peak_freq[pp];
      prev_amp_l[pp]=peak_amp_l[pp];
      prev_phase_l[pp]=peak_phase_l[pp];
      prev_amp_r[pp]=peak_amp_r[pp];
      prev_phase_r[pp]=peak_phase_r[pp];
      pp+=1;
    );
  ) : (
    prev_npeak=0;
    model_ramp=1;
  );
  incoming_model_only ? (
    load_cursor=incoming_len;
  ) : (
    has_sample=0;
    i=0;
    loop(4,vo=voice_mem+i*stride;vo[0]=0;i+=1;);
  );
);
loading && bridge_ready && bridge_version == load_generation ? (
  remaining=max(0,incoming_len-load_cursor);
  ncopy=min(4096,remaining);
  i=0;
  loop(ncopy,
    idx=load_cursor+i;
    samp_l[idx]=gmem[slot_base+64+idx];
    samp_r[idx]=gmem[slot_base+1400064+idx];
    i+=1;
  );
  load_cursor+=ncopy;
  load_cursor>=incoming_len ? (
    i=0;
    loop(incoming_peaks,
      peak_freq[i]   =gmem[slot_base+2800064+i];
      peak_amp_l[i]  =gmem[slot_base+2800192+i];
      peak_phase_l[i]=gmem[slot_base+2800320+i];
      peak_amp_r[i]  =gmem[slot_base+2800448+i];
      peak_phase_r[i]=gmem[slot_base+2800576+i];
      i+=1;
    );
    incoming_model_only ? nframes=nframes : nframes=incoming_len;
    source_sr=incoming_sr;
    detected_note=incoming_note;
    handoff_end=incoming_handoff;
    npeak=incoming_peaks;
    model_gain_l=max(0.1,min(4,incoming_gain_l));
    model_gain_r=max(0.1,min(4,incoming_gain_r));
    nLlo=max(0,incoming_nLlo);
    nLmid=max(0,incoming_nLmid);
    nLhi=max(0,incoming_nLhi);
    nRlo=max(0,incoming_nRlo);
    nRmid=max(0,incoming_nRmid);
    nRhi=max(0,incoming_nRhi);
    xfade_frames=max(1,slider12*0.001*source_sr);
    has_sample=nframes>0 && npeak>0;
    incoming_model_only ? 0 : (old_clip_start=-1; old_clip_end=-1;);
    model_ramp=incoming_model_only && prev_npeak>0 ? 0 : 1;
    last_generation=load_generation;
    loading=0;
  );
);
loading && !bridge_ready ? (loading=0;load_generation=-1;);

// React to FX parameter changes, whether from native JSFX UI or companion drop window.
clip_start=max(0,min(max(0,nframes-512),floor(nframes*slider17/10000)));
clip_end=max(clip_start+512,min(nframes,floor(nframes*slider18/10000)));
fade_in_frames=max(0,slider19*0.001*source_sr);
fade_out_frames=max(1,slider20*0.001*source_sr);
// Natural sustain body: the original PCM is looped without freezing spectra.
 // This avoids the metallic ringing produced by static additive partials.
 // Fade Out sets the crossfade at the loop seam, not the ADSR Note Off.
 region_frames=max(512,clip_end-clip_start);
 loop_start=clip_start+floor(region_frames*0.20);
 loop_end=min(clip_end-1,max(loop_start+128,clip_start+floor(region_frames*0.65)));
 loop_len=max(128,loop_end-loop_start);
 loop_fade=max(1,min(loop_len*0.33,slider20*0.001*source_sr));
 loop_return=loop_start+loop_fade;
 // Collect MIDI with sample offsets to retain precise note timing.
event_count=0;
while(midirecv(midi_offset,midi_status,midi_data))(
  event_count<128 ? (
    event_time[event_count]=midi_offset;
    event_status[event_count]=midi_status & 240;
    event_note[event_count]=midi_data & 127;
    event_velocity[event_count]=(midi_data>>8)&127;
    event_count+=1;
  );
);
event_cursor=0;
block_sample=0;

@sample
while(event_cursor<event_count && event_time[event_cursor]<=block_sample)(
  st=event_status[event_cursor];
  nn=event_note[event_cursor];
  vel=event_velocity[event_cursor];
  st==144 && vel==0 ? st=128;
  st==144 && vel>0 && has_sample ? (
    chosen=-1;
    oldest=-1;oldest_age=-1;
    v=0;
    loop(floor(slider6),
      vo=voice_mem+v*stride;
      vo[0]==0 && chosen<0 ? chosen=v;
      vo[0]!=0 && vo[8]>oldest_age ? (oldest_age=vo[8];oldest=v;);
      v+=1;
    );
    chosen<0 ? chosen=oldest;
    slider6<=1 ? chosen=0;
    chosen>=0 ? (
      vo=voice_mem+chosen*stride;
      tune=slider10>0 ? floor(detected_note/12+0.5)*12-detected_note : 0;
      target_ratio=2^((nn-slider7+slider8+tune)/12);
      // MONO portamento: reuse the previous voice pitch even when LEGATO
      // is off. LEGATO only controls whether the amplitude envelope restarts.
      mono_active=slider6<=1 && vo[0]>0;
      legato_reuse=mono_active && slider13>0 && vo[10]>0 && vo[0]<4;
      glide_reuse=mono_active && slider9>0;
      (legato_reuse || glide_reuse) ? (
        vo[1]=nn;
        vo[2]=vel/127;
        vo[7]=target_ratio;
        vo[9]=0;
        vo[10]=1;
        !legato_reuse ? (
          vo[0]=1;
          vo[3]=clip_start;
          vo[4]=0;
          vo[8]=0;
          vo[11]=0;vo[12]=0;vo[13]=0;vo[14]=0;
          vo[15]=0;vo[16]=0;vo[17]=0;vo[18]=1;vo[19]=1;vo[20]=0;
        );
        // vo[6] intentionally retains previous pitch for GLIDE.
      ) : (
        vo[0]=1;
        vo[1]=nn;
        vo[2]=vel/127;
        vo[3]=clip_start;
        vo[4]=0;
        vo[6]=target_ratio;
        vo[7]=target_ratio;
        vo[8]=0;
        vo[9]=0;
        vo[10]=1;
        vo[11]=0;vo[12]=0;vo[13]=0;vo[14]=0;
        vo[15]=0;vo[16]=0;vo[17]=0;vo[18]=1;vo[19]=1;vo[20]=0;
      );
    );
  );
  st==128 ? (
    v=0;
    loop(4,
      vo=voice_mem+v*stride;
      vo[0]>0 && vo[1]==nn ? (
        vo[10]=0;
        pedal_down ? vo[9]=1 : vo[0]=4;
      );
      v+=1;
    );
  );
  st==176 && nn==64 ? (
    pedal_down=vel>=64;
    !pedal_down ? (
      v=0;
      loop(4,
        vo=voice_mem+v*stride;
        vo[0]>0 && vo[9]>0 ? (vo[0]=4;vo[9]=0;);
        v+=1;
      );
    );
  );
  st==176 && (nn==120 || nn==123) ? (
    v=0;
    loop(4,
      vo=voice_mem+v*stride;
      vo[0]>0 ? (vo[0]=4;vo[9]=0;);
      v+=1;
    );
  );
  st==224 ? (
    bend_semi=((nn+128*vel)-8192)/8192 * slider16;
    bend_ratio=2^(bend_semi/12);
  );
  event_cursor+=1;
);

// 160 ms old/new spectral crossfade, independent of MIDI and handoff.
model_ramp=min(1,model_ramp+1/max(1,srate*0.16));
out_l=0;out_r=0;
active_count=0;
has_sample ? (
  v=0;
  loop(4,
    vo=voice_mem+v*stride;
    vo[0]>0 ? (
      active_count+=1;
      vo[8]+=1;
      vo[6]=vo[7]+(vo[6]-vo[7])*slide_coef;
      sample_rate_ratio=vo[6]*bend_ratio;
      pos=vo[3];
      vo[3]+=sample_rate_ratio*source_sr/srate;
      // In NATURAL mode the playhead never reaches the silent sample tail.
      // The first pass preserves the recorded attack; subsequent passes loop
      // the stable PCM body with a real adjustable crossfade.
      slider23<0.5 && vo[3]>=loop_end ? (
        vo[3]=loop_return+(vo[3]-loop_end);
      );
      vo[0]==1 ? (
        vo[4]=min(1,vo[4]+attack_step);
        vo[4]>=0.99999 ? vo[0]=2;
      ) : vo[0]==2 ? (
        vo[4]=max(sus_level,vo[4]-(1-sus_level)*decay_step);
        vo[4]<=sus_level+0.00001 ? vo[0]=3;
      ) : vo[0]==3 ? (
        vo[4]=sus_level;
      ) : vo[0]==4 ? (
        vo[4]*=release_coef;
        vo[4]<=0.0001 ? vo[0]=0;
      );
      // The recorded attack retains its PCM timbre. During a held MIDI note
      // the spectral phase keeps advancing beyond the sample length, so the
      // Sustain remains indefinite until the MIDI note-off enters Release.
      // Original PCM is untouched until the smooth, phase-aligned handoff.
      dry_l=0;dry_r=0;
      pos < clip_end-1 && pos >= clip_start ? (
        p0=floor(max(0,pos));
        interp=pos-p0;
        dry_l=samp_l[p0]*(1-interp)+samp_l[p0+1]*interp;
        dry_r=samp_r[p0]*(1-interp)+samp_r[p0+1]*interp;
      );
      // NATURAL sustain: crossfade the outgoing PCM tail to the beginning
      // of the same sample's stable loop. The end-of-sample never truncates
      // a held note and the natural timbre is preserved.
      slider23<0.5 && pos>=loop_end-loop_fade && pos<loop_end ? (
        loop_t=max(0,min(1,(pos-(loop_end-loop_fade))/max(1,loop_fade)));
        head_pos=loop_start+loop_t*loop_fade;
        hp0=floor(max(0,head_pos));
        hi=head_pos-hp0;
        head_l=samp_l[hp0]*(1-hi)+samp_l[hp0+1]*hi;
        head_r=samp_r[hp0]*(1-hi)+samp_r[hp0+1]*hi;
        loop_blend=loop_t*loop_t*(3-2*loop_t);
        dry_l=dry_l*(1-loop_blend)+head_l*loop_blend;
        dry_r=dry_r*(1-loop_blend)+head_r*loop_blend;
      );
      // Begin the resynthesis before the last useful body has decayed into
      // near silence. handoff_end is estimated by the Lua model analyzer.
      // End remains a hard upper bound; we never read PCM beyond it.
      region_frames=max(512,clip_end-clip_start);
      // Blend across the stable sample body (not its nearly-silent tail).
      actual_fade=min(max(source_sr*0.12,fade_out_frames),max(256,region_frames*0.58));
      safe_handoff=(handoff_end>clip_start && handoff_end<=clip_end) ? handoff_end : clip_end;
      transition_end=min(clip_end,max(clip_start+actual_fade,
                         safe_handoff+actual_fade*0.45));
      blend=max(0,min(1,(pos-(transition_end-actual_fade))/actual_fade));
      blend=blend*blend*(3-2*blend);
      // Keep slider12 meaningful as transition contour; fade duration
      // itself follows the visible right marker (slider20).
      blend=blend^(max(0.25,min(4,slider12/90))*2^slider22);
      // Spectral mode is optional; Natural Loop is the default.
      // Both modes retain full MIDI-held ADSR Sustain and Release.
      slider23<0.5 ? blend=0;
      // Clip start fade, independent of ADSR attack.
      // Use the note's elapsed time, NOT looping source position. Otherwise
      // a long fade-in restarts on every loop and causes volume pumping.
      fade_in_gain=fade_in_frames>0 ? min(1,max(0,vo[8]/max(1,fade_in_frames*srate/source_sr))) : 1;
      fade_in_gain=fade_in_gain*fade_in_gain*(3-2*fade_in_gain);
      fade_in_gain=fade_in_gain^(2^slider21);
      dry_l*=fade_in_gain;
      dry_r*=fade_in_gain;
      syn_l=0;syn_r=0;
      // Calculate the spectral signal slightly ahead of the overlap.
      // This prewarms the energy/correlation estimate before audible blending.
      blend>0 || pos >= transition_end-actual_fade-source_sr*0.045 ? (
        p=0;
        loop(npeak,
          hz=peak_freq[p];
          hz*sample_rate_ratio < srate*0.465 ? (
            phase=2*$pi*hz*pos/source_sr;
            drift=1+motion_depth*(sin(2*$pi*(0.27+0.019*p)*pos/source_sr+1.19*p));
            syn_l+=peak_amp_l[p]*cos(phase+peak_phase_l[p])*drift;
            syn_r+=peak_amp_r[p]*cos(phase+peak_phase_r[p])*drift;
          );
          p+=1;
        );
        syn_l*=model_gain_l;
        syn_r*=model_gain_r;
        // Updating spectral peaks while holding a note must never instantly
        // replace a non-zero waveform. Crossfade the OLD and NEW models.
        model_ramp<1 && prev_npeak>0 ? (
          old_syn_l=0;old_syn_r=0;
          pp=0;
          loop(prev_npeak,
            old_hz=prev_peak_freq[pp];
            old_hz*sample_rate_ratio<srate*0.465 ? (
              old_phase=2*$pi*old_hz*pos/source_sr;
              old_drift=1+motion_depth*sin(2*$pi*(0.27+0.019*pp)*pos/source_sr+1.19*pp);
              old_syn_l+=prev_amp_l[pp]*cos(old_phase+prev_phase_l[pp])*old_drift;
              old_syn_r+=prev_amp_r[pp]*cos(old_phase+prev_phase_r[pp])*old_drift;
            );
            pp+=1;
          );
          model_blend=model_ramp*model_ramp*(3-2*model_ramp);
          syn_l=syn_l*model_blend+old_syn_l*prev_gain_l*(1-model_blend);
          syn_r=syn_r*model_blend+old_syn_r*prev_gain_r*(1-model_blend);
        );
        // NOISE=0 is strict bypass: no RNG and no stochastic residual.
        // Residual/noise resynthesis uses fresh filtered stochastic
        // excitation, never repeats an original sample buffer.
        noise_mix>0 ? (
          rL=rand(2)-1;
          rR=rand(2)-1;
          vo[11]+=(rL-vo[11])*low_a;
          vo[12]+=(rL-vo[12])*high_a;
          vo[13]+=(rR-vo[13])*low_a;
          vo[14]+=(rR-vo[14])*high_a;
          syn_l+=noise_mix * (nLlo*vo[11]*lo_norm + nLmid*(vo[12]-vo[11])*mid_norm + nLhi*(rL-vo[12])*hi_norm);
          syn_r+=noise_mix * (nRlo*vo[13]*lo_norm + nRmid*(vo[14]-vo[13])*mid_norm + nRhi*(rR-vo[14])*hi_norm);
        );
      );
      // Estimate dry/synthetic energy and correlation before and during the
      // handoff. A naive linear fade can null at 50/50 when phases oppose,
      // sounding like a tiny silence. A bounded, smoothed compensation
      // reduces that cancellation without hard gain steps or pumping.
      en_alpha=1-exp(-1/max(1,srate*0.018));
      vo[15]+=(0.5*(dry_l*dry_l+dry_r*dry_r)-vo[15])*en_alpha;
      vo[16]+=(0.5*(syn_l*syn_l+syn_r*syn_r)-vo[16])*en_alpha;
      vo[17]+=(0.5*(dry_l*syn_l+dry_r*syn_r)-vo[17])*en_alpha;
      // Freeze a single polarity decision when entering the transition.
      // Anti-phase source and model can otherwise cancel exactly at 50/50.
      blend>0.025 && vo[20]<0.5 && vo[16]>0.0000000001 ? (
        vo[19]=(vo[17] < (-0.23 * sqrt(max(0.000000000001,vo[15]*vo[16])))) ? -1 : 1;
        vo[20]=1;
      );
      vo[19]<0 ? (
        syn_l=-syn_l; syn_r=-syn_r;
        vo[17]=-vo[17];
      );
      a=1-blend;
      predicted=max(0,a*a*vo[15]+blend*blend*vo[16]+2*a*blend*vo[17]);
      desired=max(0,a*vo[15]+blend*vo[16]);
      boost=blend>0 && blend<1 ? min(1.65,max(1,sqrt((desired+0.0000000001)/(predicted+0.0000000001)))) : 1;
      vo[18]+=(boost-vo[18])*(1-exp(-1/max(1,srate*0.010)));
      vgain=vo[2]*vo[4]*vo[18];
      out_l+=(a*dry_l+blend*syn_l)*vgain;
      out_r+=(a*dry_r+blend*syn_r)*vgain;
    );
    v+=1;
  );
);
spl0=out_l*output_gain;
spl1=out_r*output_gain;
block_sample+=1;


@gfx 1080 930
// MOONAR RESYNTH - custom GUI, designed for the REAPER JSFX gfx API.
// This interface is deliberately inspired by the supplied dark-red reference,
// while all branding, graphic assets and control artwork are independently drawn.
// Import remains a ReaScript action: JSFX cannot launch REAPER's file picker.

function ui_fill(x,y,w,h,red,green,blue,alpha)(
  gfx_set(red,green,blue,alpha);
  gfx_rect(ui_ox+x*ui_s,ui_oy+y*ui_s,w*ui_s,h*ui_s);
);
function ui_stroke(x,y,w,h,red,green,blue,alpha)(
  gfx_set(red,green,blue,alpha);
  gfx_roundrect(ui_ox+x*ui_s,ui_oy+y*ui_s,w*ui_s,h*ui_s,2*ui_s,1);
);
function ui_line(x1,y1,x2,y2,red,green,blue,alpha)(
  gfx_set(red,green,blue,alpha);
  gfx_line(ui_ox+x1*ui_s,ui_oy+y1*ui_s,ui_ox+x2*ui_s,ui_oy+y2*ui_s,1);
);
function ui_circle(x,y,r,red,green,blue,alpha,filled)(
  gfx_set(red,green,blue,alpha);
  gfx_circle(ui_ox+x*ui_s,ui_oy+y*ui_s,r*ui_s,filled,1);
);
function ui_text(x,y,str,size,red,green,blue)(
  gfx_setfont(1,"Arial",max(8,floor(size*ui_s)));
  gfx_set(red,green,blue,1);
  gfx_x=ui_ox+x*ui_s;
  gfx_y=ui_oy+y*ui_s;
  gfx_drawstr(str);
);
function ui_panel(x,y,w,h)(
  ui_fill(x+4,y+5,w,h,0.035,0.013,0.019,0.54);
  ui_fill(x,y,w,h,0.11,0.125,0.142,1);
  ui_fill(x,y,w,24,0.17,0.18,0.19,0.66);
  ui_stroke(x,y,w,h,0.015,0.021,0.028,0.93);
  ui_stroke(x+2,y+2,w-4,h-4,0.34,0.36,0.36,0.16);
);
function ui_knob(cx,cy,r,norm,label,value,flavor)(
  norm=max(0,min(1,norm));
  ui_text(cx-39,cy-73,label,13,0.88,0.89,0.91);
  ui_circle(cx+2,cy+4,r+7,0.015,0.017,0.022,0.92,1);
  ui_circle(cx,cy,r+4,0.23,0.24,0.26,1,1);
  ui_circle(cx,cy,r,0.07,0.075,0.085,1,1);
  // 48-piece arc, independent of the original brand's graphics.
  aa=0;
  loop(48,
    ang1=2.35+aa*4.69/48;
    ang2=2.35+(aa+0.78)*4.69/48;
    flavor==0 ? (cr=0.97;cg=0.65;cb=0.19;) : (cr=0.74;cg=0.91;cb=0.86;);
    aa/48<=norm ? (
      ui_line(cx+cos(ang1)*(r+5),cy+sin(ang1)*(r+5),cx+cos(ang2)*(r+5),cy+sin(ang2)*(r+5),cr,cg,cb,1);
      ui_line(cx+cos(ang1)*(r+6),cy+sin(ang1)*(r+6),cx+cos(ang2)*(r+6),cy+sin(ang2)*(r+6),cr,cg,cb,0.44);
    ) : (
      ui_line(cx+cos(ang1)*(r+5),cy+sin(ang1)*(r+5),cx+cos(ang2)*(r+5),cy+sin(ang2)*(r+5),0.3,0.32,0.34,1);
    );
    aa+=1;
  );
  ui_circle(cx,cy,r-5,0.13,0.14,0.155,1,1);
  ui_circle(cx-4,cy-6,r-13,0.16,0.17,0.19,0.75,1);
  indic=2.35+norm*4.69;
  ui_line(cx,cy,cx+cos(indic)*(r-11),cy+sin(indic)*(r-11),0.98,0.98,0.95,1);
  ui_fill(cx-48,cy+r+19,96,29,0.042,0.049,0.059,1);
  ui_stroke(cx-48,cy+r+19,96,29,0.22,0.24,0.27,1);
  ui_text(cx-39,cy+r+25,value,13,0.87,0.89,0.91);
);
function ui_mini_knob(cx,cy,norm,label,value)(
  norm=max(0,min(1,norm));
  ui_circle(cx+1,cy+2,17,0.02,0.025,0.030,1,1);
  ui_circle(cx,cy,14,0.19,0.20,0.21,1,1);
  ui_circle(cx,cy,11,0.075,0.08,0.09,1,1);
  angle=2.35+norm*4.69;
  ui_line(cx,cy,cx+cos(angle)*10,cy+sin(angle)*10,0.98,0.75,0.32,1);
  ui_text(cx+23,cy-17,label,11,0.89,0.89,0.90);
  ui_text(cx+23,cy+3,value,11,0.61,0.80,0.76);
);
function ui_button(x,y,w,h,title,on,accent)(
  on ? ui_fill(x,y,w,h,accent?0.23:0.19,accent?0.66:0.68,accent?0.63:0.65,1)
     : ui_fill(x,y,w,h,0.073,0.083,0.099,1);
  ui_stroke(x,y,w,h,on?0.33:0.25,on?0.76:0.29,on?0.75:0.34,1);
  on ? ui_text(x+13,y+8,title,13,0.04,0.12,0.13)
     : ui_text(x+13,y+8,title,13,0.85,0.87,0.88);
);

// Uniform scaling; panel coordinates remain fixed and mouse hitboxes match.
ui_s=min(gfx_w/1080,gfx_h/930);
ui_s=max(0.20,ui_s);
ui_ox=(gfx_w-1080*ui_s)*0.5;
ui_oy=(gfx_h-930*ui_s)*0.5;
mx=(mouse_x-ui_ox)/ui_s;
my=(mouse_y-ui_oy)/ui_s;
mb=(mouse_cap&1)!=0;
newclick=mb && !last_mb;

// Mouse wheel on footer parameters; edits actual FX sliders.
mouse_wheel!=0 ? (
  mouse_step=sign(mouse_wheel);
  (mx-335)^2+(my-869)^2<625 ? (
    slider15=max(0,min(100,slider15+mouse_step));
    sliderchange(16384);slider_automate(16384);mouse_wheel=0;
  );
  (mx-471)^2+(my-869)^2<625 ? (
    slider14=max(0,min(100,slider14+mouse_step));
    sliderchange(8192);slider_automate(8192);mouse_wheel=0;
  );
  (mx-610)^2+(my-869)^2<625 ? (
    slider9=max(0,min(1000,slider9+mouse_step*10));
    slider9>0 && slider6>1 ? (slider6=1;sliderchange(32);slider_automate(32););
    sliderchange(256);slider_automate(256);mouse_wheel=0;
  );
);
// True knob drags edit real REAPER sliders and preserve FX automation.
// Input: scroll or drag any knob; drag both trim locators and fade handles.
// These inputs edit real REAPER slider values, not visual-only state.
mouse_wheel != 0 && has_sample ? (
  wtrim0=301+716*slider17/10000;
  wtrim1=301+716*slider18/10000;
  wfi=wtrim0+716*(slider19*0.001*source_sr)/max(1,nframes);
  wfo=wtrim1-716*(slider20*0.001*source_sr)/max(1,nframes);
  my<188 && abs(mx-wfi)<20 ? (
    slider21=max(-1.5,min(1.5,slider21+0.1*sign(mouse_wheel)));
    sliderchange(1048576);slider_automate(1048576);
    mouse_wheel=0;
  );
  my>307 && abs(mx-wfo)<20 ? (
    slider22=max(-1.5,min(1.5,slider22+0.1*sign(mouse_wheel)));
    sliderchange(2097152);slider_automate(2097152);
    mouse_wheel=0;
  );
);
newclick ? (
  drag_id=0;
  wave_x0=301; wave_w=716;
  trimx0=wave_x0+wave_w*slider17/10000;
  trimx1=wave_x0+wave_w*slider18/10000;
  fade_in_x=trimx0+wave_w*(slider19*0.001*source_sr)/max(1,nframes);
  fade_out_x=trimx1-wave_w*(slider20*0.001*source_sr)/max(1,nframes);
  (my>=147 && my<=348 && has_sample) ? (
    my<187 && abs(mx-fade_in_x)<17 ? drag_id=22 :
    my>309 && abs(mx-fade_out_x)<17 ? drag_id=23 :
    abs(mx-trimx0)<15 ? drag_id=20 :
    abs(mx-trimx1)<15 ? drag_id=21 : 0;
  );
  drag_id==0 && my>=440 && my<630 ? (
    // ADSR control points: attack x (slider 1), decay/sustain x/y (2,3), release x (4).
    abs(mx-plot_release_start)<18 && abs(my-(plotbottom-sv*plotheight))<25 ? drag_id=33 :
    abs(mx-plot_attack_x)<19 ? drag_id=30 :
    abs(mx-plot_decay_x)<19 ? drag_id=31 :
    abs(mx-plot_rel_x)<19 ? drag_id=32 : 0;
  );
  drag_id==0 ? (
    dx=mx-190;dy=my-735; dx*dx+dy*dy<3000 ? drag_id=1;
    dx=mx-372;dy=my-735; dx*dx+dy*dy<3000 ? drag_id=2;
    dx=mx-554;dy=my-735; dx*dx+dy*dy<3000 ? drag_id=3;
    dx=mx-736;dy=my-735; dx*dx+dy*dy<3000 ? drag_id=4;
    dx=mx-920;dy=my-735; dx*dx+dy*dy<3000 ? drag_id=5;
    dx=mx-326;dy=my-375; dx*dx+dy*dy<700 ? drag_id=6;
    dx=mx-610;dy=my-869; dx*dx+dy*dy<700 ? drag_id=7;
    dx=mx-335;dy=my-869; dx*dx+dy*dy<700 ? drag_id=8;
    dx=mx-471;dy=my-869; dx*dx+dy*dy<700 ? drag_id=9;
  );
  drag_start_y=my;
  drag_initial=0;
  drag_id==1 ? drag_initial=log(1+slider1/100)/log(321);
  drag_id==2 ? drag_initial=log(1+slider2/100)/log(321);
  drag_id==3 ? drag_initial=(slider3+48)/48;
  drag_id==4 ? drag_initial=log(1+slider4/100)/log(321);
  drag_id==5 ? drag_initial=(slider5+36)/48;
  drag_id==6 ? drag_initial=(slider8+12)/24;
  drag_id==7 ? drag_initial=slider9/1000;
  drag_id==8 ? drag_initial=slider15/100;
  drag_id==9 ? drag_initial=slider14/100;
  drag_id==0 ? (
    mx>569 && mx<608 && my>52 && my<91 ? preset_index=max(0,preset_index-1);
    mx>842 && mx<884 && my>52 && my<91 ? preset_index=min(3,preset_index+1);
    (mx>569 && mx<608 || mx>842 && mx<884) && my>52 && my<91 ? (
      preset_index==0 ? (slider1=0;slider2=200;slider3=0;slider4=650;);
      preset_index==1 ? (slider1=330;slider2=1700;slider3=-4;slider4=2500;);
      preset_index==2 ? (slider1=0;slider2=220;slider3=-28;slider4=150;);
      preset_index==3 ? (slider1=5;slider2=500;slider3=-7;slider4=1300;);
      sliderchange(15); slider_automate(15);
    );
    mx>889 && mx<1034 && my>45 && my<99 ? help_frames=210;
    mx>755 && mx<868 && my>855 && my<885 ? (slider13=1-slider13;sliderchange(4096);slider_automate(4096););
    mx>887 && mx<962 && my>855 && my<885 ? (slider6=1;sliderchange(32);slider_automate(32););
    mx>=962 && mx<1030 && my>855 && my<885 ? (slider6=4;sliderchange(32);slider_automate(32););
    mx>721 && mx<872 && my>364 && my<397 ? (slider10=1-slider10;sliderchange(512);slider_automate(512););
    mx>878 && mx<1025 && my>364 && my<397 ? (slider12=slider12>=160 ? 30 : slider12+30;sliderchange(2048);slider_automate(2048););
  );
);
mb && drag_id>0 ? (
  norm=max(0,min(1,drag_initial+(drag_start_y-my)/180));
  drag_id==1 ? (slider1=100*(321^norm-1);sliderchange(1);slider_automate(1););
  drag_id==2 ? (slider2=100*(321^norm-1);sliderchange(2);slider_automate(2););
  drag_id==3 ? (slider3=-48+norm*48;sliderchange(4);slider_automate(4););
  drag_id==4 ? (slider4=100*(321^norm-1);sliderchange(8);slider_automate(8););
  drag_id==5 ? (slider5=-36+norm*48;sliderchange(16);slider_automate(16););
  drag_id==6 ? (slider8=-12+norm*24;sliderchange(128);slider_automate(128););
  drag_id==7 ? (
    slider9=norm*1000;sliderchange(256);slider_automate(256);
    slider9>0 && slider6>1 ? (slider6=1;sliderchange(32);slider_automate(32););
  );
  drag_id==8 ? (slider15=norm*100;sliderchange(16384);slider_automate(16384););
  drag_id==9 ? (slider14=norm*100;sliderchange(8192);slider_automate(8192););
  (drag_id==20 || drag_id==21) && has_sample ? (
    targetpct=max(0,min(10000,(mx-301)/716*10000));
    drag_id==20 ? (slider17=min(slider18-20,targetpct);sliderchange(65536);slider_automate(65536);) :
    (slider18=max(slider17+20,targetpct);sliderchange(131072);slider_automate(131072););
  );
  (drag_id==22 || drag_id==23) && has_sample ? (
    targetframes=(mx-301)/716*nframes;
    drag_id==22 ? (slider19=max(0,min(300,(targetframes-nframes*slider17/10000)/source_sr*1000));sliderchange(262144);slider_automate(262144);) :
    (slider20=max(0,min(300,(nframes*slider18/10000-targetframes)/source_sr*1000));sliderchange(524288);slider_automate(524288););
  );
  drag_id==30 ? (slider1=max(0,min(32000,(mx-plotx)/max(1,plotw*0.23)*32000));sliderchange(1);slider_automate(1););
  drag_id==31 ? (
    slider2=max(0,min(32000,(mx-plot_attack_x)/max(1,plotw*0.23)*32000));
    slider3=max(-48,min(0,-48+48*(plotbottom-my)/plotheight));
    sliderchange(6);slider_automate(6);
  );
  drag_id==32 ? (slider4=max(0,min(32000,(mx-plot_release_start)/max(1,plotx+plotw-plot_release_start)*32000));sliderchange(8);slider_automate(8););
  drag_id==33 ? (slider3=max(-48,min(0,-48+48*(plotbottom-my)/plotheight));sliderchange(4);slider_automate(4););
);
!mb && drag_id>0 ? (
  drag_id<=7 ? slider_automate(2^(drag_id-1),1);
);
!mb ? drag_id=0;
last_mb=mb;
help_frames>0 ? help_frames-=1;

// Textured dark burgundy cabinet with subtle fixed speckle texture.
ui_fill(0,0,1080,930,0.27,0.052,0.074,1);
ib=0;
loop(116,
  amount=ib/116;
  ui_fill(0,ib*8.1,1080,8.2,0.31-amount*0.08,0.07-amount*0.012,0.090-amount*0.015,0.60);
  ib+=1;
);
q=0;
loop(240,
  sx=(q*683+51)%1080;
  sy=(q*227+103)%930;
  strength=0.04+0.08*(0.5+0.5*sin(q*4.711));
  ui_fill(sx,sy,1.5,1.3,0.95,0.59,0.56,strength);
  q+=1;
);

// Top brand, centered preset chooser, and sample-import help button.
ui_text(45,30,"MOONAR",43,1,0.98,0.97);
ui_text(247,42,"RESYNTH",24,0.89,0.93,0.92);
ui_text(247,73,"NATURAL LOOP / SPECTRAL   /   V 0.6.4",11,0.40,0.81,0.75);
ui_fill(568,49,305,48,0.04,0.075,0.112,1);
ui_stroke(568,49,305,48,0.013,0.023,0.039,1);
ui_text(576,56,"<",25,0.60,0.78,0.91);
ui_text(845,56,">",25,0.60,0.78,0.91);
preset_index==0 ? ui_text(614,62,"CLASSIC",18,0.88,0.94,0.98);
preset_index==1 ? ui_text(614,62,"SOFT PAD",18,0.88,0.94,0.98);
preset_index==2 ? ui_text(614,62,"SHORT PLUCK",18,0.88,0.94,0.98);
preset_index==3 ? ui_text(614,62,"LONG BASS",18,0.88,0.94,0.98);
ui_fill(890,47,145,52,0.13,0.15,0.17,1);
ui_stroke(890,47,145,52,0.015,0.021,0.025,1);
ui_circle(911,73,8,0.96,0.60,0.15,1,1);
ui_text(927,64,"LOAD SAMPLE",13,0.94,0.94,0.93);

// Sample browser + waveform viewer.
ui_panel(44,128,990,282);
ui_fill(61,146,225,236,0.041,0.049,0.057,1);
ui_fill(67,154,213,34,0.028,0.036,0.043,1);
ui_text(80,163,"SAMPLE LIBRARY",13,0.54,0.64,0.70);
ui_fill(67,195,213,58,0.09,0.20,0.20,1);
ui_fill(67,195,4,58,0.29,0.81,0.73,1);
has_sample ? (
  ui_text(83,203,"IMPORTED SAMPLE",14,0.90,0.96,0.95);
  sprintf(#library_info,"%.2f sec   /   %d partials",nframes/max(1,source_sr),npeak);
  ui_text(83,229,#library_info,12,0.56,0.76,0.73);
) : (
  ui_text(83,209,"NO AUDIO LOADED",13,0.85,0.92,0.92);
);
ui_text(79,285,"SOURCE",12,0.49,0.59,0.61);
ui_text(79,309,"Mono / stereo WAV",12,0.76,0.81,0.81);
ui_text(79,342,"Load through REAPER",12,0.49,0.59,0.61);

// Wave viewport background & horizontal grid.
wx=301;wy=147;ww=716;wh=201;
ui_fill(wx,wy,ww,wh,0.013,0.029,0.031,1);
ui_fill(wx,wy,ww*0.75,wh,0.038,0.119,0.112,0.56);
j=1;
loop(6,
  gx=wx+j*ww/7;
  ui_line(gx,wy+4,gx,wy+wh-4,0.17,0.29,0.29,0.27);
  j+=1;
);
ui_line(wx,wy+wh*0.5,wx+ww,wy+wh*0.5,0.21,0.40,0.39,0.4);
has_sample ? (
  startx=wx+ww*slider17/10000;
  endx=wx+ww*slider18/10000;
  ui_fill(wx,wy,max(0,startx-wx),wh,0.002,0.008,0.01,0.78);
  ui_fill(endx,wy,max(0,wx+ww-endx),wh,0.002,0.008,0.01,0.78);
  ui_fill(startx,wy,max(1,endx-startx),wh,0.08,0.31,0.28,0.20);
  xpos=0;
  loop(ww,
    from=floor(xpos/max(1,ww-1)*(nframes-1));
    dt=max(1,floor(nframes/max(1,ww)));
    mn=2;ma=-2;
    ss=0;
    loop(7,
      si=min(nframes-1,from+floor(ss*dt/7));
      amp=max(abs(samp_l[si]),abs(samp_r[si]));
      mn=min(mn,-amp);ma=max(ma,amp);
      ss+=1;
    );
    hh=wh*0.42;
    ytop=wy+wh*0.5-max(-hh,min(hh,ma*hh*2.0));
    ybot=wy+wh*0.5-max(-hh,min(hh,mn*hh*2.0));
    ui_line(wx+xpos,ytop,wx+xpos,max(ytop+1,ybot),0.35,0.84,0.77,0.88);
    xpos+=1;
  );
  // Shade unselected PCM and show draggable edit cursors.
  ui_fill(wx,wy,max(0,startx-wx),wh,0.003,0.007,0.009,0.55);
  ui_fill(endx,wy,max(0,wx+ww-endx),wh,0.003,0.007,0.009,0.55);
  ui_line(startx,wy+1,startx,wy+wh-1,0.35,0.95,0.84,1);
  ui_line(endx,wy+1,endx,wy+wh-1,0.35,0.95,0.84,1);
  ui_circle(startx,wy+wh*0.52,8,0.35,0.95,0.84,1,1);
  ui_circle(endx,wy+wh*0.52,8,0.35,0.95,0.84,1,1);
  fadeix=min(endx,startx+ww*(slider19*0.001*source_sr)/max(1,nframes));
  fadeox=max(startx,endx-ww*(slider20*0.001*source_sr)/max(1,nframes));
  ui_line(startx,wy+wh*0.5,fadeix,wy+3,0.98,0.69,0.30,1);
  ui_line(fadeox,wy+wh-4,endx,wy+wh*0.5,0.98,0.69,0.30,1);
  ui_circle(fadeix,wy+4,6,0.98,0.69,0.30,1,1);
  ui_circle(fadeox,wy+wh-4,6,0.98,0.69,0.30,1,1);
  sprintf(#region_info,"START %.2fs   END %.2fs   LENGTH %.2fs",nframes*slider17/10000/source_sr,nframes*slider18/10000/source_sr,nframes*(slider18-slider17)/10000/source_sr);
  ui_text(wx+12,wy+wh-21,#region_info,12,0.70,0.95,0.90);
  ui_text(wx+12,wy+12,"CENTER: START/END / EDGE: FADES / WHEEL: BEND",12,0.58,0.94,0.85);
) : (
  ui_text(wx+106,wy+72,"SELECT AN AUDIO ITEM IN REAPER",19,0.56,0.78,0.73);
  ui_text(wx+144,wy+108,"THEN RUN THE MOONAR IMPORT ACTION",13,0.63,0.70,0.72);
);
ui_stroke(wx,wy,ww,wh,0.24,0.30,0.31,1);
ui_text(376,369,"PITCH",12,0.88,0.89,0.90);
ui_circle(326,375,23,0.03,0.04,0.047,1,1);
ui_circle(326,375,16,0.12,0.13,0.14,1,1);
pitch_angle=2.35+(slider8+12)/24*4.69;
ui_line(326,375,326+cos(pitch_angle)*13,375+sin(pitch_angle)*13,0.70,0.90,0.87,1);
sprintf(#pitch_val,"%+.2f st",slider8);
ui_fill(436,359,104,33,0.039,0.047,0.056,1);
ui_stroke(436,359,104,33,0.23,0.25,0.27,1);
ui_text(452,366,#pitch_val,13,0.88,0.91,0.92);
has_sample ? (
  sprintf(#sample_state,"MIDI ROOT %d",detected_note);
  ui_text(553,366,#sample_state,12,0.69,0.73,0.72);
) : ui_text(553,366,"WAITING FOR AUDIO",12,0.69,0.73,0.72);
// Footer readouts double as interactive toggles for tuning / crossfade.
ui_fill(722,359,146,35,slider10>0?0.078:0.065,slider10>0?0.22:0.087,slider10>0?0.20:0.10,1);
ui_stroke(722,359,146,35,0.27,0.37,0.37,1);
ui_text(734,368,slider10>0 ? "AUTO C : ON" : "AUTO C : OFF",12,0.69,0.92,0.84);
ui_fill(877,359,142,35,0.076,0.094,0.11,1);
ui_stroke(877,359,142,35,0.25,0.28,0.31,1);
sprintf(#fade_info,"BEND  %d",floor(slider12));
ui_text(888,368,#fade_info,12,0.84,0.85,0.86);

// ADSR visual panel, animated spectrogram-inspired stroke and shaped area.
ui_panel(44,427,990,400);
ui_fill(61,443,954,189,0.028,0.035,0.039,1);
gidx=1;
loop(5,
  ui_line(70+gidx*932/6,448,70+gidx*932/6,627,0.23,0.26,0.27,0.45);
  gidx+=1;
);
plotx=72;ploty=454;plotw=925;plotbottom=619;plotheight=149;
// Visible lower waveform: the *selected* PCM, normalized for display.
// It is behind the ADSR fill, so the amber envelope remains draggable.
has_sample && clip_end>clip_start ? (
  env_peak=0.0001;
  wi=0;
  loop(440,
    idx=min(max(0,nframes-1),floor(clip_start+(clip_end-clip_start)*wi/440));
    env_peak=max(env_peak,max(abs(samp_l[idx]),abs(samp_r[idx])));
    wi+=1;
  );
  env_gain=min(12,0.94/env_peak);
  wi=0;
  loop(440,
    fidx=floor(clip_start+(clip_end-clip_start)*wi/440);
    jdx=min(nframes-1,fidx+max(1,floor((clip_end-clip_start)/440)));
    v0=max(abs(samp_l[fidx]),abs(samp_r[fidx]));
    v1=max(abs(samp_l[jdx]),abs(samp_r[jdx]));
    height0=min(32,max(v0,v1)*env_gain*32);
    px=plotx+plotw*wi/440;
    ui_line(px,plotbottom-32-height0,px,plotbottom-32+height0,0.29,0.87,0.79,0.88);
    wi+=1;
  );
);
// Display each segment at a fixed scale independent of Release time.
// Therefore the last release node ALWAYS moves right as Release increases.
atk=slider1/1000;dec=slider2/1000;rel=slider4/1000;sv=(slider3+48)/48;
plot_attack_x=plotx+plotw*0.23*(atk/32);
plot_decay_x=plot_attack_x+plotw*0.23*(dec/32);
plot_release_start=max(plot_decay_x+plotw*0.15,plotx+plotw*0.52);
plot_rel_x=plot_release_start+(plotx+plotw-plot_release_start)*(rel/32);
ps=0;pxprev=plotx;pyprev=plotbottom;
loop(232,
  xx=plotx+plotw*ps/231;
  xx<=plot_attack_x ? env=(plot_attack_x>plotx ? (xx-plotx)/(plot_attack_x-plotx) : 1) :
  xx<=plot_decay_x ? env=1-(1-sv)*((xx-plot_attack_x)/max(0.001,plot_decay_x-plot_attack_x)) :
  xx<=plot_release_start ? env=sv :
  xx<=plot_rel_x ? env=sv*exp(-5*(xx-plot_release_start)/max(0.001,plot_rel_x-plot_release_start)) : env=0;
  yy=plotbottom-env*plotheight;
  ui_line(xx,yy,xx,plotbottom,0.27,0.65,0.57,0.18);
  ps>0 ? ui_line(pxprev,pyprev,xx,yy,0.98,0.67,0.24,1);
  pxprev=xx;pyprev=yy;
  ps+=1;
);
// Draggable yellow ADSR nodes; Release endpoint remains release-relative.
plot_total=atk+dec+rel;
ui_line(plotx,plotbottom,plot_attack_x,plotbottom-plotheight,0.99,0.72,0.32,1);
ui_line(plot_attack_x,plotbottom-plotheight,plot_decay_x,plotbottom-sv*plotheight,0.99,0.72,0.32,1);
ui_line(plot_decay_x,plotbottom-sv*plotheight,plot_release_start,plotbottom-sv*plotheight,0.99,0.72,0.32,1);
ui_line(plot_release_start,plotbottom-sv*plotheight,plot_rel_x,plotbottom,0.99,0.72,0.32,1);
ui_circle(plotx,plotbottom,6,0.97,0.69,0.26,1,1);
ui_circle(plot_attack_x,plotbottom-plotheight,9,0.97,0.69,0.26,1,1);
ui_circle(plot_decay_x,plotbottom-sv*plotheight,9,0.97,0.69,0.26,1,1);
ui_circle(plot_release_start,plotbottom-sv*plotheight,9,0.99,0.77,0.29,1,1);
ui_circle(plot_rel_x,plotbottom,9,0.97,0.69,0.26,1,1);
ui_text(75,449,"ENVELOPE",12,0.55,0.68,0.69);
ui_text(76,636,"0",11,0.62,0.67,0.66);
ui_text(284,636,"ATTACK",11,0.56,0.63,0.63);
ui_text(522,636,"DECAY / SUSTAIN (dB)",11,0.56,0.63,0.63);
ui_text(870,636,"RELEASE",11,0.56,0.63,0.63);

slider1>=1000 ? sprintf(#a_val,"%.2f s",slider1/1000) : sprintf(#a_val,"%.0f ms",slider1);
slider2>=1000 ? sprintf(#d_val,"%.2f s",slider2/1000) : sprintf(#d_val,"%.0f ms",slider2);
sprintf(#s_val,"%.1f dB",slider3);
slider4>=1000 ? sprintf(#r_val,"%.2f s",slider4/1000) : sprintf(#r_val,"%.0f ms",slider4);
sprintf(#v_val,"%+.1f dB",slider5);
ui_knob(190,735,35,log(1+slider1/100)/log(321),"ATTACK",#a_val,0);
ui_knob(372,735,35,log(1+slider2/100)/log(321),"DECAY",#d_val,0);
ui_knob(554,735,35,(slider3+48)/48,"SUSTAIN",#s_val,0);
ui_knob(736,735,35,log(1+slider4/100)/log(321),"RELEASE",#r_val,0);
ui_line(828,670,828,787,0.23,0.25,0.28,1);
ui_knob(920,735,35,(slider5+36)/48,"VOLUME",#v_val,1);

// Footer strip with real glide/legato/mode controls.
ui_panel(44,837,990,65);
sprintf(#noise_val,"%.0f%%",slider15);
sprintf(#motion_val,"%.0f%%",slider14);
sprintf(#glide,"%.0f ms",slider9);
ui_mini_knob(335,869,slider15/100,"NOISE",#noise_val);
ui_mini_knob(471,869,slider14/100,"MOTION",#motion_val);
ui_mini_knob(610,869,slider9/1000,"GLIDE",#glide);
ui_button(755,854,112,33,"LEGATO",slider13>0,0);
ui_button(886,854,74,33,"MONO",slider6<=1,1);
ui_button(960,854,72,33,"POLY",slider6>1,1);
ui_text(64,856,"MOONAR  /  DSP",13,0.88,0.90,0.88);
loading ? ui_text(64,877,"IMPORTING SAMPLE...",11,0.95,0.69,0.23)
: has_sample ? (
  sprintf(#footer,"%d VOICES  |  %d PARTIALS  |  SPECTRAL ENGINE",active_count,npeak);
  ui_text(64,877,"SAMPLE READY  /  MIDI IN",10,0.55,0.72,0.69);
) : ui_text(64,877,"NO AUDIO LOADED",10,0.79,0.67,0.55);

// Import explanation: the button does not pretend to open a file dialog.
help_frames>0 ? (
  ui_fill(290,315,735,70,0.042,0.06,0.067,0.99);
  ui_stroke(290,315,735,70,0.3,0.78,0.66,1);
  ui_text(307,326,"TO LOAD A SAMPLE:",16,0.82,0.94,0.87);
  ui_text(307,352,"Drop a file in the MOONAR 0.5.1 control window",13,0.71,0.83,0.81);
);

gfx_getchar();
]===]
local function compatible_engine(data)
  if not data then return false end
  for _,signature in ipairs(ENGINE_COMPATIBLE) do
    if data:find(signature,1,true) then return true end
  end
  return false
end
local function install_jsfx()
  local resource=reaper.GetResourcePath()
  local dir=resource..SEP..'Effects'
  local path=dir..SEP..JSFX_FILENAME
  local existing=read_all(path)
  -- IMPORTANT: never replace a compatible active DSP just to update Lua GUI.
  -- This deliberately leaves 0.5.0 and 0.5.1 compiled FX untouched.
  if compatible_engine(existing) then return true, 'Existing seamless DSP retained (no recompile required)' end
  if not BUNDLED_JSFX or not BUNDLED_JSFX:find('MOONAR_BUILD=0.6.4',1,true) then
    return false, 'Embedded DSP payload missing or invalid.'
  end
  if existing and not existing:find('desc:MOONAR Resynth',1,true) then
    return false, 'Unrelated effect exists at '..path..'. Nothing overwritten.'
  end
  reaper.RecursiveCreateDirectory(dir,0)
  if existing then
    local backup=path..'.before_live064.backup'
    if not read_all(backup) then
      local b=io.open(backup,'wb')
      if not b then return false, 'Unable to write a backup of the existing JSFX.' end
      b:write(existing);b:close()
    end
  end
  local f,err=io.open(path,'wb')
  if not f then return false, 'Cannot install JSFX: '..tostring(err) end
  f:write(BUNDLED_JSFX);f:close()
  if read_all(path)~=BUNDLED_JSFX then return false,'JSFX write verification failed.' end
  return true,'Audio engine installed. New effect instance may need FX-list refresh, but do not quit REAPER.'
end
local function install_bundled_updater()
  -- A successful GitHub update to 0.7.9 bootstraps the fixed updater itself.
  -- Next time UPDATE is pressed, it verifies both the Lua GUI and JSFX engine.
  local dir=reaper.GetResourcePath()..SEP..'Scripts'
  local path=dir..SEP..'MOONAR_UPDATE.lua'
  reaper.RecursiveCreateDirectory(dir,0)
  local previous=read_all(path)
  if previous==BUNDLED_UPDATER then return true end
  local temp=path..'.moonar_updater_new'
  local f,e=io.open(temp,'wb')
  if not f then return false,'Cannot stage the updater: '..tostring(e) end
  local written,why=f:write(BUNDLED_UPDATER)
  local closed=f:close()
  if not written or not closed then
    os.remove(temp)
    return false,'Could not save the updater: '..tostring(why)
  end
  if previous then
    local backup=path..'.backup_before_update_1_3'
    if not read_all(backup) then
      local b,err=io.open(backup,'wb')
      if not b then os.remove(temp);return false,'Backup error: '..tostring(err) end
      local success=b:write(previous)
      local ended=b:close()
      if not success or not ended then
        os.remove(temp)
        return false,'Failed to back up previous updater'
      end
    end
  end
  local renamed,rename_err=os.rename(temp,path)
  if not renamed then os.remove(temp);return false,'Cannot activate updater: '..tostring(rename_err) end
  return true
end
local update_ready,update_error=install_bundled_updater()
if not update_ready then
  reaper.ShowMessageBox('MOONAR updater repair failed: '..tostring(update_error),
    'MOONAR UPDATE / REPAIR',0)
end
local ready,install_err=install_jsfx()
if not ready then
  reaper.ShowMessageBox(install_err,'MOONAR RESYNTH LIVE',0)
  return
end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Radix-2 in-place FFT, Lua-only, no extra REAPER extensions needed.
local function fft(re, im, n)
  local j = 0
  for i = 0, n - 1 do
    if i < j then
      re[i], re[j] = re[j], re[i]
      im[i], im[j] = im[j], im[i]
    end
    local bit = math.floor(n / 2)
    while bit >= 1 and j >= bit do j = j-bit; bit=math.floor(bit/2) end
    j=j+bit
  end
  local sz=2
  while sz<=n do
    local half=math.floor(sz/2)
    local wrs, wis = math.cos(-2*PI/sz), math.sin(-2*PI/sz)
    for start=0,n-1,sz do
      local wr, wi=1,0
      for j=0,half-1 do
        local a,b=start+j,start+j+half
        local tr = re[b]*wr-im[b]*wi
        local ti = re[b]*wi+im[b]*wr
        re[b],im[b]=re[a]-tr,im[a]-ti
        re[a],im[a]=re[a]+tr,im[a]+ti
        wr,wi=wr*wrs-wi*wis,wr*wis+wi*wrs
      end
    end
    sz=sz*2
  end
end

local function take_audio(item)
  item = item or reaper.GetSelectedMediaItem(0,0)
  if not item then return nil,'Select an AUDIO item first.' end
  local take=reaper.GetActiveTake(item)
  if not take or reaper.TakeIsMIDI(take) then
    return nil,'Select a real audio item, not a MIDI item.'
  end
  local pos=reaper.GetMediaItemInfo_Value(item,'D_POSITION')
  local len=reaper.GetMediaItemInfo_Value(item,'D_LENGTH')
  local frames=math.min(MAX_FRAMES,math.floor(len*SR))
  if frames < 4096 then
    return nil,'Selected sample too short (minimum 0.093 s). Suggested: 0.3–2.7 seconds.'
  end
  local accessor = reaper.CreateTakeAudioAccessor(take)
  if not accessor then return nil,'Could not open the selected take audio.' end
  local l,r={},{}
  local buf = reaper.new_array(4096*2)
  local ok,err=pcall(function()
    local done=0
    while done<frames do
      local n=math.min(4096,frames-done)
      buf.clear()
      local status=reaper.GetAudioAccessorSamples(accessor,SR,2,pos+done/SR,n,buf)
      if status<=0 then error('REAPER could not read the sample at '..tostring(pos+done/SR)..' s.') end
      local a=buf.table(1,n*2)
      for i=0,n-1 do
        l[done+i+1]=a[i*2+1] or 0
        r[done+i+1]=a[i*2+2] or 0
      end
      done=done+n
    end
  end)
  reaper.DestroyAudioAccessor(accessor)
  if not ok then return nil,tostring(err) end
  return {left=l,right=r,frames=frames,length=len,item=item}
end

local function rms_in(l,r,a,b)
  local e=0;local n=0
  for i=a,b do
    local x=l[i];local y=r[i]
    if x and y then e=e+0.5*(x*x+y*y);n=n+1 end
  end
  return math.sqrt(e/math.max(1,n))
end

-- Determine sustain handoff before the original sample has faded entirely.
-- This is an original engineering choice, not a claim about Tim Hox DSP.
local function find_handoff(l,r,count)
  -- Sustain is analyzed from a stable BODY, not the nearly silent sample
  -- tail. Bass one-shots typically decay, so matching synthesis at the tail
  -- causes the old abrupt drop/swell during the PCM-to-spectral transition.
  -- A frame fraction handles very short samples; a 350ms upper cap prevents
  -- waiting for the end of long samples before sustained playback begins.
  local minimum=math.max(1,math.floor(count*0.20))
  local upper=math.max(minimum,math.floor(count*0.82))
  local anchor=math.floor(math.min(count*0.46,SR*0.35))
  return clamp(anchor,minimum,upper)
end

local function analyze(audio)
  local count=audio.frames
  local l,r=audio.left,audio.right
  local handoff=find_handoff(l,r,count)
  local win=math.min(8192, math.max(2048,math.floor(handoff*0.8)))
  local at=clamp(math.floor(handoff-win*0.67),0,count-win)
  local re,im,mono={},{},{}
  local window={}
  local energy=0
  local stereo_rms=0
  for i=0,NFFT-1 do re[i],im[i]=0,0 end
  for i=0,win-1 do
    window[i+1]=0.5-0.5*math.cos(2*PI*i/(win-1))
    local sl,sr=l[at+i+1],r[at+i+1]
    local mid=(sl+sr)*0.5
    mono[i+1]=mid
    energy=energy+mid*mid
    stereo_rms=stereo_rms+sl*sl+sr*sr
  end
  if stereo_rms<1e-10 then return nil,'The selected audio is silent.' end
  if energy < stereo_rms*0.0005 then
    for i=0,win-1 do mono[i+1]=l[at+i+1] end
  end
  for i=0,win-1 do re[i]=mono[i+1]*window[i+1] end
  fft(re,im,NFFT)
  local mags={}
  local low=math.max(2,math.floor(35*NFFT/SR))
  local high=math.floor(math.min(12500,SR*0.47)*NFFT/SR)
  local maxmag=0
  for k=low,high do
    local m=math.sqrt(re[k]*re[k]+im[k]*im[k])
    mags[k]=m
    maxmag=math.max(maxmag,m)
  end
  if maxmag<1e-7 then return nil,'No audible stable spectral material detected.' end
  local candidates={}
  for k=low+1,high-1 do
    local m=mags[k]
    if m>maxmag*0.012 and m>(mags[k-1] or 0) and m>=(mags[k+1] or 0) then
      local a=math.log(math.max(1e-14,mags[k-1] or 0))
      local b=math.log(math.max(1e-14,m))
      local c=math.log(math.max(1e-14,mags[k+1] or 0))
      local d=a-2*b+c
      local offset=math.abs(d)>1e-12 and clamp(0.5*(a-c)/d,-0.5,0.5) or 0
      candidates[#candidates+1]={freq=(k+offset)*SR/NFFT,mag=m}
    end
  end
  table.sort(candidates,function(x,y) return x.mag>y.mag end)
  local peaks={}
  for _,p in ipairs(candidates) do
    local distinct=true
    for _,chosen in ipairs(peaks) do
      if math.abs(p.freq-chosen.freq)<7 then distinct=false;break end
    end
    if distinct then peaks[#peaks+1]=p end
    if #peaks>=MAX_PEAKS then break end
  end
  if #peaks==0 then return nil,'No tonal partials were detected. Try a tonal sample.' end

  -- Sequential weighted least squares. Unlike earlier versions, phase is
  -- referenced to the absolute source sample index; this is critical for
  -- a continuous phase at the PCM/spectral handoff.
  local resL,resR={},{}
  for i=0,win-1 do
    resL[i+1]=l[at+i+1]
    resR[i+1]=r[at+i+1]
  end
  local refined={}
  for _,p in ipairs(peaks) do
    local wc,ws={},{}
    local cc,ss,cs=0,0,0
    local lc,ls,rc,rs=0,0,0,0
    for i=0,win-1 do
      local theta=2*PI*p.freq*(at+i)/SR
      local c,s=math.cos(theta),math.sin(theta)
      wc[i+1]=c;ws[i+1]=s
      local w=window[i+1]
      cc=cc+w*c*c;ss=ss+w*s*s;cs=cs+w*c*s
      lc=lc+w*resL[i+1]*c;ls=ls+w*resL[i+1]*s
      rc=rc+w*resR[i+1]*c;rs=rs+w*resR[i+1]*s
    end
    local den=math.max(1e-8,cc*ss-cs*cs)
    local al=(lc*ss-ls*cs)/den
    local bl=(ls*cc-lc*cs)/den
    local ar=(rc*ss-rs*cs)/den
    local br=(rs*cc-rc*cs)/den
    p.lamp=math.sqrt(al*al+bl*bl)
    p.ramp=math.sqrt(ar*ar+br*br)
    p.lphase=math.atan(-bl,al)
    p.rphase=math.atan(-br,ar)
    for i=0,win-1 do
      resL[i+1]=resL[i+1]-al*wc[i+1]-bl*ws[i+1]
      resR[i+1]=resR[i+1]-ar*wc[i+1]-br*ws[i+1]
    end
    if (p.lamp+p.ramp)>0.000035 then refined[#refined+1]=p end
  end
  peaks=refined
  if #peaks==0 then return nil,'The chosen region is too quiet for resynthesis.' end

  -- Manual root is available inside JSFX for chords. Lowest significant
  -- spectral partial is only a MONOPHONIC pitch estimate.
  local loudest=candidates[1].mag
  local root_hz=math.huge
  for _,p in ipairs(peaks) do
    if p.mag>loudest*0.12 and p.freq>=40 and p.freq<root_hz then root_hz=p.freq end
  end
  if root_hz==math.huge then root_hz=peaks[1].freq end
  local root=clamp(math.floor(69+12*math.log(root_hz/440)/math.log(2)+0.5),0,127)

  -- Match predicted body loudness to original level around handoff.
  local mcount=0
  local enL,enR,synL,synR=0,0,0,0
  local mf=math.min(1024, math.max(128,math.floor(handoff*0.10)))
  local start=clamp(handoff-mf,1,count-mf)
  for i=start,start+mf-1,4 do
    local yl,yr=0,0
    for _,p in ipairs(peaks) do
      local theta=2*PI*p.freq*(i-1)/SR
      yl=yl+p.lamp*math.cos(theta+p.lphase)
      yr=yr+p.ramp*math.cos(theta+p.rphase)
    end
    enL=enL+l[i]*l[i];enR=enR+r[i]*r[i]
    synL=synL+yl*yl;synR=synR+yr*yr
    mcount=mcount+1
  end
  local gainL=clamp(math.sqrt(enL/math.max(1e-9,synL)),0.3,2.2)
  local gainR=clamp(math.sqrt(enR/math.max(1e-9,synR)),0.3,2.2)

  local function residual_bands(res)
    local lp_lo,lp_hi=0,0
    local a=1-math.exp(-2*PI*500/SR)
    local b=1-math.exp(-2*PI*3500/SR)
    local e0,e1,e2=0,0,0
    for i=1,win do
      local v=res[i]
      lp_lo=lp_lo+a*(v-lp_lo)
      lp_hi=lp_hi+b*(v-lp_hi)
      local low=lp_lo
      local mid=lp_hi-lp_lo
      local high=v-lp_hi
      e0=e0+low*low;e1=e1+mid*mid;e2=e2+high*high
    end
    return math.sqrt(e0/win),math.sqrt(e1/win),math.sqrt(e2/win)
  end
  local l0,l1,l2=residual_bands(resL)
  local r0,r1,r2=residual_bands(resR)
  return {peaks=peaks,root=root,root_hz=root_hz,handoff=handoff,
          model_gain_l=gainL,model_gain_r=gainR,
          noise={l0,l1,l2,r0,r1,r2},window_start=at,window_size=win}
end


local source,track,fx,slot,analysis_result=nil,nil,-1,nil,nil
local file_label='DROP WAV / AIFF / FLAC HERE'
local status='Drop an audio file, or click LOAD SAMPLE.'
local busy=false
local wave_min,wave_max={},{}
local UWIN, UH=1080,930
local mx,my,pressed,drag,drag_initial_y,drag_initial_val=0,0,false,0,0,0
local did_mouse_down=false
-- Real user preset bank, not the four ADSR-only macros from the reference UI.
local preset_entries,selected_preset_id,preset_search,preset_scroll,preset_search_focus={},nil,'',0,false
local PRESET_DIR=reaper.GetResourcePath()..SEP..'MOONAR_RESYNTH'..SEP..'Presets'
local PRESET_HEADER='MOONAR_PRESET_V1'
local preset_hitrows={}

local last_region_start,last_region_end=0,1
local render_scale,origin_x,origin_y=1,0,0
local view_start,view_span=0,1 -- Normalized viewport over the full imported audio.
local view_cache_start,view_cache_span=-1,-1
local trim_drag_start_norm,trim_drag_start_pct,trim_drag_end_pct=0,0,10000
local last_numeric_edit_time, last_numeric_edit_par=0,0
local did_right_mouse_down=false
local knobparam={1,2,3,4,5,8,9,15,14}
local knobx={190,372,554,736,920,326,610,335,471}
local knoby={735,735,735,735,735,375,869,869,869}
local knob_radius={48,48,48,48,48,25,23,23,23}
local knobrange={{0,32000},{0,32000},{-48,0},{0,32000},{-36,12},{-12,12},{0,1000},{0,100},{0,100}}

local function pget(i)
  if not track or not reaper.ValidatePtr2(0,track,'MediaTrack*') or fx<0 then return nil end
  return reaper.TrackFX_GetParam(track,fx,i-1)
end
local defaults={0,200,0,650,0,4,72,0,0,1,1,90,0,0,0,2,0,10000,5,70,0,0,0}
local function val(i) return pget(i) or defaults[i] or 0 end
local function pset(i,v)
  if track and fx>=0 and reaper.ValidatePtr2(0,track,'MediaTrack*') then
    reaper.TrackFX_SetParam(track,fx,i-1,v)
  end
end
-- Click the displayed numeric value, or right-click a knob, to enter an exact value.
-- Values are constrained to the documented safe range of each DSP slider.
local editable_params={
  [1]={'Attack','ms',0,32000}, [2]={'Decay','ms',0,32000},
  [3]={'Sustain','dB',-48,0}, [4]={'Release','ms',0,32000},
  [5]={'Volume','dB',-36,12}, [8]={'Pitch','semitones',-12,12},
  [9]={'Glide','ms',0,1000},[14]={'Motion','%',0,100},
  [15]={'Noise','%',0,100},
}
local function edit_numeric_param(param)
  local d=editable_params[param];if not d then return end
  local prompt=string.format('Enter exact %s (%s). Allowed: %g to %g',d[1],d[2],d[3],d[4])
  local existing=string.format('%.4f',val(param)):gsub('0+$',''):gsub('%.$','')
  local ok,typed=reaper.GetUserInputs('MOONAR | '..d[1],1,prompt,existing)
  if not ok then return end
  typed=(typed or ''):gsub(',','.') -- Accept EU comma decimal separator.
  local num=tonumber(typed)
  if not num or num~=num or num==math.huge or num==-math.huge then
    status='Invalid number. Please enter a numeric value.';return
  end
  local clamped=math.max(d[3],math.min(d[4],num))
  pset(param,clamped)
  if param==9 and clamped>0 and val(6)>1 then
    pset(6,1);status='GLIDE: MONO mode selected'
  elseif clamped~=num then
    status=string.format('%s limited to %.3g %s (allowed %.3g to %.3g)',d[1],clamped,d[2],d[3],d[4])
  else
    status=string.format('%s set to %.4g %s',d[1],clamped,d[2])
  end
end
local function slot_taken(s)
  for ti=0,reaper.CountTracks(0)-1 do
    local tr=reaper.GetTrack(0,ti)
    for fi=0,reaper.TrackFX_GetCount(tr)-1 do
      local _,name=reaper.TrackFX_GetFXName(tr,fi,'')
      if name and name:find(FX_NAME,1,true) then
        local sl=reaper.TrackFX_GetParam(tr,fi,10)
        if math.floor(sl+0.5)==s then return tr,fi end
      end
    end
  end
  return nil
end
local function get_free_slot()
  for s=1,2 do if not slot_taken(s) then return s end end
end
-- MOONAR_FIX_071: refresh the JSFX registry in REAPER 7.42+ without quitting.
-- A newly installed JSFX is not automatically in TrackFX_AddByName's cache.
local function moonar_reload_fx_registry()
  if type(reaper.EnumInstalledFX)=='function' then
    pcall(reaper.EnumInstalledFX,-1)
  end
end
local function moonar_add_engine(tr)
  moonar_reload_fx_registry()
  local candidates,seen={},{}
  local function candidate(x)
    if type(x)=='string' and x~='' and not seen[x] then
      seen[x]=true
      candidates[#candidates+1]=x
    end
  end
  -- Prefer the identifiers returned by REAPER itself to guessed display names.
  if type(reaper.EnumInstalledFX)=='function' then
    for i=0,10000 do
      local ok,name,ident=reaper.EnumInstalledFX(i)
      if not ok then break end
      local n=(name or ''):lower()
      local id=(ident or ''):lower()
      if n:find('moonar resynth 0.6.4',1,true) or
         n:find('moonar_resynth_064',1,true) or
         id:find('moonar_resynth_064',1,true) then
        candidate(ident)
        candidate(name)
      end
    end
  end
  candidate('JS: '..FX_NAME)
  candidate('JS: MOONAR_Resynth_064')
  candidate('JS: MOONAR_Resynth_064.jsfx')
  candidate('MOONAR_Resynth_064')
  candidate('MOONAR_Resynth_064.jsfx')
  candidate(FX_NAME)
  for _,id in ipairs(candidates) do
    local index=reaper.TrackFX_AddByName(tr,id,false,1)
    if index and index>=0 then
      local ok,name=reaper.TrackFX_GetFXName(tr,index,'')
      if ok and (name or ''):lower():find('moonar',1,true) then
        return index
      end
    end
  end
  return -1
end

-- A 0.6.x legacy FX stays enabled until the new 0.6.1 instrument receives PCM.
-- This prevents the previous silent upgrade that bypassed the user's old sound.
local legacy_fx_pending={}
local function prepare_track()
  if track and reaper.ValidatePtr2(0,track,'MediaTrack*') and fx>=0 then return true end
  local seltrack=reaper.GetSelectedTrack(0,0)
  local function locate(tr)
    if not tr then return nil end
    for fi=0,reaper.TrackFX_GetCount(tr)-1 do
      local _,name=reaper.TrackFX_GetFXName(tr,fi,'')
      if name and name:find(FX_NAME,1,true) then return fi end
    end
    for fi=0,reaper.TrackFX_GetCount(tr)-1 do
      local _,name=reaper.TrackFX_GetFXName(tr,fi,'')
      if name and name:find('MOONAR Resynth',1,true) then return fi end
    end
  end
  -- Explicit track selection always wins. Do not redirect to another MOONAR
  -- track when the user highlights an otherwise empty REAPER track.
  if seltrack then
    track=seltrack
    fx=locate(seltrack) or -1
  else
    for ti=0,reaper.CountTracks(0)-1 do
      local tr=reaper.GetTrack(0,ti)
      local fi=locate(tr)
      if fi~=nil then track=tr;fx=fi;break end
    end
  end
  if track and fx>=0 then
    local _,actual_name=reaper.TrackFX_GetFXName(track,fx,'')
    if not (actual_name or ''):find(FX_NAME,1,true) then
      local old_fx=fx
      local preserved={}
      for i=1,22 do preserved[i]=reaper.TrackFX_GetParam(track,old_fx,i-1) end
      local new_fx=moonar_add_engine(track)
      if new_fx<0 then
        return false,'MOONAR seamless JSFX is missing. Previous FX left unchanged.'
      end
      fx=new_fx
      legacy_fx_pending={old_fx}
      for i=1,22 do if i~=11 then pset(i,preserved[i]) end end
      status='Old FX preserved until the selected track imports audio to the new FX.'
    end
    -- When updater 1.4 has already added the new JSFX, older MOONAR FX
    -- may still be active in the same chain. Don't let both render the same
    -- note (audible comb filtering / metallic coloration).
    -- Keep every older FX intact until the new sample is imported.
    local seen={}
    for _,old_fx in ipairs(legacy_fx_pending) do seen[old_fx]=true end
    for fi=0,reaper.TrackFX_GetCount(track)-1 do
      if fi~=fx and not seen[fi] then
        local _,name=reaper.TrackFX_GetFXName(track,fi,'')
        if name and name:find('MOONAR Resynth',1,true) and
           reaper.TrackFX_GetEnabled(track,fi) then
          legacy_fx_pending[#legacy_fx_pending+1]=fi
          seen[fi]=true
        end
      end
    end
    slot=math.floor((reaper.TrackFX_GetParam(track,fx,10) or 1)+0.5)
    if slot<1 or slot>2 then slot=1;pset(11,slot) end
    return true
  end
  local s=get_free_slot()
  if not s then return false,'Two MOONAR instances already use both import slots. Select an existing MOONAR track.' end
  local new_track=false
  if not track then
    reaper.InsertTrackAtIndex(reaper.CountTracks(0),true)
    track=reaper.GetTrack(0,reaper.CountTracks(0)-1)
    reaper.GetSetMediaTrackInfo_String(track,'P_NAME','MOONAR RESYNTH | MIDI IN',true)
    new_track=true
  end
  fx=moonar_add_engine(track)
  if fx<0 then
    if new_track then reaper.DeleteTrack(track);track=nil end
    return false,'REAPER cannot resolve MOONAR_Resynth_064.jsfx. Open FX Browser, refresh its list (F5), and run MOONAR LIVE again.'
  end
  slot=s
  pset(11,slot)
  if new_track then reaper.SetOnlyTrackSelected(track) end
  reaper.SetMediaTrackInfo_Value(track,'I_RECARM',1)
  reaper.SetMediaTrackInfo_Value(track,'I_RECMON',1)
  -- 4096 alone means MIDI input device 0, *not* all MIDI input devices.
  -- 6112 = 4096 + 63*32, All MIDI Inputs, all channels; includes the VKB.
  local current_input=reaper.GetMediaTrackInfo_Value(track,'I_RECINPUT')
  if current_input<4096 or current_input==4096 then
    reaper.SetMediaTrackInfo_Value(track,'I_RECINPUT',6112)
  end
  reaper.UpdateArrange()
  status=new_track and 'Created MOONAR instrument track.' or 'MOONAR added to highlighted REAPER track.'
  return true
end
-- MOONAR 0.7.2: ensure the newly added JSFX is online and the dedicated
-- MOONAR instrument track can receive MIDI. Never modify unrelated tracks.
local function recover_audio_route()
  if not track or fx<0 or not reaper.ValidatePtr2(0,track,'MediaTrack*') then return end
  local _,fx_name=reaper.TrackFX_GetFXName(track,fx,'')
  if not (fx_name or ''):lower():find('moonar',1,true) then return end
  reaper.TrackFX_SetEnabled(track,fx,true)
  if type(reaper.TrackFX_SetOffline)=='function' then
    reaper.TrackFX_SetOffline(track,fx,false)
  end
  local _,tn=reaper.GetSetMediaTrackInfo_String(track,'P_NAME','',false)
  -- Enable MIDI monitoring on the chosen instrument track. Do not change
  -- unrelated tracks or reset a custom hardware MIDI input on every launch.
  if reaper.GetSelectedTrack(0,0)==track or
     (tn or ''):find('MOONAR RESYNTH | MIDI IN',1,true) then
    reaper.SetMediaTrackInfo_Value(track,'I_RECARM',1)
    reaper.SetMediaTrackInfo_Value(track,'I_RECMON',1)
    local current_input=reaper.GetMediaTrackInfo_Value(track,'I_RECINPUT')
    if current_input<4096 or current_input==4096 then
      reaper.SetMediaTrackInfo_Value(track,'I_RECINPUT',6112)
    end
  end
end
local audition_note, audition_until, audition_peak, audition_reported=nil,0,0,false
local function stop_audition()
  if audition_note then
    if type(reaper.StuffMIDIMessage)=='function' then
      reaper.StuffMIDIMessage(0,0x80,audition_note,0)
    end
    audition_note=nil
  end
end
local function audition_current()
  if not source then
    status='NO SAMPLE: load a preset or WAV first.'
    return
  end
  if type(reaper.StuffMIDIMessage)~='function' then
    status='REAPER has no StuffMIDIMessage API.'
    return
  end
  if audition_note then
    stop_audition()
    status='MIDI C5 released. ADSR Release now fades out the held note.'
    return
  end
  recover_audio_route()
  reaper.SetOnlyTrackSelected(track)
  local n=math.floor(math.max(24,math.min(96,val(7)))+0.5)
  audition_note=n
  audition_until=reaper.time_precise()+0.80
  audition_peak=0
  audition_reported=false
  reaper.StuffMIDIMessage(0,0x90,n,110)
  status='HOLD: C5 sustains until you click RELEASE NOTE / C5.'
end

local function norm_to_wave_x(norm)
  return 301+(norm-view_start)/view_span*716
end
local function wave_x_to_norm(x)
  return math.max(0,math.min(1,view_start+((x-301)/716)*view_span))
end
local function build_wave(audio)
  -- Re-bin only the VISIBLE part of the source. Zoom never changes playback.
  wave_min,wave_max={},{}
  local length=audio.frames
  local W=716
  for x=1,W do
    local first=math.max(1,math.floor((view_start+(x-1)/W*view_span)*length)+1)
    local last=math.min(length,math.max(first,math.floor((view_start+x/W*view_span)*length)))
    local mn,mxv=0,0
    local step=math.max(1,math.floor((last-first+1)/28))
    for j=first,last,step do
      local v=math.max(math.abs(audio.left[j] or 0),math.abs(audio.right[j] or 0))
      if -v<mn then mn=-v end
      if v>mxv then mxv=v end
    end
    wave_min[x],wave_max[x]=mn,mxv
  end
  view_cache_start,view_cache_span=view_start,view_span
end
local function set_view(start,span)
  span=math.max(.001,math.min(1,span))
  start=math.max(0,math.min(1-span,start))
  if math.abs(start-view_start)<1e-9 and math.abs(span-view_span)<1e-9 then return end
  view_start,view_span=start,span
  if source then build_wave(source) end
end
local function zoom_at(x,wheel)
  local u=math.max(0,math.min(1,(x-301)/716))
  local world=view_start+u*view_span
  local new_span=math.max(.001,math.min(1,view_span*2^(-wheel/120*0.33)))
  set_view(world-u*new_span,new_span)
end
local function pan_view(wheel)
  set_view(view_start-(wheel/120)*view_span*0.09,view_span)
end
-- import audio file by temporarily making a REAPER media item, then removing it.
-- Keeps the source project free of extra audio tracks.
local function file_to_audio(path)
  local srce=reaper.PCM_Source_CreateFromFile(path)
  if not srce then return nil,'Unsupported or unreadable media file.' end
  local duration=reaper.GetMediaSourceLength(srce)
  if not duration or duration<=0 then
    reaper.PCM_Source_Destroy(srce)
    return nil,'Cannot determine audio duration.'
  end
  local idx=reaper.CountTracks(0)
  reaper.PreventUIRefresh(1)
  reaper.InsertTrackAtIndex(idx,false)
  local temp=reaper.GetTrack(0,idx)
  local item=reaper.AddMediaItemToTrack(temp)
  local take=reaper.AddTakeToMediaItem(item)
  reaper.SetMediaItemTake_Source(take,srce)
  reaper.SetMediaItemInfo_Value(item,'D_POSITION',0)
  reaper.SetMediaItemInfo_Value(item,'D_LENGTH',math.min(duration,MAX_FRAMES/SR))
  local audio,error_message=take_audio(item)
  reaper.DeleteTrack(temp)
  reaper.PreventUIRefresh(-1)
  if not audio then return nil,error_message end
  audio.total_length=duration
  audio.path=path
  return audio
end
local function model_for_region(audio)
  local from=math.floor(audio.frames*val(17)/10000)
  local upto=math.floor(audio.frames*val(18)/10000)
  upto=math.min(audio.frames,math.max(from+4096,upto))
  from=math.max(0,math.min(upto-4096,from))
  local a={left={},right={},frames=upto-from}
  for j=1,a.frames do
    a.left[j]=audio.left[from+j]
    a.right[j]=audio.right[from+j]
  end
  local res,err=analyze(a)
  if not res then return nil,err end
  for _,pk in ipairs(res.peaks) do
    pk.lphase=pk.lphase-2*PI*pk.freq*from/SR
    pk.rphase=pk.rphase-2*PI*pk.freq*from/SR
  end
  res.handoff=res.handoff+from
  return res
end
local function write_bridge(audio,a,only_model)
  reaper.gmem_attach(BUS)
  local base=(slot-1)*SLOT_STRIDE
  local version=math.floor(reaper.gmem_read(base+1) or 0)+1
  reaper.gmem_write(base,0)
  reaper.gmem_write(base+2,audio.frames)
  reaper.gmem_write(base+3,SR)
  reaper.gmem_write(base+4,a.root)
  reaper.gmem_write(base+5,#a.peaks)
  reaper.gmem_write(base+6,a.handoff)
  reaper.gmem_write(base+7,a.model_gain_l)
  reaper.gmem_write(base+8,a.model_gain_r)
  for j=1,6 do reaper.gmem_write(base+8+j,a.noise[j]) end
  reaper.gmem_write(base+15,only_model and 1 or 0)
  if not only_model then
    for i=1,audio.frames do
      reaper.gmem_write(base+64+i-1,audio.left[i])
      reaper.gmem_write(base+1400064+i-1,audio.right[i])
    end
  end
  for i,peak in ipairs(a.peaks) do
    local k=i-1
    reaper.gmem_write(base+2800064+k,peak.freq)
    reaper.gmem_write(base+2800192+k,peak.lamp)
    reaper.gmem_write(base+2800320+k,peak.lphase)
    reaper.gmem_write(base+2800448+k,peak.ramp)
    reaper.gmem_write(base+2800576+k,peak.rphase)
  end
  reaper.gmem_write(base+1,version)
  reaper.gmem_write(base,1)
end
local function import_audio(audio,display_name)
  local ok,err=prepare_track()
  if not ok then status=err; return end
  status='Analyzing audio and uploading to spectral engine...'
  local oldsrc=source
  source=audio
  pset(17,0);pset(18,10000)
  local model,merr=model_for_region(audio)
  if not model then source=oldsrc;status='Cannot analyze: '..tostring(merr);return end
  analysis_result=model
  write_bridge(audio,model,false)
  -- The new FX has received sample+model data; only now is it safe to
  -- bypass a legacy MOONAR FX. Before this point the old sound remains active.
  if #legacy_fx_pending>0 and track and
     reaper.ValidatePtr2(0,track,'MediaTrack*') then
    for _,old_fx in ipairs(legacy_fx_pending) do
      reaper.TrackFX_SetEnabled(track,old_fx,false)
    end
    legacy_fx_pending={}
  end
  view_start,view_span=0,1
  build_wave(audio)
  file_label=display_name or audio.path or 'IMPORTED AUDIO'
  if audio.path and track then
    reaper.GetSetMediaTrackInfo_String(track,'P_EXT:MOONAR_SAMPLE_PATH',audio.path,true)
  end
  local truncated=(audio.total_length or audio.length or audio.frames/SR)>audio.frames/SR+0.005
  status=string.format('Loaded %.2f s%s | root MIDI %d | %d partials | adjust START / END',audio.frames/SR,truncated and ' (first 30s only)' or '',model.root,#model.peaks)
  reaper.SetOnlyTrackSelected(track)
end
local function import_path(path)
  if busy then return end
  busy=true
  local ok,result,err=pcall(file_to_audio,path)
  if ok and result then
    local loaded,loaderr=pcall(import_audio,result,path:match('[^/\\]+$') or path)
    if not loaded then status='Import failed: '..tostring(loaderr) end
  else status='Import failed: '..tostring(ok and err or result) end
  busy=false
end
local function update_model_after_trim()
  if not source or busy then return end
  busy=true
  local ok,result,err=pcall(model_for_region,source)
  if ok and result then
    analysis_result=result
    write_bridge(source,result,true)
    status=string.format('Updated model for %.2f–%.2f s | %d partials',source.frames/SR*val(17)/10000,source.frames/SR*val(18)/10000,#result.peaks)
  else
    status='Model update failed: '..tostring(ok and err or result)
  end
  busy=false
end


-- Persistent preset bank: a .moonpreset text record plus a 32-bit float WAV.
-- Each preset has its OWN copy of the sample, so moving/deleting the source
-- file in Finder does not invalidate the preset. No internet/cloud required.
local function ensure_preset_dir()
  reaper.RecursiveCreateDirectory(PRESET_DIR,0)
end
local function preset_safe_line(t)
  return tostring(t or ''):gsub('[\r\n\t]',' '):gsub('%c',' '):sub(1,90)
end
local function preset_file(id) return PRESET_DIR..SEP..id..'.moonpreset' end
local function preset_audio_file(id) return PRESET_DIR..SEP..id..'.wav' end
local function save_preset_meta(entry)
  local f,e=io.open(preset_file(entry.id),'wb')
  if not f then return false,tostring(e) end
  f:write(PRESET_HEADER,'\n',preset_safe_line(entry.name),'\n',entry.id,'.wav\n',entry.favorite and '1' or '0','\n')
  for i=1,23 do
    f:write(i>1 and '\t' or '',string.format('%.9g',tonumber(entry.values[i]) or defaults[i] or 0))
  end
  f:write('\n');f:close()
  return true
end
local function parse_preset_meta(id)
  if not id:match('^[%w_%-]+$') then return nil end
  local f=io.open(preset_file(id),'rb');if not f then return nil end
  local header=f:read('*l')
  local name=f:read('*l')
  local wavname=f:read('*l')
  local favorite=f:read('*l')
  local params=f:read('*l')
  f:close()
  if header~=PRESET_HEADER or not name or wavname~=id..'.wav' or not params then return nil end
  local af=io.open(preset_audio_file(id),'rb');if not af then return nil end
  af:close()
  local values={}
  for n in params:gmatch('[^\t]+') do values[#values+1]=tonumber(n) end
  if #values~=22 and #values~=23 then return nil end
  return {id=id,name=preset_safe_line(name),favorite=favorite=='1',values=values}
end
local function scan_preset_bank()
  ensure_preset_dir()
  local entries={}
  for i=0,10000 do
    local name=reaper.EnumerateFiles(PRESET_DIR,i)
    if not name then break end
    local id=name:match('^([%w_%-]+)%.moonpreset$')
    if id then
      local e=parse_preset_meta(id)
      if e then entries[#entries+1]=e end
    end
  end
  table.sort(entries,function(a,b)
    if a.favorite~=b.favorite then return a.favorite end
    if a.name:lower()~=b.name:lower() then return a.name:lower()<b.name:lower() end
    return a.id<b.id
  end)
  preset_entries=entries
end
local function preset_fold_case(s)
  -- Support ASCII and Russian Cyrillic case-insensitive search locally.
  if not utf8 then return s:lower() end
  local ok,result=pcall(function()
    local buf={}
    for _,cp in utf8.codes(s) do
      if cp>=0x0410 and cp<=0x042F then cp=cp+0x20
      elseif cp==0x0401 then cp=0x0451
      elseif cp>=65 and cp<=90 then cp=cp+32 end
      buf[#buf+1]=utf8.char(cp)
    end
    return table.concat(buf)
  end)
  return ok and result or s:lower()
end
local function filtered_presets()
  local filtered={}
  local query=preset_fold_case(preset_search)
  for _,e in ipairs(preset_entries) do
    if query=='' or preset_fold_case(e.name):find(query,1,true) then filtered[#filtered+1]=e end
  end
  preset_scroll=math.max(0,math.min(preset_scroll,math.max(0,#filtered-4)))
  return filtered
end
local function selected_preset_entry()
  for _,e in ipairs(preset_entries) do if e.id==selected_preset_id then return e end end
end
local function write_preset_wav(path,audio)
  if not string.pack then return false,'This REAPER Lua version does not support string.pack.' end
  local frames=audio.frames
  if frames<1 or frames>math.floor(0xFFFFFFFF/8) then return false,'Invalid audio size.' end
  local data_bytes=frames*8
  local f,e=io.open(path,'wb')
  if not f then return false,tostring(e) end
  -- 2ch / 48 kHz / IEEE FLOAT32 / little endian. Exactly the analyzed PCM.
  local hdr=string.pack('<c4I4c4c4I4I2I2I4I4I2I2c4I4',
    'RIFF',36+data_bytes,'WAVE','fmt ',16,3,2,SR,SR*8,8,32,'data',data_bytes)
  f:write(hdr)
  for start=1,frames,4096 do
    local chunk={}
    for j=start,math.min(frames,start+4095) do
      chunk[#chunk+1]=string.pack('<ff',audio.left[j] or 0,audio.right[j] or 0)
    end
    local success,why=f:write(table.concat(chunk))
    if not success then f:close();os.remove(path);return false,tostring(why) end
  end
  f:close()
  return true
end
local function make_unique_preset_id()
  local stamp=math.floor((reaper.time_precise and reaper.time_precise() or os.time())*1000000)
  for k=1,1000 do
    local id='sound_'..tostring(stamp)..'_'..k
    local f=io.open(preset_file(id),'rb')
    if f then f:close() else return id end
  end
  return nil
end
local function save_current_preset()
  if not source then status='Load audio first, then press SAVE.';return end
  local suggested=(selected_preset_entry() and selected_preset_entry().name) or
    (file_label or 'MY SOUND'):gsub('%.[%a%d]+$',''):sub(1,60)
  local ok,name=reaper.GetUserInputs('MOONAR | Save sound preset',1,'Sound preset name:',suggested)
  if not ok then return end
  name=preset_safe_line(name):gsub('^%s+',''):gsub('%s+$','')
  if name=='' then status='Preset name cannot be empty.';return end
  ensure_preset_dir()
  local id=make_unique_preset_id()
  if not id then status='Cannot allocate unique preset ID.';return end
  local entry={id=id,name=name,favorite=false,values={}}
  for i=1,23 do entry.values[i]=val(i) end
  local wok,werr=write_preset_wav(preset_audio_file(id),source)
  if not wok then status='Cannot save preset audio: '..tostring(werr);return end
  local mok,merr=save_preset_meta(entry)
  if not mok then os.remove(preset_audio_file(id));status='Cannot save preset metadata: '..tostring(merr);return end
  selected_preset_id=id; preset_search='';preset_scroll=0
  scan_preset_bank()
  status='Saved preset: '..name..' | audio + all settings'
end
local function load_sound_preset(entry)
  if not entry or busy then return end
  local path=preset_audio_file(entry.id)
  local oldsource=source
  import_path(path)
  if source==oldsource then
    status='Cannot load preset audio: '..entry.name
    return
  end
  -- The same bank can be loaded on any of the two supported MOONAR tracks.
  -- Do not restore the private shared-memory instance slot (slider11).
  for i=1,23 do
    if i~=11 and i~=17 and i~=18 then pset(i,entry.values[i] or defaults[i] or 0) end
  end
  local st=clamp(entry.values[17] or 0,0,10000)
  local en=clamp(entry.values[18] or 10000,st+50,10000)
  pset(17,st);pset(18,en)
  update_model_after_trim()
  selected_preset_id=entry.id
  file_label=entry.name
  status='Loaded preset: '..entry.name..' (audio + parameters)'
end
local function toggle_preset_favorite(entry)
  if not entry then return end
  entry.favorite=not entry.favorite
  local ok,err=save_preset_meta(entry)
  if not ok then status='Favorite failed: '..tostring(err);return end
  scan_preset_bank()
end
local function rename_sound_preset()
  local e=selected_preset_entry()
  if not e then status='Select a preset first.';return end
  local ok,name=reaper.GetUserInputs('MOONAR | Rename preset',1,'New preset name:',e.name)
  if not ok then return end
  name=preset_safe_line(name):gsub('^%s+',''):gsub('%s+$','')
  if name=='' then status='Preset name cannot be empty.';return end
  e.name=name
  local done,err=save_preset_meta(e)
  if not done then status='Rename failed: '..tostring(err);return end
  scan_preset_bank()
  status='Renamed preset: '..name
end
local function delete_sound_preset()
  local e=selected_preset_entry()
  if not e then status='Select a preset first.';return end
  local yes=reaper.ShowMessageBox('Delete preset "'..e.name..'" and its saved WAV?\nThis cannot be undone.',
    'MOONAR | Delete preset',4)
  if yes~=6 then return end
  local m= os.remove(preset_file(e.id))
  local w= os.remove(preset_audio_file(e.id))
  selected_preset_id=nil
  scan_preset_bank()
  status=(m and w) and 'Preset deleted.' or 'Deletion incomplete. Check preset folder.'
end
local function step_sound_preset(dir)
  local list=filtered_presets()
  if #list==0 then status='No saved presets. Import a sound and press SAVE.';return end
  local current=0
  for i,e in ipairs(list) do if e.id==selected_preset_id then current=i;break end end
  local index
  if current==0 then index=(dir<0 and #list or 1)
  else index=((current-1+dir)%#list)+1 end
  load_sound_preset(list[index])
end

-- Framebuffer helpers; independent graphics (no copied trademarks/assets).
local function col(r,g,b,a) gfx.set(r,g,b,a or 1) end
local function rect(x,y,w,h,r,g,b,a)
  col(r,g,b,a);gfx.rect(origin_x+x*render_scale,origin_y+y*render_scale,w*render_scale,h*render_scale,1)
end
local function line(x1,y1,x2,y2,r,g,b,a)
  col(r,g,b,a);gfx.line(origin_x+x1*render_scale,origin_y+y1*render_scale,origin_x+x2*render_scale,origin_y+y2*render_scale)
end
local function circ(x,y,r,cr,cg,cb,a)
  col(cr,cg,cb,a);gfx.circle(origin_x+x*render_scale,origin_y+y*render_scale,r*render_scale,true,1)
end
local function txt(x,y,str,sz,r,g,b)
  gfx.setfont(1,'Arial',math.max(9,math.floor((sz or 13)*render_scale)))
  col(r or .9,g or .92,b or .91)
  gfx.x=origin_x+x*render_scale;gfx.y=origin_y+y*render_scale
  gfx.drawstr(tostring(str or ''))
end
local function panel(x,y,w,h)
  rect(x+4,y+5,w,h,.025,.02,.027,.55)
  rect(x,y,w,h,.10,.113,.13,1)
  rect(x,y,w,24,.20,.20,.21,.35)
  line(x,y,x+w,y,.04,.04,.05,1)
end
local function button(x,y,w,h,label,active)
  rect(x,y,w,h,active and .24 or .06,active and .66 or .08,active and .60 or .10,1)
  txt(x+12,y+8,label,13,active and .04 or .90,active and .12 or .91,active and .12 or .90)
end
local function knob(cx,cy,r,label,value,norm,white)
  txt(cx-41,cy-75,label,13,.87,.90,.90)
  circ(cx+2,cy+4,r+8,.02,.023,.03,1)
  circ(cx,cy,r+4,.26,.27,.29,1)
  circ(cx,cy,r,.07,.078,.087,1)
  for i=0,47 do
    local angle=2.35+i*4.69/47
    local x1,y1=cx+math.cos(angle)*(r+5),cy+math.sin(angle)*(r+5)
    local x2,y2=cx+math.cos(angle)*(r+9),cy+math.sin(angle)*(r+9)
    if i/47 <= norm then line(x1,y1,x2,y2,white and .85 or 1,white and .88 or .67,white and .83 or .22,1)
    else line(x1,y1,x2,y2,.36,.37,.39,.95) end
  end
  circ(cx,cy,r-5,.14,.15,.165,1)
  local angle=2.35+norm*4.69
  line(cx,cy,cx+math.cos(angle)*(r-10),cy+math.sin(angle)*(r-10),.98,.98,.93,1)
  local value_y=(r<=20) and (cy+r+1) or (cy+r+20)
  rect(cx-49,value_y,98,29,.044,.050,.060,1)
  txt(cx-42,value_y+5,value,13,.87,.9,.90)
end
local function miniknob(x,y,norm,label,value)
  norm=math.max(0,math.min(1,norm))
  circ(x+1,y+2,17,.018,.023,.029,1)
  circ(x,y,14,.19,.20,.21,1)
  circ(x,y,11,.070,.078,.090,1)
  local a=2.35+norm*4.69
  line(x,y,x+math.cos(a)*10,y+math.sin(a)*10,.98,.75,.32,1)
  txt(x+23,y-17,label,11,.88,.89,.90)
  txt(x+23,y+3,value,11,.58,.82,.77)
end
local function ms_to_norm(ms)
  return math.log(1+math.max(0,math.min(32000,ms))/100)/math.log(321)
end
local function norm_to_ms(norm)
  norm=math.max(0,math.min(1,norm))
  return 100*(321^norm-1)
end
local function fmt_adsr(ms)
  if ms>=1000 then return string.format('%.2f s',ms/1000) end
  return string.format('%.0f ms',ms)
end
local function fmt(v,fmtstr) return string.format(fmtstr,v) end
local function draw()
  render_scale=math.max(.18,math.min(gfx.w/UWIN,gfx.h/UH))
  origin_x=(gfx.w-UWIN*render_scale)/2
  origin_y=(gfx.h-UH*render_scale)/2
  rect(0,0,UWIN,UH,.29,.055,.078,1)
  for i=0,112 do
    local t=i/112
    rect(0,i*8.3,1080,8.5,.29-.06*t,.055-.009*t,.078-.008*t,.75)
  end
  for i=0,160 do
    local x=(i*683+51)%1080;local y=(i*227+103)%930
    rect(x,y,1.3,1,.95,.65,.66,.05)
  end
  txt(45,28,'MOONAR',46,.97,.96,.94)
  txt(258,42,'RESYNTH',24,.88,.94,.94)
  txt(258,73,'V 0.7.9 / NATURAL SUSTAIN',11,.49,.84,.79)
  rect(600,47,266,48,.045,.072,.112,1)
  local chosen=selected_preset_entry()
  txt(612,60,'<  '..((chosen and chosen.name or 'PRESETS'):sub(1,17))..'  >',17,.85,.91,.97)
  button(432,51,124,40,'UPDATE',false)
  button(890,47,151,52,'LOAD SAMPLE',false)
  circ(902,72,7,.96,.63,.16,1)
  panel(44,128,990,282)
  rect(61,146,225,236,.04,.05,.055,1)
  -- Preset bank: search and scroll a real persistent collection.
  txt(73,155,'MY SOUND PRESETS',14,.71,.87,.82)
  txt(252,156,tostring(#preset_entries),12,.43,.82,.75)
  rect(69,181,207,28,.08,.104,.112,1)
  txt(78,187,(preset_search_focus and '| ' or '')..(preset_search=='' and 'Search presets...' or preset_search):sub(1,22),12,
      preset_search=='' and .43 or .92,preset_search=='' and .60 or .95,preset_search=='' and .58 or .92)
  local listed=filtered_presets()
  if #listed==0 then
    txt(81,240,#preset_entries==0 and 'NO PRESETS SAVED' or 'NO MATCHES',12,.53,.70,.66)
    txt(81,261,'Load audio, press SAVE',11,.54,.69,.67)
  end
  for row=1,4 do
    local e=listed[preset_scroll+row]
    local y=215+(row-1)*30
    if e then
      local active=e.id==selected_preset_id
      rect(69,y,207,28,active and .08 or .052,active and .28 or .095,active and .255 or .108,1)
      if active then rect(69,y,3,28,.38,.9,.76,1) end
      txt(78,y+6,e.name:sub(1,19),12,active and .94 or .69,active and .98 or .83,active and .94 or .81)
      txt(254,y+5,e.favorite and '*' or '+',16,e.favorite and .96 or .48,e.favorite and .78 or .56,e.favorite and .32 or .56)
    end
  end
  button(69,340,66,34,'SAVE',false)
  button(140,340,64,34,'RENAME',false)
  button(209,340,67,34,'DELETE',false)
  local wx,wy,ww,wh=301,147,716,201
  rect(wx,wy,ww,wh,.014,.035,.035,1)
  for i=1,6 do local x=wx+i*ww/7;line(x,wy,x,wy+wh,.2,.3,.3,.27) end
  line(wx,wy+wh/2,wx+ww,wy+wh/2,.22,.39,.36,.5)
  if source then
    local sx=norm_to_wave_x(val(17)/10000)
    local ex=norm_to_wave_x(val(18)/10000)
    local csx=math.max(wx,math.min(wx+ww,sx))
    local cex=math.max(wx,math.min(wx+ww,ex))
    rect(csx,wy,math.max(0,cex-csx),wh,.055,.22,.19,.45)
    for i=1,716 do
      local y0=wy+wh/2-(wave_max[i] or 0)*wh*.42
      local y1=wy+wh/2-(wave_min[i] or 0)*wh*.42
      line(wx+i-1,y0,wx+i-1,y1,.36,.86,.79,.87)
    end
    rect(wx,wy,math.max(0,csx-wx),wh,.009,.012,.017,.65)
    rect(cex,wy,math.max(0,wx+ww-cex),wh,.009,.012,.017,.65)
    if sx>=wx and sx<=wx+ww then
      line(sx,wy,sx,wy+wh,.46,.97,.85,1)
      circ(sx,wy+wh*.52,8,.39,.94,.81,1)
    end
    if ex>=wx and ex<=wx+ww then
      line(ex,wy,ex,wy+wh,.46,.97,.85,1)
      circ(ex,wy+wh*.52,8,.39,.94,.81,1)
    end
    local fx0=math.min(ex,norm_to_wave_x(val(17)/10000+val(19)/1000*SR/source.frames))
    local fx1=math.max(sx,norm_to_wave_x(val(18)/10000-val(20)/1000*SR/source.frames))
    if sx>=wx and fx0<=wx+ww then
      line(math.max(wx,sx),wy+wh/2,math.min(wx+ww,fx0),wy+4,.98,.66,.24,1)
      if fx0>=wx and fx0<=wx+ww then circ(fx0,wy+4,6,.99,.70,.23,1) end
    end
    if fx1>=wx and ex<=wx+ww then
      line(math.max(wx,fx1),wy+wh-4,math.min(wx+ww,ex),wy+wh/2,.98,.66,.24,1)
      if fx1>=wx and fx1<=wx+ww then circ(fx1,wy+wh-4,6,.99,.70,.23,1) end
    end
    txt(wx+12,wy+wh-24,string.format('START %.2fs   END %.2fs   LENGTH %.2fs',val(17)/10000*source.frames/SR,val(18)/10000*source.frames/SR,(val(18)-val(17))/10000*source.frames/SR),12,.67,.94,.86)
    txt(wx+12,wy+11,'FADE IN: TOP AMBER   |   LOOP FADE: BOTTOM AMBER   |   WHEEL: ZOOM',11,.74,.88,.81)
    txt(wx+410,wy+wh-24,string.format('IN %.0fms  OUT %.0fms  ZOOM %.1fx',val(19),val(20),1/view_span),11,.88,.73,.56)
  else
    txt(wx+90,wy+72,'DROP AN AUDIO FILE TO SEE WAVEFORM',18,.66,.88,.82)
    txt(wx+125,wy+105,'Or use LOAD SAMPLE (file browser)',14,.50,.7,.68)
  end
  -- Reset scale without altering playback or source selection.
  rect(wx+ww-94,wy+6,82,26,.06,.12,.14,.95)
  txt(wx+ww-81,wy+11,'FIT / 1x',11,.85,.94,.91)
  txt(376,369,'PITCH',13,.88,.88,.88)
  local pitch=val(8);knob(326,375,17,'',fmt(pitch,'%+.2f st'),(pitch+12)/24,false)
  txt(440,367,'MIDI ROOT '..math.floor(analysis_result and analysis_result.root or 72),12,.7,.78,.78)
  button(564,357,150,38,val(23)>0 and 'SPECTRAL' or 'NATURAL',val(23)==0)
  button(723,357,148,38,val(10)>0 and 'AUTO C ON' or 'AUTO C OFF',val(10)>0)
  button(878,357,143,38,string.format('LOOP FADE %.0fms',val(20)),false)
  button(70,382,201,25,audition_note and 'RELEASE NOTE / C5' or 'HOLD NOTE / C5',audition_note~=nil)
  panel(44,427,990,400)
  rect(61,443,954,189,.019,.026,.031,1)
  for i=1,5 do local x=70+i*932/6;line(x,447,x,626,.21,.26,.28,.5) end
  local x0,ybot,h,pw=85,621,154,890
  local attack_ms,decay_ms,release_ms=val(1),val(2),val(4)
  local sustain_db=math.max(-48,math.min(0,val(3)))
  -- The DSP envelope is LINEAR in amplitude; sliders and numeric display are
  -- measured in dB. Correct preview height is therefore the actual gain.
  local sustain=10^(sustain_db/20)

  -- UI stage scale is intentionally nonlinear, unlike the SOURCE timeline.
  -- This keeps both 1 ms attacks and 32 s decays visible without falsely
  -- positioning the short source sample on the long envelope time axis.
  -- Note Off cannot have a fixed time: Sustain holds while MIDI is held.
  local attack_fraction=ms_to_norm(attack_ms)
  local decay_fraction=ms_to_norm(decay_ms)
  local release_fraction=ms_to_norm(release_ms)
  local xx_at=x0+pw*0.17*attack_fraction
  local xx_dc=xx_at+(x0+pw*0.70-xx_at)*decay_fraction
  local xx_rs=x0+pw*0.77
  local xx_ed=xx_rs+pw*0.23*release_fraction
  _G.env_points={x0,xx_at,xx_dc,xx_rs,xx_ed,ybot,h,pw,32}

  -- Preview follows the actual JSFX volume law, including zero-ms stages.
  -- Release is exponential, not a misleading straight line.
  local function env_gain_at(x)
    if x<xx_at then return (x-x0)/math.max(0.0001,xx_at-x0) end
    if x<xx_dc then
      return 1-(1-sustain)*((x-xx_at)/math.max(0.0001,xx_dc-xx_at))
    end
    if x<xx_rs then return sustain end
    if x<xx_ed then
      return sustain*math.exp(-6.907755*(x-xx_rs)/math.max(0.0001,xx_ed-xx_rs))
    end
    return 0
  end

  -- The upper waveform remains the unprocessed PCM. This lower preview
  -- *modulates* the source shape by ADSR gain to avoid falsely showing an
  -- unattenuated waveform after Decay reaches the Sustain floor. The shape
  -- is illustrative, not a rendered 32-second playback file.
  if source and source.frames>0 then
    local first=math.max(1,math.floor(source.frames*val(17)/10000)+1)
    local last=math.min(source.frames,math.floor(source.frames*val(18)/10000))
    if last>first then
      local bins=440
      local peakbins={}
      local top=0.0001
      for sample_bin=1,bins do
        local first_idx=first+math.floor((sample_bin-1)*(last-first)/bins)
        local last_idx=math.max(first_idx,math.min(last,first+math.floor(sample_bin*(last-first)/bins)))
        local step=math.max(1,math.floor((last_idx-first_idx+1)/12))
        local amp=0
        for sample_idx=first_idx,last_idx,step do
          amp=math.max(amp,math.abs(source.left[sample_idx] or 0),math.abs(source.right[sample_idx] or 0))
        end
        peakbins[sample_bin]=amp
        top=math.max(top,amp)
      end
      local normalization=math.min(12,0.94/top)
      local mid=ybot-38
      for sample_bin=1,bins do
        local x=x0+(sample_bin-1)*pw/bins
        local gain=math.max(0,math.min(1,env_gain_at(x)))
        local amp=math.min(35,(peakbins[sample_bin] or 0)*normalization*35)*gain
        if amp>0.13 then line(x,mid-amp,x,mid+amp,.29,.87,.79,.88) end
      end
      txt(78,454,'ADSR-APPLIED WAVEFORM PREVIEW (ILLUSTRATIVE)',11,.50,.79,.74)
    end
  else
    txt(78,454,'ADSR AMPLITUDE ENVELOPE / NO SOURCE AUDIO',11,.50,.79,.74)
  end

  local oldx,oldy=nil,nil
  for segment=0,440 do
    local x=x0+pw*segment/440
    local gain=math.max(0,math.min(1,env_gain_at(x)))
    local y=ybot-h*gain
    if oldx then
      line(oldx,oldy,x,y,.98,.68,.21,1)
      line(x,y,x,ybot,.29,.57,.49,.19)
    end
    oldx,oldy=x,y
  end
  -- Keep exact control points and zero-time vertical transitions visible.
  if attack_ms<=0 then line(x0,ybot,x0,ybot-h,.97,.67,.20,1) end
  if decay_ms<=0 then line(xx_at,ybot-h,xx_dc,ybot-sustain*h,.97,.67,.20,1) end
  if release_ms<=0 then line(xx_rs,ybot-sustain*h,xx_rs,ybot,.97,.67,.20,1) end
  circ(xx_at,ybot-h,9,.98,.73,.27,1)
  circ(xx_dc,ybot-sustain*h,9,.98,.73,.27,1)
  circ(xx_rs,ybot-sustain*h,9,.99,.79,.33,1)
  circ(xx_ed,ybot,9,.98,.73,.27,1)
  txt(78,472,'STAGE-SCALE VIEW  /  TIME IS NOT THE SOURCE WAVEFORM AXIS',11,.91,.71,.40)
  txt(84,637,'0',11,.55,.6,.6)
  txt(147,637,'ATTACK',11,.53,.60,.61)
  txt(421,637,'DECAY',11,.53,.60,.61)
  txt(684,637,'SUSTAIN / NOTE OFF',11,.53,.60,.61)
  txt(865,637,'RELEASE',11,.53,.60,.61)
  local xs={190,372,554,736,920}
  local labels={'ATTACK','DECAY','SUSTAIN','RELEASE','VOLUME'}
  local texts={fmt_adsr(val(1)),fmt_adsr(val(2)),fmt(val(3),'%.1f dB'),fmt_adsr(val(4)),fmt(val(5),'%+.1f dB')}
  for i=1,5 do
    local v=val(i);local mn,mxv=knobrange[i][1],knobrange[i][2]
    local norm=(i==1 or i==2 or i==4) and ms_to_norm(v) or math.max(0,math.min(1,(v-mn)/(mxv-mn)))
    knob(xs[i],735,35,labels[i],texts[i],norm,i==5)
  end
  panel(44,837,990,65)
  txt(65,856,'MOONAR / DSP',14,.89,.90,.90)
  txt(65,879,(status or ''):sub(1,29),10,.58,.76,.73)
  miniknob(335,869,val(15)/100,'NOISE',fmt(val(15),'%.0f%%'))
  miniknob(471,869,val(14)/100,'MOTION',fmt(val(14),'%.0f%%'))
  miniknob(610,869,val(9)/1000,'GLIDE',fmt(val(9),'%.0f ms'))
  button(755,854,112,34,'LEGATO',val(13)>0)
  button(886,854,74,34,'MONO',val(6)<=1)
  button(960,854,72,34,'POLY',val(6)>1)
end

local function hit_knob(x,y)
  for k=1,#knobparam do
    local px,py=knobx[k],knoby[k]
    if (x-px)^2+(y-py)^2 < knob_radius[k]^2 then return k end
  end
end
local function hit_numeric(x,y)
  -- Large ADSR/value readout rectangles, pitch readout, and footer readouts.
  for k=1,5 do
    if x>=knobx[k]-49 and x<=knobx[k]+49 and y>=790 and y<=822 then return knobparam[k] end
  end
  if x>=277 and x<=375 and y>=393 and y<=425 then return 8 end
  for k=7,9 do
    if x>=knobx[k]+20 and x<=knobx[k]+122 and y>=knoby[k]-2 and y<=knoby[k]+23 then return knobparam[k] end
  end
end
local function handle_mouse()
  mx=(gfx.mouse_x-origin_x)/render_scale
  my=(gfx.mouse_y-origin_y)/render_scale
  local held=(gfx.mouse_cap & 1)~=0
  local down=held and not did_mouse_down
  local rightheld=(gfx.mouse_cap & 2)~=0
  local rightdown=rightheld and not did_right_mouse_down
  did_right_mouse_down=rightheld
  if gfx.mouse_wheel~=0 and mx>=69 and mx<=276 and my>=210 and my<=336 then
    local entries=filtered_presets()
    preset_scroll=clamp(preset_scroll-(gfx.mouse_wheel>0 and 1 or -1),0,math.max(0,#entries-4))
    gfx.mouse_wheel=0
  end
  -- Right click a knob: exact numeric input (also supported by clicking readout).
  if rightdown then
    local k=hit_knob(mx,my)
    if k then edit_numeric_param(knobparam[k]);return end
  end
  if down then
    local editable=hit_numeric(mx,my)
    if editable then
      did_mouse_down=held;drag=0
      edit_numeric_param(editable)
      return
    end
  end
  if gfx.mouse_wheel~=0 then
    for k=1,#knobparam do
      local x,y=knobx[k],knoby[k]
      if (mx-x)^2+(my-y)^2<knob_radius[k]^2 then
        local par=knobparam[k]
        local range=knobrange[k]
        local fraction=(gfx.mouse_wheel/120)*.015
        local next_value
        if par==1 or par==2 or par==4 then
          next_value=norm_to_ms(ms_to_norm(val(par))+fraction)
        else
          next_value=math.max(range[1],math.min(range[2],val(par)+(range[2]-range[1])*fraction))
        end
        pset(par,next_value)
        if par==9 and next_value>0 and val(6)>1 then pset(6,1);status='GLIDE: MONO activated' end
        gfx.mouse_wheel=0
        break
      end
    end
  end
  if source and gfx.mouse_wheel~=0 and mx>=301 and mx<=1017 and my>=147 and my<=348 then
    local sx=norm_to_wave_x(val(17)/10000)
    local ex=norm_to_wave_x(val(18)/10000)
    local fx0=norm_to_wave_x(val(17)/10000+(val(19)/1000*SR)/source.frames)
    local fx1=norm_to_wave_x(val(18)/10000-(val(20)/1000*SR)/source.frames)
    if my<187 and math.abs(mx-fx0)<18 then
      pset(21,math.max(-1.5,math.min(1.5,val(21)+0.1*(gfx.mouse_wheel>0 and 1 or -1))))
    elseif my>307 and math.abs(mx-fx1)<18 then
      pset(22,math.max(-1.5,math.min(1.5,val(22)+0.1*(gfx.mouse_wheel>0 and 1 or -1))))
    elseif (gfx.mouse_cap & 8)~=0 then
      pan_view(gfx.mouse_wheel)
    else
      zoom_at(mx,gfx.mouse_wheel)
    end
    gfx.mouse_wheel=0
  end
  if down then
    drag=0;drag_initial_y=my
    if mx>=69 and mx<=276 and my>=181 and my<=209 then
      preset_search_focus=true;did_mouse_down=held;return
    else
      preset_search_focus=false
    end
    if mx>=69 and mx<=276 and my>=215 and my<=335 then
      local row=math.floor((my-215)/30)+1
      local e=filtered_presets()[preset_scroll+row]
      if e then
        if mx>=247 then toggle_preset_favorite(e)
        else load_sound_preset(e) end
      end
      did_mouse_down=held;return
    end
    if mx>=70 and mx<=271 and my>=382 and my<=407 then
      audition_current()
      did_mouse_down=held;return
    end
    if my>=340 and my<=374 then
      if mx>=69 and mx<=135 then save_current_preset()
      elseif mx>=140 and mx<=204 then rename_sound_preset()
      elseif mx>=209 and mx<=276 then delete_sound_preset() end
      did_mouse_down=held;return
    end
    if source and mx>=301 and mx<=1017 and my>=147 and my<=348 then
      if mx>=923 and mx<=1005 and my>=153 and my<=181 then
        set_view(0,1)
        status='Waveform zoom reset to 1x'
      else
        local x0=norm_to_wave_x(val(17)/10000)
        local x1=norm_to_wave_x(val(18)/10000)
        local fi=norm_to_wave_x(val(17)/10000+val(19)/1000*SR/source.frames)
        local fo=norm_to_wave_x(val(18)/10000-val(20)/1000*SR/source.frames)
        if my<188 and math.abs(mx-fi)<18 then drag=22
        elseif my>307 and math.abs(mx-fo)<18 then drag=23
        elseif math.abs(mx-x0)<15 then drag=20
        elseif math.abs(mx-x1)<15 then drag=21
        elseif mx>x0+12 and mx<x1-12 then drag=24 end
        trim_drag_start_norm=wave_x_to_norm(mx)
        trim_drag_start_pct=val(17)
        trim_drag_end_pct=val(18)
      end
    end
    if drag==0 and _G.env_points and my>=449 and my<=627 then
      local p=_G.env_points
      local sustain_y=p[6]-(10^(val(3)/20))*p[7]
      if math.abs(mx-p[4])<16 and math.abs(my-sustain_y)<26 then drag=33
      elseif math.abs(mx-p[2])<13 then drag=30
      elseif math.abs(mx-p[3])<13 then drag=31
      elseif math.abs(mx-p[5])<13 then drag=32 end
    end
    if drag==0 then
      local k=hit_knob(mx,my)
      if k then
        drag=k
        drag_initial_val=val(knobparam[k])
      end
    end
    if drag==0 then
      if mx>=432 and mx<=556 and my>=51 and my<=91 then
        local updater=reaper.GetResourcePath()..SEP..'Scripts'..SEP..'MOONAR_UPDATE.lua'
        if not read_all(updater) then
          status='Updater not found. Run MOONAR_GITHUB_SETUP once.'
          reaper.ShowMessageBox('MOONAR_UPDATE.lua is not installed. Run the one-time GitHub setup first.', 'MOONAR UPDATE', 0)
        else
          local cmd=reaper.AddRemoveReaScript(true,0,updater,true)
          if cmd and cmd>0 then
            status='Checking GitHub for updates...'
            reaper.defer(function() reaper.Main_OnCommand(cmd,0) end)
          else
            status='Could not register updater ReaScript.'
          end
        end
      elseif mx>890 and mx<1040 and my>47 and my<99 then
        local ok,path=reaper.GetUserFileNameForRead('','Choose an audio file','')
        if ok and path and path~='' then import_path(path) end
      elseif mx>755 and mx<867 and my>854 and my<889 then pset(13,1-val(13))
      elseif mx>886 and mx<960 and my>854 and my<889 then pset(6,1)
      elseif mx>960 and mx<1032 and my>854 and my<889 then pset(6,4)
      elseif mx>564 and mx<714 and my>357 and my<397 then
        pset(23,1-val(23))
        status=val(23)<0.5 and 'Natural PCM loop sustain' or 'Spectral sustain (optional)'
      elseif mx>723 and mx<870 and my>357 and my<397 then pset(10,1-val(10))
      elseif mx>878 and mx<1022 and my>357 and my<397 then
        pset(20,val(20)>=300 and 0 or math.min(300,val(20)+25))
        status=string.format('Loop crossfade: %.0f ms',val(20))
      elseif mx>600 and mx<866 and my>47 and my<95 then
        step_sound_preset(mx<662 and -1 or 1)
      end
    end
  end
  if held and drag>0 then
    if drag<=9 then
      local p=knobparam[drag]
      local range=knobrange[drag]
      local next_value
      if p==1 or p==2 or p==4 then
        -- Log response gives fine resolution near zero and remains continuous to 32s.
        next_value=norm_to_ms(ms_to_norm(drag_initial_val)+(drag_initial_y-my)/280)
      else
        local change=(drag_initial_y-my)/180*(range[2]-range[1])
        next_value=math.max(range[1],math.min(range[2],drag_initial_val+change))
      end
      pset(p,next_value)
      if p==9 and next_value>0 and val(6)>1 then
        pset(6,1);status='GLIDE: MONO activated'
      end
    elseif source and (drag>=20 and drag<=24) then
      local norm=wave_x_to_norm(mx)*10000
      local minimum_pct=math.max(20,math.ceil(4096/source.frames*10000))
      if drag==20 then pset(17,math.max(0,math.min(val(18)-minimum_pct,norm)))
      elseif drag==21 then pset(18,math.min(10000,math.max(val(17)+minimum_pct,norm)))
      elseif drag==22 then pset(19,math.max(0,math.min(300,(norm-val(17))/10000*source.frames/SR*1000)))
      elseif drag==23 then pset(20,math.max(0,math.min(300,(val(18)-norm)/10000*source.frames/SR*1000)))
      elseif drag==24 then
        -- Keep absolute selected length and both fades intact.
        local len=trim_drag_end_pct-trim_drag_start_pct
        local delta=(wave_x_to_norm(mx)-trim_drag_start_norm)*10000
        local moved=math.max(0,math.min(10000-len,trim_drag_start_pct+delta))
        if moved >= trim_drag_start_pct then
          pset(18,moved+len);pset(17,moved)
        else
          pset(17,moved);pset(18,moved+len)
        end
      end
    elseif _G.env_points then
      local p=_G.env_points
      local xx_at,xx_dc,xx_rs=p[2],p[3],p[4]
      local width=p[8]
      local level=math.max(10^(-48/20),math.min(1,(p[6]-my)/p[7]))
      local sustain_db=math.max(-48,math.min(0,20*math.log(level,10)))
      if drag==30 then
        -- Invert the same nonlinear stage scale used by the graph.
        local progress=math.max(0,math.min(1,(mx-p[1])/math.max(1,width*0.17)))
        pset(1,norm_to_ms(progress))
      elseif drag==31 then
        local end_of_decay=p[1]+width*0.70
        local progress=math.max(0,math.min(1,(mx-xx_at)/math.max(1,end_of_decay-xx_at)))
        pset(2,norm_to_ms(progress))
        -- Decay node controls both time (x) and sustain amplitude (y).
        pset(3,sustain_db)
      elseif drag==32 then
        local progress=math.max(0,math.min(1,(mx-xx_rs)/math.max(1,width*0.23)))
        pset(4,norm_to_ms(progress))
      elseif drag==33 then
        -- Note-Off/Sustain handle changes only the level, never the timing.
        pset(3,sustain_db)
      end
    end
  end
  if not held and did_mouse_down and (drag==20 or drag==21 or drag==24) then update_model_after_trim() end
  if not held then drag=0 end
  did_mouse_down=held
end
-- Once MOONAR LIVE is registered in Actions, replacement of this same Lua
-- file automatically restarts only its GUI. The REAPER process never quits.
local _,running_script,action_section,action_command=reaper.get_action_context()
local startup_source=running_script and read_all(running_script) or nil
local live_namespace='MOONAR_RESYNTH_LIVE'
local live_token=tostring({}):gsub('table: ','')
if reaper.SetExtState then reaper.SetExtState(live_namespace,'CURRENT_UI',live_token,false) end
local live_frame_count=0
local function restart_live_ui()
  -- Automatic action restart is optional; if unavailable we close gracefully.
  stop_audition()
  if gfx.quit then gfx.quit() end
  if action_command and action_command>0 and action_section==0 and reaper.Main_OnCommand then
    reaper.defer(function() reaper.Main_OnCommand(action_command,0) end)
  end
end
local function frame()
  live_frame_count=live_frame_count+1
  if audition_note then
    if track and reaper.ValidatePtr2(0,track,'MediaTrack*') then
      local left=math.abs(reaper.Track_GetPeakInfo(track,0) or 0)
      local right=math.abs(reaper.Track_GetPeakInfo(track,1) or 0)
      audition_peak=math.max(audition_peak,left,right)
    end
    if not audition_reported and reaper.time_precise()>=audition_until then
      audition_reported=true
      status=audition_peak>0.0001
        and 'HOLD ACTIVE: sound continues until RELEASE NOTE is clicked.'
        or 'HOLD ACTIVE: no track meter activity; check FX/MIDI routing.'
    end
  end
  if reaper.GetExtState and reaper.GetExtState(live_namespace,'CURRENT_UI')~=live_token then
    -- A newer LIVE window replaced this one; never leave its held MIDI note stuck.
    stop_audition()
    gfx.quit();return
  end
  -- Poll once every ~90 GUI frames: existing UI survives ordinary edits,
  -- but reloading the registered action after the file was replaced is automatic.
  if live_frame_count%90==0 and startup_source and running_script then
    local disk_source=read_all(running_script)
    if disk_source and disk_source~=startup_source then
      restart_live_ui();return
    end
  end
  local char=gfx.getchar()
  if char<0 then stop_audition(); gfx.quit(); return end
  if preset_search_focus then
    if char==27 or char==13 then preset_search_focus=false
    elseif char==8 then
      if utf8 and utf8.offset then
        local p=utf8.offset(preset_search,-1)
        if p then preset_search=preset_search:sub(1,p-1) end
      else preset_search=preset_search:sub(1,-2) end
      preset_scroll=0
    elseif char>=32 and char<=0x10FFFF and #preset_search<75 then
      local ok,c=pcall(utf8.char,char)
      if ok then preset_search=preset_search..c;preset_scroll=0 end
    end
  elseif char==27 then stop_audition(); gfx.quit(); return end
  local ok,fn=gfx.getdropfile(0)
  if ok and ok>0 and fn and fn~='' then
    gfx.getdropfile(-1)
    import_path(fn)
  end
  handle_mouse()
  draw()
  gfx.update()
  reaper.defer(frame)
end

-- Capture the source item BEFORE creating/selecting a new instrument track.
scan_preset_bank()
local selected=reaper.GetSelectedMediaItem(0,0)
local user_selected_track=reaper.GetSelectedTrack(0,0)
if selected and user_selected_track and reaper.GetMediaItemTrack(selected)~=user_selected_track then
  selected=nil
end
local ok,err=prepare_track()
if not ok then reaper.ShowMessageBox(err,'MOONAR Resynth',0); return end
-- One-time, user-requested safety migration: turn off the previously hidden
-- 17%% noise on this instrument. Future manual Noise changes remain intact.
local _,noise_migrated=reaper.GetSetMediaTrackInfo_String(track,'P_EXT:MOONAR_NOISE_051_MIGRATED','',false)
if noise_migrated~='1' then
  pset(15,0)
  reaper.GetSetMediaTrackInfo_String(track,'P_EXT:MOONAR_NOISE_051_MIGRATED','1',true)
end
recover_audio_route()
-- Import selected audio immediately if present, otherwise accept drag & drop.
if selected then
  local ok_import,audio,reading_error=pcall(take_audio,selected)
  if ok_import and audio then
    audio.total_length=audio.length
    import_audio(audio,'SELECTED REAPER ITEM')
  else status='Select audio or drop a file: '..tostring(ok_import and reading_error or audio) end
elseif track and reaper.ValidatePtr2(0,track,'MediaTrack*') then
  local _,saved_path=reaper.GetSetMediaTrackInfo_String(track,'P_EXT:MOONAR_SAMPLE_PATH','',false)
  if saved_path and saved_path~='' then
    local old_start,old_end=val(17),val(18)
    import_path(saved_path)
    if source then
      pset(17,old_start);pset(18,old_end)
      update_model_after_trim()
    end
  end
end
-- A REAPER JSFX can load as an instrument without a PCM source. The 0.7.1
-- migrator disabled old FX but did not transfer its sample memory. Only perform
-- this one-time restoration with explicit confirmation to avoid overwriting
-- an unsaved custom sample in a project. Preset data itself is never modified.
if not source then
  local demo=nil
  for _,e in ipairs(preset_entries) do
    if e.id=='DEMO_BASS_C2' then demo=e; break end
  end
  if demo then
    local reply=reaper.ShowMessageBox(
      'MOONAR has no source loaded in its controller. This can cause silence after 0.7 upgrade.\n\n'..
      'Load factory Demo Bass C2 into the new engine for a sound check?\n'..
      'This replaces the CURRENT sound in the new FX, but never deletes any presets.\n\n'..
      'Yes = load sound; No = leave FX sound unchanged.',
      'MOONAR 0.7.2 | Restore sound',4)
    if reply==6 then
      load_sound_preset(demo)
      if source then status='Demo Bass loaded. Click TEST NOTE or play MIDI.' end
    else
      status='No sample in UI. Select a saved preset or LOAD SAMPLE.'
    end
  else
    status='No audio in UI and no factory Bass preset. LOAD SAMPLE.'
  end
end
local _,bound_track_name=reaper.GetSetMediaTrackInfo_String(track,'P_NAME','',false)
local window_label=(bound_track_name and bound_track_name~='' and bound_track_name or 'Selected track')
gfx.init('MOONAR RESYNTH 0.7.9 | '..window_label,1080,930,0,110,70)
reaper.defer(frame)


