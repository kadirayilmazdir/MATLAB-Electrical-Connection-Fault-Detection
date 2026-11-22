
%% ADIM 9 - IYILESTIRILMIS KABLO SAGLIGI ANALIZI
clc;
clear;
close all;
rng(42);

%% 1. PARAMETRELER

N = 200;
trials = 100;
t = 1:N;

R_fault = 0.075;

% Iyilestirilmis algoritma parametreleri
filter_window = 7;
trend_window = 15;
prediction_limit = 20;
min_slope = 0.0002;

early_confirmation = 5;
fault_confirmation = 3;

% Gurultu seviyeleri (Volt)
noise_levels = [0.002 0.005 0.010 0.020];
noise_mV = noise_levels*1000;

names = {'Saglikli','Yavas Bozulma', ...
         'Ani Ariza','Akim Dalgalanmasi'};

num_noise = length(noise_levels);
num_scenario = 4;

%% 2. SONUC DIZILERI

early_success = zeros(num_noise,4,trials);
false_alarm = zeros(num_noise,4,trials);
detected = zeros(num_noise,4,trials);

delay = NaN(num_noise,4,trials);
lead = NaN(num_noise,4,trials);
prediction_error = NaN(num_noise,4,trials);

% Gercek esikten once kritik alarm
premature_fault = zeros(num_noise,4,trials);

%% 3. MONTE CARLO SIMULASYONU

for n = 1:trials

    for s = 1:num_scenario

        % Gercek temas direnci
        R = 0.03*ones(1,N);

        if s == 2
            start_idx = randi([80 110]);

            R(start_idx:end) = ...
                linspace(0.03,0.12,N-start_idx+1);

        elseif s == 3
            fault_start = randi([125 160]);
            R(fault_start:end) = 0.11;
        end

        % Akim simulasyonu
        phase = 2*pi*rand;

        if s == 4
            I = 2+1.2*sin(2*pi*t/20+phase);
        else
            I = 2+0.6*sin(2*pi*t/35+phase);
        end

        % Ayni denemede ortak gurultu ornekleri
        noise_sample = randn(1,N);

        % Gercek kritik esik gecisi
        true_idx = find(R>=R_fault,1,'first');

        %% 4. FARKLI GURULTU SEVIYELERI

        for g = 1:num_noise

            noise_std = noise_levels(g);

            % Gurultulu gerilim olcumu
            V = I.*R + noise_std*noise_sample;

            % 7 ornekli nedensel filtre
            R_est = movmean( ...
                V./I,[filter_window-1 0]);

            %% 5. KRITIK ARIZA DOGRULAMA

            fault_raw = R_est >= R_fault;
            fault = false(1,N);

            for k = fault_confirmation:N

                idx = k-fault_confirmation+1:k;

                fault(k) = all(fault_raw(idx));
            end

            detect_idx = find(fault,1,'first');

            %% 6. EGILIM TABANLI TAHMIN

            remaining = NaN(1,N);

            for k = trend_window:N

                idx = k-trend_window+1:k;

                p = polyfit(t(idx),R_est(idx),1);

                if p(1)>min_slope

                    remaining(k) = max(0, ...
                        (R_fault-R_est(k))/p(1));
                end
            end

            %% 7. ERKEN UYARI DOGRULAMA

            raw = remaining>0 & ...
                  remaining<=prediction_limit & ...
                  ~fault_raw;

            confirmed = false(1,N);

            for k = early_confirmation:N

                idx = k-early_confirmation+1:k;

                confirmed(k) = all(raw(idx));
            end

            warning_idx = find(confirmed);

            %% 8. PERFORMANS DEGERLENDIRMESI

            if isempty(true_idx)

                % Gercekte ariza olmayan senaryolar
                false_alarm(g,s,n) = ...
                    any(confirmed) || any(fault);

            else

                % Kritik tespit
                if ~isempty(detect_idx)

                    delay_value = detect_idx-true_idx;

                    if delay_value < 0

                        % Gercek esikten once kritik alarm
                        premature_fault(g,s,n) = 1;

                    else

                        % Gecerli kritik tespit
                        detected(g,s,n) = 1;
                        delay(g,s,n) = delay_value;

                    end
                end

                % Gercek kritik esikten onceki uyari
                pre = warning_idx(warning_idx<true_idx);

                if ~isempty(pre)

                    first_early = pre(1);

                    early_success(g,s,n) = 1;

                    lead(g,s,n) = ...
                        true_idx-first_early;

                    prediction_error(g,s,n) = abs( ...
                        remaining(first_early) - ...
                        lead(g,s,n));
                end
            end
        end
    end
end

%% 9. SONUC METRIKLERI

FalseAlarmPct = zeros(num_noise,4);
EarlySuccessPct = zeros(num_noise,4);
DetectionPct = zeros(num_noise,4);
PrematureFaultPct = zeros(num_noise,4);

MeanDelay = NaN(num_noise,4);
MeanLead = NaN(num_noise,4);
MeanPredictionError = NaN(num_noise,4);

for g = 1:num_noise

    for s = 1:4

        FalseAlarmPct(g,s) = ...
            100*mean(false_alarm(g,s,:),'all');

        EarlySuccessPct(g,s) = ...
            100*mean(early_success(g,s,:),'all');

        DetectionPct(g,s) = ...
            100*mean(detected(g,s,:),'all');

        PrematureFaultPct(g,s) = ...
            100*mean(premature_fault(g,s,:),'all');

        d = reshape(delay(g,s,:),[],1);
        l = reshape(lead(g,s,:),[],1);
        e = reshape(prediction_error(g,s,:),[],1);

        MeanDelay(g,s) = mean(d,'omitnan');
        MeanLead(g,s) = mean(l,'omitnan');

        MeanPredictionError(g,s) = ...
            mean(e,'omitnan');
    end
end

%% 10. SONUC TABLOSU

Noise_mV = repelem(noise_mV',4);
Scenario = repmat(names',num_noise,1);

Results = table( ...
    Noise_mV,Scenario, ...
    reshape(FalseAlarmPct',[],1), ...
    reshape(EarlySuccessPct',[],1), ...
    reshape(DetectionPct',[],1), ...
    reshape(PrematureFaultPct',[],1), ...
    reshape(MeanDelay',[],1), ...
    reshape(MeanLead',[],1), ...
    reshape(MeanPredictionError',[],1), ...
    'VariableNames', ...
    {'Noise_mV','Scenario', ...
     'FalseAlarmPct','EarlySuccessPct', ...
     'DetectionPct','PrematureFaultPct', ...
     'MeanDelay','MeanLead', ...
     'MeanPredictionError'});

disp('--- IYILESTIRILMIS ALGORITMA SONUCLARI ---');
disp(Results);

% CSV olarak kaydet
writetable(Results, ...
    'Iyilestirilmis_MonteCarlo_Sonuclari.csv');

%% 11. GRAFIK 1 - ERKEN UYARI

figure('Name','Erken Uyari Performansi');

plot(noise_mV,EarlySuccessPct(:,2), ...
    '-o','LineWidth',2,'MarkerSize',7);

xlabel('Gurultu Standart Sapmasi (mV)');
ylabel('Erken Uyari Basarisi (%)');
title('Yavas Bozulmada Erken Uyari');

xticks(noise_mV);
ylim([0 105]);
grid on;

%% 12. GRAFIK 2 - KRITIK TESPIT GECIKMESI

figure('Name','Kritik Tespit Gecikmesi');

plot(noise_mV,MeanDelay(:,2), ...
    '-o','LineWidth',2);
hold on;

plot(noise_mV,MeanDelay(:,3), ...
    '-s','LineWidth',2);

xlabel('Gurultu Standart Sapmasi (mV)');
ylabel('Ortalama Gecikme (Olcum)');
title('Gurultunun Tespit Gecikmesine Etkisi');

legend('Yavas Bozulma','Ani Ariza', ...
       'Location','best');

xticks(noise_mV);
grid on;

%% 13. GRAFIK 3 - YANLIS ALARM

figure('Name','Yanlis Alarm Analizi');

plot(noise_mV,FalseAlarmPct(:,1), ...
    '-o','LineWidth',2);
hold on;

plot(noise_mV,FalseAlarmPct(:,4), ...
    '-s','LineWidth',2);

xlabel('Gurultu Standart Sapmasi (mV)');
ylabel('Yanlis Alarm Orani (%)');
title('Saglikli Kosullarda Yanlis Alarm');

legend('Saglikli Kablo','Akim Dalgalanmasi', ...
       'Location','best');

xticks(noise_mV);
ylim([0 105]);
grid on;

%% 14. GRAFIK 4 - TAHMIN HATASI

figure('Name','Tahmin Hatasi');

plot(noise_mV,MeanPredictionError(:,2), ...
    '-o','LineWidth',2);

xlabel('Gurultu Standart Sapmasi (mV)');
ylabel('Ortalama Mutlak Hata (Olcum)');
title('Yavas Bozulmada Tahmin Hatasi');

xticks(noise_mV);
grid on;

%% 15. GRAFIK 5 - ERKEN KRITIK ALARM

figure('Name','Erken Kritik Alarm');

bar(noise_mV,PrematureFaultPct(:,2:3), ...
    'grouped');

xlabel('Gurultu Standart Sapmasi (mV)');
ylabel('Erken Kritik Alarm Orani (%)');
title('Gercek Esikten Once Kritik Alarm');

legend('Yavas Bozulma','Ani Ariza', ...
       'Location','best');

xticks(noise_mV);
ylim([0 105]);
grid on;

%% 16. TAMAMLANDI

disp(' ');
disp('Simulasyon tamamlandi.');
disp('Toplam 1600 senaryo denemesi yapildi.');
disp('Sonuclar CSV dosyasina kaydedildi.');
