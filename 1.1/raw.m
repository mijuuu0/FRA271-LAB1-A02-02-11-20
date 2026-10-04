clear; clc; close all;
folder=fileparts(mfilename('fullpath'));

%% Load cleaned results
R1 = load(fullfile(folder,'Result_Round1.mat'));
R2 = load(fullfile(folder,'Result_Round2.mat'));
R3 = load(fullfile(folder,'Result_Round3.mat'));

results = {R1, R2, R3};

%% Create figure
figure( ...
    'Name','Potentiometer Results - 15 Graphs', ...
    'Position',[50 50 1700 900]);

tiledlayout(3,5, ...
    'TileSpacing','compact', ...
    'Padding','compact');

%% Plot 3 rounds x 5 channels
for r = 1:3

    for ch = 1:5

        nexttile;

        % ดึง position
        x = results{r}.position;

        % ดึง voltage ของ A0-A4
        y = results{r}.voltage(ch,:);

        plot(x, y, ...
            'o-', ...
            'LineWidth',1.3, ...
            'MarkerSize',4);

        grid on;
        box on;

        xlim([0 100]);
        ylim([0 3.3]);

        xticks(0:20:100);

        xlabel('Position (%)');
        ylabel('Voltage (V)');

        title(sprintf('Round %d - A%d', r, ch-1));

    end
end

sgtitle('Potentiometer Output Voltage vs Position');