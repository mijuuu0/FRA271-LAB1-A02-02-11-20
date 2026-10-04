%% LAB 1.3 - Encoder analysis (MATLAB R2020b or newer)
% Unzip the supplied archive, run this script, and select the Encoder folder.
% Inputs: nested Simulink.SimulationData.Dataset variables in .mat files.
% A1 = raw channel A; A2 = raw channel B; normalized amplitude = raw/4095.
% Source files are never modified. Four combined report figures are created.
% Results: Tables/, Figures/, Processed/ under Encoder_Report_Results.
% Requires MATLAB R2020b+ and Simulink to load Dataset objects.
% Run next to the original ZIP, X(4).mat and X(7).mat, or change rootFolder.
clear; clc; close all;

%% USER SETTINGS
scriptFolder = fileparts(mfilename('fullpath'));
rootFolder = fullfile(scriptFolder,'raw data'); % Folder containing the Encoder ZIP/folder and X(4), X(7).
if isfolder(fullfile(rootFolder,'upload')), rootFolder=fullfile(rootFolder,'upload'); end
bournsPPR = 24;
amtPPR = 2048;             % PPR used in the provided data/plots; index raw file is not included.
indexFileName = "X(4).mat";
wrapFileName = "X(7).mat";
indexValidationIntervals = [1 2 3]; % Selected BEFORE summary; all intervals exported.
bournsReferenceAngleDeg = 360; % Archive BOURNS trials: one marked full turn.
amtReferenceAngleDeg = NaN;    % Manual AMT stopping angle is not exact.
referenceAngleDeg = NaN;       % Legacy optional fallback for unknown encoders.
startupCutoff = 0.1;       % Ignore recording-start artifacts, seconds.
threshold = 0.5;           % Applied to raw/4095; no filtering of waveforms.
velocityWindow = 0.1;      % Position-difference window, seconds.
zoomDuration = 0.2;        % Phase-detail plot duration, seconds.
saveFigures = true;
figureVisible = 'on';      % Four combined figure windows.
representativeIDs = zeros(2,4); % 0 = automatically prefer repeat 1.
phaseZoomStart = NaN(2,4); % Optional original start times for A/B windows.

% Optional per-recording time selections, in original recording seconds.
% The printed RecordID identifies each recording. Leave empty for all data
% after startupCutoff. Example: analysisWindows = [3 1.0 8.0; 7 2.0 10.0];
% Columns: RecordID, start time, end time. End may be Inf.
analysisWindows = zeros(0,3);

% Optional counter wrap correction. Set each entry to Counter Period + 1
% ONLY after checking the real timer setup. Order: X1, X2, X4.
% NaN disables wrap correction. Initialization/reset is NOT counter wrap.
counterModulusBOURNS = [NaN NaN NaN];
counterModulusAMT = [65536 65536 65536]; % Counter Period = 65535.
% Verify these values against the timer configuration if using another board.

assert(bournsPPR>0 && isfinite(bournsPPR),'Invalid BOURNS PPR.');
assert(isnan(amtPPR) || (isfinite(amtPPR) && amtPPR>0),'Invalid AMT PPR.');
assert(velocityWindow>0 && zoomDuration>0,'Time windows must be positive.');
if ~isfolder(rootFolder)
    selected = uigetdir(pwd,'Select the extracted Encoder folder');
    if isequal(selected,0), return; end
    rootFolder = selected;
end
outFolder = fullfile(scriptFolder,'results','Raw_Analysis');
if ~isfolder(outFolder), mkdir(outFolder); end
tableFolder=fullfile(outFolder,'Tables'); figureFolder=fullfile(outFolder,'Figures');
processedFolder=fullfile(outFolder,'Processed');
for folder={tableFolder,figureFolder,processedFolder}
    if ~isfolder(folder{1}), mkdir(folder{1}); end
end
archiveFolder=rootFolder;
if isfolder(fullfile(rootFolder,'Encoder'))
    archiveFolder=fullfile(rootFolder,'Encoder');
else
    zips=dir(fullfile(rootFolder,'*Encoder*.zip'));
    if ~isempty(zips)
        archiveFolder=fullfile(outFolder,'Input_Extracted');
        if ~isfolder(archiveFolder)
            mkdir(archiveFolder);
            unzip(fullfile(zips(1).folder,zips(1).name),archiveFolder);
        end
    end
end
files=dir(fullfile(archiveFolder,'**','*.mat'));
for special=[indexFileName wrapFileName "Homing.mat"]
    f=dir(fullfile(rootFolder,special));
    if ~isempty(f) && ~any(string({files.name})==special), files=[files;f(:)]; end %#ok<AGROW>
end
assert(~isempty(files),'No MAT files found. Select the folder containing Encoder data.');
if isnan(amtPPR)
    warning(['AMT PPR is unknown: AMT counts and A/B will be analyzed, ' ...
        'but AMT angle/velocity will remain NaN until amtPPR is entered.']);
end

%% LOAD EVERY RECORDING
records = struct('ID',{},'Encoder',{},'Condition',{},'Direction',{}, ...
    'Label',{},'SourceFile',{},'Role',{},'Dataset',{});
for fi = 1:numel(files)
    source = fullfile(files(fi).folder,files(fi).name);
    if contains(source,[filesep 'Encoder_Results' filesep]) || ...
            contains(source,[filesep 'Encoder_Report_Results' filesep]), continue; end
    try
        loaded = load(source);
    catch err
        warning('Cannot load %s: %s',source,err.message); continue
    end
    vars = fieldnames(loaded);
    for vi = 1:numel(vars)
        [sets,labels] = findRecordings(loaded.(vars{vi}),string(vars{vi}));
        for ri = 1:numel(sets)
            recordText = lower(string(source)+" "+labels(ri));
            role="Motion";
            if string(files(fi).name)==indexFileName, role="IndexPPR";
            elseif string(files(fi).name)==wrapFileName, role="Wrap";
            elseif string(files(fi).name)=="Homing.mat", role="Homing"; end
            encoder = "Unknown";
            if role=="IndexPPR" || role=="Wrap", encoder="AMT103-V"; end
            if contains(recordText,'bourns'), encoder="BOURNS";
            elseif contains(recordText,'amt103'), encoder="AMT103-V"; end
            condition = "Unspecified";
            if contains(recordText,'no speed'), condition="No Speed";
            elseif contains(recordText,'slow'), condition="Slow";
            elseif contains(recordText,'fast') || contains(recordText,'speed cw') || ...
                    contains(recordText,'speed ccw'), condition="Fast"; end
            direction = "Unspecified";
            if ~isempty(regexp(char(lower(labels(ri))),'(^|[^a-z])ccw([^a-z]|$)','once'))
                direction="CCW";
            elseif ~isempty(regexp(char(lower(labels(ri))),'(^|[^a-z])cw([^a-z]|$)','once'))
                direction="CW";
            end
            id = numel(records)+1;
            records(id) = struct('ID',id,'Encoder',encoder, ...
                'Condition',condition,'Direction',direction,'Label',labels(ri), ...
                'SourceFile',string(source),'Role',role,'Dataset',sets{ri});
        end
    end
end
assert(~isempty(records),'No recordings containing A1 and A2 were found.');

% Save a complete inventory, including source path and analysis role.
Manifest=struct2table(rmfield(records,'Dataset'));
writetable(Manifest,fullfile(tableFolder,'00_Record_Manifest.csv'));

%% ANALYZE
countRows = cell(0,19);
signalRows = cell(0,18);
processed = cell(numel(records),1);
modeNames = {'EncoderX1','EncoderX2','EncoderX4'};
multipliers = [1 2 4];
modeColors = lines(3);

for r = 1:numel(records)
    meta = records(r);
    ds = meta.Dataset;
    ppr = NaN; modulus = [NaN NaN NaN]; reference=referenceAngleDeg;
    if meta.Encoder=="BOURNS"
        ppr=bournsPPR; modulus=counterModulusBOURNS; reference=bournsReferenceAngleDeg;
    elseif meta.Encoder=="AMT103-V"
        ppr=amtPPR; modulus=counterModulusAMT; reference=amtReferenceAngleDeg;
    end
    fprintf('\nRecordID %d | %s | %s | %s | %s\n', ...
        r,meta.Encoder,meta.Condition,meta.Direction,meta.Label);

    startTime=startupCutoff; endTime=Inf;
    row=find(analysisWindows(:,1)==r,1);
    if ~isempty(row)
        startTime=max(startupCutoff,analysisWindows(row,2));
        endTime=analysisWindows(row,3);
    end
    [ta,rawA] = getSignal(ds,'A1');
    [tb,rawB] = getSignal(ds,'A2');
    use=ta>=max(startTime,tb(1)) & ta<=min(endTime,tb(end));
    t=ta(use); A=rawA(use)/4095;
    assert(numel(t)>=2,'Record %d has too few selected samples.',r);
    if isequal(ta,tb), B=rawB(use)/4095;
    else
        B=interp1(tb,rawB/4095,t,'previous');
        warning('Record %d: B aligned to A using previous-sample values.',r);
    end
    a=A>=threshold; b=B>=threshold;
    da=diff(double(a)); db=diff(double(b));
    aRise=sum(da==1); aFall=sum(da==-1);
    bRise=sum(db==1); bFall=sum(db==-1);
    state=2*double(a)+double(b);
    lut=[0 -1 1 0; 1 0 0 -1; -1 0 0 1; 0 1 -1 0];
    steps=lut(sub2ind([4 4],state(1:end-1)+1,state(2:end)+1));
    changed=diff(state)~=0;
    aLeading=sum(steps==1); bLeading=sum(steps==-1);
    skipped=sum(changed & steps==0);
    sequence="No dominant sequence";
    if aLeading>bLeading, sequence="Mostly A leads B";
    elseif bLeading>aLeading, sequence="Mostly B leads A"; end
    signalRows(end+1,:)={r,char(meta.Encoder),char(meta.Condition), ...
        char(meta.Direction),char(meta.Label),t(1),t(end),median(diff(t)), ...
        aRise,aFall,bRise,bFall,aLeading,bLeading,skipped, ...
        skipped/max(1,sum(changed))*100,char(sequence),char(meta.SourceFile)};

    modes=cell(1,3);
    for j=1:3
        if ~any(string(ds.getElementNames)==string(modeNames{j})), continue; end
        [tc,c]=getSignal(ds,modeNames{j});
        select=tc>=t(1) & tc<=t(end);
        tc=tc(select); c=c(select);
        if numel(tc)<2, continue; end
        delta=diff(c);
        if isfinite(modulus(j))
            assert(modulus(j)>0,'Counter modulus must be positive.');
            % Requires less than half a counter cycle of motion per sample.
            delta=mod(delta+modulus(j)/2,modulus(j))-modulus(j)/2;
        end
        relative=[0;cumsum(delta)];
        wrapRows=find(abs(diff(c))>modulus(j)/2);
        % Boundary candidates are retained; resets require separate inspection.
        cpr=ppr*multipliers(j);
        angle=nan(size(relative)); velocity=nan(size(relative));
        if isfinite(cpr)
            angle=relative*2*pi/cpr;
            past=interp1(tc,angle,tc-velocityWindow/2,'linear',NaN);
            future=interp1(tc,angle,tc+velocityWindow/2,'linear',NaN);
            velocity=(future-past)/velocityWindow;
        end
        % Motion interval is an estimate: first through last nonzero change.
        changes=find(delta~=0);
        motionDuration=NaN; meanVelocity=NaN;
        if ~isempty(changes)
            i0=changes(1); i1=changes(end)+1;
            motionDuration=tc(i1)-tc(i0);
            if isfinite(cpr) && motionDuration>0
                meanVelocity=(angle(i1)-angle(i0))/motionDuration;
            end
        end
        peak=NaN; finiteVelocity=velocity(isfinite(velocity));
        if ~isempty(finiteVelocity), peak=max(abs(finiteVelocity)); end
        pprEstimate=NaN;
        if meta.Role=="Motion" && isfinite(reference) && reference~=0
            pprEstimate=abs(relative(end))/multipliers(j)*360/abs(reference);
        end
        % This is a diagnostic; large changes are retained, never discarded.
        maxStep=max(abs(delta));
        if isfinite(cpr) && maxStep>cpr
            warning('Record %d %s: step exceeds one revolution; inspect reset/wrap.', ...
                r,modeNames{j});
        end
        modes{j}=struct('Time',tc,'RawCount',c,'RelativeCount',relative, ...
            'RelativePulses',relative/multipliers(j), ...
            'AngleRad',angle,'VelocityRad_s',velocity,'WrapCandidateIndices',wrapRows);
        countRows(end+1,:)={r,char(meta.Encoder),char(meta.Condition), ...
            char(meta.Direction),char(meta.Label),modeNames{j},ppr, ...
            cpr,relative(end),relative(end)/multipliers(j),rad2deg(angle(end)), ...
            rad2deg(max(angle)-min(angle)),motionDuration,meanVelocity,peak, ...
            maxStep,pprEstimate,modulus(j),char(meta.SourceFile)};
    end
    processed{r}=struct('Metadata',rmfield(meta,'Dataset'),'Time',t, ...
        'NormalizedA',A,'NormalizedB',B,'LogicA',a,'LogicB',b,'Modes',{modes});

end

%% EXPORT TABLES AND REUSABLE PROCESSED DATA
CountResults=cell2table(countRows,'VariableNames', ...
    {'RecordID','Encoder','Condition','Direction','Recording','Mode', ...
     'PPR_Used','CountsPerRev','NetCount','NetPulses','NetAngle_deg','AngleSpan_deg', ...
     'MotionDurationEstimate_s','MeanMotionVelocity_rad_s','PeakAbsVelocity_rad_s', ...
     'MaxCountStep','PPR_EstimateFromReferenceAngle','CounterModulus','SourceFile'});
SignalResults=cell2table(signalRows,'VariableNames', ...
    {'RecordID','Encoder','Condition','Direction','Recording','Start_s','End_s', ...
     'MedianSampleInterval_s','A_Rise','A_Fall','B_Rise','B_Fall', ...
     'A_LeadingTransitions','B_LeadingTransitions','SkippedTransitions', ...
     'SkippedPercentOfChangedSamples','Sequence','SourceFile'});
writetable(CountResults,fullfile(tableFolder,'31_33_Count_Position_Velocity.csv'));
writetable(SignalResults,fullfile(tableFolder,'32_AB_Signal_Results.csv'));
save(fullfile(outFolder,'Encoder_Analysis_Results.mat'), ...
    'CountResults','SignalResults','processed','bournsPPR','amtPPR', ...
    'referenceAngleDeg','bournsReferenceAngleDeg','amtReferenceAngleDeg','startupCutoff','analysisWindows','threshold', ...
    'velocityWindow','counterModulusBOURNS','counterModulusAMT','-v7.3');

% Organize processed recordings by experiment role / encoder / condition.
for r=1:numel(processed)
    meta=records(r);
    dest=fullfile(processedFolder,char(meta.Role),char(meta.Encoder),char(meta.Condition));
    if ~isfolder(dest), mkdir(dest); end
    Record=processed{r}; %#ok<NASGU>
    save(fullfile(dest,sprintf('Record_%03d.mat',r)),'Record','-v7.3');
end
Resolution=table(repelem(["BOURNS";"AMT103-V"],3), ...
    repmat(["X1";"X2";"X4"],2,1),repelem([bournsPPR;amtPPR],3), ...
    reshape(([bournsPPR;amtPPR].*[1 2 4])',[],1), ...
    'VariableNames',{'Encoder','Mode','PPR','CountsPerRev'});
Resolution.DegreesPerCount=360./Resolution.CountsPerRev;
writetable(Resolution,fullfile(tableFolder,'31_Angular_Resolution.csv'));

%% SELECT ONE REPRESENTATIVE RECORD PER CONDITION (tables keep all repeats)
% Columns: Slow CW, Slow CCW, Fast CW, Fast CCW. Rows: BOURNS, AMT.
% Set a positive RecordID above to override automatic selection.
encoders=["BOURNS" "AMT103-V"];
conditions=["Slow" "Slow" "Fast" "Fast"];
directions=["CW" "CCW" "CW" "CCW"];
chosen=zeros(2,4);
for e=1:2
    for col=1:4
        candidates=find(string({records.Encoder})==encoders(e) & ...
            string({records.Condition})==conditions(col) & ...
            string({records.Direction})==directions(col));
        override=representativeIDs(e,col);
        if override>0
            assert(ismember(override,candidates),'Representative RecordID is in the wrong condition.');
            chosen(e,col)=override;
        elseif ~isempty(candidates)
            % Prefer the recording labeled repeat 1; otherwise use the first.
            firstRepeat=find(arrayfun(@(id) ...
                ~isempty(regexp(char(records(id).Label),'1\s*$','once')), ...
                candidates),1);
            if isempty(firstRepeat), chosen(e,col)=candidates(1);
            else, chosen(e,col)=candidates(firstRepeat); end
        end
    end
end
fprintf('\nRepresentative IDs (rows BOURNS/AMT; SlowCW, SlowCCW, FastCW, FastCCW):\n');
disp(chosen);

%% FIGURE 1: A/B - two encoders, two speeds, two directions
fprintf('Creating figure 1/4...\n');
fig=figure('Color','w','Visible',figureVisible,'Position',[40 80 1500 650]);
tiledlayout(2,4,'TileSpacing','compact','Padding','compact');
for e=1:2
    for col=1:4
        nexttile;
        id=chosen(e,col);
        if id==0, axis off; text(.1,.5,'No matching recording'); continue; end
        p=processed{id}; t=p.Time;
        state=2*double(p.LogicA)+double(p.LogicB);
        lut=[0 -1 1 0; 1 0 0 -1; -1 0 0 1; 0 1 -1 0];
        changed=diff(state)~=0;
        steps=lut(sub2ind([4 4],state(1:end-1)+1,state(2:end)+1));
        a=chooseZoom(t,changed,steps,zoomDuration);
        if isfinite(phaseZoomStart(e,col))
            a=max(t(1),min(phaseZoomStart(e,col),max(t(1),t(end)-zoomDuration)));
        end
        b=min(t(end),a+zoomDuration);
        use=t>=a & t<=b;
        % Same time scale in all panels. Original measured samples, unfiltered.
        plot(t(use)-a,p.NormalizedA(use),'Color',[.1 .45 .85],'LineWidth',1);
        hold on;
        plot(t(use)-a,p.NormalizedB(use),'Color',[.9 .35 .1],'LineWidth',1);
        yline(threshold,'k:','HandleVisibility','off');
        grid on; xlim([0 zoomDuration]); ylim([-.1 1.1]);
        xlabel('Time in selected window (s)'); ylabel('Normalized amplitude');
        title(sprintf('%s | %s %s\nRecord %d; start %.3f s', ...
            encoders(e),conditions(col),directions(col),id,a),'Interpreter','none');
        legend('A','B','Location','best');
    end
end
sgtitle('1. A/B: representative measured windows (full statistics in tables)');
saveFigure(fig,figureFolder,'32_AB_Comparison',saveFigures);

%% FIGURE 2: X4 angular position and velocity, Slow/Fast on the same axes
fprintf('Creating figure 2/4...\n');
fig=figure('Color','w','Visible',figureVisible,'Position',[40 80 1500 700]);
tiledlayout(2,4,'TileSpacing','compact','Padding','compact');
speedColors=[.1 .45 .85; .9 .35 .1];
for directionIndex=1:2
    for e=1:2
        for panel=1:2
            nexttile; hold on; available=false;
            for speedIndex=1:2
                col=(speedIndex-1)*2+directionIndex;
                id=chosen(e,col);
                if id==0, continue; end
                m=processed{id}.Modes{3};
                if isempty(m) || ~any(isfinite(m.AngleRad)), continue; end
                [use,relativeTime]=motionSelection(m);
                if panel==1
                    stairs(relativeTime,m.AngleRad(use),'Color',speedColors(speedIndex,:), ...
                        'LineWidth',1.2,'DisplayName',conditions(col));
                else
                    plot(relativeTime,m.VelocityRad_s(use),'Color',speedColors(speedIndex,:), ...
                        'LineWidth',1.2,'DisplayName',conditions(col));
                end
                available=true;
            end
            if ~available
                axis off;
                text(.05,.5,encoders(e)+": enter verified PPR to calculate rad/rad/s", ...
                    'Units','normalized','FontSize',10);
            else
                grid on; xlabel('Time from first detected motion (s)');
                if panel==1, ylabel('Position (rad)');
                else, ylabel('Velocity (rad/s)'); end
                legend('show','Location','best');
            end
            if panel==1, quantity="Position"; else, quantity="Velocity"; end
            title(encoders(e)+" | "+directions(directionIndex)+" | "+quantity);
        end
    end
end
sgtitle(sprintf('2. X4 position/velocity: actual scale, velocity window %.2f s',velocityWindow));
saveFigure(fig,figureFolder,'33_Position_Velocity',saveFigures);

%% FIGURE 3: X1/X2/X4 comparison, one Slow CW recording per encoder
fprintf('Creating figure 3/4...\n');
fig=figure('Color','w','Visible',figureVisible,'Position',[80 100 1200 450]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
for e=1:2
    nexttile; hold on;
    id=chosen(e,1);
    if id==0, axis off; text(.1,.5,'No Slow CW recording'); continue; end
    anchor=processed{id}.Modes{3};
    if isempty(anchor), axis off; text(.1,.5,'No X4 signal'); continue; end
    [use,relativeTime]=motionSelection(anchor);
    t0=anchor.Time(find(diff(anchor.RelativeCount)~=0,1));
    if isempty(t0), t0=anchor.Time(1); end
    lo=anchor.Time(find(use,1)); hi=anchor.Time(find(use,1,'last'));
    for j=1:3
        m=processed{id}.Modes{j};
        if isempty(m), continue; end
        keep=m.Time>=lo & m.Time<=hi;
        stairs(m.Time(keep)-t0,m.RelativeCount(keep),'Color',modeColors(j,:), ...
            'LineWidth',1.2,'DisplayName',modeNames{j});
    end
    grid on; xlabel('Time from first detected motion (s)'); ylabel('Relative count');
    title(sprintf('%s | Slow CW | Record %d',encoders(e),id),'Interpreter','none');
    legend('show','Location','best');
end
sgtitle('3. X1/X2/X4: representative recordings; every repeat remains in the tables');
saveFigure(fig,figureFolder,'31_X1_X2_X4',saveFigures);

%% FIGURE 4: AMT index PPR and wrap validation (actual observations only)
fprintf('Creating figure 4/4...\n');
fig=figure('Color','w','Visible',figureVisible,'Position',[60 80 1300 800]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
IndexResults=table(); WrapResults=table(); PPRValidation=table();
indexID=find(string({records.Role})=="IndexPPR",1);
wrapID=find(string({records.Role})=="Wrap",1);
nexttile;
if isempty(indexID)
    axis off; text(.1,.5,'No index recording');
else
    p=processed{indexID}; [tx,x]=getSignal(records(indexID).Dataset,'X');
    rises=find(diff(double(x>=threshold))==1)+1;
    rises=rises(tx(rises)>=startupCutoff);
    events=tx(rises);
    plot(tx,x,'Color',[.2 .5 .8]); hold on;
    plot(events,x(rises),'ro'); grid on; xlabel('Time (s)'); ylabel('Index X');
    title('Index events: inspect repeated crossings near one position');
    rows=cell(0,9);
    for k=1:numel(events)-1
        dc=nan(1,3);
        for j=1:3
            m=p.Modes{j}; if isempty(m), continue; end
            endpoints=interp1(m.Time,m.RelativeCount,events(k:k+1),'previous',NaN);
            dc(j)=diff(endpoints);
        end
        estimate=abs(dc)./[1 2 4];
        ratiosOK=all(isfinite(estimate)) && max(estimate)-min(estimate)<=1;
        selected=ismember(k,indexValidationIntervals);
        status="Unselected: inspect motion";
        if all(dc==0), status="Zero count: not a complete revolution";
        elseif selected && ratiosOK, status="Selected revolution interval";
        elseif selected, status="Selected but modes disagree"; end
        rows(end+1,:)={k,events(k),events(k+1),dc(1),dc(2),dc(3), ...
            estimate(1),selected && ratiosOK && all(dc~=0),char(status)};
    end
    IndexResults=cell2table(rows,'VariableNames',{'Interval','Start_s','End_s', ...
        'DeltaX1','DeltaX2','DeltaX4','PPR_FromX1','UsedForSummary','Status'});
    writetable(IndexResults,fullfile(tableFolder,'31_Index_PPR_All_Intervals.csv'));
    valid=IndexResults.UsedForSummary;
    if any(valid)
        measured=abs([IndexResults.DeltaX1(valid) IndexResults.DeltaX2(valid)/2 ...
            IndexResults.DeltaX4(valid)/4]);
        PPRValidation=table(["X1";"X2";"X4"],repmat(sum(valid),3,1), ...
            mean(measured,1)',std(measured,0,1)',repmat(amtPPR,3,1), ...
            'VariableNames',{'Mode','ValidIntervals','MeanMeasuredPPR','StdPPR','ConfiguredPPR'});
        writetable(PPRValidation,fullfile(tableFolder,'31_AMT_Measured_PPR_Summary.csv'));
    end
end
nexttile;
if isempty(IndexResults)
    axis off; text(.1,.5,'No complete index intervals');
else
    bar(IndexResults.Interval,abs([IndexResults.DeltaX1 IndexResults.DeltaX2/2 IndexResults.DeltaX4/4]));
    hold on; yline(amtPPR,'k--','Configured PPR'); grid on;
    xlabel('Index interval'); ylabel('Pulses per interval');
    legend('X1','X2 / 2','X4 / 4','Location','best');
    title('All intervals shown; only selected revolutions summarize PPR');
end
nexttile;
if isempty(wrapID) || isempty(processed{wrapID}.Modes{3})
    axis off; text(.1,.5,'No wrap recording');
else
    m=processed{wrapID}.Modes{3};
    stairs(m.Time,m.RawCount); grid on; xlabel('Time (s)'); ylabel('Raw X4 count');
    title('Raw counter: boundary 0 / 65535');
    ix=m.WrapCandidateIndices;
    WrapResults=table(m.Time(ix+1),m.RawCount(ix),m.RawCount(ix+1), ...
        'VariableNames',{'Time_s','Before','After'});
    deltas=diff(m.RelativeCount);
    WrapResults.CorrectedDelta=deltas(ix);
    writetable(WrapResults,fullfile(tableFolder,'33_Wrap_Candidates.csv'));
end
nexttile;
if isempty(wrapID) || isempty(processed{wrapID}.Modes{3})
    axis off; text(.1,.5,'No wrap recording');
else
    m=processed{wrapID}.Modes{3};
    stairs(m.Time,m.AngleRad); grid on; xlabel('Time (s)'); ylabel('Relative position (rad)');
    title('Unwrapped X4 position (signed; no artificial jump removal)');
end
sgtitle('AMT: index interval validation and counter wrap correction');
saveFigure(fig,figureFolder,'31_33_Index_Wrap_Validation',saveFigures);
save(fullfile(outFolder,'Summary_Tables.mat'),'Manifest','Resolution','IndexResults','PPRValidation','WrapResults');

% Match full-record signal diagnostics to observed X4 motion speed.
motionIDs=[records(string({records.Role})=="Motion").ID];
selected=strcmp(CountResults.Mode,'EncoderX4') & ismember(CountResults.RecordID,motionIDs);
SpeedQuality=innerjoin(CountResults(selected,{'RecordID','Encoder','Condition','Direction', ...
    'MotionDurationEstimate_s','MeanMotionVelocity_rad_s','PeakAbsVelocity_rad_s','MaxCountStep'}), ...
    SignalResults(:,{'RecordID','MedianSampleInterval_s','A_LeadingTransitions', ...
    'B_LeadingTransitions','SkippedTransitions','SkippedPercentOfChangedSamples'}), ...
    'Keys','RecordID');
SpeedQuality.MeanAbsVelocity_rad_s=abs(SpeedQuality.MeanMotionVelocity_rad_s);
writetable(SpeedQuality,fullfile(tableFolder,'32_Speed_vs_Sampled_Signal_Quality.csv'));

% Summary across repeats; compare observed speed, not just folder labels.
SummaryCounts=groupsummary(CountResults,{'Encoder','Condition','Direction','Mode'}, ...
    {'mean','std'},{'NetCount','NetAngle_deg','MeanMotionVelocity_rad_s'});
writetable(SummaryCounts,fullfile(tableFolder,'Summary_Across_Repeats.csv'));
note=fopen(fullfile(outFolder,'READ_ME.txt'),'w');
assert(note>=0,'Cannot write READ_ME.txt');
fprintf(note,['31: mode comparison, angular resolution, selected index intervals.\n' ...
    '32: sampled A/B; skipped states are not proof of hardware count loss.\n' ...
    '33: signed relative position, windowed velocity, counter boundary candidates.\n' ...
    'No Speed is a label, not an assumption of stationary shaft.\n' ...
    'Angle uses verified PPR; counter modulus is Counter Period + 1.\n' ...
    'Startup samples before %.3f s excluded; no other jumps removed.\n' ...
    'Homing performance is NOT established: supply index, position and homed flag\n' ...
    'from several actual homing trials before evaluating repeatability.\n'],startupCutoff);
fclose(note);
disp(CountResults);
disp(SignalResults);
fprintf('\nResults saved to: %s\n',outFolder);
fprintf(['No Speed is treated as an unspecified speed condition, not stationary.\n' ...
    'A/B edge counts describe sampled data, not confirmed hardware pulse loss.\n' ...
    'Homing performance requires actual repeated homing test recordings.\n']);

%% LOCAL FUNCTIONS (keep these at the bottom of the script)
function [sets,labels]=findRecordings(object,path)
sets={}; labels=strings(0,1);
if isa(object,'Simulink.SimulationOutput')
    names=who(object);
    for i=1:numel(names)
        [s,l]=findRecordings(object.get(names{i}),path+"/"+string(names{i}));
        sets=[sets s]; labels=[labels;l]; %#ok<AGROW>
    end
    return
end
if ~isa(object,'Simulink.SimulationData.Dataset'), return; end
names=string(object.getElementNames);
if any(names=="A1") && any(names=="A2")
    sets={object}; labels=path; return
end
for i=1:object.numElements
    element=object.getElement(i); name=names(i);
    if strlength(name)==0, name="set"+i; end
    if isa(element,'Simulink.SimulationData.Signal')
        element=element.Values;
    end
    [s,l]=findRecordings(element,path+"/"+name);
    sets=[sets s]; labels=[labels;l]; %#ok<AGROW>
end
end

function [t,x]=getSignal(ds,name)
element=ds.getElement(name); ts=element.Values;
assert(isa(ts,'timeseries'),'Signal %s must contain a timeseries.',name);
t=double(ts.Time(:)); x=double(ts.Data(:));
assert(numel(t)==numel(x),'Signal %s must be scalar.',name);
assert(numel(t)>=2 && all(isfinite(t)) && all(diff(t)>0), ...
    'Signal %s requires strictly increasing times.',name);
assert(all(isfinite(x)),'Signal %s contains non-finite values.',name);
end

function start=chooseZoom(t,changed,steps,duration)
% Column vectors prevent implicit NxN expansion when combining masks.
% Prefix sums count transitions without re-scanning each whole recording.
t=t(:); changed=changed(:); steps=steps(:);
assert(numel(changed)==numel(t)-1 && numel(steps)==numel(changed), ...
    'Transition arrays must have one entry per sample interval.');
edges=find(changed);
if isempty(edges), start=t(1); return; end
candidates=edges(1:max(1,ceil(numel(edges)/200)):end);
validPrefix=[0; cumsum(double(steps~=0))];
badPrefix=[0; cumsum(double(changed & steps==0))];
edgeTime=t(1:end-1);
best=-Inf; start=max(t(1),t(edges(1))-.02);
for idx=candidates(:)'
    a=max(t(1),t(idx)-.02); b=min(t(end),a+duration);
    lo=lowerBound(edgeTime,a);
    hi=upperBound(edgeTime,b)-1;
    if lo>hi, continue; end
    valid=validPrefix(hi+1)-validPrefix(lo);
    bad=badPrefix(hi+1)-badPrefix(lo);
    n=valid+bad;
    if n==0, score=-Inf;
    else, score=valid/n+0.01*min(valid,8); end
    if score>best, best=score; start=a; end
end
start=min(start,max(t(1),t(end)-duration));
end

function i=lowerBound(x,value)
% First sample greater than or equal to value, or numel(x)+1.
lo=1; hi=numel(x)+1;
while lo<hi
    mid=floor((lo+hi)/2);
    if x(mid)<value, lo=mid+1; else, hi=mid; end
end
i=lo;
end

function i=upperBound(x,value)
% First sample greater than value, or numel(x)+1.
lo=1; hi=numel(x)+1;
while lo<hi
    mid=floor((lo+hi)/2);
    if x(mid)<=value, lo=mid+1; else, hi=mid; end
end
i=lo;
end

function saveFigure(fig,folder,name,enabled)
if ~enabled, return; end
fprintf('Exporting %s...\n',name); drawnow;
exportgraphics(fig,fullfile(folder,[name '.png']), ...
    'Resolution',200,'BackgroundColor','white');
% PNG only; no separate image per repeat.
end

function [use,relativeTime]=motionSelection(m)
% Crop idle tails for display; retain actual position, time and velocity.
changes=find(diff(m.RelativeCount)~=0);
if isempty(changes)
    use=true(size(m.Time)); t0=m.Time(1);
else
    t0=m.Time(changes(1));
    lo=max(m.Time(1),t0-.15);
    hi=min(m.Time(end),m.Time(changes(end)+1)+.15);
    use=m.Time>=lo & m.Time<=hi;
end
relativeTime=m.Time(use)-t0;
end
