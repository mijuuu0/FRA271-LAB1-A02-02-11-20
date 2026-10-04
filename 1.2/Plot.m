clear;
clc;
close all;
scriptDir=fileparts(mfilename('fullpath'));

%% =========================
% ระยะที่เก็บข้อมูล
% =========================
distance = 0:2:32;      % mm
nPoint = length(distance);

%% =========================
% โฟลเดอร์ข้อมูล
% =========================
folders = {
    'raw data/No Shield ขั้ว N'
    'raw data/No Shield ขั้ว S'
    'raw data/With Shield ขั้ว N'
    'raw data/With Shield ขั้ว S'
};

conditionName = {
    'N - No Shield'
    'S - No Shield'
    'N - With Shield'
    'S - With Shield'
};

%% =========================
% ค่าคงที่ของ Sensor
% DRV5055A2, Vcc = 3.3 V
% =========================
Vcc = 3.3;
ADCmax = 4095;

Vq = 1.65;              % V
Sensitivity = 0.030;   % V/mT

%% =========================
% เตรียมตัวแปรเก็บข้อมูล
% dimension:
% condition x round x position
% =========================
ADC_all  = zeros(4,3,nPoint);
Vout_all = zeros(4,3,nPoint);
B_all    = zeros(4,3,nPoint);

%% =========================
% โหลดข้อมูลทั้งหมด
% =========================
for c = 1:4

    for r = 1:3

        filename = fullfile( ...
            scriptDir, folders{c}, ...
            sprintf('round %d.mat',r));

        D = load(filename);

        for p = 1:nPoint

            % Dataset ของแต่ละตำแหน่ง
            pointData = D.data{p};

            % Signal ตัวแรก = Raw A0
            rawSignal = pointData{1};

            % ดึงค่า ADC
            rawValue = double(rawSignal.Values.Data);

            % ทำให้เป็น vector
            rawValue = rawValue(:);

            % ค่าเฉลี่ย ADC ณ ตำแหน่งนั้น
            ADCmean = mean(rawValue,'omitnan');

            % ADC -> Voltage
            Vout = (ADCmean / ADCmax) * Vcc;

            % Voltage -> Magnetic Flux Density
            B = (Vout - Vq) / Sensitivity;

            % เก็บค่า
            ADC_all(c,r,p)  = ADCmean;
            Vout_all(c,r,p) = Vout;
            B_all(c,r,p)    = B;

        end
    end
end

%% =========================
% แก้ลำดับข้อมูลที่เก็บย้อนทิศ
% N - No Shield, Round 3
% เก็บจาก 32 mm -> 0 mm
% =========================
ADC_all(1,3,:)  = flip(ADC_all(1,3,:));
Vout_all(1,3,:) = flip(Vout_all(1,3,:));
B_all(1,3,:)    = flip(B_all(1,3,:));

%% =========================
% Plot 3 รอบในหน้าเดียว
% =========================
figure;

for r = 1:3

    subplot(3,1,r)
    hold on

    % N - No Shield
    plot(distance, squeeze(B_all(1,r,:)), ...
        'o-', ...
        'LineWidth',1.5, ...
        'MarkerSize',5, ...
        'DisplayName','N - No Shield');

    % S - No Shield
    plot(distance, squeeze(B_all(2,r,:)), ...
        'o-', ...
        'LineWidth',1.5, ...
        'MarkerSize',5, ...
        'DisplayName','S - No Shield');

    % N - With Shield
    plot(distance, squeeze(B_all(3,r,:)), ...
        'o-', ...
        'LineWidth',1.5, ...
        'MarkerSize',5, ...
        'DisplayName','N - With Shield');

    % S - With Shield
    plot(distance, squeeze(B_all(4,r,:)), ...
        'o-', ...
        'LineWidth',1.5, ...
        'MarkerSize',5, ...
        'DisplayName','S - With Shield');

    grid on
    xlim([0 32])

    xlabel('Distance (mm)')
    ylabel('Magnetic Flux Density (mT)')

    title(sprintf('Round %d',r))

    legend('Location','best')

end

sgtitle('Magnetic Flux Density Comparison')

%% =========================
% ปรับขนาด Figure
% =========================
set(gcf,'Position',[100 50 900 900]);