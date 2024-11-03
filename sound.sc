"Hello World!".postln;
s.boot;

// OSC CONN
~n1 = NetAddr.new("127.0.0.1", 12000);

// PICK SERVER OPTIONS BASED ON ENVIRONMENT
(
  // MACBOOK
~mbMcOpts = ServerOptions.new;
// 
~mbMcOpts.memSize = 8192*4;
// ~mbMcOpts.outDevice = 'MacBook Pro Speakers';
~mbMcOpts.outDevice = 'External Headphones';
~mbMcOpts.numInputBusChannels = 0;
~mbMcOpts.numOutputBusChannels = 18;
s.options = ~mbMcOpts;
s.reboot;
)

(
  // SCARLET 
~scltMcOpts = ServerOptions.new;
// ~scltMcOpts.memSize = 8192*2;
~scltMcOpts.memSize = 8192*4;
~scltMcOpts.outDevice = 'Scarlett 18i8 USB';
~scltMcOpts.numOutputBusChannels = 18;
s.options = ~scltMcOpts;
s.reboot
)

// CLEAT (MOTU 16A)
ServerOptions.outDevices; 
(
~cltMcOpts = ServerOptions.new;
~cltMcOpts.memSize = 8192*4;
~cltMcOpts.outDevice = '16A';
~cltMcOpts.numOutputBusChannels = 18;
s.options = ~cltMcOpts;
s.reboot
)

// Linux
(
~lnxMcOpts = ServerOptions.new;
~lnxMcOpts.memSize = 8192*4;  // twice default
~lnxMcOpts.numOutputBusChannels = 18;
s.options = ~lnxMcOpts;
s.reboot;
)

// SERVER DISPLAY
(
s.makeWindow;
ServerMeter.new(s, 0, 17);
s.plotTree;
)

// Test sound
{ [SinOsc.ar(440, 0, 0.2), SinOsc.ar(442, 0, 0.2)] }.play;


// LOAD DATA
(
  // mac
~csvPath = "~/Documents/music/supercollider/sc/heliotropic_patterns/data/denton_tx_2010.csv".standardizePath;
//Linux
//  ~csvPath = "~/Documents/personal/music/sc/heliotropic_patterns/data/denton_tx_2010.csv".standardizePath;
~radIndex = 5; // GHI
~data = CSVFileReader.readInterpret(~csvPath, startRow:3);
// start in file of Jan, Feb, Mar, etc
// using actual start line to make it easy to verify in file, but that means we need to subtract offset later
~monthStartRows = [4,1492,2836,4324,5764,7252,8692,10180,11668,13108,14596,16036];
// weidly hard to extract this column once dealing w/ a 2-D array, so do it now
~rads = Array.fill(~data.size, { arg i; ~data[i][~radIndex] });
~rowOffset = 4;
~months = Array.fill(12, 
  {arg i; 
    var idx = ~monthStartRows[i]-~rowOffset, numSamples=48*28; // 48 samples per day, 28 days in a "month"
    ~rads[idx..idx+numSamples];
  });
);


~months[1].plot();
~months[6].plot();
~months[11].plot();
// check correctness w/ full rows
(
~monthsFullData = Array.fill(12, 
  {arg i; 
    var idx = ~monthStartRows[i]-~rowOffset, numSamples=48*28; // 48 samples per day, 28 days in a "month"
    ~data[idx..idx+numSamples];
  });
);
~monthsFullData[6][0]


// SYNTHS
(
 SynthDef(\blipDelayNoPan, { | panBus, freq=440, numHarms=0, decayTime=2, amp=0.1|
    var sig, env, envGen;
    sig = Blip.ar(freq, numHarms, 0.5); // blip is super intense, so keep initial mul low
    env = Env.perc;
    envGen = EnvGen.kr(env);
    sig = sig * envGen;
    sig = Decay.ar(sig, 0.2, 0.3);
    sig = CombN.ar(sig, 0.2, 0.2, decayTime, 0.3);
    sig = sig * amp;
    FreeSelf.kr(TDelay.kr(Done.kr(envGen), decayTime));
    Out.ar(panBus, sig);
}).add;

SynthDef(\fixedLocMcPanner, { |panBus, pan=0 |
  Out.ar(pan, In.ar(panBus, 1));
}).add;

SynthDef(\stereoPanner, { |panBus, pan=0|
  var input;
  input = In.ar(panBus, 1);
  input = Pan2.ar(input, pan); 
  Out.ar([0, 1], [input]);
}).add;
)

(
  // SET THIS
~mode=\preview;
//  ~mode=\cleat;

~jan1 = ~months[0][48*0..48*0+47];
~mulVals = ~jan1;
~mulList = List.new; 
// when kept in sync with amp Pbind, this determines how quickly voices get cycled through
~sampleRepeat = 48;  // 48 is "realtime"   
~mulVals.do({arg item, i; 
  ~mulList = ~mulList ++ List.newClear(~sampleRepeat).fill(item.linlin(0, ~mulVals.maxItem, 0, 1));
}); 

// good test we won't blow our ears out
~mulList.maxItem.postln;

// think this is best: loudest on ouside, donut!
// also nice that it starts mid-volume
~cleatPans = [0,3,12,15,1,7,8,14,5,6,9,10];
// TODO: what is this?
~eventCounts = Array.fill(12, {0});
~silenceCounts = Array.fill(12, {0});
~voicesPlaying = nil;
~voiceStates = Dictionary();

~pbinds = Array.fill(12, {
  arg i;
  var detune,
    decayTime,
    numHarms, 
    durs,
    sectionOffset = 0, // 0.0 - 3.0
    scale = Scale.majorPentatonic,
    group = Group.new(),
    panBus = Bus.audio(s),
    vcGroup,
    mcPanVal; 
  vcGroup = case 
    {i >= 0 && i < 4} {1}
    {i >= 4 && i < 8} {2}
    {i >= 8 && i < 12} {3};
  detune = switch(vcGroup, 1, {0.025.rand}, 2, {0.025.rand + 0.025}, 3, {0.05.rand + 0.05});    
  decayTime = 7;
  numHarms = switch(vcGroup, 1, {rrand(0,3)}, 2, {rrand(4,6)}, 3, {rrand(7,10)});
  durs = {var dur1, dur2, vals; 
    vals = [0.05, 0.1, 0.2, 0.4, 0.8];
    dur1 = vals.choose; 
    dur2 = vals.choose;
    Array.fill(48, dur1) ++ Array.fill(48, dur2);
  }.value;
  scale.tuning = Tuning.new(scale.tuning.semitones + detune);
  // stereo preview version: voice sent to out, where out = voice num 0-indexed+4, e.g., vc1 goes to out 4 
  if (~mode==\preview) {Synth.tail(group, \stereoPanner, [\panBus, panBus, \pan, ((i/11)*2)-1])};
  mcPanVal = if (~mode==\preview) {i+4} {~cleatPans[i]};
  Synth.tail(group, \fixedLocMcPanner, [\panBus, panBus, \pan, mcPanVal]);
  Pbind(
        \instrument, \blipDelayNoPan,
        \decayTime, decayTime,
        \scale, Pfunc({ scale }, inf),
        \degree, Pseq(all{: if(x == 0, {\rest}, {x.asInteger}), x <- ~months[i].linlin(0, ~rads.maxItem, 0, 25)}, inf),
        \dur, Pseq(durs, inf), 
        \root, 0,
        \numHarms, numHarms, 
        // this is the key to changing "sections" 
        // stagger amp curve of each voice as it iterates through mulList so that ~4 voices are always audible
        \amp, 0.1 
          * Pseq(~mulList.rotate((i*4)*~sampleRepeat+((~mulList.size/3)*sectionOffset).asInteger), inf) 
          // lower harmonic voices tend to clip, esp. when played fast
          * Pif(Pkey(\numHarms) < 3, 0.8, 1), 
        // \test, Pif(Pkey(\numHarms) < 3, "lessthan 3".postln, "nope"),
        \countEventsAndSilences, Pfunc {|ev| 
          if (ev['amp'] < 0.001, {~silenceCounts[i] = ~silenceCounts[i]+1}, {"noop"}); 
            ~eventCounts[i]=~eventCounts[i]+1},
        \trackVoiceStates, Pfunc {if (~eventCounts[i] >= 48, 
          { var vcName = ("vc" ++ (i+1).asString);
            if (~silenceCounts[i] >= 47, {
              ~voiceStates.put(vcName, \off);
             },{
              ~voiceStates.put(vcName, \on);
              });
              ~eventCounts[i] = 0;
              ~silenceCounts[i] = 0;
          }, {"noop"}) },
        \sendOsc, Pfunc { |e| 
             var deg, msg, oscDest;
            oscDest = "/vc" ++ (i+1); 
            deg = e[\degree]; 
            if (deg == \rest, 
                {
                  ~n1.sendMsg(oscDest, 0);
                },  
                {
                  ~n1.sendMsg(oscDest, deg);
                } 
            );
        },
        \panBus, panBus,
        \group, group,
        \addAction, 0,  // default, but specify
      ).play(quant:1);
    });

    ~voiceStatesToOsc = Routine({
        loop {
            // "Will wait ".postln;
            ~voicesPlaying = ~voiceStates.select( 
              {|item| item==\on}).keys.asArray.sort(
                // sort by number part of voice name for readability
              {arg a, b; a[2..].asInteger < b[2..].asInteger });
            ~voicesPlaying.postln;
            ~n1.sendMsg("/setRecvVoices", 
              *Array.fill(~voicesPlaying.size, {|i| "/" ++ ~voicesPlaying[i].asString}));
            1.yield;
        }
    }).play;  

    // restart if all voices happen to be silent for too long
    // expect this to be triggered at the beginning
  ~awaken = Routine({
      var silenceCount, threshold;
      silenceCount = 4;
      threshold = 10;
      loop {
        if (~voicesPlaying.isEmpty, {silenceCount = silenceCount+1});
        if (silenceCount > threshold, {
          "this is golden!".postln; 
          (0..11).do({arg i; ~pbinds[i].start(quant:1)}); 
          silenceCount=0
        });
        1.yield;
      }
  }).play;  
)


~eventCounts 
~silenceCounts
~voiceStates.getPairs;
// stop all
(0..11).do({arg i; ~pbinds[i].stop; ~voicesPlaying.removeAll })
(0..11).do({arg i; ~pbinds[i].stop; if (i==11){"do the thing".postln}})


// stop evens
(0..11).do({arg i; if (i%2 == 0) {~pbinds[i].stop}})
// resume evens
(0..11).do({arg i; if (i%2 == 0) {~pbinds[i].resume}})
// restart all
(0..11).do({arg i; ~pbinds[i].start(quant:1)})
// resume all
(0..11).do({arg i; ~pbinds[i].resume(quant:1)})
// solo 
{arg vc; (0..11).do({arg i; if (i != vc) {~pbinds[i].stop}})}.value(6);
// stop 1
~pbinds[6].stop
(0..5).do({arg i; ~pbinds[i].stop})


// OSC Processing Control
~n1.sendMsg("/gridSize", 1);
~n1.sendMsg("/gridSize", 2);
~n1.sendMsg("/gridSize", 3);
~n1.sendMsg("/gridSize", 8);
~n1.sendMsg("/gridSize", 7.rand+1);

~n1.sendMsg("/changeImgs");


~n1.sendMsg("/setRecvVoices", *["/vc5", "/vc6", "/vc7", "/vc8"]);
~n1.sendMsg("/setRecvVoices", "/vc5", "/vc6", "/vc7", "/vc8", "/vc9");
~n1.sendMsg("/setRecvVoices", "/vc6", "/vc7", "/vc7", "/vc9");
~n1.sendMsg("/setRecvVoices", "/vc6", "/vc7", "/vc7", "/vc9", "/10");
~n1.sendMsg("/setRecvVoices", "/vc1", "/vc2", "/vc3", "/vc4");
~n1.sendMsg("/setRecvVoices"); 

