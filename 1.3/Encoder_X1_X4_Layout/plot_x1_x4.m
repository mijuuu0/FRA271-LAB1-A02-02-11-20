%% แยกเซ็นเซอร์และ CW/CCW: แกนหลัก X1 แกนย่อย X4
clear; clc; close all;
folder=fileparts(mfilename('fullpath'));
D=load(fullfile(folder,'X1_X4_PlotData.mat'),'Plots');
fonts=listfonts; font='Tahoma';
if any(strcmp(fonts,'TH Sarabun New')), font='TH Sarabun New'; end
set(groot,'defaultAxesFontName',font,'defaultTextFontName',font);
set(groot,'defaultTextInterpreter','none','defaultAxesTickLabelInterpreter','none');
encoders={'BOURNS','AMT103'}; directions={'CW','CCW'};
for e=1:2
    for d=1:2
        fig=figure('Color','w','Position',[40 40 1550 1150]);
        tiledlayout(3,2,'TileSpacing','loose','Padding','loose');
        P=D.Plots(strcmp({D.Plots.Encoder},encoders{e}) & strcmp({D.Plots.Direction},directions{d}));
        topAxes=gobjects(6,1);
        for k=1:6
            R=P(k); ax=nexttile; topAxes(k)=ax; hold(ax,'on');
            stairs(ax,R.X,R.Y,'Color',[.08 .4 .8],'LineWidth',1.5);
            for j=R.X1Tick(:)', xline(ax,j,':','Color',[.75 .75 .75]); end
            xlim(ax,[0 10]); ylim(ax,[-.2 3.2]);
            yticks(ax,0:3); yticklabels(ax,{'00','01','11','10'});
            ax.XAxisLocation='top'; xticks(ax,R.X1Tick);
            xlabel(ax,'แกนหลัก: Count X1 จากจุดเริ่มช่วง'); ylabel(ax,'สถานะ A/B');
            ax.YGrid='on'; ax.FontSize=12; ax.Box='off';
            speed='ช้า'; if strcmp(R.Speed,'Fast'), speed='เร็ว'; end
            title(ax,sprintf('%s | ซ้ำที่ %d | %.3f–%.3f วินาที', ...
                speed,R.Repeat,R.Start_s,R.End_s),'FontSize',16);
        end
        heading='ตามเข็มนาฬิกา (CW)';
        if d==2, heading='ทวนเข็มนาฬิกา (CCW)'; end
        sgtitle(sprintf('1.3.2 | %s | %s',encoders{e},heading),'FontSize',22);
        drawnow;
        for k=1:6
            R=P(k); ax=topAxes(k);
            bottom=axes('Parent',fig,'Units',ax.Units,'Position',ax.Position, ...
                'Color','none','XAxisLocation','bottom','YColor','none','YTick',[], ...
                'XLim',[0 10],'YLim',[-.2 3.2],'FontName',font,'FontSize',10,'Box','off');
            % All measured X4 edges appear as minor ticks. Thin numeric labels
            % only when dense; no missing hardware counts are interpolated.
            stride=max(1,ceil(numel(R.X4Tick)/40)); pick=unique([1:stride:numel(R.X4Tick),numel(R.X4Tick)]);
            xticks(bottom,R.X4Tick(pick)); xticklabels(bottom,string(R.X4Label(pick)));
            bottom.XMinorTick='on'; bottom.XAxis.MinorTickValues=unique(R.X4Tick);
            xlabel(bottom,'แกนย่อย: Count X4 จากจุดเริ่มช่วง');
            bottom.HitTest='off'; bottom.PickableParts='none';
        end
        exportgraphics(fig,fullfile(folder,[encoders{e} '_' directions{d} '_X1_X4.png']), ...
            'Resolution',250);
    end
end
