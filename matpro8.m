
%% ADIM 12 - HIBRIT ALGORITMA OPTIMIZASYONU
clc;
clear;
close all;

%% 1 - TEMEL PARAMETRELER

N = 200;
R_fault = 0.075;

noise_levels = [0.002 0.005 0.010 0.020];

% Egitim ve bagimsiz test
train_trials = 30;
test_trials = 100;

% Sabit LS penceresi
ls_window = 7;

% Erken uyari parametreleri
trend_window = 15;
prediction_limit = 20;
min_slope = 0.0002;
early_confirmation = 5;

%% 2 - GRID SEARCH PARAMETRELERI

fast_windows = [2 3 4];
confirmations = [2 3 4];
margins = [0 0.002];

% Tum parametre kombinasyonlari
[A,B,C] = ndgrid( ...
    fast_windows,confirmations,margins);

configs = [A(:) B(:) C(:)];

num_configs = size(configs,1);

scores = zeros(num_configs,1);
train_metrics = zeros(num_configs,6);

fprintf('Toplam parametre kombinasyonu: %d\n', ...
    num_configs);

%% 3 - PARAMETRE OPTIMIZASYONU

for c = 1:num_configs

    cfg = configs(c,:);

    % Ayni egitim verileriyle adil karsilastirma
    stats = evaluateHybrid( ...
        cfg,train_trials,1001,N,R_fault, ...
        noise_levels,ls_window,trend_window, ...
        prediction_limit,min_slope, ...
        early_confirmation);

    train_metrics(c,:) = stats;

    % stats:
    % 1 = Yanlis alarm (%)
    % 2 = Erken kritik alarm (%)
    % 3 = Kacirilan kritik alarm (%)
    % 4 = Ortalama tespit gecikmesi
    % 5 = Yavas bozulma erken uyari (%)
    % 6 = Ortalama erken uyari avantaji

    % Dusuk skor daha iyi
    scores(c) = ...
        2*stats(1) + ...
        2*stats(2) + ...
        3*stats(3) + ...
        stats(4);

    fprintf('Test %2d/%2d | Skor: %.2f\n', ...
        c,num_configs,scores(c));
end

%% 4 - EN IYI PARAMETREYI SEC

[best_score,best_idx] = min(scores);

best_cfg = configs(best_idx,:);

fprintf('\n--- EN IYI PARAMETRELER ---\n');

fprintf('Hizli filtre: %d olcum\n',best_cfg(1));
fprintf('Kritik onay: %d olcum\n',best_cfg(2));
fprintf('LS toleransi: %.4f Ohm\n',best_cfg(3));
fprintf('Egitim skoru: %.2f\n',best_score);

%% 5 - BAGIMSIZ TEST

% Egitimde kullanilmayan rastgele veri
test_stats = evaluateHybrid( ...
    best_cfg,test_trials,9001,N,R_fault, ...
    noise_levels,ls_window,trend_window, ...
    prediction_limit,min_slope, ...
    early_confirmation);

fprintf('\n--- BAGIMSIZ TEST SONUCLARI ---\n');

fprintf('Yanlis alarm: %.2f %%\n',test_stats(1));
fprintf('Erken kritik alarm: %.2f %%\n',test_stats(2));
fprintf('Kacirilan kritik alarm: %.2f %%\n',test_stats(3));
fprintf('Ortalama tespit gecikmesi: %.2f olcum\n', ...
    test_stats(4));
fprintf('Yavas bozulma erken uyari: %.2f %%\n', ...
    test_stats(5));
fprintf('Ortalama erken uyari avantaji: %.2f olcum\n', ...
    test_stats(6));

%% 6 - SONUC TABLOSU

Results = table( ...
    (1:num_configs)',configs(:,1), ...
    configs(:,2),configs(:,3), ...
    train_metrics(:,1), ...
    train_metrics(:,2), ...
    train_metrics(:,3), ...
    train_metrics(:,4), ...
    scores, ...
    'VariableNames', ...
    {'ID','FastWindow','Confirmation', ...
    'Margin','FalseAlarmPct', ...
    'PrematurePct','MissPct', ...
    'MeanDelay','Score'});

Results = sortrows(Results,'Score');

disp('--- PARAMETRE SIRALAMASI ---');
disp(Results);

writetable(Results,'Optimizasyon_Sonuclari.csv');

%% 7 - OPTIMIZASYON GRAFIKLERI

figure('Name','Hibrit Parametre Optimizasyonu');

tiledlayout(2,2);

% Skorlar
nexttile;
bar(scores);
xlabel('Parametre Kombinasyonu');
ylabel('Maliyet Skoru');
title('Grid Search Sonuclari');
grid on;

% Yanlis alarm
nexttile;
bar(train_metrics(:,1));
xlabel('Parametre Kombinasyonu');
ylabel('Yanlis Alarm (%)');
title('Yanlis Alarm Karsilastirmasi');
grid on;

% Erken kritik alarm
nexttile;
bar(train_metrics(:,2));
xlabel('Parametre Kombinasyonu');
ylabel('Erken Kritik Alarm (%)');
title('Erken Kritik Alarm Analizi');
grid on;

% Tespit gecikmesi
nexttile;
bar(train_metrics(:,4));
xlabel('Parametre Kombinasyonu');
ylabel('Gecikme (Olcum)');
title('Kritik Tespit Gecikmesi');
grid on;

sgtitle('Hibrit Algoritma Parametre Optimizasyonu');

%% 8 - EN IYI PARAMETREYI KAYDET

BestParameters = table( ...
    best_cfg(1),best_cfg(2),best_cfg(3), ...
    best_score, ...
    'VariableNames', ...
    {'FastWindow','Confirmation','Margin','Score'});

writetable(BestParameters, ...
    'En_Iyi_Hibrit_Parametreler.csv');

disp(' ');
disp('Optimizasyon tamamlandi.');
disp('Sonuclar CSV dosyalarina kaydedildi.');

%% ADIM 13 - ONCE VE SONRA KARSILASTIRMASI

% Onceki hibrit parametreleri
old_cfg = [3 2 0];

% Optimize edilmis parametreler
new_cfg = best_cfg;

% Ayni bagimsiz test verileri
old_stats = evaluateHybrid( ...
    old_cfg,100,9001,N,R_fault, ...
    noise_levels,ls_window,trend_window, ...
    prediction_limit,min_slope, ...
    early_confirmation);

new_stats = evaluateHybrid( ...
    new_cfg,100,9001,N,R_fault, ...
    noise_levels,ls_window,trend_window, ...
    prediction_limit,min_slope, ...
    early_confirmation);

%% SONUC TABLOSU

Metric = [ ...
    "Yanlis Alarm (%)"; ...
    "Erken Kritik Alarm (%)"; ...
    "Kacirilan Ariza (%)"; ...
    "Tespit Gecikmesi (Olcum)"; ...
    "Erken Uyari (%)"; ...
    "Erken Uyari Avantaji (Olcum)"];

Comparison = table( ...
    Metric,old_stats',new_stats', ...
    'VariableNames', ...
    {'Metric','Onceki','Optimize'});

disp('--- ONCE VE SONRA KARSILASTIRMASI ---');
disp(Comparison);

writetable(Comparison, ...
    'Once_Sonra_Karsilastirma.csv');

%% GRAFIKLER

figure('Name','Optimizasyon Etkisi');

tiledlayout(1,2);

% Erken kritik alarm
nexttile;
bar([old_stats(2) new_stats(2)]);
xticklabels({'Onceki','Optimize'});
ylabel('Oran (%)');
title('Erken Kritik Alarm');
grid on;

% Tespit gecikmesi
nexttile;
bar([old_stats(4) new_stats(4)]);
xticklabels({'Onceki','Optimize'});
ylabel('Olcum Sayisi');
title('Ortalama Tespit Gecikmesi');
grid on;

sgtitle('Hibrit Algoritma - Optimizasyon Etkisi');

%% 9 - YEREL FONKSIYON

function stats = evaluateHybrid( ...
    cfg,trials,seed,N,R_fault,noise_levels, ...
    ls_window,trend_window,prediction_limit, ...
    min_slope,early_confirmation)

rng(seed);

fast_window = cfg(1);
fault_confirmation = cfg(2);
margin = cfg(3);

t = 1:N;

false_count = 0;
premature_count = 0;
miss_count = 0;
detect_count = 0;

early_count = 0;
lead_sum = 0;

delay_sum = 0;

healthy_total = 0;
fault_total = 0;
slow_total = 0;

xtrend = 1:trend_window;
weights = xtrend-mean(xtrend);
trend_den = sum(weights.^2);

for n = 1:trials

    for s = 1:4

        % Gercek direnc
        R = 0.03*ones(1,N);

        if s == 2

            start_idx = randi([80 110]);

            R(start_idx:end) = ...
                linspace(0.03,0.12,N-start_idx+1);

        elseif s == 3

            fault_start = randi([125 160]);
            R(fault_start:end) = 0.11;
        end

        % Akim
        phase = 2*pi*rand;

        if s == 4
            I = 2+1.2*sin(2*pi*t/20+phase);
        else
            I = 2+0.6*sin(2*pi*t/35+phase);
        end

        noise_sample = randn(1,N);

        true_idx = find(R>=R_fault,1,'first');

        for g = 1:numel(noise_levels)

            % Gerilim
            V = I.*R + ...
                noise_levels(g)*noise_sample;

            % Hizli direnc tahmini
            R_fast = movmean( ...
                V./I,[fast_window-1 0]);

            % LS direnc tahmini
            numerator = movsum( ...
                I.*V,[ls_window-1 0]);

            denominator = movsum( ...
                I.^2,[ls_window-1 0]);

            R_LS = numerator./denominator;

            % Hibrit kritik alarm adayi
            candidate = ...
                (R_fast >= R_fault) & ...
                (R_LS >= R_fault-margin);

            % Ardisik dogrulama
            fault = false(1,N);

            for k = fault_confirmation:N

                idx = k-fault_confirmation+1:k;

                fault(k) = all(candidate(idx));
            end

            % Ilk kritik alarm
            detect_idx = find(fault,1,'first');

            % Egilim tabanli erken uyari
            remaining = NaN(1,N);

            for k = trend_window:N

                idx = k-trend_window+1:k;

                slope = sum( ...
                    weights.*R_LS(idx))/trend_den;

                if slope > min_slope

                    remaining(k) = max(0, ...
                        (R_fault-R_LS(k))/slope);
                end
            end

            raw = remaining>0 & ...
                  remaining<=prediction_limit & ...
                  R_LS<R_fault;

            confirmed = false(1,N);

            for k = early_confirmation:N

                idx = k-early_confirmation+1:k;

                confirmed(k) = all(raw(idx));
            end

            if isempty(true_idx)

                healthy_total = healthy_total+1;

                if any(fault) || any(confirmed)
                    false_count = false_count+1;
                end

            else

                fault_total = fault_total+1;

                % Gercek esikten once kritik alarm
                if any(fault(1:true_idx-1))
                    premature_count = premature_count+1;
                end

                % Esikten sonraki tespit
                post_idx = find( ...
                    fault(true_idx:end),1,'first');

                if isempty(post_idx)

                    miss_count = miss_count+1;

                else

                    detect_count = detect_count+1;

                    delay_sum = delay_sum + post_idx-1;
                end

                % Yavas bozulmada erken uyari
                if s == 2

                    slow_total = slow_total+1;

                    early_idx = find( ...
                        confirmed(1:true_idx-1),1,'first');

                    if ~isempty(early_idx)

                        early_count = early_count+1;

                        lead_sum = lead_sum + ...
                            true_idx-early_idx;
                    end
                end
            end
        end
    end
end

% Yuzdelik metrikler
false_pct = 100*false_count/healthy_total;

premature_pct = ...
    100*premature_count/fault_total;

miss_pct = 100*miss_count/fault_total;

early_pct = 100*early_count/slow_total;

% Ortalama gecikme
if detect_count > 0
    mean_delay = delay_sum/detect_count;
else
    mean_delay = N;
end

% Ortalama erken uyari avantaji
if early_count > 0
    mean_lead = lead_sum/early_count;
else
    mean_lead = NaN;
end

stats = [false_pct,premature_pct,miss_pct, ...
         mean_delay,early_pct,mean_lead];

end
