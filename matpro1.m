
%% ADIM 5 - Dort Farkli Ariza Senaryosu
clc;
clear;
close all;
rng(42);

% Temel parametreler
N = 200;
t = 1:N;

R_warning = 0.045;
R_fault = 0.075;

window = 15;
confirmation_count = 3;
prediction_limit = 20;
min_slope = 0.0002;

% Dort senaryo icin temas direnci
R = zeros(4,N);

% 1 - Saglikli kablo
R(1,:) = 0.03;

% 2 - Yavas gelisen bozulma
R(2,:) = 0.03;
R(2,100:end) = linspace(0.03,0.12,101);

% 3 - Ani ariza
R(3,:) = 0.03;
R(3,145:end) = 0.11;

% 4 - Akim dalgalanmasi
R(4,:) = 0.03;

names = {'Saglikli Kablo', ...
         'Yavas Bozulma', ...
         'Ani Ariza', ...
         'Akim Dalgalanmasi'};

% Sonuc grafigi
figure('Name','Dort Ariza Senaryosu');

tiledlayout(2,2);

fprintf('\n--- SENARYO TEST RAPORU ---\n');

for s = 1:4

    % Akim modeli
    if s == 4
        I = 2 + 1.2*sin(2*pi*t/20);
    else
        I = 2 + 0.6*sin(2*pi*t/35);
    end

    % Gerilim olcumu simulasyonu
    V = I.*R(s,:) + 0.002*randn(1,N);

    % Temas direnci tahmini
    R_est = V./I;
   R_filtered = movmean(R_est,[4 0]);

    % Esik tabanli durum
    fault_detected = R_filtered >= R_fault;

    % Kritik esige kalan olcum tahmini
    remaining = NaN(1,N);

    for k = window:N

        idx = k-window+1:k;
        p = polyfit(t(idx),R_filtered(idx),1);

        if p(1) > min_slope
            remaining(k) = ...
                max(0,(R_fault-R_filtered(k))/p(1));
        end
    end

    % Erken uyari kosulu
    raw_warning = remaining > 0 & ...
                  remaining <= prediction_limit & ...
                  ~fault_detected;

    % 3 ardisik olcumle dogrulama
    confirmed = false(1,N);

    for k = confirmation_count:N
        idx = k-confirmation_count+1:k;

        if all(raw_warning(idx))
            confirmed(k) = true;
        end
    end

    % Ilk olay noktalari
    early_idx = find(confirmed,1,'first');
    fault_idx = find(fault_detected,1,'first');
    true_fault = find(R(s,:) >= R_fault,1,'first');

    % Rapor
   
%% ADIM 6 - Performans Analizi

% Gercek kritik esik gecisi
true_fault_idx = find( ...
    R(s,:) >= R_fault,1,'first');

% Erken uyari var mi?
has_early_warning = ~isempty(early_idx);

% Kritik tespit var mi?
has_detection = ~isempty(fault_idx);

fprintf('\n--- PERFORMANS ANALIZI ---\n');
fprintf('Senaryo: %s\n',names{s});

if isempty(true_fault_idx)

    % Gercekte kritik durum yok
    if has_detection
        fprintf('YANLIS KRITIK ALARM!\n');
    else
        fprintf('Yanlis kritik alarm: Yok\n');
    end

    if has_early_warning
        fprintf('YANLIS ERKEN UYARI!\n');
    else
        fprintf('Yanlis erken uyari: Yok\n');
    end

else

    fprintf('Gercek kritik gecis: %d\n', ...
        true_fault_idx);

    if has_detection
        detection_delay = ...
            fault_idx-true_fault_idx;

        fprintf('Tespit farki: %d olcum\n', ...
            detection_delay);
    else
        fprintf('Kritik esik tespit edilemedi.\n');
    end

    if has_early_warning

        lead_time = true_fault_idx-early_idx;

        if lead_time > 0
            fprintf('Erken uyari avantaji: %d olcum\n', ...
                lead_time);

            estimated_remaining = ...
                remaining(early_idx);

            prediction_error = abs( ...
                estimated_remaining-lead_time);

            fprintf('Tahmin hatasi: %.2f olcum\n', ...
                prediction_error);
        else
            fprintf('Kritik esikten once uyari yok.\n');
        end

    else
        fprintf('Erken uyari olusturulamadi.\n');
    end
end

    fprintf('\n%s\n',names{s});

    if isempty(early_idx)
        fprintf('Erken uyari: Yok\n');
    else
        fprintf('Erken uyari: %d\n',early_idx);
    end

    if isempty(fault_idx)
        fprintf('Kritik tespit: Yok\n');
    else
        fprintf('Kritik tespit: %d\n',fault_idx);
    end

    if ~isempty(true_fault) && ~isempty(fault_idx)
        fprintf('Tespit gecikmesi: %d olcum\n', ...
            fault_idx-true_fault);
    end

    % Grafik
    nexttile;

    plot(t,R_filtered,'LineWidth',1.7);
    hold on;

    yline(R_warning,'--', ...
        'Uyari Esigi');

    yline(R_fault,'--', ...
        'Kritik Esik');

    if ~isempty(early_idx)
        xline(early_idx,':', ...
            'Erken Uyari');
    end

    if ~isempty(fault_idx)
        xline(fault_idx,'--', ...
            'Kritik Tespit');
    end

    title(names{s});
    xlabel('Olcum Numarasi');
    ylabel('Direnc (Ohm)');
    ylim([0.02 0.14]);
    grid on;

end

sgtitle('MATLAB Kablo Sagligi - Senaryo Analizi');
