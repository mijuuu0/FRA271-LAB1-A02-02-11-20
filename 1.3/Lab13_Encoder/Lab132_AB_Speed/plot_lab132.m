%% การทดลอง 1.3.2 แพทเทิร์น A/B และผลของความเร็ว
% ใช้ข้อมูลและช่วงเดียวกับ Encoder_Lab132_Final เปลี่ยนเฉพาะรูปแบบแสดงผล
clear; clc; close all;
folder=fileparts(mfilename('fullpath')); D=load(fullfile(folder,'data_lab132.mat'));
fonts=listfonts; font='Tahoma';
if any(strcmp(fonts,'TH Sarabun New')), font='TH Sarabun New'; end
set(groot,'defaultAxesFontName',font,'defaultTextFontName',font,'defaultTextInterpreter','none');
out=fullfile(folder,'Figures'); if ~isfolder(out), mkdir(out); end
encoders={'BOURNS','AMT103'}; directions={'CW','CCW'};

%% แยกเซ็นเซอร์และทิศทาง: ซ้ายช้า ขวาเร็ว แถวคือซ้ำที่ 1–3
for e=1:2
    for d=1:2
        fig=figure('Color','w','Position',[40 40 1500 1100]);
        tiledlayout(3,2,'TileSpacing','loose','Padding','loose');
        for repeat=1:3
            for speed=1:2
                speedCode='Slow'; speedName='ช้า';
                if speed==2, speedCode='Fast'; speedName='เร็ว'; end
                id=find(strcmp({D.Plots.Encoder},encoders{e}) & ...
                    strcmp({D.Plots.Direction},directions{d}) & ...
                    strcmp({D.Plots.Speed},speedCode) & [D.Plots.Repeat]==repeat,1);
                R=D.Plots(id); ax=nexttile; hold(ax,'on');
                for j=1:size(R.Flags,1)
                    if R.Flags(j,3)==1
                        a=R.Flags(j,1); b=R.Flags(j,2);
                        patch(ax,[a b b a],[-.2 -.2 3.2 3.2],[1 .88 .88],'EdgeColor','none');
                    end
                end
                stairs(ax,R.X,R.Y,'Color',[.08 .4 .8],'LineWidth',1.5);
                for j=0:10, xline(ax,j,':','Color',[.75 .75 .75]); end
                xlim(ax,[0 10]); ylim(ax,[-.2 3.2]);
                yticks(ax,0:3); yticklabels(ax,{'00','01','11','10'});
                xticks(ax,(1:10)-.5); xticklabels(ax,string(1:10));
                ax.XMinorTick='on'; ax.XAxis.MinorTickValues=R.MinorTicks;
                ax.FontSize=15; ax.YGrid='on'; ax.Box='on';
                xlabel(ax,'ลำดับรอบสัญญาณ'); ylabel(ax,'สถานะของสัญญาณ A/B');
                title(ax,sprintf('หมุน%s | ซ้ำที่ %d | ไม่ผ่าน %d/10 รอบ', ...
                    speedName,repeat,R.Failed),'FontSize',18);
            end
        end
        directionName='ตามเข็มนาฬิกา'; if d==2, directionName='ทวนเข็มนาฬิกา'; end
        sgtitle(sprintf('การทดลอง 1.3.2 | %s | %s (%s)', ...
            encoders{e},directionName,directions{d}),'FontSize',22);
        exportgraphics(fig,fullfile(out,[encoders{e} '_' directions{d} '_States.png']),'Resolution',300);
    end
end

%% ตัวอย่างหนึ่งรอบจริงจากข้อมูลช้า
fig=figure('Color','w','Position',[60 60 1300 850]); tiledlayout(2,2,'TileSpacing','loose');
for k=1:numel(D.References)
    R=D.References(k); ax=nexttile;
    stairs(ax,0:4,R.Level(:),'Color',[.08 .4 .8],'LineWidth',2);
    xlim(ax,[0 4]); ylim(ax,[-.2 3.2]); xticks(ax,0:4);
    yticks(ax,0:3); yticklabels(ax,{'00','01','11','10'}); grid(ax,'on'); ax.FontSize=16;
    xlabel(ax,'ลำดับการเปลี่ยนสถานะในหนึ่งรอบ'); ylabel(ax,'สถานะของสัญญาณ A/B');
    title(ax,sprintf('%s | %s | ซ้ำที่ %d',R.Encoder,R.Direction,R.Repeat),'FontSize',19);
end
sgtitle('การทดลอง 1.3.2 | ตัวอย่างลำดับสถานะเมื่อหมุนช้า','FontSize',22);
exportgraphics(fig,fullfile(out,'AB_One_Cycle.png'),'Resolution',300);

%% สรุปจากสามซ้ำ: ไม่ผ่านหมายถึงผิดแพทเทิร์นหรือเก็บไม่ครบ
fig=figure('Color','w','Position',[70 70 1600 650]); tiledlayout(1,2,'TileSpacing','loose');
colors=[.12 .42 .72;.89 .43 .12;.23 .58 .37];
for e=1:2
    G=D.Summary(strcmp({D.Summary.Encoder},encoders{e})); ax=nexttile; hold(ax,'on');
    means=[G.MeanPct]; hMean=bar(ax,1:4,means,.6,'FaceColor',[.8 .85 .92],'EdgeColor','none');
    hRepeat=gobjects(3,1);
    for repeat=1:3
        values=arrayfun(@(g)g.RepeatPct(repeat),G);
        hRepeat(repeat)=scatter(ax,(1:4)+(repeat-2)*.1,values,70,colors(repeat,:),'filled');
    end
    for j=1:4
        text(ax,j,106,sprintf('%.1f%%',means(j)),'HorizontalAlignment','center','FontSize',17);
    end
    xticks(ax,1:4); xticklabels(ax,{'ช้า CW','ช้า CCW','เร็ว CW','เร็ว CCW'});
    xlim(ax,[.5 4.5]); ylim(ax,[0 115]); yticks(ax,0:10:100); ax.FontSize=16; ax.YGrid='on';
    xlabel(ax,'เงื่อนไขการหมุน'); ylabel(ax,'รอบที่ไม่ผ่านเกณฑ์ (%)'); title(ax,encoders{e},'FontSize',20);
    legend(ax,[hMean;hRepeat],{'เฉลี่ยสามซ้ำ','ซ้ำที่ 1','ซ้ำที่ 2','ซ้ำที่ 3'}, ...
        'Location','southoutside','Orientation','horizontal','FontSize',14);
end
sgtitle('การทดลอง 1.3.2 | ผลการตรวจแพทเทิร์น 10 รอบต่อซ้ำ','FontSize',22);
exportgraphics(fig,fullfile(out,'Speed_Comparison.png'),'Resolution',300);
fprintf('รอบไม่ผ่าน / 10 รอบ และเปอร์เซ็นต์เฉลี่ยสามซ้ำ\n');
for k=1:numel(D.Summary)
    R=D.Summary(k); speed='ช้า'; if strcmp(R.Speed,'Fast'), speed='เร็ว'; end
    fprintf('%s | %s %s | %d, %d, %d รอบ | เฉลี่ย %.1f%%\n', ...
        R.Encoder,speed,R.Direction,R.FailedCounts(1),R.FailedCounts(2),R.FailedCounts(3),R.MeanPct);
end
