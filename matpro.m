
clc;
clear;
close all;

% Akilli Kablo Sagligi Analizi
rng(42);

% 200 olcum noktasi
t = 1:200;

% Degisken yuk akimi (Amper)
I = 2 + 0.6*sin(2*pi*t/35);

% Baslangic temas direnci (Ohm)
R = 0.03*ones(size(t));

% 100. olcumden sonra temas bozulmasi
R(100:end) = linspace(0.03,0.12,101);

% Gerilim dusumu ve olcum gurultusu
Vdrop = I.*R + 0.002*randn(size(t));

% Olculen direncin tahmini
R_est = Vdrop./I;
R_filtered = movmean(R_est,5);

% Tahmini isi kaybi gucu
P_loss = I.^2.*R_filtered;

% Grafikler
figure('Name','Akilli Kablo Sagligi');

subplot(3,1,1)
plot(t,I,'LineWidth',1.5);
ylabel('Akim (A)');
grid on;
title('Yuk Akimi');

subplot(3,1,2)
plot(t,R,'--','LineWidth',1.5);
hold on;
plot(t,R_filtered,'LineWidth',1.5);
ylabel('Direnc (Ohm)');
legend('Gercek','Tahmin');
grid on;
title('Temas Direnci Analizi');

subplot(3,1,3)
plot(t,P_loss,'LineWidth',1.5);
xlabel('Olcum Numarasi');
ylabel('Kayip Gucu (W)');
grid on;
title('Elektriksel Kayip Analizi');

%% ADIM 2 - Otomatik Ariza Tespiti

% Simulasyon icin ornek esik degerleri
R_warning = 0.045;
R_fault = 0.075;

% Baglanti durumunu belirle
status = zeros(size(R_filtered));

status(R_filtered >= R_warning) = 1;
status(R_filtered >= R_fault) = 2;

% Ilk uyari ve ariza noktalarini bul
first_warning = find(status >= 1,1,'first');
first_fault = find(status == 2,1,'first');

% Sonuclari ekrana yazdir
fprintf('\n--- KABLO SAGLIK RAPORU ---\n');

fprintf('Ilk uyari: %d. olcum\n',first_warning);
fprintf('Ilk ariza: %d. olcum\n',first_fault);

fprintf('Son direnc: %.4f Ohm\n',R_filtered(end));
fprintf('Son durum kodu: %d\n',status(end));

% Durum grafigi
figure('Name','Otomatik Ariza Tespiti');

stairs(t,status,'LineWidth',2);
ylim([-0.2 2.2]);
yticks([0 1 2]);
yticklabels({'NORMAL','UYARI','ARIZA'});
xlabel('Olcum Numarasi');
ylabel('Baglanti Durumu');
title('MATLAB Otomatik Kablo Sagligi Analizi');
grid on;

%% ADIM 3 - Erken Ariza Tahmini

% Son 15 olcumden egilim hesapla
window = 15;

% Tahmini arizaya kalan olcum sayisi
remaining = NaN(size(t));

for k = window:length(t)

    % Son olcumleri sec
    idx = k-window+1:k;

    % Dogrusal egilim hesapla
    p = polyfit(t(idx),R_filtered(idx),1);

    % Direnc artiyorsa arizaya kalan sureyi tahmin et
    if p(1) > 0
        remaining(k) = ...
            max(0,(R_fault-R_filtered(k))/p(1));
    end
end

% Gercek ariza noktasindan onceki tahminler
early_idx = find( ...
    remaining > 0 & remaining <= 20 & ...
    status < 2,1,'first');

fprintf('\n--- ERKEN ARIZA TAHMINI ---\n');

if ~isempty(early_idx)
    fprintf('Erken uyari noktasi: %d\n',t(early_idx));
    fprintf('Tahmini kalan olcum: %.1f\n', ...
        remaining(early_idx));
else
    fprintf('20 olcum icinde erken tahmin yok.\n');
end

% Tahmin grafigi
figure('Name','Erken Ariza Tahmini');

plot(t,remaining,'LineWidth',1.5);
hold on;

yline(20,'--','20 Olcum Esigi');

xline(first_fault,'--','Gercek Ariza');

xlabel('Olcum Numarasi');
ylabel('Tahmini Kalan Olcum');
title('Temas Direnci ile Erken Ariza Tahmini');
ylim([0 60]);
grid on;

%% ADIM 4 - Akilli Erken Uyari Algoritmasi

% Parametreler
prediction_limit = 20;
confirmation_count = 3;

% Erken uyari kosulu
early_warning_raw = ...
    remaining > 0 & ...
    remaining <= prediction_limit & ...
    status < 2;

% Ardısik dogrulama
early_warning_confirmed = false(size(t));

for k = confirmation_count:length(t)

    idx = k-confirmation_count+1:k;

    if all(early_warning_raw(idx))
        early_warning_confirmed(k) = true;
    end
end

% Ilk dogrulanmis erken uyari
confirmed_idx = find( ...
    early_warning_confirmed,1,'first');

fprintf('\n--- AKILLI ERKEN UYARI ---\n');

if ~isempty(confirmed_idx)

    predicted_remaining = remaining(confirmed_idx);

    actual_remaining = ...
        first_fault-confirmed_idx;

    prediction_error = ...
        abs(predicted_remaining-actual_remaining);

    fprintf('Erken uyari: %d. olcum\n', ...
        confirmed_idx);

    fprintf('Tahmini kalan: %.2f olcum\n', ...
        predicted_remaining);

    fprintf('Gercek kalan: %d olcum\n', ...
        actual_remaining);

    fprintf('Mutlak tahmin hatasi: %.2f olcum\n', ...
        prediction_error);

else

    fprintf('Dogrulanmis erken uyari yok.\n');

end

% Grafik
figure('Name','Akilli Erken Uyari');

plot(t,R_filtered,'LineWidth',1.8);
hold on;

yline(R_warning,'--','Uyari Esigi');
yline(R_fault,'--','Kritik Esik');

if ~isempty(confirmed_idx)
    xline(t(confirmed_idx),'--', ...
        'Erken Uyari');
end

xline(t(first_fault),'--','Kritik Esik Gecisi');

xlabel('Olcum Numarasi');
ylabel('Temas Direnci (Ohm)');
title('Dogrulanmis Erken Ariza Tahmini');
grid on;

