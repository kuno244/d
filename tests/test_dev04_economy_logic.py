import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from dev04_logic_reference import Economy, accrue_production, claim_local

e=Economy({'food':100,'wood':50,'stone':20,'gold':5},{'food':120,'wood':100,'stone':50,'gold':20})
assert e.add('food',50)==20 and e.resources['food']==120
before=dict(e.resources)
assert not e.spend_atomic({'food':10,'wood':10,'stone':999,'gold':0})
assert e.resources==before
assert e.spend_atomic({'food':10,'wood':10,'stone':5,'gold':2})
assert e.resources=={'food':110,'wood':40,'stone':15,'gold':3}
assert e.can_afford({'food':100,'wood':40,'stone':15,'gold':3})
# 120/hour for one hour = 120, local cap clamps to 100.
stored,last=accrue_production(0,1000,4600,120,100,36000)
assert stored==100 and last==4600
# Negative clock movement gives no reward and does not move timestamp backwards.
stored2,last2=accrue_production(20,5000,4900,120,100,36000)
assert (stored2,last2)==(20,5000)
# Huge offline gap is limited to 10h.
stored3,last3=accrue_production(0,0,999999,10,1000,36000)
assert stored3==100 and last3==999999
# Claim respects global capacity and leaves unclaimed local production.
e2=Economy({'food':95},{'food':100})
claimed,remaining=claim_local(20,e2,'food')
assert claimed==5 and remaining==15 and e2.resources['food']==100
claimed2,remaining2=claim_local(remaining,e2,'food')
assert claimed2==0 and remaining2==15
print('PASS dev04 economy logic')
