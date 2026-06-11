%% plot_trombone_envelope_fit_targets_V27.m
% Shows the actual envelope, low-pass no-vibrato envelope,
% the attack/body fitting target, the release fitting target,
% final PCHIP envelope fit, and stored knots.

clear; close all; clc;

%% ---------------- User settings ----------------

tromboneSample = "C:\Users\Andre\OneDrive\Documents\MATLAB\trombone_Gs4_1_forte_normal.mp3";

harmonicToPlot = 1;
normalizeForSlide = true;
saveFigure = true;

analysisOpts = struct();
analysisOpts.numHarmonics = 15;
analysisOpts.plot_waveform = false;
analysisOpts.plot_vib = false;
analysisOpts.plot_vib_overviews = false;
analysisOpts.plot_harm_amps = false;
analysisOpts.plot_expEnv = false;

S = additive_synth_analysis_V27(tromboneSample);

%% ---------------- Extract harmonic ----------------

k = harmonicToPlot;
h = S.harm(k);

t = S.t(:);
fs = S.fs;

ampEnv = h.ampEnv(:);         % actual harmonic amplitude envelope
ampNoVib = h.ampNoVib(:);     % low-pass / no-vibrato envelope
envFit = h.expEnv.envFit(:);  % final segmented PCHIP fit

opts = S.analysisOpts;
opts = local_fill_missing_opts(opts);

%% ---------------- Rebuild the actual fitting targets ----------------

targets = local_rebuild_envelope_fit_targets(S, k, opts);

tFit = targets.tFit;
yFit = targets.yFit;                         % low-pass target on fit grid
yAttackOnFit = targets.yAttackOnFit;         % attack raw-smoothed target on fit grid
yFitHybrid = targets.yFitHybrid;             % actual attack/body target
targetAttackBody = targets.targetAttackBody; % visible attack/body section
targetRelease = targets.targetRelease;       % visible release section

knotT = targets.knotT;
knotY = targets.knotY;

%% ---------------- Normalize for clean plotting ----------------

if normalizeForSlide
    scaleVal = max([ ...
        ampEnv(:); ...
        ampNoVib(:); ...
        envFit(:); ...
        yFit(:); ...
        yAttackOnFit(:); ...
        yFitHybrid(:); ...
        targetAttackBody(:); ...
        targetRelease(:); ...
        knotY(:)], [], "omitnan");

    if isfinite(scaleVal) && scaleVal > 0
        ampEnv = ampEnv / scaleVal;
        ampNoVib = ampNoVib / scaleVal;
        envFit = envFit / scaleVal;
        yFit = yFit / scaleVal;
        yAttackOnFit = yAttackOnFit / scaleVal;
        yFitHybrid = yFitHybrid / scaleVal;
        targetAttackBody = targetAttackBody / scaleVal;
        targetRelease = targetRelease / scaleVal;
        knotY = knotY / scaleVal;
    end
end

%% ---------------- Plot ----------------

figure("Color", "w", "Position", [100 100 1250 600]);
hold on;

plot(t, ampEnv, ...
    "Color", [0.70 0.70 0.70], ...
    "LineWidth", 1.0, ...
    "DisplayName", "Actual harmonic amplitude envelope");

plot(t, ampNoVib, ...
    "Color", [0.10 0.35 0.85], ...
    "LineWidth", 1.5, ...
    "DisplayName", "Low-pass no-vibrato envelope");

plot(tFit, yAttackOnFit, ...
    "Color", [0.75 0.15 0.75], ...
    "LineWidth", 1.2, ...
    "LineStyle", ":", ...
    "DisplayName", "Raw-smoothed attack target");

plot(tFit, targetAttackBody, ...
    "Color", [0.00 0.55 0.20], ...
    "LineWidth", 2.3, ...
    "DisplayName", "Actual fit target: attack/body");

plot(tFit, targetRelease, ...
    "Color", [0.00 0.55 0.75], ...
    "LineWidth", 2.3, ...
    "LineStyle", "--", ...
    "DisplayName", "Actual fit target: release");

plot(t, envFit, ...
    "Color", [0.95 0.60 0.00], ...
    "LineWidth", 3.0, ...
    "DisplayName", "Final PCHIP envelope fit");

plot(knotT, knotY, ...
    "ko", ...
    "MarkerFaceColor", "w", ...
    "MarkerSize", 7, ...
    "LineWidth", 1.5, ...
    "DisplayName", "Stored envelope knots");

% Segment boundaries, hidden from legend so they do not show up as data1/data2.
xline(targets.tAttackEnd, ":", "Attack end", ...
    "LabelOrientation", "horizontal", ...
    "LabelVerticalAlignment", "bottom", ...
    "HandleVisibility", "off");

xline(targets.tReleaseStart, ":", "Release start", ...
    "LabelOrientation", "horizontal", ...
    "LabelVerticalAlignment", "bottom", ...
    "HandleVisibility", "off");

grid on;
box on;

xlabel("Time (s)");

if normalizeForSlide
    ylabel("Normalized amplitude");
else
    ylabel("Amplitude");
end

title(sprintf("Trombone G#4: Harmonic %d Envelope Fit Targets", k));
legend("Location", "best");

xlim([min(t), max(t)]);

if normalizeForSlide
    ylim([0, 1.08]);
end

%% ---------------- Save ----------------

if saveFigure
    outFile = sprintf("trombone_Gs4_H%d_envelope_fit_targets.png", k);
    exportgraphics(gcf, outFile, "Resolution", 300);
    fprintf("Saved figure to %s\n", outFile);
end

%% ========================================================================
% Local helper functions
% ========================================================================

function targets = local_rebuild_envelope_fit_targets(S, k, opts)

    h = S.harm(k);

    t = S.t(:);
    fs = S.fs;
    L = numel(t);

    ampEnv = h.ampEnv(:);
    ampNoVib = h.ampNoVib(:);

    trimN = max(1, round((opts.trimMs/1000)*fs));
    idxTrim = (1+trimN):(L-trimN);

    if numel(idxTrim) < round(0.1*L)
        trimN = round(0.02*fs);
        idxTrim = (1+trimN):(L-trimN);
    end

    tTrim = t(idxTrim);
    yFitFull = max(ampNoVib(idxTrim), 0);

    % This recreates ampAttackFit from the analysis code.
    % It is NOT the same as ampNoVib. It is a faster low-pass version
    % of the actual harmonic amplitude envelope.
    if opts.attackUseRawEnvelope
        ampAttackFit = local_lowpass_zero_phase(max(ampEnv, 0), opts.attackRawLpHz, fs);
    else
        ampAttackFit = ampNoVib;
    end

    yAttackFull = max(ampAttackFit(idxTrim), 0);

    % Downsample to the same fit grid used by the analysis.
    [tFit, yFit] = local_prepare_env_fit_grid(tTrim, yFitFull, opts.envFitFs);
    yFit = max(yFit(:), 0);

    yAttackOnFit = interp1(tTrim, yAttackFull(:), tFit, "pchip", "extrap");
    yAttackOnFit(~isfinite(yAttackOnFit)) = 0;
    yAttackOnFit = max(yAttackOnFit(:), 0);

    % Use the saved global timing from the analysis.
    gt = S.globalEnvTiming;

    iOnset = local_time_to_index(gt.tOnset, tFit);
    iAttackEnd = local_time_to_index(gt.tAttackEnd, tFit);
    iReleaseStart = local_time_to_index(gt.tRelease, tFit);
    iNoteEnd = local_time_to_index(gt.tNoteEnd, tFit);

    N = numel(tFit);

    iOnset = max(1, min(N-2, iOnset));
    iAttackEnd = max(iOnset + 1, min(N-1, iAttackEnd));
    iNoteEnd = max(iAttackEnd + 1, min(N, iNoteEnd));

    if isfield(gt, "hasRelease") && gt.hasRelease
        iReleaseStart = max(iAttackEnd + 1, min(iNoteEnd, iReleaseStart));
    else
        iReleaseStart = iNoteEnd;
    end

    % Rebuild yFitHybrid exactly like the envelope fitting logic:
    % raw-smoothed attack target first, then fade back to low-pass ampNoVib.
    yFitHybrid = yFit;

    if opts.attackUseRawEnvelope
        hybridEndTime = tFit(iOnset) + max(opts.attackHybridMs, 0)/1000;
        hybridEndIdx = min(iNoteEnd, max(iAttackEnd, local_time_to_index(hybridEndTime, tFit)));
        hybridFadeStartIdx = iAttackEnd;

        rawWeight = zeros(N, 1);
        rawWeight(iOnset:hybridFadeStartIdx) = 1;

        if hybridEndIdx > hybridFadeStartIdx
            fadeX = linspace(1, 0, hybridEndIdx - hybridFadeStartIdx + 1).';
            rawWeight(hybridFadeStartIdx:hybridEndIdx) = ...
                max(rawWeight(hybridFadeStartIdx:hybridEndIdx), fadeX);
        end

        yFitHybrid = rawWeight .* yAttackOnFit + (1 - rawWeight) .* yFit;
        yFitHybrid(~isfinite(yFitHybrid)) = 0;
        yFitHybrid = max(yFitHybrid(:), 0);
    end

    % These are the actual targets used by each fitting section.
    % Attack and body use yFitHybrid.
    % Release uses yFit.
    targetAttackBody = nan(size(tFit));
    targetAttackBody(iOnset:iReleaseStart) = yFitHybrid(iOnset:iReleaseStart);

    targetRelease = nan(size(tFit));
    targetRelease(iReleaseStart:iNoteEnd) = yFit(iReleaseStart:iNoteEnd);

    % Collect stored knots from all three segments.
    seg = h.expEnv.segments;
    knotT = [];
    knotY = [];

    segNames = ["attack", "body", "release"];

    for ii = 1:numel(segNames)
        name = segNames(ii);

        if isfield(seg, name) && ...
           isfield(seg.(name), "knotTimes") && ...
           isfield(seg.(name), "knotValues")

            knotT = [knotT; seg.(name).knotTimes(:)]; %#ok<AGROW>
            knotY = [knotY; seg.(name).knotValues(:)]; %#ok<AGROW>
        end
    end

    validKnots = isfinite(knotT) & isfinite(knotY);
    knotT = knotT(validKnots);
    knotY = knotY(validKnots);

    [knotT, order] = sort(knotT);
    knotY = knotY(order);

    targets = struct();
    targets.tFit = tFit;
    targets.yFit = yFit;
    targets.yAttackOnFit = yAttackOnFit;
    targets.yFitHybrid = yFitHybrid;
    targets.targetAttackBody = targetAttackBody;
    targets.targetRelease = targetRelease;
    targets.knotT = knotT;
    targets.knotY = knotY;
    targets.tOnset = tFit(iOnset);
    targets.tAttackEnd = tFit(iAttackEnd);
    targets.tReleaseStart = tFit(iReleaseStart);
    targets.tNoteEnd = tFit(iNoteEnd);
end

function opts = local_fill_missing_opts(opts)

    if ~isfield(opts, "trimMs"), opts.trimMs = 30; end
    if ~isfield(opts, "envFitFs"), opts.envFitFs = 2000; end

    if ~isfield(opts, "attackUseRawEnvelope"), opts.attackUseRawEnvelope = true; end
    if ~isfield(opts, "attackRawLpHz"), opts.attackRawLpHz = 350; end
    if ~isfield(opts, "attackHybridMs"), opts.attackHybridMs = 180; end

end

function y = local_lowpass_zero_phase(x, fcHz, fs)

    x = x(:);

    if isempty(fcHz) || ~isfinite(fcHz) || fcHz <= 0
        y = x;
        return;
    end

    if fcHz >= 0.49*fs
        y = x;
        return;
    end

    [b, a] = butter(4, fcHz/(fs/2));
    y = filtfilt(b, a, x);
    y = max(y, 0);

end

function [tOut, yOut, mapIdx] = local_prepare_env_fit_grid(tIn, yIn, fitFs)

    tIn = tIn(:);
    yIn = yIn(:);

    if numel(tIn) <= 4
        tOut = tIn;
        yOut = yIn;
        mapIdx = (1:numel(tIn)).';
        return;
    end

    dtIn = median(diff(tIn));

    if ~isfinite(dtIn) || dtIn <= 0
        tOut = tIn;
        yOut = yIn;
        mapIdx = (1:numel(tIn)).';
        return;
    end

    fsIn = 1 / dtIn;

    if isempty(fitFs) || ~isfinite(fitFs) || fitFs >= 0.95*fsIn
        tOut = tIn;
        yOut = yIn;
        mapIdx = (1:numel(tIn)).';
        return;
    end

    step = max(1, round(fsIn / fitFs));
    mapIdx = unique([1:step:numel(tIn), numel(tIn)]).';

    tOut = tIn(mapIdx);
    yOut = yIn(mapIdx);

end

function idx = local_time_to_index(t0, tVec)

    [~, idx] = min(abs(tVec(:) - t0));
    idx = max(1, min(numel(tVec), idx));

end