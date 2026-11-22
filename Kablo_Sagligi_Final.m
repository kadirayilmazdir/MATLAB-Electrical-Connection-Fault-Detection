
%% ADIM 16 - KABLO SAGLIGI FINAL PROJESI
clc;
clear;
close all;
rng(42);

%% 1 - PARAMETRELER

N = 200;
trials = 100;
t = 1:N;

R_fault = 0.075;
R_warning = 0.045;

noise_levels = [0.002 0.005 0.010 0.020];

% Onceki ve optimize edilen hibrit parametreler
configs = [3 2 0;
           2 3 0.002];

methods = {'Onceki Hibrit','Optimize Hibrit'};

ls_window = 7;

% Sonuc dizileri
false_alarm = zeros(2,4,4,trials);
premature = zeros(2,4,4,trials);
detected = zeros(2,4,4,trials);
early_success = zeros(2,4,4,trials);

delay = NaN(2,4,4,trials);
lead = NaN(2,4,4,trials);

%% 2 - MONTE CARLO SIMULASYONU

for n = 1:trials

    for s = 1:4

        R = 0.03*ones(1,N);

        if s == 2
            st = randi([80 110]);
            R(st:end) = linspace(0.03,0.12,N-st+1);
        elseif s == 3
            st = randi([125 160]);
            R(st:end) = 0.11;
        end

        phase = 2*pi*rand;

        if s == 4
            I = 2+1.2*sin(2*pi*t/20+phase);
        else
            I = 2+0.6*sin(2*pi*t/35+phase);
        end

        noise_sample = randn(1,N);
        true_idx = find(R>=R_fault,1,'first');

        for g = 1:4

            V = I.*R + noise_levels(g)*noise_sample;

            for m = 1:2

                fast_window = configs(m,1);
                confirmation = configs(m,2);
                margin = configs(m,3);

                % Hizli direnc tahmini
                R_fast = movmean(V./I, ...
                    [fast_window-1 0]);

                % Kayan LS direnç tahmini
                R_LS = movsum(I.*V,[6 0]) ./ ...
                       movsum(I.^2,[6 0]);

                %% 3 - KRITIK ALARM

                candidate = ...
                    (R_fast>=R_fault) & ...
                    (R_LS>=R_fault-margin);

                fault = false(1,N);

                for k = confirmation:N

                    idx = k-confirmation+1:k;
                    fault(k) = all(candidate(idx));

                end

                %% 4 - ERKEN UYARI TAHMINI

                remaining = NaN(1,N);

                x = 1:15;
                weights = x-mean(x);
                den = sum(weights.^2);

                for k = 15:N

                    idx = k-14:k;

                    slope = sum(weights.*R_LS(idx))/den;

                    if slope > 0.0002

                        remaining(k) = max(0, ...
                            (R_fault-R_LS(k))/slope);
                    end
                end

                raw = remaining>0 & ...
                      remaining<=20 & ...
                      R_LS<R_fault;

                early = false(1,N);

                for k = 5:N
                    early(k) = all(raw(k-4:k));
                end

                %% 5 - PERFORMANS

                if isempty(true_idx)

                    false_alarm(m,g,s,n) = ...
                        any(fault) || any(early);

                else

                    if any(fault(1:true_idx-1))
                        premature(m,g,s,n) = 1;
                    end

                    % Gercek esikten sonraki ilk tespit
                    post = find( ...
                        fault(true_idx:end),1,'first');

                    if ~isempty(post)
                        detected(m,g,s,n) = 1;
                        delay(m,g,s,n) = post-1;
                    end

                    if s == 2

                        pre = find( ...
                            early(1:true_idx-1),1,'first');

                        if ~isempty(pre)

                            early_success(m,g,s,n) = 1;
                            lead(m,g,s,n) = true_idx-pre;

                        end
                    end
                end
            end
        end
    end
end

%% 6 - SONUCLAR

% 2 ve 4 numarali senaryolar:
% Yavas bozulma ve akim dalgalanmasi

FalseAlarmPct = zeros(2,4);
PrematurePct = zeros(2,4);
DetectionPct = zeros(2,4);
EarlyPct = zeros(2,4);

MeanDelay = NaN(2,4);
MeanLead = NaN(2,4);

for m = 1:2
    for g = 1:4

        a = reshape(false_alarm(m,g,4,:),[],1);
        p = reshape(premature(m,g,2,:),[],1);
        d = reshape(detected(m,g,2:3,:),[],1);
        e = reshape(early_success(m,g,2,:),[],1);

        dl = reshape(delay(m,g,2:3,:),[],1);
        ld = reshape(lead(m,g,2,:),[],1);

        FalseAlarmPct(m,g) = 100*mean(a);
        PrematurePct(m,g) = 100*mean(p);
        DetectionPct(m,g) = 100*mean(d);
        EarlyPct(m,g) = 100*mean(e);

        MeanDelay(m,g) = mean(dl,'omitnan');
        MeanLead(m,g) = mean(ld,'omitnan');

    end
end

%% 7 - SONUC TABLOSU

Method = strings(8,1);
Noise_mV = zeros(8,1);
FalseAlarm = zeros(8,1);
PrematureAlarm = zeros(8,1);
Detection = zeros(8,1);
EarlyWarning = zeros(8,1);
Delay = zeros(8,1);
Lead = zeros(8,1);

r = 0;

for m = 1:2
    for g = 1:4

        r = r+1;

        Method(r) = string(methods{m});
        Noise_mV(r) = noise_levels(g)*1000;

        FalseAlarm(r) = FalseAlarmPct(m,g);
        PrematureAlarm(r) = PrematurePct(m,g);
        Detection(r) = DetectionPct(m,g);
        EarlyWarning(r) = EarlyPct(m,g);
        Delay(r) = MeanDelay(m,g);
        Lead(r) = MeanLead(m,g);

    end
end

Results = table(Method,Noise_mV, ...
    FalseAlarm,PrematureAlarm, ...
    Detection,EarlyWarning,Delay,Lead);

disp('--- FINAL PROJE SONUCLARI ---');
disp(Results);

%% 8 - GRAFIKLER

fig = figure( ...
    'Name','Kablo Sagligi Final Analizi', ...
    'Color',[0.08 0.10 0.14], ...
    'Position',[50 50 1450 850]);

tl = tiledlayout(2,2, ...
    'TileSpacing','loose', ...
    'Padding','compact');

noise_mV = noise_levels*1000;

nexttile;

plot(noise_mV,FalseAlarmPct', ...
    '-o','LineWidth',2);

title('Akim Dalgalanmasinda Yanlis Alarm');
xlabel('Gurultu (mV)');
ylabel('Yanlis Alarm (%)');
legend(methods,'Location','best');
grid on;

nexttile;

plot(noise_mV,PrematurePct', ...
    '-o','LineWidth',2);

title('Yavas Bozulmada Erken Kritik Alarm');
xlabel('Gurultu (mV)');
ylabel('Oran (%)');
legend(methods,'Location','best');
grid on;

nexttile;

plot(noise_mV,MeanDelay', ...
    '-o','LineWidth',2);

title('Ortalama Kritik Tespit Gecikmesi');
xlabel('Gurultu (mV)');
ylabel('Gecikme (Olcum)');
legend(methods,'Location','best');
grid on;

nexttile;

plot(noise_mV,EarlyPct', ...
    '-o','LineWidth',2);

title('Yavas Bozulmada Erken Uyari');
xlabel('Gurultu (mV)');
ylabel('Basari (%)');
legend(methods,'Location','best');
ylim([0 105]);
grid on;

title(tl, ...
    'ELECTRICAL CONNECTION - FINAL COMPARISON', ...
    'Color','w','FontSize',17);

% Grafik arka planlarini duzenle
ax = findall(fig,'Type','axes');

for k = 1:numel(ax)

    ax(k).Color = [0.12 0.15 0.20];
    ax(k).XColor = 'w';
    ax(k).YColor = 'w';
    ax(k).Title.Color = 'w';
    ax(k).XLabel.Color = 'w';
    ax(k).YLabel.Color = 'w';
    ax(k).GridColor = [0.5 0.5 0.5];
    ax(k).GridAlpha = 0.25;

end

%% 9 - DOSYALARI KAYDET

folder = 'Final_Proje_Sonuclari';

if ~exist(folder,'dir')
    mkdir(folder);
end

writetable(Results, ...
    fullfile(folder,'Final_Sonuclar.csv'));

exportgraphics(fig, ...
    fullfile(folder,'Final_Karsilastirma.png'), ...
    'Resolution',300);

exportgraphics(fig, ...
    fullfile(folder,'Final_Karsilastirma.pdf'), ...
    'ContentType','vector');

disp(' ');
disp('FINAL PROJE ANALIZI TAMAMLANDI.');
disp('Grafikler ve CSV dosyasi kaydedildi.');
