
%% ADIM 11 - IYILESTIRILMIS HIBRIT KABLO ANALIZI
clc;
clear;
close all;
rng(42);

%% 1 - PARAMETRELER

N = 200;
trials = 100;
t = 1:N;

R_fault = 0.075;

noise_levels = [0.002 0.005 0.010 0.020];
noise_mV = noise_levels*1000;

names = {'Saglikli','Yavas Bozulma', ...
         'Ani Ariza','Akim Dalgalanmasi'};

methods = {'Klasik','Kayan LS','Hibrit'};

% Filtre parametreleri
slow_window = 7;
fast_window = 3;

% Erken uyari parametreleri
trend_window = 15;
prediction_limit = 20;
min_slope = 0.0002;
early_confirmation = 5;

% Kritik alarm parametreleri
fault_confirmation = 3;
hybrid_confirmation = 2;

% GUNCELLEME:
% LS dogrulama esigi kritik esige esit.
hybrid_margin = 0;

num_noise = numel(noise_levels);
num_methods = numel(methods);
num_scenario = numel(names);

%% 2 - SONUC DIZILERI

dims = [num_methods,num_noise,num_scenario,trials];

false_alarm = zeros(dims);
premature = zeros(dims);
detected = zeros(dims);
early_success = zeros(dims);

delay = NaN(dims);
lead = NaN(dims);
prediction_error = NaN(dims);
resistance_rmse = NaN(dims);

xtrend = 1:trend_window;
weights = xtrend-mean(xtrend);
trend_den = sum(weights.^2);

%% 3 - MONTE CARLO SIMULASYONU

for n = 1:trials

    for s = 1:num_scenario

        R = 0.03*ones(1,N);

        % Senaryo olusturma
        if s == 2

            start_idx = randi([80 110]);

            R(start_idx:end) = ...
                linspace(0.03,0.12,N-start_idx+1);

        elseif s == 3

            fault_start = randi([125 160]);
            R(fault_start:end) = 0.11;

        end

        % Akim modeli
        phase = 2*pi*rand;

        if s == 4
            I = 2+1.2*sin(2*pi*t/20+phase);
        else
            I = 2+0.6*sin(2*pi*t/35+phase);
        end

        % Ortak gurultu ornekleri
        noise_sample = randn(1,N);

        % Gercek kritik esik gecisi
        true_idx = find(R>=R_fault,1,'first');

        %% 4 - GURULTU TESTLERI

        for g = 1:num_noise

            noise_std = noise_levels(g);

            % Olculen gerilim
            V = I.*R + noise_std*noise_sample;

            %% 5 - DIRENC TAHMINLERI

            % Klasik yontem
            R_classic = movmean( ...
                V./I,[slow_window-1 0]);

            % Kayan en kucuk kareler
            numerator = movsum( ...
                I.*V,[slow_window-1 0]);

            denominator = movsum( ...
                I.^2,[slow_window-1 0]);

            R_LS = numerator./denominator;

            % Hizli filtre
            R_fast = movmean( ...
                V./I,[fast_window-1 0]);

            %% 6 - UC ALGORITMA

            for m = 1:num_methods

                if m == 1
                    R_est = R_classic;

                elseif m == 2
                    R_est = R_LS;

                else
                    R_est = R_LS;
                end

                % Direnc tahmin hatasi
                resistance_rmse(m,g,s,n) = ...
                    sqrt(mean((R_est-R).^2));

                %% 7 - KRITIK ALARM

                fault = false(1,N);

                if m < 3

                    fault_raw = R_est>=R_fault;

                    for k = fault_confirmation:N

                        idx = k-fault_confirmation+1:k;

                        fault(k) = all(fault_raw(idx));
                    end

                else

                    % IYILESTIRILMIS HIBRIT KARAR

                    % Hizli filtre kritik esigi gecmeli
                    fast_alarm = R_fast>=R_fault;

                    % LS de kritik esigi gecmeli
                    ls_support = ...
                        R_LS >= (R_fault-hybrid_margin);

                    % Iki yontem birlikte onaylamali
                    candidate = fast_alarm & ls_support;

                    % 2 ardisik onay
                    for k = hybrid_confirmation:N

                        idx = ...
                            k-hybrid_confirmation+1:k;

                        fault(k) = all(candidate(idx));
                    end

                    fault_raw = candidate;
                end

                detect_idx = find(fault,1,'first');

                %% 8 - EGILIM TAHMINI

                remaining = NaN(1,N);

                for k = trend_window:N

                    idx = k-trend_window+1:k;

                    slope = sum( ...
                        weights.*R_est(idx))/trend_den;

                    if slope > min_slope

                        remaining(k) = max(0, ...
                            (R_fault-R_est(k))/slope);
                    end
                end

                %% 9 - ERKEN UYARI

                raw = remaining>0 & ...
                      remaining<=prediction_limit & ...
                      R_est<R_fault;

                confirmed = false(1,N);

                for k = early_confirmation:N

                    idx = ...
                        k-early_confirmation+1:k;

                    confirmed(k) = all(raw(idx));
                end

                warning_idx = find(confirmed);

                %% 10 - PERFORMANS

                if isempty(true_idx)

                    false_alarm(m,g,s,n) = ...
                        any(confirmed) || any(fault);

                else

                    if ~isempty(detect_idx)

                        d = detect_idx-true_idx;

                        if d < 0
                            premature(m,g,s,n) = 1;
                        else
                            detected(m,g,s,n) = 1;
                            delay(m,g,s,n) = d;
                        end
                    end

                    pre = warning_idx( ...
                        warning_idx<true_idx);

                    if ~isempty(pre)

                        first_early = pre(1);

                        early_success(m,g,s,n) = 1;

                        lead(m,g,s,n) = ...
                            true_idx-first_early;

                        prediction_error(m,g,s,n) = ...
                            abs(remaining(first_early) ...
                            -lead(m,g,s,n));
                    end
                end
            end
        end
    end
end

%% 11 - PERFORMANS METRIKLERI

sz = [num_methods,num_noise,num_scenario];

FalseAlarmPct = NaN(sz);
PrematurePct = NaN(sz);
DetectionPct = NaN(sz);
EarlySuccessPct = NaN(sz);

MeanDelay = NaN(sz);
MeanLead = NaN(sz);
MeanError = NaN(sz);
MeanRMSE = NaN(sz);

for m = 1:num_methods

    for g = 1:num_noise

        for s = 1:num_scenario

            a = reshape(false_alarm(m,g,s,:),[],1);
            p = reshape(premature(m,g,s,:),[],1);
            d = reshape(detected(m,g,s,:),[],1);
            e = reshape(early_success(m,g,s,:),[],1);

            dl = reshape(delay(m,g,s,:),[],1);
            ld = reshape(lead(m,g,s,:),[],1);
            pe = reshape(prediction_error(m,g,s,:),[],1);
            re = reshape(resistance_rmse(m,g,s,:),[],1);

            MeanRMSE(m,g,s) = mean(re)*1000;

            if s==1 || s==4

                FalseAlarmPct(m,g,s) = 100*mean(a);

            else

                PrematurePct(m,g,s) = 100*mean(p);
                DetectionPct(m,g,s) = 100*mean(d);
                EarlySuccessPct(m,g,s) = 100*mean(e);

                MeanDelay(m,g,s) = ...
                    mean(dl,'omitnan');

                MeanLead(m,g,s) = ...
                    mean(ld,'omitnan');

                MeanError(m,g,s) = ...
                    mean(pe,'omitnan');

            end
        end
    end
end

%% 12 - SONUC TABLOSU

rows = num_methods*num_noise*num_scenario;

Method = strings(rows,1);
Noise_mV = zeros(rows,1);
Scenario = strings(rows,1);

FalseAlarm = NaN(rows,1);
PrematureAlarm = NaN(rows,1);
Detection = NaN(rows,1);
EarlyWarning = NaN(rows,1);
Delay = NaN(rows,1);
Lead = NaN(rows,1);
PredictionError = NaN(rows,1);
RMSE_mOhm = NaN(rows,1);

r = 0;

for m = 1:num_methods
    for g = 1:num_noise
        for s = 1:num_scenario

            r = r+1;

            Method(r) = string(methods{m});
            Noise_mV(r) = noise_mV(g);
            Scenario(r) = string(names{s});

            FalseAlarm(r) = FalseAlarmPct(m,g,s);
            PrematureAlarm(r) = PrematurePct(m,g,s);
            Detection(r) = DetectionPct(m,g,s);
            EarlyWarning(r) = EarlySuccessPct(m,g,s);

            Delay(r) = MeanDelay(m,g,s);
            Lead(r) = MeanLead(m,g,s);
            PredictionError(r) = MeanError(m,g,s);
            RMSE_mOhm(r) = MeanRMSE(m,g,s);
        end
    end
end

Results = table( ...
    Method,Noise_mV,Scenario, ...
    FalseAlarm,PrematureAlarm,Detection, ...
    EarlyWarning,Delay,Lead, ...
    PredictionError,RMSE_mOhm);

disp('--- IYILESTIRILMIS HIBRIT SONUCLARI ---');
disp(Results);

writetable(Results, ...
    'Iyilestirilmis_Hibrit_Sonuclari.csv');

%% 13 - GRAFIKLER

figure('Name','Iyilestirilmis Hibrit Karsilastirma');

tiledlayout(2,3);

% Grafik 1 - Yanlis alarm
nexttile;
plot(noise_mV, ...
    squeeze(FalseAlarmPct(:,:,4))', ...
    '-o','LineWidth',1.8);
title('Akim Dalgalanmasi - Yanlis Alarm');
ylabel('Oran (%)');
xlabel('Gurultu (mV)');
legend(methods,'Location','best');
grid on;

% Grafik 2 - Erken uyari
nexttile;
plot(noise_mV, ...
    squeeze(EarlySuccessPct(:,:,2))', ...
    '-o','LineWidth',1.8);
title('Yavas Bozulma - Erken Uyari');
ylabel('Basari (%)');
xlabel('Gurultu (mV)');
ylim([0 105]);
legend(methods,'Location','best');
grid on;

% Grafik 3 - Ani ariza gecikmesi
nexttile;
plot(noise_mV, ...
    squeeze(MeanDelay(:,:,3))', ...
    '-o','LineWidth',1.8);
title('Ani Ariza - Tespit Gecikmesi');
ylabel('Olcum');
xlabel('Gurultu (mV)');
legend(methods,'Location','best');
grid on;

% Grafik 4 - Erken kritik alarm
nexttile;
plot(noise_mV, ...
    squeeze(PrematurePct(:,:,2))', ...
    '-o','LineWidth',1.8);
title('Yavas Bozulma - Erken Kritik Alarm');
ylabel('Oran (%)');
xlabel('Gurultu (mV)');
legend(methods,'Location','best');
grid on;

% Grafik 5 - RMSE
nexttile;
plot(noise_mV, ...
    squeeze(MeanRMSE(:,:,2))', ...
    '-o','LineWidth',1.8);
title('Direnc Tahmin Hatasi');
ylabel('RMSE (mOhm)');
xlabel('Gurultu (mV)');
legend(methods,'Location','best');
grid on;

% Grafik 6 - Tahmin hatasi
nexttile;
plot(noise_mV, ...
    squeeze(MeanError(:,:,2))', ...
    '-o','LineWidth',1.8);
title('Erken Uyari Tahmin Hatasi');
ylabel('Hata (Olcum)');
xlabel('Gurultu (mV)');
legend(methods,'Location','best');
grid on;

sgtitle('Klasik - Kayan LS - Iyilestirilmis Hibrit');

%% 14 - 20 mV OZET

fprintf('\n--- 20 mV OZET KARSILASTIRMASI ---\n');

g = num_noise;

for m = 1:num_methods

    fprintf('\n%s\n',methods{m});

    fprintf('Yanlis alarm: %.1f %%\n', ...
        FalseAlarmPct(m,g,4));

    fprintf('Erken uyari basarisi: %.1f %%\n', ...
        EarlySuccessPct(m,g,2));

    fprintf('Erken kritik alarm: %.1f %%\n', ...
        PrematurePct(m,g,2));

    fprintf('Ani ariza gecikmesi: %.2f olcum\n', ...
        MeanDelay(m,g,3));

end

disp(' ');
disp('Simulasyon tamamlandi.');
disp('Toplam 4800 algoritma-senaryo degerlendirmesi.');
disp('Sonuclar CSV dosyasina kaydedildi.');
