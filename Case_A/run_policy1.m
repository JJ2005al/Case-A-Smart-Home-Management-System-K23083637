function results = run_policy1(home, evLoad, p)

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

for k = 1:n
    demand = loadTotal(k);
    gen = pv(k);

    % PV serves load first
    pvToLoad = min(gen, demand);
    surplus = gen - pvToLoad;
    deficit = demand - pvToLoad;

    % Charge battery from surplus PV
    if surplus > 0
        chPowerLimitSOC = (p.cap - socNow) / (p.etaCh * p.dt);
        pCh(k) = min([surplus, p.pChMax, chPowerLimitSOC]);
        socNow = socNow + p.etaCh * pCh(k) * p.dt;
        gridExport(k) = surplus - pCh(k);
    end

    % Discharge battery if there is deficit
   if deficit > 0
    disPowerLimitSOC = socNow * p.etaDis / p.dt;
    pDis(k) = min([deficit, p.pDisMax, disPowerLimitSOC]);
    socNow = socNow - (pDis(k) / p.etaDis) * p.dt;
    gridImport(k) = deficit - pDis(k);
end
    soc(k) = socNow;

    % Cost
    stepCost(k) = gridImport(k) * p.dt * importTariff(k) ...
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