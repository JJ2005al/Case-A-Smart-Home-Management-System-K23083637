function results = run_policy2(home, evLoad, p)

n = height(home);

pv = home.pv_kw;
loadBase = home.base_load_kw;
loadTotal = loadBase + evLoad;
importTariff = home.import_tariff_gbp_per_kwh;
exportPrice = home.export_price_gbp_per_kwh;

soc = zeros(n,1);
pCh = zeros(n,1);
pDis = zeros(n,1);
gridImport = zeros(n,1);
gridExport = zeros(n,1);
stepCost = zeros(n,1);

socNow = p.socInit;

% Tariff thresholds
lowTariff = prctile(importTariff, 30);
highTariff = prctile(importTariff, 70);

% End-horizon protection window: last 48 steps = 24 hours for 30-min data
endWindow = 48;

for k = 1:n
    demand = loadTotal(k);
    gen = pv(k);
    tariff = importTariff(k);

    % PV serves load first
    pvToLoad = min(gen, demand);
    surplus = gen - pvToLoad;
    deficit = demand - pvToLoad;

    % --- Charge from surplus PV ---
    if surplus > 0
        chTarget = p.socMaxSoft;
chPowerLimitSOC = max(0, (chTarget - socNow) / (p.etaCh * p.dt));
        pCh(k) = min([surplus, p.pChMax, chPowerLimitSOC]);
        socNow = socNow + p.etaCh * pCh(k) * p.dt;
        gridExport(k) = surplus - pCh(k);
    end

    % --- Optional grid charging when tariff is low ---
    if surplus <= 0 && tariff <= lowTariff && socNow < p.socMaxSoft
        chTarget = p.socMaxSoft;
chPowerLimitSOC = max(0, (chTarget - socNow) / (p.etaCh * p.dt));
        extraGridCharge = min([p.pChMax, chPowerLimitSOC]);

        pCh(k) = pCh(k) + extraGridCharge;
        socNow = socNow + p.etaCh * extraGridCharge * p.dt;
        gridImport(k) = gridImport(k) + extraGridCharge;
    end

    % Recalculate deficit after any grid charging decision
    % House deficit should still be met separately
    if deficit > 0
        usableSOC = max(0, socNow - p.socMinSoft);
disPowerLimitSOC = usableSOC * p.etaDis / p.dt;

        % End-horizon protection: in last day, be more conservative
        inEndWindow = (k > n - endWindow);

        if tariff >= highTariff
            % Expensive electricity: discharge aggressively
            allowedDischarge = min([deficit, p.pDisMax, disPowerLimitSOC]);

        elseif tariff <= lowTariff
            % Cheap electricity: save battery, import instead
            allowedDischarge = 0;

        else
            % Medium tariff: only discharge if SOC is healthy
            if inEndWindow
                % More conservative near the end, but not a hard floor
                if socNow > 0.6 * p.cap
                    allowedDischarge = min([deficit, p.pDisMax, disPowerLimitSOC]);
                else
                    allowedDischarge = 0;
                end
            else
                if socNow > 0.3 * p.cap
                    allowedDischarge = min([deficit, p.pDisMax, disPowerLimitSOC]);
                else
                    allowedDischarge = 0;
                end
            end
        end

        pDis(k) = allowedDischarge;
        socNow = socNow - (pDis(k) / p.etaDis) * p.dt;
        gridImport(k) = gridImport(k) + (deficit - pDis(k));
    end

    soc(k) = socNow;

    % Cost
    stepCost(k) = gridImport(k) * p.dt * tariff ...
                - gridExport(k) * p.dt * exportPrice(k);
end

results.soc = soc;
results.pCh = pCh;
results.pDis = pDis;
results.gridImport = gridImport;
results.gridExport = gridExport;
results.stepCost = stepCost;

results.summary.totalImport_kWh = sum(gridImport) * p.dt;
results.summary.totalExport_kWh = sum(gridExport) * p.dt;
results.summary.totalCharge_kWh = sum(pCh) * p.dt;
results.summary.totalDischarge_kWh = sum(pDis) * p.dt;
results.summary.totalCost_GBP = sum(stepCost);
results.summary.finalSOC_kWh = soc(end);
results.summary.endSOC_ok = soc(end) >= p.socEndMin;

end