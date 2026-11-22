
%% ADIM 7 - Monte Carlo Guvenilirlik Testi
clc;
clear;
close all;
rng(42);

N = 200;
trials = 100;
t = 1:N;

R_fault = 0.075;
window = 15;
limit = 20;
min_slope = 0.0002;

names = {'Saglikli','Yavas Bozulma', ...
         'Ani Ariza','Akim Dalgalanmasi'};

% Her senaryo icin sonuc dizileri
early_success = zeros(4,trials);
false_alarm = zeros(4,trials);
detected = zeros(4,trials);
delay = NaN(4,trials);
lead = NaN(4,trials);

for s = 1:4
    for n = 1:trials

        R = 0.03*ones(1,N);

        % Senaryo olustur
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

        % Gurultulu gerilim olcumu
        noise_std = 0.010; % 10 mV
        V = I.*R + noise_std*randn(1,N);

        % Nedensel filtre
        R_est = movmean(V./I,[4 0]);

        % Kritik esik
        fault = R_est >= R_fault;

        true_idx = find(R>=R_fault,1,'first');
        detect_idx = find(fault,1,'first');

        % Egilim tabanli tahmin
        remaining = NaN(1,N);

        for k = window:N
            idx = k-window+1:k;
            p = polyfit(t(idx),R_est(idx),1);

            if p(1)>min_slope
                remaining(k) = max(0, ...
                    (R_fault-R_est(k))/p(1));
            end
        end

        raw = remaining>0 & ...
              remaining<=limit & ~fault;

        confirmed = false(1,N);

        for k = 3:N
            confirmed(k) = all(raw(k-2:k));
        end

        warning_idx = find(confirmed);

        % Gercek kritik durum yoksa
        if isempty(true_idx)
            false_alarm(s,n) = ...
                any(confirmed) || any(fault);
        else
            % Kritik tespit
            if ~isempty(detect_idx)
                detected(s,n) = 1;
                delay(s,n) = ...
                    detect_idx-true_idx;
            end

            % Gercek esikten onceki ilk uyari
            pre = warning_idx(warning_idx<true_idx);

            if ~isempty(pre)
                early_success(s,n) = 1;
                lead(s,n) = true_idx-pre(1);
            end
        end
    end
end

% Sonuc tablosu
FalseAlarmPct = 100*mean(false_alarm,2);
EarlySuccessPct = 100*mean(early_success,2);
DetectionPct = 100*mean(detected,2);
MeanDelay = mean(delay,2,'omitnan');
MeanLead = mean(lead,2,'omitnan');

Results = table(names',FalseAlarmPct, ...
    EarlySuccessPct,DetectionPct, ...
    MeanDelay,MeanLead, ...
    'VariableNames', ...
    {'Scenario','FalseAlarmPct', ...
     'EarlySuccessPct','DetectionPct', ...
     'MeanDelay','MeanLead'});

disp('--- MONTE CARLO TEST SONUCLARI ---');
disp(Results);

% Grafik
figure('Name','Monte Carlo Test Sonuclari');

bar([FalseAlarmPct,EarlySuccessPct,DetectionPct]);

xticks(1:4);
xticklabels(names);
ylabel('Oran (%)');
legend('Yanlis Alarm','Erken Uyari', ...
       'Kritik Tespit','Location','best');
title('100 Tekrarli Senaryo Testi');
ylim([0 110]);
grid on;
