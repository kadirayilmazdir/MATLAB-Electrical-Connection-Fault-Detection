
%% ADIM 10 - KLASIK VE LS ALGORITMA KARSILASTIRMASI
clc;
clear;
close all;
rng(42);

%% 1. PARAMETRELER

N = 200;
trials = 100;
t = 1:N;

R_fault = 0.075;

filter_window = 7;
trend_window = 15;
prediction_limit = 20;
min_slope = 0.0002;

early_confirmation = 5;
fault_confirmation = 3;

noise_levels = [0.002 0.005 0.010 0.020];
noise_mV = noise_levels*1000;

names = ["Saglikli","Yavas Bozulma", ...
         "Ani Ariza","Akim Dalgalanmasi"];

methods = ["Klasik","Kayan LS"];

num_noise = numel(noise_levels);

%% 2. SONUC DIZILERI
% Boyutlar: Yontem x Gurultu x Senaryo x Tekrar

dims = [2,num_noise,4,trials];

false_alarm = zeros(dims);
premature = zeros(dims);
detected = zeros(dims);
early_success = zeros(dims);

delay = NaN(dims);
lead = NaN(dims);
prediction_error = NaN(dims);
resistance_rmse = NaN(dims);

% Egilim hesaplamasi icin sabit agirliklar
xtrend = 1:trend_window;
trend_weights = xtrend-mean(xtrend);
trend_den = sum(trend_weights.^2);

%% 3. MONTE CARLO TESTI

for n = 1:trials

    for s = 1:4

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

        % Akim modeli
        phase = 2*pi*rand;

        if s == 4
            I = 2+1.2*sin(2*pi*t/20+phase);
        else
            I = 2+0.6*sin(2*pi*t/35+phase);
        end

        % Tum yontemlerde ortak gurultu ornekleri
        noise_sample = randn(1,N);

        % Gercek kritik esik gecisi
        true_idx = find(R>=R_fault,1,'first');

        for g = 1:num_noise

            noise_std = noise_levels(g);

            % Simule edilmis gerilim olcumu
            V = I.*R + noise_std*noise_sample;

            %% 4. IKI FARKLI DIRENC TAHMINI

            % Yontem 1: Klasik V/I + hareketli ortalama
            R_classic = movmean( ...
                V./I,[filter_window-1 0]);

            % Yontem 2: Kayan pencere LS
            numerator = movsum( ...
                I.*V,[filter_window-1 0]);

            denominator = movsum( ...
                I.^2,[filter_window-1 0]);

            R_LS = numerator./denominator;

            % Iki yontemi sirayla test et
            for m = 1:2

                if m == 1
                    R_est = R_classic;
                else
                    R_est = R_LS;
                end

                %% 5. DIRENC TAHMIN HATASI

                resistance_rmse(m,g,s,n) = ...
                    sqrt(mean((R_est-R).^2));

                %% 6. KRITIK ARIZA DOGRULAMA

                fault_raw = R_est >= R_fault;
                fault = false(1,N);

                for k = fault_confirmation:N

                    idx = k-fault_confirmation+1:k;
                    fault(k) = all(fault_raw(idx));

                end

                detect_idx = find(fault,1,'first');

                %% 7. EGILIM TABANLI ERKEN TAHMIN

                remaining = NaN(1,N);

                for k = trend_window:N

                    idx = k-trend_window+1:k;

                    % Dogrusal egim hesabi
                    slope = sum( ...
                        trend_weights.*R_est(idx)) ...
                        /trend_den;

                    if slope > min_slope

                        remaining(k) = max(0, ...
                            (R_fault-R_est(k))/slope);

                    end
                end

                %% 8. ERKEN UYARI DOGRULAMA

                raw = remaining>0 & ...
                      remaining<=prediction_limit & ...
                      ~fault_raw;

                confirmed = false(1,N);

                for k = early_confirmation:N

                    idx = k-early_confirmation+1:k;

                    confirmed(k) = all(raw(idx));

                end

                %% 9. PERFORMANS DEGERLENDIRME

                if isempty(true_idx)

                    % Gercekte kritik ariza yok
                    false_alarm(m,g,s,n) = ...
                        any(confirmed) || any(fault);

                else

                    % Ilk kritik alarm
                    if ~isempty(detect_idx)

                        d = detect_idx-true_idx;

                        if d < 0

                            % Gercek esikten once kritik alarm
                            premature(m,g,s,n) = 1;

                        else

                            detected(m,g,s,n) = 1;
                            delay(m,g,s,n) = d;

                        end
                    end

                    % Gercek esikten once erken uyari
                    warning_idx = find(confirmed);

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

%% 10. ORTALAMA PERFORMANS DEGERLERI

FalseAlarmPct = NaN(2,num_noise,4);
PrematurePct = NaN(2,num_noise,4);
DetectionPct = NaN(2,num_noise,4);
EarlySuccessPct = NaN(2,num_noise,4);

MeanDelay = NaN(2,num_noise,4);
MeanLead = NaN(2,num_noise,4);
MeanPredictionError = NaN(2,num_noise,4);
MeanRMSE = NaN(2,num_noise,4);

for m = 1:2
    for g = 1:num_noise
        for s = 1:4

            a = reshape(false_alarm(m,g,s,:),[],1);
            p = reshape(premature(m,g,s,:),[],1);
            d = reshape(detected(m,g,s,:),[],1);
            e = reshape(early_success(m,g,s,:),[],1);

            dl = reshape(delay(m,g,s,:),[],1);
            ld = reshape(lead(m,g,s,:),[],1);

            pe = reshape( ...
                prediction_error(m,g,s,:),[],1);

            re = reshape( ...
                resistance_rmse(m,g,s,:),[],1);

            MeanRMSE(m,g,s) = mean(re);

            if s == 1 || s == 4

                FalseAlarmPct(m,g,s) = 100*mean(a);

            else

                PrematurePct(m,g,s) = 100*mean(p);
                DetectionPct(m,g,s) = 100*mean(d);
                EarlySuccessPct(m,g,s) = 100*mean(e);

                MeanDelay(m,g,s) = mean(dl,'omitnan');
                MeanLead(m,g,s) = mean(ld,'omitnan');

                MeanPredictionError(m,g,s) = ...
                    mean(pe,'omitnan');

            end
        end
    end
end

%% 11. SONUC TABLOSU

rows = 2*num_noise*4;

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

for m = 1:2
    for g = 1:num_noise
        for s = 1:4

            r = r+1;

            Method(r) = methods(m);
            Noise_mV(r) = noise_mV(g);
            Scenario(r) = names(s);

            FalseAlarm(r) = FalseAlarmPct(m,g,s);
            PrematureAlarm(r) = PrematurePct(m,g,s);
            Detection(r) = DetectionPct(m,g,s);
            EarlyWarning(r) = EarlySuccessPct(m,g,s);

            Delay(r) = MeanDelay(m,g,s);
            Lead(r) = MeanLead(m,g,s);

            PredictionError(r) = ...
                MeanPredictionError(m,g,s);

            RMSE_mOhm(r) = MeanRMSE(m,g,s)*1000;

        end
    end
end

Results = table( ...
    Method,Noise_mV,Scenario, ...
    FalseAlarm,PrematureAlarm, ...
    Detection,EarlyWarning, ...
    Delay,Lead,PredictionError,RMSE_mOhm);

disp('--- ALGORITMA KARSILASTIRMA SONUCLARI ---');
disp(Results);

writetable(Results, ...
    'Algoritma_Karsilastirma.csv');

%% 12. GRAFIKLER

figure('Name','Algoritma Performans Karsilastirmasi');

tiledlayout(2,2);

% Grafik 1 - Direnc tahmin hatasi
nexttile;

plot(noise_mV,MeanRMSE(1,:,2)*1000, ...
    '-o','LineWidth',2);
hold on;

plot(noise_mV,MeanRMSE(2,:,2)*1000, ...
    '-s','LineWidth',2);

title('Direnc Tahmin Hatasi');
xlabel('Gurultu (mV)');
ylabel('RMSE (mOhm)');
legend('Klasik','Kayan LS','Location','best');
grid on;

% Grafik 2 - Erken uyari
nexttile;

plot(noise_mV,EarlySuccessPct(1,:,2), ...
    '-o','LineWidth',2);
hold on;

plot(noise_mV,EarlySuccessPct(2,:,2), ...
    '-s','LineWidth',2);

title('Yavas Bozulmada Erken Uyari');
xlabel('Gurultu (mV)');
ylabel('Basari (%)');
legend('Klasik','Kayan LS','Location','best');
ylim([0 105]);
grid on;

% Grafik 3 - Yanlis alarm
nexttile;

plot(noise_mV,FalseAlarmPct(1,:,4), ...
    '-o','LineWidth',2);
hold on;

plot(noise_mV,FalseAlarmPct(2,:,4), ...
    '-s','LineWidth',2);

title('Akim Dalgalanmasinda Yanlis Alarm');
xlabel('Gurultu (mV)');
ylabel('Yanlis Alarm (%)');
legend('Klasik','Kayan LS','Location','best');
ylim([0 105]);
grid on;

% Grafik 4 - Ani ariza gecikmesi
nexttile;

plot(noise_mV,MeanDelay(1,:,3), ...
    '-o','LineWidth',2);
hold on;

plot(noise_mV,MeanDelay(2,:,3), ...
    '-s','LineWidth',2);

title('Ani Ariza Tespit Gecikmesi');
xlabel('Gurultu (mV)');
ylabel('Gecikme (Olcum)');
legend('Klasik','Kayan LS','Location','best');
grid on;

sgtitle('Klasik ve Kayan LS Algoritma Karsilastirmasi');

%% 13. EK GRAFIK - ERKEN KRITIK ALARM

figure('Name','Erken Kritik Alarm Karsilastirmasi');

plot(noise_mV,PrematurePct(1,:,2), ...
    '-o','LineWidth',2);
hold on;

plot(noise_mV,PrematurePct(2,:,2), ...
    '-s','LineWidth',2);

title('Yavas Bozulmada Erken Kritik Alarm');
xlabel('Gurultu (mV)');
ylabel('Erken Kritik Alarm (%)');
legend('Klasik','Kayan LS','Location','best');
ylim([0 105]);
grid on;

%% 14. TAMAMLANDI

disp(' ');
disp('Karsilastirma tamamlandi.');
disp('Her yontem 1600 senaryoda test edildi.');
disp('Sonuclar Algoritma_Karsilastirma.csv dosyasinda.');
