%% vib_analyze_harmonics_analysis_V27_synthetic_validation.m
% Synthetic analysis-only validation for vib_analyze_harmonics_analysis_V27.
%
% This script does NOT call the V27 resynthesis program. It generates known
% synthetic harmonic tones, runs the V27 analysis function, and compares the
% recovered analysis parameters against the known ground truth.
%
% Validation categories:
%   1) Fundamental Frequency Recovery
%   2) Envelope Recovery
%   3) AM Parameter Recovery
%   4) FM Parameter Recovery
%   5) Vibrato Start and End Recovery
%   6) Synthetic Validation Summary
%
% Put this file in the same folder as vib_analyze_harmonics_analysis_V27.m,
% then run this script.

close all; clear; clc;
rng(27);

scriptFolder = fileparts(mfilename('fullpath'));
if isempty(scriptFolder)
    scriptFolder = pwd;
end
addpath(scriptFolder);

if exist('vib_analyze_harmonics_analysis_V27', 'file') ~= 2
    error(['Could not find vib_analyze_harmonics_analysis_V27.m. ', ...
        'Put this script in the same folder as the V27 analysis file or add it to the MATLAB path.']);
end

cfg = local_default_config();

fprintf('\n============================================================\n');
fprintf('V27 SYNTHETIC ANALYSIS-ONLY VALIDATION\n');
fprintf('============================================================\n');
fprintf('Analysis function: %s\n', which('vib_analyze_harmonics_analysis_V27'));
fprintf('Sample rate: %.0f Hz | Duration: %.2f s | Max harmonics: %d\n', ...
    cfg.fs, cfg.durationSec, cfg.numHarmonics);
fprintf('Known f0 for non-f0 tests: %d\n', cfg.useKnownF0ForParameterTests);

% -------------------------------------------------------------------------
% 1) Fundamental Frequency Recovery
% -------------------------------------------------------------------------
fprintf('\n[1/5] Fundamental Frequency Recovery\n');
T_f0 = local_test_f0_recovery(cfg);
disp(T_f0);

% -------------------------------------------------------------------------
% 2) Envelope Recovery
% -------------------------------------------------------------------------
fprintf('\n[2/5] Envelope Recovery\n');
T_env = local_test_envelope_recovery(cfg);
disp(T_env);

% -------------------------------------------------------------------------
% 3) AM Parameter Recovery
% -------------------------------------------------------------------------
fprintf('\n[3/5] AM Parameter Recovery\n');
T_am = local_test_am_recovery(cfg);
disp(T_am);

% -------------------------------------------------------------------------
% 4) FM Parameter Recovery
% -------------------------------------------------------------------------
fprintf('\n[4/5] FM Parameter Recovery\n');
T_fm = local_test_fm_recovery(cfg);
disp(T_fm);

% -------------------------------------------------------------------------
% 5) Vibrato Start and End Recovery
% -------------------------------------------------------------------------
fprintf('\n[5/5] Vibrato Start and End Recovery\n');
T_vib = local_test_vibrato_window_recovery(cfg);
disp(T_vib);

% -------------------------------------------------------------------------
% 6) Synthetic Validation Summary
% -------------------------------------------------------------------------
Summary = local_make_summary(T_f0, T_env, T_am, T_fm, T_vib, cfg);
fprintf('\n============================================================\n');
fprintf('SYNTHETIC VALIDATION SUMMARY\n');
fprintf('============================================================\n');
disp(Summary);

if cfg.makePlots
    local_plot_results(T_f0, T_env, T_am, T_fm, T_vib, cfg);
end

if cfg.saveResults
    if ~exist(cfg.outputFolder, 'dir')
        mkdir(cfg.outputFolder);
    end
    writetable(T_f0, fullfile(cfg.outputFolder, 'V27_f0_recovery.csv'));
    writetable(T_env, fullfile(cfg.outputFolder, 'V27_envelope_recovery.csv'));
    writetable(T_am, fullfile(cfg.outputFolder, 'V27_am_parameter_recovery.csv'));
    writetable(T_fm, fullfile(cfg.outputFolder, 'V27_fm_parameter_recovery.csv'));
    writetable(T_vib, fullfile(cfg.outputFolder, 'V27_vibrato_window_recovery.csv'));
    writetable(Summary, fullfile(cfg.outputFolder, 'V27_synthetic_validation_summary.csv'));
    save(fullfile(cfg.outputFolder, 'V27_synthetic_validation_results.mat'), ...
        'cfg', 'T_f0', 'T_env', 'T_am', 'T_fm', 'T_vib', 'Summary');
    fprintf('\nSaved CSV and MAT results to:\n  %s\n', cfg.outputFolder);
end

%% ========================================================================
% Local test sections
% ========================================================================

function cfg = local_default_config()
cfg = struct();

% General synthetic signal settings.
cfg.fs = 48000;
cfg.durationSec = 2.80;
cfg.numHarmonics = 10;
cfg.evalHarmonics = 8;
cfg.baseF0Hz = 220;
cfg.defaultSNRdB = Inf;
cfg.makePlots = true;
cfg.saveResults = true;
cfg.outputFolder = fullfile(pwd, ['V27_synthetic_validation_' datestr(now, 'yyyymmdd_HHMMSS')]);

% For AM/FM/envelope/window tests, true f0 can be supplied to the analyzer
% so the parameter recovery test is not dominated by pitch-tracker mistakes.
% Set this false to make all categories fully end-to-end.
cfg.useKnownF0ForParameterTests = true;

% Fundamental-frequency sweep. This intentionally spans low strings/brass,
% mid-range instruments, and high notes near the V27 stated 1200 Hz search
% limit. Reduce this list if you only want a quick smoke test.
cfg.f0SweepHz = [27.50 32.70 41.20 55.00 82.41 110.00 146.83 196.00 ...
                 261.63 329.63 440.00 659.25 880.00 1174.66].';
cfg.f0SNRdB = [Inf 35 25].';

% Synthetic vibrato defaults.
cfg.vibStartSec = 0.55;
cfg.vibEndSec = 2.25;
cfg.vibFadeSec = 0.06;
cfg.amPhaseRad = 0.30;
cfg.fmPhaseRad = -0.55;

% Analysis options that should stay quiet for batch testing.
cfg.analysis = struct();
cfg.analysis.numHarmonics = cfg.numHarmonics;
cfg.analysis.f0Method = 'majority';
cfg.analysis.plot_waveform = false;
cfg.analysis.plot_vib = false;
cfg.analysis.plot_vib_overviews = false;
cfg.analysis.plot_harm_amps = false;
cfg.analysis.plot_expEnv = false;
cfg.analysis.plot_spectrogram = false;
cfg.analysis.calcMetrics = false;
cfg.analysis.paramStoreDebugTracks = false;

% Mildly relaxed gates for synthetic validation. These still exercise the
% V27 rejection logic, but avoid labeling clean synthetic cases as failures
% only because the default listening-oriented consensus gate is too strict.
cfg.analysis.paramVibRequireConsensus = true;
cfg.analysis.paramVibMinConsensusHarmonics = 3;
cfg.analysis.paramVibMinR2 = 0.55;
cfg.analysis.paramVibMinFitDurationSec = 0.55;
cfg.analysis.paramVibMinCycles = 2.5;
cfg.analysis.paramVibWindowPadSec = 0.04;
cfg.analysis.paramVibWindowThresholdFrac = 0.20;

% Pass/fail thresholds. These are intentionally practical rather than tiny:
% the analysis uses filters, gates, and envelope segmentation, not direct
% access to the truth parameters.
cfg.thresh = struct();
cfg.thresh.f0AbsCents = 20;
cfg.thresh.envRelRMSE = 0.18;
cfg.thresh.envAttackEndAbsMs = 90;
cfg.thresh.envReleaseStartAbsMs = 160;
cfg.thresh.amRateAbsHz = 0.60;
cfg.thresh.amDepthAbs = 0.050;
cfg.thresh.amDepthRel = 0.40;
cfg.thresh.fmRateAbsHz = 0.60;
cfg.thresh.fmDepthFundRel = 0.45;
cfg.thresh.fmDepthFundAbsHz = 0.35;
cfg.thresh.vibBoundaryAbsMs = 180;
end

function T = local_test_f0_recovery(cfg)
rows = {};
row = 0;
for i = 1:numel(cfg.f0SweepHz)
    for j = 1:numel(cfg.f0SNRdB)
        p = local_base_synth_params(cfg);
        p.f0Hz = cfg.f0SweepHz(i);
        p.snrDb = cfg.f0SNRdB(j);
        p.numHarmonics = max(3, min(cfg.numHarmonics, floor(0.45 * cfg.fs / p.f0Hz)));
        p.amDepth = 0;
        p.fmDepthFundHz = 0;
        p.envelopeKind = 'sustained';
        [x, truth] = local_make_synthetic_note(p);

        S = local_run_analysis(x, cfg.fs, [], cfg, p.numHarmonics);
        errCents = 1200 * log2(S.f0Hz / truth.f0Hz);
        pass = abs(errCents) <= cfg.thresh.f0AbsCents;

        row = row + 1;
        rows(row,:) = { ...
            string(sprintf('f0_%gHz_%sSNR', truth.f0Hz, local_snr_label(truth.snrDb))), ...
            truth.f0Hz, truth.snrDb, p.numHarmonics, S.f0Hz, errCents, abs(errCents), pass}; %#ok<AGROW>
    end
end

T = cell2table(rows, 'VariableNames', { ...
    'TestID','TrueF0Hz','SNRdB','NumHarmonics','RecoveredF0Hz', ...
    'ErrorCents','AbsErrorCents','Pass'});
end

function T = local_test_envelope_recovery(cfg)
cases = { ...
    local_env_case('slow_string', 0.07, 0.24, 0.28, 0.72, 2.25, 0.38, 35), ...
    local_env_case('sharp_pluck', 0.22, 0.018, 0.42, 0.20, 2.35, 0.20, 35), ...
    local_env_case('brass_like', 0.06, 0.045, 0.18, 0.86, 2.30, 0.26, 35), ...
    local_env_case('clean_sustain', 0.05, 0.080, 0.15, 0.95, 2.40, 0.22, Inf)};

rows = {};
row = 0;
for c = 1:numel(cases)
    ec = cases{c};
    p = local_base_synth_params(cfg);
    p.f0Hz = cfg.baseF0Hz;
    p.numHarmonics = cfg.numHarmonics;
    p.snrDb = ec.snrDb;
    p.amDepth = 0;
    p.fmDepthFundHz = 0;
    p.envelopeKind = ec.name;
    p.onsetSec = ec.onsetSec;
    p.attackDurSec = ec.attackDurSec;
    p.decayDurSec = ec.decayDurSec;
    p.sustainLevel = ec.sustainLevel;
    p.releaseStartSec = ec.releaseStartSec;
    p.releaseDurSec = ec.releaseDurSec;

    [x, truth] = local_make_synthetic_note(p);
    S = local_run_analysis(x, cfg.fs, local_optional_known_f0(truth, cfg), cfg, p.numHarmonics);

    [envRelRmse, envR2] = local_envelope_error(S, truth, min(3, cfg.evalHarmonics));
    attackEndErrMs = 1000 * (local_get_field(S.globalEnvTiming, 'tAttackEnd', NaN) - truth.attackEndSec);
    releaseErrMs = 1000 * (local_get_field(S.globalEnvTiming, 'tRelease', NaN) - truth.releaseStartSec);
    noteEndErrMs = 1000 * (local_get_field(S.globalEnvTiming, 'tNoteEnd', NaN) - truth.noteEndSec);

    pass = envRelRmse <= cfg.thresh.envRelRMSE && ...
        abs(attackEndErrMs) <= cfg.thresh.envAttackEndAbsMs && ...
        abs(releaseErrMs) <= cfg.thresh.envReleaseStartAbsMs;

    row = row + 1;
    rows(row,:) = {string(ec.name), truth.snrDb, envRelRmse, envR2, ...
        truth.attackEndSec, local_get_field(S.globalEnvTiming, 'tAttackEnd', NaN), attackEndErrMs, ...
        truth.releaseStartSec, local_get_field(S.globalEnvTiming, 'tRelease', NaN), releaseErrMs, ...
        truth.noteEndSec, local_get_field(S.globalEnvTiming, 'tNoteEnd', NaN), noteEndErrMs, pass}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', { ...
    'TestID','SNRdB','EnvRelRMSE','EnvR2', ...
    'TrueAttackEndSec','RecoveredAttackEndSec','AttackEndErrorMs', ...
    'TrueReleaseStartSec','RecoveredReleaseStartSec','ReleaseStartErrorMs', ...
    'TrueNoteEndSec','RecoveredNoteEndSec','NoteEndErrorMs','Pass'});
end

function T = local_test_am_recovery(cfg)
cases = [ ...
    struct('name','AM_low_depth',  'rateHz',4.50, 'depth',0.06, 'snrDb',Inf), ...
    struct('name','AM_nominal',    'rateHz',5.50, 'depth',0.12, 'snrDb',35), ...
    struct('name','AM_deep_fast',  'rateHz',7.00, 'depth',0.24, 'snrDb',35), ...
    struct('name','AM_noisy',      'rateHz',5.80, 'depth',0.14, 'snrDb',25)];

rows = {};
row = 0;
for c = 1:numel(cases)
    ac = cases(c);
    p = local_base_synth_params(cfg);
    p.f0Hz = cfg.baseF0Hz;
    p.numHarmonics = cfg.numHarmonics;
    p.snrDb = ac.snrDb;
    p.amDepth = ac.depth;
    p.amRateHz = ac.rateHz;
    p.amPhaseRad = cfg.amPhaseRad;
    p.fmDepthFundHz = 0;
    p.vibStartSec = cfg.vibStartSec;
    p.vibEndSec = cfg.vibEndSec;
    [x, truth] = local_make_synthetic_note(p);

    S = local_run_analysis(x, cfg.fs, local_optional_known_f0(truth, cfg), cfg, p.numHarmonics);
    M = local_collect_am_models(S, cfg.evalHarmonics);
    valid = M.Amp > 0 & M.FreqHz > 0 & isfinite(M.Amp) & isfinite(M.FreqHz);

    recoveredRate = local_omitnan_median(M.FreqHz(valid));
    recoveredDepth = local_omitnan_median(M.Amp(valid));
    recoveredPhase = local_circular_mean(M.PhaseRad(valid));
    rateErrHz = recoveredRate - truth.amRateHz;
    depthErr = recoveredDepth - truth.amDepth;
    depthRelErr = depthErr / max(abs(truth.amDepth), eps);
    phaseErrDeg = rad2deg(local_wrap_to_pi(recoveredPhase - truth.amPhaseRad));

    pass = nnz(valid) >= 3 && ...
        abs(rateErrHz) <= cfg.thresh.amRateAbsHz && ...
        (abs(depthErr) <= cfg.thresh.amDepthAbs || abs(depthRelErr) <= cfg.thresh.amDepthRel);

    row = row + 1;
    rows(row,:) = {string(ac.name), truth.snrDb, truth.amRateHz, recoveredRate, rateErrHz, ...
        truth.amDepth, recoveredDepth, depthErr, depthRelErr, phaseErrDeg, nnz(valid), pass}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', { ...
    'TestID','SNRdB','TrueRateHz','RecoveredRateHz','RateErrorHz', ...
    'TrueDepth','RecoveredDepth','DepthError','DepthRelError', ...
    'PhaseErrorDeg','NumValidHarmonics','Pass'});
end

function T = local_test_fm_recovery(cfg)
cases = [ ...
    struct('name','FM_subtle',  'rateHz',4.80, 'depthCents',8,  'snrDb',Inf), ...
    struct('name','FM_nominal', 'rateHz',5.60, 'depthCents',22, 'snrDb',35), ...
    struct('name','FM_deep',    'rateHz',6.80, 'depthCents',38, 'snrDb',35), ...
    struct('name','FM_noisy',   'rateHz',5.30, 'depthCents',24, 'snrDb',25)];

rows = {};
row = 0;
for c = 1:numel(cases)
    fc = cases(c);
    p = local_base_synth_params(cfg);
    p.f0Hz = cfg.baseF0Hz;
    p.numHarmonics = cfg.numHarmonics;
    p.snrDb = fc.snrDb;
    p.amDepth = 0;
    p.fmRateHz = fc.rateHz;
    p.fmPhaseRad = cfg.fmPhaseRad;
    p.fmDepthFundHz = p.f0Hz * (2^(fc.depthCents/1200) - 1);
    p.vibStartSec = cfg.vibStartSec;
    p.vibEndSec = cfg.vibEndSec;
    [x, truth] = local_make_synthetic_note(p);

    S = local_run_analysis(x, cfg.fs, local_optional_known_f0(truth, cfg), cfg, p.numHarmonics);
    M = local_collect_fm_models(S, cfg.evalHarmonics);
    valid = M.Amp > 0 & M.FreqHz > 0 & isfinite(M.Amp) & isfinite(M.FreqHz) & M.Harmonic > 0;

    recoveredRate = local_omitnan_median(M.FreqHz(valid));
    recoveredFundDepthHz = local_omitnan_median(M.Amp(valid) ./ M.Harmonic(valid));
    recoveredPhase = local_circular_mean(M.PhaseRad(valid));
    rateErrHz = recoveredRate - truth.fmRateHz;
    depthErrHz = recoveredFundDepthHz - truth.fmDepthFundHz;
    depthRelErr = depthErrHz / max(abs(truth.fmDepthFundHz), eps);
    phaseErrDeg = rad2deg(local_wrap_to_pi(recoveredPhase - truth.fmPhaseRad));

    pass = nnz(valid) >= 3 && ...
        abs(rateErrHz) <= cfg.thresh.fmRateAbsHz && ...
        (abs(depthErrHz) <= cfg.thresh.fmDepthFundAbsHz || abs(depthRelErr) <= cfg.thresh.fmDepthFundRel);

    row = row + 1;
    rows(row,:) = {string(fc.name), truth.snrDb, fc.depthCents, truth.fmDepthFundHz, ...
        recoveredFundDepthHz, depthErrHz, depthRelErr, truth.fmRateHz, recoveredRate, ...
        rateErrHz, phaseErrDeg, nnz(valid), pass}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', { ...
    'TestID','SNRdB','TrueDepthCents','TrueFundDepthHz','RecoveredFundDepthHz', ...
    'FundDepthErrorHz','FundDepthRelError','TrueRateHz','RecoveredRateHz', ...
    'RateErrorHz','PhaseErrorDeg','NumValidHarmonics','Pass'});
end

function T = local_test_vibrato_window_recovery(cfg)
cases = [ ...
    struct('name','window_nominal', 'startSec',0.55, 'endSec',2.25, 'snrDb',35), ...
    struct('name','window_delayed', 'startSec',1.00, 'endSec',2.35, 'snrDb',35), ...
    struct('name','window_short',   'startSec',0.70, 'endSec',1.65, 'snrDb',35), ...
    struct('name','window_noisy',   'startSec',0.55, 'endSec',2.25, 'snrDb',25)];

rows = {};
row = 0;
for c = 1:numel(cases)
    vc = cases(c);
    p = local_base_synth_params(cfg);
    p.f0Hz = cfg.baseF0Hz;
    p.numHarmonics = cfg.numHarmonics;
    p.snrDb = vc.snrDb;
    p.amDepth = 0.12;
    p.amRateHz = 5.60;
    p.amPhaseRad = cfg.amPhaseRad;
    p.fmRateHz = 5.60;
    p.fmPhaseRad = cfg.fmPhaseRad;
    p.fmDepthFundHz = p.f0Hz * (2^(22/1200) - 1);
    p.vibStartSec = vc.startSec;
    p.vibEndSec = vc.endSec;
    [x, truth] = local_make_synthetic_note(p);

    S = local_run_analysis(x, cfg.fs, local_optional_known_f0(truth, cfg), cfg, p.numHarmonics);
    recoveredStart = local_get_field(S.params.vibrato, 'startSec', NaN);
    recoveredEnd = local_get_field(S.params.vibrato, 'endSec', NaN);
    startErrMs = 1000 * (recoveredStart - truth.vibStartSec);
    endErrMs = 1000 * (recoveredEnd - truth.vibEndSec);
    durErrMs = 1000 * ((recoveredEnd - recoveredStart) - (truth.vibEndSec - truth.vibStartSec));

    pass = abs(startErrMs) <= cfg.thresh.vibBoundaryAbsMs && ...
        abs(endErrMs) <= cfg.thresh.vibBoundaryAbsMs;

    row = row + 1;
    rows(row,:) = {string(vc.name), truth.snrDb, truth.vibStartSec, recoveredStart, startErrMs, ...
        truth.vibEndSec, recoveredEnd, endErrMs, durErrMs, pass}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', { ...
    'TestID','SNRdB','TrueStartSec','RecoveredStartSec','StartErrorMs', ...
    'TrueEndSec','RecoveredEndSec','EndErrorMs','DurationErrorMs','Pass'});
end

%% ========================================================================
% Synthesis and analysis helpers
% ========================================================================

function p = local_base_synth_params(cfg)
p = struct();
p.fs = cfg.fs;
p.durationSec = cfg.durationSec;
p.f0Hz = cfg.baseF0Hz;
p.numHarmonics = cfg.numHarmonics;
p.harmAmpPower = 1.10;
p.snrDb = cfg.defaultSNRdB;
p.peakNormalize = 0.80;

p.envelopeKind = 'default';
p.onsetSec = 0.06;
p.attackDurSec = 0.09;
p.decayDurSec = 0.18;
p.sustainLevel = 0.82;
p.releaseStartSec = 2.30;
p.releaseDurSec = 0.28;

p.vibStartSec = cfg.vibStartSec;
p.vibEndSec = cfg.vibEndSec;
p.vibFadeSec = cfg.vibFadeSec;
p.amRateHz = 5.5;
p.amDepth = 0;
p.amPhaseRad = cfg.amPhaseRad;
p.fmRateHz = 5.5;
p.fmDepthFundHz = 0;
p.fmPhaseRad = cfg.fmPhaseRad;
end

function [x, truth] = local_make_synthetic_note(p)
fs = p.fs;
N = max(1, round(p.durationSec * fs));
t = (0:N-1).' / fs;
K = p.numHarmonics;

harmAmps = (1 ./ (1:K).^(p.harmAmpPower)).';
harmAmps = harmAmps / max(harmAmps);

env = local_adsr_envelope(t, p);
vibWin = local_smooth_gate(t, p.vibStartSec, p.vibEndSec, p.vibFadeSec);
amTrack = p.amDepth * sin(2*pi*p.amRateHz*t + p.amPhaseRad) .* vibWin;
fmFundTrackHz = p.fmDepthFundHz * sin(2*pi*p.fmRateHz*t + p.fmPhaseRad) .* vibWin;
ampGain = max(0.02, 1 + amTrack);

xClean = zeros(N,1);
phaseOffsets = zeros(K,1);
for k = 1:K
    fk = k * (p.f0Hz + fmFundTrackHz);
    fk = max(0, min(0.49*fs, fk));
    phase = phaseOffsets(k) + cumsum(2*pi*fk/fs);
    xClean = xClean + harmAmps(k) * env .* ampGain .* cos(phase);
end

scale = 1;
mx = max(abs(xClean));
if p.peakNormalize > 0 && mx > 0
    scale = p.peakNormalize / mx;
    xClean = scale * xClean;
    harmAmps = scale * harmAmps;
end

x = xClean;
if isfinite(p.snrDb)
    noise = randn(size(xClean));
    noise = noise / max(rms(noise), eps) * rms(xClean) * 10^(-p.snrDb/20);
    x = xClean + noise;
end

truth = struct();
truth.fs = fs;
truth.t = t;
truth.xClean = xClean;
truth.x = x;
truth.f0Hz = p.f0Hz;
truth.numHarmonics = K;
truth.harmAmps = harmAmps;
truth.scale = scale;
truth.envelope = env;
truth.envelopeKind = string(p.envelopeKind);
truth.onsetSec = p.onsetSec;
truth.attackEndSec = p.onsetSec + p.attackDurSec;
truth.releaseStartSec = p.releaseStartSec;
truth.noteEndSec = min(p.durationSec, p.releaseStartSec + p.releaseDurSec);
truth.vibStartSec = p.vibStartSec;
truth.vibEndSec = p.vibEndSec;
truth.vibWin = vibWin;
truth.amRateHz = p.amRateHz;
truth.amDepth = p.amDepth;
truth.amPhaseRad = p.amPhaseRad;
truth.amTrack = amTrack;
truth.fmRateHz = p.fmRateHz;
truth.fmDepthFundHz = p.fmDepthFundHz;
truth.fmPhaseRad = p.fmPhaseRad;
truth.fmFundTrackHz = fmFundTrackHz;
truth.snrDb = p.snrDb;

% Demodulated analytic amplitude of a real cosine is approximately A/2.
truth.harmNoVibEnv = zeros(N,K);
truth.harmAmpEnv = zeros(N,K);
for k = 1:K
    truth.harmNoVibEnv(:,k) = 0.5 * harmAmps(k) * env;
    truth.harmAmpEnv(:,k) = 0.5 * harmAmps(k) * env .* ampGain;
end
end

function env = local_adsr_envelope(t, p)
N = numel(t);
env = zeros(N,1);
tOn = p.onsetSec;
tAttackEnd = p.onsetSec + p.attackDurSec;
tDecayEnd = tAttackEnd + p.decayDurSec;
tRelease = p.releaseStartSec;
tEnd = min(p.durationSec, p.releaseStartSec + p.releaseDurSec);

% Attack: smooth polynomial rise.
idx = t >= tOn & t < tAttackEnd;
if any(idx)
    u = (t(idx) - tOn) / max(tAttackEnd - tOn, eps);
    env(idx) = local_smoothstep(u);
end

% Decay to sustain.
idx = t >= tAttackEnd & t < tDecayEnd;
if any(idx)
    u = (t(idx) - tAttackEnd) / max(tDecayEnd - tAttackEnd, eps);
    env(idx) = 1 - (1 - p.sustainLevel) * local_smoothstep(u);
end

% Sustain.
idx = t >= tDecayEnd & t < tRelease;
if any(idx)
    env(idx) = p.sustainLevel;
end

% Release.
idx = t >= tRelease & t <= tEnd;
if any(idx)
    u = (t(idx) - tRelease) / max(tEnd - tRelease, eps);
    startVal = p.sustainLevel;
    if tRelease < tDecayEnd
        % If release begins during the decay segment, compute the current value.
        uRel = (tRelease - tAttackEnd) / max(tDecayEnd - tAttackEnd, eps);
        uRel = max(0, min(1, uRel));
        startVal = 1 - (1 - p.sustainLevel) * local_smoothstep(uRel);
    end
    env(idx) = startVal * (1 - local_smoothstep(u));
end

env(t > tEnd) = 0;
end

function y = local_smoothstep(u)
u = max(0, min(1, u));
y = u.^3 .* (10 - 15*u + 6*u.^2);
end

function w = local_smooth_gate(t, startSec, endSec, fadeSec)
fadeSec = max(fadeSec, eps);
wIn = local_smoothstep((t - startSec) / fadeSec);
wOut = local_smoothstep((endSec - t) / fadeSec);
w = wIn .* wOut;
end

function S = local_run_analysis(x, fs, f0Override, cfg, numHarmonics)
opts = cfg.analysis;
opts.fs = fs;
opts.numHarmonics = numHarmonics;
if ~isempty(f0Override) && isfinite(f0Override) && f0Override > 0
    opts.f0Hz = f0Override;
else
    if isfield(opts, 'f0Hz')
        opts = rmfield(opts, 'f0Hz');
    end
    opts.f0Method = 'majority';
end

% V27 defines its options in an arguments block as name-value arguments.
% Therefore a struct cannot be passed as the second positional input.
% Convert the options struct into {'name', value, ...} before calling V27.
nv = local_struct_to_name_value(opts);
S = vib_analyze_harmonics_analysis_V27(x, nv{:});
end

function nv = local_struct_to_name_value(s)
fn = fieldnames(s);
nv = cell(1, 2*numel(fn));
for ii = 1:numel(fn)
    nv{2*ii - 1} = fn{ii};
    nv{2*ii} = s.(fn{ii});
end
end

function f0 = local_optional_known_f0(truth, cfg)
if cfg.useKnownF0ForParameterTests
    f0 = truth.f0Hz;
else
    f0 = [];
end
end

function ec = local_env_case(name, onsetSec, attackDurSec, decayDurSec, sustainLevel, releaseStartSec, releaseDurSec, snrDb)
ec = struct('name',name, 'onsetSec',onsetSec, 'attackDurSec',attackDurSec, ...
    'decayDurSec',decayDurSec, 'sustainLevel',sustainLevel, ...
    'releaseStartSec',releaseStartSec, 'releaseDurSec',releaseDurSec, 'snrDb',snrDb);
end

%% ========================================================================
% Recovery metric helpers
% ========================================================================

function [relRmse, r2] = local_envelope_error(S, truth, numHarmonics)
errs = nan(numHarmonics,1);
r2s = nan(numHarmonics,1);
N = numel(truth.t);
for k = 1:min([numHarmonics, numel(S.harm), truth.numHarmonics])
    fit = [];
    if isfield(S.harm(k), 'expEnv') && isfield(S.harm(k).expEnv, 'envFit')
        fit = S.harm(k).expEnv.envFit(:);
    end
    if isempty(fit)
        continue;
    end
    fit = local_match_length(fit, N);
    y = truth.harmNoVibEnv(:,k);
    mask = isfinite(fit) & isfinite(y) & truth.t >= truth.onsetSec & truth.t <= truth.noteEndSec & y > 0;
    if nnz(mask) < 16
        continue;
    end
    e = fit(mask) - y(mask);
    errs(k) = rms(e) / max(max(abs(y(mask))), eps);
    ssRes = sum(e.^2);
    ssTot = sum((y(mask) - mean(y(mask))).^2);
    r2s(k) = 1 - ssRes / max(ssTot, eps);
end
relRmse = local_omitnan_median(errs);
r2 = local_omitnan_median(r2s);
end

function M = local_collect_am_models(S, maxHarmonics)
K = min(maxHarmonics, numel(S.params.harm));
h = nan(K,1); f = nan(K,1); a = nan(K,1); ph = nan(K,1);
for k = 1:K
    h(k) = local_get_field(S.params.harm(k), 'k', k);
    if isfield(S.params.harm(k), 'amModel')
        m = S.params.harm(k).amModel;
        f(k) = local_get_field(m, 'freqHz', NaN);
        a(k) = local_get_field(m, 'amp', NaN);
        ph(k) = local_get_field(m, 'phaseRad', NaN);
    end
end
M = table(h, f, a, ph, 'VariableNames', {'Harmonic','FreqHz','Amp','PhaseRad'});
end

function M = local_collect_fm_models(S, maxHarmonics)
K = min(maxHarmonics, numel(S.params.harm));
h = nan(K,1); f = nan(K,1); a = nan(K,1); ph = nan(K,1);
for k = 1:K
    h(k) = local_get_field(S.params.harm(k), 'k', k);
    if isfield(S.params.harm(k), 'fmModel')
        m = S.params.harm(k).fmModel;
        f(k) = local_get_field(m, 'freqHz', NaN);
        a(k) = local_get_field(m, 'amp', NaN);
        ph(k) = local_get_field(m, 'phaseRad', NaN);
    end
end
M = table(h, f, a, ph, 'VariableNames', {'Harmonic','FreqHz','Amp','PhaseRad'});
end

function Summary = local_make_summary(T_f0, T_env, T_am, T_fm, T_vib, cfg)
cat = strings(5,1);
n = zeros(5,1);
passRate = zeros(5,1);
mainMetric = strings(5,1);
medianAbsError = nan(5,1);
threshold = nan(5,1);

cat(1) = "Fundamental Frequency Recovery";
n(1) = height(T_f0);
passRate(1) = mean(T_f0.Pass) * 100;
mainMetric(1) = "median |f0 error| (cents)";
medianAbsError(1) = median(T_f0.AbsErrorCents, 'omitnan');
threshold(1) = cfg.thresh.f0AbsCents;

cat(2) = "Envelope Recovery";
n(2) = height(T_env);
passRate(2) = mean(T_env.Pass) * 100;
mainMetric(2) = "median envelope relative RMSE";
medianAbsError(2) = median(T_env.EnvRelRMSE, 'omitnan');
threshold(2) = cfg.thresh.envRelRMSE;

cat(3) = "AM Parameter Recovery";
n(3) = height(T_am);
passRate(3) = mean(T_am.Pass) * 100;
mainMetric(3) = "median |AM rate error| (Hz)";
medianAbsError(3) = median(abs(T_am.RateErrorHz), 'omitnan');
threshold(3) = cfg.thresh.amRateAbsHz;

cat(4) = "FM Parameter Recovery";
n(4) = height(T_fm);
passRate(4) = mean(T_fm.Pass) * 100;
mainMetric(4) = "median |FM rate error| (Hz)";
medianAbsError(4) = median(abs(T_fm.RateErrorHz), 'omitnan');
threshold(4) = cfg.thresh.fmRateAbsHz;

cat(5) = "Vibrato Start and End Recovery";
n(5) = height(T_vib);
passRate(5) = mean(T_vib.Pass) * 100;
mainMetric(5) = "median boundary error (ms)";
boundaryErrors = [abs(T_vib.StartErrorMs); abs(T_vib.EndErrorMs)];
medianAbsError(5) = median(boundaryErrors, 'omitnan');
threshold(5) = cfg.thresh.vibBoundaryAbsMs;

Summary = table(cat, n, passRate, mainMetric, medianAbsError, threshold, ...
    'VariableNames', {'Category','NumTests','PassRatePct','MainMetric','MedianAbsError','PassThreshold'});
end

%% ========================================================================
% Plotting helpers
% ========================================================================

function local_plot_results(T_f0, T_env, T_am, T_fm, T_vib, cfg)
figure('Name','V27 Synthetic Validation - F0 Recovery','Color','w');
semilogx(T_f0.TrueF0Hz, T_f0.ErrorCents, 'o', 'MarkerSize', 6); hold on;
yline(cfg.thresh.f0AbsCents, '--');
yline(-cfg.thresh.f0AbsCents, '--');
grid on; xlabel('True f0 (Hz)'); ylabel('Error (cents)');
title('Fundamental Frequency Recovery');

figure('Name','V27 Synthetic Validation - Envelope Recovery','Color','w');
bar(categorical(T_env.TestID), T_env.EnvRelRMSE);
yline(cfg.thresh.envRelRMSE, '--');
grid on; ylabel('Relative RMSE'); title('Envelope Recovery');

figure('Name','V27 Synthetic Validation - AM Recovery','Color','w');
plot(T_am.TrueRateHz, T_am.RecoveredRateHz, 'o', 'MarkerSize', 7); hold on;
lo = min([T_am.TrueRateHz; T_am.RecoveredRateHz]) - 0.5;
hi = max([T_am.TrueRateHz; T_am.RecoveredRateHz]) + 0.5;
plot([lo hi], [lo hi], '--'); grid on; axis equal; xlim([lo hi]); ylim([lo hi]);
xlabel('True AM rate (Hz)'); ylabel('Recovered AM rate (Hz)');
title('AM Parameter Recovery');

figure('Name','V27 Synthetic Validation - FM Recovery','Color','w');
plot(T_fm.TrueRateHz, T_fm.RecoveredRateHz, 'o', 'MarkerSize', 7); hold on;
lo = min([T_fm.TrueRateHz; T_fm.RecoveredRateHz]) - 0.5;
hi = max([T_fm.TrueRateHz; T_fm.RecoveredRateHz]) + 0.5;
plot([lo hi], [lo hi], '--'); grid on; axis equal; xlim([lo hi]); ylim([lo hi]);
xlabel('True FM rate (Hz)'); ylabel('Recovered FM rate (Hz)');
title('FM Parameter Recovery');

figure('Name','V27 Synthetic Validation - Vibrato Window','Color','w');
idx = 1:height(T_vib);
plot(idx, T_vib.StartErrorMs, 'o-', 'DisplayName','Start error'); hold on;
plot(idx, T_vib.EndErrorMs, 's-', 'DisplayName','End error');
yline(cfg.thresh.vibBoundaryAbsMs, '--');
yline(-cfg.thresh.vibBoundaryAbsMs, '--');
grid on; xticks(idx); xticklabels(T_vib.TestID); xtickangle(25);
ylabel('Boundary error (ms)'); title('Vibrato Start and End Recovery');
legend('Location','best');
end

%% ========================================================================
% Small utilities
% ========================================================================

function v = local_get_field(s, fieldName, defaultValue)
v = defaultValue;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    v = s.(fieldName);
end
end

function y = local_match_length(x, N)
x = x(:);
if numel(x) == N
    y = x;
elseif isempty(x)
    y = nan(N,1);
else
    xi = linspace(0, 1, numel(x));
    yi = linspace(0, 1, N);
    y = interp1(xi, x, yi, 'linear', 'extrap').';
end
end

function m = local_omitnan_median(x)
x = x(:);
x = x(isfinite(x));
if isempty(x)
    m = NaN;
else
    m = median(x);
end
end

function mu = local_circular_mean(phi)
phi = phi(:);
phi = phi(isfinite(phi));
if isempty(phi)
    mu = NaN;
else
    mu = angle(mean(exp(1j*phi)));
end
end

function x = local_wrap_to_pi(x)
x = mod(x + pi, 2*pi) - pi;
end

function label = local_snr_label(snrDb)
if isfinite(snrDb)
    label = sprintf('%gdB', snrDb);
else
    label = 'clean';
end
end
