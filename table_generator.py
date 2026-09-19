from economy_test_suite import EconomyState, EconomyConfig, ProjectDef, start_project, simulate_step
from decimal import Decimal

def main():
    config = EconomyConfig()
    config.daily_revenue = Decimal('7194839.00') 
    config.daily_mandatory_expenses = Decimal('7000000.00')
    config.construction_capacity = Decimal('500000.00')

    state = EconomyState(start_treasury_usd=50000000.00)
    state.add_material("wood", 200)

    start_project(state, ProjectDef("Logging Camp", 167000, 30, {}))
    start_project(state, ProjectDef("Gold Mine", 2500000, 180, {"wood": 200}))

    checkpoints = [0, 30, 90, 180, 365, 366]
    
    print("| День | Нач. казна | Поступления | Обяз. расходы | На стройку | Затраты упр. | Кон. казна | Потрачено Wood | Добыто Wood | Добыто Gold |")
    print("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
    
    last_t = 0
    start_treasury = state.treasury
    for t in checkpoints:
        while last_t < t:
            simulate_step(state, config)
            last_t += 1
            
        print(f"| **{t}** | ${start_treasury:,.2f} | ${state.revenue_history:,.2f} | ${state.expenses_history:,.2f} | ${state.construction_spent_history:,.2f} | ${state.upkeep_spent_history:,.2f} | ${state.treasury:,.2f} | {state.materials_consumed_construction.get('wood', 0) + state.materials_consumed_upkeep.get('wood', 0)} | {state.materials_produced.get('wood', 0)} | {state.materials_produced.get('gold', 0)} |")

if __name__ == '__main__':
    main()
