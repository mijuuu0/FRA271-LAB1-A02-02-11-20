folder=fileparts(mfilename('fullpath'));
R1 = load(fullfile(folder,'Result_Round1.mat'));
R2 = load(fullfile(folder,'Result_Round2.mat'));
R3 = load(fullfile(folder,'Result_Round3.mat'));

V_mean = (R1.voltage + R2.voltage + R3.voltage) / 3;

figure;

for ch = 1:5

    subplot(1,5,ch)

    plot(R1.position, V_mean(ch,:), 'o-')

    grid on
    ylim([0 3.3])
    xlim([0 100])

    title(sprintf('A%d',ch-1))
    xlabel('Position (%)')
    ylabel('Voltage (V)')

end