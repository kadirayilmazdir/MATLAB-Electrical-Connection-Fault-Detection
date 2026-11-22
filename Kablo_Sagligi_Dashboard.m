
%% ADIM 15 - PROFESYONEL KABLO SAGLIGI DASHBOARD
clc;
clear;
close all;
rng(42);

%% 1 - DOSYALARI YUKLE

file1 = 'Optimizasyon_Sonuclari.csv';
file2 = 'Once_Sonra_Karsilastirma.csv';

if ~isfile(file1) || ~isfile(file2)
    error(['Gerekli CSV dosyalari bulunamadi. ' ...
        'Onceki optimizasyon klasorunu kontrol edin.']);
end

Opt = readtable(file1);
Comp = readtable(file2);

[~,best_idx] = min(Opt.Score);

fast_window = Opt.FastWindow(best_idx);
confirmation = Opt.Confirmation(best_idx);
margin = Opt.Margin(best_idx);

R_fault = 0.075;
R_warning = 0.045;
ls_window = 7;

%% 2 - ORNEK ELEKTRIKSEL SIMULASYON

N = 200;
t = 1:N;

R_true = 0.03*ones(1,N);
R_true(100:end) = linspace(0.03,0.12,101);

I = 2 + 0.6*sin(2*pi*t/35);

noise_std = 0.010;
V = I.*R_true + noise_std*randn(1,N);

% Hizli tahmin
R_fast = movmean( ...
    V./I,[fast_window-1 0]);

% Kayan LS tahmini
R_LS = movsum( ...
    I.*V,[ls_window-1 0]) ./ ...
    movsum(I.^2,[ls_window-1 0]);

%% 3 - HIBRIT KRITIK ALARM

candidate = ...
    (R_fast >= R_fault) & ...
    (R_LS >= R_fault-margin);

fault = false(1,N);

for k = confirmation:N

    idx = k-confirmation+1:k;
    fault(k) = all(candidate(idx));

end

fault_idx = find(fault,1,'first');
true_idx = find(R_true>=R_fault,1,'first');

%% 4 - ERKEN ARIZA TAHMINI

trend_window = 15;
prediction_limit = 20;
min_slope = 0.0002;
early_confirmation = 5;

remaining = NaN(1,N);

xtrend = 1:trend_window;
weights = xtrend-mean(xtrend);
den = sum(weights.^2);

for k = trend_window:N

    idx = k-trend_window+1:k;

    slope = sum(weights.*R_LS(idx))/den;

    if slope > min_slope

        remaining(k) = max(0, ...
            (R_fault-R_LS(k))/slope);

    end
end

raw_early = remaining>0 & ...
    remaining<=prediction_limit & ...
    R_LS<R_fault;

confirmed_early = false(1,N);

for k = early_confirmation:N

    idx = k-early_confirmation+1:k;

    confirmed_early(k) = all(raw_early(idx));

end

early_idx = find( ...
    confirmed_early(1:true_idx-1), ...
    1,'first');

%% 5 - BAGLANTI DURUMU

status = zeros(1,N);

status(R_LS>=R_warning) = 1;
status(fault) = 2;

%% 6 - RENK PALETI

bg = [0.08 0.10 0.14];
panel = [0.12 0.15 0.20];
fg = [0.94 0.96 0.98];
gridColor = [0.36 0.41 0.47];

blue = [0.25 0.65 1.00];
green = [0.25 0.85 0.55];
yellow = [1.00 0.72 0.28];
red = [1.00 0.37 0.40];

%% 7 - DASHBOARD PENCERESI

fig = figure( ...
    'Name','Smart Electrical Connection Dashboard', ...
    'Color',bg, ...
    'Position',[30 30 1600 950]);

layout = tiledlayout(3,2, ...
    'TileSpacing','loose', ...
    'Padding','compact');

title(layout, ...
    'SMART ELECTRICAL CONNECTION HEALTH MONITORING', ...
    'FontSize',18, ...
    'FontWeight','bold', ...
    'Color',fg);

%% GRAFIK 1 - TEMAS DIRENCI

ax1 = nexttile;

plot(t,R_true,'--', ...
    'Color',fg,'LineWidth',1.5);
hold on;

plot(t,R_LS, ...
    'Color',blue,'LineWidth',2);

yline(R_warning,':', ...
    'Color',yellow,'LineWidth',1.2);

yline(R_fault,':', ...
    'Color',red,'LineWidth',1.2);

title('Contact Resistance Estimation');
xlabel('Sample Number');
ylabel('Resistance (Ohm)');

legend('True Resistance','Estimated LS', ...
    'Location','northwest', ...
    'TextColor',fg, ...
    'Color',panel);

xlim([1 N]);
grid on;

%% GRAFIK 2 - ARIZA ZAMAN CIZELGESI

ax2 = nexttile;

stairs(t,status, ...
    'Color',blue,'LineWidth',2);
hold on;

if ~isempty(early_idx)
    xline(early_idx,'--', ...
        'Color',yellow,'LineWidth',1.6);
end

xline(true_idx,':', ...
    'Color',red,'LineWidth',1.6);

if ~isempty(fault_idx)
    xline(fault_idx,'--', ...
        'Color',green,'LineWidth',1.6);
end

title('Fault Detection Timeline');
xlabel('Sample Number');
ylabel('Connection Status');

yticks([0 1 2]);
yticklabels({'Normal','Warning','Critical'});

ylim([-0.2 2.4]);
xlim([1 N]);
grid on;

%% GRAFIK 3 - GRID SEARCH

ax3 = nexttile;

bar(Opt.ID,Opt.Score, ...
    'FaceColor',blue, ...
    'EdgeColor','none');
hold on;

plot(Opt.ID(best_idx), ...
    Opt.Score(best_idx),'p', ...
    'MarkerSize',14, ...
    'MarkerFaceColor',yellow, ...
    'MarkerEdgeColor',yellow);

title('Grid Search Optimization');
xlabel('Parameter Combination');
ylabel('Cost Score');
grid on;

%% GRAFIK 4 - ERKEN KRITIK ALARM

ax4 = nexttile;

b = bar([Comp.Onceki(2),Comp.Optimize(2)], ...
    'FaceColor','flat');

b.CData = [red;green];

xticks([1 2]);
xticklabels({'Baseline','Optimized'});

ylabel('Premature Alarm Rate (%)');
title('Premature Critical Alarm Comparison');
grid on;

%% GRAFIK 5 - TESPIT GECIKMESI

ax5 = nexttile;

b2 = bar([Comp.Onceki(4),Comp.Optimize(4)], ...
    'FaceColor','flat');

b2.CData = [yellow;blue];

xticks([1 2]);
xticklabels({'Baseline','Optimized'});

ylabel('Detection Delay (Samples)');
title('Detection Delay Comparison');
grid on;

%% GRAFIK 6 - PERFORMANS RAPORU

ax6 = nexttile;
axis off;

summary_text = sprintf([ ...
    'OPTIMIZED HYBRID SYSTEM\n\n' ...
    'Fast Filter: %d samples\n' ...
    'Confirmation: %d samples\n' ...
    'LS Margin: %.4f Ohm\n\n' ...
    'INDEPENDENT TEST RESULTS\n\n' ...
    'False Alarm: %.2f %%\n' ...
    'Premature Alarm: %.2f %%\n' ...
    'Missed Fault: %.2f %%\n' ...
    'Detection Delay: %.2f samples\n' ...
    'Early Warning Rate: %.2f %%\n' ...
    'Mean Warning Lead: %.2f samples\n\n' ...
    'Synthetic MATLAB Simulation'], ...
    fast_window,confirmation,margin, ...
    Comp.Optimize(1), ...
    Comp.Optimize(2), ...
    Comp.Optimize(3), ...
    Comp.Optimize(4), ...
    Comp.Optimize(5), ...
    Comp.Optimize(6));

text(0.05,0.95,summary_text, ...
    'Units','normalized', ...
    'VerticalAlignment','top', ...
    'FontSize',11, ...
    'FontName','Consolas', ...
    'Color',fg, ...
    'Interpreter','none');

title('System Performance Summary');

%% 8 - TUM GRAFIKLERI BICIMLENDIR

axesList = [ax1 ax2 ax3 ax4 ax5 ax6];

for k = 1:numel(axesList)

    ax = axesList(k);

    ax.Color = panel;
    ax.XColor = fg;
    ax.YColor = fg;

    ax.FontSize = 10;
    ax.LineWidth = 0.9;

    ax.GridColor = gridColor;
    ax.GridAlpha = 0.30;

    ax.Title.Color = fg;
    ax.XLabel.Color = fg;
    ax.YLabel.Color = fg;

end

% Ozet panelinde eksenler gorunmesin
axis(ax6,'off');

%% 9 - ZAMAN CIZELGESI ACIKLAMASI

% Grafik icinde ust uste binen etiketler yerine
% aciklamalari altta tek satirda gosteriyoruz.

timelineInfo = "Early Prediction: ";

if ~isempty(early_idx)
    timelineInfo = timelineInfo + string(early_idx);
else
    timelineInfo = timelineInfo + "None";
end

timelineInfo = timelineInfo + ...
    " | True Crossing: " + string(true_idx);

if ~isempty(fault_idx)
    timelineInfo = timelineInfo + ...
        " | Critical Detection: " + string(fault_idx);
else
    timelineInfo = timelineInfo + ...
        " | Critical Detection: None";
end

subtitle(ax2,timelineInfo, ...
    'FontSize',9, ...
    'Color',fg);

%% 10 - GRAFIKLERI KAYDET

output_folder = 'Dashboard_Results';

if ~exist(output_folder,'dir')
    mkdir(output_folder);
end

drawnow;

exportgraphics(fig, ...
    fullfile(output_folder, ...
    'Electrical_Connection_Dashboard.png'), ...
    'Resolution',300);

exportgraphics(fig, ...
    fullfile(output_folder, ...
    'Electrical_Connection_Dashboard.pdf'), ...
    'ContentType','vector');

%% 11 - KONSOL RAPORU

fprintf('\n--- DASHBOARD RAPORU ---\n');

fprintf('Hizli filtre: %d ornek\n',fast_window);
fprintf('Kritik onay: %d ornek\n',confirmation);
fprintf('LS toleransi: %.4f Ohm\n',margin);

if ~isempty(early_idx)
    fprintf('Erken uyari: %d\n',early_idx);
else
    fprintf('Erken uyari: Yok\n');
end

fprintf('Gercek kritik gecis: %d\n',true_idx);

if ~isempty(fault_idx)
    fprintf('Kritik tespit: %d\n',fault_idx);
else
    fprintf('Kritik tespit: Yok\n');
end

disp(' ');
disp('Dashboard basariyla olusturuldu.');
disp('PNG ve PDF dosyalari kaydedildi.');

