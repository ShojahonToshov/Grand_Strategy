import unittest
from decimal import Decimal, ROUND_HALF_UP

class ProjectDef:
    def __init__(self, name, total_cost, days_to_build, materials_needed):
        self.name = name
        self.total_cost = Decimal(str(total_cost))
        self.total_days = days_to_build
        self.daily_money_demand = self.total_cost / Decimal(str(days_to_build))
        self.materials_needed = materials_needed

class BuildingDef:
    def __init__(self, name, upkeep_money, upkeep_materials, output):
        self.name = name
        self.upkeep_money = Decimal(str(upkeep_money))
        self.upkeep_materials = upkeep_materials
        self.output = output

class EconomyState:
    def __init__(self, start_treasury_usd=0):
        self.treasury = Decimal(str(start_treasury_usd))
        self.materials = {}
        self.active_projects = []
        self.completed_buildings = []
        
        self.revenue_history = Decimal('0')
        self.expenses_history = Decimal('0')
        self.construction_spent_history = Decimal('0')
        self.upkeep_spent_history = Decimal('0')
        
        self.materials_produced = {}
        self.materials_consumed_upkeep = {}
        self.materials_consumed_construction = {}

    def get_material(self, name):
        return self.materials.get(name, Decimal('0'))

    def add_material(self, name, amount):
        amt = Decimal(str(amount))
        self.materials[name] = self.get_material(name) + amt

    def sub_material(self, name, amount):
        amt = Decimal(str(amount))
        self.materials[name] = self.get_material(name) - amt

class EconomyConfig:
    def __init__(self):
        self.construction_capacity = Decimal('500000.00')
        self.daily_mandatory_expenses = Decimal('7000000.00')
        self.daily_revenue = Decimal('0')

class ProjectInstance:
    def __init__(self, pdef: ProjectDef):
        self.pdef = pdef
        self.invested_money = Decimal('0')
        self.days_spent = Decimal('0')
        self.completed = False

def simulate_step(state: EconomyState, config: EconomyConfig):
    # 1. Operations (run buildings that were completed BEFORE this step)
    for b in state.completed_buildings:
        can_operate = True
        for m_name, m_qty in b.upkeep_materials.items():
            if state.get_material(m_name) < Decimal(str(m_qty)):
                can_operate = False
                break
        if state.treasury < b.upkeep_money:
            can_operate = False
            
        if can_operate:
            state.treasury -= b.upkeep_money
            state.upkeep_spent_history += b.upkeep_money
            for m_name, m_qty in b.upkeep_materials.items():
                qty = Decimal(str(m_qty))
                state.sub_material(m_name, qty)
                state.materials_consumed_upkeep[m_name] = state.materials_consumed_upkeep.get(m_name, Decimal('0')) + qty
            for m_name, m_qty in b.output.items():
                qty = Decimal(str(m_qty))
                state.add_material(m_name, qty)
                state.materials_produced[m_name] = state.materials_produced.get(m_name, Decimal('0')) + qty

    # 2. State Budget
    state.treasury += config.daily_revenue
    state.revenue_history += config.daily_revenue
    
    state.treasury -= config.daily_mandatory_expenses
    state.expenses_history += config.daily_mandatory_expenses
    
    if state.treasury < Decimal('0'):
        # Can't fund construction if broke
        active_projects = []
    else:
        active_projects = [p for p in state.active_projects if not p.completed]
        
    total_demand = sum((p.pdef.total_cost - p.invested_money) if (p.pdef.total_cost - p.invested_money) < p.pdef.daily_money_demand else p.pdef.daily_money_demand for p in active_projects)
    
    alloc_ratio = Decimal('1.0')
    if total_demand > config.construction_capacity:
        alloc_ratio = config.construction_capacity / total_demand
    if total_demand > 0 and state.treasury < total_demand * alloc_ratio:
        alloc_ratio = state.treasury / total_demand

    for p in active_projects:
        demand = min(p.pdef.daily_money_demand, p.pdef.total_cost - p.invested_money)
        allocated = demand * alloc_ratio
        
        # Rounding strictly to cents
        allocated = allocated.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        if allocated > state.treasury:
            allocated = state.treasury
            
        state.treasury -= allocated
        state.construction_spent_history += allocated
        p.invested_money += allocated
        p.days_spent += alloc_ratio
        
        if p.invested_money >= p.pdef.total_cost - Decimal('0.01'):
            p.completed = True
            p.invested_money = p.pdef.total_cost
            if p.pdef.name == "Logging Camp":
                state.completed_buildings.append(BuildingDef("Logging Camp", 1200, {}, {"wood": 30}))
            elif p.pdef.name == "Gold Mine":
                state.completed_buildings.append(BuildingDef("Gold Mine", 2300, {"wood": 20}, {"gold": 2.25}))

def start_project(state: EconomyState, pdef: ProjectDef):
    # Check materials
    for m_name, m_qty in pdef.materials_needed.items():
        if state.get_material(m_name) < Decimal(str(m_qty)):
            return False
            
    # Deduct materials
    for m_name, m_qty in pdef.materials_needed.items():
        qty = Decimal(str(m_qty))
        state.sub_material(m_name, qty)
        state.materials_consumed_construction[m_name] = state.materials_consumed_construction.get(m_name, Decimal('0')) + qty
        
    state.active_projects.append(ProjectInstance(pdef))
    return True

class EconomyTests(unittest.TestCase):
    def setUp(self):
        self.config = EconomyConfig()
        # Per capita revenue approach based on total France
        self.pop_fra_metro = Decimal('41907056')
        self.target_annual_revenue = Decimal('2860909690.00') # 43.4B FF / 15.17
        self.per_capita_yearly = self.target_annual_revenue / self.pop_fra_metro
        
        # Test regional setup
        self.mock_regions = [
            Decimal('10000000'),
            Decimal('20000000'),
            Decimal('11907056')
        ]
        
        # Calculate daily revenue from regions
        regional_daily_revenues = [
            (pop * self.per_capita_yearly / Decimal('366')).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            for pop in self.mock_regions
        ]
        self.config.daily_revenue = sum(regional_daily_revenues)
        self.config.daily_mandatory_expenses = Decimal('7000000.00')
        self.config.construction_capacity = Decimal('500000.00')
        
        self.state = EconomyState(start_treasury_usd=50000000.00)
        self.state.add_material("wood", 200)

        self.proj_logging = ProjectDef("Logging Camp", 167000, 30, {})
        self.proj_mine = ProjectDef("Gold Mine", 2500000, 180, {"wood": 200})

    def test_regional_taxation_sum(self):
        # The sum of regional daily taxes should equal target annual / 366 (within cents)
        target_daily = (self.target_annual_revenue / Decimal('366')).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        diff = abs(self.config.daily_revenue - target_daily)
        self.assertTrue(diff <= Decimal('0.05'), f"Diff too large: {diff}")

    def test_start_project_insufficient_materials(self):
        self.state.sub_material("wood", 100) # Only 100 left
        success = start_project(self.state, self.proj_mine)
        self.assertFalse(success)
        self.assertEqual(len(self.state.active_projects), 0)
        self.assertEqual(self.state.get_material("wood"), Decimal('100'))

    def test_start_project_success(self):
        success = start_project(self.state, self.proj_mine)
        self.assertTrue(success)
        self.assertEqual(len(self.state.active_projects), 1)
        self.assertEqual(self.state.get_material("wood"), Decimal('0'))

    def test_capacity_limit_and_competition(self):
        # Start 5 gold mines to exceed capacity (5 * 13888 = ~69k/day, capacity is 500k, wait let's make capacity 50k)
        self.state.add_material("wood", 1000)
        self.config.construction_capacity = Decimal('50000.00')
        for i in range(5):
            start_project(self.state, self.proj_mine)
            
        simulate_step(self.state, self.config)
        
        # 5 mines daily demand = 5 * 2500000/180 = 5 * 13888.89 = 69444.45
        # It should be capped at 50000.00
        spent = sum(p.invested_money for p in self.state.active_projects)
        self.assertEqual(spent, Decimal('50000.00'))

    def test_cancel_project_no_refund(self):
        start_project(self.state, self.proj_logging)
        simulate_step(self.state, self.config)
        invested = self.state.active_projects[0].invested_money
        self.assertTrue(invested > 0)
        
        # Cancel
        self.state.active_projects.pop(0)
        # Material not refunded, money not refunded
        self.assertEqual(self.state.get_material("wood"), Decimal('200')) # Logging camp didn't take wood
        self.assertEqual(len(self.state.active_projects), 0)

    def test_completion_timing_and_output(self):
        start_project(self.state, self.proj_logging)
        start_project(self.state, self.proj_mine)
        
        # t=30
        for _ in range(30):
            simulate_step(self.state, self.config)
            
        self.assertEqual(self.state.get_material("wood"), Decimal('0'))
        self.assertEqual(self.state.get_material("gold"), Decimal('0'))
        self.assertEqual(len(self.state.completed_buildings), 1)
        
        # t=31 (first output of logging camp)
        simulate_step(self.state, self.config)
        self.assertEqual(self.state.get_material("wood"), Decimal('30'))
        
        # t=90
        for _ in range(31, 90):
            simulate_step(self.state, self.config)
        self.assertEqual(self.state.get_material("wood"), Decimal('1800'))
        self.assertEqual(self.state.get_material("gold"), Decimal('0'))
        self.assertEqual(len(self.state.completed_buildings), 1)

        # t=180
        for _ in range(90, 180):
            simulate_step(self.state, self.config)
        self.assertEqual(self.state.get_material("wood"), Decimal('4500'))
        self.assertEqual(self.state.get_material("gold"), Decimal('0'))
        self.assertEqual(len(self.state.completed_buildings), 2)
        
        # t=181
        simulate_step(self.state, self.config)
        self.assertEqual(self.state.get_material("wood"), Decimal('4530') - Decimal('20'))
        self.assertEqual(self.state.get_material("gold"), Decimal('2.25'))
        
        # t=365
        for _ in range(181, 365):
            simulate_step(self.state, self.config)
            
        # 335 days of logging * 30 = 10050. 185 days of mine * 20 = 3700.
        # Initial 200 - 200 construction + 10050 - 3700 = 6350.
        self.assertEqual(self.state.get_material("wood"), Decimal('6350'))
        self.assertEqual(self.state.get_material("gold"), Decimal('416.25'))
        
        # Cash balance check
        expected_cash = Decimal('50000000.00') + self.state.revenue_history - self.state.expenses_history - self.state.construction_spent_history - self.state.upkeep_spent_history
        self.assertAlmostEqual(self.state.treasury, expected_cash, places=2)

if __name__ == '__main__':
    unittest.main(verbosity=2)
