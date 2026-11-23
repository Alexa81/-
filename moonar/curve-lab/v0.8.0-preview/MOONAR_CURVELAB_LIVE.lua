

-- MOONAR RESYNTH 0.7.14 / AUTO EXTENDED PCM WAVEFORM + SERUM CURVE HANDLES + ONE FX PER TRACK + FULL UPDATE AND REPAIR + JSFX COMPILER FIX + SELECTED TRACK + MIDI ROUTING + GITHUB UPDATE BUTTON + RECOVER SILENCE + PREVIEW MIDI + ON-DISK PRESET BANK
-- Companion ReaScript UI: real file drag/drop and trim controls; JSFX audio engine.
-- This is an original instrument, unrelated to Tim Hox's proprietary source code.
local FX_NAME='MOONAR Curve Lab 0.8.0 Preview'
local JSFX_FILENAME='MOONAR_CurveLab_080.jsfx'
local ENGINE_COMPATIBLE={'MOONAR_LAB_BUILD=0.8.0-preview'}
local BUS='MOONAR_CURVELAB_BRIDGE_08'
local SR, MAX_FRAMES, NFFT, MAX_PEAKS=44100, 1323000, 16384, 64
local SLOT_STRIDE, PI=3200000,math.pi
local SEP=package.config:sub(1,1)

local function read_all(path)
  local f=io.open(path,'rb'); if not f then return nil end
  local d=f:read('*a'); f:close(); return d
end
local BUNDLED_UPDATER=[======[
-- MOONAR UPDATE 1.5 / WHOLE PLUGIN REPAIR + NO DUPLICATE FX INSTANCES
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
  -- IMPORTANT: The updater must NEVER add JSFX to the selected track.
  -- The GUI owns migration and imports the PCM first. Adding here used to
  -- leave two MOONAR synthesizers on the same track (sometimes both audible).
  if not reaper.GetSelectedTrack or not reaper.TrackFX_GetCount then
    return false,'Track API unavailable'
  end
  local track=reaper.GetSelectedTrack(0,0)
  if not track then return false,'No track selected' end
  local engine_source=read(effects..SEP..engine_name) or ''
  local engine_desc=engine_source:match('desc:([^\r\n]+)')
  if not engine_desc then return false,'JSFX file not yet available' end
  local modern,legacy=0,0
  for i=0,reaper.TrackFX_GetCount(track)-1 do
    local ok,name=reaper.TrackFX_GetFXName(track,i,'')
    if ok and name and name:find('MOONAR Curve Lab',1,true) then
      if name:find(engine_desc,1,true) then modern=modern+1
      else legacy=legacy+1 end
    end
  end
  if legacy>0 or modern>1 then
    return true,'MOONAR LIVE will migrate to a single engine after loading sample'
  end
  if modern==1 then return false,'Only the current MOONAR engine is attached' end
  return false,'No MOONAR engine on selected track; launch MOONAR LIVE'
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

desc:MOONAR Curve Lab 0.8.0 Preview
tags:instrument sampler resynthesis
options:gmem=MOONAR_CURVELAB_BRIDGE_08 maxmem=3100000
in_pin:none
out_pin:Left
out_pin:Right

// MOONAR_LAB_BUILD=0.8.0-preview
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
slider24:0<-1,1,0.01>Attack Curve
slider25:0<-1,1,0.01>Decay Curve
slider26:0<-1,1,0.01>Release Curve
// Original 26 parameters above remain at their original indices.
slider27:0<0,1,1{Off,On}>Moog-style Filter
slider28:1200<20,20000,1>Filter Cutoff (Hz)
slider29:0.35<0,0.95,0.01>Filter Resonance
slider30:3<0,18,0.1>Filter Drive (dB)
slider31:2<-6,6,0.01>Filter Envelope Depth (octaves)
slider32:8<0,32000,1>Filter Attack (ms)
slider33:180<0,32000,1>Filter Decay (ms)
slider34:0.50<0,1,0.01>Filter Sustain (level)
slider35:760<0,32000,1>Filter Release (ms)
slider36:0<-1,1,0.01>Filter Attack Curve
slider37:0<-1,1,0.01>Filter Decay Curve
slider38:0<-1,1,0.01>Filter Release Curve
slider39:0<-24,24,1>Transpose (semitones)

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
  stride=40;
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
    off[0]=0;off[5]=0;off[21]=0;
    off[15]=0;off[16]=0;off[17]=0;off[18]=1;off[19]=1;off[20]=0;
    z=24;loop(12,off[z]=0;z+=1;);
    i+=1;
  );
);

@slider
// The SAME normalised power curve is used by audio and both GUIs:
 // curve = -1 => ease-in, 0 => linear, +1 => ease-out.
 // These additional mid-segment handles never add new envelope stages.
attack_samples=max(1,slider1*srate/1000);
decay_samples=max(1,slider2*srate/1000);
release_samples=max(1,slider4*srate/1000);
attack_shape=exp(-3*slider24);
decay_shape=exp(-3*slider25);
release_shape=exp(-3*slider26);
sus_level=10^(slider3/20);
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
filter_attack_samples=max(1,slider32*srate/1000);
filter_decay_samples=max(1,slider33*srate/1000);
filter_release_samples=max(1,slider35*srate/1000);
filter_attack_shape=exp(-3*slider36);
filter_decay_shape=exp(-3*slider37);
filter_release_shape=exp(-3*slider38);
filter_drive=10^(slider30/20);
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
      target_ratio=2^((nn-slider7+slider8+slider39+tune)/12);
      // MONO portamento: reuse the previous voice pitch even when LEGATO
      // is off. LEGATO only controls whether the amplitude envelope restarts.
      mono_active=slider6<=1 && vo[0]>0;
      legato_reuse=mono_active && slider13>0 && vo[10]>0 && vo[0]!=4;
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
          vo[5]=0;vo[21]=0;
          vo[8]=0;
          vo[11]=0;vo[12]=0;vo[13]=0;vo[14]=0;
          vo[15]=0;vo[16]=0;vo[17]=0;vo[18]=1;vo[19]=1;vo[20]=0;
           vo[24]=0;vo[25]=1;vo[26]=0;vo[27]=0;
           zz=28;loop(8,vo[zz]=0;zz+=1;);
        );
        // vo[6] intentionally retains previous pitch for GLIDE.
      ) : (
        vo[0]=1;
        vo[1]=nn;
        vo[2]=vel/127;
        vo[3]=clip_start;
        vo[4]=0;
        vo[5]=0;vo[21]=0;
        vo[6]=target_ratio;
        vo[7]=target_ratio;
        vo[8]=0;
        vo[9]=0;
        vo[10]=1;
        vo[11]=0;vo[12]=0;vo[13]=0;vo[14]=0;
        vo[15]=0;vo[16]=0;vo[17]=0;vo[18]=1;vo[19]=1;vo[20]=0;
           vo[24]=0;vo[25]=1;vo[26]=0;vo[27]=0;
           zz=28;loop(8,vo[zz]=0;zz+=1;);
      );
    );
  );
  st==128 ? (
    v=0;
    loop(4,
      vo=voice_mem+v*stride;
      vo[0]>0 && vo[1]==nn ? (
        vo[10]=0;
        pedal_down ? vo[9]=1 : (vo[0]=4;vo[5]=0;vo[21]=vo[4];vo[25]=4;vo[26]=0;vo[27]=vo[24];);
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
        vo[0]>0 && vo[9]>0 ? (vo[0]=4;vo[5]=0;vo[21]=vo[4];vo[25]=4;vo[26]=0;vo[27]=vo[24];vo[9]=0;);
        v+=1;
      );
    );
  );
  st==176 && (nn==120 || nn==123) ? (
    v=0;
    loop(4,
      vo=voice_mem+v*stride;
      vo[0]>0 ? (vo[0]=4;vo[5]=0;vo[21]=vo[4];vo[25]=4;vo[26]=0;vo[27]=vo[24];vo[9]=0;);
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
      // Serum AHDSR: A -> H -> D -> S (indefinite while key held) -> R.
      // HOLD state 5 uses vo[5] as an independent sample counter, so it does
      // not reset the PCM playhead or interrupt the infinite Natural loop.
      // Four genuine Serum-style ADSR stages. Every curve handle modifies
      // the corresponding DSP slope, not just the display.
      // vo[5] counts samples in this stage; vo[21] captures Note Off level.
      vo[0]==1 ? (
        vo[5]+=1;
        env_t=min(1,vo[5]/attack_samples);
        vo[4]=slider1<=0 ? 1 : env_t^attack_shape;
        env_t>=1 ? (vo[0]=2;vo[5]=0;);
      ) : vo[0]==2 ? (
        vo[5]+=1;
        env_t=min(1,vo[5]/decay_samples);
        vo[4]=slider2<=0 ? sus_level : 1-(1-sus_level)*env_t^decay_shape;
        env_t>=1 ? (vo[0]=3;vo[5]=0;);
      ) : vo[0]==3 ? (
        vo[4]=sus_level;
      ) : vo[0]==4 ? (
        vo[5]+=1;
        env_t=min(1,vo[5]/release_samples);
        vo[4]=slider4<=0 ? 0 : vo[21]*(1-env_t^release_shape);
        env_t>=1 || vo[4]<=0.000001 ? (vo[0]=0;vo[4]=0;);
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
      // Dedicated per-note filter envelope, independent from AMP ADSR.
      slider27>0 ? (
        vo[25]==1 ? (
          vo[26]+=1;
          ft=min(1,vo[26]/filter_attack_samples);
          vo[24]=slider32<=0 ? 1 : ft^filter_attack_shape;
          ft>=1 ? (vo[25]=2;vo[26]=0;);
        ) : vo[25]==2 ? (
          vo[26]+=1;
          ft=min(1,vo[26]/filter_decay_samples);
          vo[24]=slider33<=0 ? slider34 : 1-(1-slider34)*ft^filter_decay_shape;
          ft>=1 ? (vo[25]=3;vo[26]=0;);
        ) : vo[25]==3 ? (
          vo[24]=slider34;
        ) : vo[25]==4 ? (
          vo[26]+=1;
          ft=min(1,vo[26]/filter_release_samples);
          vo[24]=slider35<=0 ? 0 : vo[27]*(1-ft^filter_release_shape);
          ft>=1 ? (vo[25]=0;vo[24]=0;);
        );
      );
      mix_l=a*dry_l+blend*syn_l;
      mix_r=a*dry_r+blend*syn_r;
      slider27>0 ? (
        // Stable four-stage resonant lowpass approximation with nonlinear
        // input/feedback; inspired by ladder topology, not a hardware clone.
        fc=max(20,min(srate*0.45,slider28*2^(slider31*vo[24])));
        fg=1-exp(-2*$pi*fc/srate);
        fb=slider29*3.8;
        inl=tanh((mix_l-fb*vo[31])*filter_drive);
        inr=tanh((mix_r-fb*vo[35])*filter_drive);
        vo[28]+=fg*(inl-vo[28]);
        vo[29]+=fg*(vo[28]-vo[29]);
        vo[30]+=fg*(vo[29]-vo[30]);
        vo[31]+=fg*(vo[30]-vo[31]);
        vo[32]+=fg*(inr-vo[32]);
        vo[33]+=fg*(vo[32]-vo[33]);
        vo[34]+=fg*(vo[33]-vo[34]);
        vo[35]+=fg*(vo[34]-vo[35]);
        mix_l=vo[31]/filter_drive;
        mix_r=vo[35]/filter_drive;
      );
      vgain=vo[2]*vo[4]*vo[18];
      out_l+=mix_l*vgain;
      out_r+=mix_r*vgain;
    );
    v+=1;
  );
);
spl0=out_l*output_gain;
spl1=out_r*output_gain;
block_sample+=1;


@gfx 1080 930
// MOONAR Curve Lab insert GUI. Controller runs separately/headlessly via ReaScript.
// The 26 original DSP controls and their automation indices are unchanged.
function labfill(x,y,w,h,r,g,b,alpha) (
  gfx_set(r,g,b,alpha);
  gfx_rect(lx+x*ls,ly+y*ls,w*ls,h*ls);
);
function labline(x,y,x2,y2,r,g,b,alpha) (
  gfx_set(r,g,b,alpha);
  gfx_line(lx+x*ls,ly+y*ls,lx+x2*ls,ly+y2*ls,1);
);
function labcirc(x,y,rad,r,g,b) (
  gfx_set(r,g,b,1);
  gfx_circle(lx+x*ls,ly+y*ls,rad*ls,1,1);
);
function labtext(x,y,str,sz,r,g,b) (
  gfx_setfont(1,"Arial",max(9,floor(sz*ls)));
  gfx_set(r,g,b,1);
  gfx_x=lx+x*ls;
  gfx_y=ly+y*ls;
  gfx_drawstr(str);
);
function labpanel(x,y,w,h) (
  labfill(x,y,w,h,0.07,0.095,0.14,1);
  labfill(x,y,w,2,0.25,0.18,0.36,1);
);
function labbutton(x,y,w,h,str,on) (
  labfill(x,y,w,h,on?0.34:0.11,on?0.16:0.13,on?0.52:0.20,1);
  labtext(x+12,y+7,str,15,0.94,0.88,1);
);
function labknob(x,y,rad,norm,title,value,green) (
  norm=max(0,min(1,norm));
  labcirc(x+1,y+2,rad+3,0.23,0.27,0.37);
  labcirc(x,y,rad,0.065,0.08,0.13);
  k=0;loop(32,
    ka=2.35+k*4.69/31;
    k<=norm*31 ? labline(x+cos(ka)*(rad+2),y+sin(ka)*(rad+2),x+cos(ka)*(rad+6),y+sin(ka)*(rad+6),green?0.35:0.80,green?0.99:0.42,green?0.70:1,1);
    k+=1;
  );
  ka=2.35+norm*4.69;
  labline(x,y,x+cos(ka)*(rad-8),y+sin(ka)*(rad-8),0.98,0.95,1,1);
  labtext(x-rad-7,y-rad-35,title,13,0.88,0.88,0.96);
  labtext(x-rad-8,y+rad+13,value,13,0.85,0.88,1);
);
function labenv(x,y,w,h,aa,dd,ss,rr,ca,cd,cr,green) (
  // Sustain display has a deliberately visible hold segment.
  evsecs=max(1.0,(aa+dd+rr)/1000+0.65);
  evscale=w/evsecs;
  evax=x+aa/1000*evscale;
  evdx=evax+dd/1000*evscale;
  evrx=evdx+max(0.20,0.45*evsecs-(aa+dd)/1000*0.25)*evscale;
  evrx=min(x+w-rr/1000*evscale,evrx);
  evend=min(x+w,evrx+rr/1000*evscale);
  evpb=y+h;
  p=0;prevx=x;prevy=evpb;
  loop(180,
    xx=x+p*w/179;
    xx<evax ? (t=(xx-x)/max(0.00001,evax-x);value=t^exp(-3*ca);) :
    xx<evdx ? (t=(xx-evax)/max(0.00001,evdx-evax);value=1-(1-ss)*t^exp(-3*cd);) :
    xx<evrx ? value=ss :
    xx<evend ? (t=(xx-evrx)/max(0.00001,evend-evrx);value=ss*(1-t^exp(-3*cr));)
    : value=0;
    yy=evpb-h*max(0,min(1,value));
    p>0 ? labline(prevx,prevy,xx,yy,green?0.28:0.79,green?0.99:0.44,green?0.68:1,1);
    prevx=xx;prevy=yy;
    p+=1;
  );
  labcirc(evax,y,6,green?0.32:0.88,green?1:0.51,green?0.68:1);
  labcirc(evdx,evpb-ss*h,6,green?0.32:0.88,green?1:0.51,green?0.68:1);
  labcirc(evrx,evpb-ss*h,6,green?0.32:0.88,green?1:0.51,green?0.68:1);
  labcirc(evend,evpb,6,green?0.32:0.88,green?1:0.51,green?0.68:1);
  // Bend points match the DSP power curve exponent exactly.
  evax>x+30 ? labcirc((x+evax)*0.5,evpb-h*(0.5^exp(-3*ca)),4,0.63,0.84,0.99);
  evdx-evax>30 && ss<0.98 ? labcirc((evax+evdx)*0.5,evpb-h*(1-(1-ss)*0.5^exp(-3*cd)),4,0.63,0.84,0.99);
  evend-evrx>30 && ss>0.02 ? labcirc((evrx+evend)*0.5,evpb-h*ss*(1-0.5^exp(-3*cr)),4,0.63,0.84,0.99);
);
function labcommand(n) (
  gmem[labbase+26]=n;
  gmem[labbase+27]+=1;
);
function labknobdrag(n,x,y,rad) (
  (mx-x)^2+(my-y)^2 < (rad+6)^2 ? active_knob=n;
);

ls=min(gfx_w/1080,gfx_h/930);
ls=max(0.18,ls);
lx=(gfx_w-1080*ls)*0.5;ly=(gfx_h-930*ls)*0.5;
mx=(mouse_x-lx)/ls;my=(mouse_y-ly)/ls;
labbase=(floor(slider11)-1)*3200000;
mb=(mouse_cap&1)!=0;
click=mb&&!lab_oldmb;

labfill(0,0,1080,930,0.025,0.034,0.067,1);
labfill(0,0,1080,80,0.063,0.055,0.10,1);
labtext(28,18,"MOONAR",36,0.77,0.55,1);
labtext(232,32,"CURVE LAB  v0.8.0 PREVIEW",16,0.72,0.72,0.87);
labbutton(496,20,111,43,"SYNTH",labtab==0);
labbutton(615,20,122,43,"PRESETS",labtab==1);
labbutton(745,20,151,43,"ADVANCED",labtab==2);
labbutton(904,20,151,43,"UPDATE",0);

labpanel(24,95,1032,174);
labtext(42,111,"SAMPLE  /  PCM RESYNTH",17,0.92,0.91,0.98);
labbutton(43,161,175,41,"LOAD SAMPLE",0);
has_sample ? (
  sprintf(#sampdesc,"%.2f s   |   %d partials",nframes/max(1,source_sr),npeak);
  labtext(50,212,#sampdesc,12,0.57,0.89,0.80);
) : labtext(50,212,"NO SAMPLE LOADED",12,0.89,0.59,0.64);
labfill(237,136,791,111,0.018,0.026,0.055,1);
has_sample ? (
  i=0;loop(395,
    from=floor((i/395)*max(1,nframes-1));
    vmax=0;
    j=0;loop(5,
      idx=min(nframes-1,from+j*max(1,floor(nframes/395/5)));
      vmax=max(vmax,max(abs(samp_l[idx]),abs(samp_r[idx])));
      j+=1;
    );
    h=max(1,min(42,vmax*85));
    labline(242+i*1.98,191-h,242+i*1.98,191+h,0.68,0.41,0.99,0.87);
    i+=1;
  );
) : labtext(465,181,"LOAD A WAV, AIFF OR FLAC",16,0.54,0.58,0.70);

labtab==0 ? (
  labpanel(24,282,500,505);
  labpanel(538,282,518,505);
  labtext(45,299,"VOLUME  /  AMP ADSR",18,0.89,0.82,1);
  labfill(43,348,462,238,0.024,0.033,0.072,1);
  labenv(57,365,431,203,slider1,slider2,10^(slider3/20),slider4,slider24,slider25,slider26,0);
  sprintf(#a0,"%.0f ms",slider1);
  sprintf(#d0,"%.0f ms",slider2);
  sprintf(#s0,"%.1f dB",slider3);
  sprintf(#r0,"%.0f ms",slider4);
  labknob(104,690,27,log(1+slider1/100)/log(321),"ATTACK",#a0,0);
  labknob(224,690,27,log(1+slider2/100)/log(321),"DECAY",#d0,0);
  labknob(344,690,27,(slider3+48)/48,"SUSTAIN",#s0,0);
  labknob(464,690,27,log(1+slider4/100)/log(321),"RELEASE",#r0,0);

  labtext(557,299,"MOOG-STYLE  /  24 dB LOWPASS",18,0.91,0.83,1);
  labbutton(926,294,101,37,slider27>0?"ON":"OFF",slider27>0);
  sprintf(#cut,"%.0f Hz",slider28);
  sprintf(#res,"%.2f",slider29);
  sprintf(#drv,"%.1f dB",slider30);
  sprintf(#amt,"%+.1f oct",slider31);
  labknob(620,398,35,log(max(20,slider28)/20)/log(1000),"CUTOFF",#cut,0);
  labknob(742,398,28,slider29/0.95,"RESONANCE",#res,0);
  labknob(861,398,28,slider30/18,"DRIVE",#drv,0);
  labknob(986,398,28,(slider31+6)/12,"ENV AMOUNT",#amt,0);

  labtext(562,480,"FILTER ENVELOPE  /  ADSR",15,0.57,1,0.78);
  labfill(556,508,482,162,0.019,0.036,0.065,1);
  labenv(569,519,453,139,slider32,slider33,slider34,slider35,slider36,slider37,slider38,1);
  sprintf(#fa,"%.0f ms",slider32);
  sprintf(#fd,"%.0f ms",slider33);
  sprintf(#fs,"%.2f",slider34);
  sprintf(#fr,"%.0f ms",slider35);
  labknob(620,734,21,log(1+slider32/100)/log(321),"A",#fa,1);
  labknob(745,734,21,log(1+slider33/100)/log(321),"D",#fd,1);
  labknob(870,734,21,slider34,"S",#fs,1);
  labknob(989,734,21,log(1+slider35/100)/log(321),"R",#fr,1);
) : labtab==1 ? (
  labpanel(24,282,1032,505);
  labtext(52,305,"MY SOUND PRESETS",22,0.88,0.81,1);
  labtext(52,359,"Saved sound + source WAV + all DSP settings",15,0.65,0.72,0.85);
  labbutton(52,414,131,41,"PREVIOUS",0);
  labbutton(195,414,100,41,"NEXT",0);
  labbutton(310,414,102,41,"SAVE",0);
  labbutton(425,414,126,41,"RENAME",0);
  labbutton(564,414,119,41,"DELETE",0);
  labtext(52,500,"Current preset:",17,0.73,0.77,0.92);
  // Shared controller status: names are read from its preset bank.
  #pname="";
  j=0;loop(64,
    ch=floor(gmem[labbase+3000000+j]);
    ch>0 && ch<256 ? str_setchar(#pname,j,ch);
    j+=1;
  );
  strlen(#pname)>0 ? labtext(230,500,#pname,18,0.83,1,0.79)
    : labtext(230,500,"(no preset selected)",18,0.58,0.59,0.72);
  sprintf(#pcnt,"%d presets stored",floor(gmem[labbase+3000065]));
  labtext(52,548,#pcnt,14,0.61,0.73,0.82);
  labtext(52,602,"Legacy MOONAR presets are preserved separately.",14,0.70,0.73,0.86);
  labtext(52,633,"Use IMPORT OLD to copy your previous presets into this lab.",14,0.70,0.73,0.86);
  labbutton(52,693,184,43,"IMPORT OLD",0);
) : (
  labpanel(24,282,1032,505);
  labtext(48,301,"ADVANCED / ORIGINAL MOONAR ENGINE",20,0.91,0.85,1);
  labtext(48,350,"All original 26 parameters are retained, in their original order.",16,0.75,0.78,0.90);
  labtext(48,387,"Use REAPER FX parameters / automation lanes for the full settings.",15,0.67,0.75,0.88);
  labtext(48,440,"Sustain engine: Natural PCM Loop / Spectral",15,0.78,0.83,0.93);
  labbutton(47,481,206,41,slider23<0.5?"NATURAL LOOP":"SPECTRAL",1);
  labbutton(267,481,160,41,slider6<=1?"MONO":"POLY",1);
  labbutton(440,481,155,41,slider13>0?"LEGATO ON":"LEGATO OFF",slider13>0);
  labtext(47,574,"NOISE, MOTION, GLIDE and trim remain in the REAPER parameter list.",14,0.67,0.73,0.87);
);
labpanel(24,803,1032,110);
labtext(45,821,"PITCH / TUNING",14,0.82,0.77,0.96);
sprintf(#trans,"%+.0f st",slider39);
sprintf(#fine,"%+.0f ct",slider8*100);
sprintf(#vol,"%+.1f dB",slider5);
labknob(380,864,18,(slider39+24)/48,"TRANSPOSE",#trans,0);
labknob(583,864,18,(slider8+1)/2,"DETUNE",#fine,0);
labknob(944,864,24,(slider5+36)/48,"OUTPUT",#vol,0);
labtext(45,863,slider23<0.5?"NATURAL PCM":"SPECTRAL",15,0.75,0.88,0.86);
labtext(45,887,slider6<=1?"MONO":"POLY",13,0.68,0.73,0.85);
gmem[labbase+28]>0 ? labtext(721,828,"CONTROLLER CONNECTED",12,0.50,0.89,0.68)
  : labtext(721,828,"RUN LAB LUA CONTROLLER",12,0.94,0.66,0.47);

// Keep click behavior tied to visible controls and actual slider indices.
click ? (
  active_knob=0;mouse_start_y=my;
  labtab==0 ? (
    labknobdrag(1,104,690,27);
    labknobdrag(2,224,690,27);
    labknobdrag(3,344,690,27);
    labknobdrag(4,464,690,27);
    labknobdrag(28,620,398,35);
    labknobdrag(29,742,398,28);
    labknobdrag(30,861,398,28);
    labknobdrag(31,986,398,28);
    labknobdrag(32,620,734,21);
    labknobdrag(33,745,734,21);
    labknobdrag(34,870,734,21);
    labknobdrag(35,989,734,21);
    mx>926 && mx<1027 && my>294 && my<331 ? (slider27=1-slider27;sliderchange(2^26);slider_automate(2^26););
    // Envelope stages and curve bend handles, editable with the mouse.
    my>350 && my<588 && mx>45 && mx<510 ? (
      atx=57+431*(slider1/1000)/max(1,(slider1+slider2+slider4)/1000+0.65);
      ddx=atx+431*(slider2/1000)/max(1,(slider1+slider2+slider4)/1000+0.65);
      abs(mx-atx)<15 ? active_knob=40;
      abs(mx-ddx)<15 ? active_knob=41;
      abs(mx-(57+431))<18 ? active_knob=42;
      // Midpoint bends are independent of their stage endpoints.
      abs(mx-(57+atx)*0.5)<10 ? active_knob=43;
      abs(mx-(atx+ddx)*0.5)<10 ? active_knob=44;
      // Sustain level drag: click horizontal stage.
      active_knob==0 && abs(my-(568-203*10^(slider3/20)))<16 ? active_knob=45;
    );
    my>508 && my<670 && mx>556 && mx<1041 ? (
      fax=569+453*(slider32/1000)/max(1,(slider32+slider33+slider35)/1000+0.65);
      fdx=fax+453*(slider33/1000)/max(1,(slider32+slider33+slider35)/1000+0.65);
      abs(mx-fax)<13 ? active_knob=50;
      abs(mx-fdx)<13 ? active_knob=51;
      abs(mx-(569+453))<15 ? active_knob=52;
      abs(mx-(569+fax)*0.5)<10 ? active_knob=53;
      abs(mx-(fax+fdx)*0.5)<10 ? active_knob=54;
      active_knob==0 && abs(my-(658-139*slider34))<16 ? active_knob=55;
    );
  );
  labknobdrag(39,380,864,18);
  labknobdrag(8,583,864,18);
  labknobdrag(5,944,864,24);
  mx>496 && mx<607 && my>20 && my<63 ? labtab=0;
  mx>615 && mx<737 && my>20 && my<63 ? labtab=1;
  mx>745 && mx<896 && my>20 && my<63 ? labtab=2;
  mx>904 && mx<1055 && my>20 && my<63 ? labcommand(5);
  mx>43 && mx<218 && my>161 && my<202 ? labcommand(1);
  labtab==1 && my>414 && my<455 ? (
    mx>52 && mx<183 ? labcommand(3);
    mx>195 && mx<295 ? labcommand(4);
    mx>310 && mx<412 ? labcommand(2);
    mx>425 && mx<551 ? labcommand(6);
    mx>564 && mx<683 ? labcommand(7);
  );
  labtab==1 && mx>52 && mx<236 && my>693 && my<736 ? labcommand(8);
  labtab==2 && my>481 && my<522 ? (
    mx>47 && mx<253 ? (slider23=1-slider23;sliderchange(2^22);slider_automate(2^22););
    mx>267 && mx<427 ? (slider6=slider6<=1?4:1;sliderchange(2^5);slider_automate(2^5););
    mx>440 && mx<595 ? (slider13=1-slider13;sliderchange(2^12);slider_automate(2^12););
  );
  drag_initial=0;
  active_knob==1 ? drag_initial=log(1+slider1/100)/log(321);
  active_knob==2 ? drag_initial=log(1+slider2/100)/log(321);
  active_knob==3 ? drag_initial=(slider3+48)/48;
  active_knob==4 ? drag_initial=log(1+slider4/100)/log(321);
  active_knob==28 ? drag_initial=log(max(20,slider28)/20)/log(1000);
  active_knob==29 ? drag_initial=slider29/0.95;
  active_knob==30 ? drag_initial=slider30/18;
  active_knob==31 ? drag_initial=(slider31+6)/12;
  active_knob==32 ? drag_initial=log(1+slider32/100)/log(321);
  active_knob==33 ? drag_initial=log(1+slider33/100)/log(321);
  active_knob==34 ? drag_initial=slider34;
  active_knob==35 ? drag_initial=log(1+slider35/100)/log(321);
  active_knob==39 ? drag_initial=(slider39+24)/48;
  active_knob==8 ? drag_initial=(slider8+1)/2;
  active_knob==5 ? drag_initial=(slider5+36)/48;
);
mb && active_knob>0 ? (
  norm=max(0,min(1,drag_initial+(mouse_start_y-my)/210));
  active_knob==1 ? slider1=100*(321^norm-1);
  active_knob==2 ? slider2=100*(321^norm-1);
  active_knob==3 ? slider3=-48+48*norm;
  active_knob==4 ? slider4=100*(321^norm-1);
  active_knob==28 ? slider28=20*1000^norm;
  active_knob==29 ? slider29=0.95*norm;
  active_knob==30 ? slider30=18*norm;
  active_knob==31 ? slider31=-6+12*norm;
  active_knob==32 ? slider32=100*(321^norm-1);
  active_knob==33 ? slider33=100*(321^norm-1);
  active_knob==34 ? slider34=norm;
  active_knob==35 ? slider35=100*(321^norm-1);
  active_knob==39 ? slider39=floor(-24+48*norm+0.5);
  active_knob==8 ? slider8=-1+2*norm;
  active_knob==5 ? slider5=-36+48*norm;
  active_knob==40 ? slider1=max(0,min(32000,slider1+(mx-(57+431*(slider1/1000)/max(1,(slider1+slider2+slider4)/1000+0.65)))*8));
  active_knob==41 ? slider2=max(0,min(32000,slider2+(mx-(57+431*((slider1+slider2)/1000)/max(1,(slider1+slider2+slider4)/1000+0.65)))*8));
  active_knob==42 ? slider4=max(0,min(32000,slider4+(mx-1008)*8));
  active_knob==43 ? slider24=max(-1,min(1,slider24+(mouse_start_y-my)/350));
  active_knob==44 ? slider25=max(-1,min(1,slider25+(my-mouse_start_y)/350));
  active_knob==45 ? slider3=max(-48,min(0,20*log(max(0.003981,(568-my)/203))/log(10)));
  active_knob==50 ? slider32=max(0,min(32000,slider32+(mx-(569+453*(slider32/1000)/max(1,(slider32+slider33+slider35)/1000+0.65)))*8));
  active_knob==51 ? slider33=max(0,min(32000,slider33+(mx-(569+453*((slider32+slider33)/1000)/max(1,(slider32+slider33+slider35)/1000+0.65)))*8));
  active_knob==52 ? slider35=max(0,min(32000,slider35+(mx-1022)*8));
  active_knob==53 ? slider36=max(-1,min(1,slider36+(mouse_start_y-my)/350));
  active_knob==54 ? slider37=max(-1,min(1,slider37+(my-mouse_start_y)/350));
  active_knob==55 ? slider34=max(0,min(1,(658-my)/139));
  // Notify REAPER that these visual edits are actual automatable parameters.
  active_knob==1 || active_knob==40 ? sliderchange(2^0);
  active_knob==2 || active_knob==41 ? sliderchange(2^1);
  active_knob==3 || active_knob==45 ? sliderchange(2^2);
  active_knob==4 || active_knob==42 ? sliderchange(2^3);
  active_knob==5 ? sliderchange(2^4);
  active_knob==8 ? sliderchange(2^7);
  active_knob==28 ? sliderchange(2^27);
  active_knob==29 ? sliderchange(2^28);
  active_knob==30 ? sliderchange(2^29);
  active_knob==31 ? sliderchange(2^30);
  active_knob==32 || active_knob==50 ? sliderchange(2^31);
  active_knob==33 || active_knob==51 ? sliderchange(2^32);
  active_knob==34 || active_knob==55 ? sliderchange(2^33);
  active_knob==35 || active_knob==52 ? sliderchange(2^34);
  active_knob==39 ? sliderchange(2^38);
  active_knob==43 ? sliderchange(2^23);
  active_knob==44 ? sliderchange(2^24);
  active_knob==53 ? sliderchange(2^35);
  active_knob==54 ? sliderchange(2^36);
);
!mb ? active_knob=0;
lab_oldmb=mb;
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
  if not BUNDLED_JSFX or not BUNDLED_JSFX:find('MOONAR_LAB_BUILD=0.8.0-preview',1,true) then
    return false, 'Embedded DSP payload missing or invalid.'
  end
  if existing and not existing:find('desc:MOONAR Curve Lab',1,true) then
    return false, 'Unrelated effect exists at '..path..'. Nothing overwritten.'
  end
  reaper.RecursiveCreateDirectory(dir,0)
  if existing then
    local backup=path..'.before_live066.backup'
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
  -- A successful GitHub update to 0.7.14 bootstraps the fixed updater itself.
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
local update_ready,update_error=true,nil -- lab never modifies the original MOONAR updater
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
local drag_initial_x,env_drag_axis=0,nil
local did_mouse_down=false
-- Real user preset bank, not the four ADSR-only macros from the reference UI.
local preset_entries,selected_preset_id,preset_search,preset_scroll,preset_search_focus={},nil,'',0,false
local PRESET_DIR=reaper.GetResourcePath()..SEP..'MOONAR_CURVELAB'..SEP..'Presets'
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
local defaults={0,200,0,650,0,4,72,0,0,1,1,90,0,0,0,2,0,10000,5,70,0,0,0,0,0,0,0,1200,0.35,3,2,8,180,0.50,760,0,0,0,0}
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
  [9]={'Glide','ms',0,1000},[24]={'Attack curve','bend',-1,1},[25]={'Decay curve','bend',-1,1},[26]={'Release curve','bend',-1,1},[14]={'Motion','%',0,100},
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
      if n:find('moonar curve lab 0.8.0',1,true) or
         n:find('moonar_curvelab_080',1,true) or
         id:find('moonar_curvelab_080',1,true) then
        candidate(ident)
        candidate(name)
      end
    end
  end
  candidate('JS: '..FX_NAME)
  candidate('JS: MOONAR_CurveLab_080')
  candidate('JS: MOONAR_CurveLab_080.jsfx')
  candidate('MOONAR_CurveLab_080')
  candidate('MOONAR_CurveLab_080.jsfx')
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

-- An old FX remains until the new instrument imports PCM; after a backup,
-- redundant MOONAR FX are removed so only one instrument stays on the track.
local legacy_fx_pending={}
local function prepare_track()
  if track and reaper.ValidatePtr2(0,track,'MediaTrack*') and fx>=0 then return true end
  local seltrack=reaper.GetSelectedTrack(0,0)
  if seltrack then
    -- Never attach the lab to an existing original MOONAR instrument:
    -- it would cause two synths to sound together and could mutate the original.
    for ii=0,reaper.TrackFX_GetCount(seltrack)-1 do
      local _,nm=reaper.TrackFX_GetFXName(seltrack,ii,'')
      if nm and nm:find('MOONAR Resynth',1,true) then
        seltrack=nil
        break
      end
    end
  end
  local function locate(tr)
    if not tr then return nil end
    for fi=0,reaper.TrackFX_GetCount(tr)-1 do
      local _,name=reaper.TrackFX_GetFXName(tr,fi,'')
      if name and name:find(FX_NAME,1,true) then return fi end
    end
    for fi=0,reaper.TrackFX_GetCount(tr)-1 do
      local _,name=reaper.TrackFX_GetFXName(tr,fi,'')
      if name and name:find('MOONAR Curve Lab',1,true) then return fi end
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
      for i=1,23 do preserved[i]=reaper.TrackFX_GetParam(track,old_fx,i-1) end
      local new_fx=moonar_add_engine(track)
      if new_fx<0 then
        return false,'MOONAR seamless JSFX is missing. Previous FX left unchanged.'
      end
      fx=new_fx
      legacy_fx_pending={old_fx}
      for i=1,23 do if i~=11 then pset(i,preserved[i]) end end
      status='Import PCM to complete the migration to one MOONAR engine.'
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
        if name and name:find('MOONAR Curve Lab',1,true) then
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
    return false,'REAPER cannot resolve MOONAR_CurveLab_080.jsfx. Open FX Browser, refresh its list (F5), and run MOONAR LIVE again.'
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
local function prune_redundant_moonar_after_import()
  if not track or not reaper.ValidatePtr2(0,track,'MediaTrack*') then return false end
  -- Current instance stays; previous MOONAR versions (even bypassed ones)
  -- are backed up and cleaned from THIS track only. Other FX remain intact.
  local older={}
  for i=0,reaper.TrackFX_GetCount(track)-1 do
    if i~=fx then
      local ok,name=reaper.TrackFX_GetFXName(track,i,'')
      if ok and name and name:find('MOONAR Curve Lab',1,true) then
        older[#older+1]=i
      end
    end
  end
  if #older==0 then legacy_fx_pending={};return true end
  -- Prevent doubled sound even if we cannot complete the backup.
  for _,idx in ipairs(older) do reaper.TrackFX_SetEnabled(track,idx,false) end
  if type(reaper.GetTrackStateChunk)~='function' or
     type(reaper.TrackFX_Delete)~='function' then
    status='Older MOONAR FX bypassed; cleanup unavailable in this REAPER.'
    return false
  end
  local ok,chunk=reaper.GetTrackStateChunk(track,'',false)
  if not ok or not chunk or #chunk<50 then
    status='Older MOONAR FX bypassed; project track backup failed.'
    return false
  end
  local dir=reaper.GetResourcePath()..SEP..'MOONAR_RESYNTH'..SEP..'Backups'
  reaper.RecursiveCreateDirectory(dir,0)
  local prefix=dir..SEP..'MOONAR_TrackFX_before_cleanup_'..
    os.date('%Y%m%d_%H%M%S')..'_T'..
    tostring(math.floor(reaper.GetMediaTrackInfo_Value(track,'IP_TRACKNUMBER') or 0))
  local backup=prefix..'.RTrackTemplate'
  local suffix=1
  while read_all(backup) do
    backup=prefix..'_'..tostring(suffix)..'.RTrackTemplate'
    suffix=suffix+1
  end
  local file,reason=io.open(backup,'wb')
  if not file then
    status='Legacy FX bypassed; backup unavailable: '..tostring(reason)
    return false
  end
  local written,write_reason=file:write(chunk)
  local closed,close_reason=file:close()
  if not written or not closed then
    status='Legacy FX bypassed; backup write failed: '..tostring(write_reason or close_reason)
    return false
  end
  -- Descending index order avoids selecting the wrong FX when deleting.
  table.sort(older,function(a,b) return a>b end)
  for _,idx in ipairs(older) do
    local valid,name=reaper.TrackFX_GetFXName(track,idx,'')
    if idx~=fx and valid and name and name:find('MOONAR Curve Lab',1,true) then
      local deleted=reaper.TrackFX_Delete(track,idx)
      if deleted~=false and idx<fx then fx=fx-1 end
    end
  end
  legacy_fx_pending={}
  reaper.UpdateArrange()
  return true
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
  -- PCM and spectral model sent. Back up this track and remove stale
  -- MOONAR FX so only the current synth remains in the chain.
  prune_redundant_moonar_after_import()
  view_start,view_span=0,1
  build_wave(audio)
  file_label=display_name or audio.path or 'IMPORTED AUDIO'
  if audio.path and track then
    reaper.GetSetMediaTrackInfo_String(track,'P_EXT:MOONAR_CURVELAB_SAMPLE_PATH',audio.path,true)
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
  for i=1,39 do
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
  if #values~=22 and #values~=23 and #values~=24 and #values~=26 and #values~=39 then return nil end
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
  for i=1,39 do entry.values[i]=val(i) end
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
  for i=1,39 do
    -- Version 0.7.12 stored HOLD at slot 24; do NOT reinterpret it as a bend.
    local saved=(#entry.values<26 and i>=24 and i<=26) and 0 or (entry.values[i] or defaults[i] or 0)
    if i~=11 and i~=17 and i~=18 then pset(i,saved) end
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
  txt(258,73,'V 0.7.14 / CURVED ADSR',11,.49,.84,.79)
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
  -- AHDSR tick marks are drawn from a single real time axis below.
  local x0,ybot,h,pw=85,621,154,890
  local attack_ms,decay_ms,release_ms=val(1),val(2),val(4)
  local sustain=10^(math.max(-48,math.min(0,val(3)))/20)
  local a_shape=math.exp(-3*val(24))
  local d_shape=math.exp(-3*val(25))
  local r_shape=math.exp(-3*val(26))
  -- TRUE ADSR ONLY. One Serum-style common axis; no HOLD and no fake guide nodes.
  -- DEC moves its own end and the Release endpoint by the same amount.
  local time_sec=math.max(3.7,(attack_ms+decay_ms+release_ms)/1000+0.30)
  local px_per_ms=pw/(time_sec*1000)
  local xx_at=x0+attack_ms*px_per_ms
  local xx_dc=xx_at+decay_ms*px_per_ms
  local xx_ed=xx_dc+release_ms*px_per_ms
  -- index 1 = attack, 2 = decay, 3 = release, 4 = baseline Y,
  -- 5 = height, 6 = start X, 7 = width, 8 = time span in seconds.
  _G.env_points={xx_at,xx_dc,xx_ed,ybot,h,x0,pw,time_sec}
  local function env_gain_at(x)
    if x<xx_at then
      local t=math.max(0,math.min(1,(x-x0)/math.max(0.00001,xx_at-x0)))
      return t^a_shape
    elseif x<xx_dc then
      local t=math.max(0,math.min(1,(x-xx_at)/math.max(0.00001,xx_dc-xx_at)))
      return 1-(1-sustain)*t^d_shape
    elseif x<xx_ed then
      local t=math.max(0,math.min(1,(x-xx_dc)/math.max(0.00001,xx_ed-xx_dc)))
      return sustain*(1-t^r_shape)
    end
    return 0
  end
  for tick=1,4 do
    local x=x0+pw*tick/4
    line(x,447,x,627,.21,.26,.28,.38)
    txt(x-14,636,string.format('%.1fs',time_sec*tick/4),10,.55,.61,.62)
  end
  -- AUTO EXTEND WAVEFORM: use the SAME Natural PCM body region and crossfade
  -- as the running JSFX. Unlike the old preview, a 0.4 s sample is NOT
  -- stretched as a picture once across the entire 32-second envelope.
  -- Instead the source attacks normally, then natural PCM content is
  -- repeated with the same crossfade whenever the envelope exceeds it.
  -- This is illustrative, but based on real sample values, not fake noise.
  if source and source.frames>512 then
    local frames=source.frames
    local start_frame=math.max(0,math.min(math.max(0,frames-512),
      math.floor(frames*val(17)/10000)))
    local end_frame=math.max(start_frame+512,math.min(frames,
      math.floor(frames*val(18)/10000)))
    local region=math.max(512,end_frame-start_frame)
    local body_start=start_frame+math.floor(region*0.20)
    local body_end=math.min(end_frame-1,math.max(body_start+128,
      start_frame+math.floor(region*0.65)))
    local body_len=math.max(128,body_end-body_start)
    local fade_frames=math.max(1,math.min(body_len*0.33,val(20)*0.001*SR))
    local return_frame=body_start+fade_frames
    local repeat_frames=math.max(1,body_end-return_frame)
    local function channel_value(table_samples,frame)
      frame=math.max(0,math.min(frames-1,frame))
      local base=math.floor(frame)
      local frac=frame-base
      local left=table_samples[base+1] or 0
      local right=table_samples[math.min(frames,base+2)] or left
      return left*(1-frac)+right*frac
    end
    local function playback_amp(sample_frame)
      -- First pass is the entire recorded attack. After the first body
      -- boundary, a smoothly crossfaded section repeats without pitch shift.
      if sample_frame>=body_end then
        sample_frame=return_frame+(sample_frame-body_end)%repeat_frames
      end
      local l=channel_value(source.left,sample_frame)
      local r=channel_value(source.right,sample_frame)
      if sample_frame>=body_end-fade_frames and sample_frame<body_end then
        local u=(sample_frame-(body_end-fade_frames))/fade_frames
        local blend=u*u*(3-2*u)
        local head=body_start+u*fade_frames
        l=l*(1-blend)+channel_value(source.left,head)*blend
        r=r*(1-blend)+channel_value(source.right,head)*blend
      end
      return math.max(math.abs(l),math.abs(r))
    end
    -- A stable normalization based on the original PCM sample, NOT the
    -- active envelope, so negative Sustain dB still reads correctly.
    local peak=.0001
    local peak_step=math.max(1,math.floor(region/2048))
    for frame=start_frame,end_frame-1,peak_step do
      peak=math.max(peak,
        math.abs(source.left[frame+1] or 0),
        math.abs(source.right[frame+1] or 0))
    end
    local normalization=math.min(12,.94/peak)
    local middle=ybot-38
    local bins=445
    local duration_samples=time_sec*SR
    for bin=0,bins-1 do
      local x=x0+pw*bin/bins
      local begin_frame=duration_samples*bin/bins
      local next_frame=duration_samples*(bin+1)/bins
      local amplitude=0
      -- Cover the actual output time of each display column. This displays
      -- the same repeated PCM motif when Decay or Release exceeds sample time.
      for offset=0,11 do
        local frame=start_frame+begin_frame+(next_frame-begin_frame)*offset/11
        amplitude=math.max(amplitude,playback_amp(frame))
      end
      local env=math.max(0,math.min(1,env_gain_at(x)))
      local height=math.min(35,amplitude*normalization*35)*env
      if height>.13 then
        line(x,middle-height,x,middle+height,.29,.87,.79,.83)
      end
    end
  end
  local oldx,oldy=nil,nil
  for segment=0,890 do
    local x=x0+pw*segment/890
    local y=ybot-h*math.max(0,math.min(1,env_gain_at(x)))
    line(x,y,x,ybot,.10,.55,.67,.13)
    if oldx then line(oldx,oldy,x,y,.99,.69,.25,1) end
    oldx,oldy=x,y
  end
  if attack_ms<=0 then line(x0,ybot,x0,ybot-h,.99,.69,.25,1) end
  if decay_ms<=0 then line(xx_at,ybot-h,xx_dc,ybot-sustain*h,.99,.69,.25,1) end
  if release_ms<=0 then line(xx_dc,ybot-sustain*h,xx_dc,ybot,.99,.69,.25,1) end
  -- Large amber points = real ADSR stage ends only.
  circ(xx_at,ybot-h,9,.98,.73,.27,1)
  circ(xx_dc,ybot-sustain*h,9,.98,.73,.27,1)
  circ(xx_ed,ybot,9,.98,.73,.27,1)
  -- Small cyan points = BEND controls inside existing segments.
  -- They appear only when a stage is stretched enough to edit its curve.
  local bends={
    {44,(x0+xx_at)/2,env_gain_at((x0+xx_at)/2),xx_at-x0>=44,24},
    {45,(xx_at+xx_dc)/2,env_gain_at((xx_at+xx_dc)/2),xx_dc-xx_at>=44 and 1-sustain>.015,25},
    {46,(xx_dc+xx_ed)/2,env_gain_at((xx_dc+xx_ed)/2),xx_ed-xx_dc>=44 and sustain>.015,26}
  }
  _G.env_bend_points={}
  for _,p in ipairs(bends) do
    if p[4] then
      local y=ybot-p[3]*h
      circ(p[2],y,6,.36,.85,.95,1)
      _G.env_bend_points[#_G.env_bend_points+1]={id=p[1],x=p[2],y=y,param=p[5]}
    end
  end
  txt(78,453,'ADSR / AUTO-EXTENDED PCM / SERUM CURVES',11,.54,.80,.75)
  txt(78,472,'CYAN DOTS: BEND ATTACK, DECAY, RELEASE   |   NO HOLD',11,.92,.75,.44)
  txt(84,636,'0',11,.55,.6,.6)
  local xs={190,372,554,736,920}
  local labels={'ATTACK','DECAY','SUSTAIN','RELEASE','VOLUME'}
  local par={1,2,3,4,5}
  local texts={fmt_adsr(val(1)),fmt_adsr(val(2)),fmt(val(3),'%.1f dB'),fmt_adsr(val(4)),fmt(val(5),'%+.1f dB')}
  for i=1,5 do
    local v=val(par[i]);local mn,mxv=knobrange[i][1],knobrange[i][2]
    local norm=(par[i]==3 or par[i]==5)
      and math.max(0,math.min(1,(v-mn)/(mxv-mn))) or ms_to_norm(v)
    knob(xs[i],735,35,labels[i],texts[i],norm,par[i]==5)
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
    drag=0;drag_initial_y=my;drag_initial_x=mx;env_drag_axis=nil
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
      -- Bend dots take priority over nearby stage points.
      for _,node in ipairs(_G.env_bend_points or {}) do
        if math.abs(mx-node.x)<13 and math.abs(my-node.y)<15 then
          drag=node.id;break
        end
      end
      local peak_y=p[4]-p[5]
      local decay_y=p[4]-(10^(val(3)/20))*p[5]
      if drag==0 then
        if math.abs(mx-p[3])<15 and math.abs(my-p[4])<22 then drag=43
        elseif math.abs(mx-p[2])<16 and math.abs(my-decay_y)<23 then drag=42
        elseif math.abs(mx-p[1])<15 and math.abs(my-peak_y)<22 then drag=40 end
      end
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
      local raw_time=(mx-p[6])/math.max(1,p[7])*p[8]*1000
      local t=math.max(0,raw_time)
      if drag==40 then
        pset(1,math.max(0,math.min(32000,t)))
      elseif drag==42 then
        if not env_drag_axis then
          local dx,dy=mx-drag_initial_x,my-drag_initial_y
          if math.max(math.abs(dx),math.abs(dy))>5 then
            env_drag_axis=math.abs(dy)>math.abs(dx)*1.3 and 'level' or 'time'
          end
        end
        if env_drag_axis=='level' then
          local gain=math.max(10^(-48/20),math.min(1,(p[4]-my)/p[5]))
          pset(3,math.max(-48,math.min(0,20*math.log(gain,10))))
        else
          pset(2,math.max(0,math.min(32000,t-val(1))))
        end
      elseif drag==43 then
        pset(4,math.max(0,math.min(32000,t-val(1)-val(2))))
      elseif drag==44 or drag==45 or drag==46 then
        -- Inverse of midpoint gain = .5 ^ exp(-3*bend).
        -- Hence the dragged point matches the ACTUAL JSFX curve exactly.
        local level=math.max(0.000001,math.min(.999999,(p[4]-my)/p[5]))
        local target
        if drag==44 then
          target=level
        elseif drag==45 then
          local sus=10^(val(3)/20)
          target=(1-level)/math.max(.000001,1-sus)
        else
          local sus=10^(val(3)/20)
          target=1-level/math.max(.000001,sus)
        end
        target=math.max(.000001,math.min(.999999,target))
        local shape=math.log(target)/math.log(.5)
        local bend=math.max(-1,math.min(1,-math.log(shape)/3))
        pset(drag==44 and 24 or (drag==45 and 25 or 26),bend)
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
local live_namespace='MOONAR_CURVELAB_LIVE'
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
if not ok then reaper.ShowMessageBox(err,'MOONAR Curve Lab',0); return end
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
  local _,saved_path=reaper.GetSetMediaTrackInfo_String(track,'P_EXT:MOONAR_CURVELAB_SAMPLE_PATH','',false)
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

-- CURVE LAB HEADLESS CONTROLLER: actual plugin insert draws the full interface.
-- Only this controller handles REAPER file browsers and persistent preset files.
local function lab_export_preset_state()
  if not slot then return end
  reaper.gmem_attach(BUS)
  local base=(slot-1)*SLOT_STRIDE
  local e=selected_preset_entry()
  local name=e and e.name or ''
  local i=1
  while i<=64 do
    reaper.gmem_write(base+3000000+i-1,string.byte(name,i) or 0)
    i=i+1
  end
  reaper.gmem_write(base+3000065,#preset_entries)
end
local function lab_import_legacy_presets()
  local old_dir=reaper.GetResourcePath()..SEP..'MOONAR_RESYNTH'..SEP..'Presets'
  local count=0
  if not reaper.EnumerateFiles then return end
  ensure_preset_dir()
  for i=0,10000 do
    local file=reaper.EnumerateFiles(old_dir,i)
    if not file then break end
    local original_id=file:match('^([%w_%-]+)%.moonpreset$')
    if original_id then
      local old=read_all(old_dir..SEP..file)
      local wav=read_all(old_dir..SEP..original_id..'.wav')
      if old and wav and old:find('MOONAR_PRESET_V1',1,true)==1 then
        local new_id=make_unique_preset_id()
        if new_id then
          local lines={}
          for line in (old..'\n'):gmatch('(.-)\n') do lines[#lines+1]=line end
          if #lines>=5 then
            local values={}
            for n in (lines[5] or ''):gmatch('[^\t]+') do values[#values+1]=tonumber(n) end
            if #values>=22 and #values<=26 then
              for j=#values+1,39 do values[j]=defaults[j] or 0 end
              local entry={id=new_id,name=preset_safe_line(lines[2]),favorite=lines[4]=='1',values=values}
              local new_wav=preset_audio_file(new_id)
              local f=io.open(new_wav,'wb')
              if f then
                local ok1=f:write(wav)
                local ok2=f:close()
                if ok1 and ok2 then
                  local ok3=save_preset_meta(entry)
                  if ok3 then count=count+1 else os.remove(new_wav) end
                end
              end
            end
          end
        end
      end
    end
  end
  scan_preset_bank()
  status='Imported '..count..' copies of original MOONAR presets'
end
local command_seq=-1
local function lab_controller_loop()
  if not track or not reaper.ValidatePtr2(0,track,'MediaTrack*') then
    reaper.gmem_attach(BUS)
    if slot then reaper.gmem_write((slot-1)*SLOT_STRIDE+28,0) end
    return
  end
  if reaper.GetExtState(live_namespace,'CURRENT_UI')~=live_token then
    reaper.gmem_attach(BUS)
    if slot then reaper.gmem_write((slot-1)*SLOT_STRIDE+28,0) end
    return
  end
  reaper.gmem_attach(BUS)
  local base=(slot-1)*SLOT_STRIDE
  reaper.gmem_write(base+28,1)
  local newseq=reaper.gmem_read(base+27)
  if command_seq<0 then command_seq=newseq end
  if newseq~=command_seq then
    command_seq=newseq
    local cmd=math.floor(reaper.gmem_read(base+26)+0.5)
    if cmd==1 then
      local ok,path=reaper.GetUserFileNameForRead('','MOONAR CURVE LAB | Load audio','')
      if ok and path and path~='' then import_path(path) end
    elseif cmd==2 then save_current_preset()
    elseif cmd==3 then step_sound_preset(-1)
    elseif cmd==4 then step_sound_preset(1)
    elseif cmd==5 then
      local updater=reaper.GetResourcePath()..SEP..'Scripts'..SEP..'MOONAR_CURVELAB_UPDATE.lua'
      if read_all(updater) then
        local action=reaper.AddRemoveReaScript(true,0,updater,true)
        if action and action>0 then
          reaper.defer(function() reaper.Main_OnCommand(action,0) end)
        else status='Curve Lab updater action unavailable' end
      else
        reaper.ShowMessageBox('Curve Lab updater is not installed. Run Curve Lab installer.','CURVE LAB UPDATE',0)
      end
    elseif cmd==6 then rename_sound_preset()
    elseif cmd==7 then delete_sound_preset()
    elseif cmd==8 then lab_import_legacy_presets()
    end
    lab_export_preset_state()
  end
  reaper.defer(lab_controller_loop)
end
-- No duplicate Lua graphical window: JSFX @gfx is the instrument interface.
reaper.TrackFX_Show(track,fx,3)
lab_export_preset_state()
reaper.defer(lab_controller_loop)
