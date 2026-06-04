function [ySynth, synthData] = vib_analyze_harmonics_resynthesize_V27(params, opts)
%VIB_ANALYZE_HARMONICS_RESYNTHESIZE_V27  Additive AM/FM resynthesis pipeline.
%
% Options patch: fs is read from opts.fs or params.sourceFs; it is not a positional input.
%
% Clean use:
%   synthOpts.fs = fs;
%   [ySynth, synthData] = vib_analyze_harmonics_resynthesize_V27(S.params, synthOpts);
%
% This function intentionally does not use the original audio. It only uses
% the parameter struct produced by vib_analyze_harmonics_analysis_V27.m.
%
% Model:
%   y(t) = sum_k A_k(t) cos(theta_k(t))
%
% where A_k(t) is rebuilt from the stored compact no-vibrato envelope
% model and then multiplied by a fitted sinusoidal AM gain, and theta_k(t) is accumulated from k*f0 plus a
% fitted sinusoidal FM term. Stored vibrato start/end times gate the AM/FM
% modulation and can be overridden with opts.vibratoStartSec/EndSec.

arguments
    params (1,1) struct

    % Sampling rate control
    opts.fs (1,1) double = NaN

    % Target controls
    opts.targetDurationSec double = []
    opts.targetF0Hz double = []
    opts.durationMode (1,:) char = 'preserveAttackRelease' % 'preserveAttackRelease' or 'stretchEnvelope'
    opts.scaleFmWithPitch (1,1) logical = true

    % Vibrato timing controls. Empty start/end values use the start/end
    % estimated during analysis and stored in params. The explicit
    % opts.vibratoStartSec/EndSec values are target-time seconds.
    opts.vibratoUseStoredWindow (1,1) logical = true
    opts.vibratoStartSec double = []
    opts.vibratoEndSec double = []
    opts.vibratoStartOffsetSec (1,1) double = 0
    opts.vibratoEndOffsetSec (1,1) double = 0
    opts.vibratoFadeSec (1,1) double = 0.05
    opts.vibratoDepthScale (1,1) double = 1

    % Resynthesis controls
    opts.resynthUsePhaseIntegral (1,1) logical = true
    opts.resynthUseAmOffset (1,1) logical = false
    opts.resynthUseFmOffset (1,1) logical = false
    opts.resynthClampAmplitude (1,1) logical = true
    opts.resynthAnalyticAmpScale (1,1) double = NaN
    opts.resynthNormalize (1,1) logical = false
    opts.resynthPeak (1,1) double = 0.95

    % Stochastic naturalness controls. These are resynthesis-only; they do
    % not require or store the original audio.
    opts.noiseEnable (1,1) logical = false
    opts.noiseLevelDb (1,1) double = -42       % noise RMS relative to clean synthesized RMS
    opts.noiseMode (1,:) char = 'filtered'     % 'white', 'highpass', 'filtered', or 'dark'
    opts.noiseHighpassHz (1,1) double = 1200
    opts.noiseLowpassHz (1,1) double = 14000
    opts.noiseEnvFollow (1,1) logical = true
    opts.noiseEnvPower (1,1) double = 0.70
    opts.noiseAttackBoost (1,1) double = 0.0
    opts.noiseAttackBoostMs (1,1) double = 25
    opts.noiseSeed (1,1) double = 1            % set NaN for non-repeatable noise

    % Optional low-rate random frequency jitter, mostly useful for upper
    % partials. Keep off for strict parameter verification tests.
    opts.freqJitterEnable (1,1) logical = false
    opts.freqJitterStdHz (1,1) double = 0.15
    opts.freqJitterLowpassHz (1,1) double = 12
    opts.freqJitterMinHarmonic (1,1) double = 6
    opts.freqJitterUpperPower (1,1) double = 1.0
    opts.freqJitterEnvFollow (1,1) logical = true

    % Output controls
    opts.playAudio (1,1) logical = false
    opts.saveAudio (1,1) logical = false
    opts.outputPath (1,:) char = ''

    % Plot controls
    opts.plot_waveform (1,1) logical = false
    opts.plot_amfm (1,1) logical = false
    opts.plot_harmonic_controls (1,1) logical = false
end

fs = opts.fs;
if ~isfinite(fs) || fs <= 0
    if isfield(params, 'sourceFs') && isfinite(params.sourceFs) && params.sourceFs > 0
        fs = params.sourceFs;
    else
        error('Set opts.fs, or include params.sourceFs.');
    end
end

sourceF0 = local_get_scalar(params, 'f0Hz', NaN);
if isempty(opts.targetF0Hz)
    targetF0 = sourceF0;
else
    targetF0 = opts.targetF0Hz;
end
if ~isfinite(targetF0) || targetF0 <= 0
    error('Provide opts.targetF0Hz or params.f0Hz.');
end

sourceDur = local_get_source_duration(params);
if ~isfinite(sourceDur) || sourceDur <= 0
    error('V27 params must include sourceFs and sourceNumSamples, or a valid legacy sourceDurationSec.');
end

if isempty(opts.targetDurationSec)
    targetDur = sourceDur;
else
    targetDur = opts.targetDurationSec;
end
if ~isfinite(targetDur) || targetDur <= 0
    error('opts.targetDurationSec must be positive.');
end

N = max(1, round(targetDur * fs));
t = (0:N-1).' / fs;
sourceTimeMap = local_source_time_map(t, targetDur, sourceDur, params, opts.durationMode);

K = numel(params.harm);
yHarm = zeros(N, K);
harmSynth = repmat(struct(), K, 1);

ampScaleDefault = local_get_scalar(params, 'analyticAmpScale', 2);
if isfinite(opts.resynthAnalyticAmpScale) && opts.resynthAnalyticAmpScale > 0
    ampScaleDefault = opts.resynthAnalyticAmpScale;
end

if opts.scaleFmWithPitch && isfinite(sourceF0) && sourceF0 > 0
    fmPitchScale = targetF0 / sourceF0;
else
    fmPitchScale = 1;
end

rngCleanup = local_seed_rng(opts.noiseSeed); %#ok<NASGU>

for ii = 1:K
    hk = params.harm(ii);
    k = local_get_scalar(hk, 'k', ii);

    % Initialize every harmonic entry so plotting/debug helpers can safely
    % skip disabled harmonics without missing-field errors.
    harmSynth(ii).k = k;
    harmSynth(ii).Ak = zeros(N,1);
    harmSynth(ii).fkHz = k * targetF0 * ones(N,1);
    harmSynth(ii).amGain = ones(N,1);
    harmSynth(ii).amSin = zeros(N,1);
    harmSynth(ii).fmSinHz = zeros(N,1);
    harmSynth(ii).freqJitterHz = zeros(N,1);
    harmSynth(ii).vibratoGate = zeros(N,1);
    harmSynth(ii).vibratoWindow = struct();
    harmSynth(ii).carrierPhaseRad = zeros(N,1);
    harmSynth(ii).phiKtRad = zeros(N,1);
    harmSynth(ii).phaseOffsetRad = 0;
    harmSynth(ii).envFit = zeros(N,1);
    harmSynth(ii).amModel = local_get_model(struct(), 'amModel');
    harmSynth(ii).fmModel = local_get_model(struct(), 'fmModel');

    if isfield(hk, 'enabled') && ~hk.enabled
        continue;
    end

    [envFit, envSourceTime] = local_get_envelope(hk, params, sourceDur);
    envFitTarget = interp1(envSourceTime, envFit, sourceTimeMap, 'pchip', 0);
    envFitTarget(~isfinite(envFitTarget)) = 0;
    envFitTarget = max(envFitTarget(:), 0);

    ampScale = local_get_scalar(hk, 'ampScale', ampScaleDefault);
    if ~isfinite(ampScale) || ampScale <= 0
        ampScale = ampScaleDefault;
    end
    envActual = ampScale * envFitTarget;

    [vibratoGate, vibratoWindow] = local_make_vibrato_gate(t, sourceTimeMap, hk, params, sourceDur, targetDur, opts);

    amModel = local_get_model(hk, 'amModel');
    amSin = amModel.amp * sin(2*pi*amModel.freqHz*t + amModel.phaseRad);
    if opts.resynthUseAmOffset
        amSin = amSin + amModel.offset;
    end
    amSin = opts.vibratoDepthScale * amSin .* vibratoGate;
    amGain = 1 + amSin;
    if opts.resynthClampAmplitude
        amGain = max(amGain, 0);
    end
    Ak = envActual .* amGain;

    fmModel = local_get_model(hk, 'fmModel');
    fmSinHz = fmModel.amp * sin(2*pi*fmModel.freqHz*t + fmModel.phaseRad);
    if opts.resynthUseFmOffset
        fmSinHz = fmSinHz + fmModel.offset;
    end
    fmSinHz = opts.vibratoDepthScale * fmPitchScale * fmSinHz .* vibratoGate;

    freqJitterHz = local_make_freq_jitter(N, fs, k, K, envActual, opts);

    fkHz = k * targetF0 + fmSinHz + freqJitterHz;
    fkHz = min(max(fkHz, eps), 0.49 * fs);

    phaseOffset = local_get_scalar(hk, 'phaseOffsetRad', 0);
    if opts.resynthUsePhaseIntegral
        carrierPhase = phaseOffset + [0; cumsum(2*pi*fkHz(1:end-1)/fs)];
    else
        carrierPhase = 2*pi*fkHz.*t + phaseOffset;
    end
    phiKt = carrierPhase - 2*pi*fkHz.*t;

    yk = Ak .* cos(carrierPhase);
    yHarm(:,ii) = yk;

    harmSynth(ii).k = k;
    harmSynth(ii).Ak = Ak;
    harmSynth(ii).fkHz = fkHz;
    harmSynth(ii).amGain = amGain;
    harmSynth(ii).amSin = amSin;
    harmSynth(ii).fmSinHz = fmSinHz;
    harmSynth(ii).freqJitterHz = freqJitterHz;
    harmSynth(ii).vibratoGate = vibratoGate;
    harmSynth(ii).vibratoWindow = vibratoWindow;
    harmSynth(ii).carrierPhaseRad = carrierPhase;
    harmSynth(ii).phiKtRad = phiKt;
    harmSynth(ii).phaseOffsetRad = phaseOffset;
    harmSynth(ii).envFit = envFitTarget;
    harmSynth(ii).amModel = amModel;
    harmSynth(ii).fmModel = fmModel;
end

yClean = sum(yHarm, 2);
[yNoise, noiseInfo] = local_make_output_noise(yClean, harmSynth, fs, opts);
ySynth = yClean + yNoise;

normalizationGain = 1;
if opts.resynthNormalize
    pk = max(abs(ySynth));
    if pk > 0
        normalizationGain = opts.resynthPeak / pk;
        ySynth = normalizationGain * ySynth;
        yClean = normalizationGain * yClean;
        yNoise = normalizationGain * yNoise;
        yHarm = normalizationGain * yHarm;
        noiseInfo.outputNormalizationGain = normalizationGain;
        if isfield(noiseInfo, 'targetRms'), noiseInfo.targetRms = normalizationGain * noiseInfo.targetRms; end
        if isfield(noiseInfo, 'noiseRms'), noiseInfo.noiseRms = normalizationGain * noiseInfo.noiseRms; end
        if isfield(noiseInfo, 'cleanRms'), noiseInfo.cleanRms = normalizationGain * noiseInfo.cleanRms; end
        for ii = 1:K
            if isfield(harmSynth(ii), 'Ak') && ~isempty(harmSynth(ii).Ak)
                harmSynth(ii).Ak = normalizationGain * harmSynth(ii).Ak;
            end
        end
    end
end

synthData = struct();
synthData.version = 'V27_resynthesis';
synthData.method = 'additive_AMFM_from_params';
synthData.equation = 'y(t)=sum_k A_k(t) cos(theta_k(t)); theta_k(t)=integral 2*pi*f_k(t) dt';
synthData.fs = fs;
synthData.t = t;
synthData.y = ySynth;
synthData.yClean = yClean;
synthData.yNoise = yNoise;
synthData.yHarm = yHarm;
synthData.harm = harmSynth;
synthData.sourceF0Hz = sourceF0;
synthData.targetF0Hz = targetF0;
synthData.sourceDurationSec = sourceDur;
synthData.targetDurationSec = targetDur;
synthData.durationMode = opts.durationMode;
synthData.sourceTimeMap = sourceTimeMap;
synthData.fmPitchScale = fmPitchScale;
synthData.normalizationGain = normalizationGain;
synthData.analyticAmpScale = ampScaleDefault;
synthData.noise = noiseInfo;
synthData.vibratoTiming = local_collect_vibrato_timing(harmSynth);

if opts.plot_waveform
    local_plot_synth_waveform(ySynth, fs);
end
if opts.plot_amfm
    local_plot_synthesis_amfm(params, synthData);
end
if opts.plot_harmonic_controls
    local_plot_harmonic_controls(synthData);
end

if opts.saveAudio || ~isempty(opts.outputPath)
    if isempty(opts.outputPath)
        error('Set opts.outputPath when opts.saveAudio=true.');
    end
    audiowrite(opts.outputPath, ySynth, fs);
    synthData.outputPath = opts.outputPath;
end

if opts.playAudio
    soundsc(ySynth, fs);
end
end

% ===================== Local helpers =====================

function cleanupObj = local_seed_rng(seed)
cleanupObj = [];
if isnumeric(seed) && isscalar(seed) && isfinite(seed)
    oldState = rng;
    rng(seed, 'twister');
    cleanupObj = onCleanup(@() rng(oldState));
end
end

function jitterHz = local_make_freq_jitter(N, fs, k, K, envActual, opts)
jitterHz = zeros(N,1);
if ~opts.freqJitterEnable || ~isfinite(opts.freqJitterStdHz) || opts.freqJitterStdHz <= 0
    return;
end
minH = max(1, round(opts.freqJitterMinHarmonic));
if k < minH
    return;
end
if K <= minH
    harmScale = 1;
else
    harmScale = (k - minH) / max(1, K - minH);
    harmScale = min(max(harmScale, 0), 1) ^ max(opts.freqJitterUpperPower, 0);
end
if harmScale <= 0
    return;
end
raw = randn(N,1);
raw = local_one_pole_lowpass(raw, opts.freqJitterLowpassHz, fs);
raw = local_remove_mean(raw);
rawRms = local_rms(raw);
if rawRms <= 0
    return;
end
raw = raw / rawRms;

if opts.freqJitterEnvFollow
    env = envActual(:);
    if numel(env) ~= N || max(abs(env)) <= 0
        env = ones(N,1);
    else
        env = max(env, 0);
        env = env ./ max(env + eps);
    end
else
    env = ones(N,1);
end
jitterHz = opts.freqJitterStdHz * harmScale * raw .* env;
jitterHz(~isfinite(jitterHz)) = 0;
end

function [yNoise, info] = local_make_output_noise(yClean, harmSynth, fs, opts)
N = numel(yClean);
yNoise = zeros(N,1);
info = struct('enabled',false, ...
    'levelDb',opts.noiseLevelDb, ...
    'actualLevelDb',-Inf, ...
    'mode',opts.noiseMode, ...
    'highpassHz',opts.noiseHighpassHz, ...
    'lowpassHz',opts.noiseLowpassHz, ...
    'envFollow',opts.noiseEnvFollow, ...
    'envPower',opts.noiseEnvPower, ...
    'attackBoost',opts.noiseAttackBoost, ...
    'targetRms',0, ...
    'noiseRms',0, ...
    'cleanRms',local_rms(yClean), ...
    'outputNormalizationGain',1);

if ~opts.noiseEnable || ~isfinite(opts.noiseLevelDb) || opts.noiseLevelDb <= -300 || N < 1
    return;
end

cleanRms = local_rms(yClean);
if cleanRms <= 0
    return;
end

raw = randn(N,1);
raw = local_color_noise(raw, fs, opts.noiseMode, opts.noiseHighpassHz, opts.noiseLowpassHz);
raw = local_remove_mean(raw);

env = local_make_noise_envelope(harmSynth, yClean, fs, opts);
raw = raw .* env;
raw = local_remove_mean(raw);
rawRms = local_rms(raw);
if rawRms <= 0
    return;
end

targetRms = cleanRms * 10^(opts.noiseLevelDb/20);
yNoise = raw * (targetRms / rawRms);
noiseRms = local_rms(yNoise);

info.enabled = true;
info.targetRms = targetRms;
info.noiseRms = noiseRms;
info.cleanRms = cleanRms;
info.actualLevelDb = local_ratio_db(noiseRms, cleanRms);
end

function env = local_make_noise_envelope(harmSynth, yClean, fs, opts)
N = numel(yClean);
if ~opts.noiseEnvFollow
    env = ones(N,1);
    return;
end

env = zeros(N,1);
for ii = 1:numel(harmSynth)
    if isfield(harmSynth(ii), 'Ak') && numel(harmSynth(ii).Ak) == N
        env = env + abs(harmSynth(ii).Ak(:));
    end
end
if max(env) <= 0
    env = abs(yClean(:));
end
if max(env) <= 0
    env = ones(N,1);
else
    env = max(env, 0);
    env = env ./ max(env + eps);
end

p = max(0.05, opts.noiseEnvPower);
env = env .^ p;

if isfinite(opts.noiseAttackBoost) && opts.noiseAttackBoost > 0
    dEnv = [0; diff(env)];
    dEnv = max(dEnv, 0);
    smoothHz = 1000 / max(opts.noiseAttackBoostMs, eps);
    dEnv = local_one_pole_lowpass(dEnv, smoothHz, fs);
    if max(dEnv) > 0
        dEnv = dEnv ./ max(dEnv + eps);
        env = env .* (1 + opts.noiseAttackBoost * dEnv);
    end
end

env(~isfinite(env)) = 0;
end

function y = local_color_noise(x, fs, mode, hpHz, lpHz)
y = x(:);
mode = lower(strtrim(mode));
switch mode
    case 'white'
        % no filtering
    case 'dark'
        y = local_one_pole_lowpass(y, lpHz, fs);
    case 'highpass'
        y = y - local_one_pole_lowpass(y, hpHz, fs);
    otherwise % 'filtered'
        y = y - local_one_pole_lowpass(y, hpHz, fs);
        y = local_one_pole_lowpass(y, lpHz, fs);
end
y(~isfinite(y)) = 0;
end

function y = local_one_pole_lowpass(x, fcHz, fs)
x = x(:);
y = zeros(size(x));
if isempty(x)
    return;
end
if ~isfinite(fcHz) || fcHz <= 0
    return;
end
if fcHz >= 0.49*fs
    y = x;
    return;
end
a = exp(-2*pi*fcHz/fs);
b = 1 - a;
y(1) = b * x(1);
for n = 2:numel(x)
    y(n) = b * x(n) + a * y(n-1);
end
end

function y = local_remove_mean(x)
y = x(:);
valid = isfinite(y);
if any(valid)
    y(valid) = y(valid) - mean(y(valid));
end
y(~valid) = 0;
end

function r = local_rms(x)
x = x(:);
x = x(isfinite(x));
if isempty(x)
    r = 0;
else
    r = sqrt(mean(x.^2));
end
end

function db = local_ratio_db(num, den)
if num > 0 && den > 0
    db = 20*log10(num / den);
else
    db = -Inf;
end
end

function value = local_get_scalar(s, fieldName, defaultValue)
value = defaultValue;
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    candidate = s.(fieldName);
    if isnumeric(candidate) && isscalar(candidate)
        value = candidate;
    end
end
end

function sourceDur = local_get_source_duration(params)
% V27 stores sourceFs and sourceNumSamples; duration is derived.
sourceDur = NaN;
fsSrc = local_get_scalar(params, 'sourceFs', NaN);
Nsrc = local_get_scalar(params, 'sourceNumSamples', NaN);
if isfinite(fsSrc) && fsSrc > 0 && isfinite(Nsrc) && Nsrc > 0
    sourceDur = Nsrc / fsSrc;
    return;
end
% Backward compatibility with V20-V25-style params.
sourceDur = local_get_scalar(params, 'sourceDurationSec', NaN);
if (~isfinite(sourceDur) || sourceDur <= 0) && isfield(params, 'time') && numel(params.time) >= 2
    sourceDur = params.time(end) + median(diff(params.time));
end
end

function model = local_get_model(hk, fieldName)
model = struct('freqHz',0,'amp',0,'phaseRad',0,'offset',0, ...
    'r2',NaN,'numValid',0,'peakFreqHz',NaN,'coeff',[0;0;0]);
if ~isfield(hk, fieldName) || isempty(hk.(fieldName)) || ~isstruct(hk.(fieldName))
    return;
end
src = hk.(fieldName);
fields = fieldnames(model);
for ii = 1:numel(fields)
    f = fields{ii};
    if isfield(src, f) && ~isempty(src.(f))
        model.(f) = src.(f);
    end
end
if ~isfinite(model.freqHz) || model.freqHz < 0, model.freqHz = 0; end
if ~isfinite(model.amp), model.amp = 0; end
if ~isfinite(model.phaseRad), model.phaseRad = 0; end
if ~isfinite(model.offset), model.offset = 0; end
end

function [envFit, envTime] = local_get_envelope(hk, params, sourceDur)
% V27 preferred path: rebuild the sampled envelope from compact fit
% parameters stored in hk.envModel. The full envFit vector is no longer
% required in params.
if isfield(hk, 'envModel') && ~isempty(hk.envModel) && isstruct(hk.envModel)
    envTime = local_get_source_time_axis(params, sourceDur);
    envFit = local_rebuild_envelope_from_model(hk.envModel, envTime, sourceDur);
elseif isfield(hk, 'envFit') && ~isempty(hk.envFit)
    % Backward compatibility with V20 params.
    envFit = hk.envFit(:);
    if isfield(hk, 'envTimeSec') && numel(hk.envTimeSec) == numel(envFit)
        envTime = hk.envTimeSec(:);
    elseif isfield(params, 'time') && numel(params.time) == numel(envFit)
        envTime = params.time(:);
    else
        envTime = linspace(0, max(sourceDur - eps, 0), numel(envFit)).';
    end
else
    envTime = local_get_source_time_axis(params, sourceDur);
    envFit = zeros(numel(envTime), 1);
end
[envTime, uniqueIdx] = unique(envTime(:), 'stable');
envFit = envFit(uniqueIdx);
envFit(~isfinite(envFit)) = 0;
envFit = max(envFit(:), 0);
end

function envTime = local_get_source_time_axis(params, sourceDur)
fsSrc = local_get_scalar(params, 'sourceFs', NaN);
if isfinite(fsSrc) && fsSrc > 0
    defaultN = max(1, round(sourceDur * fsSrc));
else
    defaultN = max(1, round(sourceDur));
end
Nsrc = max(1, round(local_get_scalar(params, 'sourceNumSamples', defaultN)));
if isfinite(fsSrc) && fsSrc > 0
    envTime = (0:Nsrc-1).' / fsSrc;
else
    envTime = linspace(0, max(sourceDur - eps, 0), Nsrc).';
end
end

function envFit = local_rebuild_envelope_from_model(envModel, tEval, sourceDur)
tEval = tEval(:);
baseline = local_get_scalar(envModel, 'baseline', 0);
if ~isfinite(baseline) || baseline < 0, baseline = 0; end
envFit = baseline * ones(size(tEval));

if ~isfield(envModel, 'segments') || ~isstruct(envModel.segments)
    envFit(:) = 0;
    return;
end

lastSegmentEnd = NaN;
if isfield(envModel.segments, 'attack')
    [envFit, segEnd] = local_apply_envelope_segment(envFit, tEval, envModel.segments.attack, envModel, 'attack');
    if isfinite(segEnd), lastSegmentEnd = segEnd; end
end
if isfield(envModel.segments, 'body')
    [envFit, segEnd] = local_apply_envelope_segment(envFit, tEval, envModel.segments.body, envModel, 'body');
    if isfinite(segEnd), lastSegmentEnd = segEnd; end
end
if isfield(envModel.segments, 'release')
    rel = envModel.segments.release;
    useRelease = true;
    if isfield(rel, 'hasRelease') && ~rel.hasRelease
        useRelease = false;
    end
    if useRelease
        [envFit, segEnd] = local_apply_envelope_segment(envFit, tEval, rel, envModel, 'release');
        if isfinite(segEnd), lastSegmentEnd = segEnd; end
    elseif isfield(rel, 'tEnd') && isfinite(rel.tEnd)
        lastSegmentEnd = rel.tEnd;
    end
end

% Recreate the quick post-note taper used during analysis when the modeled
% note end is earlier than the stored source duration.
if isfinite(lastSegmentEnd) && lastSegmentEnd < max(tEval)
    idx0 = find(tEval <= lastSegmentEnd, 1, 'last');
    if isempty(idx0), y0 = baseline; else, y0 = envFit(idx0); end
    mask = tEval >= lastSegmentEnd;
    x = (tEval(mask) - lastSegmentEnd) ./ max(sourceDur - lastSegmentEnd, eps);
    x = min(max(x, 0), 1);
    envFit(mask) = y0 + (baseline - y0) .* smoothstep_poly(x, 5);
end

envFit(~isfinite(envFit)) = 0;
envFit = max(envFit, 0);
end

function [envFit, segEnd] = local_apply_envelope_segment(envFit, tEval, seg, envModel, segName) %#ok<INUSD>
segEnd = NaN;
if ~isstruct(seg) || ~isfield(seg, 'tStart') || ~isfield(seg, 'tEnd') || ...
        ~isfinite(seg.tStart) || ~isfinite(seg.tEnd)
    return;
end
segStart = seg.tStart;
segEnd = seg.tEnd;
if segEnd < segStart
    tmp = segStart; segStart = segEnd; segEnd = tmp;
end
mask = tEval >= segStart & tEval <= segEnd;
if ~any(mask)
    return;
end

[knT, knV] = local_get_env_knots(seg);
if numel(knT) < 1
    return;
elseif numel(knT) == 1 || segEnd == segStart
    envFit(mask) = max(knV(1), 0);
    return;
end

method = '';
if isfield(seg, 'model') && ~isempty(seg.model), method = lower(char(seg.model)); end
if ~isempty(strfind(method, 'smoothstep'))
    order = round(local_get_scalar(envModel, 'attackShapeOrder', 5));
    x = (tEval(mask) - segStart) ./ max(segEnd - segStart, eps);
    x = min(max(x, 0), 1);
    envFit(mask) = knV(1) + (knV(end) - knV(1)) .* smoothstep_poly(x, order);
else
    envFit(mask) = interp1(knT, knV, tEval(mask), 'pchip', 'extrap');
end
envFit(mask) = max(envFit(mask), 0);
end

function [knT, knV] = local_get_env_knots(seg)
knT = [];
knV = [];
if isfield(seg, 'knotTimes') && isfield(seg, 'knotValues')
    knT = seg.knotTimes(:);
    knV = seg.knotValues(:);
end
valid = isfinite(knT) & isfinite(knV);
knT = knT(valid);
knV = knV(valid);
if isempty(knT), return; end
[knT, ia] = unique(knT, 'stable');
knV = knV(ia);
[knT, order] = sort(knT);
knV = knV(order);
end

function y = smoothstep_poly(x, order)
switch order
    case 3
        y = x.^2 .* (3 - 2*x);
    case 5
        y = x.^3 .* (10 + x.*(-15 + 6*x));
    otherwise
        y = x.^3 .* (10 + x.*(-15 + 6*x));
end
end

function [gate, info] = local_make_vibrato_gate(t, sourceTimeMap, hk, params, sourceDur, targetDur, opts)
t = t(:);
sourceTimeMap = sourceTimeMap(:);
[startSrc, endSrc, sourceMethod] = local_get_stored_vibrato_window(hk, params, sourceDur);

if opts.vibratoUseStoredWindow
    startTarget = local_source_time_to_target_time(sourceTimeMap, t, startSrc);
    endTarget = local_source_time_to_target_time(sourceTimeMap, t, endSrc);
else
    startTarget = 0;
    endTarget = targetDur;
    sourceMethod = 'disabled_full_target';
end

if ~isempty(opts.vibratoStartSec)
    startTarget = opts.vibratoStartSec;
end
if ~isempty(opts.vibratoEndSec)
    endTarget = opts.vibratoEndSec;
end

startTarget = startTarget + opts.vibratoStartOffsetSec;
endTarget = endTarget + opts.vibratoEndOffsetSec;
startTarget = max(0, min(targetDur, startTarget));
endTarget = max(0, min(targetDur, endTarget));
if endTarget < startTarget
    tmp = startTarget;
    startTarget = endTarget;
    endTarget = tmp;
end

gate = local_raised_cosine_gate(t, startTarget, endTarget, opts.vibratoFadeSec);
info = struct('sourceStartSec',startSrc,'sourceEndSec',endSrc, ...
    'targetStartSec',startTarget,'targetEndSec',endTarget, ...
    'fadeSec',opts.vibratoFadeSec, ...
    'depthScale',opts.vibratoDepthScale, ...
    'sourceMethod',sourceMethod, ...
    'useStoredWindow',opts.vibratoUseStoredWindow);
end

function [startSec, endSec, method] = local_get_stored_vibrato_window(hk, params, sourceDur)
startSec = 0;
endSec = sourceDur;
method = 'fallback_full_source';
if isfield(hk, 'vibrato') && isstruct(hk.vibrato) && isfield(hk.vibrato, 'startSec') && isfield(hk.vibrato, 'endSec')
    startSec = hk.vibrato.startSec;
    endSec = hk.vibrato.endSec;
    method = 'per_harmonic';
elseif isfield(hk, 'vibStartSec') && isfield(hk, 'vibEndSec')
    startSec = hk.vibStartSec;
    endSec = hk.vibEndSec;
    method = 'per_harmonic_legacy_fields';
elseif isfield(params, 'vibrato') && isstruct(params.vibrato) && isfield(params.vibrato, 'startSec') && isfield(params.vibrato, 'endSec')
    startSec = params.vibrato.startSec;
    endSec = params.vibrato.endSec;
    method = 'global';
end
if ~isfinite(startSec), startSec = 0; end
if ~isfinite(endSec), endSec = sourceDur; end
startSec = max(0, min(sourceDur, startSec));
endSec = max(0, min(sourceDur, endSec));
if endSec < startSec
    tmp = startSec;
    startSec = endSec;
    endSec = tmp;
end
end

function targetTime = local_source_time_to_target_time(sourceTimeMap, targetTimeGrid, sourceTime)
sourceTimeMap = sourceTimeMap(:);
targetTimeGrid = targetTimeGrid(:);
if numel(sourceTimeMap) ~= numel(targetTimeGrid) || isempty(sourceTimeMap)
    targetTime = sourceTime;
    return;
end
[mapUnique, ia] = unique(sourceTimeMap, 'stable');
targetUnique = targetTimeGrid(ia);
if numel(mapUnique) < 2
    targetTime = sourceTime;
else
    targetTime = interp1(mapUnique, targetUnique, sourceTime, 'linear', 'extrap');
end
if ~isfinite(targetTime), targetTime = sourceTime; end
end

function gate = local_raised_cosine_gate(t, startSec, endSec, fadeSec)
t = t(:);
gate = zeros(size(t));
if ~isfinite(startSec) || ~isfinite(endSec) || endSec <= startSec
    return;
end
gate(t >= startSec & t <= endSec) = 1;
fadeSec = max(0, min(fadeSec, 0.5*(endSec-startSec)));
if fadeSec > 0
    rise = t >= startSec & t < (startSec + fadeSec);
    gate(rise) = 0.5 - 0.5*cos(pi*(t(rise)-startSec)/fadeSec);
    fall = t > (endSec - fadeSec) & t <= endSec;
    gate(fall) = 0.5 - 0.5*cos(pi*(endSec-t(fall))/fadeSec);
end
gate(~isfinite(gate)) = 0;
gate = min(max(gate, 0), 1);
end

function summary = local_collect_vibrato_timing(harmSynth)
K = numel(harmSynth);
startVals = nan(K,1);
endVals = nan(K,1);
for ii = 1:K
    if isfield(harmSynth(ii), 'vibratoWindow') && isstruct(harmSynth(ii).vibratoWindow) && ...
            isfield(harmSynth(ii).vibratoWindow, 'targetStartSec') && isfield(harmSynth(ii).vibratoWindow, 'targetEndSec')
        startVals(ii) = harmSynth(ii).vibratoWindow.targetStartSec;
        endVals(ii) = harmSynth(ii).vibratoWindow.targetEndSec;
    end
end
valid = isfinite(startVals) & isfinite(endVals) & endVals >= startVals;
if any(valid)
    summary = struct('targetStartSec',median(startVals(valid)), ...
        'targetEndSec',median(endVals(valid)), ...
        'targetDurationSec',median(endVals(valid))-median(startVals(valid)), ...
        'numHarmonicsUsed',nnz(valid));
else
    summary = struct('targetStartSec',NaN,'targetEndSec',NaN, ...
        'targetDurationSec',NaN,'numHarmonicsUsed',0);
end
end

function tq = local_source_time_map(t, targetDur, sourceDur, params, mode)
mode = lower(strtrim(mode));
tq = (t(:) / max(targetDur, eps)) * sourceDur;

if strcmp(mode, 'preserveattackrelease') && targetDur > sourceDur && isfield(params, 'globalEnvTiming')
    g = params.globalEnvTiming;
    if isfield(g, 'tAttackEnd') && isfield(g, 'tRelease') && isfield(g, 'tNoteEnd')
        srcAttackEnd = max(0, min(sourceDur, g.tAttackEnd));
        if isfield(g, 'hasRelease') && g.hasRelease
            srcReleaseStart = max(srcAttackEnd, min(sourceDur, g.tRelease));
        else
            srcReleaseStart = sourceDur;
        end
        srcNoteEnd = max(srcReleaseStart, min(sourceDur, g.tNoteEnd));
        releaseDur = max(0, sourceDur - srcReleaseStart);
        targetReleaseStart = max(srcAttackEnd, targetDur - releaseDur);

        if srcReleaseStart > srcAttackEnd && targetReleaseStart > srcAttackEnd
            tq = zeros(size(t));
            attackMask = t <= srcAttackEnd;
            bodyMask = t > srcAttackEnd & t < targetReleaseStart;
            releaseMask = t >= targetReleaseStart;
            tq(attackMask) = t(attackMask);
            tq(bodyMask) = srcAttackEnd + ...
                (t(bodyMask) - srcAttackEnd) .* (srcReleaseStart - srcAttackEnd) ./ max(targetReleaseStart - srcAttackEnd, eps);
            tq(releaseMask) = srcReleaseStart + (t(releaseMask) - targetReleaseStart);
            tq = min(max(tq, 0), max(srcNoteEnd, sourceDur));
        end
    end
elseif ~strcmp(mode, 'stretchenvelope') && ~strcmp(mode, 'preserveattackrelease')
    warning('vib_resynth:unknownDurationMode', ...
        'Unknown durationMode "%s". Using stretchEnvelope.', mode);
end

tq = min(max(tq(:), 0), sourceDur);
end

function local_plot_synth_waveform(y, fs)
t = (0:numel(y)-1).' / fs;
figure('Name','V27 Resynthesized Audio','Color','w');
plot(t, y);
grid on; xlabel('Time (s)'); ylabel('Amplitude');
title('V27 parameter-only resynthesis');
end

function local_plot_synthesis_amfm(params, synthData)
K = numel(synthData.harm);
if K < 1, return; end
nCols = min(4, max(1, ceil(sqrt(K))));
nRows = ceil(K / nCols);
t = synthData.t(:);

figAM = figure('Name','V27 AM Controls Per Harmonic','Color','w');
tlAM = tiledlayout(figAM, nRows, nCols, 'TileSpacing','tight', 'Padding','tight');
title(tlAM, 'Stored AM model used by resynthesis');
for k = 1:K
    nexttile(tlAM);
    sk = synthData.harm(k);
    plot(t, sk.amSin, 'DisplayName','AM sine used'); hold on;
    if k <= numel(params.harm) && isfield(params.harm(k), 'debug') && isfield(params.harm(k).debug, 'am')
        dbgTime = local_get_source_time_axis(params, synthData.sourceDurationSec);
        dbg = interp1(dbgTime, params.harm(k).debug.am, synthData.sourceTimeMap, 'linear', NaN);
        plot(t, dbg, ':', 'DisplayName','Measured AM debug');
    end
    grid on; xlabel('Time (s)'); ylabel('AM frac.');
    title(local_model_title(sprintf('H%d AM', sk.k), sk.amModel));
    if k == 1, legend('Location','best'); end
end

figFM = figure('Name','V27 FM Controls Per Harmonic','Color','w');
tlFM = tiledlayout(figFM, nRows, nCols, 'TileSpacing','tight', 'Padding','tight');
title(tlFM, 'Stored FM model used by resynthesis');
for k = 1:K
    nexttile(tlFM);
    sk = synthData.harm(k);
    plot(t, sk.fmSinHz, 'DisplayName','FM sine used'); hold on;
    if k <= numel(params.harm) && isfield(params.harm(k), 'debug') && isfield(params.harm(k).debug, 'vibFmHz')
        dbgTime = local_get_source_time_axis(params, synthData.sourceDurationSec);
        dbg = interp1(dbgTime, params.harm(k).debug.vibFmHz, synthData.sourceTimeMap, 'linear', NaN);
        plot(t, dbg, ':', 'DisplayName','Measured FM debug');
    end
    grid on; xlabel('Time (s)'); ylabel('FM (Hz)');
    title(local_model_title(sprintf('H%d FM', sk.k), sk.fmModel));
    if k == 1, legend('Location','best'); end
end
end

function local_plot_harmonic_controls(synthData)
K = numel(synthData.harm);
if K < 1, return; end
nCols = min(4, max(1, ceil(sqrt(K))));
nRows = ceil(K / nCols);
t = synthData.t(:);

figA = figure('Name','V27 Harmonic Amplitude Controls','Color','w');
tlA = tiledlayout(figA, nRows, nCols, 'TileSpacing','tight', 'Padding','tight');
title(tlA, 'A_k(t) used for each harmonic');
for k = 1:K
    nexttile(tlA);
    sk = synthData.harm(k);
    plot(t, sk.Ak);
    grid on; xlabel('Time (s)'); ylabel('Amplitude');
    title(sprintf('H%d A_k', sk.k));
end

figF = figure('Name','V27 Harmonic Frequency Controls','Color','w');
tlF = tiledlayout(figF, nRows, nCols, 'TileSpacing','tight', 'Padding','tight');
title(tlF, 'f_k(t) used for each harmonic');
for k = 1:K
    nexttile(tlF);
    sk = synthData.harm(k);
    plot(t, sk.fkHz);
    grid on; xlabel('Time (s)'); ylabel('Hz');
    title(sprintf('H%d f_k', sk.k));
end
end

function ttl = local_model_title(base, model)
if isfield(model, 'freqHz') && isfinite(model.freqHz)
    if isfield(model, 'r2') && isfinite(model.r2)
        ttl = sprintf('%s: %.2f Hz, R^2=%.2f', base, model.freqHz, model.r2);
    else
        ttl = sprintf('%s: %.2f Hz', base, model.freqHz);
    end
else
    ttl = base;
end
end
