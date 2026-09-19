# Test script for economic model (France 1936)
import math

# 1. State Budget Parameters
FRANCE_POPULATION = 41907056 # Metropole, 1936 census
FRENCH_REVENUE_FF = 43.4e9 # Francs, 1936
EXCHANGE_RATE = 15.17 # FF per 1 USD (Fed Reserve 1936 average)
ANNUAL_REVENUE_USD = FRENCH_REVENUE_FF / EXCHANGE_RATE
DAILY_REVENUE_USD = ANNUAL_REVENUE_USD / 366 # 1936 is leap year

# Mandatory expenses (Assumption C: 95% of gross revenue goes to state survival)
DAILY_EXPENSES_USD = DAILY_REVENUE_USD * 0.95

# Starting treasury (Assumption C: Liquid reserves)
START_TREASURY_USD = 50_000_000

# Construction Capacity (Assumption C: how much the state can invest per day)
CONSTRUCTION_CAPACITY_USD = 500_000

# 2. Buildings Specs
class Project:
    def __init__(self, name, total_cost, days_to_build, materials_needed):
        self.name = name
        self.total_cost = total_cost
        self.total_days = days_to_build
        self.daily_money_demand = total_cost / days_to_build
        self.materials_needed = materials_needed # dict e.g. {"wood": 0}
        
        self.invested_money = 0.0
        self.days_spent = 0
        self.completed = False

class LoggingCamp:
    def __init__(self):
        self.name = "Logging Camp"
        self.upkeep_money = 1200 # $1000 wages, $200 materials
        self.upkeep_materials = {}
        self.output = {"wood": 30} # 1 unit = 10 m3. Total 300 m3
        
class GoldMine:
    def __init__(self):
        self.name = "Gold Mine"
        self.upkeep_money = 2300 # $2000 wages, $300 power/explosives
        self.upkeep_materials = {"wood": 20} # 200 m3 of timber
        self.output = {"gold": 2.25} # 2.25 kg of gold

def simulate(days):
    treasury = START_TREASURY_USD
    materials = {"wood": 200, "gold": 0} # Starting materials
    
    projects = [
        Project("Logging Camp", 167000, 30, {}),
        Project("Gold Mine", 2500000, 180, {"wood": 200})
    ]
    
    # Deduct upfront materials for projects (if they need it)
    for p in projects:
        for m_name, m_qty in p.materials_needed.items():
            materials[m_name] -= m_qty
    
    buildings = []
    
    print(f"\n--- Simulation for {days} days ---")
    
    for day in range(1, days + 1):
        # 1. State Budget
        treasury += DAILY_REVENUE_USD
        treasury -= DAILY_EXPENSES_USD
        
        # 2. Construction
        active_projects = [p for p in projects if not p.completed]
        total_demand = sum(p.daily_money_demand for p in active_projects)
        
        alloc_ratio = 1.0
        if total_demand > CONSTRUCTION_CAPACITY_USD:
            alloc_ratio = CONSTRUCTION_CAPACITY_USD / total_demand
        if total_demand > 0 and treasury < total_demand * alloc_ratio:
            alloc_ratio = treasury / total_demand # Slow down if out of money
            
        for p in active_projects:
            allocated = p.daily_money_demand * alloc_ratio
            treasury -= allocated
            p.invested_money += allocated
            p.days_spent += alloc_ratio # fractional days
            
            if p.invested_money >= p.total_cost - 0.01:
                p.completed = True
                p.invested_money = p.total_cost
                if p.name == "Logging Camp":
                    buildings.append(LoggingCamp())
                elif p.name == "Gold Mine":
                    buildings.append(GoldMine())
                    
        # 3. Operations
        for b in buildings:
            # Check materials
            can_operate = True
            for m, q in b.upkeep_materials.items():
                if materials.get(m, 0) < q:
                    can_operate = False
                    break
            
            if treasury < b.upkeep_money:
                can_operate = False
                
            if can_operate:
                treasury -= b.upkeep_money
                for m, q in b.upkeep_materials.items():
                    materials[m] -= q
                for m, q in b.output.items():
                    materials[m] += q

    print(f"End Treasury: ${treasury:,.2f}")
    print(f"End Materials: {materials}")
    print(f"Active Buildings: {[b.name for b in buildings]}")
    for p in projects:
        print(f"Project {p.name}: {p.invested_money / p.total_cost * 100:.1f}% done")

if __name__ == "__main__":
    simulate(30)
    simulate(90)
    simulate(365)
    simulate(366)
