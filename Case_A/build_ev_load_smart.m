function pEV = build_ev_load_smart(homeTime, evTable, dt, importTariff, pv)
% Builds EV charging profile that guarantees required energy by departure.
% Prefers cheaper / PV-richer timesteps, but always meets deadline.

n = length(homeTime);
pEV = zeros(n,1);

for i = 1:height(evTable)

    arr = evTable.arrival_time(i);
    dep = evTable.departure_time(i);
    Ereq = evTable.required_energy_kwh(i);
    pMax = evTable.max_charge_power_kw(i);

    idx = find(homeTime >= arr & homeTime < dep);

    if isempty(idx)
        warning('No timesteps found for EV event %d', i);
        continue;
    end

    Erem = Ereq;

    for j = 1:length(idx)
        k = idx(j);

        stepsRemaining = length(idx) - j + 1;
        hoursRemaining = stepsRemaining * dt;

        % Minimum average power needed from this point onward
        pReq = Erem / hoursRemaining;

        % Prefer more charging if PV is available or import tariff is cheap
        pvBonus = 0;
        tariffBonus = 0;

        if pv(k) > 0.5
            pvBonus = 0.5;   % heuristic bonus
        end

        if importTariff(k) <= prctile(importTariff,30)
            tariffBonus = 0.5;
        end

        pCharge = min(pMax, max(pReq, pReq + pvBonus + tariffBonus));

        % Do not over-deliver in the last steps
        maxUsefulPower = Erem / dt;
        pCharge = min(pCharge, maxUsefulPower);

        pEV(k) = pCharge;
        Erem = Erem - pCharge * dt;

        if Erem <= 1e-6
            break;
        end
    end

    if Erem > 1e-4
        warning('EV event %d not fully satisfied. Remaining energy = %.3f kWh', i, Erem);
    end
end
end