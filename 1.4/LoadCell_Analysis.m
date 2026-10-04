%% Load cell: three-round analysis (MATLAB + Simulink)
% Put the MAT files beside this script, or in ../data, then press Run.
% Weight_kg is deliberately excluded. No voltage scaling is applied here.
clear; clc; close all;
%% EDIT ONLY THIS SECTION
files = {'LoadCell round1.mat','LoadCell round 2.mat','LoadCell round 3.mat'};
% Actual reference masses from the supplied handwritten measurement sheet, in kg.
% The same set of loads is used for all three rounds.
% Order: 0kg, 1kg, 2kg, 3kg, 4kg, 5kg, 6kg, 7kg, 8kg, 9kg, 10kg.
% Do not add bag masses together unless bags were actually stacked.
referenceMass = [0 1.02 1.91 2.93 3.84 4.86 5.81 6.83 7.86 8.89 9.92];
% If actual loads differ between rounds, use a 3-by-11 matrix instead.
analysisWindow = [2 10];          % Seconds within each recording
RG = 68.2;                      % Actual gain-setting resistance, ohm
%% END OF INPUT SECTION
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
dataDir = scriptDir;
if ~all(cellfun(@(name)isfile(fullfile(dataDir,name)),files))
    dataDir = fullfile(scriptDir,'LoadCell');
end
assert(all(cellfun(@(name)isfile(fullfile(dataDir,name)),files)), ...
    'Put the three MAT files beside this script, or in the LoadCell folder.');
if strcmp(dataDir,scriptDir)
    outputDir = fullfile(scriptDir,'LoadCell_results');
else
    outputDir = fullfile(scriptDir,'results');
end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
labels = 0:10; nRound = 3; nLoad = 11;
if isvector(referenceMass) && numel(referenceMass)==nLoad
    referenceMass = repmat(reshape(referenceMass,1,[]),nRound,1);
end
assert(isequal(size(referenceMass),[nRound nLoad]), ...
    'referenceMass must contain 11 values or be a 3-by-11 matrix.');
assert(all(referenceMass(isfinite(referenceMass))>=0),'Mass must be nonnegative.');
assert(all(referenceMass(:,1)==0),'The 0kg recording must have reference mass 0.');
assert(analysisWindow(2)>analysisWindow(1),'Invalid analysis window.');
G = 4 + 60000/RG;
fprintf('RG = %.2f ohm; theoretical amplifier gain = %.4f\n',RG,G);
meanMA = nan(nRound,nLoad); sdMA = meanMA; meanRaw = meanMA;
sdRaw = meanMA; sdLPF = meanMA; lowRailPercent = meanMA;
driftMA = meanMA; sampleCount = meanMA;
recordings = cell(nRound,nLoad);
for r = 1:nRound
    S = load(fullfile(dataDir,files{r}));
    assert(isfield(S,'data'),'File %s has no variable named data.',files{r});
    D = S.data;
    assert(isa(D,'Simulink.SimulationData.Dataset'),'data must be a Dataset.');
    for j = 1:nLoad
        rec = getRecording(D,sprintf('%dkg',labels(j)));
        [t,v] = getSeries(rec,'A0_MA');
        keep = t>=analysisWindow(1) & t<=analysisWindow(2) & isfinite(v);
        assert(nnz(keep)>=2,'Insufficient samples: round %d, %dkg.',r,labels(j));
        tt=t(keep); vv=v(keep);
        meanMA(r,j)=mean(vv); sdMA(r,j)=std(vv); sampleCount(r,j)=numel(vv);
        drift=polyfit(tt-tt(1),vv,1); driftMA(r,j)=drift(1);
        recordings{r,j}=struct('t',t,'MA',v);
        [tr,vr]=getSeries(rec,'');
        kr=tr>=analysisWindow(1) & tr<=analysisWindow(2) & isfinite(vr);
        meanRaw(r,j)=mean(vr(kr)); sdRaw(r,j)=std(vr(kr));
        lowRailPercent(r,j)=100*mean(vr(kr)==0);
        [tl,vl]=getSeries(rec,'A0_LPF');
        kl=tl>=analysisWindow(1) & tl<=analysisWindow(2) & isfinite(vl);
        sdLPF(r,j)=std(vl(kl));
        recordings{r,j}.rawTime=tr; recordings{r,j}.raw=vr;
        recordings{r,j}.LPFTime=tl; recordings{r,j}.LPF=vl;
    end
end
[rr,ll]=ndgrid(1:nRound,labels);
Summary=table(rr(:),ll(:),referenceMass(:),meanMA(:),sdMA(:), ...
    meanRaw(:),sdRaw(:),sdLPF(:),driftMA(:),lowRailPercent(:),sampleCount(:), ...
    'VariableNames',{'Round','RecordingLabel_kg','ReferenceMass_kg', ...
    'MeanMA_V','SD_MA_V','MeanRaw_V','SD_Raw_V','SD_LPF_V', ...
    'DriftMA_V_per_s','RawZeroSamples_percent','SampleCount'});
writetable(Summary,fullfile(outputDir,'Voltage_summary.csv'));
VoltageTable=table(labels',meanMA(1,:)',meanMA(2,:)',meanMA(3,:)', ...
    'VariableNames',{'RecordingLabel_kg','Round1_V','Round2_V','Round3_V'});
disp(VoltageTable);
% 1. All three rounds, before regression. SD reflects within-record variation.
f=figure('Color','w','Position',[80 80 1000 580]); hold on;
styles={'-o','-s','-^'};
for r=1:nRound
    errorbar(labels,meanMA(r,:),sdMA(r,:),styles{r},'LineWidth',1.3, ...
        'DisplayName',sprintf('Round %d',r));
end
grid on; xticks(labels); xlabel('Load label (kg)');
ylabel('Mean conditioned load cell output (V)');
title('Load cell output across three rounds'); legend('Location','northwest');
saveFigure(f,outputDir,'01_Three_rounds');
% 2. Complete time traces: 11 loads, each with all three rounds.
f=figure('Color','w','Position',[60 40 1200 900]); tiledlayout(4,3,'TileSpacing','compact');
for j=1:nLoad
    nexttile; hold on;
    for r=1:nRound
        q=recordings{r,j}; plot(q.t,q.MA,'DisplayName',sprintf('Round %d',r));
    end
    xline(analysisWindow(1),'k:','HandleVisibility','off');
    xline(analysisWindow(2),'k:','HandleVisibility','off');
    grid on; title(sprintf('Load label: %d kg',labels(j)));
    xlabel('Time (s)'); ylabel('Output (V)');
    if j==1, legend('Location','best'); end
end
sgtitle('Conditioned load cell signal: complete recordings');
saveFigure(f,outputDir,'02_Time_traces');
% 3. Scatter between repeated round means. This is not an accuracy metric.
rangeV=max(meanMA,[],1)-min(meanMA,[],1);
Repeatability=table(labels',mean(meanMA,1)',std(meanMA,0,1)',rangeV', ...
    'VariableNames',{'RecordingLabel_kg','MeanAcrossRounds_V', ...
    'SD_of_round_means_V','Range_of_round_means_V'});
writetable(Repeatability,fullfile(outputDir,'Repeatability.csv'));
f=figure('Color','w'); bar(labels,1000*rangeV); grid on; xticks(labels);
xlabel('Load label (kg)'); ylabel('Range between round means (mV)');
title('Variation across three rounds'); saveFigure(f,outputDir,'03_Repeatability');
% 4. Filter comparison. SD includes noise and any drift/motion in the window.
f=figure('Color','w','Position',[70 70 1100 450]); tiledlayout(1,3);
for r=1:nRound
    nexttile; plot(labels,1000*[sdRaw(r,:);sdMA(r,:);sdLPF(r,:)]','-o');
    grid on; xlabel('Load label (kg)'); ylabel('Within-window SD (mV)');
    title(sprintf('Round %d',r)); legend('Before filtering','Moving average','Low-pass','Location','best');
end
saveFigure(f,outputDir,'04_Filter_comparison');
save(fullfile(outputDir,'Analysis_results.mat'),'Summary','Repeatability', ...
    'VoltageTable','meanMA','sdMA','referenceMass','analysisWindow','RG','G');
if any(~isfinite(referenceMass(:)))
    fprintf('\nVoltage plots and tables are complete.\n');
    fprintf('Fill all referenceMass values, then rerun for calibration and errors.\n');
    fprintf('Results folder: %s\n',outputDir);
    return;
end
assert(all(arrayfun(@(r)numel(unique(referenceMass(r,:)))>=2,1:nRound)), ...
    'Each round needs at least two distinct reference masses.');
% 5. Per-round voltage-on-mass regression, without forcing zero intercept.
coeff=zeros(nRound,2); R2=zeros(nRound,1);
f=figure('Color','w','Position',[70 70 1200 420]); tiledlayout(1,3);
for r=1:nRound
    x=referenceMass(r,:); y=meanMA(r,:); coeff(r,:)=polyfit(x,y,1);
    R2(r)=rSquared(y,polyval(coeff(r,:),x));
    nexttile; scatter(x,y,40,'filled'); hold on;
    xx=linspace(min(x),max(x),200); plot(xx,polyval(coeff(r,:),xx),'LineWidth',1.4);
    grid on; xlabel('Reference mass (kg)'); ylabel('Mean output (V)');
    title(sprintf('Round %d',r));
    text(.04,.94,sprintf('V = %.6f m %+.6f\nR^2 = %.6f', ...
        coeff(r,1),coeff(r,2),R2(r)),'Units','normalized','VerticalAlignment','top');
end
saveFigure(f,outputDir,'05_Regression_by_round');
pooled=polyfit(referenceMass(:),meanMA(:),1); a=pooled(1); b=pooled(2);
assert(a>0,'The fitted sensitivity must be positive for this wiring/data.');
pooledR2=rSquared(meanMA(:),polyval(pooled,referenceMass(:)));
Calibration=table((1:3)',coeff(:,1),coeff(:,2),R2, ...
    'VariableNames',{'Round','Sensitivity_V_per_kg','Intercept_V','R2'});
Calibration=[Calibration;table(0,a,b,pooledR2,'VariableNames',Calibration.Properties.VariableNames)];
writetable(Calibration,fullfile(outputDir,'Calibration_coefficients.csv'));
fprintf('\nPooled calibration: V = %.9f*m %+.9f; R2 = %.6f\n',a,b,pooledR2);
fprintf('Mass (kg) = (V - (%.9f))/%.9f\n',b,a);
fprintf('Simulink: Bias = %.9f; Gain = %.9f; optional N conversion = 9.81\n',-b,1/a);
% 6. Same-data residuals. They are not independent validation errors.
estimatedMass=(meanMA-b)/a;
signedError=estimatedMass-referenceMass;
percentError=nan(size(signedError)); nz=referenceMass>0;
percentError(nz)=100*abs(signedError(nz))./referenceMass(nz);
ErrorTable=table(rr(:),ll(:),referenceMass(:),estimatedMass(:), ...
    signedError(:),abs(signedError(:)),percentError(:), ...
    'VariableNames',{'Round','RecordingLabel_kg','ReferenceMass_kg', ...
    'EstimatedMass_kg','SignedResidual_kg','AbsoluteResidual_kg','AbsoluteResidual_percent'});
writetable(ErrorTable,fullfile(outputDir,'Calibration_residuals.csv'));
f=figure('Color','w','Position',[70 70 1050 450]); tiledlayout(1,2);
nexttile; hold on;
for r=1:nRound, scatter(referenceMass(r,:),estimatedMass(r,:),40,'filled','DisplayName',sprintf('Round %d',r)); end
lim=[min(referenceMass(:)) max(referenceMass(:))]; plot(lim,lim,'k--','DisplayName','Ideal');
grid on; xlabel('Reference mass (kg)'); ylabel('Estimated mass (kg)');
title('Same-data calibration check'); legend('Location','best');
nexttile; hold on;
for r=1:nRound, plot(referenceMass(r,:),1000*signedError(r,:),styles{r},'DisplayName',sprintf('Round %d',r)); end
yline(0,'k:','HandleVisibility','off'); grid on;
xlabel('Reference mass (kg)'); ylabel('Signed calibration residual (g)');
title('Residuals across the full range'); legend('Location','best');
saveFigure(f,outputDir,'06_Calibration_residuals');
% 7. Leave-one-round-out check: fit two rounds, evaluate the third.
% Checks transfer between rounds at these loads, not unseen-load accuracy.
cvMass=nan(nRound,nLoad);
for r=1:nRound
    train=setdiff(1:nRound,r); xx=referenceMass(train,:); yy=meanMA(train,:);
    c=polyfit(xx(:),yy(:),1); cvMass(r,:)=(meanMA(r,:)-c(2))/c(1);
end
cvError=cvMass-referenceMass;
CrossRound=table(rr(:),ll(:),referenceMass(:),cvMass(:),cvError(:), ...
    'VariableNames',{'HeldOutRound','RecordingLabel_kg','ReferenceMass_kg', ...
    'EstimatedMass_kg','SignedError_kg'});
writetable(CrossRound,fullfile(outputDir,'Cross_round_check.csv'));
Metrics=table(sqrt(mean(signedError(:).^2)),max(abs(signedError(:))), ...
    sqrt(mean(cvError(:).^2)),max(abs(cvError(:))), ...
    'VariableNames',{'SameData_RMSE_kg','SameData_MaxAbsolute_kg', ...
    'CrossRound_RMSE_kg','CrossRound_MaxAbsolute_kg'});
disp(Calibration); disp(Metrics);
writetable(Metrics,fullfile(outputDir,'Error_metrics.csv'));
save(fullfile(outputDir,'Analysis_results.mat'),'Calibration','ErrorTable', ...
    'CrossRound','Metrics','a','b','estimatedMass','-append');
fprintf('\nDo not hide the low-load residuals by clipping the predicted mass.\n');
fprintf('Zero-valued raw samples are a diagnostic, not proof of amplifier saturation.\n');
fprintf('Hysteresis needs separately identified increasing/decreasing load recordings.\n');
fprintf('Results folder: %s\n',outputDir);
%% Local helpers
function rec=getRecording(D,name)
    % Recordings can be nested Datasets, or Signals containing Datasets.
    rec=[];
    names=D.getElementNames;
    for k=1:D.numElements
        el=D.getElement(k);
        matches=strcmp(char(names{k}),name);
        if isprop(el,'Name')
            matches=matches || strcmp(char(el.Name),name);
        end
        if ~matches, continue; end
        if isa(el,'Simulink.SimulationData.Dataset')
            rec=el;
        elseif isa(el,'Simulink.SimulationData.Signal')
            rec=el.Values;
        end
        break;
    end
    assert(isa(rec,'Simulink.SimulationData.Dataset'), ...
        'Recording "%s" not found as a Dataset. Available names: %s', ...
        name,strjoin(names,', '));
end
function [t,v]=getSeries(rec,name)
    found=false;
    names=rec.getElementNames;
    for k=1:rec.numElements
        el=rec.getElement(k);
        matches=strcmp(char(names{k}),name);
        if isprop(el,'Name')
            matches=matches || strcmp(char(el.Name),name);
        end
        if ~matches, continue; end
        if isa(el,'Simulink.SimulationData.Signal')
            ts=el.Values;
        else
            ts=el;
        end
        assert(isa(ts,'timeseries'), ...
            'Signal "%s" must contain a timeseries; found %s.',name,class(ts));
        t=double(ts.Time(:)); v=double(ts.Data(:));
        found=true;
        break;
    end
    assert(found,'Signal "%s" not found. Available names: %s', ...
        name,strjoin(names,', '));
    assert(numel(t)==numel(v),'Expected a scalar time series.');
end
function R2=rSquared(y,pred)
    y=y(:); pred=pred(:); den=sum((y-mean(y)).^2);
    if den==0, R2=NaN; else, R2=1-sum((y-pred).^2)/den; end
end
function saveFigure(f,folder,name)
    exportgraphics(f,fullfile(folder,[name '.png']),'Resolution',300);
    savefig(f,fullfile(folder,[name '.fig']));
end
