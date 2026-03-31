# Case-A-Smart-Home-Management-System-K23083637
MATLAB script for Case A: Smart Home Management System coursework 
# Smart Home Energy Management (PV + Battery + EV)

This repository contains the MATLAB implementation for a smart home energy management system developed for the 6CCE3EGS coursework.

## Overview

The model simulates a residential energy system consisting of:
- Photovoltaic (PV) generation
- Battery energy storage (5 kWh)
- Grid import/export
- Electric Vehicle (EV) charging (extension)

Two control policies are implemented:
1. Policy 1 – PV self-consumption
2. Policy 2 – Tariff-aware control with SOC constraints

An extension includes EV charging, ensuring the required energy is delivered before departure.

---

## How to Run

1. Open MATLAB
2. Navigate to the project folder
3. Run: EGS_Coursework.m

---

## Key Features

- Energy balance enforced at every timestep
- Battery SOC modelling with efficiency losses
- Tariff-aware decision-making
- EV charging scheduling with constraints
- Verification checks:
  - Energy balance residual
  - SOC bounds
  - Power limits
  - EV energy delivery
  - End-of-horizon SOC

---

## Data

- `caseA_data.csv` – Household load, PV generation, tariffs
- `caseA_ev_events.csv` – EV arrival, departure, required energy, max power

---

## Results

Outputs include:
- SOC profiles
- PV vs Load comparison
- Grid import/export
- Cost analysis

Results correspond directly to those presented in the coursework report.

---

## Author

Jake Jeffries  
K23083637
