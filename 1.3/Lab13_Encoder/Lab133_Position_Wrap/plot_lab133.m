%% การทดลอง 1.3.3 ตำแหน่ง ความเร็ว Wrap-around และจุดอ้างอิงศูนย์
clear; clc; close all;
folder=fileparts(mfilename('fullpath')); D=load(fullfile(folder,'data_lab133.mat'));
fonts=listfonts; font='Tahoma';
if any(strcmp(fonts,'TH Sarabun New')), font='TH Sarabun New'; end
set(groot,'defaultAxesFontName',font,'defaultTextFontName',font,'defaultTextInterpreter','none');
out=fullfile(folder,'Figures'); if ~isfolder(out), mkdir(out); end
encoders={'BOURNS','AMT103'}; directions={'CW','CCW'};
colors=[.12 .42 .72;.89 .43 .12;.23 .58 .37];

%% เปรียบเทียบตำแหน่งและความเร็วช้า–เร็วครบสามซ้ำ ใช้โหมด X4
for e=1:2
    for d=1:2
        fig=figure('Color','w','Position',[40 40 1550 1050]);
        tiledlayout(3,2,'TileSpacing','loose','Padding','loose');
        for repeat=1:3
            for quantity=1:2
                ax=nexttile; hold(ax,'on');
                for speed=1:2
                    code='Slow'; label='หมุนช้า'; if speed==2, code='Fast'; label='หมุนเร็ว'; end
                    id=find(strcmp({D.Records.Encoder},encoders{e}) & ...
                        strcmp({D.Records.Direction},directions{d}) & ...
                        strcmp({D.Records.Speed},code) & [D.Records.Repeat]==repeat,1);
                    if isempty(id), continue; end
                    M=D.Records(id).Modes(3); time=M.Time_s-M.Time_s(1);
                    if quantity==1
                        stairs(ax,time,M.Angle_rad,'Color',colors(speed,:),'LineWidth',1.4,'DisplayName',label);
                    else
                        plot(ax,time,M.Velocity_rad_s,'Color',colors(speed,:),'LineWidth',1.2,'DisplayName',label);
                    end
                end
                xlabel(ax,'เวลาจากเริ่มช่วงวิเคราะห์ (วินาที)');
                titleText='ตำแหน่งเชิงมุม'; ylabelText='ตำแหน่งเชิงมุม (rad)';
                if quantity==2, titleText='ความเร็วเชิงมุม'; ylabelText='ความเร็วเชิงมุม (rad/s)'; end
                ylabel(ax,ylabelText); title(ax,sprintf('%s | ซ้ำที่ %d',titleText,repeat),'FontSize',18);
                grid(ax,'on'); ax.FontSize=15; legend(ax,'show','Location','best','FontSize',14);
            end
        end
        heading='ตามเข็มนาฬิกา'; if d==2, heading='ทวนเข็มนาฬิกา'; end
        sgtitle(sprintf('การทดลอง 1.3.3 | %s | %s (%s)',encoders{e},heading,directions{d}),'FontSize',22);
        exportgraphics(fig,fullfile(out,[encoders{e} '_' directions{d} '_Position_Velocity.png']),'Resolution',300);
    end
end

%% แสดงการแปลง Count ของ X1/X2/X4 เป็นพัลส์ มุม และความเร็ว
fig=figure('Color','w','Position',[60 60 1750 800]); tiledlayout(2,3,'TileSpacing','loose');
for e=1:2
    id=find(strcmp({D.Records.Encoder},encoders{e}) & strcmp({D.Records.Direction},'CW') & ...
        strcmp({D.Records.Speed},'Slow') & [D.Records.Repeat]==1,1);
    if isempty(id), axis off; continue; end
    R=D.Records(id);
    for quantity=1:3
        ax=nexttile; hold(ax,'on');
        for mode=1:3
            M=R.Modes(mode); time=M.Time_s-M.Time_s(1);
            if quantity==1, values=M.RelativePulses; label='ตำแหน่งสัมพัทธ์ (พัลส์)';
            elseif quantity==2, values=M.Angle_rad; label='ตำแหน่งเชิงมุม (rad)';
            else, values=M.Velocity_rad_s; label='ความเร็วเชิงมุม (rad/s)'; end
            plot(ax,time,values,'Color',colors(mode,:),'LineWidth',1.2,'DisplayName',M.Mode);
        end
        xlabel(ax,'เวลาจากเริ่มช่วงวิเคราะห์ (วินาที)'); ylabel(ax,label);
        title(ax,R.Encoder,'FontSize',20); ax.FontSize=15; grid(ax,'on');
        legend(ax,'show','Location','best','FontSize',14);
    end
end
sgtitle('การทดลอง 1.3.3 | การแปลงค่าจาก X1, X2 และ X4: หมุนช้า CW ซ้ำที่ 1','FontSize',22);
exportgraphics(fig,fullfile(out,'Count_To_Position_Velocity.png'),'Resolution',300);

%% Wrap-around: แถวบนตัวนับจริง แถวล่าง Count สะสมหลังแก้ Wrap
fig=figure('Color','w','Position',[70 70 1700 800]); tiledlayout(2,3,'TileSpacing','loose');
for row=1:2
    for mode=1:3
        M=D.WrapModes(mode); ax=nexttile; time=M.Time_s-M.Time_s(1);
        if row==1, stairs(ax,time,M.RawCount,'Color',colors(mode,:),'LineWidth',1.3);
            ylabel(ax,'ค่าตัวนับดิบ (Count)'); label='ก่อนแก้ Wrap-around';
        else, stairs(ax,time,M.RelativeCount,'Color',colors(mode,:),'LineWidth',1.3);
            ylabel(ax,'จำนวน Count สะสม'); label='หลังแก้ Wrap-around';
        end
        xlabel(ax,'เวลาจากเริ่มช่วงวิเคราะห์ (วินาที)'); grid(ax,'on'); ax.FontSize=15;
        title(ax,sprintf('%s | %s',M.Mode,label),'FontSize',18);
    end
end
sgtitle('การทดลอง 1.3.3 | AMT103: การแก้ค่าตัวนับเมื่อเกิด Wrap-around','FontSize',22);
exportgraphics(fig,fullfile(out,'AMT103_Wrap_Around.png'),'Resolution',300);

%% แสดงการหักค่าเริ่มเป็นศูนย์บนข้อมูลจริง ไม่ใช่ผลทดสอบ Homing บนบอร์ด
M=D.WrapModes(3);
% เลือกตำแหน่งที่บันทึกไว้จริงเป็นจุดอ้างอิงใหม่ เพื่อแสดงการหักค่า
[~,zeroIndex]=max(abs(M.Angle_rad));
time=M.Time_s(zeroIndex:end)-M.Time_s(zeroIndex);
angleBefore=M.Angle_rad(zeroIndex:end);
angleAfter=angleBefore-angleBefore(1);
fig=figure('Color','w','Position',[80 80 1400 600]); tiledlayout(1,2,'TileSpacing','loose');
ax=nexttile; stairs(ax,time,angleBefore,'Color',colors(1,:),'LineWidth',1.5);
xlabel(ax,'เวลาจากจุดอ้างอิงที่เลือก (วินาที)'); ylabel(ax,'ตำแหน่งเชิงมุม (rad)');
title(ax,'ก่อนหักค่าที่จุดอ้างอิงใหม่','FontSize',20); grid(ax,'on'); ax.FontSize=16;
ax=nexttile; stairs(ax,time,angleAfter,'Color',colors(2,:),'LineWidth',1.5);
yline(ax,0,':','Color',[.5 .5 .5]); xlabel(ax,'เวลาจากจุดอ้างอิงที่เลือก (วินาที)');
ylabel(ax,'ตำแหน่งเชิงมุมสัมพัทธ์ (rad)'); title(ax,'หลังหักค่าที่จุดอ้างอิงใหม่เป็นศูนย์','FontSize',20);
grid(ax,'on'); ax.FontSize=16;
sgtitle('การทดลอง 1.3.3 | การกำหนดตำแหน่งอ้างอิงจากข้อมูลที่บันทึก','FontSize',22);
exportgraphics(fig,fullfile(out,'Position_Zero_Reference.png'),'Resolution',300);
fprintf('ความเร็วใช้ช่วงคำนวณ %.2f วินาที | Counter period = %d\n',D.VelocityWindow_s,D.CounterPeriod);
fprintf('การตั้งศูนย์: %s\n',D.ZeroMethod);
