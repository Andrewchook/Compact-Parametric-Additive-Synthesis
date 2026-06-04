function S = vib_analyze_harmonics_analysis_V30(audioIn, opts)
%VIB_ANALYZE_HARMONICS_ANALYSIS_V30  Per-harmonic AM/FM vibrato analysis pipeline.
%
% Path-input patch: first input may be a numeric audio vector, string/char audio path, or [] with opts.audioPath.
%
% Clean use:
%   analysisOpts.fs = fs;
%   S = vib_analyze_harmonics_analysis_V30(x, analysisOpts);
%
% Or read directly from an audio file path:
%   S = vib_analyze_harmonics_analysis_V30("violin.wav", analysisOpts);
%
% When an audio path is supplied and analysisOpts.fs is empty/NaN, the
% sampling rate returned by audioread is used automatically.
%
% V15 change:
%   Adds additive AM/FM note resynthesis from the analyzed harmonic models:
%
%       y(t) = sum_k A_k(t) cos(2*pi*f_k(t)*t + phi_k(t))
%
%   In the implementation, the carrier phase is accumulated from f_k(t)
%   by default for phase continuity. Each A_k(t) is built from the fitted
%   no-vibrato envelope multiplied by a single-sinusoid fit to the extracted
%   multiplicative AM. Each f_k(t) is k*f0Hz plus a single-sinusoid fit to
%   the extracted FM in Hz. Results are stored in S.params. Resynthesis is handled by vib_analyze_harmonics_resynthesize_V30.m.
%
% V14-global change:
%   AM and FM vibrato are only retained while the smoothed no-vibrato
%   harmonic amplitude envelope is above opts.vibAmpMinFrac of that
%   smoothed envelope's maximum. Using ampNoVib instead of instantaneous
%   ampEnv prevents the gate from flickering with vibrato cycles/noise.
%   Outside this reliable-amplitude region, AM/FM vibrato values are
%   set to NaN so plots and metrics ignore low-amplitude noisy regions.
%
% V13-global change:
%   AM and FM vibrato were gated by instantaneous harmonic amplitude.
%
% V12-global change:
%   Amplitude modulation is now modeled multiplicatively rather than
%   additively. For each harmonic, the amplitude envelope is decomposed as:
%
%       ampEnv(t) = ampNoVib(t) * amGain(t)
%                = ampNoVib(t) * exp(amLog(t))
%
%   where amGain(t) is near 1 and am(t) = amGain(t) - 1 is the
%   fractional multiplicative AM residual. This makes AM depth independent
%   of the absolute harmonic amplitude and better suited for synthesis.
%
% V11-global change:
%   Envelope fitting uses a global waveform-based segmentation.
%   Attack, body, and release boundaries are detected once from the
%   overall time-domain waveform envelope and then reused for every
%   harmonic with no per-harmonic movement of segmentation.
%   The vibrato-removed amplitude envelope for each harmonic is modeled as:
%     1) attack : V19 default PCHIP anchors through the onset/attack region
%                 to preserve sharper brass-like curvature; the old
%                 smoothstep attack remains available with opts.attackModel.
%     2) body   : shape-preserving interpolation through anchor points, with
%                 extra early-body anchors to capture attack settling.
%     3) tail   : optional short release/taper segment
%
%   This is much faster than per-segment exponential fitting and better
%   matches bowed-string envelopes while allowing sharper wind/brass attacks.
%
% Output struct S:
%   .fs, .t, .x, .f0Hz
%   .harm(k).ampEnv
%   .harm(k).ampNoVib
%   .harm(k).am              (fractional multiplicative AM, amGain - 1)
%   .harm(k).amGain          (multiplicative AM gain, ampEnv ./ ampNoVib)
%   .harm(k).amLog           (log-domain AM residual, log(ampEnv)-log(ampNoVib))
%   .harm(k).amRaw/amLogRaw raw unmasked AM values before low-amplitude rejection
%   .harm(k).vibAmpMask     true where ampNoVib >= opts.vibAmpMinFrac*max(ampNoVib)
%   .harm(k).instFreqHz
%   .harm(k).freqNoVibHz
%   .harm(k).vibFmHz
%   .harm(k).metrics
%   .harm(k).expEnv         (segmented envelope fit)
%     .type                 ('segmented')
%     .envFit               (full-length fit, NaN outside idxTrim)
%     .envFitTrim           (fit over idxTrim)
%     .residual             (ampNoVib(idxTrim) - envFitTrim)
%     .rmse
%     .r2
%     .segments             (attack/decay/release boundaries and fits)
%
% V21 change:
%   S.params stores compact per-harmonic envelope model parameters
%   (attack/body/release knot times and values) instead of full envFit and
%   envTimeSec vectors. Resynthesis rebuilds the envelope from those parameters.
%
% V26 change:
%   Global envelope segmentation uses peak-anchored onset backtracking for
%   sharp/plucked notes. This avoids labeling early low-level noise as onset
%   when the main attack peak occurs much later.
%
% V30 change:
%   Fundamental-frequency estimation now uses a majority vote over multiple
%   pitch trackers, autocorrelation, cepstrum, and harmonic spectral scoring.
%   The search range is extended down to 20 Hz to improve lower instruments.
%
% Notes:
%   V19 focuses on sharper attack extraction. opts.attackModel='pchipAnchors'
%   is the default; set opts.attackModel='smoothstep' for the older V17-style
%   monotonic attack.

arguments
    audioIn = []
    opts.fs (1,1) double = NaN
    opts.audioPath = ""
    opts.numHarmonics (1,1) double = 15
    opts.f0Hz double = []
    opts.f0Method (1,:) char = 'pitch'
    opts.bandwidthF0Frac (1,1) double = 0.30
    opts.vibMaxHz (1,1) double = 15
    opts.trimMs (1,1) double = 30

    %Vibrato parameters
    opts.ampNoVibLpHz (1,1) double = 3
    opts.ampFloorFrac (1,1) double = 1e-4
    opts.vibAmpMinFrac (1,1) double = 0.10
    opts.freqNoVibLpHz (1,1) double = 2
    opts.maxPhaseJump (1,1) double = 1
    % opts.fmComplexLpHz = 30;

    opts.numExpTerms (1,1) double = 3
    opts.numReleaseTerms (1,1) double = 1
    opts.useNonlinearFit (1,1) logical = false
    opts.plot_expEnv (1,1) logical = true
    opts.releaseStartFrac (1,1) double = 0.15

    % V19 sharper-attack envelope controls
    opts.minSegmentMs (1,1) double = 5
    opts.attackModel (1,:) char = 'pchipAnchors' % 'pchipAnchors' or 'smoothstep'
    opts.attackShapeOrder (1,1) double = 5
    opts.attackNumKnots (1,1) double = 5
    opts.attackAnchorMedianMs (1,1) double = 3
    opts.attackIncludeLocalPeak (1,1) logical = true
    opts.attackUseRawEnvelope (1,1) logical = true
    opts.attackRawLpHz (1,1) double = 350
    opts.attackMaxMs (1,1) double = 45
    opts.attackMinPeakFrac (1,1) double = 0.08
    opts.attackHybridMs (1,1) double = 180
    opts.bodyEarlyAnchorMs double = [3 8 15 30 60]
    opts.globalEnvLpHz (1,1) double = 120
    opts.globalOnsetFrac (1,1) double = 0.03
    % V30: peak-anchored onset correction for plucked/sharp attacks with early low-level noise
    opts.globalUsePeakBacktrack (1,1) logical = true
    opts.globalOnsetBacktrackFrac (1,1) double = 0.05
    opts.globalOnsetBacktrackHoldMs (1,1) double = 8
    opts.globalSharpAttackMaxMs (1,1) double = 120
    opts.globalOnsetMinCorrectionMs (1,1) double = 25
    opts.globalAttackFrac (1,1) double = 0.60
    opts.globalEndFrac (1,1) double = 0.01
    opts.onsetSearchPadMs (1,1) double = 80
    opts.peakSearchPadMs (1,1) double = 180
    opts.releaseSearchPadMs (1,1) double = 250
    opts.releaseMinImprovement (1,1) double = 0.12
    opts.fitErrorMinFrac (1,1) double = 0.02
    opts.allowReleaseSegment (1,1) logical = true
    opts.envFitFs (1,1) double = 2000
    opts.globalEnvFs (1,1) double = 4000
    opts.releaseSearchStride (1,1) double = 8
    opts.bodyNumKnots (1,1) double = 5
    opts.tailNumKnots (1,1) double = 3
    opts.anchorMedianMs (1,1) double = 8

    opts.plot_vib (1,1) logical = false
    opts.plot_vib_overviews (1,1) logical = true
    opts.plot_harm_amps (1,1) logical = false
    opts.plot_waveform (1,1) logical = true

    opts.testWaveform (1,1) logical = false
    opts.overlayIdeal (1,1) logical = false

    opts.testFs (1,1) double = 48000
    opts.testDurSec (1,1) double = 3.0
    opts.testF0Hz (1,1) double = 440
    opts.testNumHarmonics (1,1) double = 10
    opts.testHarmAmps double = []
    opts.testAmpVibRateHz (1,1) double = 5.5
    opts.testAmpVibDepth (1,1) double = 0.15
    opts.testFmVibRateHz (1,1) double = 5.5
    opts.testFmVibDepthCents (1,1) double = 25
    opts.testNoiseStd (1,1) double = 0.0
    opts.testFadeMs (1,1) double = 0.30
    opts.freqDrift (1,1) double = 0.0
    opts.ampDrift (1,1) double = 0.0
    opts.poly_env (1,1) logical = true

    opts.plot_spectrogram (1,1) logical = false
    opts.specWinMs (1,1) double = 40
    opts.specHopMs (1,1) double = 10
    opts.specNfft (1,1) double = 4096
    opts.specDynRangeDb (1,1) double = 80
    opts.specOverlayCenters (1,1) logical = true

    opts.calcMetrics (1,1) logical = false

    % V19 parameter export options
    opts.paramVibBandMinHz (1,1) double = 3
    opts.paramAnalyticAmpScale (1,1) double = 2
    opts.paramStoreDebugTracks (1,1) logical = false

    % V30 AM export. Set false to omit params.harm(k).amModel entirely.
    % Resynthesis will then use amGain = 1 for every harmonic.
    opts.paramStoreAmModel (1,1) logical = false

    % V19-ish parameter export: estimate where useful vibrato is active.
    % These times are stored in S.params and can be overridden during
    % resynthesis without re-running analysis.
    opts.paramVibWindowSmoothMs (1,1) double = 80
    opts.paramVibWindowThresholdFrac (1,1) double = 0.30
    opts.paramVibWindowMinDurationSec (1,1) double = 0.10
    opts.paramVibWindowPadSec (1,1) double = 0.00

    % V30 vibrato rejection/confidence gates used before storing compact params.
    opts.paramVibIgnoreAfterAttackSec (1,1) double = 0.18
    opts.paramVibMinFitDurationSec (1,1) double = 0.70
    opts.paramVibMinCycles (1,1) double = 3.0
    opts.paramVibMinR2 (1,1) double = 0.70
    opts.paramVibLowerEdgeGuardHz (1,1) double = 0.35
    opts.paramVibUpperEdgeGuardHz (1,1) double = 0.15
    opts.paramVibMinAmDepth (1,1) double = 0.02
    opts.paramVibMaxAmDepth (1,1) double = 0.75
    opts.paramVibMinFmDepthHz (1,1) double = 0.10
    opts.paramVibMinConsensusHarmonics (1,1) double = 4
    opts.paramVibConsensusTolHz (1,1) double = 0.75
    opts.paramVibRequireConsensus (1,1) logical = true

    % V30 compact FM export. The stored top-level params.fmModel contains
    % one H1-equivalent FM sine. Resynthesis scales its depth by k.
    opts.paramCompactFmEnable (1,1) logical = true
    opts.paramCompactFmRefHarmonic (1,1) double = 1
    opts.paramCompactFmScaleByHarmonic (1,1) logical = true
end

S = [];

% ---- Input + mono ----
testInfo = [];
sourceAudioPath = "";
if opts.testWaveform
    [x, fs, testInfo] = local_make_test_waveform(opts);
    opts.fs = fs;
else
    [x, fs, opts, sourceAudioPath] = local_resolve_audio_input(audioIn, opts);
end
if isvector(x)
    x = x(:);
elseif size(x,2) > 1
    x = mean(x,2);
    x = x(:);
else
    x = x(:);
end

t = (0:length(x)-1)'/fs;

if opts.plot_waveform
    figure; plot(t,x); title('Sound Signal'); xlabel('Time (s)'); ylabel('Amplitude')
end

% ---- Estimate or set f0 ----
% V30: robust majority-vote pitch estimation. The old implementation used
% a single SRH tracker over [50 1200] Hz, which could miss or octave-shift
% low instruments. This version uses several trackers plus autocorrelation,
% cepstrum, and harmonic spectral evidence over [20 1200] Hz.
if isempty(opts.f0Hz)
    if strcmpi(opts.f0Method, 'pitch') || strcmpi(opts.f0Method, 'majority')
        [f0Hz, pitchInfo] = local_estimate_f0_majority_vote(x, fs);
    else
        error('Unknown f0Method. Use opts.f0Method=''pitch'', opts.f0Method=''majority'', or provide opts.f0Hz.');
    end
else
    f0Hz = opts.f0Hz;
    pitchInfo = struct();
    pitchInfo.method = 'manual';
    pitchInfo.f0Hz = f0Hz;
end
if isempty(f0Hz) || ~isfinite(f0Hz) || f0Hz <= 0
    error('Could not determine f0. Provide opts.f0Hz explicitly.');
end

R = struct();
R.fs = fs; R.t = t; R.x = x; R.f0Hz = f0Hz; R.sourceAudioPath = sourceAudioPath;
R.pitchInfo = pitchInfo;
globalTiming = local_detect_global_envelope_timing(x, fs, opts);
% Keep the full timing struct inside analysis; only S.params is compacted.
R.globalEnvTiming = globalTiming;

K = opts.numHarmonics;
R.harm = repmat(struct(), K, 1);
vibBand = [3, opts.vibMaxHz];

% =========================================================
% Pre-compute loop-invariant quantities
% =========================================================
trimN = max(1, round((opts.trimMs/1000)*fs));
L     = length(t);
idxTrim = (1+trimN):(L-trimN);
if numel(idxTrim) < round(0.1*L)
    warning('Trim too aggressive. Reducing.');
    trimN = round(0.02*fs);
    idxTrim = (1+trimN):(L-trimN);
end

tTrimAll = t(idxTrim);
Ntrim    = numel(idxTrim);

Npad = min(round(0.1*fs), floor(length(x)/2)-1);
Npad = max(Npad, 1);
xPad = [flipud(x(1:Npad)); x; flipud(x(end-Npad+1:end))];

winN     = min(Ntrim, max(256, round(2.0*fs)));
if mod(winN,2)==1, winN = winN-1; end
ovN      = round(0.5*winN);
nfft_pw  = max(2048, 2^nextpow2(winN));
hannWin  = hann(winN, 'periodic');

maxLagSamp = min(round(0.25*fs), Ntrim-1);
hasOptim   = opts.useNonlinearFit && license('test','Optimization_Toolbox');

% =========================================================
% Figures
% =========================================================
if opts.plot_vib_overviews
    FM_overview = figure('Name','FM Overview','Color','w');
    tiledlayout(FM_overview,4,4,'TileSpacing','tight','Padding','tight');
    FM_overlay  = figure('Name','Frequency Envelope Overlay','Color','w');
    AM_overview = figure('Name','AM Overview','Color','w');
    tiledlayout(AM_overview,4,4,'TileSpacing','tight','Padding','tight');
    AM_overlay  = figure('Name','Amplitude Envelope Overlay','Color','w');
end
if opts.plot_harm_amps
    harm_amps_overview = figure('Name','Harmonic Amplitudes (No-Vib)','Color','w');
    title('Vibrato-removed amplitude envelopes (per harmonic)');
    tiledlayout(harm_amps_overview,5,4,'TileSpacing','tight','Padding','tight');
end

% =========================================================
% Harmonic loop
% =========================================================
for k = 1:K
    fc     = k * f0Hz;
    bwHalf = opts.bandwidthF0Frac * f0Hz;

    if fc >= 0.49*fs
        warning('Harmonic %d (%.1f Hz) too high. Skipping.', k, fc);
        continue;
    end

    % Complex demodulation
    zkpad = local_complex_demod_analytic(xPad, fc, bwHalf, fs);
    zk    = zkpad(1+Npad : length(x)+Npad);

    % Amplitude
    % V12: multiplicative AM model.
    %
    %   ampEnv(t) = ampNoVib(t) * amGain(t)
    %   amLog(t)  = log(ampEnv(t)) - log(ampNoVib(t))
    %   am(t)     = amGain(t) - 1 = exp(amLog(t)) - 1
    %
    % Low-passing in log-amplitude makes the vibrato/no-vibrato split
    % multiplicative in linear amplitude and prevents negative synthesis
    % amplitudes when reconstructing with ampNoVib .* exp(amLog).
    ampEnv = abs(zk);
    ampFloor = max(1e-12, opts.ampFloorFrac * max(ampEnv));
    ampEnvSafe = max(ampEnv, ampFloor);

    logAmp      = log(ampEnvSafe);
    logAmpNoVib = local_lowpass_zero_phase(logAmp, opts.ampNoVibLpHz, fs);
    ampNoVib    = exp(logAmpNoVib);

    amLogRaw  = logAmp - logAmpNoVib;
    amGainRaw = exp(amLogRaw);
    amRaw     = amGainRaw - 1;

    % V14: only keep vibrato where the smoothed no-vibrato amplitude
    % envelope is strong enough. Gating on ampNoVib, rather than the
    % instantaneous ampEnv, avoids mask flicker when vibrato cycles or noise
    % briefly cross the threshold. Below this threshold, fractional/log AM
    % and phase-derived FM are unreliable. NaNs make plots break in those
    % regions and keep metrics from being biased by low-amplitude tails.
    vibAmpThreshold = opts.vibAmpMinFrac * max(ampNoVib);
    vibAmpMask = ampNoVib >= vibAmpThreshold;

    amLog  = amLogRaw;
    amGain = amGainRaw;
    am     = amRaw;
    amLog(~vibAmpMask)  = NaN;
    amGain(~vibAmpMask) = NaN;
    am(~vibAmpMask)     = NaN;

    % Frequency
    % triued lowpassing phase to remove spiking, didn't help that much,
    % chose median outlier masking instead
    % zk_smooth = local_lowpass_zero_phase(real(zk), opts.fmComplexLpHz, fs) + ...
    %         1j * local_lowpass_zero_phase(imag(zk), opts.fmComplexLpHz, fs);
    % 
    % ph = unwrap(angle(zk_smooth));

    ph = unwrap(angle(zk));
    ph = ph(:);
    if numel(ph) >= 2
        dph = [diff(ph); ph(end)-ph(end-1)];
    else
        dph = zeros(size(ph));
    end
    f_res  = dph * (fs/(2*pi));
    f_inst = fc + f_res;

    % Additional FM reliability gate: ignore phase-derived frequency
    % samples whose per-sample phase increment is too large. Isolated
    % rejected spikes are replaced by linear interpolation between the
    % nearest valid samples before low-pass smoothing; leading/trailing
    % rejected regions are held at the nearest valid endpoint.
    phaseJumpMask = isfinite(dph) & (abs(dph) <= opts.maxPhaseJump);
    reliableMask  = vibAmpMask & phaseJumpMask & isfinite(f_res);

    %Outlier mask
    opts.fmOutlierWin = round(0.03 * fs);  % 30 ms
    opts.fmOutlierSigma = 4;
    medLocal = movmedian(f_res, opts.fmOutlierWin);
    madLocal = movmedian(abs(f_res - medLocal), opts.fmOutlierWin);
    sigmaRobust = 1.4826 * madLocal;

    outlierMask = abs(f_res - medLocal) <= opts.fmOutlierSigma * sigmaRobust;
    reliableMask = reliableMask & outlierMask;

    interpMask    = reliableMask;
    if ~any(interpMask)
        % If the amplitude gate rejects an entire harmonic, still avoid
        % zeroing the frequency track: interpolate from phase-valid samples
        % where possible. This replaces the old f_res_clean(:)=0 fallback.
        interpMask = phaseJumpMask & isfinite(f_res);
    end
    f_res_clean = local_fill_missing_linear_hold(t, f_res, interpMask);

    f_res_noVib = local_lowpass_zero_phase(f_res_clean, opts.freqNoVibLpHz, fs);
    freqNoVibHz = fc + f_res_noVib;
    vibFmHzRaw  = f_inst - freqNoVibHz;
    vibFmHz     = vibFmHzRaw;
    vibFmHz(~reliableMask) = NaN;

    tTrim         = t(idxTrim);        tTrim = tTrim(:);
    amTrim        = am(idxTrim);       amTrim = amTrim(:);
    vibFmTrim     = vibFmHz(idxTrim);  vibFmTrim = vibFmTrim(:);
    freqNoVibTrim = freqNoVibHz(idxTrim); freqNoVibTrim = freqNoVibTrim(:);
    validVibTrimMask = reliableMask(idxTrim); validVibTrimMask = validVibTrimMask(:);
    validVibTrimMask = validVibTrimMask & isfinite(amTrim) & isfinite(vibFmTrim) & isfinite(freqNoVibTrim);
    nMetricValid = nnz(validVibTrimMask);

    % Keep metric tracks on the original trimmed sample grid.
    % Invalid/missing samples are replaced with the median of the valid
    % samples instead of being deleted, so Welch/xcorr keep correct timing.
    amMetric        = local_fill_missing_median(amTrim,        validVibTrimMask);
    vibFmMetric     = local_fill_missing_median(vibFmTrim,     validVibTrimMask);
    freqNoVibMetric = local_fill_missing_median(freqNoVibTrim, validVibTrimMask);

    % Segmented envelope fit
    % V19: use the raw/lightly smoothed harmonic amplitude for the attack
    % region. The low-rate no-vibrato envelope is excellent for sustain,
    % but it smooths away brass onsets.
    if opts.attackUseRawEnvelope
        ampAttackFit = local_lowpass_zero_phase(max(ampEnv,0), opts.attackRawLpHz, fs);
    else
        ampAttackFit = ampNoVib;
    end
    expStruct = local_fit_segmented_envelope(ampNoVib, ampAttackFit, idxTrim, tTrim, t, globalTiming, opts, hasOptim);

    % Ideal overlays
    doIdeal = opts.testWaveform && opts.overlayIdeal && ~isempty(testInfo);
    if doIdeal
        Ak = 1/k;
        if isfield(testInfo,'harmAmps') && numel(testInfo.harmAmps)>=k
            Ak = testInfo.harmAmps(k);
        end
        amIdealTrim        = opts.testAmpVibDepth * sin(2*pi*opts.testAmpVibRateHz*tTrim);
        ampEnvIdealTrim    = Ak/2 * (1 + amIdealTrim);
        idealFloor         = max(1e-12, opts.ampFloorFrac * max(ampEnvIdealTrim));
        ampNoVibIdealTrim  = exp(local_lowpass_zero_phase(log(max(ampEnvIdealTrim, idealFloor)), opts.ampNoVibLpHz, fs));
        centsTrim          = opts.testFmVibDepthCents * sin(2*pi*opts.testFmVibRateHz*tTrim);
        vibFmIdealTrim     = k * (opts.testF0Hz*(2.^(centsTrim/1200)) - opts.testF0Hz);
        freqNoVibIdealTrim = k * opts.testF0Hz;
    end

    % Metrics: use only samples above the per-harmonic amplitude threshold.
    minMetricN = max(16, round(0.05*fs));
    if nMetricValid >= minMetricN
        amDepth    = prctile(amMetric,95)    - prctile(amMetric,5);
        fmDepth    = prctile(vibFmMetric,95) - prctile(vibFmMetric,5);
        meanFreqHz = median(freqNoVibMetric);
    else
        amDepth = NaN;
        fmDepth = NaN;
        finiteFreq = freqNoVibTrim(isfinite(freqNoVibTrim));
        if ~isempty(finiteFreq)
            meanFreqHz = median(finiteFreq);
        else
            meanFreqHz = NaN;
        end
    end

    if nMetricValid >= minMetricN && numel(vibFmMetric) >= minMetricN && std(vibFmMetric) > 0
        winN_k = min(numel(vibFmMetric), max(256, round(2.0*fs)));
        if mod(winN_k,2)==1, winN_k = winN_k-1; end
        if winN_k >= 16
            ovN_k = round(0.5*winN_k);
            nfft_k = max(2048, 2^nextpow2(winN_k));
            [Pyy,fP] = pwelch(vibFmMetric-mean(vibFmMetric), hann(winN_k,'periodic'), ovN_k, nfft_k, fs);
            bandMask  = fP>=vibBand(1) & fP<=vibBand(2);
            if any(bandMask)
                [~,iPk] = max(Pyy(bandMask));
                fBand = fP(bandMask);
                vibRateHz = fBand(iPk);
            else
                vibRateHz = NaN;
            end
        else
            vibRateHz = NaN;
        end
    else
        vibRateHz = NaN;
    end

    if nMetricValid >= minMetricN && numel(amMetric) >= minMetricN && std(amMetric) > 0 && std(vibFmMetric) > 0
        maxLagSamp_k = min(round(0.25*fs), numel(amMetric)-1);
        [c,lags] = xcorr(amMetric-mean(amMetric), vibFmMetric-mean(vibFmMetric), maxLagSamp_k, 'coeff');
        [~,imax] = max(c);
        delayS   = lags(imax)/fs;
        if isfinite(vibRateHz) && vibRateHz>0
            Tper   = 1/vibRateHz;
            delayS = mod(delayS+Tper/2,Tper)-Tper/2;
        end
    else
        delayS = NaN;
    end

    % Store
    R.harm(k).k = k;
    R.harm(k).fcHz = fc;
    R.harm(k).bwHalfHz = bwHalf;
    R.harm(k).zk = zk;
    R.harm(k).ampEnv = ampEnv;
    R.harm(k).ampNoVib = ampNoVib;
    R.harm(k).am = am;
    R.harm(k).amGain = amGain;
    R.harm(k).amLog = amLog;
    R.harm(k).amRaw = amRaw;
    R.harm(k).amGainRaw = amGainRaw;
    R.harm(k).amLogRaw = amLogRaw;
    R.harm(k).ampFloor = ampFloor;
    R.harm(k).vibAmpMask = vibAmpMask;
    R.harm(k).vibAmpThreshold = vibAmpThreshold;
    R.harm(k).vibAmpMinFrac = opts.vibAmpMinFrac;
    R.harm(k).phaseJumpMask = phaseJumpMask;
    R.harm(k).reliableFmMask = reliableMask;
    R.harm(k).maxPhaseJump = opts.maxPhaseJump;
    R.harm(k).instFreqHz = f_inst;
    R.harm(k).freqNoVibHz = freqNoVibHz;
    R.harm(k).vibFmHz = vibFmHz;
    R.harm(k).vibFmHzRaw = vibFmHzRaw;
    R.harm(k).expEnv = expStruct;
    R.harm(k).metrics = struct('meanFreqHz',meanFreqHz,'amDepth',amDepth, ...
        'amDepthPct',100*amDepth,'fmDepthHz',fmDepth,'vibRateHz',vibRateHz, ...
        'amFmDelayMs',delayS*1000,'numVibSamples',numel(amMetric), ...
        'vibAmpMinFrac',opts.vibAmpMinFrac);
    if doIdeal
        R.harm(k).ideal = struct('amTrim',amIdealTrim,'vibFmHzTrim',vibFmIdealTrim, ...
            'ampEnvTrim',ampEnvIdealTrim,'ampNoVibTrim',ampNoVibIdealTrim, ...
            'freqNoVibHzTrim',freqNoVibIdealTrim);
    end

    % ---- Plots ----
    if opts.plot_vib
        figure('Name',sprintf('Harmonic %d (fc=%.1f Hz)',k,fc),'Color','w');

        subplot(5,1,1);
        plot(t,ampNoVib,'DisplayName','ampNoVib'); hold on;
        if opts.plot_expEnv
            plot(tTrim,expStruct.envFitTrim,'r--','LineWidth',1.5, ...
                'DisplayName',sprintf('Interp fit (R2=%.3f)',expStruct.r2));
            xline(expStruct.segments.attack.tEnd,'k:','Attack end');
            if isfield(expStruct.segments.release,'hasRelease') && expStruct.segments.release.hasRelease
                xline(expStruct.segments.release.tStart,'k--','Release start');
            end
            legend('Location','best');
        end
        grid on; title(sprintf('Amplitude Envelope (vibrato removed), k=%d, fc=%.1f Hz',k,fc));
        xlabel('Time (s)'); ylabel('Amplitude');

        subplot(5,1,2);
        plot(tTrim,freqNoVibTrim,'DisplayName','Measured'); hold on;
        if doIdeal
            plot(tTrim,freqNoVibIdealTrim*ones(size(tTrim)),'--','DisplayName','Ideal');
            legend('Location','best');
        end
        grid on; title(sprintf('Frequency Envelope (vibrato removed), mean=%.2f Hz',meanFreqHz));
        xlabel('Time (s)'); ylabel('Freq no-vib (Hz)');

        subplot(5,1,3);
        plot(tTrim,amTrim,'DisplayName','Measured'); hold on;
        if doIdeal
            plot(tTrim,amIdealTrim,'--','DisplayName','Ideal'); legend('Location','best');
        end
        grid on; title(sprintf('AM(t) multiplicative fractional  depth=%.3f (%.1f%%)',amDepth,100*amDepth));
        xlabel('Time (s)'); ylabel('AM (fraction)');

        subplot(5,1,4);
        plot(tTrim,vibFmTrim,'DisplayName','Measured'); hold on;
        if doIdeal
            plot(tTrim,vibFmIdealTrim,'--','DisplayName','Ideal'); legend('Location','best');
        end
        grid on; title(sprintf('Vibrato FM (Hz)  depth=%.2f Hz  rate=%.2f Hz',fmDepth,vibRateHz));
        xlabel('Time (s)'); ylabel('FM vib (Hz)');

        subplot(5,1,5);
        plot(t,ampEnv,'DisplayName','ampEnv'); hold on;
        if opts.plot_expEnv
            plot(t,expStruct.envFit,'r--','LineWidth',1.5, ...
                'DisplayName',sprintf('Interp fit (RMSE=%.4f, R2=%.4f)',expStruct.rmse,expStruct.r2));
            legend('Location','best');
        end
        grid on; title('Raw Amplitude Envelope with Interpolation Fit');
        xlabel('Time (s)'); ylabel('Amplitude');
    end

    if opts.plot_vib_overviews
        figure(FM_overview); nexttile();
        plot(tTrim,vibFmTrim,'DisplayName','Measured','LineWidth',1.5); hold on;
        if doIdeal
            plot(tTrim,vibFmIdealTrim,'--','DisplayName','Ideal','LineWidth',1.5);
            legend('Location','best');
        end
        grid on; title(sprintf('H%d freq',k)); subtitle(sprintf('mean=%.1f Hz',meanFreqHz));
        xlabel('s'); ylabel('Hz');

        figure(AM_overview); nexttile();
        plot(tTrim,amTrim,'DisplayName','Measured','LineWidth',1.5); hold on;
        if doIdeal
            plot(tTrim,amIdealTrim,'--','DisplayName','Ideal','LineWidth',1.5);
            legend('Location','best');
        end
        grid on; title(sprintf('H%d amp',k)); xlabel('s'); ylabel('fraction');

        figure(FM_overlay);
        plot(tTrim,freqNoVibTrim,'DisplayName',['Measured H' num2str(k)],'LineWidth',1.5); hold on;
        if doIdeal
            plot(tTrim,freqNoVibIdealTrim*ones(size(tTrim)),'--','DisplayName',['Ideal H' num2str(k)]);
        end
        grid on; legend();

        figure(AM_overlay);
        % plot(tTrim,temp(idxTrim)); hold on;
        plot(tTrim,ampNoVib(idxTrim),'DisplayName',['Measured H' num2str(k)],'LineWidth',1.5); hold on;
        if opts.plot_expEnv
            plot(tTrim,expStruct.envFitTrim,'--','DisplayName',sprintf('Interp H%d (R2=%.3f)',k,expStruct.r2),'LineWidth',1.5);
        end
        if doIdeal
            plot(tTrim,ampNoVibIdealTrim,'--','DisplayName',['Ideal H' num2str(k)]);
        end
        grid on; legend();
    end

    if opts.plot_harm_amps
        figure(harm_amps_overview); nexttile();
        plot(tTrim,ampNoVib(idxTrim),'DisplayName','Measured'); hold on;
        if opts.plot_expEnv
            plot(tTrim,expStruct.envFitTrim,'r--','LineWidth',1.2, ...
                'DisplayName',sprintf('Interp (R2=%.3f)',expStruct.r2));
            legend('Location','best');
        end
        if doIdeal
            plot(tTrim,ampNoVibIdealTrim,'--','DisplayName','Ideal');
            legend('Location','best');
        end
        grid on; title(sprintf('H%d amp(no-vib)',k)); xlabel('Time (s)'); ylabel('|z|');
    end
end

if opts.plot_vib_overviews
    figure(FM_overlay); title('FM overlay (vibrato removed)'); xlabel('time (s)'); ylabel('Frequency (Hz)');
    figure(AM_overlay); title('Amplitude envelope overlay (vibrato removed)'); xlabel('time (s)'); ylabel('|z|');
end

if opts.plot_spectrogram
    local_plot_spectrogram_with_filterbank(x,fs,f0Hz,opts);
end

R.testInfo = testInfo;
R.synth = [];
R.params = local_make_resynthesis_params(R, opts);
R.version = 'V30_analysis';
R.analysisOpts = opts;

if opts.calcMetrics
    try
        R.metrics = vib_analyze_harmonics_metrics_V2(R);
        R.metricFigure = vib_plot_metrics_V2(R.metrics);
    catch ME
        warning('vib_analyze:metricsFailed', ...
            'Metric calculation failed (%s). Returning analysis and params anyway.', ME.message);
    end
end

S = R;
end

% ===================== Local helpers =====================


function [x, fs, opts, sourceAudioPath] = local_resolve_audio_input(audioIn, opts)
%LOCAL_RESOLVE_AUDIO_INPUT Accept either a numeric audio vector or an audio filepath.
sourceAudioPath = "";
fs = opts.fs;

if isempty(audioIn) && strlength(string(opts.audioPath)) > 0
    audioIn = opts.audioPath;
end

if isstring(audioIn) || ischar(audioIn)
    sourceAudioPath = string(audioIn);
    if strlength(sourceAudioPath) == 0
        error('Provide an audio vector, an audio file path, opts.audioPath, or set opts.testWaveform=true.');
    end
    audioPathChar = char(sourceAudioPath);
    if ~isfile(audioPathChar)
        error('Audio file not found: %s', audioPathChar);
    end

    [x, fileFs] = audioread(audioPathChar);
    if isempty(fs) || ~isfinite(fs) || fs <= 0
        fs = fileFs;
        opts.fs = fileFs;
    elseif fs ~= fileFs
        if exist('resample','file') == 2
            warning('vib_analyze:resampleAudioPath', ...
                'opts.fs (%g Hz) differs from file sample rate (%g Hz). Resampling audio to opts.fs.', fs, fileFs);
            x = resample(x, fs, fileFs);
        else
            error(['opts.fs (%g Hz) differs from the audio file sample rate (%g Hz), ' ...
                'and resample() is unavailable. Remove opts.fs or resample the audio manually.'], fs, fileFs);
        end
    end
    return;
end

if isnumeric(audioIn)
    x = audioIn;
    if isempty(x)
        error('Provide an audio vector, an audio file path, opts.audioPath, or set opts.testWaveform=true.');
    end
    if isempty(fs) || ~isfinite(fs) || fs <= 0
        error('When providing a numeric audio vector, set opts.fs to the sampling rate.');
    end
    return;
end

error('First input must be either a numeric audio vector or an audio file path.');
end

function es = local_fit_segmented_envelope(ampNoVib, ampAttackFit, idxTrim, tTrim, tFull, globalTiming, opts, hasOptim) %#ok<INUSD>
yFitFull  = max(ampNoVib(idxTrim), 0);
yFitFull  = yFitFull(:);
yAttackFull = max(ampAttackFit(idxTrim), 0);
yAttackFull = yAttackFull(:);
tTrim     = tTrim(:);
Nfull     = numel(yFitFull);
envFull   = nan(size(tFull));

if Nfull < 6 || max(yFitFull) <= 0
    envFull(idxTrim) = yFitFull;
    es = struct('type','global_attack_body_interp','envFit',envFull,'envFitTrim',yFitFull, ...
        'baseline',0,'sourceDurationSec',max(tFull(:))-min(tFull(:))+eps, ...
        'residual',zeros(size(yFitFull)),'rmse',0,'r2',1, ...
        'segments',struct('attack',struct(),'body',struct(),'release',struct()), ...
        'fitEvalIdxStartTrim',1,'fitEvalIdxEndTrim',Nfull, 'fitFs', Inf);
    return;
end

[tFit, yFit] = local_prepare_env_fit_grid(tTrim, yFitFull, opts.envFitFs);
yFit = max(yFit(:), 0);
yAttackOnFit = interp1(tTrim, yAttackFull, tFit, 'pchip', 'extrap');
yAttackOnFit(~isfinite(yAttackOnFit)) = 0;
yAttackOnFit = max(yAttackOnFit(:), 0);
N = numel(yFit);
dt = median(diff(tFit));
if ~isfinite(dt) || dt <= 0, dt = max(median(diff(tTrim)), eps); end
minSegN = max(3, round((opts.minSegmentMs/1000) / dt));
anchorHalfWin = max(0, round((opts.anchorMedianMs/1000) / dt / 2));
attackAnchorHalfWin = max(0, round((opts.attackAnchorMedianMs/1000) / dt / 2));
attackModel = lower(strtrim(opts.attackModel));

% --- Global waveform-based segment boundaries (fixed for all harmonics) ---
iOnset = local_time_to_trim_index(globalTiming.tOnset, tFit);
iAttackEnd = local_time_to_trim_index(globalTiming.tAttackEnd, tFit);
iReleaseStart = local_time_to_trim_index(globalTiming.tRelease, tFit);
iNoteEnd = local_time_to_trim_index(globalTiming.tNoteEnd, tFit);

iOnset = max(1, min(N-2, iOnset));
iAttackEnd = max(iOnset + 1, min(N-1, iAttackEnd));
iNoteEnd = max(iAttackEnd + 1, min(N, iNoteEnd));
if globalTiming.hasRelease
    iReleaseStart = max(iAttackEnd + 1, min(iNoteEnd, iReleaseStart));
else
    iReleaseStart = iNoteEnd;
end

% For fit error, ignore pre-onset and low tail, but keep the same segment times.
yPeak = max(yFit(max(1,iOnset):iNoteEnd));
activeThresh = max(opts.fitErrorMinFrac * yPeak, 0.005 * yPeak);
iActiveEnd = find(yFit(1:iNoteEnd) >= activeThresh, 1, 'last');
if isempty(iActiveEnd)
    iActiveEnd = iNoteEnd;
else
    iActiveEnd = max(iAttackEnd + 1, min(iNoteEnd, iActiveEnd));
end

preBase = median(yFit(1:max(1, iOnset)));
if ~isfinite(preBase) || preBase < 0, preBase = 0; end

% V19 hybrid target: use raw/lightly smoothed harmonic amplitude during
% the first part of the note, then fade back to the low-passed no-vibrato
% envelope. This keeps the brass attack/settling shape without allowing
% vibrato/noise to dominate the sustain model.
yFitHybrid = yFit;
if opts.attackUseRawEnvelope
    hybridEndTime = tFit(iOnset) + max(opts.attackHybridMs, 0)/1000;
    hybridEndIdx = min(iNoteEnd, max(iAttackEnd, local_time_to_trim_index(hybridEndTime, tFit)));
    hybridFadeStartIdx = iAttackEnd;
    rawWeight = zeros(N,1);
    rawWeight(iOnset:hybridFadeStartIdx) = 1;
    if hybridEndIdx > hybridFadeStartIdx
        fadeX = linspace(1, 0, hybridEndIdx - hybridFadeStartIdx + 1).';
        rawWeight(hybridFadeStartIdx:hybridEndIdx) = max(rawWeight(hybridFadeStartIdx:hybridEndIdx), fadeX);
    end
    yFitHybrid = rawWeight .* yAttackOnFit + (1 - rawWeight) .* yFit;
    yFitHybrid(~isfinite(yFitHybrid)) = 0;
    yFitHybrid = max(yFitHybrid(:), 0);
end

envFitDs = zeros(N,1);
envFitDs(1:max(1, iOnset-1)) = preBase;

% Attack: global onset to global attack end only. Any later rise is handled by the body.
% V19 can use a PCHIP attack with several local anchors. This preserves fast
% brass-like onset curvature while retaining the old smoothstep option.
tA = tFit(iOnset:iAttackEnd);
yAttackEnd = max(yFitHybrid(iAttackEnd), preBase);
attackIdx = local_knot_indices(iOnset, iAttackEnd, max(3, round(opts.attackNumKnots)));
if opts.attackIncludeLocalPeak && iAttackEnd > iOnset
    [~, iLocalPeakRel] = max(yFitHybrid(iOnset:iAttackEnd));
    iLocalPeak = iOnset + iLocalPeakRel - 1;
    attackIdx = unique([attackIdx(:); iLocalPeak(:)]).';
end
attackVals = local_anchor_values(yFitHybrid, attackIdx, attackAnchorHalfWin);
attackVals(1) = preBase;
attackVals(end) = max(attackVals(end), preBase);

if numel(tA) <= 1
    yAttackFit = yFitHybrid(iOnset:iAttackEnd);
    attackModelUsed = 'degenerate_direct';
elseif strcmpi(attackModel, 'smoothstep')
    xA = (tA - tA(1)) / max(tA(end) - tA(1), eps);
    yAttackFit = preBase + (yAttackEnd - preBase) * smoothstep_poly(xA, opts.attackShapeOrder);
    yAttackFit(1) = preBase;
    yAttackFit(end) = yAttackEnd;
    attackModelUsed = 'global_gated_smoothstep';
elseif strcmpi(attackModel, 'pchipanchors')
    attackT = tFit(attackIdx);
    [attackT, ia] = unique(attackT(:), 'stable');
    attackValsUse = attackVals(ia);
    if numel(attackT) < 2
        yAttackFit = yFitHybrid(iOnset:iAttackEnd);
        attackModelUsed = 'pchip_attack_fallback_direct';
    else
        yAttackFit = interp1(attackT, attackValsUse, tA, 'pchip');
        yAttackFit(1) = preBase;
        yAttackFit(end) = attackValsUse(end);
        attackModelUsed = 'global_gated_pchip_attack_anchors';
    end
else
    warning('vib_analysis:unknownAttackModel', ...
        'Unknown opts.attackModel "%s". Falling back to pchipAnchors.', opts.attackModel);
    attackT = tFit(attackIdx);
    [attackT, ia] = unique(attackT(:), 'stable');
    attackValsUse = attackVals(ia);
    yAttackFit = interp1(attackT, attackValsUse, tA, 'pchip');
    yAttackFit(1) = preBase;
    yAttackFit(end) = attackValsUse(end);
    attackModelUsed = 'global_gated_pchip_attack_anchors_fallback';
end
yAttackFit(~isfinite(yAttackFit)) = 0;
envFitDs(iOnset:iAttackEnd) = max(yAttackFit(:), 0);

% Body/sustain: same global segment for every harmonic.
iBodyStart = iAttackEnd;
iBodyEnd = iReleaseStart;
if iBodyEnd < iBodyStart
    iBodyEnd = iBodyStart;
end
bodyIdx = local_knot_indices(iBodyStart, iBodyEnd, max(2, round(opts.bodyNumKnots)));
if ~isempty(opts.bodyEarlyAnchorMs) && iBodyEnd > iBodyStart
    earlyIdx = iBodyStart + round((opts.bodyEarlyAnchorMs(:).'/1000) / dt);
    earlyIdx = earlyIdx(earlyIdx > iBodyStart & earlyIdx < iBodyEnd);
    bodyIdx = unique([bodyIdx(:); earlyIdx(:)]).';
end
bodyVals = local_anchor_values(yFitHybrid, bodyIdx, anchorHalfWin);
bodyVals(1) = envFitDs(iBodyStart);
bodyVals(end) = max(bodyVals(end), 0);
if numel(bodyIdx) == 1
    bodyFit = bodyVals(1);
    envFitDs(iBodyStart) = bodyVals(1);
else
    bodyT = tFit(bodyIdx);
    bodyFit = interp1(bodyT, bodyVals, tFit(iBodyStart:iBodyEnd), 'pchip');
    bodyFit = max(bodyFit(:), 0);
    envFitDs(iBodyStart:iBodyEnd) = bodyFit;
end

% Release: same global release segment for every harmonic.
hasRelease = globalTiming.hasRelease && (iReleaseStart < iNoteEnd);
releaseInfo = struct('hasRelease',hasRelease,'method','global_waveform','improvement',NaN);
if hasRelease
    tailIdx = local_knot_indices(iReleaseStart, iNoteEnd, max(2, round(opts.tailNumKnots)));
    tailVals = local_anchor_values(yFit, tailIdx, anchorHalfWin);
    tailVals(1) = envFitDs(iReleaseStart);
    tailVals(end) = preBase;
    tailT = tFit(tailIdx);
    tailFit = interp1(tailT, tailVals, tFit(iReleaseStart:iNoteEnd), 'pchip');
    tailFit = max(tailFit(:), 0);
    envFitDs(iReleaseStart:iNoteEnd) = tailFit;
else
    tailIdx = iNoteEnd;
    tailVals = envFitDs(iNoteEnd);
    tailT = tFit(iNoteEnd);
    tailFit = [];
    if iNoteEnd > iBodyEnd
        y0T = envFitDs(iBodyEnd);
        envFitDs(iBodyEnd:iNoteEnd) = local_smooth_taper(y0T, preBase, iNoteEnd - iBodyEnd + 1);
    end
end

% After the global note end, taper quickly to baseline.
if iNoteEnd < N
    envFitDs(iNoteEnd:end) = local_smooth_taper(envFitDs(iNoteEnd), preBase, N - iNoteEnd + 1);
end
envFitDs = max(envFitDs, 0);

envTrim = interp1(tFit, envFitDs, tTrim, 'pchip', 'extrap');
envTrim = max(envTrim(:), 0);
envFull(idxTrim) = envTrim;
residual = yFitFull - envTrim;

fitEvalStart = max(1, local_time_to_trim_index(tFit(iOnset), tTrim));
fitEvalEnd = max(fitEvalStart, local_time_to_trim_index(tFit(iActiveEnd), tTrim));
fitIdx = fitEvalStart:fitEvalEnd;
resEval = residual(fitIdx);
ssRes = sum(resEval.^2);
ssTot = sum((yFitFull(fitIdx) - mean(yFitFull(fitIdx))).^2);

es = struct();
es.type = 'global_attack_body_interp';
es.envFit = envFull;
es.envFitTrim = envTrim;
es.residual = residual;
es.rmse = sqrt(mean(resEval.^2));
es.r2 = 1 - ssRes / max(ssTot, eps);
es.fitEvalIdxStartTrim = fitEvalStart;
es.fitEvalIdxEndTrim = fitEvalEnd;
es.fitFs = 1 / max(dt, eps);
es.baseline = preBase;
es.sourceDurationSec = max(tFull(:)) - min(tFull(:)) + 1/max(1, round(1/max(dt, eps)));
es.segments = struct();
es.segments.attack = struct( ...
    'idxStartTrim',max(1, local_time_to_trim_index(tFit(iOnset), tTrim)), ...
    'idxEndTrim',max(1, local_time_to_trim_index(tFit(iAttackEnd), tTrim)), ...
    'tStart',tFit(iOnset), ...
    'tEnd',tFit(iAttackEnd), ...
    'fit',yAttackFit(:), ...
    'knotIdx',attackIdx(:), ...
    'knotTimes',tFit(attackIdx), ...
    'knotValues',attackVals(:), ...
    'model',attackModelUsed);
es.segments.body = struct( ...
    'idxStartTrim',max(1, local_time_to_trim_index(tFit(iBodyStart), tTrim)), ...
    'idxEndTrim',max(1, local_time_to_trim_index(tFit(iBodyEnd), tTrim)), ...
    'tStart',tFit(iBodyStart), ...
    'tEnd',tFit(iBodyEnd), ...
    'knotIdx',bodyIdx(:), ...
    'knotTimes',tFit(bodyIdx), ...
    'knotValues',bodyVals(:), ...
    'fit',envFitDs(iBodyStart:iBodyEnd), ...
    'model','global_pchip_body_interp');
es.segments.release = struct( ...
    'idxStartTrim',max(1, local_time_to_trim_index(tFit(min(iReleaseStart,N)), tTrim)), ...
    'idxEndTrim',max(1, local_time_to_trim_index(tFit(iNoteEnd), tTrim)), ...
    'tStart',tFit(min(iReleaseStart,N)), ...
    'tEnd',tFit(iNoteEnd), ...
    'fit',tailFit, ...
    'knotIdx',tailIdx(:), ...
    'knotTimes',tailT(:), ...
    'knotValues',tailVals(:), ...
    'model','global_pchip_release_interp', ...
    'hasRelease',hasRelease, ...
    'info',releaseInfo);
end

function idx = local_knot_indices(iStart, iEnd, nKnots)
iStart = round(iStart); iEnd = round(iEnd);
if iEnd <= iStart
    idx = iStart;
    return;
end
nKnots = max(2, round(nKnots));
idx = unique(round(linspace(iStart, iEnd, nKnots)));
if idx(1) ~= iStart, idx = [iStart, idx]; end
if idx(end) ~= iEnd, idx = [idx, iEnd]; end
idx = unique(idx(:).');
end

function vals = local_anchor_values(y, idx, halfWin)
y = y(:);
vals = zeros(numel(idx),1);
for ii = 1:numel(idx)
    lo = max(1, idx(ii) - halfWin);
    hi = min(numel(y), idx(ii) + halfWin);
    vals(ii) = median(y(lo:hi));
end
end

function y = local_smooth_taper(y0, y1, n)
if n <= 1
    y = y1;
    return;
end
x = linspace(0,1,n).';
y = y0 + (y1 - y0) * smoothstep_poly(x, 5);
end

function y = local_movmean1(x, w)
x = x(:);
w = max(1, round(w));
if w <= 1
    y = x;
else
    k = ones(w,1) / w;
    y = conv(x, k, 'same');
end
end

function timing = local_detect_global_envelope_timing(x, fs, opts)
t = (0:numel(x)-1).' / fs;
% Use the overall waveform envelope to define note-level segmentation.
% V30 changes the onset logic from a simple first-threshold crossing to a
% peak-anchored backtracking method. This prevents low-level pre-onset noise
% or pickup buzz from being labeled as the note onset when the true attack is
% a later sharp transient.
gRaw = abs(hilbert(x(:)));
g = local_lowpass_zero_phase(gRaw, opts.globalEnvLpHz, fs);
g = max(g, 0);
[tg, gg] = local_prepare_env_fit_grid(t, g, opts.globalEnvFs);
N = numel(gg);

[peakVal, iPeak] = max(gg);
if ~isfinite(peakVal) || peakVal <= 0
    timing = struct('idxOnset',1,'idxAttackEnd',1,'idxPeak',1, ...
        'idxRelease',N,'idxNoteEnd',N,'tOnset',tg(1),'tAttackEnd',tg(1), ...
        'tPeak',tg(1),'tRelease',tg(end),'tNoteEnd',tg(end), ...
        'hasRelease',false,'releaseInfo',struct(), ...
        'onsetInfo',struct('method','empty_signal'));
    return;
end

dt = median(diff(tg));
if ~isfinite(dt) || dt <= 0, dt = 1/fs; end
minSegN = max(3, round((opts.minSegmentMs/1000) / dt));

% First-threshold onset is kept as the conservative/default candidate.
thOn = max(opts.globalOnsetFrac * peakVal, eps);
iFirstOnset = find(gg >= thOn, 1, 'first');
if isempty(iFirstOnset), iFirstOnset = 1; end

% Peak-backtracked onset candidate. Starting from the main global peak,
% walk backward until the envelope has stayed below a small threshold for a
% short hold time. For plucked notes this lands just before the real attack
% peak instead of at an earlier false threshold crossing.
thBack = max(max(opts.globalOnsetBacktrackFrac, opts.globalOnsetFrac) * peakVal, eps);
holdN = max(1, round((opts.globalOnsetBacktrackHoldMs/1000) / dt));
iPeakBackOnset = iFirstOnset;
if opts.globalUsePeakBacktrack && iPeak > 1
    for ii = iPeak-1:-1:1
        lo = max(1, ii - holdN + 1);
        if all(gg(lo:ii) < thBack)
            iPeakBackOnset = min(iPeak, ii + 1);
            break;
        end
    end
end

% Use the peak-backtracked onset only when it makes a meaningful correction
% and the corrected onset-to-peak time is consistent with a sharp attack.
oldPeakDelaySec = (iPeak - iFirstOnset) * dt;
backPeakDelaySec = (iPeak - iPeakBackOnset) * dt;
correctionSec = (iPeakBackOnset - iFirstOnset) * dt;
sharpAttackSec = max(opts.globalSharpAttackMaxMs, opts.attackMaxMs) / 1000;
minCorrectionSec = opts.globalOnsetMinCorrectionMs / 1000;
useBacktrackedOnset = opts.globalUsePeakBacktrack && ...
    iPeakBackOnset > iFirstOnset && ...
    correctionSec >= minCorrectionSec && ...
    backPeakDelaySec <= sharpAttackSec && ...
    oldPeakDelaySec > sharpAttackSec;

if useBacktrackedOnset
    iOnset = iPeakBackOnset;
    onsetMethod = 'peak_backtrack';
else
    iOnset = iFirstOnset;
    onsetMethod = 'first_threshold';
end

iOnset = max(1, min(N, iOnset));

% V30 attack end: if the main global peak is reached within the sharp-attack
% window after the corrected onset, treat the peak as the attack end. This is
% the desired behavior for guitar/plucked notes. Otherwise fall back to the
% V19 short-window local peak detector for slow or complex attacks.
dg = [diff(gg); 0];
iStart = min(N, iOnset + minSegN);
maxAttackN = max(minSegN + 1, round((opts.attackMaxMs/1000) / dt));
iSearchEnd = min(N, iOnset + maxAttackN);
attackThresh = max(opts.attackMinPeakFrac * peakVal, opts.globalOnsetFrac * peakVal);

if iPeak > iOnset && (iPeak - iOnset) <= maxAttackN && gg(iPeak) >= attackThresh
    iAttackEnd = iPeak;
    attackEndMethod = 'global_peak_within_attack_window';
else
    locMask = false(N,1);
    if N >= 3
        locMask(2:N-1) = (dg(1:N-2) > 0) & (dg(2:N-1) <= 0);
    end
    cand = [];
    if iStart <= iSearchEnd
        rel = find(locMask(iStart:iSearchEnd) & gg(iStart:iSearchEnd) >= attackThresh, 1, 'first');
        if ~isempty(rel)
            cand = iStart + rel - 1;
        end
    end
    if isempty(cand)
        if iStart <= iSearchEnd
            [~, relMaxEarly] = max(gg(iStart:iSearchEnd));
            iAttackEnd = iStart + relMaxEarly - 1;
            attackEndMethod = 'early_window_max';
        else
            iAttackEnd = max(iOnset + 1, min(N, iOnset + minSegN));
            attackEndMethod = 'minimum_segment_fallback';
        end
    else
        iAttackEnd = cand;
        attackEndMethod = 'first_local_peak_in_attack_window';
    end
end
iAttackEnd = max(iOnset + 1, min(N, iAttackEnd));

% Release detection from the global waveform envelope, after the attack.
if iAttackEnd < N - minSegN
    [relIdxFromAttack, relInfo] = local_best_release_index(gg(iAttackEnd:end), dt, minSegN, opts.releaseMinImprovement, [], [], opts.releaseSearchStride);
    hasRelease = relInfo.hasRelease;
    if hasRelease
        iRelease = iAttackEnd + relIdxFromAttack - 1;
    else
        iRelease = N;
    end
else
    relInfo = struct('hasRelease',false,'improvement',0,'sseSingle',NaN,'sseBest',NaN);
    hasRelease = false;
    iRelease = N;
end

% Note end from the global waveform envelope.
endThresh = max(opts.globalEndFrac * peakVal, eps);
iNoteEnd = find(gg >= endThresh, 1, 'last');
if isempty(iNoteEnd), iNoteEnd = N; end
iNoteEnd = max(iAttackEnd + 1, min(N, iNoteEnd));
if hasRelease
    iRelease = max(iAttackEnd + 1, min(iNoteEnd, iRelease));
else
    iRelease = iNoteEnd;
end

onsetInfo = struct( ...
    'method',onsetMethod, ...
    'attackEndMethod',attackEndMethod, ...
    'idxFirstThreshold',iFirstOnset, ...
    'tFirstThreshold',tg(iFirstOnset), ...
    'idxPeakBacktrack',iPeakBackOnset, ...
    'tPeakBacktrack',tg(iPeakBackOnset), ...
    'thresholdFirst',thOn, ...
    'thresholdBacktrack',thBack, ...
    'oldPeakDelaySec',oldPeakDelaySec, ...
    'backPeakDelaySec',backPeakDelaySec, ...
    'correctionSec',correctionSec, ...
    'usedBacktrackedOnset',useBacktrackedOnset);

timing = struct('idxOnset',iOnset,'idxAttackEnd',iAttackEnd,'idxPeak',iPeak, ...
    'idxRelease',iRelease,'idxNoteEnd',iNoteEnd, ...
    'tOnset',tg(iOnset),'tAttackEnd',tg(iAttackEnd),'tPeak',tg(iPeak), ...
    'tRelease',tg(iRelease),'tNoteEnd',tg(iNoteEnd), ...
    'hasRelease',hasRelease,'releaseInfo',relInfo,'onsetInfo',onsetInfo);
end

function [bestIdx, info] = local_best_release_index(y, dt, minSegN, minImprovement, idxLo, idxHi, stride)
y = max(y(:), eps);
n = numel(y);
if nargin < 4 || isempty(minImprovement), minImprovement = 0.12; end
if nargin < 5 || isempty(idxLo), idxLo = minSegN + 1; end
if nargin < 6 || isempty(idxHi), idxHi = n - minSegN + 1; end
if nargin < 7 || isempty(stride), stride = 8; end
idxLo = max(idxLo, minSegN + 1);
idxHi = min(idxHi, n - minSegN + 1);
stride = max(1, round(stride));
if idxLo > idxHi || n < 2*minSegN + 1
    bestIdx = n;
    info = struct('hasRelease',false,'improvement',0,'sseSingle',NaN,'sseBest',NaN);
    return;
end

ly = log(max(y, eps));
tau = (0:n-1).' * dt;
sseSingle = local_linefit_sse(tau, ly);

cand = idxLo:stride:idxHi;
if cand(end) ~= idxHi, cand(end+1) = idxHi; end
bestSSE = inf;
bestIdx = idxHi;
for j = cand
    sse1 = local_linefit_sse(tau(1:j), ly(1:j));
    sse2 = local_linefit_sse(tau(j:end), ly(j:end));
    sse = sse1 + sse2;
    if sse < bestSSE
        bestSSE = sse;
        bestIdx = j;
    end
end
improvement = max(0, (sseSingle - bestSSE) / max(sseSingle, eps));
hasRelease = improvement >= minImprovement;
info = struct('hasRelease',hasRelease,'improvement',improvement,'sseSingle',sseSingle,'sseBest',bestSSE,'stride',stride);
end

function sse = local_linefit_sse(x, y)
if numel(x) <= 2
    sse = 0;
    return;
end
p = polyfit(x(:), y(:), 1);
yh = polyval(p, x(:));
r = y(:) - yh(:);
sse = sum(r.^2);
end

function idx = local_time_to_trim_index(t0, tTrim)
[~, idx] = min(abs(tTrim - t0));
idx = max(1, min(numel(tTrim), idx));
end

function [tOut, yOut, mapIdx] = local_prepare_env_fit_grid(tIn, yIn, fitFs)
tIn = tIn(:); yIn = yIn(:);
if numel(tIn) <= 4
    tOut = tIn; yOut = yIn; mapIdx = (1:numel(tIn)).'; return;
end
dtIn = median(diff(tIn));
if ~isfinite(dtIn) || dtIn <= 0
    tOut = tIn; yOut = yIn; mapIdx = (1:numel(tIn)).'; return;
end
fsIn = 1 / dtIn;
if isempty(fitFs) || ~isfinite(fitFs) || fitFs >= 0.95 * fsIn
    tOut = tIn; yOut = yIn; mapIdx = (1:numel(tIn)).'; return;
end
step = max(1, round(fsIn / fitFs));
mapIdx = unique([1:step:numel(tIn), numel(tIn)]).';
tOut = tIn(mapIdx);
yOut = yIn(mapIdx);
end




function params = local_make_resynthesis_params(R, opts)
%LOCAL_MAKE_RESYNTHESIS_PARAMS  Build the compact struct needed by V30 resynthesis.
%
% V30 keeps S.params as a playback contract only.  Analysis diagnostics,
% provenance, fit-quality fields, and duplicate timing fields remain in the
% full S struct, not in S.params.
fs = R.fs;
t = R.t(:);
N = numel(t);
K = numel(R.harm);
sourceDur = N / fs;
vibBand = [opts.paramVibBandMinHz, opts.vibMaxHz];

params = struct();
params.version = 'V30_resynthesis_params_compact';
params.sourceFs = fs;
params.sourceNumSamples = N;
params.f0Hz = R.f0Hz;
params.analyticAmpScale = opts.paramAnalyticAmpScale;
params.globalEnvTiming = local_strip_global_env_timing(R.globalEnvTiming);
params.harm = repmat(struct(), K, 1);

vibStartAll = nan(K,1);
vibEndAll = nan(K,1);
vibConfidenceAll = nan(K,1);

for k = 1:K
    hk = R.harm(k);
    if ~isfield(hk, 'k') || isempty(hk.k)
        params.harm(k).k = k;
        params.harm(k).envModel = local_empty_env_model(opts);
        if opts.paramStoreAmModel
            params.harm(k).amModel = local_compact_fit_model(struct());
        end
        params.harm(k).fmModel = local_compact_fit_model(struct());
        params.harm(k).phaseOffsetRad = 0;
        continue;
    end

    if isfield(hk, 'expEnv') && isfield(hk.expEnv, 'envFit') && ~isempty(hk.expEnv.envFit)
        envFit = local_match_length(hk.expEnv.envFit(:), N);
    elseif isfield(hk, 'ampNoVib') && ~isempty(hk.ampNoVib)
        envFit = local_match_length(hk.ampNoVib(:), N);
    else
        envFit = zeros(N,1);
    end
    envFit(~isfinite(envFit)) = 0;
    envFit = max(envFit, 0);

    amTrack = nan(N,1);
    if isfield(hk, 'am') && ~isempty(hk.am)
        amTrack = local_match_length(hk.am(:), N);
    end
    fmTrack = nan(N,1);
    if isfield(hk, 'vibFmHz') && ~isempty(hk.vibFmHz)
        fmTrack = local_match_length(hk.vibFmHz(:), N);
    end

    % Estimate the time span where vibrato is actually active, then fit the
    % single-sine AM/FM models only over that span. This keeps attack/release
    % instability from biasing the stored vibrato depth/rate/phase.
    vibWindow = local_estimate_vibrato_window(t, amTrack, fmTrack, envFit, opts, fs, params.globalEnvTiming);

    % V30 inherits the V23 attack rejection: never fit sinusoidal vibrato
    % through the attack transient. For plucked notes, the early decay often
    % looks sinusoidal over a short interval even when there is no intentional
    % vibrato.
    fitStartSec = 0;
    fitEndSec = sourceDur;
    if isfield(params.globalEnvTiming, 'tAttackEnd') && isfinite(params.globalEnvTiming.tAttackEnd)
        fitStartSec = params.globalEnvTiming.tAttackEnd + opts.paramVibIgnoreAfterAttackSec;
    end
    if isfield(params.globalEnvTiming, 'hasRelease') && params.globalEnvTiming.hasRelease && ...
            isfield(params.globalEnvTiming, 'tRelease') && isfinite(params.globalEnvTiming.tRelease)
        fitEndSec = params.globalEnvTiming.tRelease;
    end

    vibFitMask = t >= max(0, fitStartSec) & t <= min(sourceDur, fitEndSec) & ...
        t >= vibWindow.startSec & t <= vibWindow.endSec;
    if nnz(vibFitMask & (isfinite(amTrack) | isfinite(fmTrack))) >= max(32, round(0.05*fs))
        amFitTrack = amTrack;
        fmFitTrack = fmTrack;
        amFitTrack(~vibFitMask) = NaN;
        fmFitTrack(~vibFitMask) = NaN;
    else
        amFitTrack = amTrack;
        fmFitTrack = fmTrack;
    end

    if opts.paramStoreAmModel
        amModel = local_fit_single_sine(t, amFitTrack, vibBand, fs);
        amModel = local_apply_single_vibrato_gate(amModel, 'AM', vibBand, opts);
    else
        amModel = local_compact_fit_model(struct());
    end
    fmModel = local_fit_single_sine(t, fmFitTrack, vibBand, fs);
    fmModel = local_apply_single_vibrato_gate(fmModel, 'FM', vibBand, opts);

    refIdx = [];
    if isfield(hk, 'vibAmpMask') && numel(hk.vibAmpMask) == N
        refIdx = find(hk.vibAmpMask(:) & envFit > 0, 1, 'first');
    end
    if isempty(refIdx)
        refIdx = find(envFit > 0, 1, 'first');
    end
    if isempty(refIdx), refIdx = 1; end

    phaseOffset = 0;
    if isfield(hk, 'zk') && numel(hk.zk) == N && isfinite(hk.zk(refIdx))
        fmSource = fmModel.amp * sin(2*pi*fmModel.freqHz*t + fmModel.phaseRad);
        fkSource = hk.k * R.f0Hz + fmSource;
        fkSource = min(max(fkSource, eps), 0.49*fs);
        phaseAccum = [0; cumsum(2*pi*fkSource(1:end-1)/fs)];
        desiredPhase = angle(hk.zk(refIdx)) + 2*pi*hk.fcHz*t(refIdx);
        phaseOffset = desiredPhase - phaseAccum(refIdx);
    end

    % Temporary rich models are kept until global consensus has a chance to
    % use isVibrato/rejectReason/r2. They are stripped after consensus below.
    params.harm(k).k = hk.k;
    params.harm(k).envModel = local_strip_env_model(hk, N, fs, sourceDur, opts);
    if opts.paramStoreAmModel
        params.harm(k).amModel = local_strip_fit_model(amModel);
    end
    params.harm(k).fmModel = local_strip_fit_model(fmModel);
    params.harm(k).phaseOffsetRad = phaseOffset;
    params.harm(k).vibrato = local_strip_vibrato_window(vibWindow);

    if any(envFit > 0) && isfinite(vibWindow.startSec) && isfinite(vibWindow.endSec) && vibWindow.endSec > vibWindow.startSec
        vibStartAll(k) = vibWindow.startSec;
        vibEndAll(k) = vibWindow.endSec;
        vibConfidenceAll(k) = vibWindow.confidence;
    end
end

validWindow = isfinite(vibStartAll) & isfinite(vibEndAll) & vibEndAll > vibStartAll;
if any(validWindow)
    globalStart = median(vibStartAll(validWindow));
    globalEnd = median(vibEndAll(validWindow));
    globalConfidence = local_omitnan_median(vibConfidenceAll(validWindow));
    if ~isfinite(globalConfidence), globalConfidence = 0; end
    params.vibrato = struct('startSec',globalStart,'endSec',globalEnd, ...
        'durationSec',max(0, globalEnd-globalStart), ...
        'numHarmonicsUsed',nnz(validWindow), ...
        'confidence',globalConfidence, ...
        'method','median_of_per_harmonic_normalized_AM_FM_activity');
else
    params.vibrato = struct('startSec',0,'endSec',sourceDur, ...
        'durationSec',sourceDur, ...
        'numHarmonicsUsed',0, ...
        'confidence',0, ...
        'method','fallback_full_note');
end

params = local_apply_global_vibrato_consensus(params, opts);
params = local_build_compact_fm_model(params, opts);
params = local_recompute_phase_offsets_for_compact_fm(params, R, t, fs, N);
params = local_finalize_compact_resynthesis_params(params, opts);
end


function params = local_build_compact_fm_model(params, opts)
%LOCAL_BUILD_COMPACT_FM_MODEL Store one shared H1-equivalent FM model.
% The measured per-harmonic FM depths are expected to scale approximately
% with harmonic number.  This function estimates a base depth in Hz from
% amp_k/k, stores one top-level params.fmModel, and removes redundant
% params.harm(k).fmModel fields from the compact playback contract.
if ~opts.paramCompactFmEnable || ~isfield(params, 'harm') || isempty(params.harm)
    params.fmModel = local_compact_global_fm_model(struct());
    return;
end

K = numel(params.harm);
baseAmp = [];
freqHz = [];
phaseRad = [];
weights = [];
sourceHarm = [];

for ii = 1:K
    hk = params.harm(ii);
    k = local_copy_field(hk, 'k', ii);
    if ~isnumeric(k) || ~isscalar(k) || ~isfinite(k) || k <= 0
        k = ii;
    end
    if ~isfield(hk, 'fmModel') || ~isstruct(hk.fmModel)
        continue;
    end
    m = hk.fmModel;
    isGood = isfield(m, 'isVibrato') && isequal(m.isVibrato, true) && ...
        isfield(m, 'freqHz') && isfinite(m.freqHz) && m.freqHz > 0 && ...
        isfield(m, 'amp') && isfinite(m.amp) && m.amp > 0 && ...
        isfield(m, 'phaseRad') && isfinite(m.phaseRad);
    if ~isGood
        continue;
    end
    if opts.paramCompactFmScaleByHarmonic
        baseAmp(end+1,1) = m.amp / k; %#ok<AGROW>
    else
        baseAmp(end+1,1) = m.amp; %#ok<AGROW>
    end
    freqHz(end+1,1) = m.freqHz; %#ok<AGROW>
    phaseRad(end+1,1) = m.phaseRad; %#ok<AGROW>
    sourceHarm(end+1,1) = k; %#ok<AGROW>
    w = 1;
    if isfield(m, 'r2') && isfinite(m.r2)
        w = max(m.r2, 0.01);
    end
    if isfield(m, 'numValid') && isfinite(m.numValid) && m.numValid > 0
        w = w * sqrt(m.numValid);
    end
    weights(end+1,1) = w; %#ok<AGROW>
end

if isempty(baseAmp)
    fmModel = local_compact_global_fm_model(struct());
else
    fmModel = struct();
    fmModel.freqHz = local_weighted_mean(freqHz, weights);
    fmModel.amp = median(baseAmp(isfinite(baseAmp) & baseAmp >= 0));
    fmModel.phaseRad = local_weighted_circular_mean(phaseRad, weights);
    fmModel.refHarmonic = max(1, round(opts.paramCompactFmRefHarmonic));
    fmModel.scaleByHarmonic = opts.paramCompactFmScaleByHarmonic;
    fmModel.numHarmonicsUsed = numel(unique(sourceHarm));
    fmModel.method = 'V30_global_H1_equivalent_FM_from_median_amp_over_harmonic_number';
    fmModel.sourceHarmonics = sourceHarm(:).';
    fmModel.baseAmpHzCandidates = baseAmp(:).';
    fmModel = local_compact_global_fm_model(fmModel);
end

params.fmModel = fmModel;

% Remove redundant per-harmonic FM models from the stored playback params.
% AM remains per-harmonic only when opts.paramStoreAmModel is true because
% its depth is not generally a simple k-scaled copy in the same way as FM.
if isfield(params.harm, 'fmModel')
    params.harm = rmfield(params.harm, 'fmModel');
end
end

function params = local_recompute_phase_offsets_for_compact_fm(params, R, t, fs, N)
%LOCAL_RECOMPUTE_PHASE_OFFSETS_FOR_COMPACT_FM Keep phase offsets consistent
% with the compact global FM model that will be used during V30 resynthesis.
if ~isfield(params, 'fmModel') || ~isstruct(params.fmModel) || ...
        ~isfield(params.fmModel, 'freqHz') || ~isfinite(params.fmModel.freqHz) || params.fmModel.freqHz <= 0 || ...
        ~isfield(params.fmModel, 'amp') || ~isfinite(params.fmModel.amp) || params.fmModel.amp <= 0 || ...
        ~isfield(params, 'harm') || isempty(params.harm) || ~isfield(R, 'harm')
    return;
end
K = min(numel(params.harm), numel(R.harm));
for ii = 1:K
    hkR = R.harm(ii);
    if ~isfield(hkR, 'zk') || numel(hkR.zk) ~= N
        continue;
    end
    k = local_copy_field(params.harm(ii), 'k', ii);
    if ~isnumeric(k) || ~isscalar(k) || ~isfinite(k) || k <= 0
        k = ii;
    end
    refIdx = [];
    if isfield(hkR, 'vibAmpMask') && numel(hkR.vibAmpMask) == N
        if isfield(hkR, 'ampNoVib') && numel(hkR.ampNoVib) == N
            refIdx = find(hkR.vibAmpMask(:) & hkR.ampNoVib(:) > 0, 1, 'first');
        else
            refIdx = find(hkR.vibAmpMask(:), 1, 'first');
        end
    end
    if isempty(refIdx) && isfield(hkR, 'ampNoVib') && numel(hkR.ampNoVib) == N
        refIdx = find(hkR.ampNoVib(:) > 0, 1, 'first');
    end
    if isempty(refIdx), refIdx = 1; end
    if ~isfinite(hkR.zk(refIdx))
        continue;
    end

    fmAmp = params.fmModel.amp;
    if isfield(params.fmModel, 'scaleByHarmonic') && params.fmModel.scaleByHarmonic
        refH = 1;
        if isfield(params.fmModel, 'refHarmonic') && isfinite(params.fmModel.refHarmonic) && params.fmModel.refHarmonic > 0
            refH = params.fmModel.refHarmonic;
        end
        fmAmp = fmAmp * (k / refH);
    end
    fmSource = fmAmp * sin(2*pi*params.fmModel.freqHz*t + params.fmModel.phaseRad);
    fkSource = k * R.f0Hz + fmSource;
    fkSource = min(max(fkSource, eps), 0.49*fs);
    phaseAccum = [0; cumsum(2*pi*fkSource(1:end-1)/fs)];
    fcHz = k * R.f0Hz;
    if isfield(hkR, 'fcHz') && isfinite(hkR.fcHz)
        fcHz = hkR.fcHz;
    end
    desiredPhase = angle(hkR.zk(refIdx)) + 2*pi*fcHz*t(refIdx);
    params.harm(ii).phaseOffsetRad = desiredPhase - phaseAccum(refIdx);
end
end

function model = local_compact_global_fm_model(modelIn)
model = struct('freqHz',0,'amp',0,'phaseRad',0,'refHarmonic',1,'scaleByHarmonic',true);
if nargin < 1 || isempty(modelIn) || ~isstruct(modelIn)
    return;
end
fields = fieldnames(model);
for ii = 1:numel(fields)
    f = fields{ii};
    if isfield(modelIn, f) && ~isempty(modelIn.(f))
        model.(f) = modelIn.(f);
    end
end
if ~isfinite(model.freqHz) || model.freqHz < 0, model.freqHz = 0; end
if ~isfinite(model.amp) || model.amp < 0, model.amp = 0; end
if ~isfinite(model.phaseRad), model.phaseRad = 0; end
if ~isfinite(model.refHarmonic) || model.refHarmonic <= 0, model.refHarmonic = 1; end
model.refHarmonic = max(1, round(model.refHarmonic));
model.scaleByHarmonic = logical(model.scaleByHarmonic);
if model.amp == 0 || model.freqHz == 0
    model.phaseRad = 0;
end
end

function y = local_weighted_mean(x, w)
x = x(:); w = w(:);
mask = isfinite(x) & isfinite(w) & w > 0;
if ~any(mask)
    y = median(x(isfinite(x)));
else
    y = sum(w(mask).*x(mask)) / sum(w(mask));
end
if isempty(y) || ~isfinite(y)
    y = 0;
end
end

function ph = local_weighted_circular_mean(phases, w)
phases = phases(:); w = w(:);
mask = isfinite(phases) & isfinite(w) & w > 0;
if ~any(mask)
    phases = phases(isfinite(phases));
    if isempty(phases)
        ph = 0;
    else
        ph = median(phases);
    end
    return;
end
sx = sum(w(mask).*cos(phases(mask)));
sy = sum(w(mask).*sin(phases(mask)));
ph = atan2(sy, sx);
if ~isfinite(ph)
    ph = 0;
end
end


function paramsOut = local_finalize_compact_resynthesis_params(paramsIn, opts)
%LOCAL_FINALIZE_COMPACT_RESYNTHESIS_PARAMS Remove analysis-only fields.
paramsOut = struct();
paramsOut.version = 'V30_resynthesis_params_compact';
paramsOut.sourceFs = local_copy_field(paramsIn, 'sourceFs', NaN);
paramsOut.sourceNumSamples = local_copy_field(paramsIn, 'sourceNumSamples', NaN);
paramsOut.f0Hz = local_copy_field(paramsIn, 'f0Hz', NaN);
paramsOut.analyticAmpScale = local_copy_field(paramsIn, 'analyticAmpScale', opts.paramAnalyticAmpScale);
paramsOut.globalEnvTiming = local_strip_global_env_timing(local_copy_field(paramsIn, 'globalEnvTiming', struct()));

sourceDur = NaN;
if isfinite(paramsOut.sourceFs) && paramsOut.sourceFs > 0 && isfinite(paramsOut.sourceNumSamples) && paramsOut.sourceNumSamples > 0
    sourceDur = paramsOut.sourceNumSamples / paramsOut.sourceFs;
end
if isfield(paramsIn, 'vibrato') && isstruct(paramsIn.vibrato) && ...
        isfield(paramsIn.vibrato, 'startSec') && isfield(paramsIn.vibrato, 'endSec')
    vibStart = paramsIn.vibrato.startSec;
    vibEnd = paramsIn.vibrato.endSec;
else
    vibStart = 0;
    vibEnd = sourceDur;
end
if ~isfinite(vibStart), vibStart = 0; end
if ~isfinite(vibEnd), vibEnd = sourceDur; end
if isfinite(sourceDur)
    vibStart = max(0, min(sourceDur, vibStart));
    vibEnd = max(0, min(sourceDur, vibEnd));
end
if vibEnd < vibStart
    tmp = vibStart; vibStart = vibEnd; vibEnd = tmp;
end
paramsOut.vibrato = struct('startSec',vibStart,'endSec',vibEnd);
paramsOut.fmModel = local_compact_global_fm_model(local_copy_field(paramsIn, 'fmModel', struct()));

K = 0;
if isfield(paramsIn, 'harm') && isstruct(paramsIn.harm)
    K = numel(paramsIn.harm);
end
if opts.paramStoreAmModel
    paramsOut.harm = repmat(struct('k',[], 'envModel',[], 'amModel',[], 'phaseOffsetRad',[]), K, 1);
else
    paramsOut.harm = repmat(struct('k',[], 'envModel',[], 'phaseOffsetRad',[]), K, 1);
end
for kk = 1:K
    hk = paramsIn.harm(kk);
    paramsOut.harm(kk).k = local_copy_field(hk, 'k', kk);
    if isfield(hk, 'envModel') && isstruct(hk.envModel)
        paramsOut.harm(kk).envModel = local_compact_env_model(hk.envModel, opts);
    else
        paramsOut.harm(kk).envModel = local_empty_env_model(opts);
    end
    if opts.paramStoreAmModel
        paramsOut.harm(kk).amModel = local_compact_fit_model(local_copy_field(hk, 'amModel', struct()));
    end
    phaseOffset = local_copy_field(hk, 'phaseOffsetRad', 0);
    if ~isnumeric(phaseOffset) || ~isscalar(phaseOffset) || ~isfinite(phaseOffset)
        phaseOffset = 0;
    end
    paramsOut.harm(kk).phaseOffsetRad = phaseOffset;
end
if ~opts.paramStoreAmModel && isfield(paramsOut.harm, 'amModel')
    paramsOut.harm = rmfield(paramsOut.harm, 'amModel');
end
end

function value = local_copy_field(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
end
end

function model = local_compact_fit_model(modelIn)
model = struct('freqHz',0,'amp',0,'phaseRad',0);
if nargin < 1 || isempty(modelIn) || ~isstruct(modelIn)
    return;
end
fields = fieldnames(model);
for ii = 1:numel(fields)
    f = fields{ii};
    if isfield(modelIn, f) && ~isempty(modelIn.(f)) && isnumeric(modelIn.(f)) && isscalar(modelIn.(f))
        model.(f) = modelIn.(f);
    end
end
if ~isfinite(model.freqHz) || model.freqHz < 0, model.freqHz = 0; end
if ~isfinite(model.amp), model.amp = 0; end
if ~isfinite(model.phaseRad), model.phaseRad = 0; end
end

function envOut = local_empty_env_model(opts)
envOut = struct();
envOut.attackShapeOrder = opts.attackShapeOrder;
envOut.baseline = 0;
envOut.segments = struct('attack',struct(), 'body',struct(), 'release',struct());
end

function envOut = local_compact_env_model(envIn, opts)
envOut = local_empty_env_model(opts);
if nargin < 1 || isempty(envIn) || ~isstruct(envIn)
    return;
end
if isfield(envIn, 'attackShapeOrder') && isnumeric(envIn.attackShapeOrder) && isscalar(envIn.attackShapeOrder) && isfinite(envIn.attackShapeOrder)
    envOut.attackShapeOrder = envIn.attackShapeOrder;
end
if isfield(envIn, 'baseline') && isnumeric(envIn.baseline) && isscalar(envIn.baseline) && isfinite(envIn.baseline)
    envOut.baseline = max(envIn.baseline, 0);
end
if isfield(envIn, 'segments') && isstruct(envIn.segments)
    if isfield(envIn.segments, 'attack')
        envOut.segments.attack = local_strip_env_segment(envIn.segments.attack);
    end
    if isfield(envIn.segments, 'body')
        envOut.segments.body = local_strip_env_segment(envIn.segments.body);
    end
    if isfield(envIn.segments, 'release')
        envOut.segments.release = local_strip_env_segment(envIn.segments.release);
    end
end
end


function out = local_strip_global_env_timing(in)
%LOCAL_STRIP_GLOBAL_ENV_TIMING Keep only time values needed by resynthesis.
out = struct();
if nargin < 1 || isempty(in) || ~isstruct(in)
    return;
end
keepFields = {'tAttackEnd','tRelease','tNoteEnd','hasRelease'};
for ii = 1:numel(keepFields)
    f = keepFields{ii};
    if isfield(in, f) && ~isempty(in.(f))
        out.(f) = in.(f);
    end
end
end

function model = local_apply_single_vibrato_gate(model, kind, bandHz, opts)
%LOCAL_APPLY_SINGLE_VIBRATO_GATE Reject transient/noisy sine fits before storage.
if nargin < 2, kind = 'AM'; end
kind = upper(string(kind));
reason = "";
pass = true;

if ~isfield(model, 'freqHz') || ~isfinite(model.freqHz) || model.freqHz <= 0
    pass = false; reason = "nonpositive_frequency";
elseif model.freqHz <= bandHz(1) + opts.paramVibLowerEdgeGuardHz
    pass = false; reason = "near_lower_band_edge";
elseif model.freqHz >= bandHz(2) - opts.paramVibUpperEdgeGuardHz
    pass = false; reason = "near_upper_band_edge";
elseif ~isfield(model, 'r2') || ~isfinite(model.r2) || model.r2 < opts.paramVibMinR2
    pass = false; reason = "low_r2";
elseif ~isfield(model, 'fitDurationSec') || ~isfinite(model.fitDurationSec) || model.fitDurationSec < opts.paramVibMinFitDurationSec
    pass = false; reason = "too_short";
elseif ~isfield(model, 'numCycles') || ~isfinite(model.numCycles) || model.numCycles < opts.paramVibMinCycles
    pass = false; reason = "too_few_cycles";
elseif ~isfield(model, 'amp') || ~isfinite(model.amp) || model.amp <= 0
    pass = false; reason = "nonpositive_depth";
end

if pass && kind == "AM"
    if model.amp < opts.paramVibMinAmDepth
        pass = false; reason = "am_depth_too_small";
    elseif model.amp > opts.paramVibMaxAmDepth
        pass = false; reason = "am_depth_too_large_transient_like";
    end
elseif pass && kind == "FM"
    if model.amp < opts.paramVibMinFmDepthHz
        pass = false; reason = "fm_depth_too_small";
    end
end

model.isVibrato = pass;
model.rejectReason = char(reason);
model.gateInfo = struct('kind',char(kind), ...
    'minR2',opts.paramVibMinR2, ...
    'minDurationSec',opts.paramVibMinFitDurationSec, ...
    'minCycles',opts.paramVibMinCycles, ...
    'lowerEdgeGuardHz',opts.paramVibLowerEdgeGuardHz, ...
    'upperEdgeGuardHz',opts.paramVibUpperEdgeGuardHz);

if ~pass
    model.amp = 0;
    model.freqHz = 0;
    model.phaseRad = 0;
    if isfield(model, 'fitFull') && ~isempty(model.fitFull)
        model.fitFull(:) = model.offset;
    end
end
end

function params = local_apply_global_vibrato_consensus(params, opts)
%LOCAL_APPLY_GLOBAL_VIBRATO_CONSENSUS Require several harmonics to share one rate.
if ~opts.paramVibRequireConsensus || ~isfield(params, 'harm') || isempty(params.harm)
    return;
end
K = numel(params.harm);
freqs = [];
harms = [];
modelKinds = strings(0,1);
for k = 1:K
    if isfield(params.harm(k), 'amModel') && isfield(params.harm(k).amModel, 'isVibrato') && params.harm(k).amModel.isVibrato
        freqs(end+1,1) = params.harm(k).amModel.freqHz; %#ok<AGROW>
        harms(end+1,1) = k; %#ok<AGROW>
        modelKinds(end+1,1) = "AM"; %#ok<AGROW>
    end
    if isfield(params.harm(k), 'fmModel') && isfield(params.harm(k).fmModel, 'isVibrato') && params.harm(k).fmModel.isVibrato
        freqs(end+1,1) = params.harm(k).fmModel.freqHz; %#ok<AGROW>
        harms(end+1,1) = k; %#ok<AGROW>
        modelKinds(end+1,1) = "FM"; %#ok<AGROW>
    end
end

if isempty(freqs)
    params.vibrato.consensus = struct('accepted',false,'reason','no_individual_models_passed', ...
        'rateHz',NaN,'numHarmonics',0,'numModels',0);
    params = local_reject_all_vibrato_models(params, 'no_individual_models_passed');
    return;
end

bestCount = 0;
bestModels = false(size(freqs));
bestRate = NaN;
tol = opts.paramVibConsensusTolHz;
for ii = 1:numel(freqs)
    near = abs(freqs - freqs(ii)) <= tol;
    nH = numel(unique(harms(near)));
    if nH > bestCount
        bestCount = nH;
        bestModels = near;
        bestRate = median(freqs(near));
    end
end

accepted = bestCount >= opts.paramVibMinConsensusHarmonics;
params.vibrato.consensus = struct('accepted',accepted, ...
    'rateHz',bestRate, ...
    'numHarmonics',bestCount, ...
    'numModels',nnz(bestModels), ...
    'toleranceHz',tol, ...
    'minHarmonics',opts.paramVibMinConsensusHarmonics, ...
    'candidateFreqHz',freqs, ...
    'candidateHarmonic',harms, ...
    'candidateKind',modelKinds);

if ~accepted
    params.vibrato.consensus.reason = 'not_enough_harmonics_at_common_rate';
    params = local_reject_all_vibrato_models(params, 'global_consensus_failed');
    if isfield(params, 'vibrato')
        params.vibrato.confidence = 0;
        params.vibrato.numHarmonicsUsed = 0;
        params.vibrato.method = 'rejected_global_consensus_failed';
    end
    return;
end

params.vibrato.consensus.reason = 'accepted';
for k = 1:K
    if isfield(params.harm(k), 'amModel') && isfield(params.harm(k).amModel, 'isVibrato') && params.harm(k).amModel.isVibrato
        if abs(params.harm(k).amModel.freqHz - bestRate) > tol
            params.harm(k).amModel = local_zero_stored_model(params.harm(k).amModel, 'outside_global_rate_cluster');
        end
    end
    if isfield(params.harm(k), 'fmModel') && isfield(params.harm(k).fmModel, 'isVibrato') && params.harm(k).fmModel.isVibrato
        if abs(params.harm(k).fmModel.freqHz - bestRate) > tol
            params.harm(k).fmModel = local_zero_stored_model(params.harm(k).fmModel, 'outside_global_rate_cluster');
        end
    end
end
end

function params = local_reject_all_vibrato_models(params, reason)
for k = 1:numel(params.harm)
    if isfield(params.harm(k), 'amModel')
        params.harm(k).amModel = local_zero_stored_model(params.harm(k).amModel, reason);
    end
    if isfield(params.harm(k), 'fmModel')
        params.harm(k).fmModel = local_zero_stored_model(params.harm(k).fmModel, reason);
    end
    if isfield(params.harm(k), 'vibrato') && isstruct(params.harm(k).vibrato)
        params.harm(k).vibrato.rejected = true;
        params.harm(k).vibrato.rejectReason = reason;
        params.harm(k).vibrato.confidence = 0;
    end
end
end

function model = local_zero_stored_model(model, reason)
if ~isfield(model, 'offset') || ~isfinite(model.offset), model.offset = 0; end
model.freqHz = 0;
model.amp = 0;
model.phaseRad = 0;
model.isVibrato = false;
model.rejectReason = reason;
end

function model = local_strip_fit_model(modelIn)
fields = {'freqHz','amp','phaseRad','offset','r2','numValid','peakFreqHz','coeff','fitDurationSec','numCycles','isVibrato','rejectReason','gateInfo'};
model = struct();
for ii = 1:numel(fields)
    f = fields{ii};
    if isfield(modelIn, f)
        model.(f) = modelIn.(f);
    end
end
end

function out = local_strip_vibrato_window(vibWindow)
fields = {'startSec','endSec','durationSec','confidence','threshold','maxScore','method','numActiveSamples','fitStartSec','fitEndSec','rejected','rejectReason'};
out = struct();
for ii = 1:numel(fields)
    f = fields{ii};
    if isfield(vibWindow, f)
        out.(f) = vibWindow.(f);
    end
end
end

function envModel = local_strip_env_model(hk, N, fs, sourceDur, opts) %#ok<INUSD>
%LOCAL_STRIP_ENV_MODEL Store only envelope parameters needed for playback.
envModel = local_empty_env_model(opts);
if ~isfield(hk, 'expEnv') || isempty(hk.expEnv) || ~isstruct(hk.expEnv)
    return;
end
src = hk.expEnv;
if isfield(src, 'baseline') && isfinite(src.baseline)
    envModel.baseline = max(src.baseline, 0);
end
if isfield(src, 'segments') && isstruct(src.segments)
    if isfield(src.segments, 'attack')
        envModel.segments.attack = local_strip_env_segment(src.segments.attack);
    end
    if isfield(src.segments, 'body')
        envModel.segments.body = local_strip_env_segment(src.segments.body);
    end
    if isfield(src.segments, 'release')
        envModel.segments.release = local_strip_env_segment(src.segments.release);
    end
end

% Robust baseline fallback from the first attack knot.
if (~isfield(envModel, 'baseline') || ~isfinite(envModel.baseline)) && ...
        isfield(envModel.segments, 'attack') && isfield(envModel.segments.attack, 'knotValues') && ...
        ~isempty(envModel.segments.attack.knotValues)
    envModel.baseline = max(envModel.segments.attack.knotValues(1), 0);
end
end

function segOut = local_strip_env_segment(segIn)
% Keep only the small set of values needed to reconstruct the envelope.
segOut = struct();
keepFields = {'tStart','tEnd','model','hasRelease','knotTimes','knotValues'};
for ii = 1:numel(keepFields)
    f = keepFields{ii};
    if isfield(segIn, f)
        segOut.(f) = segIn.(f);
    end
end
if isfield(segOut, 'knotTimes'), segOut.knotTimes = segOut.knotTimes(:); end
if isfield(segOut, 'knotValues'), segOut.knotValues = segOut.knotValues(:); end
end

function val = local_get_char_field(s, fieldName, defaultVal)
val = defaultVal;
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    val = char(s.(fieldName));
end
end

function vibWindow = local_estimate_vibrato_window(t, amTrack, fmTrack, envFit, opts, fs, globalTiming)
%LOCAL_ESTIMATE_VIBRATO_WINDOW Estimate where AM/FM modulation is reliably active.
t = t(:);
N = numel(t);
amTrack = local_match_length(amTrack(:), N);
fmTrack = local_match_length(fmTrack(:), N);
envFit = local_match_length(envFit(:), N);
if nargin < 7 || isempty(globalTiming) || ~isstruct(globalTiming)
    globalTiming = struct();
end

fitStartSec = 0;
fitEndSec = t(end);
if isfield(globalTiming, 'tAttackEnd') && isfinite(globalTiming.tAttackEnd)
    fitStartSec = globalTiming.tAttackEnd + opts.paramVibIgnoreAfterAttackSec;
end
if isfield(globalTiming, 'hasRelease') && globalTiming.hasRelease && ...
        isfield(globalTiming, 'tRelease') && isfinite(globalTiming.tRelease)
    fitEndSec = globalTiming.tRelease;
end

valid = isfinite(t) & envFit > 0 & (isfinite(amTrack) | isfinite(fmTrack)) & ...
    t >= max(0, fitStartSec) & t <= min(t(end), fitEndSec);
score = zeros(N,1);
usedParts = 0;

validAm = valid & isfinite(amTrack);
if nnz(validAm) >= 8
    amCentered = abs(amTrack - local_omitnan_median(amTrack(validAm)));
    amScale = prctile(amCentered(validAm), 95);
    if isfinite(amScale) && amScale > eps
        score = score + min(amCentered ./ amScale, 1);
        usedParts = usedParts + 1;
    end
end

validFm = valid & isfinite(fmTrack);
if nnz(validFm) >= 8
    fmCentered = abs(fmTrack - local_omitnan_median(fmTrack(validFm)));
    fmScale = prctile(fmCentered(validFm), 95);
    if isfinite(fmScale) && fmScale > eps
        score = score + min(fmCentered ./ fmScale, 1);
        usedParts = usedParts + 1;
    end
end

if usedParts > 0
    score = score ./ usedParts;
end
score(~valid) = 0;

smoothN = max(1, round((opts.paramVibWindowSmoothMs/1000) * fs));
if smoothN > 1
    scoreSmooth = movmean(score, smoothN);
else
    scoreSmooth = score;
end

maxScore = max(scoreSmooth);
thresh = opts.paramVibWindowThresholdFrac * maxScore;
active = valid & scoreSmooth >= thresh & maxScore > 0;

[startIdx, endIdx] = local_longest_true_run(active);
if isempty(startIdx)
    validIdx = find(valid);
    if isempty(validIdx)
        startIdx = 1;
        endIdx = N;
    else
        startIdx = validIdx(1);
        endIdx = validIdx(end);
    end
end

padN = max(0, round(opts.paramVibWindowPadSec * fs));
startIdx = max(1, startIdx - padN);
endIdx = min(N, endIdx + padN);

minN = max(1, round(opts.paramVibWindowMinDurationSec * fs));
if (endIdx - startIdx + 1) < minN
    centerIdx = round((startIdx + endIdx) / 2);
    halfN = floor(minN / 2);
    startIdx = max(1, centerIdx - halfN);
    endIdx = min(N, startIdx + minN - 1);
    startIdx = max(1, min(startIdx, max(1, endIdx - minN + 1)));
end

startSec = t(startIdx);
endSec = t(endIdx);
confidence = 0;
if maxScore > 0 && any(active)
    confidence = mean(scoreSmooth(active)) / maxScore;
end
if ~isfinite(confidence), confidence = 0; end

vibWindow = struct();
vibWindow.startSec = startSec;
vibWindow.endSec = endSec;
vibWindow.durationSec = max(0, endSec - startSec);
vibWindow.confidence = confidence;
vibWindow.threshold = thresh;
vibWindow.maxScore = maxScore;
vibWindow.method = 'normalized_AM_FM_activity_longest_run';
vibWindow.numActiveSamples = nnz(active);
vibWindow.fitStartSec = fitStartSec;
vibWindow.fitEndSec = fitEndSec;
vibWindow.rejected = false;
vibWindow.rejectReason = '';
vibWindow.activeMask = active;
vibWindow.score = scoreSmooth;
end

function [startIdx, endIdx] = local_longest_true_run(mask)
mask = mask(:) ~= 0;
if ~any(mask)
    startIdx = [];
    endIdx = [];
    return;
end
d = diff([false; mask; false]);
starts = find(d == 1);
ends = find(d == -1) - 1;
[~, imax] = max(ends - starts + 1);
startIdx = starts(imax);
endIdx = ends(imax);
end

function y = local_optional_track(s, fieldName, N)
y = nan(N,1);
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    y = local_match_length(s.(fieldName)(:), N);
end
end

function model = local_fit_single_sine(t, y, bandHz, fs)
t = t(:);
y = y(:);
if numel(y) ~= numel(t)
    y = local_match_length(y, numel(t));
end
valid = isfinite(t) & isfinite(y);
minN = max(32, round(0.05*fs));
if nnz(valid) < minN || std(y(valid)) <= eps
    offset = local_omitnan_median(y(valid));
    if ~isfinite(offset), offset = 0; end
    model = local_empty_sine_model(offset, numel(t));
    return;
end

% Fill gaps only inside the valid fit span for spectral peak detection.
% Do not extrapolate the fitted window over the full note because that can
% make a short transient look like a low-frequency periodic component.
validIdx = find(valid);
spanIdx = validIdx(1):validIdx(end);
spanValid = valid(spanIdx);
yFill = local_fill_missing_linear(t(spanIdx), y(spanIdx), spanValid);
yDet = yFill - local_omitnan_median(y(valid));
winN = min(numel(yDet), max(256, round(2.0*fs)));
if mod(winN,2)==1, winN = winN-1; end
if winN < 16
    model = local_empty_sine_model(local_omitnan_median(y(valid)), numel(t));
    return;
end
ovN = round(0.5*winN);
nfft = max(2048, 2^nextpow2(winN));
[Pyy, fP] = pwelch(yDet - mean(yDet), hann(winN,'periodic'), ovN, nfft, fs);
bandMask = fP >= bandHz(1) & fP <= bandHz(2);
if ~any(bandMask) || all(Pyy(bandMask) <= 0)
    model = local_empty_sine_model(local_omitnan_median(y(valid)), numel(t));
    return;
end
[~, iPk] = max(Pyy(bandMask));
fBand = fP(bandMask);
f0 = fBand(iPk);

lo = max(bandHz(1), f0 - 0.75);
hi = min(bandHz(2), f0 + 0.75);
if hi > lo
    fitOpts = optimset('Display','off');
    try
        fHat = fminbnd(@(ff)local_sine_fit_sse(t(valid), y(valid), ff), lo, hi, fitOpts);
    catch
        fHat = f0;
    end
else
    fHat = f0;
end

[~, coeff, yHatValid] = local_sine_design_fit(t(valid), y(valid), fHat);
offset = coeff(1);
bSin = coeff(2);
bCos = coeff(3);
amp = hypot(bSin, bCos);
phase = atan2(bCos, bSin);
yHatFull = offset + amp * sin(2*pi*fHat*t + phase);
res = y(valid) - yHatValid;
ssRes = sum(res.^2);
ssTot = sum((y(valid) - mean(y(valid))).^2);
r2 = 1 - ssRes / max(ssTot, eps);

fitDurationSec = max(t(valid)) - min(t(valid));
if ~isfinite(fitDurationSec), fitDurationSec = 0; end
numCycles = fHat * fitDurationSec;
model = struct('freqHz',fHat,'amp',amp,'phaseRad',phase,'offset',offset, ...
    'fitFull',yHatFull,'r2',r2,'validMask',valid,'numValid',nnz(valid), ...
    'peakFreqHz',f0,'coeff',coeff(:),'fitDurationSec',fitDurationSec, ...
    'numCycles',numCycles,'isVibrato',false,'rejectReason','ungated');
end

function model = local_empty_sine_model(offset, N)
if nargin < 1 || ~isfinite(offset), offset = 0; end
model = struct('freqHz',0,'amp',0,'phaseRad',0,'offset',offset, ...
    'fitFull',offset*ones(N,1),'r2',NaN,'validMask',false(N,1), ...
    'numValid',0,'peakFreqHz',NaN,'coeff',[offset;0;0], ...
    'fitDurationSec',0,'numCycles',0,'isVibrato',false,'rejectReason','empty_or_invalid');
end

function sse = local_sine_fit_sse(t, y, freqHz)
[~, ~, yHat] = local_sine_design_fit(t, y, freqHz);
r = y(:) - yHat(:);
sse = sum(r.^2);
end

function [X, coeff, yHat] = local_sine_design_fit(t, y, freqHz)
t = t(:); y = y(:);
X = [ones(size(t)), sin(2*pi*freqHz*t), cos(2*pi*freqHz*t)];
coeff = X \ y;
yHat = X * coeff;
end

function yFill = local_fill_missing_linear(t, y, valid)
yFill = y(:);
if all(valid)
    return;
end
if nnz(valid) >= 2
    yFill(~valid) = interp1(t(valid), y(valid), t(~valid), 'linear', 'extrap');
elseif nnz(valid) == 1
    idx = find(valid, 1);
    yFill(~valid) = y(idx);
else
    yFill(:) = 0;
end
end

function yFill = local_fill_missing_linear_hold(t, y, valid)
t = t(:);
yFill = y(:);
valid = valid(:) & isfinite(t) & isfinite(yFill);

if isempty(yFill) || all(valid)
    return;
end

if nnz(valid) >= 2
    invalid = ~valid;
    yFill(invalid) = interp1(t(valid), yFill(valid), t(invalid), 'linear');

    firstValid = find(valid, 1, 'first');
    lastValid  = find(valid, 1, 'last');
    if firstValid > 1
        yFill(1:firstValid-1) = yFill(firstValid);
    end
    if lastValid < numel(yFill)
        yFill(lastValid+1:end) = yFill(lastValid);
    end
elseif nnz(valid) == 1
    idx = find(valid, 1);
    yFill(:) = yFill(idx);
else
    finiteMask = isfinite(yFill);
    if nnz(finiteMask) >= 2
        yFill = local_fill_missing_linear_hold(t, yFill, finiteMask);
    elseif nnz(finiteMask) == 1
        idx = find(finiteMask, 1);
        yFill(:) = yFill(idx);
    else
        yFill(:) = 0;
    end
end
end

function y = local_match_length(y, N)
y = y(:);
if numel(y) == N
    return;
elseif isempty(y)
    y = nan(N,1);
elseif numel(y) > N
    y = y(1:N);
else
    y(end+1:N,1) = nan;
end
end

function m = local_omitnan_median(x)
x = x(isfinite(x));
if isempty(x)
    m = NaN;
else
    m = median(x);
end
end

function yFill = local_fill_missing_median(y, valid)
yFill = y(:);
valid = valid(:) & isfinite(yFill);

if isempty(yFill)
    return;
end

if any(valid)
    medVal = median(yFill(valid));
else
    finiteMask = isfinite(yFill);
    if any(finiteMask)
        medVal = median(yFill(finiteMask));
    else
        medVal = 0;
    end
end

yFill(~valid | ~isfinite(yFill)) = medVal;
end

function [yHat, model] = local_fit_continuous_decay(tau, y, y0, M, useNL, hasOptim)
tau = tau(:);
y   = max(y(:), 0);
Dur = max(tau(end) - tau(1), eps);

rates0 = logspace(log10(1/max(Dur,eps)), log10(40/max(Dur,eps)), M).';
tailN = max(3, round(0.1 * numel(y)));
floorHint = median(y(max(1,end-tailN+1):end));
floorHint = min(max(floorHint, 0), 0.98 * y0);

E = exp(-tau * rates0.');
% very fast fallback: try only two floor candidates
floorCand = unique([0; floorHint]);
bestSSE = inf;
bestFloor = 0;
bestW = ones(M,1) / M;
for c = floorCand(:).'
    target = max(y - c, 0);
    a = lsqnonneg(E, target);
    if sum(a) <= 0
        w = ones(M,1) / M;
    else
        w = a / sum(a);
    end
    yh = c + (y0 - c) * (E * w);
    sse = sum((y - yh).^2);
    if sse < bestSSE
        bestSSE = sse;
        bestFloor = c;
        bestW = w;
    end
end
floorVal = bestFloor;
weights = bestW;
rates = rates0;
yHat = floorVal + (y0 - floorVal) * (E * weights);

if useNL && hasOptim && numel(y) >= max(6, M + 2)
    modelFun = @(p,t) local_continuous_decay_eval(p, t, y0, M);
    wlog0 = log(max(weights, eps));
    wlog0 = wlog0 - mean(wlog0);
    p0 = [floorVal; wlog0; log(rates)];
    lb = [0; -20 * ones(M,1); log(1e-3) * ones(M,1)];
    ub = [0.999 * y0; 20 * ones(M,1); log(1e3) * ones(M,1)];
    lsqOpts = optimoptions('lsqcurvefit','Display','off', ...
        'MaxIterations',200,'FunctionTolerance',1e-8,'StepTolerance',1e-8);
    try
        pf = lsqcurvefit(modelFun, p0, tau, y, lb, ub, lsqOpts);
        floorVal = pf(1);
        weights = local_softmax(pf(2:M+1));
        rates = exp(pf(M+2:end));
        yHat = modelFun(pf, tau);
    catch ME
        warning('vib_analyze:contDecayFitFailed', ...
            'Continuous decay lsqcurvefit failed (%s). Using fixed-rate fallback.', ME.message);
    end
end

yHat = max(yHat(:), 0);
model = struct('offset',floorVal,'weights',weights(:),'rates',rates(:), ...
    'numTerms',M,'y0',y0,'tau',tau(:));
end

function y = local_continuous_decay_eval(params, tau, y0, M)
floorVal = params(1);
weights = local_softmax(params(2:M+1));
rates = exp(params(M+2:end));
E = exp(-tau(:) * rates(:).');
y = floorVal + (y0 - floorVal) * (E * weights(:));
end

function w = local_softmax(u)
u = u(:);
u = u - max(u);
eu = exp(u);
s = sum(eu);
if ~isfinite(s) || s <= 0
    w = ones(size(u)) / numel(u);
else
    w = eu / s;
end
end

function zk = local_complex_demod_analytic(x, fc, bwHalf, fs)
t  = (0:length(x)-1).' / fs;
zk = local_lowpass_zero_phase(x .* exp(-1j*2*pi*fc*t), min(max(bwHalf,5),0.45*fs), fs);
end

function y = local_lowpass_zero_phase(x, fcHz, fs)
fcHz = max(fcHz, 0.1);
if fcHz >= 0.49*fs
    y = x;
    return;
end
[b,a] = butter(4, fcHz/(fs/2));
y = filtfilt(b, a, x);
end

function [x_env, fs, info] = local_make_test_waveform(opts)
fs = opts.testFs;
T  = opts.testDurSec;
N  = max(1, round(T*fs));
t  = (0:N-1).' / fs;
K  = opts.testNumHarmonics;
if isempty(opts.testHarmAmps)
    Ak = (1./(1:K)).';
else
    Ak = opts.testHarmAmps(:);
    if numel(Ak) < K
        Ak(end+1:K,1) = 0;
    elseif numel(Ak) > K
        Ak = Ak(1:K);
    end
end
ampVib = 1 + opts.testAmpVibDepth*sin(2*pi*opts.testAmpVibRateHz*t) + linspace(0,opts.ampDrift,N)';
cents  = opts.testFmVibDepthCents*sin(2*pi*opts.testFmVibRateHz*t) + linspace(0,opts.freqDrift,N)';
f0_t   = opts.testF0Hz .* (2.^(cents/1200));
x = zeros(N,1);
for k = 1:K
    phi = cumsum(2*pi*(k.*f0_t)/fs);
    x = x + Ak(k)*cos(phi);
end
x = ampVib .* x;
if opts.poly_env
    x_env = poly_asr_env(t, T, 0.5, 2, 5) .* x;
else
    fadeN = min(round((opts.testFadeMs/1000)*fs), floor(N/2));
    w = ones(N,1);
    if fadeN > 0
        w(1:fadeN) = linspace(0,1,fadeN).';
        w(end-fadeN+1:end) = linspace(1,0,fadeN).';
    end
    x_env = x .* w;
end
if opts.testNoiseStd > 0
    x_env = x_env + opts.testNoiseStd * randn(size(x_env));
end
mx = max(abs(x_env));
if mx > 0
    x_env = 0.8 * x_env / mx;
    Ak = Ak * 0.8 / mx;
end
info = struct('x_no_env',x,'fs',fs,'N',N,'f0Hz_nominal',opts.testF0Hz, ...
    'numHarmonics',K,'harmAmps',Ak,'ampVibRateHz',opts.testAmpVibRateHz, ...
    'ampVibDepth',opts.testAmpVibDepth,'fmVibRateHz',opts.testFmVibRateHz, ...
    'fmVibDepthCents',opts.testFmVibDepthCents);
end

function local_plot_spectrogram_with_filterbank(x, fs, f0Hz, opts)
winN = max(32, round(opts.specWinMs/1000*fs));
hopN = max(1, round(opts.specHopMs/1000*fs));
[S,F,T] = spectrogram(x, hann(winN,'periodic'), max(0,winN-hopN), max(256,round(opts.specNfft)), fs, 'yaxis');
Sdb = 20*log10(abs(S)+1e-12);
mx = max(Sdb(:));
Sdb = max(Sdb, mx - opts.specDynRangeDb);
figure('Name','Spectrogram + harmonic filterbank');
imagesc(T,F,Sdb); axis xy; xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('Spectrogram with bandpass filter-bank boundaries'); colorbar; hold on;
K = opts.numHarmonics;
bw = opts.bandwidthF0Frac * f0Hz;
for k = 1:K
    fc = k * f0Hz;
    fcLP = min(max(bw,5),0.45*fs);
    plot(T,(fc-fcLP)*ones(size(T)),'w--','LineWidth',1);
    plot(T,(fc+fcLP)*ones(size(T)),'w--','LineWidth',1);
    if opts.specOverlayCenters
        plot(T,fc*ones(size(T)),'w-','LineWidth',0.75);
    end
    text(T(1)+0.01*(T(end)-T(1)), fc, sprintf('H%d',k), 'Color','w', 'FontSize',9, 'VerticalAlignment','bottom');
end
ylim([0, min(fs/2, (K+1)*f0Hz+bw)]);
hold off;
end

function env = poly_asr_env(t, T, atk, rel, order)
if nargin < 5, order = 5; end
atk = max(atk,0);
rel = max(rel,0);
if atk + rel > T
    s = T / (atk + rel + eps);
    atk = atk * s;
    rel = rel * s;
end
env = ones(size(t));
if atk > 0
    xa = min(max(t/atk,0),1);
    env(t<=atk) = smoothstep_poly(xa(t<=atk), order);
end
if rel > 0
    tr0 = T - rel;
    xr = min(max((t-tr0)/rel,0),1);
    env(t>=tr0) = 1 - smoothstep_poly(xr(t>=tr0), order);
end
end

function y = smoothstep_poly(x, order)
switch order
    case 3
        y = x.^2 .* (3 - 2*x);
    case 5
        y = x.^3 .* (10 + x.*(-15 + 6*x));
    otherwise
        error('order must be 3 or 5');
end
end

function [f0Hz, info] = local_estimate_f0_majority_vote(x, fs)
%LOCAL_ESTIMATE_F0_MAJORITY_VOTE Robust fundamental estimate for solo notes.
%
% Combines:
%   1) MATLAB pitch() SRH
%   2) MATLAB pitch() NCF
%   3) MATLAB pitch() PEF
%   4) MATLAB pitch() CEP
%   5) autocorrelation
%   6) cepstrum fallback
%   7) harmonic-summation spectrum estimate
%
% The final answer is a weighted majority vote in pitch/cents space, followed
% by an octave correction check using harmonic spectral evidence.

rangeHz = [20 5000];          % lower than old [50 1200] for tuba/bass/double bass
clusterTolCents = 70;         % candidates within about 0.7 semitones vote together
octaveImproveRatio = 1.12;    % require spectral improvement before octave correction
octaveImproveLog = log(octaveImproveRatio);

x = x(:);
x = x(isfinite(x));
if isempty(x)
    error('Pitch estimation failed: empty or non-finite input audio.');
end

[xSeg, segInfo] = local_select_pitch_segment_v27(x, fs);

cands = struct('method', {}, 'fHz', {}, 'weight', {}, 'details', {});

% Longer windows help low-pitched instruments. At 40 Hz, 120 ms contains
% nearly 5 cycles, which is much better than a short speech-style window.
desiredWinN = max([round(0.120 * fs), round(3 * fs / rangeHz(1)), round(0.046 * fs)]);
winN = min(numel(xSeg), desiredWinN);
if mod(winN, 2) == 1 && winN < numel(xSeg)
    winN = winN + 1;
end
hopN = max(1, round(0.010 * fs));
ovN = max(0, winN - hopN);

% ---- Audio Toolbox pitch() methods ----
if exist('pitch', 'file') == 2
    pitchMethods = {'SRH', 'NCF', 'PEF', 'CEP'};

    for ii = 1:numel(pitchMethods)
        methodName = pitchMethods{ii};
        try
            fTrack = pitch(xSeg, fs, ...
                'Method', methodName, ...
                'Range', rangeHz, ...
                'WindowLength', winN, ...
                'OverlapLength', ovN);

            [fCand, wCand, detail] = local_track_to_pitch_candidate_v27(fTrack, rangeHz);
            cands = local_add_f0_candidate_v27(cands, methodName, fCand, wCand, detail);
        catch ME
            detail = struct('error', ME.message);
            cands = local_add_f0_candidate_v27(cands, [methodName '_failed'], NaN, 0, detail);
        end
    end
end

% ---- Time-domain autocorrelation candidate ----
try
    [fAuto, wAuto, autoDetail] = local_autocorr_f0_candidate_v27(xSeg, fs, rangeHz);
    cands = local_add_f0_candidate_v27(cands, 'AUTOCORR', fAuto, wAuto, autoDetail);
catch ME
    cands = local_add_f0_candidate_v27(cands, 'AUTOCORR_failed', NaN, 0, struct('error', ME.message));
end

% ---- Cepstrum fallback candidate ----
try
    [fCep, wCep, cepDetail] = local_cepstrum_f0_candidate_v27(xSeg, fs, rangeHz);
    cands = local_add_f0_candidate_v27(cands, 'CEPSTRUM_LOCAL', fCep, wCep, cepDetail);
catch ME
    cands = local_add_f0_candidate_v27(cands, 'CEPSTRUM_LOCAL_failed', NaN, 0, struct('error', ME.message));
end

% ---- Harmonic-spectrum candidate ----
try
    [fHarm, wHarm, harmDetail] = local_harmonic_spectrum_f0_candidate_v27(xSeg, fs, rangeHz);
    cands = local_add_f0_candidate_v27(cands, 'HARMONIC_SUM', fHarm, wHarm, harmDetail);
catch ME
    cands = local_add_f0_candidate_v27(cands, 'HARMONIC_SUM_failed', NaN, 0, struct('error', ME.message));
end

valid = arrayfun(@(c) isfinite(c.fHz) && c.fHz >= rangeHz(1) && c.fHz <= rangeHz(2) && c.weight > 0, cands);
if ~any(valid)
    error('Pitch estimation failed: no pitch method produced a valid f0.');
end
validCands = cands(valid);

% ---- Majority vote by cents-space clustering ----
clusters = local_cluster_pitch_candidates_v27(validCands, clusterTolCents);
clusterScores = [clusters.score];
[~, iBest] = max(clusterScores);
winner = clusters(iBest);

f0Vote = winner.centerHz;

% ---- Octave correction using harmonic spectral support ----
octFactors = [0.5 1 2];
octScores = -inf(size(octFactors));

for ii = 1:numel(octFactors)
    fTest = f0Vote * octFactors(ii);
    if fTest >= rangeHz(1) && fTest <= rangeHz(2)
        octScores(ii) = local_harmonic_spectrum_score_v27(xSeg, fs, fTest);
    end
end

[bestOctScore, iOct] = max(octScores);
baseScore = octScores(octFactors == 1);

% Scores are log-power based, so compare by difference, not ratio.
if isfinite(bestOctScore) && isfinite(baseScore) && ...
        octFactors(iOct) ~= 1 && (bestOctScore - baseScore) > octaveImproveLog
    f0Hz = f0Vote * octFactors(iOct);
    octaveCorrected = true;
else
    f0Hz = f0Vote;
    octaveCorrected = false;
end

info = struct();
info.method = 'majority_vote_pitch';
info.f0Hz = f0Hz;
info.rangeHz = rangeHz;
info.segment = segInfo;
info.candidates = cands;
info.validCandidates = validCands;
info.clusters = clusters;
info.winningCluster = winner;
info.f0BeforeOctaveCheck = f0Vote;
info.octaveFactors = octFactors;
info.octaveScores = octScores;
info.octaveCorrected = octaveCorrected;
end

function [xSeg, info] = local_select_pitch_segment_v27(x, fs)
% Select a stable, high-energy portion of the note and avoid the attack.
x = x(:);
x = x - local_mean_finite_v27(x);

if exist('hilbert', 'file') == 2
    env = abs(hilbert(x));
else
    env = abs(x);
end

smoothN = max(1, round(0.020 * fs));
env = movmean(env, smoothN);

peakEnv = max(env);
if ~isfinite(peakEnv) || peakEnv <= 0
    xSeg = x;
    info = struct('idxStart', 1, 'idxEnd', numel(x), 'reason', 'empty_envelope');
    return;
end

active = env >= 0.08 * peakEnv;
[iStart, iEnd] = local_longest_true_region_v27(active);

if isempty(iStart)
    iStart = 1;
    iEnd = numel(x);
end

nActive = iEnd - iStart + 1;

% Skip attack, but do not remove too much of a short note.
attackSkip = min(round(0.150 * fs), floor(0.25 * nActive));
tailSkip   = min(round(0.050 * fs), floor(0.10 * nActive));

segStart = iStart + attackSkip;
segEnd   = iEnd - tailSkip;

minSegN = max(round(0.250 * fs), 512);
if segEnd - segStart + 1 < minSegN
    segStart = iStart;
    segEnd = iEnd;
end

segStart = max(1, min(numel(x), segStart));
segEnd = max(segStart, min(numel(x), segEnd));

xSeg = x(segStart:segEnd);

% Limit extremely long notes for speed, keeping the middle stable region.
maxSegN = round(4.0 * fs);
if numel(xSeg) > maxSegN
    mid = round(numel(xSeg) / 2);
    halfN = floor(maxSegN / 2);
    lo = max(1, mid - halfN);
    hi = min(numel(xSeg), lo + maxSegN - 1);
    xSeg = xSeg(lo:hi);
    segStart = segStart + lo - 1;
    segEnd = segStart + numel(xSeg) - 1;
end

xSeg = xSeg - local_mean_finite_v27(xSeg);

info = struct();
info.idxStart = segStart;
info.idxEnd = segEnd;
info.tStart = (segStart - 1) / fs;
info.tEnd = (segEnd - 1) / fs;
info.durationSec = numel(xSeg) / fs;
info.reason = 'longest_active_region_attack_skipped';
end

function [fCand, weight, detail] = local_track_to_pitch_candidate_v27(fTrack, rangeHz)
fTrack = fTrack(:);
valid = isfinite(fTrack) & fTrack >= rangeHz(1) & fTrack <= rangeHz(2);
f = fTrack(valid);

if numel(f) < 3
    fCand = NaN;
    weight = 0;
    detail = struct('numValid', numel(f), 'reason', 'too_few_valid_frames');
    return;
end

midi = 69 + 12 * log2(f / 440);
medMidi = median(midi);
dev = abs(midi - medMidi);
robustSigma = 1.4826 * median(dev);

% Allow vibrato, but reject octave jumps and gross frame errors.
keep = dev <= max(0.75, 3 * robustSigma);
if nnz(keep) < 3
    keep = true(size(f));
end

midiKeep = midi(keep);
fCand = 440 * 2.^((median(midiKeep) - 69) / 12);

spreadCents = 100 * std(midiKeep);
coverage = nnz(valid) / max(1, numel(fTrack));
stability = 60 / (60 + max(0, spreadCents));

weight = coverage * stability;
weight = max(0.05, min(1.0, weight));

detail = struct();
detail.numFrames = numel(fTrack);
detail.numValid = nnz(valid);
detail.numKept = nnz(keep);
detail.coverage = coverage;
detail.spreadCents = spreadCents;
detail.weight = weight;
end

function [f0, weight, detail] = local_autocorr_f0_candidate_v27(x, fs, rangeHz)
x = x(:);
x = x - local_mean_finite_v27(x);

if max(abs(x)) > 0
    x = x / max(abs(x));
end

maxLag = min(numel(x) - 2, floor(fs / rangeHz(1)));
minLag = max(2, ceil(fs / rangeHz(2)));

if maxLag <= minLag
    f0 = NaN;
    weight = 0;
    detail = struct('reason', 'invalid_lag_range');
    return;
end

rFull = xcorr(x, maxLag, 'coeff');
r = rFull(maxLag + 1:end);
lags = (0:maxLag).'; %#ok<NASGU>

searchIdx = minLag:maxLag;
rs = r(searchIdx);

isPeak = false(size(rs));
if numel(rs) >= 3
    isPeak(2:end-1) = rs(2:end-1) > rs(1:end-2) & rs(2:end-1) >= rs(3:end);
end

if any(isPeak)
    peakIdxs = searchIdx(isPeak);
    [peakVal, imax] = max(r(peakIdxs));
    lag = peakIdxs(imax);
else
    [peakVal, rel] = max(rs);
    lag = searchIdx(rel);
end

% Parabolic lag refinement.
lagFine = lag;
if lag > 1 && lag < numel(r)
    y1 = r(lag - 1);
    y2 = r(lag);
    y3 = r(lag + 1);
    denom = y1 - 2*y2 + y3;
    if abs(denom) > eps
        delta = 0.5 * (y1 - y3) / denom;
        if abs(delta) <= 1
            lagFine = lag + delta;
        end
    end
end

f0 = fs / lagFine;
weight = max(0.05, min(0.90, peakVal));

detail = struct();
detail.lag = lag;
detail.lagFine = lagFine;
detail.peakValue = peakVal;
detail.weight = weight;
end

function [f0, weight, detail] = local_cepstrum_f0_candidate_v27(x, fs, rangeHz)
x = x(:);
x = x - local_mean_finite_v27(x);

N = numel(x);
if N < 128
    f0 = NaN;
    weight = 0;
    detail = struct('reason', 'too_short');
    return;
end

w = local_hann_window_v27(N);
nfft = 2^nextpow2(max(N, round(0.5 * fs)));
X = fft(x .* w, nfft);
logMag = log(abs(X) + eps);
cep = real(ifft(logMag));

q = (0:nfft-1).' / fs;
qMin = 1 / rangeHz(2);
qMax = 1 / rangeHz(1);

idx = find(q >= qMin & q <= qMax);
if isempty(idx)
    f0 = NaN;
    weight = 0;
    detail = struct('reason', 'empty_quefrency_range');
    return;
end

[peakVal, rel] = max(cep(idx));
iPk = idx(rel);
f0 = 1 / q(iPk);

noiseFloor = median(abs(cep(idx))) + eps;
prom = peakVal / noiseFloor;
weight = max(0.05, min(0.80, prom / 10));

detail = struct();
detail.quefrencySec = q(iPk);
detail.peakValue = peakVal;
detail.prominence = prom;
detail.weight = weight;
end

function [f0, weight, detail] = local_harmonic_spectrum_f0_candidate_v27(x, fs, rangeHz)
[fAxis, logP] = local_log_power_spectrum_v27(x, fs);

gridStepHz = 0.25;
grid = rangeHz(1):gridStepHz:min(rangeHz(2), 0.45 * fs);
scores = zeros(size(grid));

for ii = 1:numel(grid)
    scores(ii) = local_harmonic_spectrum_score_from_logp_v27(fAxis, logP, grid(ii));
end

[bestScore, iBest] = max(scores);
fCoarse = grid(iBest);

% Fine search around the best coarse value.
fineStepHz = max(0.02, fCoarse / 2000);
fineGrid = max(rangeHz(1), fCoarse - 2):fineStepHz:min(rangeHz(2), fCoarse + 2);
fineScores = zeros(size(fineGrid));

for ii = 1:numel(fineGrid)
    fineScores(ii) = local_harmonic_spectrum_score_from_logp_v27(fAxis, logP, fineGrid(ii));
end

[bestFineScore, iFine] = max(fineScores);
f0 = fineGrid(iFine);

scoreMed = median(scores);
scoreMad = 1.4826 * median(abs(scores - scoreMed)) + eps;
z = (bestScore - scoreMed) / scoreMad;

weight = max(0.10, min(1.10, z / 8));

detail = struct();
detail.fCoarse = fCoarse;
detail.bestScore = bestFineScore;
detail.scoreMedian = scoreMed;
detail.scoreRobustZ = z;
detail.weight = weight;
end

function score = local_harmonic_spectrum_score_v27(x, fs, f0)
[fAxis, logP] = local_log_power_spectrum_v27(x, fs);
score = local_harmonic_spectrum_score_from_logp_v27(fAxis, logP, f0);
end

function score = local_harmonic_spectrum_score_from_logp_v27(fAxis, logP, f0)
if ~isfinite(f0) || f0 <= 0
    score = -inf;
    return;
end

nyq = fAxis(end);
maxH = min(35, floor(nyq / f0));

if maxH < 2
    score = -inf;
    return;
end

k = (1:maxH).';
freqs = k * f0;

% Lower harmonics matter more, but do not depend only on harmonic 1 because
% low instruments often have weak fundamentals.
weights = 1 ./ sqrt(k);

vals = interp1(fAxis, logP, freqs, 'linear', min(logP));
score = sum(weights .* vals) / sum(weights);
end

function [fAxis, logP] = local_log_power_spectrum_v27(x, fs)
x = x(:);
x = x - local_mean_finite_v27(x);

maxN = round(4.0 * fs);
if numel(x) > maxN
    mid = round(numel(x) / 2);
    halfN = floor(maxN / 2);
    lo = max(1, mid - halfN);
    hi = min(numel(x), lo + maxN - 1);
    x = x(lo:hi);
end

N = numel(x);
w = local_hann_window_v27(N);

nfft = 2^nextpow2(max(N, round(4.0 * fs)));
nfft = min(nfft, 2^20);

X = fft(x .* w, nfft);
half = 1:(floor(nfft / 2) + 1);

P = abs(X(half)).^2;
P = P / max(P + eps);
logP = log(P + eps);

% A tiny smoothing helps avoid selecting one noisy FFT bin.
if numel(logP) >= 5
    logP = movmean(logP, 3);
end

fAxis = (half(:) - 1) * fs / nfft;
end

function cands = local_add_f0_candidate_v27(cands, methodName, fHz, weight, details)
if nargin < 5
    details = struct();
end

if isempty(weight) || ~isfinite(weight)
    weight = 0;
end

c = struct();
c.method = methodName;
c.fHz = fHz;
c.weight = weight;
c.details = details;

if isempty(cands)
    cands = c;
else
    cands(end + 1) = c;
end
end

function clusters = local_cluster_pitch_candidates_v27(cands, tolCents)
clusters = struct('idx', {}, 'centerHz', {}, 'score', {}, 'count', {}, 'spreadCents', {});

for ii = 1:numel(cands)
    f = cands(ii).fHz;
    w = cands(ii).weight;

    if ~isfinite(f) || f <= 0 || ~isfinite(w) || w <= 0
        continue;
    end

    assigned = false;

    for jj = 1:numel(clusters)
        cents = 1200 * log2(f / clusters(jj).centerHz);
        if abs(cents) <= tolCents
            clusters(jj).idx(end + 1) = ii;
            clusters(jj) = local_update_pitch_cluster_v27(clusters(jj), cands);
            assigned = true;
            break;
        end
    end

    if ~assigned
        newCluster = struct();
        newCluster.idx = ii;
        newCluster.centerHz = f;
        newCluster.score = w;
        newCluster.count = 1;
        newCluster.spreadCents = 0;

        if isempty(clusters)
            clusters = newCluster;
        else
            clusters(end + 1) = newCluster;
        end
    end
end
end

function cluster = local_update_pitch_cluster_v27(cluster, cands)
idx = cluster.idx(:);
f = [cands(idx).fHz].';
w = [cands(idx).weight].';

w(~isfinite(w) | w <= 0) = eps;
logF = log(f);

cluster.centerHz = exp(sum(w .* logF) / sum(w));
cluster.score = sum(w);
cluster.count = numel(idx);
cluster.spreadCents = local_weighted_spread_cents_v27(f, w, cluster.centerHz);
end

function s = local_weighted_spread_cents_v27(f, w, centerHz)
c = 1200 * log2(f(:) / centerHz);
w = w(:);
w = w / sum(w);
mu = sum(w .* c);
s = sqrt(sum(w .* (c - mu).^2));
end

function [iStart, iEnd] = local_longest_true_region_v27(mask)
mask = mask(:) ~= 0;

if ~any(mask)
    iStart = [];
    iEnd = [];
    return;
end

d = diff([false; mask; false]);
starts = find(d == 1);
ends = find(d == -1) - 1;

[~, imax] = max(ends - starts + 1);
iStart = starts(imax);
iEnd = ends(imax);
end

function w = local_hann_window_v27(N)
N = max(1, round(N));
if N == 1
    w = 1;
    return;
end

n = (0:N-1).';
w = 0.5 - 0.5 * cos(2 * pi * n / (N - 1));
end

function m = local_mean_finite_v27(x)
x = x(:);
x = x(isfinite(x));

if isempty(x)
    m = 0;
else
    m = mean(x);
end
end
