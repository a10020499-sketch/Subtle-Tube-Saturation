function generateSpectrumProbes(outDir, fs)
%GENERATESPECTRUMPROBES  Compact probe set for looking at the processing in a DAW
%   spectrum analyser. Deliberately short and at the program-material rate
%   (48 kHz by default) so probes and music can sit on the same timeline.
%
%   Each probe answers one question you can SEE:
%     P1_tone_1k          harmonic series of a mid tone - H2/H3/H4... spacing and
%                         decay is the "voice" of the curve (odd-only = symmetric)
%     P2_tone_100         same at low frequency, where most saturation happens
%     P3_tone_5k          a high tone: shows what the HF band is or is not doing
%     P4_twotone_IMD      1000 + 1100 Hz. Nonlinearity puts products at 100 Hz,
%                         900, 1200, 2100... The INHARMONIC ones are the "fizz";
%                         this is the probe that makes it visible
%     P5_twotone_HF_IMD   6500 + 7150 Hz - the same test up where the hf_clean
%                         split acts, so you can see the split working
%     P6_sweep_20_20k     log sweep: in a spectrogram, harmonics appear as extra
%                         curved lines above the fundamental
%     P7_pink             pink noise: overall tonal balance / tilt
%     P8_decay_tail       exponentially decaying noise bursts - a reverb-tail
%                         stand-in for judging low-level detail and "air"
%
%   All probes are -12 dBFS peak (except the tail probe) so they sit in the same
%   part of the curve as real programme material.

    if nargin<1||isempty(outDir)
        here=fileparts(mfilename('fullpath'));
        outDir=fullfile(fileparts(here),'data','probes');
    end
    if nargin<2||isempty(fs); fs=48000; end
    if ~exist(outDir,'dir'); mkdir(outDir); end
    rng(4242,'twister');
    A = 10^(-12/20);
    W = @(n) tukeywin(n, 0.02);                       % gentle edges, no clicks

    dur=3; n=round(dur*fs); t=(0:n-1)'/fs; w=W(n);
    write(outDir,'P1_tone_1k.wav',   A*sin(2*pi*1000*t).*w, fs);
    write(outDir,'P2_tone_100.wav',  A*sin(2*pi*100 *t).*w, fs);
    write(outDir,'P3_tone_5k.wav',   A*sin(2*pi*5000*t).*w, fs);

    % two-tone IMD probes (equal amplitude, sum kept at -12 dBFS peak)
    tt = @(f1,f2) A*0.5*(sin(2*pi*f1*t)+sin(2*pi*f2*t)).*w;
    write(outDir,'P4_twotone_IMD_1000_1100.wav', tt(1000,1100), fs);
    write(outDir,'P5_twotone_HF_IMD_6500_7150.wav', tt(6500,7150), fs);

    % log sweep 20 Hz - 20 kHz
    T=8; N=round(T*fs); ts=(0:N-1)'/fs; f1=20; f2=20000;
    L=T/log(f2/f1); s=sin(2*pi*f1*L*(exp(ts/L)-1));
    fN=round(0.02*fs); r=0.5-0.5*cos(pi*(0:fN-1)'/fN);
    s(1:fN)=s(1:fN).*r; s(end-fN+1:end)=s(end-fN+1:end).*flipud(r);
    write(outDir,'P6_sweep_20_20k.wav', A*s, fs);

    % pink noise
    np=round(4*fs);
    if exist('pinknoise','file'); pn=pinknoise(np); else; pn=cumsum(randn(np,1)); pn=pn/max(abs(pn)); end
    pn=pn(:)-mean(pn); pn=pn/max(abs(pn))*A;
    write(outDir,'P7_pink.wav', pn.*W(np), fs);

    % decaying noise bursts - reverb-tail stand-in for low-level detail / air
    nb=round(6*fs); x=zeros(nb,1);
    for k=0:2
        st=round(k*2*fs)+1;
        len=round(1.8*fs); env=exp(-(0:len-1)'/(0.45*fs));
        if exist('pinknoise','file'); b=pinknoise(len); else; b=randn(len,1); end
        b=b(:)/max(abs(b));
        x(st:st+len-1)=x(st:st+len-1)+A*b.*env;
    end
    write(outDir,'P8_decay_tail.wav', x, fs);

    fprintf('generateSpectrumProbes: 8 probes written to %s (fs=%d)\n', outDir, fs);
end

function write(d,n,x,fs)
    audiowrite(fullfile(d,n), max(min(x,1),-1), fs, 'BitsPerSample',24);
end
