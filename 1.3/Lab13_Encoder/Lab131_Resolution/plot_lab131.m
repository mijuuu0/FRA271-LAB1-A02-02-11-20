%% การทดลอง 1.3.1 ความละเอียดและจำนวน Count ต่อรอบ
clear; clc; close all;
folder=fileparts(mfilename('fullpath')); D=load(fullfile(folder,'data_lab131.mat'));
fonts=listfonts; font='Tahoma';
if any(strcmp(fonts,'TH Sarabun New')), font='TH Sarabun New'; end
set(groot,'defaultAxesFontName',font,'defaultTextFontName',font,'defaultTextInterpreter','none');
out=fullfile(folder,'Figures'); if ~isfolder(out), mkdir(out); end
colors=[.12 .42 .72;.89 .43 .12;.23 .58 .37];
fig=figure('Color','w','Position',[50 50 1400 600]); tiledlayout(1,2,'TileSpacing','loose');
for e=1:2
    R=D.Results(e); ax=nexttile; h=bar(ax,R.Counts','grouped');
    for j=1:3, h(j).FaceColor=colors(j,:); end
    xticks(ax,1:3); xticklabels(ax,{'X1','X2','X4'}); ax.FontSize=16; ax.YGrid='on';
    xlabel(ax,'โหมดการอ่าน'); ylabel(ax,'จำนวน Count ต่อการหมุนหนึ่งรอบ');
    title(ax,sprintf('%s | PPR = %d',R.Encoder,R.PPR),'FontSize',20);
    legend(ax,{'ซ้ำที่ 1','ซ้ำที่ 2','ซ้ำที่ 3'},'Location','northwest','FontSize',14);
end
sgtitle('การทดลอง 1.3.1 | จำนวน Count เมื่อหมุนครบหนึ่งรอบ','FontSize',22);
exportgraphics(fig,fullfile(out,'01_Counts_Per_Revolution.png'),'Resolution',300);
fig=figure('Color','w','Position',[60 60 1400 600]); tiledlayout(1,2,'TileSpacing','loose');
for e=1:2
    R=D.Results(e); ax=nexttile; bar(ax,1:3,R.Resolution_deg,'FaceColor',colors(e,:));
    xticks(ax,1:3); xticklabels(ax,{'X1','X2','X4'}); ax.FontSize=16; ax.YGrid='on';
    ylim(ax,[0 max(R.Resolution_deg)*1.25]);
    for j=1:3
        text(ax,j,R.Resolution_deg(j),sprintf('%.6g',R.Resolution_deg(j)), ...
            'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',16);
    end
    xlabel(ax,'โหมดการอ่าน'); ylabel(ax,'ความละเอียดเชิงมุม (องศา/Count)');
    title(ax,R.Encoder,'FontSize',20);
end
sgtitle('การทดลอง 1.3.1 | ความละเอียดเชิงมุมของ Encoder','FontSize',22);
exportgraphics(fig,fullfile(out,'02_Angular_Resolution.png'),'Resolution',300);
for e=1:2
    R=D.Results(e); fprintf('\n%s | %s\n',R.Encoder,R.Measurement);
    fprintf('จำนวน Count ต่อรอบ: แถว = ซ้ำที่ 1–3, คอลัมน์ = X1, X2, X4\n'); disp(R.Counts);
    fprintf('ความละเอียดเชิงมุม (องศา/Count):\n'); disp(R.Resolution_deg);
end
