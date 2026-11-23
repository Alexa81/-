

-- MOONAR CURVE LAB 0.8.3 PREVIEW / AUTO EXTENDED PCM WAVEFORM + SERUM CURVE HANDLES + ONE FX PER TRACK + FULL UPDATE AND REPAIR + JSFX COMPILER FIX + SELECTED TRACK + MIDI ROUTING + GITHUB UPDATE BUTTON + RECOVER SILENCE + PREVIEW MIDI + ON-DISK PRESET BANK
-- Companion ReaScript UI: real file drag/drop and trim controls; JSFX audio engine.
-- This is an original instrument, unrelated to Tim Hox's proprietary source code.
local FX_NAME='MOONAR Curve Lab 0.8.1 Preview'
local JSFX_FILENAME='MOONAR_CurveLab_080.jsfx'
local ENGINE_COMPATIBLE={'MOONAR_LAB_BUILD=0.8.1-preview'}
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

desc:MOONAR Curve Lab 0.8.1 Preview
tags:instrument sampler resynthesis
options:gmem=MOONAR_CURVELAB_BRIDGE_08 maxmem=3100000
in_pin:none
out_pin:Left
out_pin:Right

// MOONAR_LAB_BUILD=0.8.1-preview
// Independent educational sampler/resynthesis prototype, NOT Tim Hox's source.
// Protocol version 2. Natural PCM body-loop sustain (default) or optional spectral synthesis.

slider1:0<0,32000,1>-Attack (ms)
slider2:200<0,32000,1>-Decay (ms)
slider3:0<-48,0,0.1>-Sustain (dB)
slider4:650<0,32000,1>-Release (ms)
slider5:0<-36,12,0.1>-Output (dB)
slider6:4<1,4,1>-Polyphony (voices)
slider7:72<24,96,1>-MIDI keyboard root (C5=72)
slider8:0<-12,12,0.01>-Fine tune (semitones)
slider9:0<0,1000,1>-Glide (ms, mono)
slider10:1<0,1,1{Off,On}>-Tune detected root to nearest C
slider11:1<1,2,1>-Internal import slot (1-2)
slider12:90<10,250,1>-Original-to-synthesis fade (ms)
slider13:0<0,1,1{Off,On}>-Legato (mono only)
slider14:0<0,100,1>-Organic harmonic motion (%)
slider15:0<0,100,1>-Residual noise body (%)
slider16:2<0,12,1>-Pitch bend range (semitones)
slider17:0<0,10000,1>-Trim Start (0-100%)
slider18:10000<1,10000,1>-Trim End (0-100%)
slider19:5<0,300,1>-Start Fade (ms)
slider20:70<0,300,1>-End Fade / Synth Crossfade (ms)
slider21:0<-1.5,1.5,0.05>-Fade In Bend
slider22:0<-1.5,1.5,0.05>-Fade Out Bend
slider23:0<0,1,1{Natural Loop,Spectral}>-Sustain Engine
slider24:0<-1,1,0.01>-Attack Curve
slider25:0<-1,1,0.01>-Decay Curve
slider26:0<-1,1,0.01>-Release Curve
// Original 26 parameters above remain at their original indices.
slider27:0<0,1,1{Off,On}>-Moog-style Filter
slider28:1200<20,20000,1>-Filter Cutoff (Hz)
slider29:0.35<0,0.95,0.01>-Filter Resonance
slider30:3<0,18,0.1>-Filter Drive (dB)
slider31:2<-6,6,0.01>-Filter Envelope Depth (octaves)
slider32:8<0,32000,1>-Filter Attack (ms)
slider33:180<0,32000,1>-Filter Decay (ms)
slider34:0.50<0,1,0.01>-Filter Sustain (level)
slider35:760<0,32000,1>-Filter Release (ms)
slider36:0<-1,1,0.01>-Filter Attack Curve
slider37:0<-1,1,0.01>-Filter Decay Curve
slider38:0<-1,1,0.01>-Filter Release Curve
slider39:0<-24,24,1>-Transpose (semitones)

@init
// Local bounded saturation: do not rely on nonstandard tanh() builtins.
function lab_tanh(input) (
  input=max(-12,min(12,input));
  exponent=exp(2*input);
  (exponent-1)/(exponent+1);
);
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
        inl=lab_tanh((mix_l-fb*vo[31])*filter_drive);
        inr=lab_tanh((mix_r-fb*vo[35])*filter_drive);
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



// The DSP engine is intentionally headless. The single user-facing GUI is
// MOONAR_CURVELAB_LIVE.lua (ReaScript gfx) which supports Finder drag/drop.
// All native sliders are prefixed '-' and remain available to automation.

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
  if not BUNDLED_JSFX or not BUNDLED_JSFX:find('MOONAR_LAB_BUILD=0.8.1-preview',1,true) then
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
  local path=dir..SEP..'MOONAR_CURVELAB_UPDATE.lua'
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
      if n:find('moonar curve lab 0.8.1',1,true) or
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
    reaper.GetSetMediaTrackInfo_String(track,'P_NAME','MOONAR CURVE LAB | MIDI IN',true)
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
  -- Preserve user's Record Arm, Input Monitoring and MIDI input state.
  -- The synth processes MIDI items without forcing live recording.
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
  -- Never alter the track's Record Arm, Input Monitoring or input selection
  -- when opening MOONAR or restoring its audio.
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

local persist_loaded_sample -- defined after the 32-bit-float WAV writer below
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
  -- Importing a REAPER media item has no source path. Save its analyzed PCM
  -- per-track so closing the GUI and relaunching restores the SAME waveform.
  if persist_loaded_sample then
    local cached,why=persist_loaded_sample(audio)
    if not cached then
      status='Audio loaded but cache failed: '..tostring(why)
    end
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
-- Persistent, independent PCM cache. The WAV is stored outside temporary
-- gmem; the REAPER track carries the path in its project state. Unlike a
-- preset, this auto-cache needs no user action and never edits original MOONAR.
persist_loaded_sample=function(audio)
  if not track or not reaper.ValidatePtr2(0,track,'MediaTrack*') then
    return false,'No valid instrument track'
  end
  local guid=reaper.GetTrackGUID(track)
  if not guid or guid=='' then return false,'Missing track GUID' end
  guid=guid:gsub('[^%w]','')
  local dir=reaper.GetResourcePath()..SEP..'MOONAR_CURVELAB'..SEP..'SessionSamples'
  reaper.RecursiveCreateDirectory(dir,0)
  local target=dir..SEP..'sample_'..guid..'.wav'
  -- A cached WAV is already the exact PCM that was loaded on this reopen.
  if audio.path~=target then
    local tmp=target..'.new'
    os.remove(tmp)
    local ok,why=write_preset_wav(tmp,audio)
    if not ok then return false,why end
    local saved,why2=os.rename(tmp,target)
    if not saved then os.remove(tmp);return false,'Could not finalize cached WAV: '..tostring(why2) end
  end
  local _,previous=reaper.GetSetMediaTrackInfo_String(track,
    'P_EXT:MOONAR_CURVELAB_SAMPLE_PATH','',false)
  reaper.GetSetMediaTrackInfo_String(track,'P_EXT:MOONAR_CURVELAB_SAMPLE_PATH',target,true)
  -- When restoring an existing cache, retain the user's original source name.
  if previous~=target or audio.path~=target then
    reaper.GetSetMediaTrackInfo_String(track,'P_EXT:MOONAR_CURVELAB_SAMPLE_LABEL',file_label,true)
  end
  if previous~=target and type(reaper.MarkProjectDirty)=='function' then
    reaper.MarkProjectDirty(0)
  end
  return true
end

local function restore_audio_from_bridge()
  if not slot then return nil end
  reaper.gmem_attach(BUS)
  local base=(slot-1)*SLOT_STRIDE
  local ready=reaper.gmem_read(base)
  local frames=math.floor(reaper.gmem_read(base+2) or 0)
  local sr=reaper.gmem_read(base+3)
  if ready~=1 or frames<4096 or frames>MAX_FRAMES or
     math.abs(sr-SR)>1 then return nil end
  local audio={left={},right={},frames=frames,
    total_length=frames/SR,length=frames/SR}
  for i=1,frames do
    audio.left[i]=reaper.gmem_read(base+64+i-1)
    audio.right[i]=reaper.gmem_read(base+1400064+i-1)
  end
  return audio
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

-- MOONAR CURVE LAB 0.8.2 / unified midnight violet GUI.
-- One Lua window accepts REAPER gfx.getdropfile; exactly one JSFX renders audio.
-- Neither the original v0.7.14 source nor saved original presets are modified.
local ui_view='SYNTH'
local ui_controls={}
local ui_envnodes={}
local ui_drag=nil
local ui_mouse_was_down=false
local ui_right_was_down=false
local ui_start_y,ui_start_x,ui_start_value=0,0,0
local ui_trim_initial_start,ui_trim_initial_end=0,0
local ui_preset_rows={}
local ui_error=''
local function vr(x,y,w,h,rr,gg,bb,aa)
  rect(x,y,w,h,rr,gg,bb,aa or 1)
end
local function vtxt(x,y,t,size,rr,gg,bb)
  txt(x,y,t,size or 13,rr or .86,gg or .86,bb or .95)
end
local function vline(x,y,x2,y2,rr,gg,bb,aa)
  line(x,y,x2,y2,rr,gg,bb,aa or 1)
end
local function vpanel(x,y,w,h,title)
  vr(x+3,y+4,w,h,.010,.012,.036,.55)
  vr(x,y,w,h,.067,.074,.131,1)
  vr(x,y,w,2,.26,.20,.41,1)
  if title then vtxt(x+17,y+15,title,15,.88,.86,.99) end
end
local function vbutton(x,y,w,h,textvalue,selected,kind)
  vr(x,y,w,h,selected and .38 or .106,selected and .26 or .113,selected and .59 or .20,1)
  vtxt(x+11,y+math.max(7,(h-17)/2),textvalue,13,selected and .98 or .75,selected and .97 or .77,selected and 1 or .91)
  if kind then ui_controls[#ui_controls+1]={kind='button',action=kind,x=x,y=y,w=w,h=h} end
end
local function vknob(x,y,r,label,id,min,max,fmt_text)
  local value=val(id)
  local norm
  if id==28 then norm=math.log(math.max(20,value)/20)/math.log(1000)
  elseif id==1 or id==2 or id==4 or id==32 or id==33 or id==35 then norm=ms_to_norm(value)
  else norm=(value-min)/math.max(.00001,max-min) end
  norm=clamp(norm,0,1)
  circ(x+1,y+3,r+6,.032,.037,.074,1)
  circ(x,y,r+1,.21,.23,.34,1)
  circ(x,y,r-2,.070,.074,.13,1)
  for n=0,28 do
    local ang=2.35+(n/28)*4.7
    local x1,y1=x+math.cos(ang)*(r+3),y+math.sin(ang)*(r+3)
    local x2,y2=x+math.cos(ang)*(r+7),y+math.sin(ang)*(r+7)
    if n/28<=norm then vline(x1,y1,x2,y2,.67,.48,.98)
    else vline(x1,y1,x2,y2,.33,.34,.47) end
  end
  local theta=2.35+norm*4.7
  vline(x,y,x+math.cos(theta)*(r-7),y+math.sin(theta)*(r-7),.94,.90,1)
  vtxt(x-r-8,y-r-29,label,11,.73,.74,.88)
  vtxt(x-r-8,y+r+13,fmt_text,12,.92,.87,1)
  ui_controls[#ui_controls+1]={kind='knob',x=x,y=y,r=r+9,param=id,min=min,max=max}
end
local function vvalue(id)
  if id==1 or id==2 or id==4 or id==32 or id==33 or id==35 then return fmt_adsr(val(id)) end
  if id==28 then return string.format('%.0f Hz',val(id)) end
  if id==8 then return string.format('%+.1f ct',val(id)*100) end
  if id==39 then return string.format('%+.0f st',val(id)) end
  if id==5 then return string.format('%+.1f dB',val(id)) end
  if id==3 then return string.format('%.1f dB',val(id)) end
  if id==34 then return string.format('%.2f',val(id)) end
  if id==31 then return string.format('%+.1f oct',val(id)) end
  if id==29 then return string.format('%.2f',val(id)) end
  if id==30 then return string.format('%.1f dB',val(id)) end
  if id==9 then return string.format('%.0f ms',val(id)) end
  return string.format('%.0f',val(id))
end
local function venv(x,y,w,h,prefix,mode)
  local a,d,s,r,ca,cd,cr
  if mode=='AMP' then
    a,d,s,r=val(1),val(2),10^(val(3)/20),val(4)
    ca,cd,cr=val(24),val(25),val(26)
  else
    a,d,s,r=val(32),val(33),val(34),val(35)
    ca,cd,cr=val(36),val(37),val(38)
  end
  vr(x,y,w,h,.019,.025,.061,1)
  for n=1,3 do
    vline(x+w*n/4,y+8,x+w*n/4,y+h-8,.18,.19,.31,.34)
  end
  local unit=math.max(2.6,(a+d+r)/1000+.45)
  local px=w/(unit*1000)
  local xA=x+a*px
  local xD=xA+d*px
  local xS=xD+450*px
  local xR=math.min(x+w,xS+r*px)
  local bottom=y+h-13
  local height=h-31
  local function amp(t,st)
    t=clamp(t,0,1)
    if st==1 then return t^math.exp(-3*ca)
    elseif st==2 then return 1-(1-s)*t^math.exp(-3*cd)
    elseif st==3 then return s*(1-t^math.exp(-3*cr)) end
    return s
  end
  local function getgain(xx)
    if xx<xA then return amp((xx-x)/math.max(.00001,xA-x),1) end
    if xx<xD then return amp((xx-xA)/math.max(.00001,xD-xA),2) end
    if xx<xS then return s end
    if xx<xR then return amp((xx-xS)/math.max(.00001,xR-xS),3) end
    return 0
  end
  local oldx,oldy
  for n=0,170 do
    local px0=x+w*n/170
    local py0=bottom-getgain(px0)*height
    if oldx then
      vline(oldx,oldy,px0,py0,mode=='AMP' and .73 or .30,mode=='AMP' and .42 or .96,mode=='AMP' and .98 or .77,1)
    end
    oldx,oldy=px0,py0
  end
  local points={
    {name='A',x=xA,y=bottom-height,param=mode=='AMP' and 1 or 32},
    {name='D',x=xD,y=bottom-s*height,param=mode=='AMP' and 2 or 33},
    {name='S',x=xS,y=bottom-s*height,param=mode=='AMP' and 3 or 34},
    {name='R',x=xR,y=bottom,param=mode=='AMP' and 4 or 35},
    {name='CA',x=(x+xA)/2,y=bottom-amp(.5,1)*height,param=mode=='AMP' and 24 or 36,bend=true},
    {name='CD',x=(xA+xD)/2,y=bottom-amp(.5,2)*height,param=mode=='AMP' and 25 or 37,bend=true},
    {name='CR',x=(xS+xR)/2,y=bottom-amp(.5,3)*height,param=mode=='AMP' and 26 or 38,bend=true}
  }
  for _,p in ipairs(points) do
    local usable=not p.bend or
      (p.name=='CA' and xA-x>24) or
      (p.name=='CD' and xD-xA>24 and s<.98) or
      (p.name=='CR' and xR-xS>24 and s>.02)
    if usable then
      circ(p.x,p.y,p.bend and 5 or 7,
        p.bend and .44 or (mode=='AMP' and .78 or .35),
        p.bend and .83 or (mode=='AMP' and .58 or .98),
        p.bend and 1 or (mode=='AMP' and .98 or .71),1)
      ui_envnodes[#ui_envnodes+1]={mode=mode,x=p.x,y=p.y,
        point=p.name,param=p.param,startx=x,width=w,unit=unit,
        bottom=bottom,height=height,sustain=s,attack=a,decay=d,release=r}
    end
  end
end
local function vwave()
  vpanel(24,104,1032,218,nil)
  vtxt(45,119,'SOURCE SAMPLE',14,.86,.86,.97)
  vtxt(338,119,source and file_label:sub(1,53) or 'Drag a WAV / AIFF / FLAC file here',13,.62,.75,.91)
  vbutton(891,114,148,34,'LOAD SAMPLE',false,'load')
  local x,y,w,h=44,160,990,128
  vr(x,y,w,h,.015,.024,.053,1)
  for n=1,7 do
    vline(x+n*w/8,y+6,x+n*w/8,y+h-5,.19,.22,.31,.26)
  end
  vline(x,y+h/2,x+w,y+h/2,.35,.26,.48,.35)
  if source then
    for n=0,494 do
      local idx=math.floor((view_start+view_span*n/495)*715)+1
      idx=clamp(idx,1,716)
      local peak1=wave_max[idx] or 0
      local peak2=wave_min[idx] or 0
      local xx=x+n*2
      vline(xx,y+h/2-peak1*53,xx,y+h/2-peak2*53,.44,.90,.80,.89)
    end
    local st=clamp((val(17)/10000-view_start)/view_span,0,1)
    local ed=clamp((val(18)/10000-view_start)/view_span,0,1)
    vline(x+w*st,y+4,x+w*st,y+h-3,.45,1,.8)
    vline(x+w*ed,y+4,x+w*ed,y+h-3,.45,1,.8)
    circ(x+w*st,y+h/2,6,.40,.95,.79)
    circ(x+w*ed,y+h/2,6,.40,.95,.79)
    ui_controls[#ui_controls+1]={kind='wave',part='start',x=x+w*st,y=y+h/2,r=13}
    ui_controls[#ui_controls+1]={kind='wave',part='end',x=x+w*ed,y=y+h/2,r=13}
    vtxt(48,293,string.format('TRIM  %.2f - %.2f s',source.frames/SR*val(17)/10000,source.frames/SR*val(18)/10000),11,.66,.71,.86)
  else
    vtxt(340,212,'DROP SAMPLE HERE',21,.70,.55,.95)
  end
  vbutton(913,289,124,27,'FIT / 1x',false,'fit')
  vtxt(355,295,'PCM / SPECTRAL RESYNTH  •  DRAG & DROP',11,.52,.57,.77)
end
local function vpreset_overlay()
  vpanel(24,334,1032,380,'PRESETS  /  PERSONAL SOUND BANK')
  vtxt(52,388,'Choose a sound. Sample, original synthesis and filter settings are saved together.',13,.65,.68,.85)
  vr(52,420,448,42,.026,.035,.071,1)
  vtxt(66,430,'SEARCH  '..(preset_search=='' and '(click to type)' or preset_search),14,.69,.74,.92)
  ui_controls[#ui_controls+1]={kind='button',action='search',x=52,y=420,w=448,h=42}
  local entries=filtered_presets()
  ui_preset_rows={}
  for i=1,6 do
    local e=entries[preset_scroll+i]
    local y=470+(i-1)*35
    if e then
      vbutton(52,y,600,32,(e.favorite and '*  ' or '   ')..e.name:sub(1,53),e.id==selected_preset_id,'preset:'..e.id)
      vbutton(658,y,60,32,e.favorite and '★' or '☆',false,'favorite:'..e.id)
      ui_preset_rows[#ui_preset_rows+1]=e
    end
  end
  if #entries==0 then vtxt(77,515,'No presets yet. Import a sample, then press SAVE.',15,.62,.66,.82) end
  vbutton(766,474,244,45,'SAVE PRESET',false,'save')
  vbutton(766,532,244,45,'RENAME',false,'rename')
  vbutton(766,590,244,45,'DELETE',false,'delete')
end
local function vadvanced_overlay()
  vpanel(24,334,1032,380,'ADVANCED / ORIGINAL MOONAR CONTROLS')
  vtxt(50,393,'All original DSP parameters remain accessible here and via REAPER automation.',13,.67,.70,.85)
  vknob(120,510,32,'NOISE',15,0,100,vvalue(15))
  vknob(295,510,32,'MOTION',14,0,100,vvalue(14))
  vknob(480,510,32,'GLIDE',9,0,1000,vvalue(9))
  vknob(670,510,32,'MIDI ROOT',7,24,96,vvalue(7))
  vknob(885,510,32,'BEND RANGE',16,0,12,vvalue(16))
  vbutton(62,632,172,43,val(23)>.5 and 'SPECTRAL' or 'NATURAL LOOP',val(23)>.5,'engine')
  vbutton(244,632,140,43,val(10)>.5 and 'AUTO C ON' or 'AUTO C OFF',val(10)>.5,'auto-c')
  vbutton(394,632,130,43,val(6)<=1 and 'MONO' or 'POLY',val(6)<=1,'poly')
  vbutton(534,632,146,43,val(13)>.5 and 'LEGATO ON' or 'LEGATO OFF',val(13)>.5,'legato')
  vbutton(690,632,210,43,audition_note and 'RELEASE NOTE' or 'TEST NOTE',false,'audition')
end
local function draw_new()
  render_scale=math.max(.18,math.min(gfx.w/UWIN,gfx.h/UH))
  origin_x=(gfx.w-UWIN*render_scale)/2
  origin_y=(gfx.h-UH*render_scale)/2
  ui_controls={}
  ui_envnodes={}
  vr(0,0,UWIN,UH,.021,.027,.057,1)
  for i=0,95 do
    local v=i/95
    vr(0,i*9.8,1080,10,.022+.007*v,.027+.007*v,.058+.01*v,.23)
  end
  vr(0,0,UWIN,92,.050,.048,.094,1)
  vr(0,90,UWIN,2,.32,.22,.47,1)
  vtxt(32,18,'MOONAR',38,.91,.83,1)
  vtxt(236,34,'CURVE LAB',19,.68,.60,.91)
  vtxt(239,65,'v0.8.3  /  ONE SYNTH  /  DROP SAMPLE',11,.47,.69,.80)
  vbutton(640,23,127,47,'PRESETS',ui_view=='PRESETS','presets')
  vbutton(774,23,141,47,'MORE',ui_view=='ADVANCED','advanced')
  vbutton(923,23,131,47,'UPDATE',false,'update')
  vwave()
  if ui_view=='SYNTH' then
    vpanel(24,338,327,361,'AMP ENVELOPE')
    vpanel(361,338,333,361,'MOOG-STYLE FILTER')
    vpanel(704,338,352,361,'FILTER ENVELOPE')
    vtxt(46,367,'VOLUME / ADSR',12,.64,.60,.94)
    vtxt(723,367,'FILTER / ADSR',12,.46,.92,.76)
    venv(42,394,292,172,1,'AMP')
    venv(718,394,322,172,2,'FILTER')
    vknob(80,623,22,'ATTACK',1,0,32000,vvalue(1))
    vknob(158,623,22,'DECAY',2,0,32000,vvalue(2))
    vknob(237,623,22,'SUSTAIN',3,-48,0,vvalue(3))
    vknob(315,623,22,'RELEASE',4,0,32000,vvalue(4))
    vknob(756,623,22,'ATTACK',32,0,32000,vvalue(32))
    vknob(836,623,22,'DECAY',33,0,32000,vvalue(33))
    vknob(920,623,22,'SUSTAIN',34,0,1,vvalue(34))
    vknob(1009,623,22,'RELEASE',35,0,32000,vvalue(35))
    vbutton(465,389,130,35,val(27)>.5 and 'FILTER ON' or 'FILTER OFF',val(27)>.5,'filter-on')
    vknob(435,489,33,'CUTOFF',28,20,20000,vvalue(28))
    vknob(603,489,29,'RESONANCE',29,0,.95,vvalue(29))
    vknob(436,622,29,'DRIVE',30,0,18,vvalue(30))
    vknob(603,622,29,'ENV AMOUNT',31,-6,6,vvalue(31))
    vtxt(386,680,'4-POLE LOWPASS  •  PER-VOICE ENVELOPE',11,.50,.64,.81)
  elseif ui_view=='PRESETS' then vpreset_overlay()
  else vadvanced_overlay() end
  vpanel(24,724,1032,183,'TUNING / OUTPUT')
  vtxt(44,765,source and ('LOADED: '..file_label:sub(1,39)) or 'NO SAMPLE LOADED',12,.58,.79,.75)
  vknob(128,833,27,'TRANSPOSE',39,-24,24,vvalue(39))
  vknob(343,833,27,'FINE DETUNE',8,-12,12,vvalue(8))
  vknob(557,833,27,'OUTPUT',5,-36,12,vvalue(5))
  vbutton(695,811,148,45,val(6)<=1 and 'MONO' or 'POLY',val(6)<=1,'poly')
  vbutton(862,811,166,45,audition_note and 'RELEASE NOTE' or 'TEST NOTE',false,'audition')
  vtxt(43,889,(status or ''):sub(1,95),11,.60,.72,.80)
end
local function new_button(action)
  if action=='load' then
    local ok,path=reaper.GetUserFileNameForRead('','Load MOONAR sample','')
    if ok and path and path~='' then import_path(path) end
  elseif action=='fit' then set_view(0,1)
  elseif action=='presets' then ui_view=ui_view=='PRESETS' and 'SYNTH' or 'PRESETS'
  elseif action=='advanced' then ui_view=ui_view=='ADVANCED' and 'SYNTH' or 'ADVANCED'
  elseif action=='filter-on' then pset(27,val(27)>.5 and 0 or 1)
  elseif action=='engine' then pset(23,1-val(23))
  elseif action=='auto-c' then pset(10,1-val(10))
  elseif action=='poly' then pset(6,val(6)<=1 and 4 or 1)
  elseif action=='legato' then pset(13,1-val(13))
  elseif action=='audition' then audition_current()
  elseif action=='save' then save_current_preset()
  elseif action=='rename' then rename_sound_preset()
  elseif action=='delete' then delete_sound_preset()
  elseif action=='search' then preset_search_focus=true
  elseif action=='update' then
    local script=reaper.GetResourcePath()..SEP..'Scripts'..SEP..'MOONAR_CURVELAB_UPDATE.lua'
    if not read_all(script) then
      status='Curve Lab updater not found. Run the Curve Lab installer.'
    else
      local command=reaper.AddRemoveReaScript(true,0,script,true)
      if command and command>0 then
        status='Checking Curve Lab updates...'
        reaper.defer(function() reaper.Main_OnCommand(command,0) end)
      else status='Unable to register Curve Lab updater' end
    end
  elseif action:find('^preset:') then
    local id=action:sub(8)
    for _,e in ipairs(preset_entries) do if e.id==id then load_sound_preset(e);break end end
  elseif action:find('^favorite:') then
    local id=action:sub(10)
    for _,e in ipairs(preset_entries) do if e.id==id then toggle_preset_favorite(e);break end end
  end
end
local function env_pointer(node,x,y)
  local value=val(node.param)
  local scale=node.width/(node.unit*1000)
  local x0=node.startx
  if node.point=='A' then
    pset(node.param,clamp((x-x0)/scale,0,32000))
  elseif node.point=='D' then
    pset(node.param,clamp((x-x0)/scale-node.attack,0,32000))
  elseif node.point=='R' then
    pset(node.param,clamp((x-x0)/scale-node.attack-node.decay-450,0,32000))
  elseif node.point=='S' then
    local lvl=clamp((node.bottom-y)/node.height,.00001,1)
    if node.mode=='AMP' then pset(3,clamp(20*math.log(lvl,10),-48,0))
    else pset(34,lvl) end
  else
    local level=clamp((node.bottom-y)/node.height,.000001,.999999)
    local target=level
    if node.point=='CD' then target=(1-level)/math.max(.000001,1-node.sustain)
    elseif node.point=='CR' then target=1-level/math.max(.000001,node.sustain) end
    target=clamp(target,.000001,.999999)
    local exponent=math.log(target)/math.log(.5)
    pset(node.param,clamp(-math.log(exponent)/3,-1,1))
  end
end
local function new_mouse()
  local x=(gfx.mouse_x-origin_x)/render_scale
  local y=(gfx.mouse_y-origin_y)/render_scale
  local held=(gfx.mouse_cap & 1)~=0
  local right=(gfx.mouse_cap & 2)~=0
  local justdown=held and not ui_mouse_was_down
  local rightdown=right and not ui_right_was_down
  if gfx.mouse_wheel~=0 then
    if ui_view=='PRESETS' and y>468 and y<695 then
      preset_scroll=clamp(preset_scroll-(gfx.mouse_wheel>0 and 1 or -1),0,math.max(0,#filtered_presets()-6))
    elseif source and x>44 and x<1034 and y>=160 and y<=288 then
      zoom_at(301+(x-44)/990*716,gfx.mouse_wheel)
    end
    gfx.mouse_wheel=0
  end
  if rightdown then
    for _,c in ipairs(ui_controls) do
      if c.kind=='knob' and (x-c.x)^2+(y-c.y)^2<c.r^2 and editable_params[c.param] then
        edit_numeric_param(c.param)
        break
      end
    end
  end
  if justdown then
    ui_drag=nil
    local action
    for _,c in ipairs(ui_controls) do
      if c.kind=='button' and x>=c.x and x<=c.x+c.w and y>=c.y and y<=c.y+c.h then
        action=c.action;break
      end
    end
    if action then new_button(action)
    else
      for _,c in ipairs(ui_envnodes) do
        if math.abs(x-c.x)<12 and math.abs(y-c.y)<15 then
          ui_drag={kind='env',node=c};break
        end
      end
      if not ui_drag then
        for _,c in ipairs(ui_controls) do
          if c.kind=='knob' and (x-c.x)^2+(y-c.y)^2<c.r^2 then
            ui_drag={kind='knob',node=c};break
          elseif c.kind=='wave' and (x-c.x)^2+(y-c.y)^2<c.r^2 then
            ui_drag={kind='wave',node=c};break
          end
        end
      end
      if ui_drag then
        ui_start_y=y;ui_start_x=x
        if ui_drag.kind=='knob' then ui_start_value=val(ui_drag.node.param) end
        ui_trim_initial_start=val(17)
        ui_trim_initial_end=val(18)
      end
    end
  end
  if held and ui_drag then
    local item=ui_drag.node
    if ui_drag.kind=='env' then
      env_pointer(item,x,y)
    elseif ui_drag.kind=='wave' and source then
      local norm=clamp(view_start+(x-44)/990*view_span,0,1)*10000
      local minspan=math.max(20,math.ceil(4096/source.frames*10000))
      if item.part=='start' then pset(17,clamp(norm,0,val(18)-minspan))
      else pset(18,clamp(norm,val(17)+minspan,10000)) end
    elseif ui_drag.kind=='knob' then
      local id=item.param
      local diff=(ui_start_y-y)/210
      local value=ui_start_value
      if id==28 then
        value=20*1000^clamp(math.log(math.max(20,value)/20)/math.log(1000)+diff,0,1)
      elseif id==1 or id==2 or id==4 or id==32 or id==33 or id==35 then
        value=norm_to_ms(ms_to_norm(value)+diff)
      else
        value=clamp(value+diff*(item.max-item.min),item.min,item.max)
      end
      if id==39 or id==6 or id==7 or id==16 then value=math.floor(value+.5) end
      pset(id,value)
      if id==9 and value>0 and val(6)>1 then pset(6,1) end
    end
  end
  if not held and ui_mouse_was_down and ui_drag and ui_drag.kind=='wave' then
    update_model_after_trim()
  end
  if not held then ui_drag=nil end
  ui_mouse_was_down=held
  ui_right_was_down=right
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
  new_mouse()
  draw_new()
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
-- Restore this track's saved PCM FIRST. A selected item in the arrangement
-- must not silently replace the existing MOONAR patch every time GUI opens.
local _,saved_path=reaper.GetSetMediaTrackInfo_String(track,
  'P_EXT:MOONAR_CURVELAB_SAMPLE_PATH','',false)
local _,saved_label=reaper.GetSetMediaTrackInfo_String(track,
  'P_EXT:MOONAR_CURVELAB_SAMPLE_LABEL','',false)
local restore_start,restore_end=val(17),val(18)
local restored=false
if saved_path and saved_path~='' then
  local file=io.open(saved_path,'rb')
  if file then
    file:close()
    import_path(saved_path)
    if source then restored=true end
  else
    status='Cached sample not found; use LOAD SAMPLE to relink it.'
  end
end
if not restored and (not saved_path or saved_path=='') then
  local bridge_audio=restore_audio_from_bridge()
  if bridge_audio then
    import_audio(bridge_audio,saved_label~='' and saved_label or 'RECOVERED AUDIO')
    restored=source~=nil
  end
end
if restored then
  pset(17,restore_start);pset(18,restore_end)
  update_model_after_trim()
  if saved_label and saved_label~='' then file_label=saved_label end
  status='Restored saved sample, waveform and DSP settings from this track.'
elseif selected and (not saved_path or saved_path=='') then
  -- Only auto-import an arrangement item when the patch has no saved sample.
  local ok_import,audio,reading_error=pcall(take_audio,selected)
  if ok_import and audio then
    audio.total_length=audio.length
    import_audio(audio,'SELECTED REAPER ITEM')
  else
    status='Select audio or drop a file: '..tostring(ok_import and reading_error or audio)
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


-- One visible GUI. Do not expose a second JSFX editor window on startup.
if type(reaper.TrackFX_Show)=='function' then
  reaper.TrackFX_Show(track,fx,2)
end
local _,bound_track_name=reaper.GetSetMediaTrackInfo_String(track,'P_NAME','',false)
gfx.init('MOONAR CURVE LAB 0.8.3 | '..((bound_track_name and bound_track_name~='') and bound_track_name or 'Selected track'),1080,930,0,110,70)
reaper.defer(frame)
