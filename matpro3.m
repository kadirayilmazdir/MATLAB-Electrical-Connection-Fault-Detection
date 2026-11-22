
%% ADIM 8 - Coklu Gurultu Monte Carlo Testi
clc;
clear;
close all;
rng(42);

%% 1. PARAMETRELER
N = 200;
trials = 100;
t = 1:N;

R_fault = 0.075;
window = 15;
limit = 20;
min_slope = 0.0002;

% Gurultu seviyeleri (Volt)
noise_levels = [0.002 0.005 0.010 0.020];
noise_mV = noise_levels*1000;

names = {'Saglikli','Yavas Bozulma', ...
         'Ani Ariza','Akim Dalgalanmasi'};

num_noise = length(noise_levels);
num_scenario = 4;

%% 2. SONUC DIZILERI
% Boyut: Gurultu x Senaryo x Tekrar
early_success = zeros(num_noise,4,trials);
false_alarm = zeros(num_noise,4,trials);
detected = zeros(num_noise,4,trials);

delay = NaN(num_noise,4,trials);
lead = NaN(num_noise,4,trials);
prediction_error = NaN(num_noise,4,trials);

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

        % Ayni denemede ayni standart
        % gurultu orneklerini kullan
        noise_sample = randn(1,N);

        true_idx = find(R>=R_fault,1,'first');

        %% 4. FARKLI GURULTU SEVIYELERI
        for g = 1:num_noise

            noise_std = noise_levels(g);

            % Gurultulu gerilim olcumu
            V = I.*R + noise_std*noise_sample;

            % Nedensel filtre
            R_est = movmean(V./I,[4 0]);

            % Kritik esik
            fault = R_est >= R_fault;

            detect_idx = find(fault,1,'first');

            %% 5. ERKEN ARIZA TAHMINI
            remaining = NaN(1,N);

            for k = window:N

                idx = k-window+1:k;

                p = polyfit(t(idx),R_est(idx),1);

                if p(1)>min_slope
                    remaining(k) = max(0, ...
                        (R_fault-R_est(k))/p(1));
                end

            end

            % Erken uyari kosulu
            raw = remaining>0 & ...
                  remaining<=limit & ~fault;

            % 3 ardisik olcum dogrulamasi
            confirmed = false(1,N);

            for k = 3:N
                confirmed(k) = all(raw(k-2:k));
            end

            warning_idx = find(confirmed);

            %% 6. PERFORMANS KONTROLU

            if isempty(true_idx)

                % Gercekte kritik ariza yok
                false_alarm(g,s,n) = ...
                    any(confirmed) || any(fault);

            else

                % Kritik ariza tespiti
                if ~isempty(detect_idx)

                    detected(g,s,n) = 1;

                    delay(g,s,n) = ...
                        detect_idx-true_idx;
                end

                % Gercek esikten onceki uyarilar
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

%% 7. SONUCLARI HESAPLA

FalseAlarmPct = zeros(num_noise,4);
EarlySuccessPct = zeros(num_noise,4);
DetectionPct = zeros(num_noise,4);

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

        d = reshape(delay(g,s,:),[],1);
        l = reshape(lead(g,s,:),[],1);
        e = reshape(prediction_error(g,s,:),[],1);

        MeanDelay(g,s) = mean(d,'omitnan');
        MeanLead(g,s) = mean(l,'omitnan');

        MeanPredictionError(g,s) = ...
            mean(e,'omitnan');
    end
end

%% 8. SONUC TABLOSU

Noise_mV = repelem(noise_mV',4);
Scenario = repmat(names',num_noise,1);

Results = table( ...
    Noise_mV,Scenario, ...
    reshape(FalseAlarmPct',[],1), ...
    reshape(EarlySuccessPct',[],1), ...
    reshape(DetectionPct',[],1), ...
    reshape(MeanDelay',[],1), ...
    reshape(MeanLead',[],1), ...
    reshape(MeanPredictionError',[],1), ...
    'VariableNames', ...
    {'Noise_mV','Scenario', ...
     'FalseAlarmPct','EarlySuccessPct', ...
     'DetectionPct','MeanDelay', ...
     'MeanLead','MeanPredictionError'});

disp('--- COKLU GURULTU TEST SONUCLARI ---');
disp(Results);

% CSV dosyasina kaydet
writetable(Results,'MonteCarlo_Sonuclari.csv');

%% 9. GRAFIK 1 - ERKEN UYARI BASARISI

figure('Name','Gurultu ve Erken Uyari');

plot(noise_mV,EarlySuccessPct(:,2), ...
    '-o','LineWidth',2,'MarkerSize',7);

xlabel('Gurultu Standart Sapmasi (mV)');
ylabel('Erken Uyari Basarisi (%)');
title('Yavas Bozulmada Erken Uyari Basarisi');
ylim([0 105]);
xticks(noise_mV);
grid on;

%% 10. GRAFIK 2 - TESPIT GECIKMESI

figure('Name','Gurultu ve Tespit Gecikmesi');

plot(noise_mV,MeanDelay(:,2), ...
    '-o','LineWidth',2);
hold on;

plot(noise_mV,MeanDelay(:,3), ...
    '-s','LineWidth',2);

xlabel('Gurultu Standart Sapmasi (mV)');
ylabel('Ortalama Gecikme (Olcum)');
title('Gurultunun Kritik Tespit Gecikmesine Etkisi');

legend('Yavas Bozulma','Ani Ariza', ...
       'Location','best');

xticks(noise_mV);
grid on;

%% 11. GRAFIK 3 - YANLIS ALARM

figure('Name','Gurultu ve Yanlis Alarm');

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

%% 12. GRAFIK 4 - TAHMIN HATASI

figure('Name','Gurultu ve Tahmin Hatasi');

plot(noise_mV,MeanPredictionError(:,2), ...
    '-o','LineWidth',2);

xlabel('Gurultu Standart Sapmasi (mV)');
ylabel('Ortalama Mutlak Hata (Olcum)');
title('Yavas Bozulmada Tahmin Hatasi');

xticks(noise_mV);
grid on;

disp('Simulasyon tamamlandi.');
disp('Sonuclar MonteCarlo_Sonuclari.csv dosyasina kaydedildi.');

