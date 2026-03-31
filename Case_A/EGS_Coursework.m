clear; clc;

home = readtable('caseA_smart_home_30min_summer.csv');
ev   = readtable('caseA_ev_events.csv');

home.timestamp = datetime(home.timestamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
ev.arrival_time = datetime(ev.arrival_time, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
ev.departure_time = datetime(ev.departure_time, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');

dt = 0.5;                 % hours, 30 min data

cap = 5.0;                % kWh
pChMax = 2.5;             % kW
pDisMax = 2.5;            % kW
etaCh = 0.95;
etaDis = 0.95;
socInit = 0.5 * cap;      % 50% initial SOC
socEndMin = socInit;      % good choice for end-of-horizon condition
clear; clc;


% Load data
home = readtable('caseA_smart_home_30min_summer.csv');
home.timestamp = datetime(home.timestamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');

% Parameters
params.dt = 0.5;
params.cap = 5.0;
params.pChMax = 2.5;
params.pDisMax = 2.5;
params.etaCh = 0.95;
params.etaDis = 0.95;
params.socInit = 2.5;
params.socEndMin = 2.5;

% soc soft ceiling and floor for battery health
params.socMinSoft = 0.5;   % kWh
params.socMaxSoft = 4.5;   % kWh

% EV integration section
pEV = zeros(height(home),1);

ev = readtable('caseA_ev_events.csv');
ev.arrival_time = datetime(ev.arrival_time, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
ev.departure_time = datetime(ev.departure_time, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');

evLoad = build_ev_load_smart(home.timestamp, ev, params.dt, ...
    home.import_tariff_gbp_per_kwh, home.pv_kw);

% Run policy 1
results1 = run_policy1(home, evLoad, params);


% Plots 1
figure;
plot(home.timestamp, results1.soc, 'LineWidth', 1.2);
ylabel('SOC (kWh)');
xlabel('Time');
title('Battery State of Charge');

figure;
plot(home.timestamp, home.pv_kw, home.timestamp, home.base_load_kw + evLoad);
legend('PV', 'Total Load');
ylabel('Power (kW)');
xlabel('Time');
title('PV and Load');

disp(results1.summary)

% Run policy 2
results2 = run_policy2(home, evLoad, params);


% Plots 2
figure;
plot(home.timestamp, results2.soc, 'LineWidth', 1.2);
ylabel('SOC (kWh)');
xlabel('Time');
title('Battery State of Charge');

figure;
plot(home.timestamp, home.pv_kw, home.timestamp, home.base_load_kw + evLoad);
legend('PV', 'Total Load');
ylabel('Power (kW)');
xlabel('Time');
title('PV and Load');

disp(results2.summary)

% Fixing graphs by using a smaller window
idx = home.timestamp >= datetime(2025,7,5) & home.timestamp <= datetime(2025,7,12);
figure;
plot(home.timestamp(idx), results2.soc(idx), 'LineWidth', 1.5);
ylabel('SOC (kWh)');
xlabel('Time');
title('Battery State of Charge (Policy 2)');
grid on;

%Fixing graphs by overlapping policy 1 and 2
figure;
plot(home.timestamp(idx), results1.soc(idx), '--', 'LineWidth', 1.5);
hold on;
plot(home.timestamp(idx), results2.soc(idx), '-', 'LineWidth', 1.5);
legend('Policy 1', 'Policy 2');
ylabel('SOC (kWh)');
xlabel('Time');
title('SOC Comparison');
grid on;

% Fixing graphs by "improving PV vs Load plot"
figure;
plot(home.timestamp(idx), home.pv_kw(idx), 'LineWidth', 1.5);
hold on;
plot(home.timestamp(idx), (home.base_load_kw(idx) + evLoad(idx)), 'LineWidth', 1.5);
legend('PV Generation', 'Total Load');
ylabel('Power (kW)');
xlabel('Time');
title('PV Generation vs Load');
grid on;

% Checking if EV energy demand is met 
for i = 1:height(ev)
    idx = find(home.timestamp >= ev.arrival_time(i) & ...
               home.timestamp < ev.departure_time(i));

    delivered = sum(evLoad(idx)) * params.dt;
    required = ev.required_energy_kwh(i);

    fprintf('EV %d: Required = %.2f kWh, Delivered = %.2f kWh, Met = %d\n', ...
        i, required, delivered, delivered >= required - 1e-6);
end

% Checking SOC bounds 
assert(all(results1.soc >= -1e-9), 'Policy 1 failed: SOC below zero');
assert(all(results1.soc <= params.cap + 1e-9), 'Policy 1 failed: SOC above capacity');

assert(all(results2.soc >= -1e-9), 'Policy 2 failed: SOC below zero');
assert(all(results2.soc <= params.cap + 1e-9), 'Policy 2 failed: SOC above capacity');

fprintf('Policy 2 minimum SOC = %.3f kWh\n', min(results2.soc));
fprintf('Policy 2 maximum SOC = %.3f kWh\n', max(results2.soc));

% Battery power limits
assert(all(results1.pCh <= params.pChMax + 1e-9), 'Policy 1 failed: charge power exceeded');
assert(all(results1.pDis <= params.pDisMax + 1e-9), 'Policy 1 failed: discharge power exceeded');

assert(all(results2.pCh <= params.pChMax + 1e-9), 'Policy 2 failed: charge power exceeded');
assert(all(results2.pDis <= params.pDisMax + 1e-9), 'Policy 2 failed: discharge power exceeded');

% Energy balance residual
lhs1 = home.pv_kw + results1.gridImport + results1.pDis;
rhs1 = home.base_load_kw + evLoad + results1.pCh + results1.gridExport;
residual1 = lhs1 - rhs1;

lhs2 = home.pv_kw + results2.gridImport + results2.pDis;
rhs2 = home.base_load_kw + evLoad + results2.pCh + results2.gridExport;
residual2 = lhs2 - rhs2;

fprintf('Policy 1 max energy balance residual = %.6f kW\n', max(abs(residual1)));
fprintf('Policy 2 max energy balance residual = %.6f kW\n', max(abs(residual2)));

% End of Horizon SOC
fprintf('Policy 1 final SOC = %.3f kWh\n', results1.soc(end));
fprintf('Policy 2 final SOC = %.3f kWh\n', results2.soc(end));

fprintf('Policy 1 end SOC condition met = %d\n', results1.soc(end) >= params.socInit - 1e-9);
fprintf('Policy 2 end SOC condition met = %d\n', results2.soc(end) >= params.socInit - 1e-9);

