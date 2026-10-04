%% Lab 1.3.3: convert recorded outputs, retain recorded angle and velocity
clear;clc;close all;
root=fileparts(mfilename('fullpath'));out=fullfile(root,'results','generated');
if ~isfolder(out),mkdir(out);end
files={'B.mat','AMT.mat'};encoders={'BOURNS','AMT103'};pprs=[24 2048];
mode={'EncoderX1','EncoderX2','EncoderX4'};factor=[1 2 4];rows={};
for e=1:2
 S=load(fullfile(root,files{e}));names=fieldnames(S);D=S.(names{1});
 for k=1:D.numElements
  rec=D.getElement(k);
  if isa(rec,'Simulink.SimulationData.Signal'),rec=rec.Values;end
  f=figure('Color','w','Position',[50 50 1300 650]);tiledlayout(2,3);
  for j=1:3
   suffix=sprintf('X%d',factor(j));
   sig=rec.getElement(['pulses' suffix]);ts=sig.Values;t=double(ts.Time(:));pulses=double(ts.Data(:));
   sig=rec.getElement(['angle' suffix]);angle=double(sig.Values.Data(:));
   sig=rec.getElement(['omega' suffix]);velocity=double(sig.Values.Data(:));
   assert(numel(angle)==numel(t) && numel(velocity)==numel(t));
   % Use the original derived outputs, including their recorded zero reference.
   meanSpeed=sum(abs(diff(angle)))/(t(end)-t(1));
   nexttile(j);plot(t-t(1),angle*180/pi);grid on;title(mode{j});ylabel('Angle (deg)');xlabel('Time (s)');
   nexttile(j+3);plot(t-t(1),velocity);grid on;ylabel('Velocity (rad/s)');xlabel('Time (s)');
   rows(end+1,:)={encoders{e},k,mode{j},pulses(end),angle(end),angle(end)*180/pi,meanSpeed};
  end
  exportgraphics(f,fullfile(out,sprintf('%s_Record_%d.png',encoders{e},k)),'Resolution',250);
 end
end
writetable(cell2table(rows,'VariableNames',{'Encoder','Record','Mode','End_Pulses','End_rad','End_deg','MeanAbsSpeed_rad_s'}),fullfile(out,'Position_Velocity.csv'));
